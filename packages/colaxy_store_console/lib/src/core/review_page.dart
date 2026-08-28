import 'package:colaxy_store_console/src/core/store.dart';
import 'package:colaxy_store_console/src/core/store_review.dart';

/// One page of reviews, plus the cursor for the next one.
///
/// ## Parameters
///
/// ### Required
/// - **[store]**: Which store the page came from.
/// - **[reviews]**: The reviews on this page.
///
/// ### Optional
/// - **[nextCursor]**: Token for the following page (default: `null`, which
///   means this was the last page).
/// - **[total]**: Total matching reviews, when the store reports one
///   (default: `null`; App Store Connect sends it, Google Play does not).
///
/// ## Example
///
/// ```dart
/// var page = await console.reviews.listPage();
/// while (true) {
///   handle(page.reviews);
///   if (page.isLast) break;
///   page = await console.reviews.listPage(page.nextQuery()!);
/// }
/// ```
class ReviewPage {
  /// Creates a page of reviews.
  const ReviewPage({
    required this.store,
    required this.reviews,
    this.nextCursor,
    this.total,
  });

  /// Which store the page came from.
  final Store store;

  /// The reviews on this page.
  ///
  /// May be empty while [nextCursor] is still set: Google Play filters
  /// client-side, so a whole page can be filtered away with more to come.
  final List<StoreReview> reviews;

  /// Token for the following page, or `null` if this was the last one.
  final String? nextCursor;

  /// Total matching reviews, when the store reports one.
  final int? total;

  /// Whether this is the final page.
  bool get isLast => nextCursor == null;

  @override
  String toString() =>
      'ReviewPage(${store.displayName}, ${reviews.length} reviews, '
      'last: $isLast)';
}
