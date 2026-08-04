/// A leaf model (level 3) — plain class with primitives and an enum.
enum MemberRole { unknown, engineer, manager, designer }

class Member {
  const Member({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.yearsExperience,
  });

  final String id;
  final String fullName;
  final String email;
  final MemberRole role;
  final int yearsExperience;

  @override
  String toString() =>
      'Member($fullName <$email>, $role, ${yearsExperience}y, id=$id)';
}
