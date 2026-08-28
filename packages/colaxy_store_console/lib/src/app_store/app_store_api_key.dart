import 'dart:io';

import 'package:colaxy_store_console/src/core/store.dart';
import 'package:colaxy_store_console/src/core/store_console_exception.dart';

/// An App Store Connect API key: the `.p8` private key and its two IDs.
///
/// Create one in App Store Connect under **Users and Access → Integrations →
/// App Store Connect API**, on the **Team Keys** tab. The `.p8` file
/// downloads exactly once, so keep it somewhere you can restore from.
///
/// The role decides what the key reaches, and no narrow role covers
/// everything: **Customer Support** reads and answers reviews,
/// **Sales**/**Finance** read sales reports, and only **Admin** does both.
/// An *individual* key cannot reach the sales endpoints at all, whatever its
/// owner's role — which is why the Team Keys tab matters. See the README for
/// the full table.
///
/// ## Parameters
///
/// ### Required
/// - **[keyId]**: The 10-character key ID, shown next to the key in App Store
///   Connect. Becomes the JWT's `kid` header.
/// - **[issuerId]**: The team's issuer ID, a UUID shown above the key list.
///   Becomes the JWT's `iss` claim.
/// - **[privateKey]**: The PEM contents of the `.p8` file, including the
///   `-----BEGIN PRIVATE KEY-----` lines.
///
/// ## Example
///
/// ```dart
/// final key = AppStoreApiKey.fromP8File(
///   keyId: 'ABCD123456',
///   issuerId: '69a6de70-....-....-....-1f2c3d4e5f60',
///   path: 'secrets/AuthKey_ABCD123456.p8',
/// );
/// ```
class AppStoreApiKey {
  /// Creates a key from a PEM string already in memory.
  ///
  /// Prefer this in CI, where the key usually arrives as an environment
  /// variable rather than a file.
  AppStoreApiKey({
    required this.keyId,
    required this.issuerId,
    required String privateKey,
  }) : privateKey = _normalise(privateKey) {
    if (keyId.isEmpty) {
      throw const StoreAuthException(
        'keyId is empty. It is the 10-character ID shown next to the key in '
        'App Store Connect.',
        store: Store.appStore,
      );
    }
    if (issuerId.isEmpty) {
      throw const StoreAuthException(
        'issuerId is empty. It is the UUID shown above the key list in App '
        'Store Connect.',
        store: Store.appStore,
      );
    }
    if (!this.privateKey.contains('-----BEGIN')) {
      throw const StoreAuthException(
        'privateKey does not look like PEM: no "-----BEGIN" header. Pass the '
        'whole contents of the .p8 file, not just the base64 body.',
        store: Store.appStore,
      );
    }
  }

  /// Reads the private key from a `.p8` file on disk.
  ///
  /// Throws [StoreAuthException] if [path] does not exist, rather than the
  /// bare `FileSystemException` that names no cause.
  factory AppStoreApiKey.fromP8File({
    required String keyId,
    required String issuerId,
    required String path,
  }) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StoreAuthException(
        'No App Store Connect private key at "$path".',
        store: Store.appStore,
      );
    }
    return AppStoreApiKey(
      keyId: keyId,
      issuerId: issuerId,
      privateKey: file.readAsStringSync(),
    );
  }

  /// The 10-character key ID. Sent as the JWT `kid` header.
  final String keyId;

  /// The team's issuer UUID. Sent as the JWT `iss` claim.
  final String issuerId;

  /// The PEM-encoded EC private key.
  final String privateKey;

  /// Undoes the newline mangling a PEM key picks up in transit.
  ///
  /// CI secret stores routinely hand back a key with literal `\n` sequences
  /// or CRLF line endings; either makes the PEM parser fail with a message
  /// that points at the crypto layer instead of at the secret.
  static String _normalise(String pem) =>
      pem.replaceAll(r'\n', '\n').replaceAll('\r\n', '\n').trim();

  @override
  String toString() => 'AppStoreApiKey($keyId)';
}
