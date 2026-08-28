import 'package:colaxy_store_console/src/core/review_reply.dart';
import 'package:colaxy_store_console/src/core/store.dart';
import 'package:colaxy_store_console/src/core/store_review.dart';
import 'package:googleapis/androidpublisher/v3.dart' as play;

/// Turns `googleapis` Android Publisher models into this package's models.
///
/// Google nests the interesting fields two levels down, under
/// `Review.comments[].userComment`, and a review can in principle hold
/// several comments. In practice the first one carries the user's review and
/// the developer reply rides alongside it, so that is what this reads —
/// falling back to a scan of the whole list rather than assuming index 0.
abstract final class PlayReviewMapper {
  /// Maps one `Review` to a [StoreReview].
  static StoreReview review(play.Review source) {
    final userComment = _firstUserComment(source);
    final developerComment = _firstDeveloperComment(source);

    return StoreReview(
      store: Store.googlePlay,
      id: source.reviewId ?? '',
      rating: userComment?.starRating ?? 0,
      body: userComment?.text,
      authorName: source.authorName,
      // Google reports only a last-modified time, never a creation time, so
      // `createdAt` stays null rather than being filled with a wrong value.
      updatedAt: timestamp(userComment?.lastModified),
      languageCode: userComment?.reviewerLanguage,
      appVersion: userComment?.appVersionName,
      device: userComment?.device,
      osVersion: userComment?.androidOsVersion?.toString(),
      thumbsUp: userComment?.thumbsUpCount ?? 0,
      thumbsDown: userComment?.thumbsDownCount ?? 0,
      reply: developerComment == null ? null : reply(developerComment),
      raw: source,
    );
  }

  /// Maps one `DeveloperComment` to a [ReviewReply].
  ///
  /// Play replies go live immediately and have no resource ID of their own,
  /// so the state is always [ReviewReplyState.published] and the ID is null.
  static ReviewReply reply(play.DeveloperComment source) => ReviewReply(
    store: Store.googlePlay,
    body: source.text ?? '',
    lastModified: timestamp(source.lastModified),
  );

  /// Maps a reply-write result to a [ReviewReply].
  static ReviewReply replyResult(play.ReviewReplyResult source) => ReviewReply(
    store: Store.googlePlay,
    body: source.replyText ?? '',
    lastModified: timestamp(source.lastEdited),
  );

  /// Converts Google's `{seconds, nanos}` timestamp to a [DateTime].
  ///
  /// `seconds` arrives as a string because it is an int64, so it is parsed
  /// rather than cast; an unparseable value yields `null` instead of an
  /// epoch-zero date that would silently sort to the beginning of time.
  static DateTime? timestamp(play.Timestamp? source) {
    if (source == null) return null;
    final seconds = int.tryParse(source.seconds ?? '');
    if (seconds == null) return null;
    final millis = seconds * 1000 + (source.nanos ?? 0) ~/ 1000000;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  static play.UserComment? _firstUserComment(play.Review source) {
    for (final comment in source.comments ?? const <play.Comment>[]) {
      if (comment.userComment != null) return comment.userComment;
    }
    return null;
  }

  static play.DeveloperComment? _firstDeveloperComment(play.Review source) {
    for (final comment in source.comments ?? const <play.Comment>[]) {
      if (comment.developerComment != null) return comment.developerComment;
    }
    return null;
  }
}
