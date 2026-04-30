import 'package:analyzer/dart/element/element.dart';

import 'constructor_resolver.dart';
import 'cycle_tracker.dart';
import 'field_strategy.dart';

/// Emits the generated extension for a class [element] annotated with
/// `@Mockable()`. Returns the generated source as a single Dart string.
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

  return tracker.enter(element, () {
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
}
