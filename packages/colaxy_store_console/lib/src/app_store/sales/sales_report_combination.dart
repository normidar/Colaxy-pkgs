import 'package:colaxy_store_console/src/app_store/sales/sales_frequency.dart';
import 'package:colaxy_store_console/src/app_store/sales/sales_report_sub_type.dart';
import 'package:colaxy_store_console/src/app_store/sales/sales_report_type.dart';

/// One legal combination of report type, sub-type and frequency.
///
/// Apple publishes this as a table and rejects anything outside it. The
/// rejection is worth avoiding locally, because it is actively misleading:
/// asking for a `SUBSCRIPTION_EVENT` report at `MONTHLY` frequency returns
/// `PARAMETER_ERROR.INVALID.INVALID_COMBINATION` with the detail "Invalid
/// combination of date type and date" — pointing at the date, when the date
/// was fine and the frequency was not.
///
/// ## Parameters
///
/// ### Required
/// - **[type]**: The report type.
/// - **[subType]**: The sub-type valid for [type].
/// - **[frequencies]**: Frequencies Apple accepts for this pairing.
/// - **[versions]**: Report versions, oldest first.
class SalesReportCombination {
  /// Creates a combination entry.
  const SalesReportCombination({
    required this.type,
    required this.subType,
    required this.frequencies,
    required this.versions,
  });

  /// Every combination Apple documents.
  ///
  /// Transcribed from the "Allowed values based on sales report type" table
  /// on Apple's `GET /v1/salesReports` reference.
  static const all = <SalesReportCombination>[
    SalesReportCombination(
      type: SalesReportType.sales,
      subType: SalesReportSubType.summary,
      frequencies: {
        SalesFrequency.daily,
        SalesFrequency.weekly,
        SalesFrequency.monthly,
        SalesFrequency.yearly,
      },
      versions: ['1_0'],
    ),
    SalesReportCombination(
      type: SalesReportType.preOrder,
      subType: SalesReportSubType.summary,
      frequencies: {
        SalesFrequency.daily,
        SalesFrequency.weekly,
        SalesFrequency.monthly,
        SalesFrequency.yearly,
      },
      versions: ['1_0'],
    ),
    SalesReportCombination(
      type: SalesReportType.newsstand,
      subType: SalesReportSubType.detailed,
      frequencies: {SalesFrequency.daily, SalesFrequency.weekly},
      versions: ['1_0'],
    ),
    SalesReportCombination(
      type: SalesReportType.subscription,
      subType: SalesReportSubType.summary,
      frequencies: {SalesFrequency.daily},
      versions: ['1_3'],
    ),
    SalesReportCombination(
      type: SalesReportType.subscriptionEvent,
      subType: SalesReportSubType.summary,
      frequencies: {SalesFrequency.daily},
      versions: ['1_3'],
    ),
    SalesReportCombination(
      type: SalesReportType.subscriber,
      subType: SalesReportSubType.detailed,
      frequencies: {SalesFrequency.daily},
      versions: ['1_3'],
    ),
    SalesReportCombination(
      type: SalesReportType.subscriptionOfferCodeRedemption,
      subType: SalesReportSubType.summary,
      frequencies: {SalesFrequency.daily},
      versions: ['1_0'],
    ),
    SalesReportCombination(
      type: SalesReportType.installs,
      subType: SalesReportSubType.summary,
      frequencies: {SalesFrequency.monthly},
      versions: ['1_2'],
    ),
    // Apple lists INSTALLS/DETAILED on two rows, with different versions per
    // frequency. Merging them would default a yearly request to 1_2, which
    // only monthly accepts.
    SalesReportCombination(
      type: SalesReportType.installs,
      subType: SalesReportSubType.detailed,
      frequencies: {SalesFrequency.monthly},
      versions: ['1_2'],
    ),
    SalesReportCombination(
      type: SalesReportType.installs,
      subType: SalesReportSubType.detailed,
      frequencies: {SalesFrequency.yearly},
      versions: ['1_0', '1_1'],
    ),
    SalesReportCombination(
      type: SalesReportType.installs,
      subType: SalesReportSubType.summaryInstallType,
      frequencies: {SalesFrequency.yearly},
      versions: ['1_0', '1_1'],
    ),
    SalesReportCombination(
      type: SalesReportType.installs,
      subType: SalesReportSubType.summaryTerritory,
      frequencies: {SalesFrequency.yearly},
      versions: ['1_0', '1_1'],
    ),
    SalesReportCombination(
      type: SalesReportType.installs,
      subType: SalesReportSubType.summaryChannel,
      frequencies: {SalesFrequency.yearly},
      versions: ['1_0', '1_1'],
    ),
    SalesReportCombination(
      type: SalesReportType.firstAnnual,
      subType: SalesReportSubType.detailed,
      frequencies: {SalesFrequency.daily},
      versions: ['1_0'],
    ),
    SalesReportCombination(
      type: SalesReportType.firstAnnual,
      subType: SalesReportSubType.summary,
      frequencies: {SalesFrequency.yearly},
      versions: ['1_0'],
    ),
    SalesReportCombination(
      type: SalesReportType.winBackEligibility,
      subType: SalesReportSubType.summary,
      frequencies: {SalesFrequency.daily},
      versions: ['1_0'],
    ),
  ];

  /// The report type.
  final SalesReportType type;

  /// The sub-type valid for [type].
  final SalesReportSubType subType;

  /// Frequencies Apple accepts for this pairing.
  final Set<SalesFrequency> frequencies;

  /// Report versions, oldest first.
  final List<String> versions;

  /// The newest version, used when a query does not name one.
  String get latestVersion => versions.last;

  /// The entry for [type] and [subType], narrowed by [frequency].
  ///
  /// [frequency] matters: a report type and sub-type can appear on more than
  /// one row of Apple's table with a different version list each time.
  /// Ignoring it would resolve a yearly `INSTALLS`/`DETAILED` request to the
  /// monthly-only version.
  ///
  /// Returns `null` when Apple publishes no such report.
  static SalesReportCombination? find(
    SalesReportType type,
    SalesReportSubType subType, {
    SalesFrequency? frequency,
  }) {
    for (final combination in all) {
      if (combination.type != type || combination.subType != subType) continue;
      if (frequency == null || combination.frequencies.contains(frequency)) {
        return combination;
      }
    }
    return null;
  }

  /// Every frequency Apple offers for [type] and [subType], across all rows.
  static Set<SalesFrequency> frequenciesFor(
    SalesReportType type,
    SalesReportSubType subType,
  ) => {
    for (final combination in all)
      if (combination.type == type && combination.subType == subType)
        ...combination.frequencies,
  };

  /// Every sub-type valid for [type].
  static List<SalesReportSubType> subTypesFor(SalesReportType type) => [
    ...{
      for (final combination in all)
        if (combination.type == type) combination.subType,
    },
  ];

  @override
  String toString() =>
      '${type.wireName}/${subType.wireName} '
      '(${frequencies.map((f) => f.wireName).join(', ')})';
}
