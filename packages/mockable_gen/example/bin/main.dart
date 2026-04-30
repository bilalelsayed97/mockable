import 'package:mockable/mockable.dart';
import 'package:mockable_gen_example/user.dart';

void main() {
  // Make output reproducible — drop this for varied data.
  MockFaker.seed(2026);

  print('Single mock:');
  print(UserMock.mock());

  print('\nList of 5 mocks:');
  for (final user in UserMock.mockList(5)) {
    print(user);
  }
}
