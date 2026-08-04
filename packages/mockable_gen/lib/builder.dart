import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/mock_generator.dart';

const _header = '''
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import
''';

/// Returns the `Builder` registered in `build.yaml`. Emits a standalone
/// `.mock.dart` library next to every input library that contains at least one
/// class annotated with `@Mockable()`.
///
/// A standalone library (rather than a `part of` file) is required so the
/// output can import the libraries that declare deeply-nested model types,
/// which lets a single annotation on the top class generate the entire nested
/// tree across files.
Builder mockBuilder(BuilderOptions options) => LibraryBuilder(
      const MockLibraryGenerator(),
      generatedExtension: '.mock.dart',
      header: _header,
      writeDescriptions: false,
    );
