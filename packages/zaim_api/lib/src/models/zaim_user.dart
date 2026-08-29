import 'package:meta/meta.dart';
import 'package:zaim_api/src/json_utils.dart';

/// The authenticated Zaim user, as returned by `GET /v2/home/user/verify`.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: Zaim's numeric user id.
/// - **[login]**: The login name.
/// - **[name]**: The display name.
/// - **[inputCount]**: Total number of records the user has entered.
/// - **[dayCount]**: Total number of days the user has recorded on.
/// - **[repeatCount]**: Current streak of consecutive recording days.
/// - **[day]**: Start date of the user's month (1–31).
/// - **[week]**: First day of the user's week.
/// - **[month]**: Start month of the user's year.
/// - **[currencyCode]**: The user's default currency, e.g. `JPY`.
///
/// ### Optional
/// - **[profileImageUrl]**: Profile picture URL (default: `null`).
/// - **[coverImageUrl]**: Cover picture URL (default: `null`).
/// - **[profileModified]**: When the profile last changed (default: `null`).
///
/// ## Example
///
/// ```dart
/// final me = await client.user.verify();
/// print('${me.name} has entered ${me.inputCount} records');
/// ```
@immutable
class ZaimUser {
  /// Creates a user.
  const ZaimUser({
    required this.id,
    required this.login,
    required this.name,
    required this.inputCount,
    required this.dayCount,
    required this.repeatCount,
    required this.day,
    required this.week,
    required this.month,
    required this.currencyCode,
    this.profileImageUrl,
    this.coverImageUrl,
    this.profileModified,
  });

  /// Parses the `me` object of a `GET /v2/home/user/verify` response.
  factory ZaimUser.fromJson(Map<String, dynamic> json) => ZaimUser(
        id: asInt(json, 'id'),
        login: asString(json, 'login'),
        name: asString(json, 'name'),
        inputCount: asInt(json, 'input_count'),
        dayCount: asInt(json, 'day_count'),
        repeatCount: asInt(json, 'repeat_count'),
        day: asInt(json, 'day'),
        week: asInt(json, 'week'),
        month: asInt(json, 'month'),
        currencyCode: asString(json, 'currency_code'),
        profileImageUrl: asStringOrNull(json, 'profile_image_url'),
        coverImageUrl: asStringOrNull(json, 'cover_image_url'),
        profileModified: asTimestamp(json, 'profile_modified'),
      );

  /// Zaim's numeric user id.
  final int id;

  /// The user's login name.
  final String login;

  /// The user's display name.
  final String name;

  /// Total number of records the user has ever entered.
  final int inputCount;

  /// Total number of distinct days the user has recorded on.
  final int dayCount;

  /// The current run of consecutive days with at least one record.
  final int repeatCount;

  /// The day of the month the user's accounting month starts on.
  final int day;

  /// The first day of the user's week.
  final int week;

  /// The month the user's accounting year starts on.
  final int month;

  /// The user's default currency code, for example `JPY`.
  final String currencyCode;

  /// URL of the user's profile image, or `null` when unset.
  final String? profileImageUrl;

  /// URL of the user's cover image, or `null` when unset.
  final String? coverImageUrl;

  /// When the profile was last modified, in UTC. `null` when Zaim omitted it.
  final DateTime? profileModified;

  /// Serialises back to Zaim's wire format.
  Map<String, dynamic> toJson() => {
        'id': id,
        'login': login,
        'name': name,
        'input_count': inputCount,
        'day_count': dayCount,
        'repeat_count': repeatCount,
        'day': day,
        'week': week,
        'month': month,
        'currency_code': currencyCode,
        'profile_image_url': profileImageUrl,
        'cover_image_url': coverImageUrl,
        'profile_modified': profileModified == null
            ? null
            : formatZaimTimestamp(profileModified!),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZaimUser &&
          other.id == id &&
          other.login == login &&
          other.name == name &&
          other.inputCount == inputCount &&
          other.dayCount == dayCount &&
          other.repeatCount == repeatCount &&
          other.day == day &&
          other.week == week &&
          other.month == month &&
          other.currencyCode == currencyCode &&
          other.profileImageUrl == profileImageUrl &&
          other.coverImageUrl == coverImageUrl &&
          other.profileModified == profileModified;

  @override
  int get hashCode => Object.hash(
        id,
        login,
        name,
        inputCount,
        dayCount,
        repeatCount,
        day,
        week,
        month,
        currencyCode,
        profileImageUrl,
        coverImageUrl,
        profileModified,
      );

  @override
  String toString() =>
      'ZaimUser(id: $id, login: $login, name: $name, currencyCode: '
      '$currencyCode, inputCount: $inputCount, dayCount: $dayCount, '
      'repeatCount: $repeatCount)';
}
