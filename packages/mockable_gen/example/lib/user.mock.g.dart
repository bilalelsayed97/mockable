// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint

part of 'user.dart';

// **************************************************************************
// MockGenerator
// **************************************************************************

extension UserMock on User {
  static User mock() => User(
        id: MockFaker.id(),
        email: MockFaker.email(),
        fullName: MockFaker.name(),
        age: MockFaker.integer(),
        tags: List.generate(3, (_) => MockFaker.word()),
      );

  static List<User> mockList([int count = 10]) =>
      List.generate(count, (_) => UserMock.mock());
}
