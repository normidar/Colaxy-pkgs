/// Client-side parameter checks, applied before any request leaves the
/// process so that obvious mistakes surface as an [ArgumentError] instead of
/// a `400 Parameters are not enough.` round trip.
library;

/// Zaim's length ceiling for `comment`, `name`, and `place`.
const int maxTextLength = 100;

/// Zaim's ceiling for the `limit` parameter of `GET /v2/home/money`.
const int maxPageLimit = 100;

/// Throws an [ArgumentError] when [value] exceeds [maxTextLength].
void checkTextLength(String? value, String name) {
  if (value == null) return;
  if (value.length > maxTextLength) {
    throw ArgumentError.value(
      value,
      name,
      'must be at most $maxTextLength characters '
      '(got ${value.length})',
    );
  }
}

/// Throws an [ArgumentError] unless [amount] is a positive integer.
void checkAmount(int amount) {
  if (amount <= 0) {
    throw ArgumentError.value(amount, 'amount', 'must be greater than zero');
  }
}

/// Throws an [ArgumentError] unless `1 <= limit <= 100` and `page >= 1`.
void checkPaging({required int page, required int limit}) {
  if (page < 1) {
    throw ArgumentError.value(page, 'page', 'must be 1 or greater');
  }
  if (limit < 1 || limit > maxPageLimit) {
    throw ArgumentError.value(
        limit,
        'limit',
        'must be between 1 and '
            '$maxPageLimit');
  }
}

/// Throws an [ArgumentError] unless [date] is within five years either side
/// of [now], the window Zaim accepts for payments and transfers.
void checkFiveYearWindow(DateTime date, String name, {DateTime? now}) {
  final today = _startOfDay(now ?? DateTime.now());
  final day = _startOfDay(date);
  final earliest = DateTime(today.year - 5, today.month, today.day);
  final latest = DateTime(today.year + 5, today.month, today.day);
  if (day.isBefore(earliest) || day.isAfter(latest)) {
    throw ArgumentError.value(
      date,
      name,
      'must be within five years of today '
      '(${_ymd(earliest)}..${_ymd(latest)})',
    );
  }
}

/// Throws an [ArgumentError] unless [date] falls in the window Zaim accepts
/// for creating income: the past three months, and not in the future.
void checkIncomeWindow(DateTime date, String name, {DateTime? now}) {
  final today = _startOfDay(now ?? DateTime.now());
  final day = _startOfDay(date);
  final earliest = DateTime(today.year, today.month - 3, today.day);
  if (day.isBefore(earliest)) {
    throw ArgumentError.value(
      date,
      name,
      'income may only be recorded for the past three months '
      '(on or after ${_ymd(earliest)})',
    );
  }
  if (day.isAfter(today)) {
    throw ArgumentError.value(
      date,
      name,
      'income may not be recorded in the future (on or before '
      '${_ymd(today)})',
    );
  }
}

/// Throws an [ArgumentError] when a transfer's two accounts are the same.
void checkTransferAccounts(int? fromAccountId, int? toAccountId) {
  if (fromAccountId != null && fromAccountId == toAccountId) {
    throw ArgumentError.value(
      toAccountId,
      'toAccountId',
      'must differ from fromAccountId ($fromAccountId): a transfer moves '
          'money between two different accounts',
    );
  }
}

DateTime _startOfDay(DateTime value) {
  final local = value.isUtc ? value.toLocal() : value;
  return DateTime(local.year, local.month, local.day);
}

String _ymd(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
