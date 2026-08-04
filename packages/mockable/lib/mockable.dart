/// Annotation and runtime helpers for `package:mockable_gen`.
///
/// See README for usage. Add `@Mockable()` to a class, then run
/// `dart run build_runner build` to generate a sibling `xxx.mock.dart`
/// library with `XxxMock.mock()` and `XxxMock.mockList(count)` factories.
library;

export 'src/mock_annotation.dart';
export 'src/mock_faker.dart';
