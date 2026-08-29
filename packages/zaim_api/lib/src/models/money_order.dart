/// The sort key for `GET /v2/home/money`.
///
/// Zaim sorts descending in both cases, so with no filters at all the newest
/// date comes first.
enum MoneyOrder {
  /// Order by record id.
  id('id'),

  /// Order by the record's date. This is Zaim's default.
  date('date');

  const MoneyOrder(this.wireName);

  /// The exact string Zaim expects in the `order` query parameter.
  final String wireName;
}
