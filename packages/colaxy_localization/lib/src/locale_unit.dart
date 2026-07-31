import 'dart:convert';
import 'dart:io';

import 'package:characters/characters.dart';
import 'package:colaxy_localization/colaxy_localization.dart';
import 'package:colaxy_localization/src/cli_logger.dart';

/// 一個のローカリゼーションのユニット、これは一つのアプリの中にある一つの翻訳を示します。
class LocaleUnit {
  LocaleUnit({
    required this.locale,
    this.rootPath = '.',
  });

  /// The app's project directory that all paths are resolved against.
  final String rootPath;

  /// https://developer.apple.com/documentation/appstoreconnectapi/managing-metadata-in-your-app-by-using-locale-shortcodes
  static final iosLocaleMap = {
    'zh-CN': 'zh-Hans',
    'zh-TW': 'zh-Hant',
    'ja-JP': 'ja',
    'en-US': 'en-US',
    'tr-TR': 'tr',
    'pt-PT': 'pt-PT',
    'es-ES': 'es-ES',
    'ko-KR': 'ko',
    'vi-VN': 'vi',
    'ru-RU': 'ru',
  };

  static const _blockedKeywords = ['google', 'apple', 'android', 'ios'];

  // Store limits count user-perceived characters. `String.length` counts UTF-16
  // code units, so an emoji or a combining sequence inflated the count and a
  // valid string was rejected (or an over-long one slipped through).

  bool isMainLocale = false;

  final String locale;

  late final Map<String, String> _json =
      (jsonDecode(_getJsonFile().readAsStringSync()) as Map<String, dynamic>)
          .cast<String, String>();

  String get metadataDir => '$rootPath/fastlane/metadata';

  /// App Store Connect directory name for this locale.
  ///
  /// Reading [iosLocaleMap] with `!` turned an unmapped locale into a bare
  /// null-check crash that named neither the locale nor the map.
  String get iosLocale {
    final mapped = iosLocaleMap[locale];
    if (mapped == null) {
      throw StateError(
        'No App Store locale mapped for "$locale". '
        'Supported: ${iosLocaleMap.keys.join(', ')}.',
      );
    }
    return mapped;
  }

  /// Reads a required key from this locale's JSON file.
  ///
  /// Every getter used to do `_require('key')`, so a missing key surfaced as an
  /// unattributed "Null check operator used on a null value".
  String _require(String key) {
    final value = _json[key];
    if (value == null) {
      throw StateError(
        'Key "$key" is missing from ${_getJsonFile().path}.',
      );
    }
    return value;
  }

  void fitAllToFastlane() {
    _fitAppNameToFastlane();
    _fitDescriptionToFastlane();
    _fitIosSubtitleToFastlane();
    _fitAndroidShortDescriptionToFastlane();
    _fitStoreReleaseNoteToFastlane();
    _fitStoreKeywordsToFastlane();
    _fitStorePromotionalTextToFastlane();
    _fitIosSupportUrlToFastlane();
    _fitIosPrivacyUrlToFastlane();
    _fitAppNameAndroid();
    _fitAppNameIos();
  }

  void _fitAndroidShortDescriptionToFastlane() {
    final shortDescription = _getAndroidShortDescription();
    File('$metadataDir/android/$locale/short_description.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync(shortDescription);
  }

  void _fitAppNameAndroid() {
    final appName = _getAppName();
    final androidNameLocalization = AndroidNameLocalization(rootPath: rootPath);
    if (isMainLocale) {
      androidNameLocalization.fitLocale(appName: appName);
    } else {
      androidNameLocalization.fitLocale(appName: appName, locale: locale);
    }
  }

  void _fitAppNameIos() {
    final appName = _getAppName();
    final iosNameLocalization = IOSNameLocalization(rootPath: rootPath);
    if (isMainLocale) {
      iosNameLocalization.fitLocale(appName: appName);
    } else {
      iosNameLocalization.fitLocale(appName: appName, locale: locale);
    }
  }

  void _fitAppNameToFastlane() {
    final appName = _getAppStoreName();

    final fastlaneAndroidAppNameFile = File(
      '$metadataDir/android/$locale/title.txt',
    );
    final fastlaneIosAppNameFile = File('$metadataDir/$iosLocale/name.txt');

    fastlaneAndroidAppNameFile
      ..createSync(recursive: true)
      ..writeAsStringSync(appName);
    fastlaneIosAppNameFile
      ..createSync(recursive: true)
      ..writeAsStringSync(appName);
  }

  void _fitDescriptionToFastlane() {
    final description = _getDescription();
    var androidDescription = description;
    var iosDescription = description;
    final fastlaneAndroidDescriptionFile = File(
      '$metadataDir/android/$locale/full_description.txt',
    );
    final fastlaneIosDescriptionFile = File(
      '$metadataDir/$iosLocale/description.txt',
    );

    final minimumVersion = LocaleApp(rootPath: rootPath).getMinimumVersion();
    CliLogger.info('minimumVersion: $minimumVersion');

    if (minimumVersion != null) {
      androidDescription =
          '$androidDescription\n\n'
          '[Minimum supported app version: $minimumVersion]';
      iosDescription = '$iosDescription\n\n[:mav: $minimumVersion]';
    }

    fastlaneAndroidDescriptionFile
      ..createSync(recursive: true)
      ..writeAsStringSync(androidDescription);
    fastlaneIosDescriptionFile
      ..createSync(recursive: true)
      ..writeAsStringSync(iosDescription);
  }

  void _fitIosPrivacyUrlToFastlane() {
    final privacyUrl = _getIosPrivacyUrl();
    File('$metadataDir/$iosLocale/privacy_url.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync(privacyUrl);
  }

  void _fitIosSubtitleToFastlane() {
    final subtitle = _getIosSubtitle();
    File('$metadataDir/$iosLocale/subtitle.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync(subtitle);
  }

  void _fitIosSupportUrlToFastlane() {
    final supportUrl = _getIosSupportUrl();
    File('$metadataDir/$iosLocale/support_url.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync(supportUrl);
  }

  void _fitStoreKeywordsToFastlane() {
    final storeKeywords = _getStoreKeywords();
    File('$metadataDir/$iosLocale/keywords.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync(storeKeywords);
  }

  void _fitStorePromotionalTextToFastlane() {
    final promotionalText = _getStorePromotionalText();
    File('$metadataDir/$iosLocale/promotional_text.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync(promotionalText);
  }

  void _fitStoreReleaseNoteToFastlane() {
    final storeReleaseNote = _getStoreReleaseNote();
    final fastlaneAndroidStoreReleaseNoteFile = File(
      '$metadataDir/android/$locale/changelogs/default.txt',
    );
    final fastlaneIosStoreReleaseNoteFile = File(
      '$metadataDir/$iosLocale/release_notes.txt',
    );

    fastlaneAndroidStoreReleaseNoteFile
      ..createSync(recursive: true)
      ..writeAsStringSync(storeReleaseNote);
    fastlaneIosStoreReleaseNoteFile
      ..createSync(recursive: true)
      ..writeAsStringSync(storeReleaseNote);
  }

  String _getAndroidShortDescription() {
    final shortDescription = _require('store_android_short_description');
    if (shortDescription.characters.length > 80) {
      throw StateError('$locale short_description is too long');
    }
    return shortDescription;
  }

  /// アプリの名前を取得します、これは30文字以内である必要があります。
  /// iOS、Androidの両方で使用されます。
  String _getAppName() {
    final appName = _require('app_name');
    if (appName.characters.length > 30) {
      throw StateError('$locale app_name is too long');
    }
    return appName;
  }

  String _getAppStoreName() {
    final appStoreName = _require('store_app_name');
    if (appStoreName.characters.length > 30) {
      throw StateError('$locale store_app_name is too long');
    }
    return appStoreName;
  }

  /// アプリの説明を取得します、これは4000文字以内である必要があります。
  /// iOS、Androidの両方で使用されます。
  String _getDescription() {
    final description = _require('store_description');
    if (description.characters.length > 4000) {
      throw StateError('$locale description is too long');
    }
    return description;
  }

  String _getIosPrivacyUrl() {
    final privacyUrl = _require('store_ios_privacy_url');
    if (privacyUrl.characters.length > 255) {
      throw StateError('$locale privacy_url is too long');
    }
    return privacyUrl;
  }

  String _getIosSubtitle() {
    final subtitle = _require('store_ios_subtitle');
    if (subtitle.characters.length > 30) {
      throw StateError('$locale subtitle is too long');
    }
    return subtitle;
  }

  String _getIosSupportUrl() {
    final supportUrl = _require('store_ios_support_url');
    if (supportUrl.characters.length > 255) {
      throw StateError('$locale support_url is too long');
    }
    return supportUrl;
  }

  File _getJsonFile() {
    final file = File('$rootPath/assets/localizations/$locale.json');
    if (!file.existsSync()) {
      throw StateError('Localization file not found: ${file.path}');
    }
    return file;
  }

  /// iOS側のキーワードを取得します、これは100文字以内である必要があります。
  String _getStoreKeywords() {
    final storeKeywords = _require('store_ios_keywords');
    if (storeKeywords.characters.length > 100) {
      throw StateError('$locale store_keywords is too long');
    }
    // Matched case-insensitively and on whole words: `contains('ios')` both
    // missed `iOS` and rejected innocent words such as `radios`.
    final blocked = _blockedKeywords
        .where(
          (word) => RegExp(
            r'\b' + RegExp.escape(word) + r'\b',
            caseSensitive: false,
          ).hasMatch(storeKeywords),
        )
        .toList();
    if (blocked.isNotEmpty) {
      throw StateError(
        '$locale store_ios_keywords contains blocked trademarks: '
        '${blocked.join(', ')}.',
      );
    }
    return storeKeywords;
  }

  /// iOS側のプロモーションテキストを取得します、これは170文字以内である必要があります。
  String _getStorePromotionalText() {
    final promotionalText = _require('store_ios_promotional_text');
    if (promotionalText.characters.length > 170) {
      throw StateError('$locale store_promotional_text is too long');
    }
    return promotionalText;
  }

  String _getStoreReleaseNote() => _require('store_release_note');
}
