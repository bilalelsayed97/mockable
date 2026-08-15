import 'package:analyzer/dart/element/element.dart';

const _excludedNames = {'fromJson', 'empty', 'mock', 'mockList'};

/// How the mock for a class should be generated, based on the constructors it
/// exposes.
enum MockCtorMode {
  /// Nothing usable was found — caller should skip generation and log.
  none,

  /// One representative constructor: today's classic `mock()`/`mockList()`.
  single,

  /// Multiple named factory variants (a Freezed-style sealed union): one
  /// `mockXxx()` per variant, plus `mock()` delegating to [ResolvedConstructors.primary].
  union,
}

/// The outcome of [resolveConstructors].
class ResolvedConstructors {
  const ResolvedConstructors.none()
      : mode = MockCtorMode.none,
        primary = null,
        variants = const [];

  const ResolvedConstructors.single(ConstructorElement this.primary)
      : mode = MockCtorMode.single,
        variants = const [];

  const ResolvedConstructors.union(
      this.variants, ConstructorElement this.primary)
      : mode = MockCtorMode.union;

  final MockCtorMode mode;

  /// [MockCtorMode.single]: the chosen constructor. [MockCtorMode.union]: the
  /// "richest" variant — the one `mock()` and nested `_$mockXxx()` helpers use.
  final ConstructorElement? primary;

  /// [MockCtorMode.union] only: every variant constructor, in declaration
  /// order.
  final List<ConstructorElement> variants;
}

/// Resolves how a consumer would normally build an instance of [element]:
///
/// 1. The unnamed constructor (generative or redirecting factory) wins when
///    usable. For Freezed classes this is the `factory Foo(...) = _Foo`
///    redirect. → [MockCtorMode.single].
/// 2. Otherwise the named generative/factory constructors that aren't on the
///    excluded list (`fromJson`, `empty`, `mock`, `mockList`) and don't start
///    with an underscore. Two or more → [MockCtorMode.union] (a sealed/Freezed
///    union of variants); exactly one → [MockCtorMode.single].
/// 3. Nothing usable → [MockCtorMode.none].
///
/// A generative constructor on an abstract (or sealed) class is never usable —
/// calling it would not compile. Factory constructors remain usable there.
ResolvedConstructors resolveConstructors(InterfaceElement element) {
  final all = element.constructors;

  for (final c in all) {
    if (_isUnnamed(c) && _isUsable(c)) return ResolvedConstructors.single(c);
  }

  final named = <ConstructorElement>[];
  for (final c in all) {
    final name = c.name;
    if (name == null) continue;
    if (_excludedNames.contains(name)) continue;
    if (name.startsWith('_')) continue;
    if (!_isUsable(c)) continue;
    named.add(c);
  }

  if (named.isEmpty) return const ResolvedConstructors.none();
  if (named.length == 1) return ResolvedConstructors.single(named.first);
  return ResolvedConstructors.union(named, _richest(named));
}

/// `true` when [element] is a class that cannot be instantiated directly
/// (abstract or sealed) — used to tailor skip messages.
bool isUninstantiableClass(InterfaceElement element) =>
    element is ClassElement && (element.isAbstract || element.isSealed);

/// `true` when a bare `Type()` call on [element] would resolve to a callable
/// constructor — used by cycle fallbacks before emitting one.
bool hasUsableUnnamedConstructor(InterfaceElement element) {
  for (final c in element.constructors) {
    if (_isUnnamed(c) && _isUsable(c)) return true;
  }
  return false;
}

bool _isUnnamed(ConstructorElement c) => c.name == 'new' || c.name == null;

bool _isUsable(ConstructorElement c) {
  if (c.isFactory) return true;
  final owner = c.enclosingElement;
  if (owner is ClassElement && (owner.isAbstract || owner.isSealed)) {
    // A generative constructor on an abstract/sealed class can't be called.
    return false;
  }
  return c.isGenerative;
}

/// The variant `mock()` should default to: most parameters wins, ties go to
/// the first-declared variant.
ConstructorElement _richest(List<ConstructorElement> variants) {
  var best = variants.first;
  for (final c in variants.skip(1)) {
    if (c.formalParameters.length > best.formalParameters.length) best = c;
  }
  return best;
}
