/// A Dart client for the Zaim REST API v2.1.0.
///
/// Zaim (<https://zaim.net>) is a Japanese personal household-accounting
/// service. This library wraps its OAuth 1.0a API: the three-legged token
/// dance, money record CRUD, the user's categories, genres, and accounts, and
/// the public master data endpoints that need no credentials at all.
///
/// Two things about the API are worth knowing before you start:
///
/// - Only records the user entered **by hand** are exposed. Rows Zaim
///   imported automatically from a linked bank or card are not returned.
/// - Unless the app was registered as *permanently accessible*, the
///   permission a user grants **expires after 24 hours**.
///
/// ## Example
///
/// ```dart
/// import 'package:zaim_api/zaim_api.dart';
///
/// Future<void> main() async {
///   final client = ZaimClient(
///     credentials: const ZaimCredentials(
///       consumerKey: 'YOUR_CONSUMER_KEY',
///       consumerSecret: 'YOUR_CONSUMER_SECRET',
///       accessToken: 'USER_ACCESS_TOKEN',
///       accessTokenSecret: 'USER_ACCESS_TOKEN_SECRET',
///     ),
///   );
///   try {
///     final me = await client.user.verify();
///     print('Hello, ${me.name}');
///   } finally {
///     client.close();
///   }
/// }
/// ```
library;

export 'src/endpoints/account_api.dart' show AccountApi;
export 'src/endpoints/category_api.dart' show CategoryApi;
export 'src/endpoints/default_api.dart' show DefaultApi;
export 'src/endpoints/genre_api.dart' show GenreApi;
export 'src/endpoints/money_api.dart' show MoneyApi;
export 'src/endpoints/user_api.dart' show UserApi;
export 'src/models/default_account.dart' show DefaultAccount;
export 'src/models/default_category.dart' show DefaultCategory;
export 'src/models/default_genre.dart' show DefaultGenre;
export 'src/models/money_mode.dart' show MoneyMode;
export 'src/models/money_order.dart' show MoneyOrder;
export 'src/models/money_record.dart' show MoneyRecord;
export 'src/models/money_write_result.dart' show MoneyWriteResult;
export 'src/models/zaim_account.dart' show ZaimAccount;
export 'src/models/zaim_category.dart' show ZaimCategory;
export 'src/models/zaim_currency.dart' show ZaimCurrency;
export 'src/models/zaim_genre.dart' show ZaimGenre;
export 'src/models/zaim_place.dart' show ZaimPlace;
export 'src/models/zaim_user.dart' show ZaimUser;
export 'src/models/zaim_user_counters.dart' show ZaimUserCounters;
export 'src/zaim_auth.dart'
    show ZaimAuthFlow, ZaimCredentials, ZaimOAuthEndpoints, ZaimRequestToken;
export 'src/zaim_client.dart' show ZaimClient;
export 'src/zaim_exception.dart' show ZaimApiException, ZaimAuthException;
