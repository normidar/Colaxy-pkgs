import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/src/app_store/beta_tester.dart';

/// The TestFlight testers on an account.
///
/// Testers belong to the account, not to an app: creating one and adding it
/// to a group are the same request when the group is named up front, and two
/// requests otherwise.
///
/// ## Parameters
///
/// ### Required
/// - **`client`**: An authenticated App Store Connect client.
///
/// ## Example
///
/// ```dart
/// await api.invite(
///   const BetaTester(email: 'tester@example.com'),
///   groupIds: [group.id],
/// );
/// ```
class BetaTestersApi {
  /// Creates a testers client.
  const BetaTestersApi({required AppStoreConnectClient client})
    : _client = client;

  final AppStoreConnectClient _client;

  /// Testers on the account, optionally narrowed to one app or group.
  Future<List<BetaTester>> list({String? appId, String? groupId}) async {
    final resources = await _client
        .resources(
          '/v1/betaTesters',
          query: {
            'filter[apps]': appId,
            'filter[betaGroups]': groupId,
            'limit': 200,
          },
        )
        .toList();
    return [for (final json in resources) BetaTester.fromJson(json)];
  }

  /// Adds [tester], putting them straight into [groupIds].
  ///
  /// Apple keys testers by email. Inviting someone the account already knows
  /// attaches the existing record to the group rather than creating a second
  /// one — so this is safe to run repeatedly, which is what a CI job needs.
  ///
  /// **This sends a real invitation email** when the group is external.
  /// There is no dry run for it.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[tester]**: The tester. Only `email` is required.
  ///
  /// ### Optional
  /// - **[groupIds]**: Groups to add them to (default: none, leaving the
  ///   tester on the account and in no group).
  Future<BetaTester> invite(
    BetaTester tester, {
    List<String> groupIds = const [],
  }) async {
    if (tester.email.isEmpty) {
      throw ArgumentError.value(
        tester.email,
        'tester.email',
        'A tester needs an email address; Apple keys them by it',
      );
    }
    final response = await _client.postJson('/v1/betaTesters', {
      'data': {
        'type': 'betaTesters',
        'attributes': tester.toAttributes(),
        if (groupIds.isNotEmpty)
          'relationships': {
            'betaGroups': {
              'data': [
                for (final id in groupIds) {'type': 'betaGroups', 'id': id},
              ],
            },
          },
      },
    });
    return BetaTester.fromJson(
      response['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  /// Removes a tester from the account entirely.
  ///
  /// Destructive and account-wide: it does not merely drop them from one
  /// group. Never called for you.
  Future<void> remove(String testerId) =>
      _client.delete('/v1/betaTesters/$testerId');
}
