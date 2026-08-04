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

  final ctor = resolveConstructor(element);
  if (ctor == null) {
    return '// mockable_gen: skipped $className — no usable constructor found.';
  }

  final classRef = registry.type(element);

  final body = tracker.enter(element, () {
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
        auto: helpers.register,
      );
      args.add(param.isNamed ? '$name: $value' : value);
    }

    final ctorCall = ctor.name == 'new' || ctor.name == null
        ? classRef
        : '$classRef.${ctor.name}';
    final argsBlock = args.isEmpty ? '' : '${args.join(',\n        ')},';

    return '''
extension ${className}Mock on $classRef {
  static $classRef mock() => $ctorCall(
        $argsBlock
      );

  static List<$classRef> mockList([int count = $defaultCount]) =>
      List.generate(count, (_) => ${className}Mock.mock());
}
''';
  });

  return body;
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

    final ctor = resolveConstructor(el);
    if (ctor == null) {
      if (_hasMockExtension(el)) {
        _sourceByKey[key] =
            '$typeRef $helperName() => ${typeRef}Mock.mock();\n';
      } else {
        _sourceByKey[key] =
            '// mockable_gen: ${el.name} has no usable constructor.\n'
            '$typeRef $helperName() => throw UnimplementedError(\'no usable constructor for ${el.name}\');\n';
      }
      return helperName;
    }

    final body = tracker.enter(el, () {
      final args = <String>[];
      for (final param in ctor.formalParameters) {
        final pname = param.name;
        if (pname == null || pname.isEmpty) continue;
        final ignored = isMockIgnored(param);
        final value = emitValueForParameter(
          paramName: pname,
          type: param.type,
          tracker: tracker,
          registry: _registry,
          ignored: ignored,
          auto: register,
        );
        args.add(param.isNamed ? '$pname: $value' : value);
      }
      final call = ctor.name == 'new' || ctor.name == null
          ? typeRef
          : '$typeRef.${ctor.name}';
      final argsBlock =
          args.isEmpty ? '' : '\n      ${args.join(',\n      ')},\n    ';
      return '$call($argsBlock)';
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

  static String _keyFor(InterfaceElement el) =>
      '${el.library.uri}#${el.name}';
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
