import 'package:analyzer/dart/element/element.dart';

import 'constructor_resolver.dart';
import 'cycle_tracker.dart';
import 'field_strategy.dart';

/// Emits the generated extension for a class [element] annotated with
/// `@Mockable()`. Returns the generated source as a single Dart string.
///
/// Nested model types reachable from [element] that are themselves *not*
/// annotated (and lack a hand-written `XxxMock` extension) are auto-mocked
/// via private top-level helpers (`_$mockXxx()`) appended to the same output
/// file. Helpers are dedup'd by type name within this file.
///
/// [defaultCount] is the value used in `mockList([int count = N])`.
String emitMockExtension({
  required InterfaceElement element,
  required int defaultCount,
  required CycleTracker tracker,
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

  // Helper-name (e.g. `_$mockDwPolicyDetails`) -> generated source.
  // Insertion order is preserved so output is stable.
  final helpers = <String, String>{};

  late final AutoMockRegister registerHelper;
  registerHelper = (InterfaceElement el, CycleTracker innerTracker) {
    final name = el.name ?? '';
    final helperName = '_\$mock$name';
    if (helpers.containsKey(helperName)) return helperName;

    if (el.typeParameters.isNotEmpty) {
      helpers[helperName] =
          '// mockable_gen: cannot auto-mock generic type $name — provide a hand-written ${name}Mock extension.\n'
          '$name $helperName() => throw UnimplementedError(\'auto-mock unsupported for generic $name\');\n';
      return helperName;
    }

    final nestedCtor = resolveConstructor(el);
    if (nestedCtor == null) {
      helpers[helperName] =
          '// mockable_gen: $name has no usable constructor.\n'
          '$name $helperName() => throw UnimplementedError(\'no usable constructor for $name\');\n';
      return helperName;
    }

    // Reserve the slot before recursing so cycles see "already registered"
    // and short-circuit via the cycle tracker.
    helpers[helperName] = '';

    final body = innerTracker.enter(el, () {
      final args = <String>[];
      for (final param in nestedCtor.formalParameters) {
        final pname = param.name;
        if (pname == null || pname.isEmpty) continue;
        final ignored = isMockIgnored(param);
        final value = emitValueForParameter(
          paramName: pname,
          type: param.type,
          tracker: innerTracker,
          ignored: ignored,
          auto: registerHelper,
        );
        args.add(param.isNamed ? '$pname: $value' : value);
      }
      final call = nestedCtor.name == 'new' || nestedCtor.name == null
          ? name
          : '$name.${nestedCtor.name}';
      final argsBlock =
          args.isEmpty ? '' : '\n      ${args.join(',\n      ')},\n    ';
      return '$call($argsBlock)';
    });

    helpers[helperName] = '$name $helperName() => $body;\n';
    return helperName;
  };

  final extensionSource = tracker.enter(element, () {
    final args = <String>[];
    for (final param in ctor.formalParameters) {
      final name = param.name;
      if (name == null || name.isEmpty) continue;
      final ignored = isMockIgnored(param);
      final value = emitValueForParameter(
        paramName: name,
        type: param.type,
        tracker: tracker,
        ignored: ignored,
        auto: registerHelper,
      );
      if (param.isNamed) {
        args.add('$name: $value');
      } else {
        args.add(value);
      }
    }

    final ctorCall = ctor.name == 'new' || ctor.name == null
        ? className
        : '$className.${ctor.name}';

    final argsBlock = args.isEmpty ? '' : '${args.join(',\n        ')},';

    return '''
extension ${className}Mock on $className {
  static $className mock() => $ctorCall(
        $argsBlock
      );

  static List<$className> mockList([int count = $defaultCount]) =>
      List.generate(count, (_) => ${className}Mock.mock());
}
''';
  });

  if (helpers.isEmpty) return extensionSource;
  return '$extensionSource\n${helpers.values.join('\n')}';
}
