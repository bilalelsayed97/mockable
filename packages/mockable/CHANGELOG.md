## 0.2.2

- Republish in lockstep with `mockable_gen 0.2.2`. No API changes.

## 0.2.1

- Republish in lockstep with `mockable_gen 0.2.1`. No API changes; this
  version exists so `mockable` and `mockable_gen` share a version number
  going forward.

## 0.2.0

- Version sync with `mockable_gen` 0.2.0 (which adds auto-mocking of
  unannotated nested model types). No functional changes in this package —
  the runtime/annotation surface (`@Mockable()`, `@MockableIgnore()`,
  `MockFaker`) is unchanged from 0.1.0.

## 0.1.0

- Initial release.
- `@Mockable()` annotation marks a class for mock generation by `mockable_gen`.
- `@MockableIgnore()` annotation skips mock generation for a single field.
- `MockFaker` static façade over `package:faker` with helpers covering common
  field shapes (email, phone, name, id, url, dates, currency, etc.) plus a
  `seed()` for deterministic output.
