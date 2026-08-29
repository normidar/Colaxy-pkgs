import 'package:zaim_api/src/json_utils.dart';
import 'package:zaim_api/src/models/money_mode.dart';
import 'package:zaim_api/src/models/money_order.dart';
import 'package:zaim_api/src/models/money_record.dart';
import 'package:zaim_api/src/models/money_write_result.dart';
import 'package:zaim_api/src/validation.dart';
import 'package:zaim_api/src/zaim_transport.dart';

/// The `/v2/home/money*` endpoints: reading, creating, updating, and deleting
/// the user's money records.
///
/// Obtain an instance from `ZaimClient.money`; this class is not meant to be
/// constructed directly.
///
/// ## Create and update take one method per mode
///
/// Zaim puts the mode in the path (`/v2/home/money/payment`, `.../income`,
/// `.../transfer`) and accepts a different parameter set for each: payments
/// need a genre, income does not; transfers need both accounts, payments only
/// the source. So creates and updates are three separate methods each, which
/// lets the compiler reject a genre on an income or a `toAccountId` on a
/// payment. [delete] is the exception: its payload is nothing but the id, so
/// a single method taking a [MoneyMode] is the smaller surface.
class MoneyApi {
  /// Wraps the client's shared transport. Internal: use `ZaimClient.money`.
  const MoneyApi(this._transport);

  /// The page size [listAll] uses while walking pages. Zaim's maximum.
  static const int _listAllPageSize = maxPageLimit;

  final ZaimTransport _transport;

  /// `GET /v2/home/money` — one page of the user's records.
  ///
  /// **Authentication:** required. **Scope:** read.
  ///
  /// Only records the user entered by hand are returned; anything Zaim
  /// imported automatically from a linked bank or card is invisible to the
  /// API. With no arguments the newest date comes first.
  ///
  /// ## Parameters
  ///
  /// ### Optional
  /// - **[mode]**: Only payments, only income, or only transfers.
  /// - **[categoryId]**: Only records in this category.
  /// - **[genreId]**: Only records in this genre.
  /// - **[order]**: Sort by [MoneyOrder.id] or [MoneyOrder.date]; Zaim
  ///   defaults to date.
  /// - **[startDate]**: Earliest date to include, sent as `Y-m-d`.
  /// - **[endDate]**: Latest date to include, sent as `Y-m-d`.
  /// - **[page]**: 1-based page number (default: `1`).
  /// - **[limit]**: Records per page, at most 100 (default: `20`).
  /// - **[groupByReceiptId]**: Group the response by receipt (default:
  ///   `false`).
  ///
  /// `mapping=1` is always sent and is not exposed here.
  ///
  /// Throws an [ArgumentError] when [page] is below 1 or [limit] is outside
  /// `1..100`.
  Future<List<MoneyRecord>> list({
    MoneyMode? mode,
    int? categoryId,
    int? genreId,
    MoneyOrder? order,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 20,
    bool groupByReceiptId = false,
  }) async {
    checkPaging(page: page, limit: limit);
    final json = await _transport.get(
      '/v2/home/money',
      query: _buildListQuery(
        mode: mode,
        categoryId: categoryId,
        genreId: genreId,
        order: order,
        startDate: startDate,
        endDate: endDate,
        page: page,
        limit: limit,
        groupByReceiptId: groupByReceiptId,
      ),
    );
    return _parseRecords(asMapList(json, 'money'));
  }

  /// Every record matching the filters, walking pages of 100 until Zaim
  /// returns a short page.
  ///
  /// **Authentication:** required. **Scope:** read.
  ///
  /// The stream is lazy: nothing is fetched until it is listened to, and
  /// cancelling it stops the paging. Filters mean the same as on [list];
  /// `page` and `limit` are managed internally.
  Stream<MoneyRecord> listAll({
    MoneyMode? mode,
    int? categoryId,
    int? genreId,
    MoneyOrder? order,
    DateTime? startDate,
    DateTime? endDate,
    bool groupByReceiptId = false,
  }) async* {
    var page = 1;
    while (true) {
      final records = await list(
        mode: mode,
        categoryId: categoryId,
        genreId: genreId,
        order: order,
        startDate: startDate,
        endDate: endDate,
        page: page,
        limit: _listAllPageSize,
        groupByReceiptId: groupByReceiptId,
      );
      yield* Stream.fromIterable(records);
      // A page shorter than the limit — including an empty one — is the last.
      if (records.length < _listAllPageSize) return;
      page++;
    }
  }

  /// `POST /v2/home/money/payment` — records money going out.
  ///
  /// **Authentication:** required. **Scope:** write.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[categoryId]**: The category to file the payment under.
  /// - **[genreId]**: The genre to file the payment under.
  /// - **[amount]**: A positive integer; Zaim takes no decimal point.
  /// - **[date]**: Sent as `Y-m-d`; must be within five years either way.
  ///
  /// ### Optional
  /// - **[fromAccountId]**: The account the money left.
  /// - **[comment]**: At most 100 characters.
  /// - **[name]**: Product name, at most 100 characters.
  /// - **[place]**: Place name, at most 100 characters. Supplying it makes
  ///   Zaim return a [MoneyWriteResult.place] and a `zm-…`
  ///   [MoneyWriteResult.placeUid].
  ///
  /// Throws an [ArgumentError] when [amount] is not positive, [date] is more
  /// than five years away, or any text field exceeds 100 characters.
  Future<MoneyWriteResult> createPayment({
    required int categoryId,
    required int genreId,
    required int amount,
    required DateTime date,
    int? fromAccountId,
    String? comment,
    String? name,
    String? place,
  }) async {
    checkAmount(amount);
    checkFiveYearWindow(date, 'date');
    checkTextLength(comment, 'comment');
    checkTextLength(name, 'name');
    checkTextLength(place, 'place');
    final json = await _transport.post('/v2/home/money/payment', {
      ...ZaimTransport.mappingParameter,
      'category_id': '$categoryId',
      'genre_id': '$genreId',
      'amount': '$amount',
      'date': formatZaimDate(date),
      if (fromAccountId != null) 'from_account_id': '$fromAccountId',
      if (comment != null) 'comment': comment,
      if (name != null) 'name': name,
      if (place != null) 'place': place,
    });
    return MoneyWriteResult.fromJson(json);
  }

  /// `POST /v2/home/money/income` — records money coming in.
  ///
  /// **Authentication:** required. **Scope:** write.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[categoryId]**: The category to file the income under.
  /// - **[amount]**: A positive integer.
  /// - **[date]**: Sent as `Y-m-d`. Zaim only accepts income for the **past
  ///   three months**, and never in the future — a much narrower window than
  ///   payments and transfers get.
  ///
  /// ### Optional
  /// - **[toAccountId]**: The account the money arrived in.
  /// - **[place]**: At most 100 characters. Supplying it makes Zaim return a
  ///   [MoneyWriteResult.place] and a `zi-…` [MoneyWriteResult.placeUid].
  /// - **[comment]**: At most 100 characters.
  ///
  /// Throws an [ArgumentError] when [amount] is not positive, [date] is in
  /// the future or more than three months old, or any text field exceeds 100
  /// characters.
  Future<MoneyWriteResult> createIncome({
    required int categoryId,
    required int amount,
    required DateTime date,
    int? toAccountId,
    String? place,
    String? comment,
  }) async {
    checkAmount(amount);
    checkIncomeWindow(date, 'date');
    checkTextLength(place, 'place');
    checkTextLength(comment, 'comment');
    final json = await _transport.post('/v2/home/money/income', {
      ...ZaimTransport.mappingParameter,
      'category_id': '$categoryId',
      'amount': '$amount',
      'date': formatZaimDate(date),
      if (toAccountId != null) 'to_account_id': '$toAccountId',
      if (place != null) 'place': place,
      if (comment != null) 'comment': comment,
    });
    return MoneyWriteResult.fromJson(json);
  }

  /// `POST /v2/home/money/transfer` — moves money between two of the user's
  /// own accounts.
  ///
  /// **Authentication:** required. **Scope:** write.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[amount]**: A positive integer.
  /// - **[date]**: Sent as `Y-m-d`; must be within five years either way.
  /// - **[fromAccountId]**: The source account.
  /// - **[toAccountId]**: The destination account, which must differ from
  ///   the source.
  ///
  /// ### Optional
  /// - **[comment]**: At most 100 characters.
  ///
  /// Throws an [ArgumentError] when the two accounts are the same, [amount]
  /// is not positive, [date] is more than five years away, or [comment]
  /// exceeds 100 characters.
  Future<MoneyWriteResult> createTransfer({
    required int amount,
    required DateTime date,
    required int fromAccountId,
    required int toAccountId,
    String? comment,
  }) async {
    checkAmount(amount);
    checkFiveYearWindow(date, 'date');
    checkTransferAccounts(fromAccountId, toAccountId);
    checkTextLength(comment, 'comment');
    final json = await _transport.post('/v2/home/money/transfer', {
      ...ZaimTransport.mappingParameter,
      'amount': '$amount',
      'date': formatZaimDate(date),
      'from_account_id': '$fromAccountId',
      'to_account_id': '$toAccountId',
      if (comment != null) 'comment': comment,
    });
    return MoneyWriteResult.fromJson(json);
  }

  /// `PUT /v2/home/money/payment/:id` — rewrites an existing payment.
  ///
  /// **Authentication:** required. **Scope:** write.
  ///
  /// Zaim requires [amount] and [date] on every update, even when they have
  /// not changed. [date] must be within five years either way.
  ///
  /// Throws an [ArgumentError] on the same conditions as [createPayment].
  Future<MoneyWriteResult> updatePayment(
    int id, {
    required int amount,
    required DateTime date,
    int? categoryId,
    int? genreId,
    int? fromAccountId,
    String? comment,
  }) async {
    checkAmount(amount);
    checkFiveYearWindow(date, 'date');
    checkTextLength(comment, 'comment');
    final json = await _transport.put('/v2/home/money/payment/$id', {
      ...ZaimTransport.mappingParameter,
      'amount': '$amount',
      'date': formatZaimDate(date),
      if (categoryId != null) 'category_id': '$categoryId',
      if (genreId != null) 'genre_id': '$genreId',
      if (fromAccountId != null) 'from_account_id': '$fromAccountId',
      if (comment != null) 'comment': comment,
    });
    return MoneyWriteResult.fromJson(json);
  }

  /// `PUT /v2/home/money/income/:id` — rewrites an existing income record.
  ///
  /// **Authentication:** required. **Scope:** write.
  ///
  /// Zaim requires [amount] and [date] on every update.
  ///
  /// NOTE: the three-month window is documented for *creating* income only.
  /// The update parameter table gives the same ±5 year window as the other
  /// two modes, so that is what is enforced here.
  ///
  /// Throws an [ArgumentError] when [amount] is not positive, [date] is more
  /// than five years away, or [comment] exceeds 100 characters.
  Future<MoneyWriteResult> updateIncome(
    int id, {
    required int amount,
    required DateTime date,
    int? categoryId,
    int? toAccountId,
    String? comment,
  }) async {
    checkAmount(amount);
    checkFiveYearWindow(date, 'date');
    checkTextLength(comment, 'comment');
    final json = await _transport.put('/v2/home/money/income/$id', {
      ...ZaimTransport.mappingParameter,
      'amount': '$amount',
      'date': formatZaimDate(date),
      if (categoryId != null) 'category_id': '$categoryId',
      if (toAccountId != null) 'to_account_id': '$toAccountId',
      if (comment != null) 'comment': comment,
    });
    return MoneyWriteResult.fromJson(json);
  }

  /// `PUT /v2/home/money/transfer/:id` — rewrites an existing transfer.
  ///
  /// **Authentication:** required. **Scope:** write.
  ///
  /// Zaim requires [amount] and [date] on every update. Unlike
  /// [createTransfer] the two accounts are optional here, but when both are
  /// given they must still differ.
  ///
  /// Throws an [ArgumentError] when the two accounts are the same, [amount]
  /// is not positive, [date] is more than five years away, or [comment]
  /// exceeds 100 characters.
  Future<MoneyWriteResult> updateTransfer(
    int id, {
    required int amount,
    required DateTime date,
    int? fromAccountId,
    int? toAccountId,
    String? comment,
  }) async {
    checkAmount(amount);
    checkFiveYearWindow(date, 'date');
    checkTransferAccounts(fromAccountId, toAccountId);
    checkTextLength(comment, 'comment');
    final json = await _transport.put('/v2/home/money/transfer/$id', {
      ...ZaimTransport.mappingParameter,
      'amount': '$amount',
      'date': formatZaimDate(date),
      if (fromAccountId != null) 'from_account_id': '$fromAccountId',
      if (toAccountId != null) 'to_account_id': '$toAccountId',
      if (comment != null) 'comment': comment,
    });
    return MoneyWriteResult.fromJson(json);
  }

  /// `DELETE /v2/home/money/{mode}/:id` — removes a record.
  ///
  /// **Authentication:** required. **Scope:** write.
  ///
  /// [mode] must match the record's own mode, since Zaim keys the endpoint on
  /// it; [MoneyRecord.mode] carries it. Delete takes no other parameters,
  /// which is why one method covers all three modes.
  Future<MoneyWriteResult> delete(MoneyMode mode, int id) async {
    final json = await _transport.delete(
      '/v2/home/money/${mode.wireName}/$id',
      query: ZaimTransport.mappingParameter,
    );
    return MoneyWriteResult.fromJson(json);
  }

  /// Parses the `money` array, dropping records `MoneyRecord.fromJson`
  /// cannot parse rather than letting one bad record fail the whole page.
  ///
  /// The only way `MoneyRecord.fromJson` throws is a `mode` value outside
  /// `payment` / `income` / `transfer` — Zaim adding a mode this package does
  /// not know yet. That should not cost the caller every other record in the
  /// response.
  static List<MoneyRecord> _parseRecords(List<Map<String, dynamic>> maps) {
    final records = <MoneyRecord>[];
    for (final map in maps) {
      try {
        records.add(MoneyRecord.fromJson(map));
      } on FormatException {
        // Skip: an unrecognised `mode` this package does not know yet.
      }
    }
    return List.unmodifiable(records);
  }

  /// Builds the query for [list]: `mapping=1` is always included and both
  /// dates are rendered as `Y-m-d`.
  static Map<String, String> _buildListQuery({
    MoneyMode? mode,
    int? categoryId,
    int? genreId,
    MoneyOrder? order,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 20,
    bool groupByReceiptId = false,
  }) =>
      {
        ...ZaimTransport.mappingParameter,
        if (categoryId != null) 'category_id': '$categoryId',
        if (genreId != null) 'genre_id': '$genreId',
        if (mode != null) 'mode': mode.wireName,
        if (order != null) 'order': order.wireName,
        if (startDate != null) 'start_date': formatZaimDate(startDate),
        if (endDate != null) 'end_date': formatZaimDate(endDate),
        'page': '$page',
        'limit': '$limit',
        if (groupByReceiptId) 'group_by': 'receipt_id',
      };
}
