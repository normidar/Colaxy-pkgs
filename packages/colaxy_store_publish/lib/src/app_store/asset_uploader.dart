import 'dart:io';
import 'dart:typed_data';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/src/app_store/checksum_algorithm.dart';
import 'package:colaxy_store_publish/src/app_store/upload_operation.dart';
import 'package:colaxy_store_publish/src/core/store_publish_exception.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

/// Sends file bytes to the URLs an App Store Connect reservation hands back.
///
/// Apple's API takes no file bodies. A reservation answers a list of
/// [UploadOperation]s pointing at another host, each carrying its own headers
/// and a byte range, and the bytes go there **without the API's bearer
/// token** — those URLs authenticate themselves.
///
/// The whole file is read into memory once and sliced. Screenshots are a few
/// megabytes, and re-reading a range per chunk would cost more than it saves;
/// this is not the class to send a multi-gigabyte binary through.
///
/// ## Parameters
///
/// ### Optional
/// - **`httpClient`**: Transport (default: a client this object owns and
///   closes).
/// - **[retryPolicy]**: When to retry a chunk (default: `RetryPolicy()`).
/// - **[onLog]**: Receives one line per chunk and retry (default: `null`).
///
/// ## Example
///
/// ```dart
/// final checksum = await uploader.upload(file, reservation.uploadOperations);
/// ```
class AssetUploader {
  /// Creates an uploader.
  AssetUploader({
    http.Client? httpClient,
    this.retryPolicy = const RetryPolicy(),
    this.onLog,
    @visibleForTesting Future<void> Function(Duration)? sleep,
  }) : _http = httpClient ?? http.Client(),
       _ownsHttp = httpClient == null,
       _sleep = sleep ?? _wait;

  /// When to retry a chunk.
  final RetryPolicy retryPolicy;

  /// Receives one line per chunk and retry.
  final StoreConsoleLog? onLog;

  final http.Client _http;
  final bool _ownsHttp;
  final Future<void> Function(Duration) _sleep;

  static Future<void> _wait(Duration duration) =>
      Future<void>.delayed(duration);

  /// Sends [file] through [operations] and answers its checksum.
  ///
  /// The checksum is what the commit step needs, and computing it here means
  /// the file is read exactly once for both purposes.
  ///
  /// Chunks are sent **in sequence, not in parallel**. Apple is reported to
  /// throttle concurrent uploads, and a rejected chunk partway through a
  /// parallel batch leaves an asset in a state this package would have to
  /// reason about. Sequential is slower and knowable.
  ///
  /// The file is held in memory while it is sliced. Screenshots are small;
  /// an `.ipa` is not, and a build upload will hold the whole archive. The
  /// checksum needs every byte anyway, so streaming would only move the cost
  /// rather than remove it — but this is worth knowing before pointing it at
  /// something very large.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[file]**: The file the reservation was made for.
  /// - **[operations]**: What the reservation answered.
  ///
  /// ### Optional
  /// - **[algorithm]**: How to compute the checksum (default:
  ///   [ChecksumAlgorithm.md5], which is what screenshot commits require).
  Future<String> upload(
    File file,
    List<UploadOperation> operations, {
    ChecksumAlgorithm algorithm = ChecksumAlgorithm.md5,
  }) async {
    if (operations.isEmpty) {
      throw FastlaneLayoutException(
        'App Store Connect reserved the asset but described no way to upload '
        'it. Nothing was sent.',
        path: file.path,
      );
    }

    final bytes = await file.readAsBytes();
    for (final operation in operations) {
      await _send(operation, bytes, file.path);
    }
    return _digest(bytes, algorithm);
  }

  /// Computes the checksum of [file] without uploading it.
  ///
  /// For comparing a local file against an asset already on the store.
  static Future<String> checksum(
    File file, {
    ChecksumAlgorithm algorithm = ChecksumAlgorithm.md5,
  }) async => _digest(await file.readAsBytes(), algorithm);

  static String _digest(Uint8List bytes, ChecksumAlgorithm algorithm) =>
      switch (algorithm) {
        ChecksumAlgorithm.md5 => md5.convert(bytes).toString(),
        ChecksumAlgorithm.sha256 => sha256.convert(bytes).toString(),
      };

  /// Closes the HTTP client, if this object owns it.
  void close() {
    if (_ownsHttp) _http.close();
  }

  Future<void> _send(
    UploadOperation operation,
    Uint8List bytes,
    String path,
  ) async {
    final end = operation.offset + operation.length;
    if (end > bytes.length) {
      throw FastlaneLayoutException(
        'App Store Connect asked for bytes $end of a file that is only '
        '${bytes.length} long. The reservation and the file disagree — the '
        'file changed after it was reserved.',
        path: path,
      );
    }
    final chunk = Uint8List.sublistView(bytes, operation.offset, end);
    final uri = Uri.parse(operation.url);

    var attempt = 0;
    while (true) {
      attempt++;
      final response = await _http.send(
        http.Request(operation.method, uri)
          ..headers.addAll(operation.requestHeaders)
          ..bodyBytes = chunk,
      );
      await response.stream.drain<void>();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        onLog?.call(
          'uploaded ${operation.length} bytes at ${operation.offset}',
        );
        return;
      }
      if (!retryPolicy.shouldRetry(
            attempt: attempt,
            statusCode: response.statusCode,
          ) ||
          attempt >= retryPolicy.maxAttempts) {
        throw StoreApiException(
          'Uploading bytes ${operation.offset}+${operation.length} failed.',
          statusCode: response.statusCode,
          store: Store.appStore,
          detail:
              "The chunk goes to Apple's asset host, not the API, so this "
              "status is that host's. A 403 usually means the reservation "
              'expired.',
        );
      }
      final wait = retryPolicy.backoffFor(attempt);
      onLog?.call(
        '${response.statusCode} uploading chunk at ${operation.offset}; '
        'retrying in ${wait.inMilliseconds}ms '
        '(attempt $attempt of ${retryPolicy.maxAttempts})',
      );
      await _sleep(wait);
    }
  }
}
