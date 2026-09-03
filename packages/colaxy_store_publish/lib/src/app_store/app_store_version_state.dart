/// Where a version sits in the App Store's review and release cycle.
///
/// All 20 values from the specification. **Only [prepareForSubmission] is a
/// safe window to write metadata in** — the API rejects edits to a version in
/// review with a `409`, and which fields lock at which state is not fully
/// documented.
///
/// ## Example
///
/// ```dart
/// if (version.appStoreState?.isEditable ?? false) {
///   await api.update(localization);
/// }
/// ```
enum AppStoreVersionState {
  /// Review passed; awaiting release.
  accepted('ACCEPTED'),

  /// The developer removed it from sale.
  developerRemovedFromSale('DEVELOPER_REMOVED_FROM_SALE'),

  /// The developer rejected it after review.
  developerRejected('DEVELOPER_REJECTED'),

  /// Apple is reviewing it.
  inReview('IN_REVIEW'),

  /// The uploaded binary was rejected as invalid.
  invalidBinary('INVALID_BINARY'),

  /// Review rejected the metadata rather than the binary.
  metadataRejected('METADATA_REJECTED'),

  /// Waiting for Apple to release it.
  pendingAppleRelease('PENDING_APPLE_RELEASE'),

  /// Blocked on a contract.
  pendingContract('PENDING_CONTRACT'),

  /// Waiting for the developer to release it.
  pendingDeveloperRelease('PENDING_DEVELOPER_RELEASE'),

  /// Editable. The only state this package will write metadata into.
  prepareForSubmission('PREPARE_FOR_SUBMISSION'),

  /// A pre-order that is ready for sale.
  preorderReadyForSale('PREORDER_READY_FOR_SALE'),

  /// Apple is processing it for the store.
  processingForAppStore('PROCESSING_FOR_APP_STORE'),

  /// Ready to be submitted for review.
  readyForReview('READY_FOR_REVIEW'),

  /// Live on the App Store.
  readyForSale('READY_FOR_SALE'),

  /// Review rejected it.
  rejected('REJECTED'),

  /// No longer for sale.
  removedFromSale('REMOVED_FROM_SALE'),

  /// Waiting on an export compliance answer.
  waitingForExportCompliance('WAITING_FOR_EXPORT_COMPLIANCE'),

  /// Queued for review.
  waitingForReview('WAITING_FOR_REVIEW'),

  /// Superseded by a newer version.
  replacedWithNewVersion('REPLACED_WITH_NEW_VERSION'),

  /// Not applicable.
  notApplicable('NOT_APPLICABLE');

  /// Creates a state with the wire name App Store Connect uses for it.
  const AppStoreVersionState(this.wireName);

  /// The value App Store Connect sends and accepts in filters.
  final String wireName;

  /// The state [wireName] names, or `null` for one this package does not know.
  ///
  /// Answers `null` rather than throwing: Apple adds states, and a run that
  /// dies on an unrecognised one is worse than a run that reports the version
  /// is not editable.
  static AppStoreVersionState? byWireName(String wireName) {
    for (final state in values) {
      if (state.wireName == wireName) return state;
    }
    return null;
  }

  /// Whether metadata can be written to a version in this state.
  ///
  /// Deliberately narrow. Some fields — `promotionalText`, `whatsNew` — are
  /// reported to be editable in other states too, but the rules are neither
  /// documented nor uniform across locales, and the failure is a `409` naming
  /// only the attribute. Treating one state as the write window makes the
  /// failure predictable.
  bool get isEditable => this == AppStoreVersionState.prepareForSubmission;
}

/// The newer state enum App Store Connect reports alongside
/// [AppStoreVersionState].
///
/// **These are two different enums on the same resource**, not an alias: this
/// one has 15 values, carries `PROCESSING_FOR_DISTRIBUTION` and
/// `READY_FOR_DISTRIBUTION` which the other lacks, and lacks several the
/// other has. `AppStoreVersion` exposes both because the specification does,
/// and which one to branch on is not yet verified against a real account.
enum AppVersionState {
  /// Review passed; awaiting release.
  accepted('ACCEPTED'),

  /// The developer rejected it after review.
  developerRejected('DEVELOPER_REJECTED'),

  /// Apple is reviewing it.
  inReview('IN_REVIEW'),

  /// The uploaded binary was rejected as invalid.
  invalidBinary('INVALID_BINARY'),

  /// Review rejected the metadata rather than the binary.
  metadataRejected('METADATA_REJECTED'),

  /// Waiting for Apple to release it.
  pendingAppleRelease('PENDING_APPLE_RELEASE'),

  /// Waiting for the developer to release it.
  pendingDeveloperRelease('PENDING_DEVELOPER_RELEASE'),

  /// Editable.
  prepareForSubmission('PREPARE_FOR_SUBMISSION'),

  /// Being processed for distribution.
  processingForDistribution('PROCESSING_FOR_DISTRIBUTION'),

  /// Ready to distribute.
  readyForDistribution('READY_FOR_DISTRIBUTION'),

  /// Ready to be submitted for review.
  readyForReview('READY_FOR_REVIEW'),

  /// Review rejected it.
  rejected('REJECTED'),

  /// Superseded by a newer version.
  replacedWithNewVersion('REPLACED_WITH_NEW_VERSION'),

  /// Waiting on an export compliance answer.
  waitingForExportCompliance('WAITING_FOR_EXPORT_COMPLIANCE'),

  /// Queued for review.
  waitingForReview('WAITING_FOR_REVIEW');

  /// Creates a state with the wire name App Store Connect uses for it.
  const AppVersionState(this.wireName);

  /// The value App Store Connect sends and accepts in filters.
  final String wireName;

  /// The state [wireName] names, or `null` for one this package does not know.
  static AppVersionState? byWireName(String wireName) {
    for (final state in values) {
      if (state.wireName == wireName) return state;
    }
    return null;
  }
}
