import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:mockable_gen/builder.dart';
import 'package:test/test.dart';

void main() {
  group('MockGenerator', () {
    test('generates mock + mockList for a plain JsonSerializable-style class',
        () async {
      await testBuilder(
        mockBuilder(BuilderOptions.empty),
        const {
          'mockable|lib/mockable.dart': _mockDataStub,
          'pkg|lib/user.dart': '''
import 'package:mockable/mockable.dart';

@Mockable()
class User {
  const User({required this.id, required this.email, required this.fullName});

  final String id;
  final String email;
  final String fullName;
}
''',
        },
        outputs: {
          'pkg|lib/user.mock.dart': decodedMatches(allOf([
            // Standalone library, not a part file.
            isNot(contains('part of')),
            contains("import 'package:mockable/mockable.dart';"),
            contains("import 'package:pkg/user.dart';"),
            contains('extension UserMock on User'),
            contains('static User mock()'),
            contains('id: MockFaker.id()'),
            contains('email: MockFaker.email()'),
            contains('fullName: MockFaker.name()'),
            contains('static List<User> mockList([int count = 10])'),
          ])),
        },
      );
    });

    test('respects defaultCount on the annotation', () async {
      await testBuilder(
        mockBuilder(BuilderOptions.empty),
        const {
          'mockable|lib/mockable.dart': _mockDataStub,
          'pkg|lib/post.dart': '''
import 'package:mockable/mockable.dart';

@Mockable(defaultCount: 5)
class Post {
  const Post({required this.title});
  final String title;
}
''',
        },
        outputs: {
          'pkg|lib/post.mock.dart':
              decodedMatches(contains('mockList([int count = 5])')),
        },
      );
    });

    test('uses type-based fallbacks when no name heuristic matches', () async {
      await testBuilder(
        mockBuilder(BuilderOptions.empty),
        const {
          'mockable|lib/mockable.dart': _mockDataStub,
          'pkg|lib/widget_data.dart': '''
import 'package:mockable/mockable.dart';

@Mockable()
class WidgetData {
  const WidgetData({required this.label, required this.count, required this.active});
  final String label;
  final int count;
  final bool active;
}
''',
        },
        outputs: {
          'pkg|lib/widget_data.mock.dart': decodedMatches(allOf(
            contains('label: MockFaker.word()'),
            contains('count: MockFaker.integer()'),
            contains('active: MockFaker.boolean()'),
          )),
        },
      );
    });

    test('emits null for fields tagged with @MockableIgnore', () async {
      await testBuilder(
        mockBuilder(BuilderOptions.empty),
        const {
          'mockable|lib/mockable.dart': _mockDataStub,
          'pkg|lib/order.dart': '''
import 'package:mockable/mockable.dart';

@Mockable()
class Order {
  const Order({required this.id, this.opaque});
  final String id;
  @MockableIgnore() final String? opaque;
}
''',
        },
        outputs: {
          'pkg|lib/order.mock.dart': decodedMatches(allOf(
            contains('id: MockFaker.id()'),
            contains('opaque: null'),
          )),
        },
      );
    });

    test('skips a class whose XxxMock extension already exists', () async {
      await testBuilder(
        mockBuilder(BuilderOptions.empty),
        const {
          'mockable|lib/mockable.dart': _mockDataStub,
          'pkg|lib/handcrafted.dart': '''
import 'package:mockable/mockable.dart';

@Mockable()
class Handcrafted {
  const Handcrafted({required this.label});
  final String label;
}

extension HandcraftedMock on Handcrafted {
  static Handcrafted mock() => const Handcrafted(label: 'fixed');
}
''',
        },
        outputs: const {},
      );
    });

    test('lists of a primitive use the type fallback inside List.generate',
        () async {
      await testBuilder(
        mockBuilder(BuilderOptions.empty),
        const {
          'mockable|lib/mockable.dart': _mockDataStub,
          'pkg|lib/tags.dart': '''
import 'package:mockable/mockable.dart';

@Mockable()
class Tagged {
  const Tagged({required this.tags});
  final List<String> tags;
}
''',
        },
        outputs: {
          'pkg|lib/tags.mock.dart': decodedMatches(
            contains('tags: List.generate(3, (_) => MockFaker.word())'),
          ),
        },
      );
    });

    test('lists of a nested model inline a helper via List.generate', () async {
      await testBuilder(
        mockBuilder(BuilderOptions.empty),
        const {
          'mockable|lib/mockable.dart': _mockDataStub,
          'pkg|lib/cart.dart': '''
import 'package:mockable/mockable.dart';

@Mockable()
class Cart {
  const Cart({required this.items});
  final List<Item> items;
}

class Item {
  const Item({required this.sku});
  final String sku;
}
''',
        },
        outputs: {
          'pkg|lib/cart.mock.dart': decodedMatches(allOf(
            contains(r'items: List.generate(3, (_) => _$mockItem())'),
            contains(r'Item _$mockItem() => Item('),
          )),
        },
      );
    });

    test('auto-mocks an unannotated nested model via _\$mockX helper',
        () async {
      await testBuilder(
        mockBuilder(BuilderOptions.empty),
        const {
          'mockable|lib/mockable.dart': _mockDataStub,
          'pkg|lib/claim.dart': '''
import 'package:mockable/mockable.dart';

@Mockable()
class Claim {
  const Claim({required this.policy});
  final Policy policy;
}

class Policy {
  const Policy({required this.number});
  final String number;
}
''',
        },
        outputs: {
          'pkg|lib/claim.mock.dart': decodedMatches(allOf(
            contains(r'policy: _$mockPolicy()'),
            contains(r'Policy _$mockPolicy() => Policy('),
            contains('number: MockFaker.word()'),
          )),
        },
      );
    });

    test('auto-mocks unannotated nested types inside lists', () async {
      await testBuilder(
        mockBuilder(BuilderOptions.empty),
        const {
          'mockable|lib/mockable.dart': _mockDataStub,
          'pkg|lib/claim_with_docs.dart': '''
import 'package:mockable/mockable.dart';

@Mockable()
class ClaimWithDocs {
  const ClaimWithDocs({required this.docs});
  final List<Doc> docs;
}

class Doc {
  const Doc({required this.title});
  final String title;
}
''',
        },
        outputs: {
          'pkg|lib/claim_with_docs.mock.dart': decodedMatches(allOf(
            contains(r'docs: List.generate(3, (_) => _$mockDoc())'),
            contains(r'Doc _$mockDoc() => Doc('),
            contains('title: MockFaker.sentence()'),
          )),
        },
      );
    });

    test('auto-mock recurses through multiple unannotated levels', () async {
      await testBuilder(
        mockBuilder(BuilderOptions.empty),
        const {
          'mockable|lib/mockable.dart': _mockDataStub,
          'pkg|lib/deep.dart': '''
import 'package:mockable/mockable.dart';

@Mockable()
class A {
  const A({required this.b});
  final B b;
}

class B {
  const B({required this.c});
  final C c;
}

class C {
  const C({required this.value});
  final String value;
}
''',
        },
        outputs: {
          'pkg|lib/deep.mock.dart': decodedMatches(allOf(
            contains(r'b: _$mockB()'),
            contains(r'B _$mockB() => B('),
            contains(r'c: _$mockC()'),
            contains(r'C _$mockC() => C('),
          )),
        },
      );
    });

    test('deeply nests across separate files from a single annotation',
        () async {
      // The real-world case: A -> B -> C, each in its own file, only A
      // annotated. The standalone `.mock.dart` must import b.dart AND c.dart
      // and inline helpers all the way down.
      await testBuilder(
        mockBuilder(BuilderOptions.empty),
        const {
          'mockable|lib/mockable.dart': _mockDataStub,
          'pkg|lib/c.dart': '''
class C {
  const C({required this.value});
  final String value;
}
''',
          'pkg|lib/b.dart': '''
import 'c.dart';

class B {
  const B({required this.c});
  final C c;
}
''',
          'pkg|lib/a.dart': '''
import 'package:mockable/mockable.dart';
import 'b.dart';

@Mockable()
class A {
  const A({required this.b});
  final B b;
}
''',
        },
        outputs: {
          'pkg|lib/a.mock.dart': decodedMatches(allOf([
            contains("import 'package:pkg/b.dart';"),
            contains("import 'package:pkg/c.dart';"),
            contains(r'b: _$mockB()'),
            contains(r'B _$mockB() => B('),
            contains(r'c: _$mockC()'),
            contains(r'C _$mockC() => C('),
            contains('value: MockFaker.word()'),
          ])),
        },
      );
    });

    test('resolves a redirecting-factory (Freezed-style) nested type', () async {
      await testBuilder(
        mockBuilder(BuilderOptions.empty),
        const {
          'mockable|lib/mockable.dart': _mockDataStub,
          'pkg|lib/frz_leaf.dart': '''
abstract class Leaf {
  const factory Leaf({required String label}) = _Leaf;
}

class _Leaf implements Leaf {
  const _Leaf({required this.label});
  final String label;
}
''',
          'pkg|lib/frz_root.dart': '''
import 'package:mockable/mockable.dart';
import 'frz_leaf.dart';

@Mockable()
class Root {
  const Root({required this.leaf});
  final Leaf leaf;
}
''',
        },
        outputs: {
          'pkg|lib/frz_root.mock.dart': decodedMatches(allOf(
            contains("import 'package:pkg/frz_leaf.dart';"),
            contains(r'leaf: _$mockLeaf()'),
            contains(r'Leaf _$mockLeaf() => Leaf('),
            contains('label: MockFaker.word()'),
          )),
        },
      );
    });

    test('recurses into Map values instead of emitting an empty map',
        () async {
      await testBuilder(
        mockBuilder(BuilderOptions.empty),
        const {
          'mockable|lib/mockable.dart': _mockDataStub,
          'pkg|lib/holder.dart': '''
import 'package:mockable/mockable.dart';

@Mockable()
class Holder {
  const Holder({required this.byId});
  final Map<String, Entry> byId;
}

class Entry {
  const Entry({required this.value});
  final String value;
}
''',
        },
        outputs: {
          'pkg|lib/holder.mock.dart': decodedMatches(allOf(
            isNot(contains('<String, Entry>{}')),
            contains(r'_$mockEntry()'),
            contains(r'Entry _$mockEntry() => Entry('),
          )),
        },
      );
    });

    test('disambiguates two same-named types from different files', () async {
      await testBuilder(
        mockBuilder(BuilderOptions.empty),
        const {
          'mockable|lib/mockable.dart': _mockDataStub,
          'pkg|lib/left.dart': '''
class Detail {
  const Detail({required this.left});
  final String left;
}
''',
          'pkg|lib/right.dart': '''
class Detail {
  const Detail({required this.right});
  final int right;
}
''',
          'pkg|lib/root.dart': '''
import 'package:mockable/mockable.dart';
import 'left.dart' as l;
import 'right.dart' as r;

@Mockable()
class Root {
  const Root({required this.a, required this.b});
  final l.Detail a;
  final r.Detail b;
}
''',
        },
        outputs: {
          'pkg|lib/root.mock.dart': decodedMatches(predicate<String>((src) {
            // One library keeps the plain name; the colliding one is prefixed.
            final leftPlain = src.contains("import 'package:pkg/left.dart';");
            final rightPrefixed =
                RegExp(r"import 'package:pkg/right\.dart' as _i\d+;")
                    .hasMatch(src);
            // Two distinct helpers, one per Detail type.
            final firstHelper = src.contains(r'_$mockDetail(');
            final secondHelper = src.contains(r'_$mockDetail$2(');
            return leftPlain && rightPrefixed && firstHelper && secondHelper;
          }, 'imports one Detail plainly, prefixes the other, and emits two helpers')),
        },
      );
    });

    test('always inlines a helper even when a hand-written extension exists',
        () async {
      // Per design: nested types are always inlined. A hand-written extension
      // on a nested type is only used as a fallback when the type has no
      // usable constructor (see next test).
      await testBuilder(
        mockBuilder(BuilderOptions.empty),
        const {
          'mockable|lib/mockable.dart': _mockDataStub,
          'pkg|lib/handwritten_nested.dart': '''
import 'package:mockable/mockable.dart';

@Mockable()
class Outer {
  const Outer({required this.inner});
  final Inner inner;
}

class Inner {
  const Inner({required this.label});
  final String label;
}

extension InnerMock on Inner {
  static Inner mock() => const Inner(label: 'fixed');
}
''',
        },
        outputs: {
          'pkg|lib/handwritten_nested.mock.dart':
              decodedMatches(predicate<String>((src) {
            return src.contains(r'inner: _$mockInner()') &&
                src.contains(r'Inner _$mockInner() => Inner(');
          }, 'inlines _\$mockInner rather than deferring to the hand-written extension')),
        },
      );
    });

    test('falls back to a hand-written extension when no constructor is usable',
        () async {
      await testBuilder(
        mockBuilder(BuilderOptions.empty),
        const {
          'mockable|lib/mockable.dart': _mockDataStub,
          'pkg|lib/no_ctor.dart': '''
import 'package:mockable/mockable.dart';

@Mockable()
class Wrapper {
  const Wrapper({required this.sealed});
  final Sealed sealed;
}

class Sealed {
  Sealed._();
}

extension SealedMock on Sealed {
  static Sealed mock() => Sealed._();
}
''',
        },
        outputs: {
          'pkg|lib/no_ctor.mock.dart': decodedMatches(allOf(
            contains(r'sealed: _$mockSealed()'),
            contains(r'Sealed _$mockSealed() => SealedMock.mock()'),
          )),
        },
      );
    });

    test('auto-mock dedupes when the same nested type appears twice',
        () async {
      await testBuilder(
        mockBuilder(BuilderOptions.empty),
        const {
          'mockable|lib/mockable.dart': _mockDataStub,
          'pkg|lib/dedup.dart': '''
import 'package:mockable/mockable.dart';

@Mockable()
class Pair {
  const Pair({required this.left, required this.right});
  final Side left;
  final Side right;
}

class Side {
  const Side({required this.label});
  final String label;
}
''',
        },
        outputs: {
          'pkg|lib/dedup.mock.dart': decodedMatches(predicate<String>((src) {
            final matches = RegExp(r'Side _\$mockSide\(\) => Side\(')
                .allMatches(src)
                .length;
            return matches == 1 &&
                src.contains(r'left: _$mockSide()') &&
                src.contains(r'right: _$mockSide()');
          }, 'emits exactly one _\$mockSide helper used by both fields')),
        },
      );
    });

    test('auto-mock handles A -> B -> A cycles via the cycle fallback',
        () async {
      await testBuilder(
        mockBuilder(BuilderOptions.empty),
        const {
          'mockable|lib/mockable.dart': _mockDataStub,
          'pkg|lib/cycle.dart': '''
import 'package:mockable/mockable.dart';

@Mockable()
class Node {
  const Node({required this.child});
  final Leaf child;
}

class Leaf {
  const Leaf({this.parent});
  final Leaf? parent;
}
''',
        },
        outputs: {
          'pkg|lib/cycle.mock.dart': decodedMatches(predicate<String>((src) {
            return src.contains(r'child: _$mockLeaf()') &&
                src.contains(r'Leaf _$mockLeaf() => Leaf(') &&
                src.contains('parent: null');
          }, 'emits Leaf helper with cycle fallback (null) for self-reference')),
        },
      );
    });
  });
}

const _mockDataStub = '''
library mockable;

class Mockable {
  final int defaultCount;
  final int? seed;
  final String? locale;
  const Mockable({this.defaultCount = 10, this.seed, this.locale});
}

class MockableIgnore {
  const MockableIgnore();
}

class MockFaker {
  static String word() => '';
  static String sentence() => '';
  static String name() => '';
  static String firstName() => '';
  static String lastName() => '';
  static String email() => '';
  static String phone({String? locale}) => '';
  static String url() => '';
  static String id() => '';
  static String uuid() => '';
  static String shortCode() => '';
  static String address() => '';
  static String city() => '';
  static String country() => '';
  static int integer({int min = 0, int max = 1000}) => 0;
  static double decimal({double min = 0, double max = 999, int scale = 2}) => 0;
  static double currency() => 0;
  static DateTime dateTime() => DateTime(2024);
  static String dateString() => '';
  static bool boolean() => false;
}
''';
