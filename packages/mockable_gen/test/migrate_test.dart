import 'package:mockable_gen/src/migrate.dart';
import 'package:test/test.dart';

void main() {
  group('stripMockPartDirectives', () {
    test('removes a single-quoted .mock.g.dart part directive', () {
      const input = '''
import 'package:mockable/mockable.dart';

part 'user.mock.g.dart';

@Mockable()
class User {}
''';
      final result = stripMockPartDirectives(input);
      expect(result.removed, 1);
      expect(result.source, isNot(contains('mock.g.dart')));
      expect(
          result.source, contains("import 'package:mockable/mockable.dart';"));
      expect(result.source, contains('class User {}'));
    });

    test('removes a double-quoted directive', () {
      const input = 'part "order.mock.g.dart";\nclass Order {}\n';
      final result = stripMockPartDirectives(input);
      expect(result.removed, 1);
      expect(result.source, isNot(contains('mock.g.dart')));
    });

    test('removes multiple directives and counts them', () {
      const input = '''
part 'a.mock.g.dart';
part 'b.mock.g.dart';
class C {}
''';
      final result = stripMockPartDirectives(input);
      expect(result.removed, 2);
      expect(result.source.trim(), 'class C {}');
    });

    test('leaves .freezed.dart / .g.dart / .mock.dart untouched', () {
      const input = '''
part 'user.freezed.dart';
part 'user.g.dart';
part 'user.mock.dart';
class User {}
''';
      final result = stripMockPartDirectives(input);
      expect(result.removed, 0);
      expect(result.source, equals(input));
    });

    test('tolerates leading/trailing whitespace on the directive line', () {
      const input = "  \tpart 'x.mock.g.dart';  \nclass X {}\n";
      final result = stripMockPartDirectives(input);
      expect(result.removed, 1);
      expect(result.source, isNot(contains('mock.g.dart')));
    });

    test('collapses the blank-line gap left behind', () {
      const input = '''
import 'a.dart';

part 'x.mock.g.dart';

class X {}
''';
      final result = stripMockPartDirectives(input);
      // No run of 3+ newlines should remain.
      expect(RegExp(r'\n{3,}').hasMatch(result.source), isFalse);
      expect(result.source, contains("import 'a.dart';"));
      expect(result.source, contains('class X {}'));
    });

    test('returns the source unchanged when nothing matches', () {
      const input = "import 'a.dart';\nclass A {}\n";
      final result = stripMockPartDirectives(input);
      expect(result.removed, 0);
      expect(result.source, same(input));
    });
  });

  group('hasMockGPartDirective', () {
    test('detects a legacy directive', () {
      expect(hasMockGPartDirective("part 'user.mock.g.dart';"), isTrue);
    });

    test('is false for the new .mock.dart layout', () {
      expect(hasMockGPartDirective("part 'user.mock.dart';"), isFalse);
    });

    test('is false when there is no part directive', () {
      expect(hasMockGPartDirective('class User {}'), isFalse);
    });
  });
}
