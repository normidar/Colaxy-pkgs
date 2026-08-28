/// How to order a review listing.
///
/// Only App Store Connect accepts a sort. The Google Play Developer API has
/// no sort parameter and always returns its own order, so
/// `PlayReviewsApi` ignores this — see the support matrix in the README.
enum ReviewSort {
  /// Most recently created first.
  newestFirst,

  /// Oldest first.
  oldestFirst,

  /// Five stars first.
  highestRating,

  /// One star first.
  lowestRating,
}

/// Filters and paging for a review listing.
///
/// The two APIs support different subsets of this. Where App Store Connect
/// has a server-side filter, it is used; where Google Play has none,
/// `PlayReviewsApi` applies the filter to each page after fetching it. That
/// means a Play page can come back holding fewer than [pageSize] reviews
/// while more still remain — always drive paging off the returned cursor,
/// never off the page length.
///
/// ## Parameters
///
/// ### Optional
/// - **[pageSize]**: Reviews per page (default: `null`, letting each store
///   choose; Play defaults to 10 and caps at 100, the App Store defaults to
///   20 and caps at 200).
/// - **[cursor]**: Opaque page token from a previous `ReviewPage`
///   (default: `null`, meaning start at the first page).
/// - **[sort]**: Ordering, App Store only (default: `null`).
/// - **[ratings]**: Star ratings to keep, e.g. `{1, 2}` (default: empty,
///   meaning all ratings).
/// - **[territories]**: ISO 3166-1 alpha-3 storefronts to keep, App Store
///   only (default: empty, meaning all territories).
/// - **[hasReply]**: `true` for only-replied, `false` for only-unreplied
///   (default: `null`, meaning both).
/// - **[translationLanguage]**: BCP-47 code asking Google Play to machine
///   translate review text (default: `null`, meaning original text).
///
/// ## Example
///
/// ```dart
/// // Everything that still needs an answer, worst first.
/// const query = ReviewQuery(
///   ratings: {1, 2},
///   hasReply: false,
///   sort: ReviewSort.lowestRating,
/// );
/// ```
class ReviewQuery {
  /// Creates a review query.
  const ReviewQuery({
    this.pageSize,
    this.cursor,
    this.sort,
    this.ratings = const {},
    this.territories = const {},
    this.hasReply,
    this.translationLanguage,
  }) : assert(
         pageSize == null || pageSize > 0,
         'pageSize must be positive when set',
       );

  /// Reviews per page.
  final int? pageSize;

  /// Opaque page token from a previous `ReviewPage`.
  final String? cursor;

  /// Ordering. App Store only.
  final ReviewSort? sort;

  /// Star ratings to keep. Empty means all.
  ///
  /// App Store Connect filters this server-side via `filter[rating]`. Google
  /// Play has no such filter, so it is applied per page after fetching.
  final Set<int> ratings;

  /// ISO 3166-1 alpha-3 storefronts to keep. App Store only. Empty means all.
  final Set<String> territories;

  /// Whether to keep only reviews that do, or do not, have a developer reply.
  ///
  /// App Store Connect filters this server-side via `exists[publishedResponse]`
  /// — which, note, only counts *published* responses, so a reply still
  /// pending publication reads as "no reply". Google Play applies it per page
  /// after fetching.
  final bool? hasReply;

  /// BCP-47 code asking Google Play to machine translate review text.
  ///
  /// When set, `StoreReview.body` holds the translation and the original
  /// stays available under `StoreReview.raw`. App Store only ever returns the
  /// original.
  final String? translationLanguage;

  /// Whether a review with [rating] and [reviewHasReply] passes
  /// [ratings] and [hasReply].
  ///
  /// Used by the Google Play client, which has no server-side equivalent.
  /// [territories] is not checked here — Google Play never reports a
  /// territory, so filtering on it would drop every Play review.
  bool matches({required int rating, required bool reviewHasReply}) {
    if (ratings.isNotEmpty && !ratings.contains(rating)) return false;
    if (hasReply != null && hasReply != reviewHasReply) return false;
    return true;
  }

  /// A copy of this query pointing at [cursor].
  ReviewQuery withCursor(String? cursor) => ReviewQuery(
    pageSize: pageSize,
    cursor: cursor,
    sort: sort,
    ratings: ratings,
    territories: territories,
    hasReply: hasReply,
    translationLanguage: translationLanguage,
  );
}
