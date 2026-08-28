import 'dart:convert';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:test/test.dart';

/// A trimmed but otherwise verbatim `customerReviews` page, including the
/// `included` array Apple sends when `include=response` is requested.
const _page = '''
{
  "data": [
    {
      "type": "customerReviews",
      "id": "00000000-1111-2222-3333-444444444444",
      "attributes": {
        "rating": 1,
        "title": "Crashes on launch",
        "body": "Opens then closes immediately since the update.",
        "reviewerNickname": "yuki",
        "createdDate": "2026-08-20T04:15:22-07:00",
        "territory": "JPN"
      },
      "relationships": {
        "response": {
          "data": { "type": "customerReviewResponses", "id": "resp-1" }
        }
      }
    },
    {
      "type": "customerReviews",
      "id": "55555555-6666-7777-8888-999999999999",
      "attributes": {
        "rating": 5,
        "title": "Great",
        "body": "",
        "reviewerNickname": "sam",
        "createdDate": "2026-08-21T09:00:00Z",
        "territory": "USA"
      },
      "relationships": { "response": { "data": null } }
    }
  ],
  "included": [
    {
      "type": "customerReviewResponses",
      "id": "resp-1",
      "attributes": {
        "responseBody": "Sorry! Fixed in 2.4.1.",
        "lastModifiedDate": "2026-08-20T11:00:00Z",
        "state": "PENDING_PUBLISH"
      }
    }
  ],
  "links": { "next": "https://api.appstoreconnect.apple.com/v1/apps/1/x?c=2" },
  "meta": { "paging": { "total": 412, "limit": 2 } }
}
''';

void main() {
  final json = jsonDecode(_page) as Map<String, dynamic>;
  final data = (json['data'] as List).cast<Map<String, dynamic>>();
  final responses = AppStoreReviewMapper.includedResponses(json['included']);

  group('AppStoreReviewMapper.review', () {
    test('maps attributes onto the unified model', () {
      final review = AppStoreReviewMapper.review(
        data.first,
        responsesById: responses,
      );

      expect(review.store, Store.appStore);
      expect(review.id, '00000000-1111-2222-3333-444444444444');
      expect(review.rating, 1);
      expect(review.title, 'Crashes on launch');
      expect(review.body, 'Opens then closes immediately since the update.');
      expect(review.authorName, 'yuki');
      expect(review.territory, 'JPN');
    });

    test('normalises createdDate to UTC', () {
      final review = AppStoreReviewMapper.review(data.first);

      // The payload is -07:00; storing it as-is would make reviews from two
      // storefronts sort against each other wrongly.
      expect(review.createdAt, DateTime.utc(2026, 8, 20, 11, 15, 22));
      expect(review.createdAt!.isUtc, isTrue);
    });

    test('attaches the reply from the included array', () {
      final review = AppStoreReviewMapper.review(
        data.first,
        responsesById: responses,
      );

      expect(review.hasReply, isTrue);
      expect(review.reply!.id, 'resp-1');
      expect(review.reply!.body, 'Sorry! Fixed in 2.4.1.');
      expect(review.reply!.state, ReviewReplyState.pendingPublish);
      expect(review.reply!.lastModified, DateTime.utc(2026, 8, 20, 11));
    });

    test('reads as unanswered when the relationship data is null', () {
      final review = AppStoreReviewMapper.review(
        data[1],
        responsesById: responses,
      );

      expect(review.hasReply, isFalse);
      expect(review.reply, isNull);
    });

    test('maps an empty body to null rather than an empty string', () {
      // `body: ""` and "no body" are the same thing to a caller, and only one
      // of them survives a `?? 'no text'` fallback.
      expect(AppStoreReviewMapper.review(data[1]).body, isNull);
    });

    test('survives a resource with no attributes at all', () {
      final review = AppStoreReviewMapper.review(<String, dynamic>{
        'type': 'customerReviews',
        'id': 'bare',
      });

      expect(review.id, 'bare');
      expect(review.rating, 0);
      expect(review.title, isNull);
      expect(review.createdAt, isNull);
    });
  });

  group('AppStoreReviewMapper.includedResponses', () {
    test('indexes only customerReviewResponses', () {
      final mixed = AppStoreReviewMapper.includedResponses([
        {'type': 'territories', 'id': 'JPN'},
        {'type': 'customerReviewResponses', 'id': 'resp-1'},
      ]);

      expect(mixed.keys, ['resp-1']);
    });

    test('returns empty for a missing or malformed included array', () {
      expect(AppStoreReviewMapper.includedResponses(null), isEmpty);
      expect(AppStoreReviewMapper.includedResponses('nonsense'), isEmpty);
    });
  });

  group('AppStoreReviewMapper.replyState', () {
    test('maps the documented states', () {
      expect(
        AppStoreReviewMapper.replyState('PUBLISHED'),
        ReviewReplyState.published,
      );
      expect(
        AppStoreReviewMapper.replyState('PENDING_PUBLISH'),
        ReviewReplyState.pendingPublish,
      );
    });

    test('maps an unknown state to unknown instead of throwing', () {
      // Apple adds enum members without notice; a new one must not take down
      // a whole page of otherwise-valid reviews.
      expect(
        AppStoreReviewMapper.replyState('SOME_FUTURE_STATE'),
        ReviewReplyState.unknown,
      );
      expect(AppStoreReviewMapper.replyState(null), ReviewReplyState.unknown);
    });
  });
}
