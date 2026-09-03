import 'package:meta/meta.dart';

/// A submission of an app version to App Store review.
///
/// **This is the current way to submit.** `appStoreVersionSubmissions`
/// accepts `DELETE` only (verified against the 4.4.1 specification), so
/// documentation and blog posts that tell you to POST there are describing an
/// endpoint that no longer exists for that purpose.
///
/// The flow is three requests, and the middle one is easy to forget:
///
/// 1. `POST /v1/reviewSubmissions` — create, naming the platform and app.
/// 2. `POST /v1/reviewSubmissionItems` — add the version to it. **A
///    submission with no items submits nothing.**
/// 3. `PATCH /v1/reviewSubmissions/{id}` with `submitted: true` — send it.
///
/// Creating a submission is *not* submitting. That separation is the only
/// thing on the Apple side that resembles Google Play's staged edit, and it
/// is much narrower: the items are staged, the metadata is not.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: Apple's identifier for the submission.
///
/// ### Optional
/// - **[platform]**: `IOS`, `MAC_OS`, `TV_OS` or `VISION_OS`.
/// - **[state]**: Apple's state string, kept verbatim.
/// - **[submittedDate]**: When it was sent, if it has been.
@immutable
class ReviewSubmission {
  /// Creates a review submission.
  const ReviewSubmission({
    required this.id,
    this.platform,
    this.state,
    this.submittedDate,
  });

  /// Reads a submission out of a JSON:API resource object.
  @internal
  factory ReviewSubmission.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? const {};
    return ReviewSubmission(
      id: json['id'] as String? ?? '',
      platform: attributes['platform'] as String?,
      state: attributes['state'] as String?,
      submittedDate: DateTime.tryParse(
        attributes['submittedDate'] as String? ?? '',
      ),
    );
  }

  /// Apple's identifier for the submission.
  final String id;

  /// `IOS`, `MAC_OS`, `TV_OS` or `VISION_OS`.
  final String? platform;

  /// Apple's state string.
  ///
  /// Typed as a plain string in the specification — there is no
  /// `ReviewSubmissionState` enum to model — so it is carried through
  /// untouched rather than guessed at.
  final String? state;

  /// When it was sent, if it has been.
  final DateTime? submittedDate;

  /// Whether it has been sent to review.
  bool get isSubmitted => submittedDate != null;

  @override
  String toString() =>
      'ReviewSubmission($id, ${state ?? '?'}, '
      '${isSubmitted ? 'submitted' : 'draft'})';
}
