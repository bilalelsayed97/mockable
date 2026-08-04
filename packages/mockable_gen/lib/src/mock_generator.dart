import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:mockable/mockable.dart';
import 'package:source_gen/source_gen.dart';

import 'code_emitter.dart';
import 'cycle_tracker.dart';
import 'import_registry.dart';
import 'migrate.dart';

/// `source_gen` generator for `package:mockable`'s `@Mockable()` annotation.
///
/// For every annotated class in a library it emits a `XxxMock` extension with
/// `mock()` / `mockList([count])` factories into a single standalone
/// `.mock.dart` library. Unlike a `part of` file, that library carries its own
/// imports, so the entire nested model tree reachable from an annotated class —
/// at any depth, spread across any number of files — is inlined as private
/// `_$mockXxx()` helpers and made resolvable. Only the top-level class needs
/// the annotation.
class MockLibraryGenerator extends Generator {
  const MockLibraryGenerator();

  static const _checker = TypeChecker.typeNamed(Mockable, inPackage: 'mockable');

  @override
  Future<String?> generate(LibraryReader library, BuildStep buildStep) async {
    final annotated = library.annotatedWith(_checker).toList();
    if (annotated.isEmpty) return null;

    await _warnOnLegacyPartDirective(buildStep);

    final registry = ImportRegistry();
    final tracker = CycleTracker();
    final helpers = HelperCollector(registry);
    final extensions = <String>[];

    for (final ann in annotated) {
      final element = ann.element;
      if (element is! InterfaceElement) {
        throw InvalidGenerationSourceError(
          '@Mockable() can only be applied to classes '
          '(got ${element.runtimeType}).',
          element: element,
        );
      }

      if (_existingMockExtension(element)) {
        log.info(
          'mockable_gen: skipping ${element.name} — '
          'a hand-written extension named ${element.name}Mock already exists.',
        );
        continue;
      }

      final defaultCount =
          ann.annotation.read('defaultCount').literalValue as int? ?? 10;

      extensions.add(emitMockExtension(
        element: element,
        defaultCount: defaultCount,
        tracker: tracker,
        registry: registry,
        helpers: helpers,
      ));
    }

    if (extensions.isEmpty) return null;

    final body = <String>[
      ...extensions,
      ...helpers.sources,
    ].join('\n');

    final resolved = registry.finish(body);

    // `MockFaker` is referenced literally throughout the generated code, so its
    // import is always required; a Set dedupes it against any registry import.
    final imports = <String>{
      "import '${ImportRegistry.mockableUri}';",
      ...resolved.imports,
    }.toList()
      ..sort();

    return <String>[
      ...imports,
      '',
      resolved.body,
    ].join('\n');
  }

  /// Logs a one-line warning if the input library still declares an old
  /// `part '<...>.mock.g.dart';` directive (the 0.2.x layout), nudging the user
  /// toward the migration command. Best-effort — any failure here must never
  /// break generation.
  Future<void> _warnOnLegacyPartDirective(BuildStep buildStep) async {
    try {
      final source = await buildStep.readAsString(buildStep.inputId);
      if (hasMockGPartDirective(source)) {
        log.warning(
          "mockable_gen 0.3.0 emits a standalone '.mock.dart' library, but "
          "${buildStep.inputId.path} still has a `part '...mock.g.dart';` "
          'directive. Run `dart run mockable_gen:migrate` to remove it and '
          'delete stale files, then import the generated `.mock.dart`.',
        );
      }
    } catch (_) {
      // Ignore — the warning is a convenience, not a correctness requirement.
    }
  }

  /// Returns `true` if [element]'s library already declares an extension named
  /// `<ClassName>Mock` — lets a consumer hand-write a mock factory for the
  /// annotated class and have the generator skip it.
  bool _existingMockExtension(InterfaceElement element) {
    final expectedName = '${element.name}Mock';
    for (final ext in element.library.extensions) {
      if (ext.name == expectedName) return true;
    }
    return false;
  }
}
