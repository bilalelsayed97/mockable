## 0.1.0

- Initial release.
- `build_runner` generator emits `xxx.mock.g.dart` part files for classes
  annotated with `@Mockable()` from `package:mockable`.
- Field-name heuristics for `email` / `phone` / `name` / `id` / `url` /
  `description` / `date` / `address` / `code` / currency-shaped fields.
- Type-based fallback for `String`, `int`, `double`, `bool`, `DateTime`,
  enums, `List<T>`, `Map<K, V>`, and nested `@Mockable`-annotated models.
- Cycle detection with fallback to `.empty()` factories when present.
- Skips classes whose `XxxMock` extension is already hand-written.
- Honors `@MockableIgnore()` on parameters and fields (initializing-formal aware).
- Generic classes and missing constructors are skipped with a log message.
