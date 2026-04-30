## 0.1.0

- Initial release.
- `@Mockable()` annotation marks a class for mock generation by `mockable_gen`.
- `@MockableIgnore()` annotation skips mock generation for a single field.
- `MockFaker` static façade over `package:faker` with helpers covering common
  field shapes (email, phone, name, id, url, dates, currency, etc.) plus a
  `seed()` for deterministic output.
