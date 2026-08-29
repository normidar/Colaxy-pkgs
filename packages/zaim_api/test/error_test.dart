import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:zaim_api/zaim_api.dart';

import 'fixtures.dart';

ZaimClient _clientReturning(int statusCode, String body) => ZaimClient(
      credentials: testCredentials,
      httpClient: MockClient(
        (_) async => http.Response(
          body,
          statusCode,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

void main() {
  group('401', () {
    test('raises ZaimAuthException with the permission message', () async {
      final client = _clientReturning(
        401,
        '{"message":"This consumer key does not have a permission for the '
        'action."}',
      );
      await expectLater(
        client.money.list(),
        throwsA(
          isA<ZaimAuthException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having(
                (e) => e.message,
                'message',
                'This consumer key does not have a permission for the action.',
              ),
        ),
      );
    });

    test('raises ZaimAuthException with the authentication message', () async {
      final client = _clientReturning(
        401,
        '{"message":"User authentication was failed."}',
      );
      await expectLater(
        client.user.verify(),
        throwsA(
          isA<ZaimAuthException>().having(
            (e) => e.message,
            'message',
            'User authentication was failed.',
          ),
        ),
      );
    });

    test('ZaimAuthException is also a ZaimApiException', () async {
      final client = _clientReturning(401, '{"message":"nope"}');
      await expectLater(client.user.verify(), throwsA(isA<ZaimApiException>()));
    });
  });

  group('404', () {
    test('raises ZaimApiException, not ZaimAuthException', () async {
      final client = _clientReturning(404, '{"message":"URL is not defined."}');
      await expectLater(
        client.category.list(),
        throwsA(
          isA<ZaimApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message', 'URL is not defined.'),
        ),
      );
      await expectLater(
        client.category.list(),
        throwsA(isNot(isA<ZaimAuthException>())),
      );
    });
  });

  group('400', () {
    for (final message in const [
      'Parameters are not enough.',
      'Insert action was failed.',
      'Update action was failed.',
    ]) {
      test('keeps the server message "$message"', () async {
        final client = _clientReturning(400, '{"message":"$message"}');
        await expectLater(
          client.money.list(),
          throwsA(
            isA<ZaimApiException>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having((e) => e.message, 'message', message),
          ),
        );
      });
    }
  });

  group('body handling', () {
    test('keeps the raw body on the exception', () async {
      const body = '{"message":"URL is not defined.","requested":1370831964}';
      final client = _clientReturning(404, body);
      await expectLater(
        client.genre.list(),
        throwsA(isA<ZaimApiException>().having((e) => e.body, 'body', body)),
      );
    });

    test('falls back to a generated message when the body has none', () async {
      final client = _clientReturning(500, '<html>gateway error</html>');
      await expectLater(
        client.account.list(),
        throwsA(
          isA<ZaimApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message', contains('500')),
        ),
      );
    });

    test('rejects a success response that is not JSON', () async {
      final client = _clientReturning(200, 'not json at all');
      await expectLater(
        client.user.verify(),
        throwsA(
          isA<ZaimApiException>()
              .having((e) => e.message, 'message', contains('not valid JSON')),
        ),
      );
    });

    test('toString names the status and the message', () {
      const exception = ZaimApiException(
        statusCode: 400,
        message: 'Parameters are not enough.',
        body: '',
      );
      expect(exception.toString(), contains('400'));
      expect(exception.toString(), contains('Parameters are not enough.'));
    });
  });

  test('UTF-8 response bodies survive intact', () async {
    final client = ZaimClient(
      credentials: testCredentials,
      httpClient: MockClient(
        // No charset in the content type: `http` would otherwise fall back to
        // latin-1 and mangle the Japanese name.
        (_) async => http.Response.bytes(
          utf8.encode('{"categories":[{"id":1,"name":"食費","mode":"payment"}]}'),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    final categories = await client.category.list();
    expect(categories.single.name, '食費');
  });
}
