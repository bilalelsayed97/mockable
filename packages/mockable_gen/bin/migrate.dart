import 'dart:io';

import 'package:mockable_gen/src/migrate.dart';

/// One-shot migration for consumers upgrading `mockable_gen` 0.2.x → 0.3.0.
///
/// Run from your project root:
///
/// ```bash
/// dart run mockable_gen:migrate            # rewrite in place
/// dart run mockable_gen:migrate --dry-run  # preview only
/// dart run mockable_gen:migrate lib test   # limit to specific roots
/// ```
///
/// It performs the two *safe* rewrites the build step cannot do itself:
///  1. removes every `part '<...>.mock.g.dart';` directive from your sources, and
///  2. deletes stale `*.mock.g.dart` files (this package's old output).
///
/// It does NOT add `import '<name>.mock.dart';` at call sites — after running
/// this, do `dart run build_runner build` and add that import where the
/// resulting errors point.
Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run') || args.contains('-n');
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final roots = args.where((a) => !a.startsWith('-')).toList();
  if (roots.isEmpty) roots.add('.');

  final dartFiles = <File>[];
  final staleMockFiles = <File>[];
  for (final root in roots) {
    _collect(root, dartFiles, staleMockFiles);
  }

  var directivesRemoved = 0;
  var filesRewritten = 0;
  for (final file in dartFiles) {
    final original = file.readAsStringSync();
    final result = stripMockPartDirectives(original);
    if (result.removed == 0) continue;

    directivesRemoved += result.removed;
    filesRewritten++;
    final rel = _rel(file.path);
    if (dryRun) {
      stdout.writeln('would remove ${result.removed} part directive(s): $rel');
    } else {
      file.writeAsStringSync(result.source);
      stdout.writeln('removed ${result.removed} part directive(s): $rel');
    }
  }

  var deleted = 0;
  for (final file in staleMockFiles) {
    final rel = _rel(file.path);
    if (dryRun) {
      stdout.writeln('would delete stale file: $rel');
    } else {
      file.deleteSync();
      stdout.writeln('deleted stale file: $rel');
    }
    deleted++;
  }

  stdout
    ..writeln('')
    ..writeln(dryRun
        ? 'Dry run — no files changed.'
        : 'Done.')
    ..writeln('  part directives ${dryRun ? 'to remove' : 'removed'}: '
        '$directivesRemoved (in $filesRewritten file(s))')
    ..writeln('  stale .mock.g.dart files ${dryRun ? 'to delete' : 'deleted'}: '
        '$deleted');

  if (directivesRemoved == 0 && deleted == 0) {
    stdout.writeln('\nNothing to migrate — you are already on the 0.3.0 layout.');
    return;
  }

  if (!dryRun) {
    stdout
      ..writeln('\nNext steps:')
      ..writeln('  1. dart run build_runner build   '
          '# regenerates as <name>.mock.dart')
      ..writeln("  2. add import '<name>.mock.dart'; where the build errors "
          'point (call sites of XxxMock).');
  }
}

/// Recursively gathers `.dart` sources and stale `*.mock.g.dart` files under
/// [path], skipping build/tooling and hidden directories.
void _collect(String path, List<File> dartFiles, List<File> staleMockFiles) {
  final type = FileSystemEntity.typeSync(path);
  if (type == FileSystemEntityType.file) {
    _classify(File(path), dartFiles, staleMockFiles);
    return;
  }
  if (type != FileSystemEntityType.directory) {
    stderr.writeln('skipping (not found): $path');
    return;
  }

  for (final entity in Directory(path).listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    if (_isPruned(entity.path)) continue;
    _classify(entity, dartFiles, staleMockFiles);
  }
}

void _classify(File file, List<File> dartFiles, List<File> staleMockFiles) {
  final name = file.uri.pathSegments.last;
  if (name.endsWith('.mock.g.dart')) {
    staleMockFiles.add(file);
  } else if (name.endsWith('.dart')) {
    dartFiles.add(file);
  }
}

/// Prunes paths inside tooling/build/hidden directories.
bool _isPruned(String path) {
  final segments = path.split(Platform.pathSeparator);
  for (final s in segments) {
    if (s == '.dart_tool' || s == 'build' || s == '.git') return true;
    // Hidden directories (but allow a leading '.' root passed explicitly).
    if (s.length > 1 && s.startsWith('.')) return true;
  }
  return false;
}

String _rel(String path) {
  final cwd = Directory.current.path;
  if (path.startsWith(cwd)) {
    return path.substring(cwd.length).replaceFirst(RegExp(r'^[/\\]'), '');
  }
  return path;
}

void _printUsage() {
  stdout.writeln('''
mockable_gen migrate — upgrade a project from the 0.2.x part-file output to the
0.3.0 standalone-library output.

Usage:
  dart run mockable_gen:migrate [options] [paths...]

Options:
  -n, --dry-run   Show what would change without touching any files.
  -h, --help      Show this help.

Paths default to the current directory. It removes `part '<...>.mock.g.dart';`
directives and deletes stale `*.mock.g.dart` files. Afterwards run
`dart run build_runner build` and add `import '<name>.mock.dart';` at call
sites.''');
}
