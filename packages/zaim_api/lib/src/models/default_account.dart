import 'package:meta/meta.dart';
import 'package:zaim_api/src/json_utils.dart';

/// An account from Zaim's public account master, `GET /v2/account`.
///
/// This endpoint needs no authentication and returns only an id and a name —
/// it describes the account types Zaim ships with, not any user's accounts.
/// For the accounts a signed-in user actually has, use `client.account.list()`
/// and the richer `ZaimAccount`.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: The master account id.
/// - **[name]**: The English display name.
@immutable
class DefaultAccount {
  /// Creates a master account.
  const DefaultAccount({required this.id, required this.name});

  /// Parses one element of the `accounts` array.
  factory DefaultAccount.fromJson(Map<String, dynamic> json) => DefaultAccount(
        id: asInt(json, 'id'),
        name: asString(json, 'name'),
      );

  /// The master account id.
  final int id;

  /// The display name, for example `Wallet`.
  final String name;

  /// Serialises back to Zaim's wire format.
  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DefaultAccount && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'DefaultAccount(id: $id, name: $name)';
}
