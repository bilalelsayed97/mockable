// Demonstrates the MockFaker runtime helpers. The annotation + generated
// extensions are demonstrated in the mockable_gen package's example.

import 'package:mockable/mockable.dart';

void main() {
  // Deterministic for reproducibility — drop this for varied output.
  MockFaker.seed(2026);

  print('email:      ${MockFaker.email()}');
  print('name:       ${MockFaker.name()}');
  print('phone (us): ${MockFaker.phone()}');
  print('phone (sa): ${MockFaker.phone(locale: 'sa')}');
  print('id:         ${MockFaker.id()}');
  print('uuid:       ${MockFaker.uuid()}');
  print('shortCode:  ${MockFaker.shortCode()}');
  print('sentence:   ${MockFaker.sentence()}');
  print('integer:    ${MockFaker.integer(min: 18, max: 80)}');
  print('currency:   ${MockFaker.currency()}');
  print('dateString: ${MockFaker.dateString()}');
}
