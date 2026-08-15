import 'package:analyzer/dart/element/element.dart';

/// Tracks which classes are currently mid-generation so cyclic references
/// (`A` -> `B` -> `A`) can fall back to a safe sentinel instead of recursing
/// forever.
class CycleTracker {
  final Set<String> _stack = <String>{};

  /// Returns `true` if [element] is already being expanded earlier in the
  /// current generation chain — in which case the caller should emit a
  /// fallback rather than recurse.
  bool isInCycle(InterfaceElement element) => _stack.contains(_keyFor(element));

  /// Run [body] with [element] pushed onto the cycle-detection stack and
  /// pop it on exit. Use to wrap any recursive descent into nested types.
  T enter<T>(InterfaceElement element, T Function() body) {
    final key = _keyFor(element);
    _stack.add(key);
    try {
      return body();
    } finally {
      _stack.remove(key);
    }
  }

  static String _keyFor(InterfaceElement element) =>
      '${element.library.uri}#${element.name}';
}
