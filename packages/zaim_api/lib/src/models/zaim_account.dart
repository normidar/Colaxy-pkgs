import 'package:meta/meta.dart';
import 'package:zaim_api/src/json_utils.dart';

/// One of the user's own accounts, from `GET /v2/home/account`.
///
/// Accounts are the wallets, bank accounts, and cards money moves between.
/// Their ids go into `from_account_id` and `to_account_id`.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: The account id to pass to the money endpoints.
/// - **[name]**: The display name.
///
/// ### Optional
/// - **[sort]**: Display order (default: `0`).
/// - **[active]**: `1` while the account is in use (default: `1`).
/// - **[localId]**: Zaim's local identifier for the account (default: `null`).
/// - **[websiteId]**: The aggregation source, `null` when Zaim sent `0`
///   (default: `null`).
/// - **[parentAccountId]**: The master account this one derives from, `null`
///   when Zaim sent `0` (default: `null`).
/// - **[modified]**: When the account last changed (default: `null`).
@immutable
class ZaimAccount {
  /// Creates an account.
  const ZaimAccount({
    required this.id,
    required this.name,
    this.sort = 0,
    this.active = 1,
    this.localId,
    this.websiteId,
    this.parentAccountId,
    this.modified,
  });

  /// Parses one element of the `accounts` array.
  factory ZaimAccount.fromJson(Map<String, dynamic> json) => ZaimAccount(
        id: asInt(json, 'id'),
        name: asString(json, 'name'),
        sort: asInt(json, 'sort'),
        active: asInt(json, 'active', fallback: 1),
        localId: asId(json, 'local_id'),
        websiteId: asId(json, 'website_id'),
        parentAccountId: asId(json, 'parent_account_id'),
        modified: asTimestamp(json, 'modified'),
      );

  /// The account id. Use it for `from_account_id` and `to_account_id`.
  final int id;

  /// The display name.
  final String name;

  /// The display order within the user's list.
  final int sort;

  /// The raw `active` flag: `1` for a live account. See [isActive].
  final int active;

  /// Zaim's local identifier for the account, or `null` when it has none.
  final int? localId;

  /// The aggregation website the account is linked to, or `null` for a purely
  /// manual account.
  final int? websiteId;

  /// The master account this one derives from, or `null` when it has none.
  final int? parentAccountId;

  /// When the account was last modified, in UTC.
  final DateTime? modified;

  /// Whether the account is live, i.e. whether [active] is `1`.
  bool get isActive => active == 1;

  /// Serialises back to Zaim's wire format.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'modified': modified == null ? null : formatZaimTimestamp(modified!),
        'sort': sort,
        'active': active,
        'local_id': localId ?? 0,
        'website_id': websiteId ?? 0,
        'parent_account_id': parentAccountId ?? 0,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZaimAccount &&
          other.id == id &&
          other.name == name &&
          other.sort == sort &&
          other.active == active &&
          other.localId == localId &&
          other.websiteId == websiteId &&
          other.parentAccountId == parentAccountId &&
          other.modified == modified;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        sort,
        active,
        localId,
        websiteId,
        parentAccountId,
        modified,
      );

  @override
  String toString() => 'ZaimAccount(id: $id, name: $name, sort: $sort, '
      'active: $active, parentAccountId: $parentAccountId)';
}
