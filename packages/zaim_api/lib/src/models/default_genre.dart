import 'package:meta/meta.dart';
import 'package:zaim_api/src/json_utils.dart';

/// A genre from Zaim's public genre master, `GET /v2/genre`.
///
/// This endpoint needs no authentication and returns only an id, its parent
/// category id, and a name. For the genres a signed-in user actually has, use
/// `client.genre.list()` and `ZaimGenre`.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: The master genre id.
/// - **[categoryId]**: The master category this genre sits under.
/// - **[name]**: The English display name.
@immutable
class DefaultGenre {
  /// Creates a master genre.
  const DefaultGenre({
    required this.id,
    required this.categoryId,
    required this.name,
  });

  /// Parses one element of the `genres` array.
  factory DefaultGenre.fromJson(Map<String, dynamic> json) => DefaultGenre(
        id: asInt(json, 'id'),
        categoryId: asInt(json, 'category_id'),
        name: asString(json, 'name'),
      );

  /// The master genre id.
  final int id;

  /// The master category this genre belongs to.
  final int categoryId;

  /// The display name, for example `Grocery`.
  final String name;

  /// Serialises back to Zaim's wire format.
  Map<String, dynamic> toJson() => {
        'id': id,
        'category_id': categoryId,
        'name': name,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DefaultGenre &&
          other.id == id &&
          other.categoryId == categoryId &&
          other.name == name;

  @override
  int get hashCode => Object.hash(id, categoryId, name);

  @override
  String toString() =>
      'DefaultGenre(id: $id, categoryId: $categoryId, name: $name)';
}
