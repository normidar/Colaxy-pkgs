import 'package:colaxy_icons_launcher/utils/svg_converter.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

/// A minimal valid SVG: a solid red square.
const _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <rect width="64" height="64" fill="#FF0000"/>
</svg>
''';

late Directory _dir;

String _writeSvg(String name, [String content = _svg]) {
  final file = File('${_dir.path}/$name')..writeAsStringSync(content);
  return file.path;
}

void main() {
  setUp(() => _dir = Directory.systemTemp.createTempSync('svg_converter_test'));
  tearDown(() => _dir.deleteSync(recursive: true));

  test('leaves a non-SVG path untouched', () async {
    final path = '${_dir.path}/icon.png';
    expect(await resolveSvgImagePath(path), path);
    expect(svgPngBytesFor(path), isNull);
  });

  test('rasterizes an SVG to PNG bytes held in memory', () async {
    final path = _writeSvg('icon.svg');

    final resolved = await resolveSvgImagePath(path);

    // The path is returned unchanged: nothing is written next to the asset.
    expect(resolved, path);
    expect(File('${_dir.path}/icon.png').existsSync(), isFalse);

    final bytes = svgPngBytesFor(path);
    expect(bytes, isNotNull);
    // PNG magic number.
    expect(bytes!.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
  });

  test('matches the extension case-insensitively', () async {
    final path = _writeSvg('icon.SVG');
    await resolveSvgImagePath(path);
    expect(svgPngBytesFor(path), isNotNull);
  });

  test('converts a file referenced twice only once', () async {
    final path = _writeSvg('shared.svg');

    await resolveSvgImagePath(path);
    final first = svgPngBytesFor(path);
    await resolveSvgImagePath(path);

    // Same instance, not just equal bytes: the second call hit the cache.
    expect(identical(svgPngBytesFor(path), first), isTrue);
  });

  test('rasterizes at 1024x1024 regardless of the SVG viewBox', () async {
    // Large enough to stay sharp when downscaled to a 1024px store icon.
    final small = _writeSvg(
      'small.svg',
      '<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8" '
          'viewBox="0 0 8 8"><rect width="8" height="8" fill="#00FF00"/></svg>',
    );
    await resolveSvgImagePath(small);

    final bytes = svgPngBytesFor(small)!;
    // Width and height live at bytes 16-24 of a PNG's IHDR chunk, big-endian.
    int uint32(int offset) =>
        (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    expect(uint32(16), 1024);
    expect(uint32(20), 1024);
  });
}
