import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:oauth1/oauth1.dart' as oauth1;
import 'package:zaim_api/src/zaim_transport.dart';

/// Zaim's OAuth 1.0a endpoints.
///
/// Zaim signs with **HMAC-SHA1 only**; no other signature method is accepted.
abstract final class ZaimOAuthEndpoints {
  /// Step 1 — temporary credentials request (`POST`).
  static const String requestToken = 'https://api.zaim.net/v2/auth/request';

  /// Step 2 — the page the user is sent to in a browser.
  static const String authorize = 'https://auth.zaim.net/users/auth';

  /// Step 3 — token credentials request (`POST`, with `oauth_verifier`).
  static const String accessToken = 'https://api.zaim.net/v2/auth/access';
}

/// The short-lived token pair from step 1 of the OAuth 1.0a dance.
///
/// Keep it around between [ZaimAuthFlow.requestToken] and
/// [ZaimAuthFlow.accessToken]: the secret is needed to sign the final
/// exchange, and in a web app that means persisting it across the redirect.
///
/// ## Parameters
///
/// ### Required
/// - **[token]**: The `oauth_token` to put in the authorization URL.
/// - **[tokenSecret]**: The matching `oauth_token_secret`.
@immutable
class ZaimRequestToken {
  /// Creates a request token pair.
  const ZaimRequestToken({required this.token, required this.tokenSecret});

  /// Restores a request token from [toJson] output.
  factory ZaimRequestToken.fromJson(Map<String, dynamic> json) =>
      ZaimRequestToken(
        token: json['oauth_token'] as String? ?? '',
        tokenSecret: json['oauth_token_secret'] as String? ?? '',
      );

  /// The temporary `oauth_token`.
  final String token;

  /// The temporary `oauth_token_secret`.
  final String tokenSecret;

  /// Serialises the pair so it can survive a redirect.
  Map<String, dynamic> toJson() => {
        'oauth_token': token,
        'oauth_token_secret': tokenSecret,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZaimRequestToken &&
          other.token == token &&
          other.tokenSecret == tokenSecret;

  @override
  int get hashCode => Object.hash(token, tokenSecret);

  /// A redacted description. The secret is never printed.
  @override
  String toString() => 'ZaimRequestToken(token: $token, tokenSecret: <hidden>)';
}

/// The four values needed to sign every authenticated Zaim request: the app's
/// consumer key and secret, plus the user's access token and secret.
///
/// Persist this — not the [ZaimRequestToken] — after the user has authorized
/// the app. Note that unless the app was registered as *permanently
/// accessible*, the permission these credentials carry **expires 24 hours
/// after the user granted it**, and calls then start failing with
/// `ZaimAuthException`.
///
/// ## Parameters
///
/// ### Required
/// - **[consumerKey]**: From the Zaim Developers Center.
/// - **[consumerSecret]**: From the Zaim Developers Center.
/// - **[accessToken]**: Returned by [ZaimAuthFlow.accessToken].
/// - **[accessTokenSecret]**: Returned by [ZaimAuthFlow.accessToken].
///
/// ## Example
///
/// ```dart
/// final credentials = ZaimCredentials.fromJson(
///   jsonDecode(await secureStorage.read()) as Map<String, dynamic>,
/// );
/// final client = ZaimClient(credentials: credentials);
/// ```
@immutable
class ZaimCredentials {
  /// Creates a credential set.
  const ZaimCredentials({
    required this.consumerKey,
    required this.consumerSecret,
    required this.accessToken,
    required this.accessTokenSecret,
  });

  /// Restores credentials from [toJson] output.
  factory ZaimCredentials.fromJson(Map<String, dynamic> json) =>
      ZaimCredentials(
        consumerKey: json['consumer_key'] as String? ?? '',
        consumerSecret: json['consumer_secret'] as String? ?? '',
        accessToken: json['access_token'] as String? ?? '',
        accessTokenSecret: json['access_token_secret'] as String? ?? '',
      );

  /// The app's consumer key.
  final String consumerKey;

  /// The app's consumer secret.
  final String consumerSecret;

  /// The user's access token.
  final String accessToken;

  /// The user's access token secret.
  final String accessTokenSecret;

  /// Serialises all four values. Treat the result as a secret.
  Map<String, dynamic> toJson() => {
        'consumer_key': consumerKey,
        'consumer_secret': consumerSecret,
        'access_token': accessToken,
        'access_token_secret': accessTokenSecret,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZaimCredentials &&
          other.consumerKey == consumerKey &&
          other.consumerSecret == consumerSecret &&
          other.accessToken == accessToken &&
          other.accessTokenSecret == accessTokenSecret;

  @override
  int get hashCode =>
      Object.hash(consumerKey, consumerSecret, accessToken, accessTokenSecret);

  /// A redacted description: neither secret is ever printed.
  @override
  String toString() => 'ZaimCredentials(consumerKey: $consumerKey, '
      'consumerSecret: <hidden>, accessToken: $accessToken, '
      'accessTokenSecret: <hidden>)';
}

/// Drives Zaim's three-legged OAuth 1.0a flow.
///
/// ```text
/// 1. requestToken()      POST https://api.zaim.net/v2/auth/request
/// 2. authorizationUrl()  open in a browser, user approves, Zaim calls back
///                        (or shows a PIN) with oauth_verifier
/// 3. accessToken()       POST https://api.zaim.net/v2/auth/access
/// ```
///
/// ## Parameters
///
/// ### Required
/// - **consumerKey**: From the Zaim Developers Center.
/// - **consumerSecret**: From the Zaim Developers Center.
///
/// ### Optional
/// - **httpClient**: Inject a client for tests; when omitted one is created
///   and [close] disposes it (default: `null`).
///
/// ## Example
///
/// ```dart
/// final flow = ZaimAuthFlow(
///   consumerKey: 'YOUR_CONSUMER_KEY',
///   consumerSecret: 'YOUR_CONSUMER_SECRET',
/// );
/// final requestToken = await flow.requestToken(callbackUrl: 'oob');
/// print('Open: ${flow.authorizationUrl(requestToken)}');
/// final verifier = stdin.readLineSync()!;
/// final credentials = await flow.accessToken(requestToken, verifier);
/// flow.close();
/// ```
class ZaimAuthFlow {
  /// Creates a flow for the app identified by [consumerKey].
  ZaimAuthFlow({
    required String consumerKey,
    required String consumerSecret,
    http.Client? httpClient,
  })  : _ownedClient = httpClient == null ? http.Client() : null,
        _clientCredentials =
            oauth1.ClientCredentials(consumerKey, consumerSecret) {
    _authorization = oauth1.Authorization(
      _clientCredentials,
      oauth1.Platform(
        ZaimOAuthEndpoints.requestToken,
        ZaimOAuthEndpoints.authorize,
        ZaimOAuthEndpoints.accessToken,
        oauth1.SignatureMethods.hmacSha1,
      ),
      ThrowingBaseClient(httpClient ?? _ownedClient!),
    );
  }

  final http.Client? _ownedClient;
  final oauth1.ClientCredentials _clientCredentials;
  late final oauth1.Authorization _authorization;

  /// Step 1: asks Zaim for a temporary token pair.
  ///
  /// [callbackUrl] is the URL Zaim redirects to after the user approves. Pass
  /// the default `'oob'` for out-of-band (PIN) authorization, which is what a
  /// console or desktop app wants. For a Browser App the callback must live
  /// under the Service URL registered with the app.
  ///
  /// Requires no scope. Throws a `ZaimApiException` if Zaim rejects the
  /// consumer key.
  Future<ZaimRequestToken> requestToken({String callbackUrl = 'oob'}) async {
    final response =
        await _authorization.requestTemporaryCredentials(callbackUrl);
    return ZaimRequestToken(
      token: response.credentials.token,
      tokenSecret: response.credentials.tokenSecret,
    );
  }

  /// Step 2: the URL to open in a browser so the user can approve the app.
  ///
  /// Zaim appends `oauth_verifier` to the callback (or shows it as a PIN when
  /// [requestToken] was called with `'oob'`); feed that value to
  /// [accessToken].
  Uri authorizationUrl(ZaimRequestToken token) =>
      Uri.parse(ZaimOAuthEndpoints.authorize)
          .replace(queryParameters: {'oauth_token': token.token});

  /// Step 3: exchanges [token] plus [verifier] for long-lived credentials.
  ///
  /// The returned [ZaimCredentials] is what `ZaimClient` needs; persist it.
  /// Requires no scope. Throws a `ZaimApiException` when the verifier is wrong
  /// or the request token has already been used.
  Future<ZaimCredentials> accessToken(
    ZaimRequestToken token,
    String verifier,
  ) async {
    final response = await _authorization.requestTokenCredentials(
      oauth1.Credentials(token.token, token.tokenSecret),
      verifier,
    );
    return ZaimCredentials(
      consumerKey: _clientCredentials.token,
      consumerSecret: _clientCredentials.tokenSecret,
      accessToken: response.credentials.token,
      accessTokenSecret: response.credentials.tokenSecret,
    );
  }

  /// Closes the HTTP client this flow created itself. Does nothing when a
  /// client was injected.
  void close() => _ownedClient?.close();
}
