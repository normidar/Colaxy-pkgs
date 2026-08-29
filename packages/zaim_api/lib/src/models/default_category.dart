import 'package:meta/meta.dart';
import 'package:zaim_api/src/json_utils.dart';
import 'package:zaim_api/src/models/money_mode.dart';

/// A category from Zaim's public category master, `GET /v2/category`.
///
/// This endpoint needs no authentication and returns only an id, a mode, and
/// a name. For the categories a signed-in user actually has — which may be
/// renamed or deactivated — use `client.category.list()` and `ZaimCategory`.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: The master category id.
/// - **[name]**: The English display name.
///
/// ### Optional
/// - **[mode]**: `payment` or `income`, or `null` when unrecognised
///   (default: `null`).
@immutable
class DefaultCategory {
  /// Creates a master category.
  const DefaultCategory({required this.id, required this.name, this.mode});

  /// Parses one element of the `categories` array.
  factory DefaultCategory.fromJson(Map<String, dynamic> json) =>
      DefaultCategory(
        id: asInt(json, 'id'),
        name: asString(json, 'name'),
        mode: MoneyMode.tryParse(asStringOrNull(json, 'mode')),
      );

  /// The master category id.
  final int id;

  /// The display name, for example `Food`.
  final String name;

  /// Whether the category applies to payments or income, or `null` when Zaim
  /// sent a value this package does not know.
  final MoneyMode? mode;

  /// Serialises back to Zaim's wire format.
  Map<String, dynamic> toJson() => {
        'id': id,
        'mode': mode?.wireName,
        'name': name,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DefaultCategory &&
          other.id == id &&
          other.name == name &&
          other.mode == mode;

  @override
  int get hashCode => Object.hash(id, name, mode);

  @override
  String toString() =>
      'DefaultCategory(id: $id, name: $name, mode: ${mode?.wireName})';
}
