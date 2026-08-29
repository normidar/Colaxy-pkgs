import 'package:http/http.dart' as http;
import 'package:zaim_api/src/json_utils.dart';
import 'package:zaim_api/src/models/default_account.dart';
import 'package:zaim_api/src/models/default_category.dart';
import 'package:zaim_api/src/models/default_genre.dart';
import 'package:zaim_api/src/models/zaim_currency.dart';
import 'package:zaim_api/src/zaim_transport.dart';

/// Zaim's public master data: `/v2/account`, `/v2/category`, `/v2/genre`, and
/// `/v2/currency`.
///
/// None of these need authentication or a scope, so they can be called before
/// the user has authorized anything — useful for populating pickers on a
/// first-run screen. They still go through the same HTTP and error handling
/// as the authenticated endpoints.
///
/// Prefer `ZaimClient.defaults()` over constructing this directly; both are
/// equivalent.
///
/// ## Parameters
///
/// ### Optional
/// - **httpClient**: Inject a client for tests; when omitted one is created
///   and [close] disposes it (default: `null`).
///
/// ## Example
///
/// ```dart
/// final defaults = ZaimClient.defaults();
/// for (final currency in await defaults.currencies()) {
///   print('${currency.currencyCode} ${currency.unit} (${currency.point} dp)');
/// }
/// defaults.close();
/// ```
class DefaultApi {
  /// Creates an unauthenticated API over the given client, or over a client
  /// this object creates and [close] disposes.
  factory DefaultApi({http.Client? httpClient}) {
    final owned = httpClient == null ? http.Client() : null;
    return DefaultApi._(
      ZaimTransport(httpClient ?? owned!, ownedClient: owned),
    );
  }

  const DefaultApi._(this._transport);

  final ZaimTransport _transport;

  /// `GET /v2/account` — the default account master.
  ///
  /// **Authentication:** not required. **Scope:** none.
  Future<List<DefaultAccount>> accounts() async {
    final json = await _transport.get('/v2/account');
    return asMapList(json, 'accounts')
        .map(DefaultAccount.fromJson)
        .toList(growable: false);
  }

  /// `GET /v2/category` — the default category master.
  ///
  /// **Authentication:** not required. **Scope:** none.
  Future<List<DefaultCategory>> categories() async {
    final json = await _transport.get('/v2/category');
    return asMapList(json, 'categories')
        .map(DefaultCategory.fromJson)
        .toList(growable: false);
  }

  /// `GET /v2/genre` — the default genre master.
  ///
  /// **Authentication:** not required. **Scope:** none.
  Future<List<DefaultGenre>> genres() async {
    final json = await _transport.get('/v2/genre');
    return asMapList(json, 'genres')
        .map(DefaultGenre.fromJson)
        .toList(growable: false);
  }

  /// `GET /v2/currency` — the currency master.
  ///
  /// **Authentication:** not required. **Scope:** none.
  ///
  /// [ZaimCurrency.point] is the currency's decimal places; it is `0` for
  /// JPY, which is why every amount in this package is an `int`.
  Future<List<ZaimCurrency>> currencies() async {
    final json = await _transport.get('/v2/currency');
    return asMapList(json, 'currencies')
        .map(ZaimCurrency.fromJson)
        .toList(growable: false);
  }

  /// Closes the HTTP client this object created itself. Does nothing when a
  /// client was injected.
  void close() => _transport.close();
}
