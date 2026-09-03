import 'package:colaxy_store_publish/src/app_store/upload_operation.dart';
import 'package:meta/meta.dart';

/// A screenshot reservation on App Store Connect.
///
/// Created before any bytes move: `POST /v1/appScreenshots` with a file name
/// and size answers one of these, carrying the [uploadOperations] to send the
/// file through and a [deliveryState] of `AWAITING_UPLOAD`.
///
/// The reservation is only complete once it is committed with `uploaded:
/// true` and a checksum. **`AppScreenshot` is one of the resources that
/// requires `sourceFileChecksum`** — several newer asset types do not, so the
/// requirement cannot be inferred from the pattern.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: Apple's identifier for the reservation.
///
/// ### Optional
/// - **[fileName]**: The name given at reservation.
/// - **[fileSize]**: The size given at reservation.
/// - **[sourceFileChecksum]**: The checksum, once committed.
/// - **[assetToken]**: Apple's token for the asset.
/// - **[deliveryState]**: `AWAITING_UPLOAD`, `UPLOAD_COMPLETE`, `COMPLETE`…
/// - **[deliveryErrors]**: What Apple objected to, when it did.
/// - **[uploadOperations]**: Where to send the bytes.
@immutable
class AppScreenshot {
  /// Creates a screenshot reservation.
  const AppScreenshot({
    required this.id,
    this.fileName,
    this.fileSize,
    this.sourceFileChecksum,
    this.assetToken,
    this.deliveryState,
    this.deliveryErrors = const [],
    this.uploadOperations = const [],
  });

  /// Reads a reservation out of a JSON:API resource object.
  @internal
  factory AppScreenshot.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? const {};
    final state =
        attributes['assetDeliveryState'] as Map<String, dynamic>? ?? const {};
    return AppScreenshot(
      id: json['id'] as String? ?? '',
      fileName: attributes['fileName'] as String?,
      fileSize: (attributes['fileSize'] as num?)?.toInt(),
      sourceFileChecksum: attributes['sourceFileChecksum'] as String?,
      assetToken: attributes['assetToken'] as String?,
      deliveryState: state['state'] as String?,
      deliveryErrors: [
        for (final error in state['errors'] as List<dynamic>? ?? const [])
          if (error is Map<String, dynamic>)
            '${error['code'] ?? '?'}: ${error['description'] ?? ''}',
      ],
      uploadOperations: [
        for (final operation
            in attributes['uploadOperations'] as List<dynamic>? ?? const [])
          if (operation is Map<String, dynamic>)
            UploadOperation.fromJson(operation),
      ],
    );
  }

  /// Apple's identifier for the reservation.
  final String id;

  /// The name given at reservation.
  final String? fileName;

  /// The size given at reservation.
  final int? fileSize;

  /// The checksum, once committed.
  final String? sourceFileChecksum;

  /// Apple's token for the asset.
  final String? assetToken;

  /// Where the asset is in Apple's processing.
  final String? deliveryState;

  /// What Apple objected to, when it did.
  ///
  /// Processing is asynchronous, so a screenshot that uploaded cleanly can
  /// still fail here minutes later. An empty list is not proof of success
  /// until [isComplete].
  final List<String> deliveryErrors;

  /// Where to send the bytes.
  final List<UploadOperation> uploadOperations;

  /// Whether Apple has finished processing the asset.
  bool get isComplete => deliveryState == 'COMPLETE';

  /// Whether Apple rejected the asset.
  bool get hasFailed => deliveryErrors.isNotEmpty;

  @override
  String toString() =>
      'AppScreenshot($id, ${fileName ?? '?'}, ${deliveryState ?? '?'})';
}
