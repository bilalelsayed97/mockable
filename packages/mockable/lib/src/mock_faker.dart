import 'dart:math';

import 'package:faker/faker.dart' as f;

/// A small static façade over `package:faker` providing the helpers that
/// `mockable_gen` emits in generated `.mock.dart` files.
///
/// All methods are static so generated code can call them without holding a
/// reference. Use [seed] to make subsequent calls deterministic (useful for
/// golden tests and snapshot widget tests).
class MockFaker {
  MockFaker._();

  static f.Faker _faker = f.Faker();
  static Random _random = Random();

  /// Seed the underlying random source. After calling this, every method
  /// below produces a deterministic sequence of values until [resetSeed] is
  /// called or a different seed is set.
  static void seed(int seedValue) {
    _random = Random(seedValue);
    _faker = f.Faker(seed: seedValue);
  }

  /// Reset to a non-deterministic random source.
  static void resetSeed() {
    _random = Random();
    _faker = f.Faker();
  }

  // ── strings ────────────────────────────────────────────────────────────

  static String word() => _faker.lorem.word();

  static String sentence() => _faker.lorem.sentence();

  static String paragraph() => _faker.lorem.sentences(3).join(' ');

  static String name() => _faker.person.name();

  static String firstName() => _faker.person.firstName();

  static String lastName() => _faker.person.lastName();

  static String email() => _faker.internet.email();

  /// Locale-friendly phone number. Defaults to a US-style number; pass a
  /// locale hint to vary the format (advisory in v1).
  static String phone({String? locale}) {
    if (locale == 'sa' || locale == 'ar') {
      // Saudi-style mobile: +9665XXXXXXXX
      final digits = List.generate(8, (_) => _random.nextInt(10)).join();
      return '+9665$digits';
    }
    return _faker.phoneNumber.us();
  }

  static String url() => 'https://${_faker.internet.domainName()}';

  /// Short id-like string (e.g. `'a1b2c3d4'`).
  static String id() => _randomAlphanumeric(8);

  /// Standards-style UUID (random; not cryptographically strong).
  static String uuid() => _faker.guid.guid();

  /// Six-character upper-case alphanumeric code.
  static String shortCode() => _randomAlphanumeric(6).toUpperCase();

  static String address() => _faker.address.streetAddress();

  static String city() => _faker.address.city();

  static String country() => _faker.address.country();

  // ── numbers ────────────────────────────────────────────────────────────

  static int integer({int min = 0, int max = 1000}) =>
      min + _random.nextInt(max - min);

  static double decimal({double min = 0, double max = 999, int scale = 2}) {
    final value = min + _random.nextDouble() * (max - min);
    final factor = pow(10, scale);
    return (value * factor).roundToDouble() / factor;
  }

  /// Currency-shaped value, e.g. `199.99`.
  static double currency() => decimal(min: 1, max: 9999);

  // ── dates ──────────────────────────────────────────────────────────────

  static DateTime dateTime() {
    final now = DateTime.now();
    final offsetDays = _random.nextInt(365 * 4) - (365 * 2);
    return now.add(Duration(days: offsetDays));
  }

  /// `'YYYY-MM-DD'` form.
  static String dateString() {
    final d = dateTime();
    return '${d.year.toString().padLeft(4, '0')}'
        '-${d.month.toString().padLeft(2, '0')}'
        '-${d.day.toString().padLeft(2, '0')}';
  }

  // ── bool ───────────────────────────────────────────────────────────────

  static bool boolean() => _random.nextBool();

  // ── internal ───────────────────────────────────────────────────────────

  static const _alphanumeric =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  static String _randomAlphanumeric(int length) {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(_alphanumeric[_random.nextInt(_alphanumeric.length)]);
    }
    return buffer.toString();
  }
}
