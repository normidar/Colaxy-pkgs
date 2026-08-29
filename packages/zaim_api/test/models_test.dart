import 'package:test/test.dart';
import 'package:zaim_api/zaim_api.dart';

import 'fixtures.dart';

void main() {
  group('ZaimUser.fromJson', () {
    final user = ZaimUser.fromJson(
      decode(userVerifyJson)['me'] as Map<String, dynamic>,
    );

    test('reads every documented field', () {
      expect(user.id, 10000000);
      expect(user.login, 'XXXXXXX');
      expect(user.name, 'MyName');
      expect(user.inputCount, 100);
      expect(user.dayCount, 10);
      expect(user.repeatCount, 2);
      expect(user.day, 1);
      expect(user.week, 3);
      expect(user.month, 7);
      expect(user.currencyCode, 'JPY');
      expect(user.profileImageUrl, 'http://xxx.xxxx/yyy.jpg');
      expect(user.coverImageUrl, 'http://xxx.xxxx/xxx.jpg');
    });

    test('parses profile_modified as the JST instant it denotes', () {
      // 2011-11-07 16:47:43 JST is 07:47:43 UTC the same day.
      expect(user.profileModified, DateTime.utc(2011, 11, 7, 7, 47, 43));
    });

    test('round-trips through toJson', () {
      expect(ZaimUser.fromJson(user.toJson()), user);
      expect(user.toJson()['profile_modified'], '2011-11-07 16:47:43');
    });
  });

  group('MoneyRecord.fromJson', () {
    final record = MoneyRecord.fromJson(
      (decode(moneyListJson)['money'] as List).first as Map<String, dynamic>,
    );

    test('reads every documented field', () {
      expect(record.id, 381);
      expect(record.mode, MoneyMode.income);
      expect(record.userId, 1);
      expect(record.date, DateTime(2011, 11, 7));
      expect(record.categoryId, 11);
      expect(record.toAccountId, 34555);
      expect(record.amount, 10000);
      expect(record.comment, isEmpty);
      expect(record.active, 1);
      expect(record.isActive, isTrue);
      expect(record.name, isEmpty);
      expect(record.place, isEmpty);
      expect(record.created, DateTime.utc(2011, 11, 6, 16, 10, 50));
      expect(record.currencyCode, 'JPY');
    });

    test('maps the 0 foreign keys to null', () {
      expect(record.genreId, isNull, reason: 'genre_id was 0');
      expect(record.fromAccountId, isNull, reason: 'from_account_id was 0');
      expect(record.receiptId, isNull, reason: 'receipt_id was 0');
    });

    test('restores the 0 sentinels in toJson', () {
      final json = record.toJson();
      expect(json['genre_id'], 0);
      expect(json['from_account_id'], 0);
      expect(json['receipt_id'], 0);
      expect(json['to_account_id'], 34555);
      expect(json['date'], '2011-11-07');
      expect(MoneyRecord.fromJson(json), record);
    });

    test('tolerates ids and amounts sent as strings', () {
      final loose = MoneyRecord.fromJson(const {
        'id': '381',
        'mode': 'payment',
        'user_id': '1',
        'date': '2011-11-07',
        'category_id': '11',
        'genre_id': '0',
        'amount': '10000',
      });
      expect(loose.id, 381);
      expect(loose.userId, 1);
      expect(loose.amount, 10000);
      expect(loose.genreId, isNull);
    });

    test('ignores unexpected extra fields', () {
      final json = decode(moneyListJson)['money'] as List;
      final extended = Map<String, dynamic>.from(
        json.first as Map<String, dynamic>,
      )..['a_field_zaim_added_later'] = {'nested': true};
      expect(MoneyRecord.fromJson(extended), record);
    });

    test('rejects an unknown mode', () {
      expect(
        () => MoneyRecord.fromJson(const {'id': 1, 'mode': 'refund'}),
        throwsFormatException,
      );
    });
  });

  group('MoneyWriteResult.fromJson', () {
    test('parses a create response with a place', () {
      final result = MoneyWriteResult.fromJson(decode(moneyCreateJson));
      expect(result.id, 11820767);
      expect(result.modified, DateTime.utc(2013, 7, 8, 12, 4, 54));
      expect(result.placeUid, 'zm-098f6bcd4621d373');
      expect(result.requested, DateTime.utc(2011, 5, 12, 16, 25, 27));
      expect(result.user.inputCount, 12);
      expect(result.user.repeatCount, 1);
      expect(result.user.dayCount, 10);
      expect(result.user.dataModified, DateTime.utc(2013, 7, 8, 12, 4, 56));

      final place = result.place!;
      expect(place.id, 58);
      expect(place.userId, 1);
      expect(place.genreId, 10101);
      expect(place.categoryId, 7);
      expect(place.accountId, 3);
      expect(place.mode, MoneyMode.payment);
      expect(place.placeUid, 'zm-098f6bcd4621d373');
      expect(place.service, 'place');
      expect(place.name, 'test');
      expect(place.originalName, 'test');
      expect(place.tel, isEmpty);
      expect(place.count, 2);
      expect(place.calcFlag, 10);
      expect(place.editFlag, 0);
      expect(place.isActive, isTrue);
      expect(place.modified, DateTime.utc(2017, 6, 28, 9, 24, 51));
      expect(place.created, DateTime.utc(2016, 12, 7, 14, 37, 48));
    });

    test('maps the place 0 foreign keys to null', () {
      final place = MoneyWriteResult.fromJson(decode(moneyCreateJson)).place!;
      expect(place.transferAccountId, isNull);
      expect(place.placePatternId, isNull);
    });

    test('parses a create response without a place', () {
      final result =
          MoneyWriteResult.fromJson(decode(moneyCreateWithoutPlaceJson));
      expect(result.id, 11820767);
      expect(result.place, isNull);
      expect(result.placeUid, isNull);
    });

    test('parses an update response, whose user has no data_modified', () {
      final result = MoneyWriteResult.fromJson(decode(moneyUpdateJson));
      expect(result.id, 1506);
      expect(result.modified, DateTime.utc(2013, 6, 10, 2, 37, 18));
      expect(result.user.repeatCount, 2);
      expect(result.user.dayCount, 50);
      expect(result.user.inputCount, 376);
      expect(result.user.dataModified, isNull);
    });

    test('parses a delete response', () {
      final result = MoneyWriteResult.fromJson(decode(moneyDeleteJson));
      expect(result.id, 1504);
      expect(result.user.inputCount, 352);
      expect(result.place, isNull);
    });
  });

  group('ZaimCategory.fromJson', () {
    test('parses the documented sample', () {
      final category = ZaimCategory.fromJson(
        (decode(categoryListJson)['categories'] as List).first
            as Map<String, dynamic>,
      );
      expect(category.id, 12093);
      expect(category.name, 'Food');
      expect(category.mode, MoneyMode.payment);
      expect(category.sort, 1);
      expect(category.parentCategoryId, 101);
      expect(category.isActive, isTrue);
      expect(category.modified, DateTime.utc(2012, 12, 31, 15));
      expect(ZaimCategory.fromJson(category.toJson()), category);
    });

    test('maps parent_category_id 0 to null', () {
      final category = ZaimCategory.fromJson(
        const {'id': 1, 'name': 'x', 'parent_category_id': 0},
      );
      expect(category.parentCategoryId, isNull);
    });
  });

  group('ZaimGenre.fromJson', () {
    test('parses the documented sample', () {
      final genre = ZaimGenre.fromJson(
        (decode(genreListJson)['genres'] as List).first as Map<String, dynamic>,
      );
      expect(genre.id, 12093);
      expect(genre.name, 'Grocery');
      expect(genre.sort, 1);
      expect(genre.isActive, isTrue);
      expect(genre.categoryId, 101);
      expect(genre.parentGenreId, 10101);
      expect(genre.modified, DateTime.utc(2012, 12, 31, 15));
      expect(ZaimGenre.fromJson(genre.toJson()), genre);
    });
  });

  group('ZaimAccount.fromJson', () {
    final account = ZaimAccount.fromJson(
      (decode(accountListJson)['accounts'] as List).first
          as Map<String, dynamic>,
    );

    test('parses the documented sample', () {
      expect(account.id, 15497739);
      expect(account.name, 'Credit card');
      expect(account.modified, DateTime.utc(2022, 3, 15, 4, 39, 52));
      expect(account.sort, 8);
      expect(account.isActive, isTrue);
      expect(account.localId, 15497739);
      expect(ZaimAccount.fromJson(account.toJson()), account);
    });

    test('maps the 0 foreign keys to null', () {
      expect(account.websiteId, isNull);
      expect(account.parentAccountId, isNull);
    });
  });

  group('public master data', () {
    test('DefaultAccount.fromJson', () {
      final accounts = (decode(defaultAccountJson)['accounts'] as List)
          .map((e) => DefaultAccount.fromJson(e as Map<String, dynamic>))
          .toList();
      expect(accounts, [
        const DefaultAccount(id: 1, name: 'Wallet'),
        const DefaultAccount(id: 2, name: 'Savings'),
      ]);
    });

    test('DefaultCategory.fromJson', () {
      final categories = (decode(defaultCategoryJson)['categories'] as List)
          .map((e) => DefaultCategory.fromJson(e as Map<String, dynamic>))
          .toList();
      expect(categories, [
        const DefaultCategory(id: 101, name: 'Food', mode: MoneyMode.payment),
        const DefaultCategory(id: 102, name: 'House', mode: MoneyMode.payment),
      ]);
    });

    test('DefaultGenre.fromJson', () {
      final genres = (decode(defaultGenreJson)['genres'] as List)
          .map((e) => DefaultGenre.fromJson(e as Map<String, dynamic>))
          .toList();
      expect(genres, [
        const DefaultGenre(id: 10101, categoryId: 101, name: 'Grocery'),
        const DefaultGenre(id: 10102, categoryId: 101, name: 'Breakfast'),
      ]);
    });

    test('ZaimCurrency.fromJson keeps JPY at zero decimal places', () {
      final currencies = (decode(currencyJson)['currencies'] as List)
          .map((e) => ZaimCurrency.fromJson(e as Map<String, dynamic>))
          .toList();
      expect(currencies.first.currencyCode, 'AUD');
      expect(currencies.first.point, 2);
      expect(currencies.last.currencyCode, 'JPY');
      expect(currencies.last.unit, '￥');
      expect(currencies.last.name, 'Japanese YEN');
      expect(currencies.last.point, 0);
    });
  });

  group('MoneyMode', () {
    test('parses the three wire names', () {
      expect(MoneyMode.parse('payment'), MoneyMode.payment);
      expect(MoneyMode.parse('income'), MoneyMode.income);
      expect(MoneyMode.parse('transfer'), MoneyMode.transfer);
    });

    test('tryParse returns null for anything else', () {
      expect(MoneyMode.tryParse('refund'), isNull);
      expect(MoneyMode.tryParse(null), isNull);
    });
  });

  group('credentials', () {
    test('round-trip through JSON', () {
      expect(
        ZaimCredentials.fromJson(testCredentials.toJson()),
        testCredentials,
      );
    });

    test('toString never prints a secret', () {
      final text = testCredentials.toString();
      expect(text, contains('TEST_CONSUMER_KEY'));
      expect(text, isNot(contains('TEST_CONSUMER_SECRET')));
      expect(text, isNot(contains('TEST_ACCESS_TOKEN_SECRET')));
    });

    test('ZaimRequestToken round-trips and hides its secret', () {
      const token = ZaimRequestToken(
        token: 'TEST_REQUEST_TOKEN',
        tokenSecret: 'TEST_REQUEST_TOKEN_SECRET',
      );
      expect(ZaimRequestToken.fromJson(token.toJson()), token);
      expect(token.toString(), isNot(contains('TEST_REQUEST_TOKEN_SECRET')));
    });
  });
}
