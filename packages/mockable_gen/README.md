# mockable_gen

[![pub package](https://img.shields.io/pub/v/mockable_gen.svg)](https://pub.dev/packages/mockable_gen)

`build_runner` generator for [`package:mockable`](https://pub.dev/packages/mockable). Emits a standalone `xxx.mock.dart` library containing `XxxMock.mock()` and `XxxMock.mockList(count)` factories for every class annotated with `@Mockable()`. Annotate only the root class — the **entire nested model tree, across any number of files, is mocked automatically**.

## Install

```yaml
dependencies:
  mockable: ^0.4.0

dev_dependencies:
  mockable_gen: ^0.4.0
  build_runner: ^2.4.13
```

> **Upgrading from 0.2.x?** The generated output changed from a `part` file to a
> standalone library — see [Migrating from 0.2.x to 0.3.0](#migrating-from-02x-to-030).

## Usage

```dart
import 'package:mockable/mockable.dart';

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

Generated output — a standalone library `user.mock.dart`. Import it where you
need the mock:

```dart
import 'package:your_app/user.mock.dart';

final user = UserMock.mock();
```

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:mockable/mockable.dart';
import 'package:your_app/user.dart';

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

1. The generator picks a constructor (priority: unnamed generative or redirecting factory; otherwise the named ones that aren't `fromJson`/`empty`/`mock` and don't start with `_` — two or more of those trigger [union mode](#sealed--freezed-union-classes) with one mock per variant). Generative constructors on abstract classes are never used.
2. For each parameter, it picks a value via two layers:
    - **Field-name heuristics** — `email` → `MockFaker.email()`, `phone` → `MockFaker.phone()`, etc. (see the [mockable README](../mockable/README.md) for the full table).
    - **Type-based fallback** — `String` → `MockFaker.word()`, `int` → `MockFaker.integer()`, `bool` → `MockFaker.boolean()`, `DateTime` → `MockFaker.dateTime()`, enums → first non-`unknown`/`none` value, nested models → inlined `_$mockXxx()` helper, `List<T>`/`Map<K, V>` → populated with mocked elements.
3. Generates the `XxxMock` extension with `mock()` and `mockList([int count = N])`, followed by a private `_$mockXxx()` helper for every nested type it reached.

## Deep nesting across files — no annotation needed

You only need `@Mockable()` on the **root** class. Every nested model reachable from it — at any depth, and **however many files the types are spread across** — is inlined via a private `_$mockXxx()` helper in the generated library. Because the output is a real library (not a `part of` file), it emits the `import` directives those nested types need, so a four-level `Company → Department → Team → Member` graph in four separate files fully mocks from one annotation. See [`example/`](example/).

```dart
// company.dart — the only annotated file
@Mockable()
class Company {
  const Company({required this.departments});
  final List<Department> departments; // Department, Team, Member all in
                                       // separate, unannotated files
}
```

Generated `company.mock.dart` (abridged):

```dart
import 'package:mockable/mockable.dart';
import 'package:your_app/company.dart';
import 'package:your_app/models/department.dart';
import 'package:your_app/models/team.dart';
import 'package:your_app/models/member.dart';

extension CompanyMock on Company {
  static Company mock() =>
      Company(departments: List.generate(3, (_) => _$mockDepartment()));
  // ...
}

Department _$mockDepartment() => Department(
      primaryTeam: _$mockTeam(),
      teamsByRegion: {MockFaker.word(): _$mockTeam()},
      /* ... */
    );
Team _$mockTeam() => Team(lead: _$mockMember(), members: List.generate(3, (_) => _$mockMember()), /* ... */);
Member _$mockMember() => Member(email: MockFaker.email(), /* ... */);
```

Nested types are **always inlined**, even if they are themselves `@Mockable()` or have a hand-written `XxxMock` extension, so every generated file is self-contained. A hand-written extension is used only as a fallback when a nested type has no usable constructor. Helpers are dedup'd per file; two same-named types from different files are disambiguated with `as _iN` import prefixes; cycles fall back the same way as the root case.

## Abstract classes

An abstract class generates normally as long as it exposes a **factory
constructor** — including Freezed-style redirecting factories
(`factory Foo(...) = _Foo`). An abstract class with only generative
constructors (or none at all, e.g. a pure interface) cannot be instantiated,
so:

- annotated directly, it is skipped with a
  `// mockable_gen: skipped Foo — abstract class with no factory constructor`
  comment instead of emitting uncompilable code;
- reached as a nested type, the generator defers to a hand-written
  `FooMock` extension in the same library if one exists, else emits a
  helper that throws `UnimplementedError` so the gap is explicit.

## Sealed / Freezed union classes

A class whose only public constructors are **two or more named factories** —
the shape of a Freezed sealed state class — gets one mock method **per
variant**, plus `mock()`/`mockList()` delegating to the *richest* variant
(most parameters; ties go to the first declared):

```dart
@freezed
sealed class LanguageSelectorState with _$LanguageSelectorState {
  const factory LanguageSelectorState.initial() = _Initial;
  const factory LanguageSelectorState.loaded({
    required List<LanguageItem> languages,
    required List<LanguageItem> filteredLanguages,
    required String selectedLanguage,
    required String searchQuery,
  }) = _Loaded;
  const factory LanguageSelectorState.changing() = _Changing;
  const factory LanguageSelectorState.error({required String message}) = _Error;
}
```

generates:

```dart
extension LanguageSelectorStateMock on LanguageSelectorState {
  static LanguageSelectorState mockInitial() => LanguageSelectorState.initial();
  static LanguageSelectorState mockLoaded() => LanguageSelectorState.loaded(
        languages: List.generate(3, (_) => _$mockLanguageItem()),
        filteredLanguages: List.generate(3, (_) => _$mockLanguageItem()),
        selectedLanguage: MockFaker.word(),
        searchQuery: MockFaker.word(),
      );
  static LanguageSelectorState mockChanging() =>
      LanguageSelectorState.changing();
  static LanguageSelectorState mockError() =>
      LanguageSelectorState.error(message: MockFaker.sentence());

  static LanguageSelectorState mock() => mockLoaded(); // richest variant

  static List<LanguageSelectorState> mockList([int count = 10]) =>
      List.generate(count, (_) => LanguageSelectorStateMock.mock());
}
```

Details:

- A class with a usable **unnamed** constructor keeps the classic
  single-`mock()` output, even if it also has named factories.
- `fromJson`, `empty`, `mock`, `mockList` and `_`-private constructors (like
  Freezed's `const Foo._()`) are never treated as variants.
- When a union appears as a **nested field** of another mocked class, its
  `_$mockXxx()` helper uses the richest variant.
- If a variant's method name would collide with `mock()`/`mockList()` (e.g. a
  variant named `list`), it is renamed with a `Variant` suffix
  (`mockListVariant()`) and a comment explains the rename.

## Pairs naturally with

- [`json_serializable`](https://pub.dev/packages/json_serializable) — your existing `@JsonSerializable()` DTOs work as-is; just add `@Mockable()`.
- [`freezed`](https://pub.dev/packages/freezed) — redirecting factories and `@Default(...)` are recognized, and sealed unions get [one mock per variant](#sealed--freezed-union-classes).
- [`skeletonizer`](https://pub.dev/packages/skeletonizer) — `mockData: UserMock.mockList(8)` produces realistic-width skeletons.

## Edge cases

- **Cyclic references** (`A` → `B` → `A`) — the generator detects cycles and falls back to `.empty()` if available, else `null` for nullable fields, else the unnamed constructor with no args.
- **Generic classes** (`Class<T>`) — skipped in v1 with a log message.
- **Abstract classes without a factory constructor** — skipped with a comment (root) or deferred to a hand-written extension / throwing helper (nested); see [Abstract classes](#abstract-classes).
- **Manual override** — if a hand-written `extension XxxMock on Xxx` already exists in the same library, the generator skips that class.
- **Custom `@JsonKey(fromJson:)`** — emits `null` (or a TODO marker) so you can fill in the right value manually.
- **`@MockableIgnore()`** — apply on a field to opt out of mock generation for that one field.

## Migrating from 0.2.x to 0.3.0

0.3.0 changes the generated output from a `part 'xxx.mock.g.dart';` file to a
**standalone `xxx.mock.dart` library**. This is what makes deep, cross-file
nesting work from a single annotation (a `part` file can't declare its own
imports, so it could never reference nested types living in other files). The
call-site API — `XxxMock.mock()` and `XxxMock.mockList([count])` — is unchanged.

### Automated

After bumping both dependencies to `^0.3.0`, run the bundled migration command
from your project root:

```bash
dart run mockable_gen:migrate            # rewrites in place
dart run mockable_gen:migrate --dry-run  # preview only, changes nothing
```

It removes every `part 'xxx.mock.g.dart';` directive and deletes the stale
`*.mock.g.dart` files. Then regenerate and wire up the call sites:

```bash
dart run build_runner build              # writes xxx.mock.dart
```

Add `import 'xxx.mock.dart';` wherever you call `XxxMock.mock()` — the build
errors point you to each spot. (The command intentionally does *not* touch call
sites, since inserting the right import is best left to you / `dart fix`.)

### Manual

The same steps by hand:

1. Bump both dependencies to `^0.3.0` (`mockable` and `mockable_gen`).
2. Remove every `part 'xxx.mock.g.dart';` directive from your annotated files.
3. Delete the stale generated files:
   ```bash
   find . -name '*.mock.g.dart' -delete
   ```
4. Regenerate — the builder now writes `xxx.mock.dart` instead:
   ```bash
   dart run build_runner build
   ```
5. Add `import 'xxx.mock.dart';` wherever you call `XxxMock.mock()` /
   `XxxMock.mockList()`.

Before / after:

```dart
// user.dart
  import 'package:mockable/mockable.dart';
- part 'user.mock.g.dart';

  @Mockable()
  class User { /* ... */ }
```

```dart
// wherever you build mocks (e.g. a test or a Skeletonizer screen)
+ import 'package:your_app/user.mock.dart';

  final users = UserMock.mockList(5); // same API as before
```

Bonus after upgrading: nested models spread across multiple files no longer need
their own `@Mockable()`. Annotate only the root class and the whole tree is
mocked — see [Deep nesting across files](#deep-nesting-across-files--no-annotation-needed).

## License

MIT
