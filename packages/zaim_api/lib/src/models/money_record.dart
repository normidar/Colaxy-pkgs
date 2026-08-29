import 'package:meta/meta.dart';
import 'package:zaim_api/src/json_utils.dart';
import 'package:zaim_api/src/models/money_mode.dart';

/// One money record — a payment, an income, or a transfer — as returned by
/// `GET /v2/home/money`.
///
/// Only records the user entered **manually** are ever returned. Rows that
/// Zaim imported automatically from a linked bank or card are not exposed by
/// the API at all.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: The record id, used in the update and delete paths.
/// - **[mode]**: Whether this is a payment, an income, or a transfer.
/// - **[userId]**: The owning user's id.
/// - **[date]**: The calendar date of the record.
/// - **[categoryId]**: The category the record belongs to.
/// - **[amount]**: The amount, an integer with no decimal point.
/// - **[active]**: `1` while the record is live; see [isActive].
///
/// ### Optional
/// - **[genreId]**: Genre id, `null` when Zaim sent `0` (default: `null`).
/// - **[toAccountId]**: Destination account, `null` when `0` (default:
///   `null`).
/// - **[fromAccountId]**: Source account, `null` when `0` (default: `null`).
/// - **[receiptId]**: Receipt this record was grouped under, `null` when `0`
///   (default: `null`).
/// - **[comment]**: Free-text note (default: `''`).
/// - **[name]**: Product name (default: `''`).
/// - **[place]**: Place name (default: `''`).
/// - **[currencyCode]**: Currency of [amount] (default: `''`).
/// - **[created]**: When the record was created (default: `null`).
///
/// ## Example
///
/// ```dart
/// final records = await client.money.list(mode: MoneyMode.payment);
/// for (final r in records) {
///   print('${r.date}: ${r.amount} ${r.currencyCode} at ${r.place}');
/// }
/// ```
@immutable
class MoneyRecord {
  /// Creates a money record.
  const MoneyRecord({
    required this.id,
    required this.mode,
    required this.userId,
    required this.date,
    required this.categoryId,
    required this.amount,
    this.genreId,
    this.toAccountId,
    this.fromAccountId,
    this.receiptId,
    this.comment = '',
    this.name = '',
    this.place = '',
    this.currencyCode = '',
    this.active = 1,
    this.created,
  });

  /// Parses one element of the `money` array.
  ///
  /// Throws a [FormatException] when `mode` is not one of `payment`,
  /// `income`, or `transfer`.
  factory MoneyRecord.fromJson(Map<String, dynamic> json) => MoneyRecord(
        id: asInt(json, 'id'),
        mode: MoneyMode.parse(asString(json, 'mode')),
        userId: asInt(json, 'user_id'),
        // `date` is always present in practice; the epoch keeps parsing
        // total rather than throwing if it ever is not.
        date: asDate(json, 'date') ?? DateTime(1970),
        categoryId: asInt(json, 'category_id'),
        amount: asInt(json, 'amount'),
        // NOTE: Zaim sends `0`, not `null`, for foreign keys that are unset.
        // `asId` maps that sentinel to `null` so `0` can never be mistaken
        // for a real account, genre, or receipt.
        genreId: asId(json, 'genre_id'),
        toAccountId: asId(json, 'to_account_id'),
        fromAccountId: asId(json, 'from_account_id'),
        receiptId: asId(json, 'receipt_id'),
        comment: asString(json, 'comment'),
        name: asString(json, 'name'),
        place: asString(json, 'place'),
        currencyCode: asString(json, 'currency_code'),
        active: asInt(json, 'active', fallback: 1),
        created: asTimestamp(json, 'created'),
      );

  /// The record id. Pass it to the update and delete endpoints.
  final int id;

  /// Whether this record is a payment, an income, or a transfer.
  final MoneyMode mode;

  /// The id of the user the record belongs to.
  final int userId;

  /// The calendar date of the record, at local midnight.
  final DateTime date;

  /// The category id.
  final int categoryId;

  /// The genre id, or `null` when the record has none (Zaim's `0`).
  final int? genreId;

  /// The account money went into, or `null` when the record has none.
  final int? toAccountId;

  /// The account money came out of, or `null` when the record has none.
  final int? fromAccountId;

  /// The amount. Always an integer: Zaim never sends a decimal point.
  final int amount;

  /// The user's free-text comment. Empty when unset.
  final String comment;

  /// The raw `active` flag: `1` for a live record. See [isActive].
  final int active;

  /// The product name. Empty when unset.
  final String name;

  /// The receipt this record was grouped under, or `null` when it has none.
  final int? receiptId;

  /// The place name. Empty when unset.
  final String place;

  /// When the record was created, in UTC. `null` when Zaim omitted it.
  final DateTime? created;

  /// The currency of [amount], for example `JPY`.
  final String currencyCode;

  /// Whether the record is live, i.e. whether [active] is `1`.
  bool get isActive => active == 1;

  /// Serialises back to Zaim's wire format, restoring the `0` sentinels for
  /// the foreign keys that [MoneyRecord.fromJson] mapped to `null`.
  Map<String, dynamic> toJson() => {
        'id': id,
        'mode': mode.wireName,
        'user_id': userId,
        'date': formatZaimDate(date),
        'category_id': categoryId,
        'genre_id': genreId ?? 0,
        'to_account_id': toAccountId ?? 0,
        'from_account_id': fromAccountId ?? 0,
        'amount': amount,
        'comment': comment,
        'active': active,
        'name': name,
        'receipt_id': receiptId ?? 0,
        'place': place,
        'created': created == null ? null : formatZaimTimestamp(created!),
        'currency_code': currencyCode,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoneyRecord &&
          other.id == id &&
          other.mode == mode &&
          other.userId == userId &&
          other.date == date &&
          other.categoryId == categoryId &&
          other.genreId == genreId &&
          other.toAccountId == toAccountId &&
          other.fromAccountId == fromAccountId &&
          other.amount == amount &&
          other.comment == comment &&
          other.active == active &&
          other.name == name &&
          other.receiptId == receiptId &&
          other.place == place &&
          other.created == created &&
          other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(
        id,
        mode,
        userId,
        date,
        categoryId,
        genreId,
        toAccountId,
        fromAccountId,
        amount,
        comment,
        active,
        name,
        receiptId,
        place,
        created,
        currencyCode,
      );

  @override
  String toString() => 'MoneyRecord(id: $id, mode: ${mode.wireName}, date: '
      '${formatZaimDate(date)}, amount: $amount, categoryId: $categoryId, '
      'genreId: $genreId, fromAccountId: $fromAccountId, toAccountId: '
      '$toAccountId, place: $place)';
}
