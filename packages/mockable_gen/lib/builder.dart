import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/mock_generator.dart';

const _header = '''
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
''';

/// Returns the `Builder` registered in `build.yaml`. Emits a `.mock.g.dart`
/// part-file next to every input library that contains at least one class
/// annotated with `@Mockable()`.
Builder mockBuilder(BuilderOptions options) =>
    PartBuilder([MockGenerator()], '.mock.g.dart', header: _header);
