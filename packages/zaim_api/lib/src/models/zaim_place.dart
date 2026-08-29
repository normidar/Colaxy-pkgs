import 'package:meta/meta.dart';
import 'package:zaim_api/src/json_utils.dart';
import 'package:zaim_api/src/models/money_mode.dart';

/// A place Zaim recorded alongside a money record.
///
/// Zaim returns this object from the money create and update endpoints when
/// the request supplied a `place`. It is Zaim's own place master row, keyed by
/// [placeUid] — `zm-…` for payments, `zi-…` for income.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: The place id.
/// - **[userId]**: The owning user's id.
/// - **[categoryId]**: The category the place is filed under.
/// - **[placeUid]**: Zaim's stable place identifier.
/// - **[name]**: The place name as it is shown.
/// - **[originalName]**: The name as it was first submitted.
///
/// ### Optional
/// - **[mode]**: `payment` or `income`, or `null` if Zaim sent something else
///   (default: `null`).
/// - **[genreId]**, **[accountId]**, **[transferAccountId]**,
///   **[placePatternId]**: foreign keys; `null` when Zaim sent `0`.
/// - **[service]**, **[tel]**: descriptive strings (default: `''`).
/// - **[count]**: How many records reference this place (default: `0`).
/// - **[calcFlag]**, **[editFlag]**, **[active]**: Zaim's internal flags.
/// - **[modified]**, **[created]**: timestamps (default: `null`).
@immutable
class ZaimPlace {
  /// Creates a place.
  const ZaimPlace({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.placeUid,
    required this.name,
    required this.originalName,
    this.mode,
    this.genreId,
    this.accountId,
    this.transferAccountId,
    this.placePatternId,
    this.service = '',
    this.tel = '',
    this.count = 0,
    this.calcFlag = 0,
    this.editFlag = 0,
    this.active = 1,
    this.modified,
    this.created,
  });

  /// Parses the top-level `place` object of a money write response.
  factory ZaimPlace.fromJson(Map<String, dynamic> json) => ZaimPlace(
        id: asInt(json, 'id'),
        userId: asInt(json, 'user_id'),
        categoryId: asInt(json, 'category_id'),
        placeUid: asString(json, 'place_uid'),
        name: asString(json, 'name'),
        originalName: asString(json, 'original_name'),
        // NOTE: `mode` is tolerated as unknown here rather than thrown on.
        // The place master is shared machinery and a place is never the point
        // of the call, so an unfamiliar value should not fail the write.
        mode: MoneyMode.tryParse(asStringOrNull(json, 'mode')),
        // NOTE: the specification only spells out the `0`-means-null rule for
        // money records, but the sample place carries
        // `transfer_account_id: 0` and `place_pattern_id: 0` with the same
        // meaning, so the same mapping is applied here.
        genreId: asId(json, 'genre_id'),
        accountId: asId(json, 'account_id'),
        transferAccountId: asId(json, 'transfer_account_id'),
        placePatternId: asId(json, 'place_pattern_id'),
        service: asString(json, 'service'),
        tel: asString(json, 'tel'),
        count: asInt(json, 'count'),
        calcFlag: asInt(json, 'calc_flag'),
        editFlag: asInt(json, 'edit_flag'),
        active: asInt(json, 'active', fallback: 1),
        modified: asTimestamp(json, 'modified'),
        created: asTimestamp(json, 'created'),
      );

  /// The place id.
  final int id;

  /// The id of the user the place belongs to.
  final int userId;

  /// The category the place is filed under.
  final int categoryId;

  /// Zaim's stable identifier: `zm-…` for payments, `zi-…` for income.
  final String placeUid;

  /// The place name.
  final String name;

  /// The name as originally submitted, before Zaim normalised it.
  final String originalName;

  /// Whether the place belongs to payments or income, or `null` when Zaim
  /// sent a value this package does not know.
  final MoneyMode? mode;

  /// The genre the place is filed under, or `null` when it has none.
  final int? genreId;

  /// The account the place defaults to, or `null` when it has none.
  final int? accountId;

  /// The transfer counterpart account, or `null` when it has none.
  final int? transferAccountId;

  /// The place pattern this place matched, or `null` when it has none.
  final int? placePatternId;

  /// The source of the place row, for example `place`.
  final String service;

  /// The telephone number, empty when unset.
  final String tel;

  /// How many money records reference this place.
  final int count;

  /// Zaim's internal calculation flag.
  final int calcFlag;

  /// Zaim's internal edit flag.
  final int editFlag;

  /// The raw `active` flag: `1` for a live place. See [isActive].
  final int active;

  /// When the place was last modified, in UTC.
  final DateTime? modified;

  /// When the place was created, in UTC.
  final DateTime? created;

  /// Whether the place is live, i.e. whether [active] is `1`.
  bool get isActive => active == 1;

  /// Serialises back to Zaim's wire format, restoring the `0` sentinels.
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'genre_id': genreId ?? 0,
        'category_id': categoryId,
        'account_id': accountId ?? 0,
        'transfer_account_id': transferAccountId ?? 0,
        'mode': mode?.wireName,
        'place_uid': placeUid,
        'service': service,
        'name': name,
        'original_name': originalName,
        'tel': tel,
        'count': count,
        'place_pattern_id': placePatternId ?? 0,
        'calc_flag': calcFlag,
        'edit_flag': editFlag,
        'active': active,
        'modified': modified == null ? null : formatZaimTimestamp(modified!),
        'created': created == null ? null : formatZaimTimestamp(created!),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZaimPlace &&
          other.id == id &&
          other.userId == userId &&
          other.genreId == genreId &&
          other.categoryId == categoryId &&
          other.accountId == accountId &&
          other.transferAccountId == transferAccountId &&
          other.mode == mode &&
          other.placeUid == placeUid &&
          other.service == service &&
          other.name == name &&
          other.originalName == originalName &&
          other.tel == tel &&
          other.count == count &&
          other.placePatternId == placePatternId &&
          other.calcFlag == calcFlag &&
          other.editFlag == editFlag &&
          other.active == active &&
          other.modified == modified &&
          other.created == created;

  @override
  int get hashCode => Object.hashAll([
        id,
        userId,
        genreId,
        categoryId,
        accountId,
        transferAccountId,
        mode,
        placeUid,
        service,
        name,
        originalName,
        tel,
        count,
        placePatternId,
        calcFlag,
        editFlag,
        active,
        modified,
        created,
      ]);

  @override
  String toString() => 'ZaimPlace(id: $id, placeUid: $placeUid, name: $name, '
      'mode: ${mode?.wireName}, categoryId: $categoryId, genreId: $genreId, '
      'count: $count)';
}
