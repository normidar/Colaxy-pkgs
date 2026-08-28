import 'package:colaxy_store_console/src/app_store/app_store_api_key.dart';
import 'package:colaxy_store_console/src/core/store.dart';
import 'package:colaxy_store_console/src/core/store_console_exception.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:meta/meta.dart';

/// Mints and caches the ES256 bearer token App Store Connect expects.
///
/// Apple has no token endpoint: you sign a short-lived JWT yourself with the
/// `.p8` key. Apple rejects any token whose `exp` is more than 20 minutes
/// out, and re-signing on every request costs a full ECDSA operation, so this
/// caches one token and re-signs only once it is close to expiring.
///
/// ## Parameters
///
/// ### Required
/// - **[apiKey]**: The key to sign with.
///
/// ### Optional
/// - **[lifetime]**: How long each token is valid (default: 20 minutes, the
///   maximum Apple accepts).
/// - **[refreshMargin]**: How long before expiry to mint a fresh token
///   (default: 1 minute), so a request in flight cannot expire mid-way.
/// - **`clock`**: Time source, for tests (default: [DateTime.now]).
class AppStoreTokenProvider {
  /// Creates a token provider.
  AppStoreTokenProvider(
    this.apiKey, {
    this.lifetime = const Duration(minutes: 20),
    this.refreshMargin = const Duration(minutes: 1),
    @visibleForTesting DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    if (lifetime > const Duration(minutes: 20) || lifetime <= Duration.zero) {
      throw ArgumentError.value(
        lifetime,
        'lifetime',
        'App Store Connect rejects tokens valid for more than 20 minutes',
      );
    }
  }

  /// Audience claim Apple requires on every token.
  static const audience = 'appstoreconnect-v1';

  /// The key used to sign tokens.
  final AppStoreApiKey apiKey;

  /// How long each token is valid.
  final Duration lifetime;

  /// How long before expiry a fresh token is minted.
  final Duration refreshMargin;

  final DateTime Function() _clock;

  String? _token;
  DateTime? _expiresAt;

  /// A currently valid bearer token, signing a new one only when needed.
  ///
  /// Throws [StoreAuthException] if the `.p8` key cannot be parsed or signed
  /// with — the underlying failures come out of the crypto layer naming
  /// neither the key nor the store.
  String token() {
    final now = _clock();
    final cached = _token;
    final expiry = _expiresAt;
    if (cached != null && expiry != null && now.isBefore(expiry)) {
      return cached;
    }

    // `iat` and `exp` are set here rather than left to `sign`'s `expiresIn`,
    // which reads the wall clock. Deriving them from the same clock that
    // drives the cache keeps the token's own expiry and the cache's view of
    // it from drifting apart.
    final issuedAt = now.toUtc();
    final jwt = JWT(
      <String, dynamic>{
        'iss': apiKey.issuerId,
        'aud': audience,
        'iat': _epochSeconds(issuedAt),
        'exp': _epochSeconds(issuedAt.add(lifetime)),
      },
      header: <String, dynamic>{
        'alg': 'ES256',
        'kid': apiKey.keyId,
        'typ': 'JWT',
      },
    );

    final String signed;
    try {
      signed = jwt.sign(
        ECPrivateKey(apiKey.privateKey),
        algorithm: JWTAlgorithm.ES256,
        noIssueAt: true,
      );
    } on Exception catch (error) {
      // The failure can surface as a JWTException from the signer or as a
      // bare FormatException from the base64 decode inside the PEM parser,
      // neither of which names the key or the store.
      throw StoreAuthException(
        'Could not sign an App Store Connect token with key '
        '"${apiKey.keyId}": $error. The .p8 must be the EC private key '
        'downloaded from App Store Connect.',
        store: Store.appStore,
      );
    }

    _token = signed;
    _expiresAt = now.add(lifetime - refreshMargin);
    return signed;
  }

  /// Drops the cached token so the next [token] call signs a fresh one.
  ///
  /// Used when Apple answers `401`, which can happen before the local expiry
  /// if the key is revoked mid-run.
  void invalidate() {
    _token = null;
    _expiresAt = null;
  }

  static int _epochSeconds(DateTime moment) =>
      moment.millisecondsSinceEpoch ~/ 1000;
}
