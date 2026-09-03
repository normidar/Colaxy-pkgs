import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:googleapis/androidpublisher/v3.dart' as play;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

/// Records requests and answers them from a queue or a router.
///
/// The queue covers tests that make one or two calls in a known order; the
/// router covers the publisher tests, which make a dozen and would be
/// unreadable as a queue.
class Recorder {
  final requests = <http.Request>[];
  final _queued = <http.Response>[];
  http.Response? Function(http.Request request)? _router;

  MockClient get client => MockClient((request) async {
    requests.add(request);
    final routed = _router?.call(request);
    if (routed != null) return routed;
    if (_queued.isEmpty) return _json(const <String, dynamic>{});
    return _queued.removeAt(0);
  });

  /// Requests seen so far, as `METHOD path` strings.
  List<String> get trace => [
    for (final request in requests) '${request.method} ${request.url.path}',
  ];

  /// Answers the next request with [body].
  void enqueue(Object body, {int status = 200}) =>
      _queued.add(_json(body, status: status));

  /// Answers every request [router] returns a response for.
  void route(http.Response? Function(http.Request request) router) =>
      _router = router;

  /// A canned response, for routers that answer the same thing every time.
  static http.Response ok(Object body) => _json(body);

  /// A canned failure, for routers that answer the same thing every time.
  static http.Response error(Object body, {required int status}) =>
      _json(body, status: status);

  static http.Response _json(Object body, {int status = 200}) => http.Response(
    body is String ? body : jsonEncode(body),
    status,
    headers: const {'content-type': 'application/json'},
  );
}

/// A Google API error body, in the shape `googleapis` parses.
Map<String, dynamic> apiError(
  int code,
  String message, {
  String? reason,
}) => {
  'error': {
    'code': code,
    'message': message,
    'errors': [
      if (reason != null) {'reason': reason, 'message': message},
    ],
  },
};

/// An Android Publisher client over [recorder].
play.AndroidPublisherApi publisherApi(Recorder recorder) =>
    play.AndroidPublisherApi(recorder.client);

/// Builds a fastlane Android metadata tree under a fresh temp directory.
///
/// [locales] maps a locale directory name to the relative paths it holds and
/// their contents. Anything whose path ends in an image suffix is written as
/// a one-pixel PNG instead of as text.
Directory buildMetadataTree(
  Map<String, Map<String, String>> locales, {
  Map<String, String> root = const {},
}) {
  final temp = Directory.systemTemp.createTempSync('colaxy_publish_test');
  final android = Directory(p.join(temp.path, 'fastlane', 'metadata',
      'android'))..createSync(recursive: true);

  for (final entry in root.entries) {
    _write(File(p.join(android.path, entry.key)), entry.value);
  }
  for (final locale in locales.entries) {
    for (final file in locale.value.entries) {
      _write(File(p.join(android.path, locale.key, file.key)), file.value);
    }
  }
  return android;
}

/// One-pixel PNG, so uploads carry plausible bytes.
final Uint8List onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE'
  'hQGAhKmMIQAAAABJRU5ErkJggg==',
);

void _write(File file, String contents) {
  file.parent.createSync(recursive: true);
  const imageSuffixes = {'.png', '.jpg', '.jpeg'};
  if (imageSuffixes.contains(p.extension(file.path).toLowerCase())) {
    file.writeAsBytesSync(onePixelPng);
  } else {
    file.writeAsStringSync(contents);
  }
}
