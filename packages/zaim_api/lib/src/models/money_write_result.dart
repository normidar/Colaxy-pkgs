import 'package:meta/meta.dart';
import 'package:zaim_api/src/json_utils.dart';
import 'package:zaim_api/src/models/zaim_place.dart';
import 'package:zaim_api/src/models/zaim_user_counters.dart';

/// What Zaim returns from every money create, update, and delete.
///
/// The three endpoints share one response shape: the affected record's [id]
/// and [modified] timestamp, the user's refreshed counters, and — when the
/// request supplied a `place` — the [place] Zaim matched or created plus its
/// [placeUid].
///
/// The `stamps` and `banners` fields Zaim also sends are deliberately not
/// modelled: `stamps` is always `null` and `banners` is always empty.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: The id of the record that was written or deleted.
/// - **[user]**: The user's counters after the write.
///
/// ### Optional
/// - **[modified]**: When the record was written (default: `null`).
/// - **[placeUid]**: Set only when a `place` was supplied (default: `null`).
/// - **[place]**: The matched place row (default: `null`).
/// - **[requested]**: Server timestamp of the response (default: `null`).
///
/// ## Example
///
/// ```dart
/// final result = await client.money.createPayment(
///   categoryId: 101,
///   genreId: 10101,
///   amount: 1280,
///   date: DateTime.now(),
///   place: 'Corner store',
/// );
/// print('created ${result.id} at ${result.place?.name}');
/// ```
@immutable
class MoneyWriteResult {
  /// Creates a write result.
  const MoneyWriteResult({
    required this.id,
    required this.user,
    this.modified,
    this.placeUid,
    this.place,
    this.requested,
  });

  /// Parses a money create / update / delete response.
  factory MoneyWriteResult.fromJson(Map<String, dynamic> json) {
    final money = asMap(json, 'money') ?? const <String, dynamic>{};
    final place = asMap(json, 'place');
    return MoneyWriteResult(
      id: asInt(money, 'id'),
      user: ZaimUserCounters.fromJson(
        asMap(json, 'user') ?? const <String, dynamic>{},
      ),
      modified: asTimestamp(money, 'modified'),
      placeUid: asStringOrNull(money, 'place_uid'),
      place: place == null ? null : ZaimPlace.fromJson(place),
      requested: asUnixTimestamp(json, 'requested'),
    );
  }

  /// The id of the record that was created, updated, or deleted.
  final int id;

  /// When the record was written, in UTC.
  final DateTime? modified;

  /// Zaim's identifier for the supplied place — `zm-…` for payments, `zi-…`
  /// for income — or `null` when the request carried no `place`.
  final String? placeUid;

  /// The place Zaim matched or created, or `null` when none was supplied.
  final ZaimPlace? place;

  /// The user's running totals after the write.
  final ZaimUserCounters user;

  /// When Zaim served the response, in UTC.
  final DateTime? requested;

  /// Serialises back to Zaim's wire format.
  Map<String, dynamic> toJson() => {
        'money': {
          'id': id,
          if (modified != null) 'modified': formatZaimTimestamp(modified!),
          if (placeUid != null) 'place_uid': placeUid,
        },
        if (place != null) 'place': place!.toJson(),
        'user': user.toJson(),
        if (requested != null) 'requested': toUnixSeconds(requested!),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoneyWriteResult &&
          other.id == id &&
          other.modified == modified &&
          other.placeUid == placeUid &&
          other.place == place &&
          other.user == user &&
          other.requested == requested;

  @override
  int get hashCode =>
      Object.hash(id, modified, placeUid, place, user, requested);

  @override
  String toString() => 'MoneyWriteResult(id: $id, modified: $modified, '
      'placeUid: $placeUid, user: $user)';
}
