import 'package:mockable/mockable.dart';

import 'models/department.dart';

/// Top of a four-level tree (Company → Department → Team → Member) whose models
/// live in separate files. Only THIS class is annotated — running
/// `dart run build_runner build` generates `company.mock.dart`, a standalone
/// library that imports every nested file and mocks the whole tree.
@Mockable()
class Company {
  const Company({
    required this.name,
    required this.headquarters,
    required this.departments,
  });

  final String name;
  final String headquarters;
  final List<Department> departments;

  @override
  String toString() =>
      'Company($name @ $headquarters, ${departments.length} departments)';
}
