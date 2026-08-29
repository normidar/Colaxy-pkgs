import 'package:meta/meta.dart';
import 'package:zaim_api/src/json_utils.dart';
import 'package:zaim_api/src/models/money_mode.dart';

/// One of the user's own categories, from `GET /v2/home/category`.
///
/// These are the categories the user actually sees, which may be renamed,
/// reordered, or deactivated copies of the master categories returned by
/// `GET /v2/category` (`DefaultCategory`).
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: The category id to pass to the money endpoints.
/// - **[name]**: The display name.
///
/// ### Optional
/// - **[mode]**: `payment` or `income`, or `null` when unrecognised
///   (default: `null`).
/// - **[sort]**: Display order (default: `0`).
/// - **[parentCategoryId]**: The master category this one derives from,
///   `null` when Zaim sent `0` (default: `null`).
/// - **[active]**: `1` while the category is in use (default: `1`).
/// - **[modified]**: When the category last changed (default: `null`).
@immutable
class ZaimCategory {
  /// Creates a category.
  const ZaimCategory({
    required this.id,
    required this.name,
    this.mode,
    this.sort = 0,
    this.parentCategoryId,
    this.active = 1,
    this.modified,
  });

  /// Parses one element of the `categories` array.
  factory ZaimCategory.fromJson(Map<String, dynamic> json) => ZaimCategory(
        id: asInt(json, 'id'),
        name: asString(json, 'name'),
        mode: MoneyMode.tryParse(asStringOrNull(json, 'mode')),
        sort: asInt(json, 'sort'),
        parentCategoryId: asId(json, 'parent_category_id'),
        active: asInt(json, 'active', fallback: 1),
        modified: asTimestamp(json, 'modified'),
      );

  /// The category id. Pass this to the money create and update endpoints.
  final int id;

  /// The display name.
  final String name;

  /// Whether the category applies to payments or income, or `null` when Zaim
  /// sent a value this package does not know.
  final MoneyMode? mode;

  /// The display order within the user's list.
  final int sort;

  /// The master category this one derives from, or `null` when it has none.
  final int? parentCategoryId;

  /// The raw `active` flag: `1` for a live category. See [isActive].
  final int active;

  /// When the category was last modified, in UTC.
  final DateTime? modified;

  /// Whether the category is live, i.e. whether [active] is `1`.
  bool get isActive => active == 1;

  /// Serialises back to Zaim's wire format.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mode': mode?.wireName,
        'sort': sort,
        'parent_category_id': parentCategoryId ?? 0,
        'active': active,
        'modified': modified == null ? null : formatZaimTimestamp(modified!),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZaimCategory &&
          other.id == id &&
          other.name == name &&
          other.mode == mode &&
          other.sort == sort &&
          other.parentCategoryId == parentCategoryId &&
          other.active == active &&
          other.modified == modified;

  @override
  int get hashCode =>
      Object.hash(id, name, mode, sort, parentCategoryId, active, modified);

  @override
  String toString() => 'ZaimCategory(id: $id, name: $name, mode: '
      '${mode?.wireName}, sort: $sort, parentCategoryId: $parentCategoryId)';
}
