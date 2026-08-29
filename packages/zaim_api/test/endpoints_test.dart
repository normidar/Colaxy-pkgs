import 'package:test/test.dart';
import 'package:zaim_api/zaim_api.dart';

import 'fixtures.dart';

/// Zaim answers the OAuth token endpoints in form encoding, not JSON.
const String requestTokenBody = 'oauth_token=TEMP_TOKEN'
    '&oauth_token_secret=TEMP_SECRET'
    '&oauth_callback_confirmed=true';

void main() {
  group('authenticated endpoints', () {
    test('GET /v2/home/user/verify carries no mapping parameter', () async {
      final log = RequestLog();
      final client = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([userVerifyJson]),
      );

      final me = await client.user.verify();

      expect(log.last.url.path, '/v2/home/user/verify');
      expect(log.last.url.queryParameters, isEmpty);
      expect(me.id, 10000000);
      expect(me.name, 'MyName');
    });

    test('GET /v2/home/category sends mapping=1', () async {
      final log = RequestLog();
      final client = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([categoryListJson]),
      );

      final categories = await client.category.list();

      expect(log.last.url.path, '/v2/home/category');
      expect(log.last.url.queryParameters, {'mapping': '1'});
      expect(categories.single.name, 'Food');
    });

    test('GET /v2/home/genre sends mapping=1', () async {
      final log = RequestLog();
      final client = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([genreListJson]),
      );

      final genres = await client.genre.list();

      expect(log.last.url.path, '/v2/home/genre');
      expect(log.last.url.queryParameters, {'mapping': '1'});
      expect(genres.single.name, 'Grocery');
    });

    test('GET /v2/home/account sends mapping=1', () async {
      final log = RequestLog();
      final client = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([accountListJson]),
      );

      final accounts = await client.account.list();

      expect(log.last.url.path, '/v2/home/account');
      expect(log.last.url.queryParameters, {'mapping': '1'});
      expect(accounts.single.name, 'Credit card');
    });

    test('all requests go to https://api.zaim.net', () async {
      final log = RequestLog();
      final client = ZaimClient(
        credentials: testCredentials,
        httpClient: log.client([userVerifyJson]),
      );
      await client.user.verify();
      expect(log.last.url.scheme, 'https');
      expect(log.last.url.host, 'api.zaim.net');
    });
  });

  group('ZaimClient.defaults', () {
    test('GET /v2/account needs no credentials and no mapping', () async {
      final log = RequestLog();
      final defaults = ZaimClient.defaults(
        httpClient: log.client([defaultAccountJson]),
      );

      final accounts = await defaults.accounts();

      expect(log.last.url.toString(), 'https://api.zaim.net/v2/account');
      expect(log.last.headers.containsKey('Authorization'), isFalse);
      expect(accounts, hasLength(2));
      expect(accounts.first.name, 'Wallet');
    });

    test('GET /v2/category', () async {
      final log = RequestLog();
      final defaults = ZaimClient.defaults(
        httpClient: log.client([defaultCategoryJson]),
      );
      final categories = await defaults.categories();
      expect(log.last.url.path, '/v2/category');
      expect(categories.first.mode, MoneyMode.payment);
    });

    test('GET /v2/genre', () async {
      final log = RequestLog();
      final defaults = ZaimClient.defaults(
        httpClient: log.client([defaultGenreJson]),
      );
      final genres = await defaults.genres();
      expect(log.last.url.path, '/v2/genre');
      expect(genres.first.categoryId, 101);
    });

    test('GET /v2/currency', () async {
      final log = RequestLog();
      final defaults = ZaimClient.defaults(
        httpClient: log.client([currencyJson]),
      );
      final currencies = await defaults.currencies();
      expect(log.last.url.path, '/v2/currency');
      expect(currencies.map((c) => c.currencyCode), ['AUD', 'JPY']);
    });

    test('shares the error handling of the authenticated endpoints', () async {
      final log = RequestLog();
      final defaults = ZaimClient.defaults(
        httpClient: log.client(
          ['{"message":"URL is not defined."}'],
          statusCode: 404,
        ),
      );
      await expectLater(
        defaults.currencies(),
        throwsA(
          isA<ZaimApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message', 'URL is not defined.'),
        ),
      );
    });
  });

  group('ZaimAuthFlow', () {
    test('builds the documented authorization URL', () {
      final flow = ZaimAuthFlow(
        consumerKey: 'TEST_CONSUMER_KEY',
        consumerSecret: 'TEST_CONSUMER_SECRET',
        httpClient: RequestLog().client(const ['']),
      );
      const token = ZaimRequestToken(
        token: 'TEST_REQUEST_TOKEN',
        tokenSecret: 'TEST_REQUEST_TOKEN_SECRET',
      );

      expect(
        flow.authorizationUrl(token).toString(),
        'https://auth.zaim.net/users/auth?oauth_token=TEST_REQUEST_TOKEN',
      );
      flow.close();
    });

    test('exposes the three documented OAuth endpoints', () {
      expect(
        ZaimOAuthEndpoints.requestToken,
        'https://api.zaim.net/v2/auth/request',
      );
      expect(
        ZaimOAuthEndpoints.authorize,
        'https://auth.zaim.net/users/auth',
      );
      expect(
        ZaimOAuthEndpoints.accessToken,
        'https://api.zaim.net/v2/auth/access',
      );
    });

    test('requestToken posts to the request endpoint and reads the pair',
        () async {
      final log = RequestLog();
      final flow = ZaimAuthFlow(
        consumerKey: 'TEST_CONSUMER_KEY',
        consumerSecret: 'TEST_CONSUMER_SECRET',
        httpClient: log.client(const [requestTokenBody]),
      );

      final token = await flow.requestToken();

      expect(log.last.method, 'POST');
      expect(log.last.url.toString(), ZaimOAuthEndpoints.requestToken);
      expect(log.last.headers['Authorization'], contains('oauth_callback'));
      expect(token.token, 'TEMP_TOKEN');
      expect(token.tokenSecret, 'TEMP_SECRET');
      flow.close();
    });

    test('accessToken exchanges the verifier for full credentials', () async {
      final log = RequestLog();
      final flow = ZaimAuthFlow(
        consumerKey: 'TEST_CONSUMER_KEY',
        consumerSecret: 'TEST_CONSUMER_SECRET',
        httpClient: log.client(const [
          'oauth_token=FINAL_TOKEN&oauth_token_secret=FINAL_SECRET',
        ]),
      );

      final credentials = await flow.accessToken(
        const ZaimRequestToken(
          token: 'TEMP_TOKEN',
          tokenSecret: 'TEMP_SECRET',
        ),
        'TEST_VERIFIER',
      );

      expect(log.last.url.toString(), ZaimOAuthEndpoints.accessToken);
      expect(
        log.last.headers['Authorization'],
        contains('oauth_verifier="TEST_VERIFIER"'),
      );
      expect(credentials.consumerKey, 'TEST_CONSUMER_KEY');
      expect(credentials.consumerSecret, 'TEST_CONSUMER_SECRET');
      expect(credentials.accessToken, 'FINAL_TOKEN');
      expect(credentials.accessTokenSecret, 'FINAL_SECRET');
      flow.close();
    });

    test('surfaces a rejected consumer key as ZaimAuthException', () async {
      final log = RequestLog();
      final flow = ZaimAuthFlow(
        consumerKey: 'TEST_CONSUMER_KEY',
        consumerSecret: 'TEST_CONSUMER_SECRET',
        httpClient: log.client(
          const ['{"message":"User authentication was failed."}'],
          statusCode: 401,
        ),
      );

      await expectLater(
        flow.requestToken(),
        throwsA(
          isA<ZaimAuthException>().having(
            (e) => e.message,
            'message',
            'User authentication was failed.',
          ),
        ),
      );
      flow.close();
    });
  });
}
