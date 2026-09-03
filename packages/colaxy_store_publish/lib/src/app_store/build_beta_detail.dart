import 'package:meta/meta.dart';

/// Where a build stands with internal TestFlight testers.
enum InternalBetaState {
  /// Apple is still processing it.
  processing('PROCESSING'),

  /// Processing failed.
  processingException('PROCESSING_EXCEPTION'),

  /// Blocked on the export compliance answer.
  ///
  /// The most common reason a distribution looks like it worked and reached
  /// nobody. Set `usesNonExemptEncryption` on the build to clear it.
  missingExportCompliance('MISSING_EXPORT_COMPLIANCE'),

  /// Ready for testers.
  readyForBetaTesting('READY_FOR_BETA_TESTING'),

  /// Testers have it.
  inBetaTesting('IN_BETA_TESTING'),

  /// Past its TestFlight lifetime.
  expired('EXPIRED'),

  /// Apple is reviewing the export compliance answer.
  inExportComplianceReview('IN_EXPORT_COMPLIANCE_REVIEW');

  /// Creates a state with the wire name App Store Connect uses for it.
  const InternalBetaState(this.wireName);

  /// The value App Store Connect sends.
  final String wireName;

  /// The state [wireName] names, or `null` for one this package does not know.
  static InternalBetaState? byWireName(String wireName) {
    for (final state in values) {
      if (state.wireName == wireName) return state;
    }
    return null;
  }
}

/// Where a build stands with external TestFlight testers.
///
/// Six values longer than [InternalBetaState], and the extra ones are the
/// beta review cycle: external testers cannot receive a build until Apple has
/// reviewed it.
enum ExternalBetaState {
  /// Apple is still processing it.
  processing('PROCESSING'),

  /// Processing failed.
  processingException('PROCESSING_EXCEPTION'),

  /// Blocked on the export compliance answer.
  missingExportCompliance('MISSING_EXPORT_COMPLIANCE'),

  /// Ready for testers.
  readyForBetaTesting('READY_FOR_BETA_TESTING'),

  /// Testers have it.
  inBetaTesting('IN_BETA_TESTING'),

  /// Past its TestFlight lifetime.
  expired('EXPIRED'),

  /// Waiting to be submitted for beta review.
  ///
  /// This is where a build sits when it has been assigned to an external
  /// group and nothing submitted it. App Store Connect shows "Ready to
  /// Submit", and no tester sees it.
  readyForBetaSubmission('READY_FOR_BETA_SUBMISSION'),

  /// Apple is reviewing the export compliance answer.
  inExportComplianceReview('IN_EXPORT_COMPLIANCE_REVIEW'),

  /// Queued for beta review.
  waitingForBetaReview('WAITING_FOR_BETA_REVIEW'),

  /// Apple is reviewing it.
  inBetaReview('IN_BETA_REVIEW'),

  /// Beta review rejected it.
  betaRejected('BETA_REJECTED'),

  /// Beta review passed.
  betaApproved('BETA_APPROVED'),

  /// Not applicable.
  notApplicable('NOT_APPLICABLE');

  /// Creates a state with the wire name App Store Connect uses for it.
  const ExternalBetaState(this.wireName);

  /// The value App Store Connect sends.
  final String wireName;

  /// The state [wireName] names, or `null` for one this package does not know.
  static ExternalBetaState? byWireName(String wireName) {
    for (final state in values) {
      if (state.wireName == wireName) return state;
    }
    return null;
  }

  /// Whether the build is waiting to be submitted for beta review.
  bool get awaitsBetaSubmission =>
      this == ExternalBetaState.readyForBetaSubmission;
}

/// A build's TestFlight status, for internal and external testers separately.
///
/// Worth reading after any distribution: the two states diverge, and the
/// external one is where "assigned but reaching nobody" shows up as
/// [ExternalBetaState.readyForBetaSubmission].
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: Apple's identifier for the detail record.
///
/// ### Optional
/// - **[internalBuildState]**: Status with internal testers.
/// - **[externalBuildState]**: Status with external testers.
/// - **[autoNotifyEnabled]**: Whether testers are told automatically.
@immutable
class BuildBetaDetail {
  /// Creates a build beta detail.
  const BuildBetaDetail({
    required this.id,
    this.internalBuildState,
    this.externalBuildState,
    this.autoNotifyEnabled,
  });

  /// Reads a detail record out of a JSON:API resource object.
  @internal
  factory BuildBetaDetail.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? const {};
    return BuildBetaDetail(
      id: json['id'] as String? ?? '',
      internalBuildState: InternalBetaState.byWireName(
        attributes['internalBuildState'] as String? ?? '',
      ),
      externalBuildState: ExternalBetaState.byWireName(
        attributes['externalBuildState'] as String? ?? '',
      ),
      autoNotifyEnabled: attributes['autoNotifyEnabled'] as bool?,
    );
  }

  /// Apple's identifier for the detail record.
  final String id;

  /// Status with internal testers.
  final InternalBetaState? internalBuildState;

  /// Status with external testers.
  final ExternalBetaState? externalBuildState;

  /// Whether testers are told automatically.
  final bool? autoNotifyEnabled;

  /// Whether the build is stuck waiting for a beta review submission.
  bool get awaitsBetaSubmission =>
      externalBuildState?.awaitsBetaSubmission ?? false;

  /// Whether either state is blocked on the export compliance answer.
  bool get missingExportCompliance =>
      internalBuildState == InternalBetaState.missingExportCompliance ||
      externalBuildState == ExternalBetaState.missingExportCompliance;

  @override
  String toString() =>
      'BuildBetaDetail($id, internal: '
      '${internalBuildState?.wireName ?? '?'}, external: '
      '${externalBuildState?.wireName ?? '?'})';
}
