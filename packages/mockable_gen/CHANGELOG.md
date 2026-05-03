## 0.2.2

- Raise `analyzer` lower bound to `>=8.0.0`. The generator uses the unified
  Element API (`LibraryElement.extensions`, `ConstructorElement.formalParameters`,
  `FormalParameterElement`, `Metadata.annotations`, `EnumElement.constants`),
  which only exists on analyzer 8+. The previous `>=7.0.0` floor allowed pub
  to resolve analyzer 7.x and fail at compile time.
- Released in lockstep with `mockable 0.2.2`.

## 0.2.1

- Fix `mockable` dependency constraint: now requires `mockable: ^0.2.1`
  (0.2.0 was published with a stale `^0.1.0` constraint, which prevented
  consumers from depending on the latest `mockable` alongside `mockable_gen`).
- Released in lockstep with `mockable 0.2.1`.

## 0.2.0

- Auto-mock unannotated nested model types. When an `@Mockable()` class has a
  field whose type is itself a model class without `@Mockable()` and without a
  hand-written `XxxMock` extension, the generator now emits a private
  `_$mockXxx()` helper in the same `.mock.g.dart` file and references it from
  the parent's factory — instead of emitting a broken `XxxMock.mock()` call.
- Helpers are dedup'd by type name within each output file, so referencing the
  same nested type from multiple fields produces a single helper.
- Recursion is depth-unbounded but cycle-safe: A → B → A reuses the existing
  cycle fallback (`.empty()` constructor if present, else `null` for nullable
  fields, else a default constructor call).
- Resolution priority for nested model types: `@Mockable`-annotated > existing
  `XxxMock` extension > generated `_$mockXxx()` helper.

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
