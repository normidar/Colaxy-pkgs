import 'package:colaxy_store_console/src/core/review_reply.dart';
import 'package:colaxy_store_console/src/core/store.dart';

/// One user review, in a shape both stores map onto.
///
/// The two consoles model reviews differently, so a field a store does not
/// provide is `null` rather than faked. The differences worth knowing:
///
/// - **[title]** is App Store only. Google Play reviews have no title.
/// - **[territory]** is App Store only, as an ISO 3166-1 alpha-3 code.
/// - **[languageCode]**, **[device]**, **[osVersion]**, **[appVersion]**,
///   **[thumbsUp]** and **[thumbsDown]** are Google Play only.
/// - **[authorName]** is the reviewer's nickname on the App Store and their
///   display name on Google Play; either store may omit it.
/// - **[createdAt]** is the review's creation time on the App Store, but
///   Google Play only reports a *last modified* time, so on Play
///   [createdAt] is `null` and [updatedAt] carries it.
///
/// ## Parameters
///
/// ### Required
/// - **[store]**: Which store the review came from.
/// - **[id]**: Store-assigned review ID, unique within that store.
/// - **[rating]**: Star rating, 1–5.
///
/// ### Optional
/// - **[title]**, **[body]**, **[authorName]**, **[createdAt]**,
///   **[updatedAt]**, **[territory]**, **[languageCode]**, **[appVersion]**,
///   **[device]**, **[osVersion]**: see the notes above (default: `null`).
/// - **[thumbsUp]** / **[thumbsDown]**: Play "was this helpful" counts
///   (default: `0`).
/// - **[reply]**: The developer reply, if one exists (default: `null`).
/// - **[raw]**: The untouched store payload this was mapped from
///   (default: `null`).
///
/// ## Example
///
/// ```dart
/// await for (final review in console.reviews.list()) {
///   if (review.rating <= 2 && !review.hasReply) {
///     print('${review.store.displayName}: ${review.body}');
///   }
/// }
/// ```
class StoreReview {
  /// Creates a store review.
  const StoreReview({
    required this.store,
    required this.id,
    required this.rating,
    this.title,
    this.body,
    this.authorName,
    this.createdAt,
    this.updatedAt,
    this.territory,
    this.languageCode,
    this.appVersion,
    this.device,
    this.osVersion,
    this.thumbsUp = 0,
    this.thumbsDown = 0,
    this.reply,
    this.raw,
  });

  /// Which store the review came from.
  final Store store;

  /// Store-assigned review ID.
  ///
  /// Unique within its store, not across stores. Pair it with [store] if you
  /// persist reviews from both in one table.
  final String id;

  /// Star rating, 1–5.
  final int rating;

  /// Review headline. App Store only.
  final String? title;

  /// Review text.
  ///
  /// Google Play only exposes reviews that have text, so a Play review always
  /// has one. An App Store review may be a bare rating with no body.
  final String? body;

  /// The reviewer's display name or nickname.
  final String? authorName;

  /// When the review was written. App Store only — see the class docs.
  final DateTime? createdAt;

  /// When the review was last edited.
  final DateTime? updatedAt;

  /// ISO 3166-1 alpha-3 storefront code, e.g. `JPN`. App Store only.
  final String? territory;

  /// BCP-47 language the review was written in. Google Play only.
  final String? languageCode;

  /// App version the reviewer was running. Google Play only.
  final String? appVersion;

  /// Device the review came from, as a Play device codename. Play only.
  final String? device;

  /// Android version the reviewer was running, as an API level. Play only.
  final String? osVersion;

  /// How many users marked the review helpful. Google Play only.
  final int thumbsUp;

  /// How many users marked the review unhelpful. Google Play only.
  final int thumbsDown;

  /// The developer's reply, if there is one.
  final ReviewReply? reply;

  /// The untouched store payload this was mapped from.
  ///
  /// For Google Play this is a `googleapis` `Review`; for the App Store it is
  /// the decoded JSON:API resource `Map`. Reach for it when you need a field
  /// this package does not model yet.
  final Object? raw;

  /// Whether a developer has already replied.
  bool get hasReply => reply != null;

  /// The best available timestamp for the review.
  ///
  /// [createdAt] when the store reports it, otherwise [updatedAt]. Use this
  /// to sort a merged list from both stores.
  DateTime? get timestamp => createdAt ?? updatedAt;

  @override
  String toString() =>
      'StoreReview(${store.displayName}, $id, $rating★, "${title ?? body}")';
}
