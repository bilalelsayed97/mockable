import 'package:analyzer/dart/element/element.dart';

/// Collects every user-defined type referenced while generating a `.mock.dart`
/// library and produces the `import` directives that make those types
/// resolvable from the standalone output file.
///
/// The output is a *library* (not a `part of` file), so — unlike the old
/// part-file design — it can and must import the libraries that declare the
/// nested types reachable from an `@Mockable()` class, no matter how deep or
/// how many files they span.
///
/// References are emitted as opaque placeholder tokens ([type]/[external])
/// while code is built, then swapped for their final spelling by [finish].
/// Deferring the decision until the whole tree is known lets us apply
/// **collision-only prefixing**: a library is imported unprefixed (clean
/// output) unless another library contributes a colliding simple name, in
/// which case the later one gets an `as _iN` prefix. This keeps the common
/// case (unique names across files) readable while staying correct when two
/// files declare, say, two different `Details` types.
class ImportRegistry {
  /// The runtime library that hosts `MockFaker`; always imported because every
  /// generated file calls into it.
  static const mockableUri = 'package:mockable/mockable.dart';

  /// U+0001 delimiter — never occurs in Dart source, so a token can sit next to
  /// `.`/`(` and be swapped out by an exact-match `replaceAll` without
  /// clobbering unrelated digits elsewhere in the generated code.
  static const _d = '\u0001';

  final List<_Ref> _refs = <_Ref>[];
  final Map<String, String> _tokenByKey = <String, String>{};

  /// Records a reference to [element]'s type and returns a placeholder token to
  /// embed in the generated source. Resolved by [finish].
  String type(InterfaceElement element) =>
      external(element.library.uri.toString(), element.name ?? '');

  /// Records a reference to a symbol [name] declared in library [uri] and
  /// returns a placeholder token. Used for `MockFaker` and any non-element
  /// reference.
  String external(String uri, String name) {
    final key = '$uri#$name';
    return _tokenByKey.putIfAbsent(key, () {
      final token = '$_d${_refs.length}$_d';
      _refs.add(_Ref(uri, name));
      return token;
    });
  }

  /// A placeholder for `MockFaker`, importing `package:mockable/mockable.dart`.
  String get mockFaker => external(mockableUri, 'MockFaker');

  /// Replaces every placeholder token in [body] with its final reference and
  /// returns the computed import block plus the rewritten source.
  ({List<String> imports, String body}) finish(String body) {
    final namesByUri = <String, Set<String>>{};
    for (final ref in _refs) {
      (namesByUri[ref.uri] ??= <String>{}).add(ref.name);
    }

    // Decide prefixes deterministically (sorted) so a library only yields an
    // `as _iN` prefix when it would otherwise clash with an already-claimed
    // simple name.
    final uris = namesByUri.keys.toList()..sort();
    final prefixByUri = <String, String?>{};
    final claimed = <String>{};
    var counter = 0;
    for (final uri in uris) {
      final names = namesByUri[uri]!;
      final free = names.every((n) => !claimed.contains(n));
      if (free) {
        prefixByUri[uri] = null;
        claimed.addAll(names);
      } else {
        prefixByUri[uri] = '_i${++counter}';
      }
    }

    var out = body;
    for (var i = 0; i < _refs.length; i++) {
      final ref = _refs[i];
      final prefix = prefixByUri[ref.uri];
      final spelling = prefix == null ? ref.name : '$prefix.${ref.name}';
      out = out.replaceAll('$_d$i$_d', spelling);
    }

    final imports = <String>[
      for (final uri in uris)
        if (prefixByUri[uri] == null)
          "import '$uri';"
        else
          "import '$uri' as ${prefixByUri[uri]};",
    ]..sort();

    return (imports: imports, body: out);
  }
}

class _Ref {
  const _Ref(this.uri, this.name);
  final String uri;
  final String name;
}
