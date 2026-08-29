import 'package:http/http.dart' as http;
import 'package:oauth1/oauth1.dart' as oauth1;
import 'package:zaim_api/src/endpoints/account_api.dart';
import 'package:zaim_api/src/endpoints/category_api.dart';
import 'package:zaim_api/src/endpoints/default_api.dart';
import 'package:zaim_api/src/endpoints/genre_api.dart';
import 'package:zaim_api/src/endpoints/money_api.dart';
import 'package:zaim_api/src/endpoints/user_api.dart';
import 'package:zaim_api/src/zaim_auth.dart';
import 'package:zaim_api/src/zaim_transport.dart';

/// The entry point for every authenticated Zaim call.
///
/// One client owns one signed HTTP connection and hands out the five endpoint
/// groups: [user], [money], [category], [genre], and [account]. Every request
/// it sends carries a full OAuth 1.0a HMAC-SHA1 signature
/// (`oauth_consumer_key`, `oauth_signature_method`, `oauth_version`,
/// `oauth_token`, `oauth_timestamp`, `oauth_nonce`, `oauth_signature`) and
/// the `mapping=1` parameter Zaim requires.
///
/// For the public master data, which needs no credentials at all, use the
/// static [ZaimClient.defaults].
///
/// ## Parameters
///
/// ### Required
/// - **credentials**: The consumer key/secret plus the user's access token
///   pair, from [ZaimAuthFlow].
///
/// ### Optional
/// - **httpClient**: Inject a client — a `MockClient` in tests, a
///   `BrowserClient` on the web. When omitted one is created and [close]
///   disposes it (default: `null`).
///
/// ## Example
///
/// ```dart
/// final client = ZaimClient(credentials: credentials);
/// try {
///   final me = await client.user.verify();
///   final records = await client.money.list(limit: 50);
///   print('${me.name}: ${records.length} records');
/// } finally {
///   client.close();
/// }
/// ```
class ZaimClient {
  /// Creates a client that signs every request with [credentials].
  factory ZaimClient({
    required ZaimCredentials credentials,
    http.Client? httpClient,
  }) {
    final owned = httpClient == null ? http.Client() : null;
    final signing = oauth1.Client(
      // Zaim accepts HMAC-SHA1 and nothing else.
      oauth1.SignatureMethods.hmacSha1,
      oauth1.ClientCredentials(
        credentials.consumerKey,
        credentials.consumerSecret,
      ),
      oauth1.Credentials(
        credentials.accessToken,
        credentials.accessTokenSecret,
      ),
      BaseClientAdapter(httpClient ?? owned!),
    );
    return ZaimClient._(ZaimTransport(signing, ownedClient: owned));
  }

  ZaimClient._(this._transport)
      : user = UserApi(_transport),
        money = MoneyApi(_transport),
        category = CategoryApi(_transport),
        genre = GenreApi(_transport),
        account = AccountApi(_transport);

  final ZaimTransport _transport;

  /// `GET /v2/home/user/verify` — who the credentials belong to.
  final UserApi user;

  /// The `/v2/home/money*` endpoints: list, create, update, delete.
  final MoneyApi money;

  /// `GET /v2/home/category` — the user's own categories.
  final CategoryApi category;

  /// `GET /v2/home/genre` — the user's own genres.
  final GenreApi genre;

  /// `GET /v2/home/account` — the user's own accounts.
  final AccountApi account;

  /// The public `/v2/account`, `/v2/category`, `/v2/genre`, and
  /// `/v2/currency` endpoints, which need no credentials.
  ///
  /// Useful before the user has authorized anything — for example to fill a
  /// category picker on a first-run screen. Call [DefaultApi.close] when you
  /// are done if you did not inject [httpClient].
  static DefaultApi defaults({http.Client? httpClient}) =>
      DefaultApi(httpClient: httpClient);

  /// Closes the HTTP client this object created itself.
  ///
  /// Does nothing when a client was injected: whoever created that client
  /// owns it.
  void close() => _transport.close();
}
