/// The response samples from the Zaim API reference (v2.1.0, 2018-07-04),
/// copied verbatim so the parsers are tested against the documented shapes
/// rather than against shapes invented for the tests.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zaim_api/zaim_api.dart';

/// `GET /v2/home/user/verify`.
const String userVerifyJson = '''
{
  "me": {
    "id": 10000000,
    "login": "XXXXXXX",
    "name": "MyName",
    "input_count": 100,
    "day_count": 10,
    "repeat_count": 2,
    "day": 1,
    "week": 3,
    "month": 7,
    "currency_code": "JPY",
    "profile_image_url": "http://xxx.xxxx/yyy.jpg",
    "cover_image_url": "http://xxx.xxxx/xxx.jpg",
    "profile_modified": "2011-11-07 16:47:43"
  },
  "requested": 1367902710
}
''';

/// `GET /v2/home/money`.
const String moneyListJson = '''
{
  "money": [
    {
      "id": 381,
      "mode": "income",
      "user_id": 1,
      "date": "2011-11-07",
      "category_id": 11,
      "genre_id": 0,
      "to_account_id": 34555,
      "from_account_id": 0,
      "amount": 10000,
      "comment": "",
      "active": 1,
      "name": "",
      "receipt_id": 0,
      "place": "",
      "created": "2011-11-07 01:10:50",
      "currency_code": "JPY"
    }
  ],
  "requested": 1321782829
}
''';

/// A money create response, with the `place` a request supplying `place`
/// triggers.
const String moneyCreateJson = '''
{
  "stamps": null,
  "banners": [],
  "money": {
    "id": 11820767,
    "modified": "2013-07-08 21:04:54",
    "place_uid": "zm-098f6bcd4621d373"
  },
  "place": {
    "id": 58, "user_id": 1, "genre_id": 10101, "category_id": 7,
    "account_id": 3, "transfer_account_id": 0, "mode": "payment",
    "place_uid": "zm-098f6bcd4621d373", "service": "place",
    "name": "test", "original_name": "test", "tel": "", "count": 2,
    "place_pattern_id": 0, "calc_flag": 10, "edit_flag": 0, "active": 1,
    "modified": "2017-06-28 18:24:51", "created": "2016-12-07 23:37:48"
  },
  "user": { "input_count": 12, "repeat_count": 1, "day_count": 10,
            "data_modified": "2013-07-08 21:04:56" },
  "requested": 1305217527
}
''';

/// A money create response without a place, exactly as documented.
const String moneyCreateWithoutPlaceJson = '''
{
  "stamps": null,
  "banners": [],
  "money": { "id": 11820767, "modified": "2013-07-08 21:04:54" },
  "user": { "input_count": 12, "repeat_count": 1, "day_count": 10,
            "data_modified": "2013-07-08 21:04:56" },
  "requested": 1305217527
}
''';

/// A money update response.
const String moneyUpdateJson = '''
{
  "money": { "id": 1506, "modified": "2013-06-10 11:37:18" },
  "user": { "repeat_count": 2, "day_count": 50, "input_count": 376 },
  "requested": 1370831848
}
''';

/// A money delete response.
const String moneyDeleteJson = '''
{
  "money": { "id": 1504, "modified": "2013-06-10 11:39:14" },
  "user": { "repeat_count": 2, "day_count": 50, "input_count": 352 },
  "requested": 1370831964
}
''';

/// `GET /v2/home/category`.
const String categoryListJson = '''
{
  "categories": [
    { "id": 12093, "name": "Food", "mode": "payment", "sort": 1,
      "parent_category_id": 101, "active": 1, "modified": "2013-01-01 00:00:00" }
  ],
  "requested": 1321795825
}
''';

/// `GET /v2/home/genre`.
const String genreListJson = '''
{
  "genres": [
    { "id": 12093, "name": "Grocery", "sort": 1, "active": 1,
      "category_id": 101, "parent_genre_id": 10101,
      "modified": "2013-01-01 00:00:00" }
  ],
  "requested": 1321795825
}
''';

/// `GET /v2/home/account`.
const String accountListJson = '''
{
  "accounts": [
    { "id": 15497739, "name": "Credit card", "modified": "2022-03-15 13:39:52",
      "sort": 8, "active": 1, "local_id": 15497739, "website_id": 0,
      "parent_account_id": 0 }
  ],
  "requested": 1669618091
}
''';

/// `GET /v2/account`.
const String defaultAccountJson = '''
{ "accounts": [ { "id": 1, "name": "Wallet" }, { "id": 2, "name": "Savings" } ],
  "requested": 1321795444 }
''';

/// `GET /v2/category`.
const String defaultCategoryJson = '''
{ "categories": [ { "id": 101, "mode": "payment", "name": "Food" },
                  { "id": 102, "mode": "payment", "name": "House" } ],
  "requested": 1321795444 }
''';

/// `GET /v2/genre`.
const String defaultGenreJson = '''
{ "genres": [ { "id": 10101, "category_id": 101, "name": "Grocery" },
              { "id": 10102, "category_id": 101, "name": "Breakfast" } ],
  "requested": 1321795444 }
''';

/// `GET /v2/currency`.
const String currencyJson = r'''
{ "currencies": [
    { "currency_code": "AUD", "unit": "$", "name": "Australian dollar", "point": 2 },
    { "currency_code": "JPY", "unit": "￥", "name": "Japanese YEN", "point": 0 } ],
  "requested": 1321796963 }
''';

/// Obvious placeholders. No real key, secret, or token appears anywhere in
/// this package.
const ZaimCredentials testCredentials = ZaimCredentials(
  consumerKey: 'TEST_CONSUMER_KEY',
  consumerSecret: 'TEST_CONSUMER_SECRET',
  accessToken: 'TEST_ACCESS_TOKEN',
  accessTokenSecret: 'TEST_ACCESS_TOKEN_SECRET',
);

/// Decodes [source] into a JSON object.
Map<String, dynamic> decode(String source) =>
    jsonDecode(source) as Map<String, dynamic>;

/// Records every request a client makes so tests can assert on the URL, the
/// method, and the form body.
class RequestLog {
  /// The requests seen so far, oldest first.
  final List<http.Request> requests = [];

  /// The most recent request. Fails loudly when nothing was sent.
  http.Request get last => requests.last;

  /// The form fields of [last], decoded from its body.
  Map<String, String> get lastFields => Uri.splitQueryString(last.body);

  /// Builds a [MockClient] that logs each request and answers with the
  /// responses [bodies] yields, in order. The final body repeats if the
  /// client sends more requests than there are bodies.
  MockClient client(List<String> bodies, {int statusCode = 200}) {
    var index = 0;
    return MockClient((request) async {
      requests.add(request);
      final body = bodies[index < bodies.length ? index : bodies.length - 1];
      index++;
      return http.Response(
        body,
        statusCode,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  }
}
