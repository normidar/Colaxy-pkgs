import 'package:meta/meta.dart';

/// What one setup check concluded.
///
/// ## Example
///
/// ```dart
/// final failed = checks.where((c) => c.outcome == DoctorOutcome.fail);
/// ```
enum DoctorOutcome {
  /// The store answered, and answered with something.
  pass,

  /// The store answered, but had nothing to report.
  ///
  /// Distinct from [pass] deliberately. An app with no store listing yet
  /// proves the credentials and the request shape; it does not prove that
  /// reading a listing works. Calling it a pass would claim a verification
  /// that did not happen — the same distinction `colaxy_store_console`'s
  /// verify tool draws.
  empty,

  /// The store rejected the request, or the answer could not be read.
  fail,

  /// Not attempted, for want of something to attempt it with.
  skip,
}

/// One setup check's result.
///
/// ## Parameters
///
/// ### Required
/// - **[name]**: What was checked.
/// - **[outcome]**: What it concluded.
/// - **[detail]**: Enough to act on, in one line.
@immutable
class DoctorCheck {
  /// Creates a result.
  const DoctorCheck(this.name, this.outcome, this.detail);

  /// Creates a result for something not attempted.
  const DoctorCheck.skipped(this.name, String missing)
    : outcome = DoctorOutcome.skip,
      detail = 'needs $missing';

  /// What was checked.
  final String name;

  /// What it concluded.
  final DoctorOutcome outcome;

  /// Enough to act on, in one line.
  final String detail;

  /// The five-character tag used when printing a column of results.
  String get tag => switch (outcome) {
    DoctorOutcome.pass => 'PASS ',
    DoctorOutcome.empty => 'EMPTY',
    DoctorOutcome.fail => 'FAIL ',
    DoctorOutcome.skip => 'SKIP ',
  };

  @override
  String toString() => '$tag  ${name.padRight(28)} $detail';
}
