/// The kind of money record: a payment, an income, or a transfer between two
/// of the user's own accounts.
///
/// The enum name doubles as the value Zaim uses on the wire and as the path
/// segment of the create/update/delete endpoints
/// (`/v2/home/money/payment`, `.../income`, `.../transfer`).
enum MoneyMode {
  /// Money going out. Requires both a category and a genre.
  payment('payment'),

  /// Money coming in. Requires a category; genres do not apply.
  income('income'),

  /// Money moved between two accounts of the same user.
  transfer('transfer');

  const MoneyMode(this.wireName);

  /// The exact string Zaim uses for this mode in JSON and in URLs.
  final String wireName;

  /// Parses [value] into a [MoneyMode], or returns `null` when it is not one
  /// of the three known modes.
  static MoneyMode? tryParse(String? value) {
    for (final mode in MoneyMode.values) {
      if (mode.wireName == value) return mode;
    }
    return null;
  }

  /// Parses [value] into a [MoneyMode].
  ///
  /// Throws a [FormatException] when [value] is not `payment`, `income`, or
  /// `transfer`.
  static MoneyMode parse(String value) {
    final mode = tryParse(value);
    if (mode == null) {
      throw FormatException('Unknown Zaim money mode: "$value"', value);
    }
    return mode;
  }
}
