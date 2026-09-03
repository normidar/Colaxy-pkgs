import 'package:colaxy_store_publish/src/app_store/upload_operation.dart';
import 'package:meta/meta.dart';

/// Which of a build upload's three slots a file fills.
///
/// The three values line up exactly with the three relationships a
/// `BuildUpload` carries — `assetFile`, `assetDescriptionFile` and
/// `assetSpiFile` — so a build upload is not one file but up to three.
///
/// For a plain `.ipa` or `.pkg`, [asset] is the one that matters. The other
/// two hold the property lists Transporter used to package alongside a
/// binary; whether App Store Connect requires them for an API upload is
/// **not verified against a real account**.
enum BuildUploadAssetType {
  /// The binary itself.
  asset('ASSET'),

  /// The accompanying description property list.
  assetDescription('ASSET_DESCRIPTION'),

  /// The accompanying SPI property list.
  assetSpi('ASSET_SPI');

  /// Creates an asset type with the wire name App Store Connect uses.
  const BuildUploadAssetType(this.wireName);

  /// The value App Store Connect expects in `assetType`.
  final String wireName;
}

/// The uniform type identifier of a build upload file.
///
/// All five values from the specification. Apple types this as an enum, not
/// a free string, so an unlisted file kind cannot be uploaded at all.
enum BuildUploadUti {
  /// An iOS, tvOS or visionOS app archive.
  ipa('com.apple.ipa'),

  /// A macOS installer package.
  pkg('com.apple.pkg'),

  /// A binary property list.
  binaryPropertyList('com.apple.binary-property-list'),

  /// An XML property list.
  xmlPropertyList('com.apple.xml-property-list'),

  /// A zip archive.
  zipArchive('com.pkware.zip-archive');

  /// Creates a type identifier with the wire name App Store Connect uses.
  const BuildUploadUti(this.wireName);

  /// The value App Store Connect expects in `uti`.
  final String wireName;

  /// The identifier for a file with this [extension], or `null`.
  ///
  /// Answers `null` rather than guessing: uploading an archive under the
  /// wrong type identifier fails somewhere that does not name the file.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[extension]**: The file suffix, with its dot, e.g. `.ipa`.
  static BuildUploadUti? byExtension(String extension) =>
      switch (extension.toLowerCase()) {
        '.ipa' => BuildUploadUti.ipa,
        '.pkg' => BuildUploadUti.pkg,
        '.zip' => BuildUploadUti.zipArchive,
        '.plist' => BuildUploadUti.xmlPropertyList,
        _ => null,
      };
}

/// One file inside a build upload, and where to send its bytes.
///
/// The same reservation shape as a screenshot — [uploadOperations] point at
/// another host — with one difference that matters: the commit takes a
/// `Checksums` **object naming an algorithm**, where a screenshot takes a
/// bare `sourceFileChecksum` string.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: Apple's identifier for the file.
///
/// ### Optional
/// - **[fileName]**, **[fileSize]**: What was reserved.
/// - **[assetType]**: Which slot it fills.
/// - **[uti]**: Its type identifier, kept verbatim.
/// - **[deliveryState]**: Where Apple is with it.
/// - **[uploadOperations]**: Where to send the bytes.
@immutable
class BuildUploadFile {
  /// Creates a build upload file.
  const BuildUploadFile({
    required this.id,
    this.fileName,
    this.fileSize,
    this.assetType,
    this.uti,
    this.deliveryState,
    this.uploadOperations = const [],
  });

  /// Reads a file out of a JSON:API resource object.
  @internal
  factory BuildUploadFile.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? const {};
    final state =
        attributes['assetDeliveryState'] as Map<String, dynamic>? ?? const {};
    return BuildUploadFile(
      id: json['id'] as String? ?? '',
      fileName: attributes['fileName'] as String?,
      fileSize: (attributes['fileSize'] as num?)?.toInt(),
      assetType: attributes['assetType'] as String?,
      uti: attributes['uti'] as String?,
      deliveryState: state['state'] as String?,
      uploadOperations: [
        for (final operation
            in attributes['uploadOperations'] as List<dynamic>? ?? const [])
          if (operation is Map<String, dynamic>)
            UploadOperation.fromJson(operation),
      ],
    );
  }

  /// Apple's identifier for the file.
  final String id;

  /// The name given at reservation.
  final String? fileName;

  /// The size given at reservation.
  final int? fileSize;

  /// Which slot it fills, as Apple reports it.
  final String? assetType;

  /// Its type identifier, as Apple reports it.
  final String? uti;

  /// Where Apple is with it.
  final String? deliveryState;

  /// Where to send the bytes.
  final List<UploadOperation> uploadOperations;

  @override
  String toString() =>
      'BuildUploadFile($id, ${fileName ?? '?'}, ${deliveryState ?? '?'})';
}
