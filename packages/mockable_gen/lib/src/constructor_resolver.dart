import 'package:analyzer/dart/element/element.dart';

const _excludedNames = {'fromJson', 'empty', 'mock', 'mockList'};

/// Picks the constructor that best represents how a consumer would normally
/// build an instance of [element]. Priority:
///
/// 1. The unnamed constructor (generative or redirecting factory). For
///    Freezed classes this is the `factory Foo(...) = _Foo` redirect.
/// 2. The first named generative or factory constructor that isn't on the
///    excluded list (`fromJson`, `empty`, `mock`, `mockList`) and doesn't
///    start with an underscore.
///
/// Returns `null` if nothing usable was found — caller should skip generation
/// and log.
ConstructorElement? resolveConstructor(InterfaceElement element) {
  final all = element.constructors;

  for (final c in all) {
    if (_isUnnamed(c) && _isUsable(c)) return c;
  }

  for (final c in all) {
    final name = c.name;
    if (name == null) continue;
    if (_excludedNames.contains(name)) continue;
    if (name.startsWith('_')) continue;
    if (!_isUsable(c)) continue;
    return c;
  }

  return null;
}

bool _isUnnamed(ConstructorElement c) => c.name == 'new' || c.name == null;

bool _isUsable(ConstructorElement c) {
  if (c.isFactory || c.isGenerative) return true;
  return false;
}
