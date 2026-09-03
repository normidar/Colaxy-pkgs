import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/src/app_store/beta_group.dart';
import 'package:colaxy_store_publish/src/app_store/beta_tester.dart';

/// The TestFlight groups of one app.
///
/// ## Parameters
///
/// ### Required
/// - **`client`**: An authenticated App Store Connect client.
/// - **[appId]**: The numeric app ID.
///
/// ## Example
///
/// ```dart
/// final group = await api.byName('Internal');
/// await api.addBuild(groupId: group!.id, buildId: build.id);
/// ```
class BetaGroupsApi {
  /// Creates a beta groups client for one app.
  const BetaGroupsApi({
    required AppStoreConnectClient client,
    required this.appId,
  }) : _client = client;

  /// The numeric app ID.
  final String appId;

  final AppStoreConnectClient _client;

  /// Every group the app has.
  Future<List<BetaGroup>> list() async {
    final resources = await _client
        .resources('/v1/apps/$appId/betaGroups', query: {'limit': 200})
        .toList();
    return [for (final json in resources) BetaGroup.fromJson(json)];
  }

  /// The group called [name], or `null` if the app has none.
  ///
  /// Matched exactly. Group names are chosen by hand in App Store Connect and
  /// a near-match is more likely a typo than an intent.
  Future<BetaGroup?> byName(String name) async {
    for (final group in await list()) {
      if (group.name == name) return group;
    }
    return null;
  }

  /// Creates a group.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[name]**: The group's name.
  ///
  /// ### Optional
  /// - **[isInternalGroup]**: Whether it is internal (default: `false`).
  ///   Internal groups receive builds without Apple's beta review; external
  ///   ones do not.
  /// - **[hasAccessToAllBuilds]**: Whether every build reaches it
  ///   automatically (default: `null`, leaving Apple's default).
  /// - **[feedbackEnabled]**: Whether testers can send feedback
  ///   (default: `null`).
  Future<BetaGroup> create({
    required String name,
    bool isInternalGroup = false,
    bool? hasAccessToAllBuilds,
    bool? feedbackEnabled,
  }) async {
    final response = await _client.postJson('/v1/betaGroups', {
      'data': {
        'type': 'betaGroups',
        'attributes': <String, dynamic>{
          'name': name,
          'isInternalGroup': isInternalGroup,
          'hasAccessToAllBuilds': ?hasAccessToAllBuilds,
          'feedbackEnabled': ?feedbackEnabled,
        },
        'relationships': {
          'app': {
            'data': {'type': 'apps', 'id': appId},
          },
        },
      },
    });
    return BetaGroup.fromJson(
      response['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  /// Gives [groupId] access to [buildId].
  ///
  /// For an **external** group this is not enough on its own: the build also
  /// has to go through `AppStoreBuildsApi.submitForBetaReview`, or it sits at
  /// "Ready to Submit" and no tester sees it.
  Future<void> addBuild({
    required String groupId,
    required String buildId,
  }) => _client.postJson(
    '/v1/betaGroups/$groupId/relationships/builds',
    {
      'data': [
        {'type': 'builds', 'id': buildId},
      ],
    },
  );

  // Removing a build from a group is deliberately absent. The endpoint is
  // `DELETE /v1/betaGroups/{id}/relationships/builds` and it needs a request
  // body naming what to remove; `AppStoreConnectClient.delete` sends none,
  // and inventing a path that takes a POST instead would be a guess. Nothing
  // in a publish needs it, so it waits for a body-carrying delete rather than
  // shipping something unverified.

  /// The testers in [groupId].
  Future<List<BetaTester>> testers(String groupId) async {
    final resources = await _client
        .resources('/v1/betaGroups/$groupId/betaTesters', query: {'limit': 200})
        .toList();
    return [for (final json in resources) BetaTester.fromJson(json)];
  }

  /// Adds testers that already exist on the account to [groupId].
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[groupId]**: The group to add to.
  /// - **[testerIds]**: Apple identifiers of existing testers.
  Future<void> addTesters({
    required String groupId,
    required List<String> testerIds,
  }) async {
    if (testerIds.isEmpty) return;
    await _client.postJson(
      '/v1/betaGroups/$groupId/relationships/betaTesters',
      {
        'data': [
          for (final id in testerIds) {'type': 'betaTesters', 'id': id},
        ],
      },
    );
  }
}
