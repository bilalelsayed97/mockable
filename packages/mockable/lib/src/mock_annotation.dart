/// Marks a class for mock generation by `package:mockable_gen`.
///
/// Place this annotation on a class alongside `@JsonSerializable()` or
/// `@Freezed()` (or by itself on any class with a usable constructor) and
/// `mockable_gen` will emit a sibling `xxx.mock.dart` library containing:
///
/// ```dart
/// extension XxxMock on Xxx {
///   static Xxx mock();
///   static List<Xxx> mockList([int count = N]);
/// }
/// ```
///
/// Only the root class needs the annotation — every nested model reachable
/// from it, at any depth and across any number of files, is mocked
/// automatically.
///
/// Example:
/// ```dart
/// import 'package:mockable/mockable.dart';
///
/// @Mockable()
/// class User {
///   final String email;
///   const User({required this.email});
/// }
///
/// // Call site (import the generated 'user.mock.dart'):
/// final users = UserMock.mockList(5);
/// ```
class Mockable {
  /// Default count used by `mockList()` when no argument is passed.
  final int defaultCount;

  /// When set, `MockFaker` is seeded so generated mocks are deterministic
  /// for this class. Useful for golden screenshot tests.
  final int? seed;

  /// Locale hint forwarded to faker (e.g. `'en'`, `'ar'`, `'fr'`).
  ///
  /// Currently advisory; richer locale support depends on future faker
  /// integration. The seed-based determinism is locale-independent.
  final String? locale;

  const Mockable({this.defaultCount = 10, this.seed, this.locale});
}

/// Marks a single field so the generator emits `null` for it instead of a
/// faker-generated value. The consumer is expected to override the field if
/// they need a non-null value.
///
/// ```dart
/// @Mockable()
/// class Order {
///   final String id;
///   @MockableIgnore() final ComplexThing? thing;
///   const Order({required this.id, this.thing});
/// }
/// ```
class MockableIgnore {
  const MockableIgnore();
}
