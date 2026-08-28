import 'dart:convert';
import 'dart:io';

import 'package:colaxy_store_console/src/core/store.dart';
import 'package:colaxy_store_console/src/core/store_console_exception.dart';
import 'package:googleapis/androidpublisher/v3.dart' show AndroidPublisherApi;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;

/// A Google Cloud service account authorised on a Play Console developer
/// account.
///
/// Setting one up, once per developer account:
///
/// 1. In Google Cloud, enable the **Google Play Android Developer API**.
/// 2. Create a service account and download its JSON key.
/// 3. In Play Console, under **Users and permissions**, invite the service
///    account's email and grant it the app permissions you need — at minimum
///    *View app information* to read reviews and *Reply to reviews* to answer
///    them.
///
/// Step 3 is the one that is easy to miss: without it every call fails with
/// `401`, even though the JSON key itself is valid.
///
/// ## Parameters
///
/// ### Required
/// - **[json]**: The decoded service-account key.
///
/// ## Example
///
/// ```dart
/// final account = PlayServiceAccount.fromFile('secrets/play-api.json');
/// ```
class PlayServiceAccount {
  /// Creates a service account from a decoded JSON key.
  PlayServiceAccount(this.json) {
    if (json['type'] != 'service_account') {
      throw StoreAuthException(
        'This JSON is not a service-account key (type is '
        '"${json['type']}"). Download the key from the service account\'s '
        'Keys tab in Google Cloud, not an OAuth client secret.',
        store: Store.googlePlay,
      );
    }
    if (json['client_email'] is! String || json['private_key'] is! String) {
      throw const StoreAuthException(
        'The service-account key is missing client_email or private_key.',
        store: Store.googlePlay,
      );
    }
  }

  /// Reads a service-account key from a JSON file on disk.
  factory PlayServiceAccount.fromFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StoreAuthException(
        'No Google Play service-account key at "$path".',
        store: Store.googlePlay,
      );
    }
    return PlayServiceAccount.fromJsonString(file.readAsStringSync());
  }

  /// Parses a service-account key from its JSON text.
  ///
  /// Use this in CI, where the key is usually an environment variable.
  factory PlayServiceAccount.fromJsonString(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw StoreAuthException(
        'The Google Play service-account key is not valid JSON: '
        '${error.message}',
        store: Store.googlePlay,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const StoreAuthException(
        'The Google Play service-account key must be a JSON object.',
        store: Store.googlePlay,
      );
    }
    return PlayServiceAccount(decoded);
  }

  /// The decoded service-account key.
  final Map<String, dynamic> json;

  /// Scope for the Google Play Developer API: reviews, releases, listings.
  static const String androidPublisherScope =
      AndroidPublisherApi.androidpublisherScope;

  /// Scope for the Play Developer Reporting API: crash rate, ANR rate, and
  /// the rest of Android vitals.
  ///
  /// This is a *different* scope from [androidPublisherScope], and a token
  /// minted for one will be rejected by the other's endpoints.
  static const reportingScope =
      'https://www.googleapis.com/auth/playdeveloperreporting';

  /// Scope for reading the developer account's Cloud Storage report bucket,
  /// where Google puts the install, rating and revenue CSVs that have no API.
  static const storageReadScope =
      'https://www.googleapis.com/auth/devstorage.read_only';

  /// The service account's email, the one to invite in Play Console.
  String get clientEmail => json['client_email'] as String;

  /// Exchanges the key for an authenticated HTTP client.
  ///
  /// The returned client refreshes its own access token, so it can be held
  /// for the lifetime of a long run. Close it when done.
  ///
  /// ## Parameters
  ///
  /// ### Optional
  /// - **`scopes`**: OAuth scopes to request (default:
  ///   `[androidPublisherScope]`). Each Google Play API needs its own — pass
  ///   several to get one client that covers them all, which saves a token
  ///   exchange per API.
  /// - **`baseClient`**: Transport the authenticated client wraps
  ///   (default: `null`, letting `googleapis_auth` create one).
  ///
  /// ## Example
  ///
  /// ```dart
  /// final client = await account.authenticate(
  ///   scopes: [
  ///     PlayServiceAccount.androidPublisherScope,
  ///     PlayServiceAccount.reportingScope,
  ///   ],
  /// );
  /// ```
  Future<http.Client> authenticate({
    List<String>? scopes,
    http.Client? baseClient,
  }) async {
    final requested = scopes ?? <String>[androidPublisherScope];
    if (requested.isEmpty) {
      throw ArgumentError.value(scopes, 'scopes', 'Cannot be empty');
    }
    try {
      return await auth.clientViaServiceAccount(
        auth.ServiceAccountCredentials.fromJson(json),
        requested,
        baseClient: baseClient,
      );
    } on Exception catch (error) {
      throw StoreAuthException(
        'Google rejected the service account "$clientEmail" for scopes '
        '${requested.join(', ')}: $error',
        store: Store.googlePlay,
      );
    }
  }

  @override
  String toString() => 'PlayServiceAccount($clientEmail)';
}
