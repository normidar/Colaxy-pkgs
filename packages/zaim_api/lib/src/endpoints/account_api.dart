import 'package:zaim_api/src/json_utils.dart';
import 'package:zaim_api/src/models/zaim_account.dart';
import 'package:zaim_api/src/zaim_transport.dart';

/// The `/v2/home/account` endpoint.
///
/// Obtain an instance from `ZaimClient.account`; this class is not meant to
/// be constructed directly.
class AccountApi {
  /// Wraps the client's shared transport. Internal: use `ZaimClient.account`.
  const AccountApi(this._transport);

  final ZaimTransport _transport;

  /// `GET /v2/home/account` — the user's own accounts.
  ///
  /// **Authentication:** required. **Scope:** read.
  ///
  /// `mapping=1` is sent automatically. Inactive accounts are included; use
  /// [ZaimAccount.isActive] to filter them out.
  Future<List<ZaimAccount>> list() async {
    final json = await _transport.get(
      '/v2/home/account',
      query: ZaimTransport.mappingParameter,
    );
    return asMapList(json, 'accounts')
        .map(ZaimAccount.fromJson)
        .toList(growable: false);
  }
}
