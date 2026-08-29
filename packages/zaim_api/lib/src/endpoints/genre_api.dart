import 'package:zaim_api/src/json_utils.dart';
import 'package:zaim_api/src/models/zaim_genre.dart';
import 'package:zaim_api/src/zaim_transport.dart';

/// The `/v2/home/genre` endpoint.
///
/// Obtain an instance from `ZaimClient.genre`; this class is not meant to be
/// constructed directly.
class GenreApi {
  /// Wraps the client's shared transport. Internal: use `ZaimClient.genre`.
  const GenreApi(this._transport);

  final ZaimTransport _transport;

  /// `GET /v2/home/genre` — the user's own genres.
  ///
  /// **Authentication:** required. **Scope:** read.
  ///
  /// `mapping=1` is sent automatically. Inactive genres are included; use
  /// [ZaimGenre.isActive] to filter them out.
  Future<List<ZaimGenre>> list() async {
    final json = await _transport.get(
      '/v2/home/genre',
      query: ZaimTransport.mappingParameter,
    );
    return asMapList(json, 'genres')
        .map(ZaimGenre.fromJson)
        .toList(growable: false);
  }
}
