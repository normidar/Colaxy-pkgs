import 'package:meta/meta.dart';
import 'package:zaim_api/src/json_utils.dart';

/// A currency from Zaim's public currency master, `GET /v2/currency`.
///
/// [point] is the number of decimal places the currency uses. It is `0` for
/// JPY, which is why every `amount` in this package is an `int` with no
/// decimal point: for currencies with `point > 0` the amount is expressed in
/// the currency's minor units.
///
/// ## Parameters
///
/// ### Required
/// - **[currencyCode]**: ISO code, e.g. `JPY`.
/// - **[name]**: English name, e.g. `Japanese YEN`.
///
/// ### Optional
/// - **[unit]**: The symbol, e.g. `￥` (default: `''`).
/// - **[point]**: Decimal places (default: `0`).
@immutable
class ZaimCurrency {
  /// Creates a currency.
  const ZaimCurrency({
    required this.currencyCode,
    required this.name,
    this.unit = '',
    this.point = 0,
  });

  /// Parses one element of the `currencies` array.
  factory ZaimCurrency.fromJson(Map<String, dynamic> json) => ZaimCurrency(
        currencyCode: asString(json, 'currency_code'),
        name: asString(json, 'name'),
        unit: asString(json, 'unit'),
        point: asInt(json, 'point'),
      );

  /// The ISO currency code, for example `JPY` or `AUD`.
  final String currencyCode;

  /// The English currency name, for example `Japanese YEN`.
  final String name;

  /// The currency symbol, for example `￥` or `$`.
  final String unit;

  /// The number of decimal places this currency uses. `0` for JPY.
  final int point;

  /// Serialises back to Zaim's wire format.
  Map<String, dynamic> toJson() => {
        'currency_code': currencyCode,
        'unit': unit,
        'name': name,
        'point': point,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZaimCurrency &&
          other.currencyCode == currencyCode &&
          other.name == name &&
          other.unit == unit &&
          other.point == point;

  @override
  int get hashCode => Object.hash(currencyCode, name, unit, point);

  @override
  String toString() => 'ZaimCurrency(currencyCode: $currencyCode, name: '
      '$name, unit: $unit, point: $point)';
}
