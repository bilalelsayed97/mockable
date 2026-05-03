import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import 'cycle_tracker.dart';

/// Callback the field strategy invokes when it encounters a nested model type
/// that is *not* `@Mockable()`-annotated and has no hand-written `XxxMock`
/// extension. The callback is responsible for emitting (or reusing) a helper
/// for the type and returning the helper's identifier (e.g.
/// `_$mockDwPolicyDetails`). Implemented in [code_emitter] so generation and
/// the registry share the same helper map per output file.
typedef AutoMockRegister = String Function(
  InterfaceElement element,
  CycleTracker tracker,
);

/// Returns the source-code expression that should be used as the value for a
/// constructor parameter when generating a `mock()` factory.
///
/// [paramName] is the formal parameter name (used for name-based heuristics).
/// [type] is the declared type. [tracker] is shared cycle state. [auto], when
/// provided, enables recursion into unannotated nested model types.
String emitValueForParameter({
  required String paramName,
  required DartType type,
  required CycleTracker tracker,
  required bool ignored,
  AutoMockRegister? auto,
}) {
  if (ignored) {
    return type.nullabilitySuffix == NullabilitySuffix.question
        ? 'null'
        : _typeFallback(type, tracker, auto);
  }

  final byName = _byName(paramName, type);
  if (byName != null) return byName;

  return _typeFallback(type, tracker, auto);
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
    if (lower.contains('fullname') || lower == 'name' || lower.endsWith('name')) {
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
    if (lower == 'code' || lower.endsWith('code')) return 'MockFaker.shortCode()';
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
      if (_isAnnotatedMockable(innerEl) || _hasMockExtension(innerEl)) {
        return '${innerEl.name}Mock.mockList(3)';
      }
      if (auto != null && !tracker.isInCycle(innerEl)) {
        final helper = auto(innerEl, tracker);
        return 'List.generate(3, (_) => $helper())';
      }
    }
    final innerExpr = _typeFallback(inner, tracker, auto);
    return 'List.generate(3, (_) => $innerExpr)';
  }

  if (type.isDartCoreSet && type is InterfaceType) {
    final inner = type.typeArguments.firstOrNull;
    if (inner == null) return 'const <dynamic>{}';
    final innerExpr = _typeFallback(inner, tracker, auto);
    return '{$innerExpr}';
  }

  if (type.isDartCoreMap && type is InterfaceType) {
    final args = type.typeArguments;
    if (args.length == 2) {
      return '<${args[0].getDisplayString()}, ${args[1].getDisplayString()}>{}';
    }
    return '<dynamic, dynamic>{}';
  }

  if (element is EnumElement) {
    final preferred = _preferredEnumValue(element);
    return '${element.name}.$preferred';
  }

  if (_isMockableModel(type) && element is InterfaceElement) {
    if (tracker.isInCycle(element)) {
      return _cycleFallback(type, element);
    }
    if (_isAnnotatedMockable(element) || _hasMockExtension(element)) {
      return '${element.name}Mock.mock()';
    }
    if (auto != null) {
      return '${auto(element, tracker)}()';
    }
    return '${element.name}Mock.mock()';
  }

  if (element is InterfaceElement && _hasFactory(element, 'empty')) {
    return '${element.name}.empty()';
  }

  if (type.nullabilitySuffix == NullabilitySuffix.question) {
    return 'null';
  }

  // Last resort — surface the gap to the developer rather than emit
  // something that may compile but will mislead.
  final name = element?.name ?? type.getDisplayString();
  return '/* TODO(mockable_gen): provide value for $name */ null as $name';
}

bool _isAnnotatedMockable(InterfaceElement element) {
  for (final m in element.metadata.annotations) {
    final value = m.computeConstantValue();
    final t = value?.type;
    if (t == null) continue;
    if (t.element?.name == 'Mockable') return true;
  }
  return false;
}

bool _hasMockExtension(InterfaceElement element) {
  final library = element.library;
  final expected = '${element.name}Mock';
  for (final ext in library.extensions) {
    if (ext.name == expected) return true;
  }
  return false;
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

String _cycleFallback(DartType type, InterfaceElement modelElement) {
  if (_hasFactory(modelElement, 'empty')) {
    return '${modelElement.name}.empty()';
  }
  if (type.nullabilitySuffix == NullabilitySuffix.question) {
    return 'null';
  }
  return '${modelElement.name}()';
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
