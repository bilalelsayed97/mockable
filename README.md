# mockable + mockable_gen

Auto-generate `XxxMock.mock()` and `XxxMock.mockList(count)` factories for any Dart class via build_runner. Designed for [Skeletonizer](https://pub.dev/packages/skeletonizer) loading screens, widget tests, and offline previews.

| Package | Role |
|---|---|
| [`mockable`](packages/mockable) | Runtime annotation (`@Mockable()`) + `MockFaker` helpers. |
| [`mockable_gen`](packages/mockable_gen) | `build_runner` generator. Dev-dep only. |

## Quick start

```yaml
# pubspec.yaml
dependencies:
  mockable: ^0.1.0

dev_dependencies:
  mockable_gen: ^0.1.0
  build_runner: ^2.4.13
```

```dart
// user.dart
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

```bash
dart run build_runner build
```

```dart
// Anywhere in your app:
final users = UserMock.mockList(8);
```

See [`packages/mockable_gen/example`](packages/mockable_gen/example) for a runnable demo.

## Contributing

This repo is a [melos](https://pub.dev/packages/melos) workspace.

```bash
dart pub global activate melos
melos bootstrap
melos run analyze
melos run test
```

## License

[MIT](LICENSE)
