import 'package:colaxy_store_console/src/app_store/sales/sales_frequency.dart';
import 'package:colaxy_store_console/src/app_store/sales/sales_report_combination.dart';
import 'package:colaxy_store_console/src/app_store/sales/sales_report_sub_type.dart';
import 'package:colaxy_store_console/src/app_store/sales/sales_report_type.dart';

/// Which sales report to ask App Store Connect for.
///
/// The type, sub-type and frequency are checked against
/// [SalesReportCombination.all] when the query is built, so an impossible
/// request fails here with a message naming the actual problem rather than at
/// Apple with one that blames the date.
///
/// [version] is deliberately *not* validated. Apple's published version list
/// and the versions its API accepts have drifted apart before — accounts have
/// been told `SALES`/`DAILY` needs `1_1` while the documentation said `1_0` —
/// so an explicit version is passed through untouched. Leave it unset to get
/// the newest version Apple documents for the combination.
///
/// ## Parameters
///
/// ### Required
/// - **[type]**: Which report.
/// - **[subType]**: How much detail.
/// - **[frequency]**: How often the report is cut.
///
/// ### Optional
/// - **[date]**: Which period (default: `null`, which is only allowed for
///   [SalesFrequency.daily] and returns the most recent day available).
/// - **[version]**: Report version (default: `null`, meaning the newest
///   documented for this combination).
///
/// ## Example
///
/// ```dart
/// final query = SalesReportQuery.sales(date: DateTime.utc(2026, 8, 20));
/// final table = await team.salesReports.fetch(query);
/// ```
class SalesReportQuery {
  /// Creates a sales report query, validating the combination.
  ///
  /// Throws [ArgumentError] when Apple has no such report, when the frequency
  /// is not offered for it, or when a date is required and missing.
  SalesReportQuery({
    required this.type,
    required this.subType,
    required this.frequency,
    this.date,
    this.version,
  }) : combination = _resolve(type, subType, frequency) {
    if (frequency.requiresDate && date == null) {
      throw ArgumentError.value(
        date,
        'date',
        'A ${frequency.wireName} report needs a date; only DAILY may omit one',
      );
    }
    if (frequency == SalesFrequency.weekly &&
        date != null &&
        !SalesFrequency.isEndOfWeek(date!)) {
      throw ArgumentError.value(
        date,
        'date',
        'A weekly report is addressed by the Sunday that closes the week. '
            'Apple is reported to snap some other days to a week boundary '
            'rather than reject them, which would hand you a different week '
            'than you asked for. Use SalesFrequency.endOfWeek(date).',
      );
    }
  }

  /// Units and proceeds — the report most callers want.
  ///
  /// ## Parameters
  ///
  /// ### Optional
  /// - **`date`**: Which period (default: `null`, the latest daily report).
  /// - **`frequency`**: How often (default: [SalesFrequency.daily]).
  /// - **`version`**: Report version (default: Apple's newest).
  factory SalesReportQuery.sales({
    DateTime? date,
    SalesFrequency frequency = SalesFrequency.daily,
    String? version,
  }) => SalesReportQuery(
    type: SalesReportType.sales,
    subType: SalesReportSubType.summary,
    frequency: frequency,
    date: date,
    version: version,
  );

  /// Active subscription counts. Daily only.
  factory SalesReportQuery.subscriptions({DateTime? date, String? version}) =>
      SalesReportQuery(
        type: SalesReportType.subscription,
        subType: SalesReportSubType.summary,
        frequency: SalesFrequency.daily,
        date: date,
        version: version,
      );

  /// Subscription state changes. Daily only.
  factory SalesReportQuery.subscriptionEvents({
    DateTime? date,
    String? version,
  }) => SalesReportQuery(
    type: SalesReportType.subscriptionEvent,
    subType: SalesReportSubType.summary,
    frequency: SalesFrequency.daily,
    date: date,
    version: version,
  );

  /// Per-subscriber rows, pseudonymised by Apple. Daily only.
  factory SalesReportQuery.subscribers({DateTime? date, String? version}) =>
      SalesReportQuery(
        type: SalesReportType.subscriber,
        subType: SalesReportSubType.detailed,
        frequency: SalesFrequency.daily,
        date: date,
        version: version,
      );

  /// Which report.
  final SalesReportType type;

  /// How much detail.
  final SalesReportSubType subType;

  /// How often the report is cut.
  final SalesFrequency frequency;

  /// Which period, or `null` for the latest daily report.
  final DateTime? date;

  /// Report version, or `null` for Apple's newest for this combination.
  final String? version;

  /// The matched entry from Apple's table.
  final SalesReportCombination combination;

  /// The version this query will send.
  String get resolvedVersion => version ?? combination.latestVersion;

  /// The `filter[…]` parameters for `GET /v1/salesReports`.
  ///
  /// [vendorNumber] identifies the team, not the app: sales reports cover
  /// every app under one App Store Connect account and cannot be narrowed to
  /// one by the API.
  Map<String, Object?> toFilters({required String vendorNumber}) => {
    'filter[frequency]': frequency.wireName,
    'filter[reportType]': type.wireName,
    'filter[reportSubType]': subType.wireName,
    'filter[vendorNumber]': vendorNumber,
    'filter[version]': resolvedVersion,
    'filter[reportDate]': date == null ? null : frequency.formatDate(date!),
  };

  static SalesReportCombination _resolve(
    SalesReportType type,
    SalesReportSubType subType,
    SalesFrequency frequency,
  ) {
    final anyFrequency = SalesReportCombination.find(type, subType);
    if (anyFrequency == null) {
      final valid = SalesReportCombination.subTypesFor(
        type,
      ).map((subType) => subType.wireName).join(', ');
      throw ArgumentError.value(
        subType,
        'subType',
        'Apple has no ${type.wireName} report with sub-type '
            '${subType.wireName}. Valid sub-types: '
            '${valid.isEmpty ? 'none' : valid}.',
      );
    }
    final combination = SalesReportCombination.find(
      type,
      subType,
      frequency: frequency,
    );
    if (combination == null) {
      final valid = SalesReportCombination.frequenciesFor(
        type,
        subType,
      ).map((frequency) => frequency.wireName).join(', ');
      throw ArgumentError.value(
        frequency,
        'frequency',
        'Apple does not offer ${type.wireName}/${subType.wireName} at '
            '${frequency.wireName}. Valid frequencies: $valid.',
      );
    }
    return combination;
  }

  @override
  String toString() =>
      'SalesReportQuery(${type.wireName}/${subType.wireName}/'
      '${frequency.wireName}, v$resolvedVersion, '
      '${date == null ? 'latest' : frequency.formatDate(date!)})';
}
