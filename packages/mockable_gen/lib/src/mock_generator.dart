import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:mockable/mockable.dart';
import 'package:source_gen/source_gen.dart';

import 'code_emitter.dart';
import 'cycle_tracker.dart';

/// `source_gen` generator for `package:mockable`'s `@Mockable()` annotation.
///
/// For each annotated class, emits a sibling extension `XxxMock` with
/// `mock()` and `mockList([count])` static factories. See package README
/// for the field-value strategy.
class MockGenerator extends GeneratorForAnnotation<Mockable> {
  const MockGenerator();

  @override
  String? generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! InterfaceElement) {
      throw InvalidGenerationSourceError(
        '@Mockable() can only be applied to classes (got ${element.runtimeType}).',
        element: element,
      );
    }

    if (_existingMockExtension(element)) {
      log.info(
        'mockable_gen: skipping ${element.name} — '
        'a hand-written extension named ${element.name}Mock already exists.',
      );
      return null;
    }

    final defaultCount = annotation.read('defaultCount').literalValue as int? ?? 10;

    final tracker = CycleTracker();
    return emitMockExtension(
      element: element,
      defaultCount: defaultCount,
      tracker: tracker,
    );
  }

  /// Returns `true` if the element's library already declares an extension
  /// named `<ClassName>Mock` on the same class — allows the consumer to
  /// hand-write a mock factory and have the generator skip it.
  bool _existingMockExtension(InterfaceElement element) {
    final library = element.library;
    final expectedName = '${element.name}Mock';
    for (final ext in library.extensions) {
      if (ext.name == expectedName) return true;
    }
    return false;
  }
}
