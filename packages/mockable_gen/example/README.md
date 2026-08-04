# mockable_gen example

An end-to-end consumer of `mockable` + `mockable_gen` that shows **deep,
cross-file nesting from a single annotation**. Only `lib/company.dart` is
annotated; the `Department → Team → Member` models live in separate files under
`lib/models/` and are mocked automatically.

```bash
dart pub get
dart run build_runner build
dart run bin/main.dart
```

The first command resolves dependencies; the second generates the standalone
`lib/company.mock.dart` library (importing every nested model file); the third
prints a fully-populated four-level mock tree.
