/// One page of a JSON:API collection response from App Store Connect.
///
/// Every App Store Connect list endpoint answers with the same envelope —
/// `data`, an optional `included`, `links.next`, `meta.paging.total` — so
/// pulling those four apart belongs in one place rather than in each API.
///
/// ## Parameters
///
/// ### Required
/// - **[raw]**: The decoded response body, kept whole so callers can reach
///   fields this class does not model (`included` in particular).
class JsonApiPage {
  /// Wraps a decoded App Store Connect response.
  JsonApiPage(this.raw);

  /// The decoded response body.
  final Map<String, dynamic> raw;

  /// The `data` array, with anything that is not an object dropped.
  ///
  /// A single-resource endpoint answers with an object rather than an array;
  /// that comes back here as a one-element list, so the same code reads both.
  late final List<Map<String, dynamic>> data = _data();

  /// The `included` array, or `null` when the response has none.
  Object? get included => raw['included'];

  /// The URL of the next page, or `null` when this was the last one.
  ///
  /// Apple sends a fully-formed URL carrying every filter of the original
  /// request. It is meant to be followed verbatim, not rebuilt.
  String? get nextCursor {
    final links = raw['links'];
    if (links is! Map<String, dynamic>) return null;
    final next = links['next'];
    return next is String && next.isNotEmpty ? next : null;
  }

  /// Total matching resources, when Apple reports one.
  int? get total {
    final meta = raw['meta'];
    if (meta is! Map<String, dynamic>) return null;
    final paging = meta['paging'];
    if (paging is! Map<String, dynamic>) return null;
    final total = paging['total'];
    return total is int ? total : null;
  }

  /// Whether this is the final page.
  bool get isLast => nextCursor == null;

  List<Map<String, dynamic>> _data() {
    final data = raw['data'];
    if (data is Map<String, dynamic>) return [data];
    if (data is! List) return const [];
    return [
      for (final entry in data)
        if (entry is Map<String, dynamic>) entry,
    ];
  }

  @override
  String toString() =>
      'JsonApiPage(${data.length} resources, last: $isLast, total: $total)';
}
