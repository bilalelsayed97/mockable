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

part 'user.mock.g.dart';

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
          'pkg|lib/user.mock.g.dart': decodedMatches(allOf(
            contains('extension UserMock on User'),
            contains('static User mock() => User('),
            contains('id: MockFaker.id()'),
            contains('email: MockFaker.email()'),
            contains('fullName: MockFaker.name()'),
            contains('static List<User> mockList([int count = 10])'),
          )),
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

part 'post.mock.g.dart';

@Mockable(defaultCount: 5)
class Post {
  const Post({required this.title});
  final String title;
}
''',
        },
        outputs: {
          'pkg|lib/post.mock.g.dart':
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

part 'widget_data.mock.g.dart';

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
          'pkg|lib/widget_data.mock.g.dart': decodedMatches(allOf(
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

part 'order.mock.g.dart';

@Mockable()
class Order {
  const Order({required this.id, this.opaque});
  final String id;
  @MockableIgnore() final String? opaque;
}
''',
        },
        outputs: {
          'pkg|lib/order.mock.g.dart': decodedMatches(allOf(
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

part 'tags.mock.g.dart';

@Mockable()
class Tagged {
  const Tagged({required this.tags});
  final List<String> tags;
}
''',
        },
        outputs: {
          'pkg|lib/tags.mock.g.dart': decodedMatches(
            contains('tags: List.generate(3, (_) => MockFaker.word())'),
          ),
        },
      );
    });

    test('lists of a nested mockable model call NestedMock.mockList(3)',
        () async {
      await testBuilder(
        mockBuilder(BuilderOptions.empty),
        const {
          'mockable|lib/mockable.dart': _mockDataStub,
          'pkg|lib/cart.dart': '''
import 'package:mockable/mockable.dart';

part 'cart.mock.g.dart';

@Mockable()
class Cart {
  const Cart({required this.items});
  final List<Item> items;
}

@Mockable()
class Item {
  const Item({required this.sku});
  final String sku;
}
''',
        },
        outputs: {
          'pkg|lib/cart.mock.g.dart': decodedMatches(allOf(
            contains('items: ItemMock.mockList(3)'),
            contains('extension ItemMock on Item'),
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

part 'claim.mock.g.dart';

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
          'pkg|lib/claim.mock.g.dart': decodedMatches(allOf(
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

part 'claim_with_docs.mock.g.dart';

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
          'pkg|lib/claim_with_docs.mock.g.dart': decodedMatches(allOf(
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

part 'deep.mock.g.dart';

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
          'pkg|lib/deep.mock.g.dart': decodedMatches(allOf(
            contains(r'b: _$mockB()'),
            contains(r'B _$mockB() => B('),
            contains(r'c: _$mockC()'),
            contains(r'C _$mockC() => C('),
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

part 'dedup.mock.g.dart';

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
          'pkg|lib/dedup.mock.g.dart': decodedMatches(predicate<String>((src) {
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

    test('auto-mock prefers a hand-written XxxMock extension over a helper',
        () async {
      await testBuilder(
        mockBuilder(BuilderOptions.empty),
        const {
          'mockable|lib/mockable.dart': _mockDataStub,
          'pkg|lib/handwritten_nested.dart': '''
import 'package:mockable/mockable.dart';

part 'handwritten_nested.mock.g.dart';

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
          'pkg|lib/handwritten_nested.mock.g.dart':
              decodedMatches(predicate<String>((src) {
            return src.contains('inner: InnerMock.mock()') &&
                !src.contains(r'_$mockInner');
          }, 'uses hand-written InnerMock and emits no _\$mockInner helper')),
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

part 'cycle.mock.g.dart';

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
          'pkg|lib/cycle.mock.g.dart':
              decodedMatches(predicate<String>((src) {
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
