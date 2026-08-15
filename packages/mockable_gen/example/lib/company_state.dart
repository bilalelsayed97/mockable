import 'package:mockable/mockable.dart';

import 'company.dart';

/// A Freezed-style sealed union (hand-rolled here to keep the example
/// dependency-free). The generator emits one `mockXxx()` per variant —
/// `mockInitial()`, `mockLoaded()`, `mockError()` — plus `mock()` and
/// `mockList()` delegating to the richest variant (`loaded`).
@Mockable()
sealed class CompanyState {
  const factory CompanyState.initial() = _Initial;

  const factory CompanyState.loaded({
    required List<Company> companies,
    required String searchQuery,
  }) = _Loaded;

  const factory CompanyState.error({required String message}) = _Error;
}

class _Initial implements CompanyState {
  const _Initial();

  @override
  String toString() => 'CompanyState.initial()';
}

class _Loaded implements CompanyState {
  const _Loaded({required this.companies, required this.searchQuery});

  final List<Company> companies;
  final String searchQuery;

  @override
  String toString() =>
      'CompanyState.loaded(${companies.length} companies, query: "$searchQuery")';
}

class _Error implements CompanyState {
  const _Error({required this.message});

  final String message;

  @override
  String toString() => 'CompanyState.error($message)';
}
