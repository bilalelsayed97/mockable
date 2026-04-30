# mockable_gen example

A minimal end-to-end consumer of `mockable` + `mockable_gen`.

```bash
dart pub get
dart run build_runner build
dart run bin/main.dart
```

The first command resolves dependencies; the second generates
`lib/user.mock.g.dart`; the third prints sample mock instances using the
generated factories.
