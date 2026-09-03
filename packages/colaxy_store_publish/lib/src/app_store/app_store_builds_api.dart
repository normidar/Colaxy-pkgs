import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/src/app_store/app_store_build.dart';
import 'package:colaxy_store_publish/src/app_store/beta_build_localization.dart';
import 'package:colaxy_store_publish/src/app_store/build_beta_detail.dart';

/// The builds of one app, and their TestFlight state.
///
/// **Read-only as far as creating builds goes**: `/v1/builds` accepts `GET`
/// only. A build appears as the result of an upload, so everything here
/// either finds one or adjusts one that already exists.
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
/// final build = await api.latest();
/// final detail = await api.betaDetail(build!.id);
/// ```
class AppStoreBuildsApi {
  /// Creates a builds client for one app.
  const AppStoreBuildsApi({
    required AppStoreConnectClient client,
    required this.appId,
  }) : _client = client;

  /// The numeric app ID.
  final String appId;

  final AppStoreConnectClient _client;

  /// The app's builds, newest first as Apple returns them.
  ///
  /// ## Parameters
  ///
  /// ### Optional
  /// - **[version]**: The build number to filter on, e.g. `412`. This is
  ///   `CFBundleVersion`, **not** the marketing version — Apple keeps that on
  ///   the pre-release version, which is a different filter.
  /// - **[preReleaseVersion]**: The marketing version, e.g. `1.4.0`.
  /// - **[expired]**: Whether to include expired builds (default: `false`,
  ///   excluding them).
  Future<List<AppStoreBuild>> list({
    String? version,
    String? preReleaseVersion,
    bool expired = false,
  }) async {
    final resources = await _client
        .resources(
          '/v1/builds',
          query: {
            'filter[app]': appId,
            'filter[version]': version,
            'filter[preReleaseVersion.version]': preReleaseVersion,
            'filter[expired]': '$expired',
            'limit': 200,
          },
        )
        .toList();
    return [for (final json in resources) AppStoreBuild.fromJson(json)];
  }

  /// The most recently uploaded build, or `null` if the app has none.
  ///
  /// ## Parameters
  ///
  /// ### Optional
  /// - **[version]**: Narrow to one build number.
  /// - **[preReleaseVersion]**: Narrow to one marketing version.
  Future<AppStoreBuild?> latest({
    String? version,
    String? preReleaseVersion,
  }) async {
    final builds = await list(
      version: version,
      preReleaseVersion: preReleaseVersion,
    );
    if (builds.isEmpty) return null;
    // Apple's default ordering is not documented as newest-first, so sort on
    // the field that actually says when the build arrived.
    builds.sort((a, b) {
      final left = a.uploadedDate;
      final right = b.uploadedDate;
      if (left == null || right == null) return 0;
      return right.compareTo(left);
    });
    return builds.first;
  }

  /// The TestFlight state of [buildId], for internal and external testers.
  ///
  /// Worth reading after any distribution: this is where "assigned but
  /// reaching nobody" shows up, as `READY_FOR_BETA_SUBMISSION` on the
  /// external side.
  Future<BuildBetaDetail?> betaDetail(String buildId) async {
    final resources = await _client
        .resources(
          '/v1/buildBetaDetails',
          query: {'filter[build]': buildId, 'limit': 10},
        )
        .toList();
    if (resources.isEmpty) return null;
    return BuildBetaDetail.fromJson(resources.first);
  }

  /// Answers the export compliance question for [buildId].
  ///
  /// A build with this unanswered sits in `MISSING_EXPORT_COMPLIANCE` and
  /// reaches no tester, which looks exactly like a distribution that worked.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[buildId]**: The build to answer for.
  /// - **[usesNonExemptEncryption]**: Whether the app uses encryption that
  ///   is not exempt. Answering this wrongly is a compliance matter, not a
  ///   publishing detail — there is no default here for that reason.
  Future<AppStoreBuild> setExportCompliance({
    required String buildId,
    required bool usesNonExemptEncryption,
  }) async {
    final response = await _client.patchJson('/v1/builds/$buildId', {
      'data': {
        'type': 'builds',
        'id': buildId,
        'attributes': {'usesNonExemptEncryption': usesNonExemptEncryption},
      },
    });
    return AppStoreBuild.fromJson(
      response['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  /// The tester-facing notes on [buildId].
  Future<List<BetaBuildLocalization>> testerNotes(String buildId) async {
    final resources = await _client
        .resources(
          '/v1/builds/$buildId/betaBuildLocalizations',
          query: {'limit': 200},
        )
        .toList();
    return [
      for (final json in resources) BetaBuildLocalization.fromJson(json),
    ];
  }

  /// Writes the tester-facing note for one locale on [buildId].
  ///
  /// Distinct from an App Store version's `whatsNew`: that is the public
  /// release note, this is what TestFlight shows testers. They come from the
  /// same `release_notes.txt` but are two separate writes.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[buildId]**: The build to annotate.
  /// - **[locale]**: The App Store locale.
  /// - **[whatsNew]**: The note.
  Future<BetaBuildLocalization> setTesterNote({
    required String buildId,
    required String locale,
    required String whatsNew,
  }) async {
    for (final existing in await testerNotes(buildId)) {
      if (existing.locale != locale || existing.id == null) continue;
      final response = await _client.patchJson(
        '/v1/betaBuildLocalizations/${existing.id}',
        {
          'data': {
            'type': 'betaBuildLocalizations',
            'id': existing.id,
            'attributes': {'whatsNew': whatsNew},
          },
        },
      );
      return BetaBuildLocalization.fromJson(
        response['data'] as Map<String, dynamic>? ?? const {},
      );
    }

    final response = await _client.postJson('/v1/betaBuildLocalizations', {
      'data': {
        'type': 'betaBuildLocalizations',
        'attributes': {'locale': locale, 'whatsNew': whatsNew},
        'relationships': {
          'build': {
            'data': {'type': 'builds', 'id': buildId},
          },
        },
      },
    });
    return BetaBuildLocalization.fromJson(
      response['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  /// Submits [buildId] for Apple's beta review.
  ///
  /// Required before **external** testers can receive a build. Assigning a
  /// build to an external group and stopping there leaves it at "Ready to
  /// Submit" and no tester ever sees it — the single most common way a
  /// TestFlight automation appears to work and does nothing.
  ///
  /// Internal groups do not need this.
  Future<void> submitForBetaReview(String buildId) => _client.postJson(
    '/v1/betaAppReviewSubmissions',
    {
      'data': {
        'type': 'betaAppReviewSubmissions',
        'relationships': {
          'build': {
            'data': {'type': 'builds', 'id': buildId},
          },
        },
      },
    },
  );
}
