import 'package:meta/meta.dart';

/// A build App Store Connect has processed.
///
/// **Builds cannot be created through the API's `builds` resource** —
/// `/v1/builds` accepts `GET` only (verified against the 4.4.1
/// specification). A build appears as the *result* of an upload, so this type
/// is always something read, never something posted.
///
/// [version] is the build number (`CFBundleVersion`), not the marketing
/// version. Apple keeps the marketing version on the pre-release version and
/// the App Store version instead, which is why finding "the build for 1.4.0"
/// means filtering on two different fields.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: Apple's identifier for the build.
///
/// ### Optional
/// - **[version]**: The build number.
/// - **[processingState]**: Apple's processing status, kept verbatim.
/// - **[uploadedDate]**: When it was uploaded.
/// - **[expired]**: Whether it is past its TestFlight lifetime.
/// - **[usesNonExemptEncryption]**: The export compliance answer, when set.
@immutable
class AppStoreBuild {
  /// Creates a build.
  const AppStoreBuild({
    required this.id,
    this.version,
    this.processingState,
    this.uploadedDate,
    this.expired,
    this.usesNonExemptEncryption,
  });

  /// Reads a build out of a JSON:API resource object.
  @internal
  factory AppStoreBuild.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? const {};
    return AppStoreBuild(
      id: json['id'] as String? ?? '',
      version: attributes['version'] as String?,
      processingState: attributes['processingState'] as String?,
      uploadedDate: DateTime.tryParse(
        attributes['uploadedDate'] as String? ?? '',
      ),
      expired: attributes['expired'] as bool?,
      usesNonExemptEncryption: attributes['usesNonExemptEncryption'] as bool?,
    );
  }

  /// Apple's identifier for the build.
  final String id;

  /// The build number (`CFBundleVersion`).
  final String? version;

  /// Apple's processing status.
  ///
  /// Typed as a plain string in the specification rather than an enum, so it
  /// is carried through untouched instead of being guessed at.
  final String? processingState;

  /// When it was uploaded.
  final DateTime? uploadedDate;

  /// Whether it is past its TestFlight lifetime.
  final bool? expired;

  /// The export compliance answer, when it has been given.
  ///
  /// A build with this unset sits in `MISSING_EXPORT_COMPLIANCE` and reaches
  /// no tester, which is the most common reason a TestFlight distribution
  /// looks like it worked and did nothing.
  final bool? usesNonExemptEncryption;

  /// Whether Apple has finished processing the build.
  bool get isProcessed => processingState == 'VALID';

  @override
  String toString() =>
      'AppStoreBuild($id, ${version ?? '?'}, ${processingState ?? '?'})';
}
