import 'package:colaxy_icons_launcher/utils/icon.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('icons_launcher_icon_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  String writePng({required int size, int numChannels = 4}) {
    final image = img.Image(
      width: size,
      height: size,
      numChannels: numChannels,
    );
    img.fill(image, color: image.getColor(255, 0, 0, 255));
    final path = '${tempDir.path}/source.png';
    File(path).writeAsBytesSync(img.encodePng(image));
    return path;
  }

  group('Icon.loadFile', () {
    test('loads a png file', () {
      final icon = Icon.loadFile(writePng(size: 16));
      expect(icon, isNotNull);
      expect(icon!.image.width, 16);
    });

    test('returns null for a non-image file', () {
      final path = '${tempDir.path}/not_an_image.png';
      File(path).writeAsStringSync('plain text');
      expect(Icon.loadFile(path), isNull);
    });
  });

  group('Icon.copyResized', () {
    test('downscales a larger image', () {
      final icon = Icon.loadFile(writePng(size: 64))!;
      final resized = icon.copyResized(32);
      expect(resized.image.width, 32);
      expect(resized.image.height, 32);
    });

    test('upscales a smaller image', () {
      final icon = Icon.loadFile(writePng(size: 16))!;
      final resized = icon.copyResized(48);
      expect(resized.image.width, 48);
      expect(resized.image.height, 48);
    });
  });

  group('alpha handling', () {
    test('hasAlpha is true for an rgba image', () {
      final icon = Icon.loadFile(writePng(size: 8))!;
      expect(icon.hasAlpha, isTrue);
    });

    test('removeAlpha drops the alpha channel', () {
      final icon = Icon.loadFile(writePng(size: 8))!;
      icon.removeAlpha();
      expect(icon.hasAlpha, isFalse);
    });

    test('removeAlpha keeps an rgb image untouched', () {
      final icon = Icon.loadFile(writePng(size: 8, numChannels: 3))!;
      expect(icon.hasAlpha, isFalse);
      icon.removeAlpha();
      expect(icon.image.numChannels, 3);
    });
  });

  group('saving', () {
    test('saveResizedPng writes a resized png', () {
      final icon = Icon.loadFile(writePng(size: 64))!;
      final outPath = '${tempDir.path}/out/resized.png';

      icon.saveResizedPng(20, outPath);

      final written = img.decodePng(File(outPath).readAsBytesSync());
      expect(written, isNotNull);
      expect(written!.width, 20);
      expect(written.height, 20);
    });

    test('saveIco writes a windows ico file', () {
      final icon = Icon.loadFile(writePng(size: 32))!;
      final outPath = '${tempDir.path}/out/icon.ico';

      Icon.saveIco([icon], outPath);

      final bytes = File(outPath).readAsBytesSync();
      expect(bytes, isNotEmpty);
      expect(img.decodeIco(bytes), isNotNull);
    });
  });
}
