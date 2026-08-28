import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:googleapis/androidpublisher/v3.dart' as play;
import 'package:test/test.dart';

play.Review _review({
  String? reviewId = 'gp:AOqpTOG',
  String? authorName = 'Kenji',
  List<play.Comment>? comments,
}) => play.Review(
  reviewId: reviewId,
  authorName: authorName,
  comments: comments,
);

play.Comment _userComment({
  int? starRating = 2,
  String? text = 'Battery drain since 3.0.',
  String? seconds = '1787212800',
  int? nanos = 500000000,
}) => play.Comment(
  userComment: play.UserComment(
    starRating: starRating,
    text: text,
    reviewerLanguage: 'ja',
    appVersionName: '3.0.1',
    androidOsVersion: 34,
    device: 'oriole',
    thumbsUpCount: 7,
    thumbsDownCount: 1,
    lastModified: play.Timestamp(seconds: seconds, nanos: nanos),
  ),
);

void main() {
  group('PlayReviewMapper.review', () {
    test('maps the nested user comment onto the unified model', () {
      final review = PlayReviewMapper.review(
        _review(comments: [_userComment()]),
      );

      expect(review.store, Store.googlePlay);
      expect(review.id, 'gp:AOqpTOG');
      expect(review.rating, 2);
      expect(review.body, 'Battery drain since 3.0.');
      expect(review.authorName, 'Kenji');
      expect(review.languageCode, 'ja');
      expect(review.appVersion, '3.0.1');
      expect(review.device, 'oriole');
      expect(review.osVersion, '34');
      expect(review.thumbsUp, 7);
      expect(review.thumbsDown, 1);
    });

    test('reports the time as updatedAt, never createdAt', () {
      // Google only sends a last-modified time. Filling createdAt with it
      // would make a Play review that was edited today look newly written.
      final review = PlayReviewMapper.review(
        _review(comments: [_userComment()]),
      );

      expect(review.createdAt, isNull);
      expect(review.updatedAt, DateTime.utc(2026, 8, 20, 8, 0, 0, 500));
      expect(review.timestamp, review.updatedAt);
    });

    test('finds the comments regardless of their order in the list', () {
      // A Review can hold several comments and the docs do not promise the
      // user comment comes first.
      final review = PlayReviewMapper.review(
        _review(
          comments: [
            play.Comment(
              developerComment: play.DeveloperComment(
                text: 'Try 3.0.2, it should be better.',
                lastModified: play.Timestamp(seconds: '1787299200'),
              ),
            ),
            _userComment(),
          ],
        ),
      );

      expect(review.rating, 2);
      expect(review.hasReply, isTrue);
      expect(review.reply!.body, 'Try 3.0.2, it should be better.');
      expect(review.reply!.store, Store.googlePlay);
      expect(review.reply!.state, ReviewReplyState.published);
      expect(review.reply!.id, isNull);
    });

    test('survives a review with no comments at all', () {
      final review = PlayReviewMapper.review(_review());

      expect(review.rating, 0);
      expect(review.body, isNull);
      expect(review.hasReply, isFalse);
      expect(review.updatedAt, isNull);
    });
  });

  group('PlayReviewMapper.timestamp', () {
    test('parses the int64 seconds field, which arrives as a string', () {
      expect(
        PlayReviewMapper.timestamp(play.Timestamp(seconds: '1787212800')),
        DateTime.utc(2026, 8, 20, 8),
      );
    });

    test('adds sub-second precision from nanos', () {
      expect(
        PlayReviewMapper.timestamp(
          play.Timestamp(seconds: '1787212800', nanos: 250000000),
        ),
        DateTime.utc(2026, 8, 20, 8, 0, 0, 250),
      );
    });

    test('returns null rather than the epoch for an unparseable value', () {
      // Epoch-zero would sort to the beginning of time and read as a real
      // date, which is worse than an obvious null.
      expect(PlayReviewMapper.timestamp(null), isNull);
      expect(PlayReviewMapper.timestamp(play.Timestamp()), isNull);
      expect(PlayReviewMapper.timestamp(play.Timestamp(seconds: 'x')), isNull);
    });
  });

  group('PlayReviewMapper.replyResult', () {
    test('maps a reply write result', () {
      final reply = PlayReviewMapper.replyResult(
        play.ReviewReplyResult(
          replyText: 'Thanks for the report.',
          lastEdited: play.Timestamp(seconds: '1787299200'),
        ),
      );

      expect(reply.body, 'Thanks for the report.');
      expect(reply.store, Store.googlePlay);
      expect(reply.lastModified, DateTime.utc(2026, 8, 21, 8));
    });
  });
}
