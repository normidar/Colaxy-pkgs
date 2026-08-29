import 'package:meta/meta.dart';
import 'package:zaim_api/src/json_utils.dart';

/// The `user` object every money create/update/delete response carries.
///
/// It is a much smaller shape than the full user returned by
/// `GET /v2/home/user/verify`: Zaim echoes back the three running totals that
/// the write just changed, plus — on creates — when the user's data was last
/// modified.
///
/// ## Parameters
///
/// ### Required
/// - **[inputCount]**: Total number of records after the write.
/// - **[dayCount]**: Total number of recorded days after the write.
/// - **[repeatCount]**: Consecutive recording days after the write.
///
/// ### Optional
/// - **[dataModified]**: When the user's data last changed. Zaim sends this
///   on creates and omits it on updates and deletes (default: `null`).
@immutable
class ZaimUserCounters {
  /// Creates a counter snapshot.
  const ZaimUserCounters({
    required this.inputCount,
    required this.dayCount,
    required this.repeatCount,
    this.dataModified,
  });

  /// Parses the `user` object of a money write response.
  factory ZaimUserCounters.fromJson(Map<String, dynamic> json) =>
      ZaimUserCounters(
        inputCount: asInt(json, 'input_count'),
        dayCount: asInt(json, 'day_count'),
        repeatCount: asInt(json, 'repeat_count'),
        dataModified: asTimestamp(json, 'data_modified'),
      );

  /// Total number of records the user has entered.
  final int inputCount;

  /// Total number of distinct days the user has recorded on.
  final int dayCount;

  /// The current run of consecutive days with at least one record.
  final int repeatCount;

  /// When the user's data was last modified, in UTC, or `null` when the
  /// response omitted it.
  final DateTime? dataModified;

  /// Serialises back to Zaim's wire format.
  Map<String, dynamic> toJson() => {
        'input_count': inputCount,
        'day_count': dayCount,
        'repeat_count': repeatCount,
        'data_modified':
            dataModified == null ? null : formatZaimTimestamp(dataModified!),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZaimUserCounters &&
          other.inputCount == inputCount &&
          other.dayCount == dayCount &&
          other.repeatCount == repeatCount &&
          other.dataModified == dataModified;

  @override
  int get hashCode =>
      Object.hash(inputCount, dayCount, repeatCount, dataModified);

  @override
  String toString() => 'ZaimUserCounters(inputCount: $inputCount, dayCount: '
      '$dayCount, repeatCount: $repeatCount, dataModified: $dataModified)';
}
