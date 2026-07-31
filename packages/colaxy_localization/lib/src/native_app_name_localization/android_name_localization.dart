import 'dart:io' show File;

import 'package:xml/xml.dart';

/// Writes the Android `app_name` string resource for each locale, and points
/// `AndroidManifest.xml` at it.
class AndroidNameLocalization {
  /// Creates an Android name localizer rooted at [rootPath].
  const AndroidNameLocalization({this.rootPath = '.'});

  /// The app's project directory.
  final String rootPath;

  static final _androidLocaleMap = {
    'zh-CN': 'zh-rCN',
    'zh-TW': 'zh-rTW',
    'ja-JP': 'ja',
    'tr-TR': 'tr',
    'pt-PT': 'pt-rPT',
    'es-ES': 'es-rES',
    'ko-KR': 'ko',
    'vi-VN': 'vi',
    'ru-RU': 'ru',
  };

  /// `android/app/src/main/res`
  String get resFolder => '$srcFolder/res';

  /// `android/app/src/main`
  String get srcFolder => '$rootPath/android/app/src/main';

  /// Androidの名前のローカリゼーションファイルを作成する
  ///
  /// Only the `app_name` entry is touched: the file used to be overwritten
  /// wholesale, which silently dropped every other string resource in it.
  void fitLocale({required String appName, String? locale}) {
    var localeFile = File('$resFolder/values/strings.xml');
    if (locale != null) {
      final localeFolderName = _androidLocaleMap[locale];
      if (localeFolderName == null) {
        throw StateError(
          'No Android resource folder mapped for locale "$locale". '
          'Supported: ${_androidLocaleMap.keys.join(', ')}.',
        );
      }
      localeFile = File('$resFolder/values-$localeFolderName/strings.xml');
    }

    final document = localeFile.existsSync()
        ? _parseOrNull(localeFile.readAsStringSync())
        : null;

    // Build the document rather than templating a string, so an app name
    // containing `&` or `<` is escaped properly.
    final doc = document ?? XmlDocument([XmlElement(XmlName('resources'))]);

    final resources = doc.findElements('resources').firstOrNull;
    if (resources == null) {
      throw StateError('${localeFile.path} has no <resources> root element.');
    }

    final existing = resources
        .findElements('string')
        .where((e) => e.getAttribute('name') == 'app_name')
        .firstOrNull;

    if (existing != null) {
      existing.innerText = appName;
    } else {
      resources.children.add(
        XmlElement(
          XmlName('string'),
          [XmlAttribute(XmlName('name'), 'app_name')],
          [XmlText(appName)],
        ),
      );
    }

    localeFile
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '${doc.toXmlString(pretty: true, indent: '    ')}\n',
      );
  }

  /// Points `android:label` at `@string/app_name`.
  void updateManifestAppName() {
    final manifestPath = '$srcFolder/AndroidManifest.xml';
    final manifest = File(manifestPath);
    if (!manifest.existsSync()) {
      throw StateError('AndroidManifest.xml not found at: $manifestPath');
    }
    final manifestXml = XmlDocument.parse(manifest.readAsStringSync());

    // Comments used to be stripped from the whole document here, silently
    // deleting anything the app author had written in their manifest.

    final manifestNode = manifestXml.findElements('manifest').firstOrNull;
    final application = manifestNode?.findElements('application').firstOrNull;
    if (application == null) {
      throw StateError(
        '$manifestPath has no <manifest>/<application> element.',
      );
    }
    application.setAttribute('android:label', '@string/app_name');

    manifest.writeAsStringSync(
      manifestXml.toXmlString(
        pretty: true,
        indent: '    ',
        indentAttribute: (attribute) =>
            attribute.name.toString() != 'android:name',
      ),
    );
  }

  XmlDocument? _parseOrNull(String source) {
    try {
      return XmlDocument.parse(source);
    } on XmlException {
      return null;
    }
  }
}
