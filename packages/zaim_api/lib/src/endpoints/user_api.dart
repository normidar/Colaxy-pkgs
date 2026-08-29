import 'package:zaim_api/src/json_utils.dart';
import 'package:zaim_api/src/models/zaim_user.dart';
import 'package:zaim_api/src/zaim_transport.dart';

/// The `/v2/home/user/*` endpoints.
///
/// Obtain an instance from `ZaimClient.user`; this class is not meant to be
/// constructed directly.
class UserApi {
  /// Wraps the client's shared transport. Internal: use `ZaimClient.user`.
  const UserApi(this._transport);

  final ZaimTransport _transport;

  /// `GET /v2/home/user/verify` — the user the credentials belong to.
  ///
  /// **Authentication:** required. **Scope:** none — this call works with a
  /// read-only or a write app alike, which makes it the cheapest way to check
  /// whether the stored credentials are still valid.
  ///
  /// Throws a `ZaimAuthException` when they are not, for instance because the
  /// app was not registered as *permanently accessible* and the 24-hour
  /// permission window has closed.
  Future<ZaimUser> verify() async {
    final json = await _transport.get('/v2/home/user/verify');
    return ZaimUser.fromJson(asMap(json, 'me') ?? const <String, dynamic>{});
  }
}
