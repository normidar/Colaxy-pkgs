import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/src/app_store/app_store_build.dart';
import 'package:colaxy_store_publish/src/app_store/app_store_builds_api.dart';
import 'package:colaxy_store_publish/src/app_store/beta_group.dart';
import 'package:colaxy_store_publish/src/app_store/beta_groups_api.dart';
import 'package:colaxy_store_publish/src/app_store/build_beta_detail.dart';
import 'package:colaxy_store_publish/src/core/store_publish_exception.dart';

/// Getting one build to a set of TestFlight groups.
///
/// This class exists for a single reason: **assigning a build to an external
/// group is not enough.** The assignment succeeds, App Store Connect shows
/// the build against the group, and no tester ever receives it — it sits at
/// `READY_FOR_BETA_SUBMISSION` until something posts a
/// `betaAppReviewSubmissions`. Every part of that failure reports success.
///
/// [distribute] does the whole sequence and reports what it found, including
/// the two conditions that silently strand a build:
///
/// - an external group with no beta review submission,
/// - a build with no export compliance answer.
///
/// ## Parameters
///
/// ### Required
/// - **[builds]**: The builds client for the app.
/// - **[groups]**: The beta groups client for the app.
///
/// ### Optional
/// - **[onLog]**: Receives one line per step (default: `null`).
class TestFlightApi {
  /// Creates a TestFlight client.
  const TestFlightApi({
    required this.builds,
    required this.groups,
    this.onLog,
  });

  /// The builds client for the app.
  final AppStoreBuildsApi builds;

  /// The beta groups client for the app.
  final BetaGroupsApi groups;

  /// Receives one line per step.
  final StoreConsoleLog? onLog;

  /// Gives [buildId] to the named groups, and submits for beta review if any
  /// of them is external.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[buildId]**: The build to distribute.
  /// - **[groupNames]**: Group names as they appear in App Store Connect.
  ///
  /// ### Optional
  /// - **[testerNotes]**: "What to test" text keyed by locale. Written to the
  ///   build, not to the App Store listing — they are different fields on
  ///   different resources (default: empty).
  /// - **[submitForBetaReview]**: Whether to submit when an external group is
  ///   involved (default: `true`). Turning it off leaves external testers
  ///   without the build, which is only ever what you want if something else
  ///   submits it.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final detail = await testFlight.distribute(
  ///   buildId: build.id,
  ///   groupNames: ['Internal'],
  ///   testerNotes: {'ja': '不具合の修正'},
  /// );
  /// ```
  Future<BuildBetaDetail?> distribute({
    required String buildId,
    required List<String> groupNames,
    Map<String, String> testerNotes = const {},
    bool submitForBetaReview = true,
  }) async {
    if (groupNames.isEmpty) {
      throw ArgumentError.value(
        groupNames,
        'groupNames',
        'Name at least one group; a build assigned to nothing reaches nobody',
      );
    }

    final resolved = <BetaGroup>[];
    final available = await groups.list();
    for (final name in groupNames) {
      final group = available.where((g) => g.name == name).firstOrNull;
      if (group == null) {
        throw FastlaneLayoutException(
          'No TestFlight group named "$name". The app has: '
          '${available.map((g) => g.name ?? '?').join(', ')}.',
        );
      }
      resolved.add(group);
    }

    for (final entry in testerNotes.entries) {
      await builds.setTesterNote(
        buildId: buildId,
        locale: entry.key,
        whatsNew: entry.value,
      );
      onLog?.call('wrote tester note for ${entry.key}');
    }

    for (final group in resolved) {
      await groups.addBuild(groupId: group.id, buildId: buildId);
      onLog?.call('gave ${group.name} access to the build');
    }

    final external = resolved.where((group) => group.needsBetaReview).toList();
    if (external.isNotEmpty && submitForBetaReview) {
      await builds.submitForBetaReview(buildId);
      onLog?.call(
        'submitted for beta review, needed by: '
        '${external.map((g) => g.name ?? '?').join(', ')}',
      );
    } else if (external.isNotEmpty) {
      onLog?.call(
        'NOT submitted for beta review, so ${external.length} external '
        'group(s) will not receive this build',
      );
    }

    final detail = await builds.betaDetail(buildId);
    _warnAboutStrandedBuild(detail, external.isNotEmpty);
    return detail;
  }

  /// The most recent build, with its TestFlight state.
  ///
  /// A convenience for the common shape of a release job: find what was just
  /// uploaded, then hand it to [distribute].
  Future<(AppStoreBuild, BuildBetaDetail?)?> latestWithState({
    String? preReleaseVersion,
  }) async {
    final build = await builds.latest(preReleaseVersion: preReleaseVersion);
    if (build == null) return null;
    return (build, await builds.betaDetail(build.id));
  }

  /// Logs the two states that leave a build reaching nobody.
  ///
  /// Not raised as an error: both are recoverable, both are Apple's to
  /// resolve, and a run that has already assigned the build has done real
  /// work worth reporting. But neither is visible without looking.
  void _warnAboutStrandedBuild(BuildBetaDetail? detail, bool hasExternal) {
    if (detail == null) return;
    if (detail.missingExportCompliance) {
      onLog?.call(
        'WARNING: the build has no export compliance answer, so it reaches '
        'no tester. Call builds.setExportCompliance to clear it.',
      );
    }
    if (hasExternal && detail.awaitsBetaSubmission) {
      onLog?.call(
        'WARNING: the build is READY_FOR_BETA_SUBMISSION, so external '
        'testers do not have it yet.',
      );
    }
  }
}
