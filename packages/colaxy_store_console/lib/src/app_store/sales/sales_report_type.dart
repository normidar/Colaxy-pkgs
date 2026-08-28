/// Which sales report to download.
///
/// Not every type supports every sub-type and frequency; see
/// `SalesReportCombination` for the table Apple publishes.
enum SalesReportType {
  /// Units and proceeds per SKU, territory and product type.
  ///
  /// The general-purpose report, and the one most callers want.
  sales('SALES'),

  /// Pre-orders placed and cancelled.
  preOrder('PRE_ORDER'),

  /// Newsstand issue downloads. Legacy.
  newsstand('NEWSSTAND'),

  /// Active subscription counts by state, plan and territory.
  subscription('SUBSCRIPTION'),

  /// Subscription state changes: starts, cancellations, renewals.
  subscriptionEvent('SUBSCRIPTION_EVENT'),

  /// Per-subscriber rows, pseudonymised by Apple.
  subscriber('SUBSCRIBER'),

  /// Offer codes redeemed.
  subscriptionOfferCodeRedemption('SUBSCRIPTION_OFFER_CODE_REDEMPTION'),

  /// First-time and redownload installs.
  ///
  /// Note this is a *sales* report of installs, not App Store analytics.
  installs('INSTALLS'),

  /// First-year subscription revenue, for the reduced commission rate.
  firstAnnual('FIRST_ANNUAL'),

  /// Which lapsed subscribers qualify for a win-back offer.
  winBackEligibility('WIN_BACK_ELIGIBILITY');

  const SalesReportType(this.wireName);

  /// The value Apple expects in `filter[reportType]`.
  final String wireName;
}
