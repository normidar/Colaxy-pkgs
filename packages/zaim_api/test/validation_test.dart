import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:zaim_api/src/validation.dart';
import 'package:zaim_api/zaim_api.dart';

import 'fixtures.dart';

/// A client that fails the test if anything reaches the network: every case
/// below must be rejected locally, before a request is built.
MockClient get _neverCalled => MockClient((request) async {
      fail('a request was sent to ${request.url} despite invalid arguments');
    });

void main() {
  late ZaimClient client;

  setUp(() {
    client = ZaimClient(credentials: testCredentials, httpClient: _neverCalled);
  });

  group('text length', () {
    final tooLong = 'x' * 101;
    final justRight = 'x' * 100;

    test('rejects a comment over 100 characters', () {
      expect(
        () => client.money.createPayment(
          categoryId: 101,
          genreId: 10101,
          amount: 100,
          date: DateTime.now(),
          comment: tooLong,
        ),
        throwsA(
          isA<ArgumentError>().having((e) => e.name, 'name', 'comment'),
        ),
      );
    });

    test('rejects a name over 100 characters', () {
      expect(
        () => client.money.createPayment(
          categoryId: 101,
          genreId: 10101,
          amount: 100,
          date: DateTime.now(),
          name: tooLong,
        ),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'name')),
      );
    });

    test('rejects a place over 100 characters', () {
      expect(
        () => client.money.createIncome(
          categoryId: 11,
          amount: 100,
          date: DateTime.now(),
          place: tooLong,
        ),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'place')),
      );
    });

    test('rejects a long comment on update too', () {
      expect(
        () => client.money.updateTransfer(
          1,
          amount: 100,
          date: DateTime.now(),
          comment: tooLong,
        ),
        throwsArgumentError,
      );
    });

    test('accepts exactly 100 characters', () async {
      final log = RequestLog();
      final sending = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([moneyCreateWithoutPlaceJson]),
      );
      await sending.money.createPayment(
        categoryId: 101,
        genreId: 10101,
        amount: 100,
        date: DateTime.now(),
        comment: justRight,
      );
      expect(log.lastFields['comment'], justRight);
    });
  });

  group('paging', () {
    test('rejects limit above 100', () {
      expect(
        () => client.money.list(limit: 101),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'limit')),
      );
    });

    test('rejects limit below 1', () {
      expect(() => client.money.list(limit: 0), throwsArgumentError);
    });

    test('rejects page below 1', () {
      expect(
        () => client.money.list(page: 0),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'page')),
      );
    });
  });

  group('amount', () {
    test('rejects zero', () {
      expect(
        () => client.money.createPayment(
          categoryId: 101,
          genreId: 10101,
          amount: 0,
          date: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'amount')),
      );
    });

    test('rejects a negative amount on every write', () {
      final date = DateTime.now();
      expect(
        () => client.money.createIncome(
          categoryId: 11,
          amount: -1,
          date: date,
        ),
        throwsArgumentError,
      );
      expect(
        () => client.money.createTransfer(
          amount: -1,
          date: date,
          fromAccountId: 1,
          toAccountId: 2,
        ),
        throwsArgumentError,
      );
      expect(
        () => client.money.updatePayment(1, amount: -1, date: date),
        throwsArgumentError,
      );
    });
  });

  group('the five-year window for payments and transfers', () {
    final now = DateTime.now();

    test('rejects a date more than five years in the past', () {
      expect(
        () => client.money.createPayment(
          categoryId: 101,
          genreId: 10101,
          amount: 100,
          date: DateTime(now.year - 5, now.month, now.day - 1),
        ),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'date')),
      );
    });

    test('rejects a date more than five years in the future', () {
      expect(
        () => client.money.createTransfer(
          amount: 100,
          date: DateTime(now.year + 5, now.month, now.day + 1),
          fromAccountId: 1,
          toAccountId: 2,
        ),
        throwsArgumentError,
      );
    });

    test('accepts a date four years away in either direction', () async {
      final log = RequestLog();
      final sending = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([moneyCreateWithoutPlaceJson]),
      );
      await sending.money.createPayment(
        categoryId: 101,
        genreId: 10101,
        amount: 100,
        date: DateTime(now.year - 4, now.month, now.day),
      );
      await sending.money.createPayment(
        categoryId: 101,
        genreId: 10101,
        amount: 100,
        date: DateTime(now.year + 4, now.month, now.day),
      );
      expect(log.requests, hasLength(2));
    });
  });

  group('the three-month window for creating income', () {
    final now = DateTime.now();

    test('rejects a date more than three months in the past', () {
      expect(
        () => client.money.createIncome(
          categoryId: 11,
          amount: 100,
          date: DateTime(now.year, now.month - 3, now.day - 1),
        ),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'date')),
      );
    });

    test('rejects a date in the future', () {
      expect(
        () => client.money.createIncome(
          categoryId: 11,
          amount: 100,
          date: DateTime(now.year, now.month, now.day + 1),
        ),
        throwsArgumentError,
      );
    });

    test('accepts one month ago', () async {
      final log = RequestLog();
      final sending = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([moneyCreateWithoutPlaceJson]),
      );
      await sending.money.createIncome(
        categoryId: 11,
        amount: 100,
        date: DateTime(now.year, now.month - 1, now.day),
      );
      expect(log.requests, hasLength(1));
    });

    test(
        'the three-month boundary lands on the last day of the target month '
        'instead of overflowing into the next one', () {
      // Three months before May 31 is "February 31", which does not exist.
      // The boundary must clamp to February 28/29, not silently roll forward
      // into March.
      final now = DateTime(2026, 5, 31);
      expect(
        () => checkIncomeWindow(DateTime(2026, 2, 28), 'date', now: now),
        returnsNormally,
      );
      expect(
        () => checkIncomeWindow(DateTime(2026, 2, 27), 'date', now: now),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'date')),
      );
    });

    test('does not apply the three-month window to income updates', () async {
      final log = RequestLog();
      final sending = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([moneyUpdateJson]),
      );
      await sending.money.updateIncome(
        1506,
        amount: 100,
        date: DateTime(now.year - 2, now.month, now.day),
      );
      expect(log.requests, hasLength(1));
    });
  });

  group('transfer accounts', () {
    test('rejects a transfer to and from the same account', () {
      expect(
        () => client.money.createTransfer(
          amount: 100,
          date: DateTime.now(),
          fromAccountId: 7,
          toAccountId: 7,
        ),
        throwsA(
          isA<ArgumentError>().having((e) => e.name, 'name', 'toAccountId'),
        ),
      );
    });

    test('rejects it on update as well', () {
      expect(
        () => client.money.updateTransfer(
          1,
          amount: 100,
          date: DateTime.now(),
          fromAccountId: 7,
          toAccountId: 7,
        ),
        throwsArgumentError,
      );
    });

    test('allows an update that names only one side', () async {
      final log = RequestLog();
      final sending = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([moneyUpdateJson]),
      );
      await sending.money.updateTransfer(
        1,
        amount: 100,
        date: DateTime.now(),
        fromAccountId: 7,
      );
      expect(log.lastFields['from_account_id'], '7');
      expect(log.lastFields.containsKey('to_account_id'), isFalse);
    });
  });

  test('an injected client is never closed by close()', () async {
    var closed = false;
    final injected = _ClosableMockClient(() => closed = true);
    ZaimClient(credentials: testCredentials, httpClient: injected).close();
    expect(closed, isFalse);
  });
}

/// A [MockClient] that reports when it is closed.
class _ClosableMockClient extends http.BaseClient {
  _ClosableMockClient(this._onClose);

  final void Function() _onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      fail('no request expected');

  @override
  void close() => _onClose();
}
