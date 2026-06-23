import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pure_svg/svg.dart';
import 'package:universal_io/io.dart';

/// Size (in pixels) used to rasterize SVG sources before they're fed into
/// the regular PNG-based icon pipeline. High enough to stay sharp once
/// downscaled to the largest icon variant any platform requests (1024 for
/// iOS/macOS App Store icons).
const int _svgRasterSize = 1024;

/// In-memory cache of already-rasterized SVG sources, keyed by the original
/// SVG file path, so the same file referenced by multiple platforms (e.g. a
/// shared `image_path`) is only converted once and never touches disk.
final Map<String, Uint8List> _svgPngCache = {};

/// Returns the rasterized PNG bytes previously produced for [imagePath] by
/// [resolveSvgImagePath], or `null` if [imagePath] isn't a resolved SVG.
Uint8List? svgPngBytesFor(String imagePath) => _svgPngCache[imagePath];

/// If [imagePath] points to an SVG file, rasterizes it to PNG bytes kept in
/// memory and returns [imagePath] unchanged (use [svgPngBytesFor] to fetch
/// the bytes). Otherwise returns [imagePath] unchanged.
Future<String> resolveSvgImagePath(String imagePath) async {
  if (p.extension(imagePath).toLowerCase() != '.svg') {
    return imagePath;
  }

  if (_svgPngCache.containsKey(imagePath)) {
    return imagePath;
  }

  final svgString = File(imagePath).readAsStringSync();
  _svgPngCache[imagePath] = await svg.toPng(
    SvgStringLoader(svgString),
    width: _svgRasterSize,
    height: _svgRasterSize,
  );
  return imagePath;
}
