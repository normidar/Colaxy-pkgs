import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/src/app_store/review_submission.dart';

/// Submitting an app version to App Store review.
///
/// **Nothing here is called automatically by anything else in this package.**
/// Submitting is the one action a release pipeline can take that a human
/// cannot quietly undo — cancelling costs a review cycle — so it is always an
/// explicit call, the same judgement `colaxy_store_console` made in keeping
/// its verify tool read-only by default.
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
/// final submission = await api.prepare(
///   platform: 'IOS',
///   appStoreVersionId: version.id,
/// );
/// // Nothing has been sent yet. This is the line that submits:
/// await api.submit(submission.id);
/// ```
class ReviewSubmissionsApi {
  /// Creates a review submissions client for one app.
  const ReviewSubmissionsApi({
    required AppStoreConnectClient client,
    required this.appId,
  }) : _client = client;

  /// The numeric app ID.
  final String appId;

  final AppStoreConnectClient _client;

  /// The app's review submissions.
  Future<List<ReviewSubmission>> list() async {
    final resources = await _client
        .resources('/v1/apps/$appId/reviewSubmissions', query: {'limit': 200})
        .toList();
    return [for (final json in resources) ReviewSubmission.fromJson(json)];
  }

  /// Creates a submission and puts [appStoreVersionId] in it.
  ///
  /// **Does not submit.** Two requests happen here — the submission and the
  /// item — and neither sends anything to review. [submit] does that.
  ///
  /// The item is the step that is easy to miss: a submission created without
  /// one is valid, submittable, and submits nothing.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[platform]**: `IOS`, `MAC_OS`, `TV_OS` or `VISION_OS`.
  /// - **[appStoreVersionId]**: The version to submit.
  Future<ReviewSubmission> prepare({
    required String platform,
    required String appStoreVersionId,
  }) async {
    final created = ReviewSubmission.fromJson(
      (await _client.postJson('/v1/reviewSubmissions', {
            'data': {
              'type': 'reviewSubmissions',
              'attributes': {'platform': platform},
              'relationships': {
                'app': {
                  'data': {'type': 'apps', 'id': appId},
                },
              },
            },
          }))['data']
          as Map<String, dynamic>? ??
          const {},
    );

    await _client.postJson('/v1/reviewSubmissionItems', {
      'data': {
        'type': 'reviewSubmissionItems',
        'relationships': {
          'reviewSubmission': {
            'data': {'type': 'reviewSubmissions', 'id': created.id},
          },
          'appStoreVersion': {
            'data': {'type': 'appStoreVersions', 'id': appStoreVersionId},
          },
        },
      },
    });

    return created;
  }

  /// Sends [submissionId] to App Store review.
  ///
  /// **This is the irreversible one.** Cancelling afterwards costs a review
  /// cycle, so nothing calls it for you and there is no combined
  /// "prepare and submit" convenience — the two steps stay two lines so the
  /// second is a decision.
  Future<ReviewSubmission> submit(String submissionId) async {
    final response = await _client.patchJson(
      '/v1/reviewSubmissions/$submissionId',
      {
        'data': {
          'type': 'reviewSubmissions',
          'id': submissionId,
          'attributes': {'submitted': true},
        },
      },
    );
    return ReviewSubmission.fromJson(
      response['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  /// Cancels [submissionId].
  ///
  /// Only useful before Apple starts the review; afterwards the review is
  /// already spent.
  Future<ReviewSubmission> cancel(String submissionId) async {
    final response = await _client.patchJson(
      '/v1/reviewSubmissions/$submissionId',
      {
        'data': {
          'type': 'reviewSubmissions',
          'id': submissionId,
          'attributes': {'canceled': true},
        },
      },
    );
    return ReviewSubmission.fromJson(
      response['data'] as Map<String, dynamic>? ?? const {},
    );
  }
}
