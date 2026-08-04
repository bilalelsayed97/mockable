// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint, unused_import
import 'package:mockable/mockable.dart';
import 'package:mockable_gen_example/company.dart';
import 'package:mockable_gen_example/models/department.dart';
import 'package:mockable_gen_example/models/member.dart';
import 'package:mockable_gen_example/models/team.dart';

extension CompanyMock on Company {
  static Company mock() => Company(
        name: MockFaker.name(),
        headquarters: MockFaker.word(),
        departments: List.generate(3, (_) => _$mockDepartment()),
      );

  static List<Company> mockList([int count = 10]) =>
      List.generate(count, (_) => CompanyMock.mock());
}

Department _$mockDepartment() => Department(
      title: MockFaker.sentence(),
      primaryTeam: _$mockTeam(),
      teamsByRegion: {MockFaker.word(): _$mockTeam()},
    );

Team _$mockTeam() => Team(
      name: MockFaker.name(),
      lead: _$mockMember(),
      members: List.generate(3, (_) => _$mockMember()),
    );

Member _$mockMember() => Member(
      id: MockFaker.id(),
      fullName: MockFaker.name(),
      email: MockFaker.email(),
      role: MemberRole.engineer,
      yearsExperience: MockFaker.integer(),
    );
