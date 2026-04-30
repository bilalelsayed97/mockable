import 'package:mockable/mockable.dart';

part 'user.mock.g.dart';

@Mockable()
class User {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.age,
    required this.tags,
  });

  final String id;
  final String email;
  final String fullName;
  final int age;
  final List<String> tags;

  @override
  String toString() =>
      'User(id: $id, email: $email, name: $fullName, age: $age, tags: $tags)';
}
