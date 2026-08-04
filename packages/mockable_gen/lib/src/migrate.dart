/// Pure, `dart:io`-free helpers for migrating consumers from the 0.2.x part-file
/// output (`xxx.mock.g.dart`) to the 0.3.0 standalone-library output
/// (`xxx.mock.dart`).
///
/// Kept free of I/O so it can be unit-tested and reused by the generator's
/// build-time warning; the file-system side lives in `bin/migrate.dart`.
library;

/// Matches a whole-line `part '<...>.mock.g.dart';` directive (single or double
/// quoted), tolerating leading/trailing horizontal whitespace. Only the old
/// `.mock.g.dart` extension is matched — `.g.dart`, `.freezed.dart`, and the new
/// `.mock.dart` are intentionally left alone.
final RegExp _mockPartLine = RegExp(
  r'''^[ \t]*part\s+(['"])[^'"]*\.mock\.g\.dart\1\s*;[ \t]*$''',
  multiLine: true,
);

/// Result of [stripMockPartDirectives].
typedef StripResult = ({String source, int removed});

/// Removes every `part '<...>.mock.g.dart';` directive from [source] and returns
/// the rewritten text along with how many were removed.
///
/// Removing a directive can leave a gap of blank lines; any run of three or more
/// consecutive newlines is collapsed back to a single blank line so the file
/// stays tidy. If nothing matched, the source is returned unchanged.
StripResult stripMockPartDirectives(String source) {
  final matches = _mockPartLine.allMatches(source).length;
  if (matches == 0) return (source: source, removed: 0);

  // Drop the directive lines together with their trailing newline so we don't
  // leave a stray empty line behind for every removal.
  var out = source.replaceAll(RegExp('${_mockPartLine.pattern}\n?', multiLine: true), '');

  // Collapse 3+ consecutive newlines (an over-wide gap) down to one blank line.
  out = out.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return (source: out, removed: matches);
}

/// Returns `true` if [source] still declares an old `part '<...>.mock.g.dart';`
/// directive. Used by the generator to warn during a build.
bool hasMockGPartDirective(String source) => _mockPartLine.hasMatch(source);
