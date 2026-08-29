import 'package:meta/meta.dart';
import 'package:zaim_api/src/json_utils.dart';

/// One of the user's own genres, from `GET /v2/home/genre`.
///
/// A genre is the second level below a category, and applies to payments
/// only: `POST /v2/home/money/payment` requires both `category_id` and
/// `genre_id`, while income and transfer take neither.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: The genre id to pass to the payment endpoints.
/// - **[name]**: The display name.
/// - **[categoryId]**: The category this genre sits under.
///
/// ### Optional
/// - **[sort]**: Display order (default: `0`).
/// - **[parentGenreId]**: The master genre this one derives from, `null` when
///   Zaim sent `0` (default: `null`).
/// - **[active]**: `1` while the genre is in use (default: `1`).
/// - **[modified]**: When the genre last changed (default: `null`).
@immutable
class ZaimGenre {
  /// Creates a genre.
  const ZaimGenre({
    required this.id,
    required this.name,
    required this.categoryId,
    this.sort = 0,
    this.parentGenreId,
    this.active = 1,
    this.modified,
  });

  /// Parses one element of the `genres` array.
  factory ZaimGenre.fromJson(Map<String, dynamic> json) => ZaimGenre(
        id: asInt(json, 'id'),
        name: asString(json, 'name'),
        categoryId: asInt(json, 'category_id'),
        sort: asInt(json, 'sort'),
        parentGenreId: asId(json, 'parent_genre_id'),
        active: asInt(json, 'active', fallback: 1),
        modified: asTimestamp(json, 'modified'),
      );

  /// The genre id. Pass this to the payment create and update endpoints.
  final int id;

  /// The display name.
  final String name;

  /// The category this genre belongs to.
  final int categoryId;

  /// The display order within the category.
  final int sort;

  /// The master genre this one derives from, or `null` when it has none.
  final int? parentGenreId;

  /// The raw `active` flag: `1` for a live genre. See [isActive].
  final int active;

  /// When the genre was last modified, in UTC.
  final DateTime? modified;

  /// Whether the genre is live, i.e. whether [active] is `1`.
  bool get isActive => active == 1;

  /// Serialises back to Zaim's wire format.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sort': sort,
        'active': active,
        'category_id': categoryId,
        'parent_genre_id': parentGenreId ?? 0,
        'modified': modified == null ? null : formatZaimTimestamp(modified!),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZaimGenre &&
          other.id == id &&
          other.name == name &&
          other.categoryId == categoryId &&
          other.sort == sort &&
          other.parentGenreId == parentGenreId &&
          other.active == active &&
          other.modified == modified;

  @override
  int get hashCode =>
      Object.hash(id, name, categoryId, sort, parentGenreId, active, modified);

  @override
  String toString() => 'ZaimGenre(id: $id, name: $name, categoryId: '
      '$categoryId, sort: $sort, parentGenreId: $parentGenreId)';
}
