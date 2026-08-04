import 'member.dart';

/// Level 2 model — nests [Member] both directly and inside a list.
class Team {
  const Team({
    required this.name,
    required this.lead,
    required this.members,
  });

  final String name;
  final Member lead;
  final List<Member> members;

  @override
  String toString() =>
      'Team($name, lead=${lead.fullName}, members=${members.length})';
}
