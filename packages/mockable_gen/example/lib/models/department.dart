import 'team.dart';

/// Level 1 model — declared with a redirecting factory constructor to mimic a
/// Freezed class, and nesting [Team] through both a field and a `Map` value.
abstract class Department {
  const factory Department({
    required String title,
    required Team primaryTeam,
    required Map<String, Team> teamsByRegion,
  }) = _Department;

  String get title;
  Team get primaryTeam;
  Map<String, Team> get teamsByRegion;
}

class _Department implements Department {
  const _Department({
    required this.title,
    required this.primaryTeam,
    required this.teamsByRegion,
  });

  @override
  final String title;
  @override
  final Team primaryTeam;
  @override
  final Map<String, Team> teamsByRegion;

  @override
  String toString() =>
      'Department($title, primary=${primaryTeam.name}, regions=${teamsByRegion.keys.toList()})';
}
