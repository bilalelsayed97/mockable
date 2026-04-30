# mockable

[![pub package](https://img.shields.io/pub/v/mockable.svg)](https://pub.dev/packages/mockable)

Annotation and runtime helpers for [`package:mockable_gen`](https://pub.dev/packages/mockable_gen) — a `build_runner` generator that emits `XxxMock.mock()` and `XxxMock.mockList(count)` factories for your Dart classes.

Useful for [Skeletonizer](https://pub.dev/packages/skeletonizer) loading screens, widget tests, offline previews, and anywhere else you'd otherwise hand-write `.empty()` factories.

## Install

```yaml
dependencies:
  mockable: ^0.1.0

dev_dependencies:
  mockable_gen: ^0.1.0
  build_runner: ^2.4.13
```

## Usage

Annotate any class with `@Mockable()` and add a `part` directive:

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

Run the generator:

```bash
dart run build_runner build
```

A sibling `user.mock.g.dart` appears with:

```dart
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

Use it anywhere — for example with Skeletonizer:

```dart
Skeletonizer(
  enabled: isLoading,
  child: ListView(
    children: (isLoading ? UserMock.mockList(8) : users)
        .map(UserCard.new)
        .toList(),
  ),
)
```

## API

### `@Mockable()`
Marks a class for generation. Optional parameters:
- `defaultCount` (default `10`) — used as the default for `mockList([int count = N])`.
- `seed` — when set, makes generated mocks deterministic for this class.
- `locale` — locale hint forwarded to faker.

### `@MockableIgnore()`
Place on a field (or initializing-formal parameter) to skip mock generation
for that field. The generator emits `null` for it instead.

```dart
@Mockable()
class Order {
  const Order({required this.id, this.complex});
  final String id;
  @MockableIgnore() final ComplexThing? complex;
}
```

### `MockFaker`
Static helpers used inside generated code. You can also call them directly
when hand-writing mocks. See the [example](example/mockable_example.dart) for
the full surface.

```dart
MockFaker.email();        // 'foo.bar@example.com'
MockFaker.name();         // 'John Doe'
MockFaker.phone(locale: 'sa'); // '+9665XXXXXXXX'
MockFaker.integer(min: 18, max: 80);
MockFaker.dateString();   // 'YYYY-MM-DD'
MockFaker.seed(42);       // deterministic from this point
```

## Field-name heuristics

The generator picks a faker helper based on the parameter name:

| Name pattern | Helper |
|---|---|
| `email`, `mail` | `MockFaker.email()` |
| `phone`, `mobile`, `cell` | `MockFaker.phone()` |
| `name`, `firstName`, `lastName`, `fullName` | `MockFaker.name()` |
| `id`, `*Id` (String) | `MockFaker.id()` |
| `uuid`, `guid` | `MockFaker.uuid()` |
| `url`, `link`, `image` | `MockFaker.url()` |
| `description`, `title`, `note`, `comment`, `message` | `MockFaker.sentence()` |
| `date`, `createdAt`, `updatedAt` (String) | `MockFaker.dateString()` |
| `address`, `city`, `country` | `MockFaker.address()` etc. |
| `code`, `*Code` (String) | `MockFaker.shortCode()` |
| `amount`, `price`, `total`, `balance`, `cost` (numeric) | `MockFaker.currency()` |

Anything that doesn't match falls back to a type-based default.

## See also

- [`mockable_gen`](https://pub.dev/packages/mockable_gen) — the build_runner generator that consumes this package.
- [Skeletonizer](https://pub.dev/packages/skeletonizer) — the loading-skeleton widget that pairs naturally with generated mocks.

## License

MIT
