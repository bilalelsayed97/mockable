import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import 'constructor_resolver.dart';
import 'cycle_tracker.dart';
import 'import_registry.dart';

/// Callback the field strategy invokes when it encounters a nested model type.
/// The callback is responsible for emitting (or reusing) a private
/// `_$mockXxx()` helper for the type and returning the helper's identifier. It
/// is always supplied during real generation; the parameter stays nullable only
/// so unit tests can exercise the value strategy in isolation. Implemented in
/// [code_emitter] so generation and the helper registry share one map per
/// output file.
typedef AutoMockRegister = String Function(
  InterfaceElement element,
  CycleTracker tracker,
);

/// Returns the source-code expression that should be used as the value for a
/// constructor parameter when generating a `mock()` factory.
///
/// [paramName] is the formal parameter name (used for name-based heuristics).
/// [type] is the declared type. [tracker] is shared cycle state. [registry]
/// records the imports every emitted type reference needs. [auto], when
/// provided, inlines a helper for any nested model type reached from here.
String emitValueForParameter({
  required String paramName,
  required DartType type,
  required CycleTracker tracker,
  required ImportRegistry registry,
  required bool ignored,
  AutoMockRegister? auto,
}) {
  if (ignored) {
    return type.nullabilitySuffix == NullabilitySuffix.question
        ? 'null'
        : _typeFallback(type, tracker, registry, auto);
  }

  final byName = _byName(paramName, type);
  if (byName != null) return byName;

  return _typeFallback(type, tracker, registry, auto);
}

/// Returns `true` if [param] is annotated with `@MockableIgnore()`. Walks both
/// the parameter's own metadata AND, for initializing formals (`this.x`),
/// the metadata of the field they reference — so consumers can put the
/// annotation on either the parameter or the field declaration.
bool isMockIgnored(FormalParameterElement param) {
  if (_hasMockIgnore(param.metadata.annotations)) return true;
  if (param is FieldFormalParameterElement) {
    final field = param.field;
    if (field != null && _hasMockIgnore(field.metadata.annotations)) {
      return true;
    }
  }
  return false;
}

bool _hasMockIgnore(List<ElementAnnotation> annotations) {
  for (final m in annotations) {
    final value = m.computeConstantValue();
    final t = value?.type;
    if (t == null) continue;
    if (t.element?.name == 'MockableIgnore') return true;
  }
  return false;
}

// ── name heuristics ─────────────────────────────────────────────────────

String? _byName(String paramName, DartType type) {
  final lower = paramName.toLowerCase();

  bool has(List<String> needles) => needles.any(lower.contains);

  if (type.isDartCoreString) {
    if (has(['email', 'mail'])) return 'MockFaker.email()';
    if (has(['phone', 'mobile', 'cell'])) return 'MockFaker.phone()';
    if (lower.contains('firstname')) return 'MockFaker.firstName()';
    if (lower.contains('lastname')) return 'MockFaker.lastName()';
    if (lower.contains('fullname') ||
        lower == 'name' ||
        lower.endsWith('name')) {
      return 'MockFaker.name()';
    }
    if (has(['uuid', 'guid'])) return 'MockFaker.uuid()';
    if (has(['url', 'link', 'image'])) return 'MockFaker.url()';
    if (has(['description', 'title', 'note', 'comment', 'message'])) {
      return 'MockFaker.sentence()';
    }
    if (has(['createdat', 'updatedat', 'startdate', 'enddate', 'date'])) {
      return 'MockFaker.dateString()';
    }
    if (lower.contains('address')) return 'MockFaker.address()';
    if (lower.contains('city')) return 'MockFaker.city()';
    if (lower.contains('country')) return 'MockFaker.country()';
    if (lower == 'id' || lower.endsWith('id')) return 'MockFaker.id()';
    if (lower == 'code' || lower.endsWith('code')) {
      return 'MockFaker.shortCode()';
    }
    return null;
  }

  if (type.isDartCoreInt || type.isDartCoreDouble || type.isDartCoreNum) {
    if (has(['amount', 'price', 'total', 'balance', 'cost'])) {
      return type.isDartCoreInt
          ? 'MockFaker.currency().toInt()'
          : 'MockFaker.currency()';
    }
  }

  return null;
}

// ── type fallbacks ──────────────────────────────────────────────────────

String _typeFallback(
  DartType type,
  CycleTracker tracker,
  ImportRegistry registry,
  AutoMockRegister? auto,
) {
  if (type.isDartCoreString) return 'MockFaker.word()';
  if (type.isDartCoreInt) return 'MockFaker.integer()';
  if (type.isDartCoreDouble || type.isDartCoreNum) return 'MockFaker.decimal()';
  if (type.isDartCoreBool) return 'MockFaker.boolean()';

  final element = type.element;

  if (element != null && element.name == 'DateTime') {
    return 'MockFaker.dateTime()';
  }

  if (type.isDartCoreList && type is InterfaceType) {
    final inner = type.typeArguments.firstOrNull;
    if (inner == null) return 'const []';
    final innerEl = inner.element;
    if (_isMockableModel(inner) && innerEl is InterfaceElement) {
      // Always inline a fresh helper for nested models (even annotated ones),
      // so the generated file is fully self-contained.
      if (auto != null && !tracker.isInCycle(innerEl)) {
        final helper = auto(innerEl, tracker);
        return 'List.generate(3, (_) => $helper())';
      }
    }
    final innerExpr = _typeFallback(inner, tracker, registry, auto);
    return 'List.generate(3, (_) => $innerExpr)';
  }

  if (type.isDartCoreSet && type is InterfaceType) {
    final inner = type.typeArguments.firstOrNull;
    if (inner == null) return 'const <dynamic>{}';
    final innerExpr = _typeFallback(inner, tracker, registry, auto);
    return '{$innerExpr}';
  }

  if (type.isDartCoreMap && type is InterfaceType) {
    final args = type.typeArguments;
    if (args.length == 2) {
      // Emit one representative entry so nested models inside the value (or
      // key) type are recursed into, instead of an empty map. A single entry
      // avoids duplicate-key surprises at runtime.
      final keyExpr = _typeFallback(args[0], tracker, registry, auto);
      final valueExpr = _typeFallback(args[1], tracker, registry, auto);
      return '{$keyExpr: $valueExpr}';
    }
    return '<dynamic, dynamic>{}';
  }

  if (element is EnumElement) {
    final preferred = _preferredEnumValue(element);
    return '${registry.type(element)}.$preferred';
  }

  if (_isMockableModel(type) && element is InterfaceElement) {
    if (tracker.isInCycle(element)) {
      return _cycleFallback(type, element, registry);
    }
    // Always inline a fresh `_$mock` helper for the nested model.
    if (auto != null) {
      return '${auto(element, tracker)}()';
    }
    // Conservative fallback for the isolated-testing path where no registrar
    // is supplied: defer to a (possibly hand-written) extension.
    return '${registry.type(element)}Mock.mock()';
  }

  if (element is InterfaceElement && _hasFactory(element, 'empty')) {
    return '${registry.type(element)}.empty()';
  }

  if (type.nullabilitySuffix == NullabilitySuffix.question) {
    return 'null';
  }

  // Last resort — surface the gap to the developer rather than emit
  // something that may compile but will mislead.
  if (element is InterfaceElement) {
    final ref = registry.type(element);
    return '/* TODO(mockable_gen): provide value for ${element.name} */ null as $ref';
  }
  final name = type.getDisplayString();
  return '/* TODO(mockable_gen): provide value for $name */ null as $name';
}

bool _isMockableModel(DartType type) {
  final element = type.element;
  if (element is! InterfaceElement) return false;
  if (element is EnumElement) return false;
  if (type.isDartCoreString ||
      type.isDartCoreInt ||
      type.isDartCoreDouble ||
      type.isDartCoreBool ||
      type.isDartCoreNum ||
      type.isDartCoreList ||
      type.isDartCoreMap ||
      type.isDartCoreSet ||
      type.isDartCoreObject ||
      type.isDartCoreIterable) {
    return false;
  }
  if (element.name == 'DateTime' || element.name == 'Duration') return false;
  return true;
}

String _cycleFallback(
  DartType type,
  InterfaceElement modelElement,
  ImportRegistry registry,
) {
  if (_hasFactory(modelElement, 'empty')) {
    return '${registry.type(modelElement)}.empty()';
  }
  if (type.nullabilitySuffix == NullabilitySuffix.question) {
    return 'null';
  }
  if (hasUsableUnnamedConstructor(modelElement)) {
    return '${registry.type(modelElement)}()';
  }
  // A bare `Type()` would not compile (abstract/union type in a cycle) —
  // surface the gap instead.
  final ref = registry.type(modelElement);
  return '/* TODO(mockable_gen): cyclic uninstantiable type ${modelElement.name} */ null as $ref';
}

bool _hasFactory(InterfaceElement element, String name) {
  for (final c in element.constructors) {
    if (c.name == name && c.isFactory) return true;
  }
  return false;
}

String _preferredEnumValue(EnumElement element) {
  final values = element.constants;
  for (final v in values) {
    final lower = (v.name ?? '').toLowerCase();
    if (lower == 'unknown' || lower == 'none' || lower == 'undefined') {
      continue;
    }
    return v.name ?? '';
  }
  return values.isNotEmpty ? values.first.name ?? '' : '';
}

extension on Iterable<DartType> {
  DartType? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
