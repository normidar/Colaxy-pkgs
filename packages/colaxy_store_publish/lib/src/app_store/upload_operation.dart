import 'package:meta/meta.dart';

/// One chunk of an asset upload, as App Store Connect describes it.
///
/// Apple's API never takes a file body itself — **every request body in the
/// 4.4.1 specification is JSON**. Reserving an asset instead returns a list of
/// these, each naming a URL, a byte range of the local file, and the headers
/// to send. The bytes go to a different host entirely, without the API's
/// bearer token.
///
/// This is the deepest difference from Google Play, where the API receives
/// the file directly.
///
/// ## Parameters
///
/// ### Required
/// - **[method]**: HTTP method, `PUT` in every observed case.
/// - **[url]**: Where to send this chunk.
/// - **[offset]**: First byte of the local file this chunk carries.
/// - **[length]**: How many bytes.
///
/// ### Optional
/// - **[requestHeaders]**: Headers Apple requires on the chunk (default:
///   empty).
@immutable
class UploadOperation {
  /// Creates an upload operation.
  const UploadOperation({
    required this.method,
    required this.url,
    required this.offset,
    required this.length,
    this.requestHeaders = const {},
  });

  /// Reads an operation out of Apple's `uploadOperations` array.
  @internal
  factory UploadOperation.fromJson(Map<String, dynamic> json) {
    final headers = <String, String>{};
    for (final header in json['requestHeaders'] as List<dynamic>? ?? const []) {
      if (header is! Map<String, dynamic>) continue;
      final name = header['name'];
      final value = header['value'];
      if (name is String && value is String) headers[name] = value;
    }
    return UploadOperation(
      method: json['method'] as String? ?? 'PUT',
      url: json['url'] as String? ?? '',
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      length: (json['length'] as num?)?.toInt() ?? 0,
      requestHeaders: headers,
    );
  }

  /// HTTP method.
  final String method;

  /// Where to send this chunk.
  final String url;

  /// First byte of the local file this chunk carries.
  final int offset;

  /// How many bytes.
  final int length;

  /// Headers Apple requires on the chunk.
  final Map<String, String> requestHeaders;

  @override
  String toString() => 'UploadOperation($method $offset+$length)';
}
