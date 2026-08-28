/// How much detail a sales report carries.
///
/// Which values are legal depends on the report type; see
/// `SalesReportCombination`.
enum SalesReportSubType {
  /// Aggregated rows. The usual choice.
  summary('SUMMARY'),

  /// One row per transaction or subscriber, where Apple offers it.
  detailed('DETAILED'),

  /// Installs broken down by first-time versus redownload.
  summaryInstallType('SUMMARY_INSTALL_TYPE'),

  /// Installs broken down by territory.
  summaryTerritory('SUMMARY_TERRITORY'),

  /// Installs broken down by acquisition channel.
  summaryChannel('SUMMARY_CHANNEL');

  const SalesReportSubType(this.wireName);

  /// The value Apple expects in `filter[reportSubType]`.
  final String wireName;
}
