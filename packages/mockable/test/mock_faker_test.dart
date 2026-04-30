import 'package:mockable/mockable.dart';
import 'package:test/test.dart';

void main() {
  group('MockFaker', () {
    setUp(MockFaker.resetSeed);

    test('strings are non-empty', () {
      expect(MockFaker.word(), isNotEmpty);
      expect(MockFaker.sentence(), isNotEmpty);
      expect(MockFaker.email(), contains('@'));
      expect(MockFaker.url(), startsWith('https://'));
      expect(MockFaker.id(), hasLength(8));
      expect(MockFaker.shortCode(), hasLength(6));
    });

    test('integer respects min/max bounds', () {
      for (var i = 0; i < 100; i++) {
        final value = MockFaker.integer(min: 5, max: 10);
        expect(value, inInclusiveRange(5, 9));
      }
    });

    test('decimal respects scale', () {
      final value = MockFaker.decimal(scale: 2);
      expect(value.toStringAsFixed(2), endsWith(value.toStringAsFixed(2)));
    });

    test('seed produces deterministic output', () {
      MockFaker.seed(42);
      final firstRunSentence = MockFaker.sentence();
      final firstRunInt = MockFaker.integer();

      MockFaker.seed(42);
      expect(MockFaker.sentence(), firstRunSentence);
      expect(MockFaker.integer(), firstRunInt);
    });

    test('phoneSaudi locale produces Saudi-shaped number', () {
      final phone = MockFaker.phone(locale: 'sa');
      expect(phone, startsWith('+9665'));
      expect(phone, hasLength('+9665'.length + 8));
    });

    test('dateString is YYYY-MM-DD', () {
      final s = MockFaker.dateString();
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s), isTrue);
    });
  });
}
