import 'package:mockable/mockable.dart';

// Import the generated standalone library to bring `CompanyMock` into scope.
import 'package:mockable_gen_example/company.mock.dart';

void main() {
  // Make output reproducible — drop this for varied data.
  MockFaker.seed(2026);

  final company = CompanyMock.mock();

  print('Company: $company\n');
  for (final department in company.departments) {
    print('  • $department');
    print('     primary team lead: ${department.primaryTeam.lead}');
    for (final member in department.primaryTeam.members) {
      print('       - $member');
    }
  }

  print('\nList of 3 companies:');
  for (final c in CompanyMock.mockList(3)) {
    print('  - $c');
  }
}
