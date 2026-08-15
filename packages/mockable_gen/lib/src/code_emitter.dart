import 'package:analyzer/dart/element/element.dart';

import 'constructor_resolver.dart';
import 'cycle_tracker.dart';
import 'field_strategy.dart';
import 'import_registry.dart';

/// Emits the `XxxMock` extension for a class [element] annotated with
/// `@Mockable()`, returning the source (with unresolved import tokens) that the
/// generator assembles into the standalone `.mock.dart` library.
///
/// Every nested model type reachable from [element] — annotated or not, at any
/// depth, across any number of files — is inlined as a private top-level
/// `_$mockXxx()` helper via [helpers]. Because [helpers] is shared across all
/// annotated classes in the file, each nested type is emitted at most once.
///
/// Sealed/Freezed-style unions (multiple named factory variants, no unnamed
/// constructor) get one `mockXxx()` per variant plus `mock()` delegating to the
/// richest variant.
///
/// [defaultCount] is the value used in `mockList([int count = N])`.
String emitMockExtension({
  required InterfaceElement element,
  required int defaultCount,
  required CycleTracker tracker,
  required ImportRegistry registry,
  required HelperCollector helpers,
}) {
  final className = element.name;
  if (className == null || className.isEmpty) {
    throw StateError('Cannot generate mock for unnamed class.');
  }

  if (element.typeParameters.isNotEmpty) {
    return '// mockable_gen: skipped $className — generic classes are not supported in v1.';
  }

  final resolved = resolveConstructors(element);
  if (resolved.mode == MockCtorMode.none) {
    if (isUninstantiableClass(element) && element.constructors.isNotEmpty) {
      return '// mockable_gen: skipped $className — abstract class with no factory constructor (cannot be instantiated).';
    }
    return '// mockable_gen: skipped $className — no usable constructor found.';
  }

  final classRef = registry.type(element);

  return tracker.enter(element, () {
    if (resolved.mode == MockCtorMode.single) {
      final call = emitConstructorCall(
        ctor: resolved.primary!,
        classRef: classRef,
        tracker: tracker,
        registry: registry,
        auto: helpers.register,
      );
      return '''
extension ${className}Mock on $classRef {
  static $classRef mock() => $call;

  static List<$classRef> mockList([int count = $defaultCount]) =>
      List.generate(count, (_) => ${className}Mock.mock());
}
''';
    }

    // Union mode: one static method per variant, then mock()/mockList()
    // delegating to the richest variant.
    final usedNames = <String>{'mock', 'mockList'};
    final methodNameByCtor = <ConstructorElement, String>{};
    final methods = <String>[];

    for (final variant in resolved.variants) {
      final base = 'mock${_pascal(variant.name!)}';
      final methodName = _dedupeMethodName(base, usedNames);
      methodNameByCtor[variant] = methodName;

      final call = emitConstructorCall(
        ctor: variant,
        classRef: classRef,
        tracker: tracker,
        registry: registry,
        auto: helpers.register,
      );
      final renameNote = methodName == base
          ? ''
          : '  // mockable_gen: renamed from $base to avoid a collision.\n';
      methods.add('$renameNote  static $classRef $methodName() => $call;');
    }

    final primaryMethod = methodNameByCtor[resolved.primary]!;

    return '''
extension ${className}Mock on $classRef {
${methods.join('\n\n')}

  static $classRef mock() => $primaryMethod();

  static List<$classRef> mockList([int count = $defaultCount]) =>
      List.generate(count, (_) => ${className}Mock.mock());
}
''';
  });
}

/// Emits `ClassRef.name(arg: value, ...)` (or `ClassRef(...)` for the unnamed
/// constructor) for [ctor], faking every parameter via the field strategy.
String emitConstructorCall({
  required ConstructorElement ctor,
  required String classRef,
  required CycleTracker tracker,
  required ImportRegistry registry,
  required AutoMockRegister auto,
}) {
  final args = <String>[];
  for (final param in ctor.formalParameters) {
    final name = param.name;
    if (name == null || name.isEmpty) continue;
    final ignored = isMockIgnored(param);
    final value = emitValueForParameter(
      paramName: name,
      type: param.type,
      tracker: tracker,
      registry: registry,
      ignored: ignored,
      auto: auto,
    );
    args.add(param.isNamed ? '$name: $value' : value);
  }

  final call = ctor.name == 'new' || ctor.name == null
      ? classRef
      : '$classRef.${ctor.name}';
  final argsBlock =
      args.isEmpty ? '' : '\n      ${args.join(',\n      ')},\n    ';
  return '$call($argsBlock)';
}

/// Uppercases only the first letter: `loaded` → `Loaded`, `loadedOk` →
/// `LoadedOk`.
String _pascal(String name) =>
    name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);

/// Returns [base] if free, else appends `Variant`, then `$2`, `$3`… until the
/// name is unique. The chosen name is added to [used].
String _dedupeMethodName(String base, Set<String> used) {
  var name = base;
  if (used.contains(name)) {
    name = '${base}Variant';
    var n = 2;
    while (used.contains(name)) {
      name = '${base}Variant\$$n';
      n++;
    }
  }
  used.add(name);
  return name;
}

/// Owns the per-output-file map of inlined `_$mockXxx()` helpers. Shared across
/// every `@Mockable()` class in a library so a nested type reached from two
/// different annotated classes is only generated once.
class HelperCollector {
  HelperCollector(this._registry);

  final ImportRegistry _registry;

  // Library-qualified key (`uri#Name`) -> generated helper source. Insertion
  // order is preserved for stable output; the reserved-empty-string slot also
  // acts as a second cycle guard alongside [CycleTracker].
  final Map<String, String> _sourceByKey = <String, String>{};
  final Map<String, String> _nameByKey = <String, String>{};
  final Set<String> _usedNames = <String>{};

  /// The generated helper sources, in insertion order.
  Iterable<String> get sources =>
      _sourceByKey.values.where((s) => s.isNotEmpty);

  /// Returns the helper function name for [el], generating it (and, on first
  /// visit, its transitive helpers) if necessary. Matches [AutoMockRegister].
  ///
  /// A nested union type gets one helper built from its richest variant.
  String register(InterfaceElement el, CycleTracker tracker) {
    final key = _keyFor(el);
    final existing = _nameByKey[key];
    if (existing != null) return existing;

    final typeRef = _registry.type(el);
    final helperName = _uniqueName(el.name ?? 'Anon');
    _nameByKey[key] = helperName;
    // Reserve the slot before recursing so cycles see "already registered".
    _sourceByKey[key] = '';

    if (el.typeParameters.isNotEmpty) {
      _sourceByKey[key] =
          '// mockable_gen: cannot auto-mock generic type ${el.name} — provide a hand-written ${el.name}Mock extension.\n'
          '$typeRef $helperName() => throw UnimplementedError(\'auto-mock unsupported for generic ${el.name}\');\n';
      return helperName;
    }

    final resolved = resolveConstructors(el);
    if (resolved.mode == MockCtorMode.none) {
      if (_hasMockExtension(el)) {
        _sourceByKey[key] =
            '$typeRef $helperName() => ${typeRef}Mock.mock();\n';
      } else {
        final reason = isUninstantiableClass(el) && el.constructors.isNotEmpty
            ? '${el.name} is abstract with no factory constructor'
            : '${el.name} has no usable constructor';
        _sourceByKey[key] = '// mockable_gen: $reason.\n'
            '$typeRef $helperName() => throw UnimplementedError(\'no usable constructor for ${el.name}\');\n';
      }
      return helperName;
    }

    final body = tracker.enter(el, () {
      return emitConstructorCall(
        ctor: resolved.primary!,
        classRef: typeRef,
        tracker: tracker,
        registry: _registry,
        auto: register,
      );
    });

    _sourceByKey[key] = '$typeRef $helperName() => $body;\n';
    return helperName;
  }

  String _uniqueName(String typeName) {
    final base = '_\$mock$typeName';
    var name = base;
    var n = 2;
    while (_usedNames.contains(name)) {
      name = '$base\$$n';
      n++;
    }
    _usedNames.add(name);
    return name;
  }

  static String _keyFor(InterfaceElement el) => '${el.library.uri}#${el.name}';
}

/// Returns `true` if [element]'s library declares an extension named
/// `<ClassName>Mock` — a hand-written mock the generator should defer to when a
/// type otherwise has no usable constructor.
bool _hasMockExtension(InterfaceElement element) {
  final expected = '${element.name}Mock';
  for (final ext in element.library.extensions) {
    if (ext.name == expected) return true;
  }
  return false;
}
