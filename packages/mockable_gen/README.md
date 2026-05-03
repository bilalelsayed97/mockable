# mockable_gen

[![pub package](https://img.shields.io/pub/v/mockable_gen.svg)](https://pub.dev/packages/mockable_gen)

`build_runner` generator for [`package:mockable`](https://pub.dev/packages/mockable). Emits a sibling `xxx.mock.g.dart` file containing `XxxMock.mock()` and `XxxMock.mockList(count)` factories for every class annotated with `@Mockable()`.

## Install

```yaml
dependencies:
  mockable: ^0.1.0

dev_dependencies:
  mockable_gen: ^0.2.0
  build_runner: ^2.4.13
```

## Usage

```dart
import 'package:mockable/mockable.dart';

part 'user.mock.g.dart';

@Mockable()
class User {
  final String id;
  final String email;
  final String fullName;

  const User({required this.id, required this.email, required this.fullName});
}
```

Run the builder:

```bash
dart run build_runner build
```

Generated output (`user.mock.g.dart`):

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND
part of 'user.dart';

extension UserMock on User {
  static User mock() => User(
        id: MockFaker.id(),
        email: MockFaker.email(),
        fullName: MockFaker.name(),
      );

  static List<User> mockList([int count = 10]) =>
      List.generate(count, (_) => UserMock.mock());
}
```

## How it works

For each class annotated with `@Mockable()`:

1. The generator picks a constructor (priority: unnamed generative or redirecting factory; otherwise the first named one that isn't `fromJson`/`empty`/`mock` and doesn't start with `_`).
2. For each parameter, it picks a value via two layers:
    - **Field-name heuristics** — `email` → `MockFaker.email()`, `phone` → `MockFaker.phone()`, etc. (see the [mockable README](../mockable/README.md) for the full table).
    - **Type-based fallback** — `String` → `MockFaker.word()`, `int` → `MockFaker.integer()`, `bool` → `MockFaker.boolean()`, `DateTime` → `MockFaker.dateTime()`, enums → first non-`unknown`/`none` value, nested `@Mockable` models → `XxxMock.mock()`, `List<T>` → `TMock.mockList(3)` or `List.generate(3, ...)`.
3. Generates the `XxxMock` extension with `mock()` and `mockList([int count = N])`.

## Nested types — no annotation needed (since 0.2.0)

You only need `@Mockable()` on the root class. Any nested model type referenced in a field is auto-mocked via a private `_$mockXxx()` helper emitted into the same `.mock.g.dart` file — no need to annotate every model in a deep graph.

```dart
@Mockable()
class Claim {
  const Claim({required this.policy, required this.docs});
  final Policy policy;        // not annotated — auto-mocked
  final List<Doc> docs;       // not annotated — auto-mocked
}

class Policy {
  const Policy({required this.number});
  final String number;
}

class Doc {
  const Doc({required this.title});
  final String title;
}
```

Generated:

```dart
extension ClaimMock on Claim {
  static Claim mock() => Claim(
        policy: _$mockPolicy(),
        docs: List.generate(3, (_) => _$mockDoc()),
      );
  // ...
}

Policy _$mockPolicy() => Policy(number: MockFaker.word());
Doc _$mockDoc() => Doc(title: MockFaker.sentence());
```

Resolution priority for a nested type: `@Mockable()`-annotated → hand-written `XxxMock` extension → auto-generated `_$mockXxx()` helper. Helpers are dedup'd per file; cycles are handled the same way as the root case.

## Pairs naturally with

- [`json_serializable`](https://pub.dev/packages/json_serializable) — your existing `@JsonSerializable()` DTOs work as-is; just add `@Mockable()`.
- [`freezed`](https://pub.dev/packages/freezed) — Freezed redirecting factories and `@Default(...)` are recognized.
- [`skeletonizer`](https://pub.dev/packages/skeletonizer) — `mockData: UserMock.mockList(8)` produces realistic-width skeletons.

## Edge cases

- **Cyclic references** (`A` → `B` → `A`) — the generator detects cycles and falls back to `.empty()` if available, else `null` for nullable fields, else the unnamed constructor with no args.
- **Generic classes** (`Class<T>`) — skipped in v1 with a log message.
- **Manual override** — if a hand-written `extension XxxMock on Xxx` already exists in the same library, the generator skips that class.
- **Custom `@JsonKey(fromJson:)`** — emits `null` (or a TODO marker) so you can fill in the right value manually.
- **`@MockableIgnore()`** — apply on a field to opt out of mock generation for that one field.

## License

MIT
