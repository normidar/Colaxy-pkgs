import 'package:zaim_api/src/json_utils.dart';
import 'package:zaim_api/src/models/zaim_category.dart';
import 'package:zaim_api/src/zaim_transport.dart';

/// The `/v2/home/category` endpoint.
///
/// Obtain an instance from `ZaimClient.category`; this class is not meant to
/// be constructed directly.
class CategoryApi {
  /// Wraps the client's shared transport. Internal: use `ZaimClient.category`.
  const CategoryApi(this._transport);

  final ZaimTransport _transport;

  /// `GET /v2/home/category` — the user's own categories.
  ///
  /// **Authentication:** required. **Scope:** read.
  ///
  /// `mapping=1` is sent automatically. Inactive categories are included; use
  /// [ZaimCategory.isActive] to filter them out.
  Future<List<ZaimCategory>> list() async {
    final json = await _transport.get(
      '/v2/home/category',
      query: ZaimTransport.mappingParameter,
    );
    return asMapList(json, 'categories')
        .map(ZaimCategory.fromJson)
        .toList(growable: false);
  }
}
