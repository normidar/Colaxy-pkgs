import 'dart:convert';

import 'package:test/test.dart';
import 'package:zaim_api/zaim_api.dart';

import 'fixtures.dart';

/// Writes are validated against a ±5 year window, so the request-shape tests
/// use today rather than the 2011 date the read fixtures carry.
final DateTime today = DateTime(
  DateTime.now().year,
  DateTime.now().month,
  DateTime.now().day,
);

/// [today] rendered the way the package sends it.
final String todayYmd = '${today.year.toString().padLeft(4, '0')}-'
    '${today.month.toString().padLeft(2, '0')}-'
    '${today.day.toString().padLeft(2, '0')}';

void main() {
  group('GET /v2/home/money query string', () {
    test('sends mapping=1 even with no filters', () async {
      final log = RequestLog();
      final client = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([moneyListJson]),
      );
      await client.money.list();

      final query = log.last.url.queryParameters;
      expect(query['mapping'], '1');
      expect(query['page'], '1');
      expect(query['limit'], '20');
      expect(query.containsKey('mode'), isFalse);
      expect(query.containsKey('group_by'), isFalse);
      expect(log.last.url.path, '/v2/home/money');
      expect(log.last.method, 'GET');
    });

    test('sends every filter, with dates as Y-m-d', () async {
      final log = RequestLog();
      final client = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([moneyListJson]),
      );
      await client.money.list(
        mode: MoneyMode.transfer,
        categoryId: 101,
        genreId: 10101,
        order: MoneyOrder.id,
        startDate: DateTime(2011, 1, 2),
        endDate: DateTime(2011, 11, 7),
        page: 3,
        limit: 100,
        groupByReceiptId: true,
      );

      expect(log.last.url.queryParameters, {
        'mapping': '1',
        'category_id': '101',
        'genre_id': '10101',
        'mode': 'transfer',
        'order': 'id',
        'start_date': '2011-01-02',
        'end_date': '2011-11-07',
        'page': '3',
        'limit': '100',
        'group_by': 'receipt_id',
      });
    });

    test('signs the request with HMAC-SHA1 OAuth 1.0a parameters', () async {
      final log = RequestLog();
      final client = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([moneyListJson]),
      );
      await client.money.list();

      final header = log.last.headers['Authorization']!;
      expect(header, startsWith('OAuth '));
      for (final parameter in const [
        'oauth_consumer_key',
        'oauth_signature_method',
        'oauth_version',
        'oauth_token',
        'oauth_timestamp',
        'oauth_nonce',
        'oauth_signature',
      ]) {
        expect(header, contains('$parameter='), reason: 'missing $parameter');
      }
      expect(header, contains('oauth_signature_method="HMAC-SHA1"'));
      expect(header, contains('oauth_version="1.0"'));
    });

    test('parses the returned records', () async {
      final log = RequestLog();
      final client = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([moneyListJson]),
      );
      final records = await client.money.list();
      expect(records, hasLength(1));
      expect(records.single.id, 381);
      expect(records.single.mode, MoneyMode.income);
    });
  });

  group('listAll paging', () {
    /// Builds a `money` response holding [count] synthetic records.
    String page(int count, {int firstId = 1}) => jsonEncode({
          'money': [
            for (var i = 0; i < count; i++)
              {
                'id': firstId + i,
                'mode': 'payment',
                'user_id': 1,
                'date': '2011-11-07',
                'category_id': 101,
                'genre_id': 10101,
                'amount': 100,
              },
          ],
          'requested': 1321782829,
        });

    test('walks pages of 100 and stops on a short page', () async {
      final log = RequestLog();
      final client = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([page(100), page(3, firstId: 101)]),
      );

      final records = await client.money.listAll().toList();

      expect(records, hasLength(103));
      expect(records.first.id, 1);
      expect(records.last.id, 103);
      expect(log.requests, hasLength(2));
      expect(log.requests[0].url.queryParameters['page'], '1');
      expect(log.requests[0].url.queryParameters['limit'], '100');
      expect(log.requests[1].url.queryParameters['page'], '2');
    });

    test('stops after one request when the first page is short', () async {
      final log = RequestLog();
      final client = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([page(2)]),
      );
      expect(await client.money.listAll().toList(), hasLength(2));
      expect(log.requests, hasLength(1));
    });

    test('forwards the filters to every page', () async {
      final log = RequestLog();
      final client = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([page(100), page(0)]),
      );
      await client.money
          .listAll(mode: MoneyMode.payment, categoryId: 101)
          .toList();

      expect(log.requests, hasLength(2));
      for (final request in log.requests) {
        expect(request.url.queryParameters['mode'], 'payment');
        expect(request.url.queryParameters['category_id'], '101');
        expect(request.url.queryParameters['mapping'], '1');
      }
    });

    test('is lazy: nothing is fetched until the stream is listened to',
        () async {
      final log = RequestLog();
      final client = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([page(1)]),
      );
      client.money.listAll();
      await Future<void>.delayed(Duration.zero);
      expect(log.requests, isEmpty);
    });
  });

  group('create', () {
    test('POSTs a payment as form fields with mapping=1', () async {
      final log = RequestLog();
      final client = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([moneyCreateJson]),
      );

      final result = await client.money.createPayment(
        categoryId: 101,
        genreId: 10101,
        amount: 1280,
        date: today,
        fromAccountId: 34555,
        comment: 'lunch',
        name: 'bento',
        place: 'test',
      );

      expect(log.last.method, 'POST');
      expect(log.last.url.path, '/v2/home/money/payment');
      expect(log.lastFields, {
        'mapping': '1',
        'category_id': '101',
        'genre_id': '10101',
        'amount': '1280',
        'date': todayYmd,
        'from_account_id': '34555',
        'comment': 'lunch',
        'name': 'bento',
        'place': 'test',
      });
      expect(result.id, 11820767);
      expect(result.placeUid, 'zm-098f6bcd4621d373');
      expect(result.place?.name, 'test');
    });

    test('POSTs an income without the payment-only fields', () async {
      final log = RequestLog();
      final client = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([moneyCreateWithoutPlaceJson]),
      );

      await client.money.createIncome(
        categoryId: 11,
        amount: 10000,
        date: DateTime.now(),
        toAccountId: 34555,
      );

      expect(log.last.url.path, '/v2/home/money/income');
      expect(log.lastFields.keys, containsAll(['mapping', 'category_id']));
      expect(log.lastFields.containsKey('genre_id'), isFalse);
      expect(log.lastFields.containsKey('from_account_id'), isFalse);
      expect(log.lastFields['to_account_id'], '34555');
    });

    test('POSTs a transfer with both accounts', () async {
      final log = RequestLog();
      final client = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([moneyCreateWithoutPlaceJson]),
      );

      await client.money.createTransfer(
        amount: 5000,
        date: today,
        fromAccountId: 1,
        toAccountId: 2,
      );

      expect(log.last.url.path, '/v2/home/money/transfer');
      expect(log.lastFields, {
        'mapping': '1',
        'amount': '5000',
        'date': todayYmd,
        'from_account_id': '1',
        'to_account_id': '2',
      });
    });

    test('omits optional fields that were not supplied', () async {
      final log = RequestLog();
      final client = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([moneyCreateWithoutPlaceJson]),
      );
      await client.money.createPayment(
        categoryId: 101,
        genreId: 10101,
        amount: 1,
        date: today,
      );
      expect(log.lastFields.keys, [
        'mapping',
        'category_id',
        'genre_id',
        'amount',
        'date',
      ]);
    });
  });

  group('update', () {
    test('PUTs to the per-mode path', () async {
      final expected = {
        MoneyMode.payment: '/v2/home/money/payment/1506',
        MoneyMode.income: '/v2/home/money/income/1506',
        MoneyMode.transfer: '/v2/home/money/transfer/1506',
      };

      for (final entry in expected.entries) {
        final log = RequestLog();
        final client = ZaimClient(
          credentials: testCredentials,
          httpClient: log.client([moneyUpdateJson]),
        );
        final date = today;
        switch (entry.key) {
          case MoneyMode.payment:
            await client.money.updatePayment(1506, amount: 1, date: date);
          case MoneyMode.income:
            await client.money.updateIncome(1506, amount: 1, date: date);
          case MoneyMode.transfer:
            await client.money.updateTransfer(1506, amount: 1, date: date);
        }
        expect(log.last.method, 'PUT');
        expect(log.last.url.path, entry.value);
        expect(log.lastFields['mapping'], '1');
        expect(log.lastFields['amount'], '1');
        expect(log.lastFields['date'], todayYmd);
      }
    });

    test('sends only the optional fields that were supplied', () async {
      final log = RequestLog();
      final client = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([moneyUpdateJson]),
      );
      await client.money.updatePayment(
        1506,
        amount: 900,
        date: today,
        genreId: 10102,
      );
      expect(log.lastFields, {
        'mapping': '1',
        'amount': '900',
        'date': todayYmd,
        'genre_id': '10102',
      });
    });

    test('parses the update response', () async {
      final log = RequestLog();
      final client = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([moneyUpdateJson]),
      );
      final result = await client.money.updatePayment(
        1506,
        amount: 900,
        date: today,
      );
      expect(result.id, 1506);
      expect(result.user.inputCount, 376);
    });
  });

  group('delete', () {
    test('DELETEs the per-mode path with mapping=1', () async {
      for (final mode in MoneyMode.values) {
        final log = RequestLog();
        final client = ZaimClient(
          credentials: testCredentials,
          httpClient: log.client([moneyDeleteJson]),
        );
        final result = await client.money.delete(mode, 1504);

        expect(log.last.method, 'DELETE');
        expect(log.last.url.path, '/v2/home/money/${mode.wireName}/1504');
        expect(log.last.url.queryParameters, {'mapping': '1'});
        expect(result.id, 1504);
      }
    });
  });
}
