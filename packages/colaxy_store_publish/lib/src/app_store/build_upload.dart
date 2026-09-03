import 'package:meta/meta.dart';

/// How far App Store Connect has got with a build upload.
enum BuildUploadState {
  /// Reserved; the bytes have not arrived.
  awaitingUpload('AWAITING_UPLOAD'),

  /// Apple is processing what it received.
  processing('PROCESSING'),

  /// Apple rejected it. Read `BuildUpload.errors` for why.
  failed('FAILED'),

  /// Done. The build now exists and can be distributed.
  complete('COMPLETE');

  /// Creates a state with the wire name App Store Connect uses.
  const BuildUploadState(this.wireName);

  /// The value App Store Connect sends.
  final String wireName;

  /// The state [wireName] names, or `null` for one this package does not know.
  static BuildUploadState? byWireName(String wireName) {
    for (final state in values) {
      if (state.wireName == wireName) return state;
    }
    return null;
  }

  /// Whether the upload has stopped, either way.
  bool get isFinished =>
      this == BuildUploadState.complete || this == BuildUploadState.failed;
}

/// An upload of an app binary to App Store Connect.
///
/// **This is what removed the last reason to run Transporter or `altool`.**
/// Until App Store Connect API 4.1 there was no way to deliver a binary over
/// the API at all, and this repository's plans were written around that
/// limit. `buildUploads` replaced it.
///
/// A build upload is not a build. It is the *delivery* — the build appears
/// as a result once [state] reaches [BuildUploadState.complete], which is why
/// `/v1/builds` accepts no `POST`.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: Apple's identifier for the upload.
///
/// ### Optional
/// - **[cfBundleVersion]**: The build number the upload declared.
/// - **[cfBundleShortVersionString]**: The marketing version it declared.
/// - **[platform]**: `IOS`, `MAC_OS`, `TV_OS` or `VISION_OS`.
/// - **[state]**: How far Apple has got.
/// - **[errors]**, **[warnings]**: What Apple said about it.
/// - **[createdDate]**, **[uploadedDate]**: When it began and finished.
@immutable
class BuildUpload {
  /// Creates a build upload.
  const BuildUpload({
    required this.id,
    this.cfBundleVersion,
    this.cfBundleShortVersionString,
    this.platform,
    this.state,
    this.errors = const [],
    this.warnings = const [],
    this.createdDate,
    this.uploadedDate,
  });

  /// Reads an upload out of a JSON:API resource object.
  @internal
  factory BuildUpload.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? const {};
    final state = attributes['state'] as Map<String, dynamic>? ?? const {};
    List<String> details(String key) => [
      for (final detail in state[key] as List<dynamic>? ?? const [])
        if (detail is Map<String, dynamic>)
          '${detail['code'] ?? '?'}: ${detail['description'] ?? ''}',
    ];
    return BuildUpload(
      id: json['id'] as String? ?? '',
      cfBundleVersion: attributes['cfBundleVersion'] as String?,
      cfBundleShortVersionString:
          attributes['cfBundleShortVersionString'] as String?,
      platform: attributes['platform'] as String?,
      state: BuildUploadState.byWireName(state['state'] as String? ?? ''),
      errors: details('errors'),
      warnings: details('warnings'),
      createdDate: DateTime.tryParse(
        attributes['createdDate'] as String? ?? '',
      ),
      uploadedDate: DateTime.tryParse(
        attributes['uploadedDate'] as String? ?? '',
      ),
    );
  }

  /// Apple's identifier for the upload.
  final String id;

  /// The build number the upload declared.
  ///
  /// Declared up front, unlike Google Play, which reads the version code out
  /// of the bundle itself. Getting it wrong here is not caught by the file.
  final String? cfBundleVersion;

  /// The marketing version it declared.
  final String? cfBundleShortVersionString;

  /// `IOS`, `MAC_OS`, `TV_OS` or `VISION_OS`.
  final String? platform;

  /// How far Apple has got.
  final BuildUploadState? state;

  /// What Apple objected to.
  final List<String> errors;

  /// What Apple warned about but accepted.
  final List<String> warnings;

  /// When the upload was created.
  final DateTime? createdDate;

  /// When the bytes finished arriving.
  final DateTime? uploadedDate;

  /// Whether the upload finished successfully.
  bool get isComplete => state == BuildUploadState.complete;

  /// Whether Apple rejected it.
  bool get hasFailed => state == BuildUploadState.failed;

  @override
  String toString() =>
      'BuildUpload($id, ${cfBundleVersion ?? '?'}, '
      '${state?.wireName ?? '?'})';
}
