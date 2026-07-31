import 'dart:io';

import 'package:colaxy_localization/colaxy_localization.dart';
import 'package:yaml/yaml.dart' show YamlMap, loadYaml;

/// The locale that is treated as the app's main one when none is given.
const defaultMainLocale = 'en-US';

/// 一個のアプリのローカリゼーション、中に複数のLocaleUnitが存在する可能性がある
class LocaleApp {
  /// Creates a locale app rooted at [rootPath] (the app's project directory).
  const LocaleApp({this.rootPath = '.'});

  /// The app's project directory.
  ///
  /// Paths like `assets/localizations` and `pubspec.yaml` are resolved against
  /// this, so [getLocaleApps] can return apps that actually point somewhere.
  final String rootPath;

  /// Directory holding this app's `<locale>.json` files.
  String get localizationsDir => '$rootPath/assets/localizations';

  /// アプリのローカリゼーションのユニットを取得する
  ///
  /// [mainLocale] is the locale written to the platform default slots
  /// (`values/strings.xml`, `Info.plist`). Defaults to [defaultMainLocale].
  List<LocaleUnit> getLocaleUnits({String mainLocale = defaultMainLocale}) {
    AndroidNameLocalization(rootPath: rootPath).updateManifestAppName();

    final appsDir = Directory(localizationsDir);
    if (!appsDir.existsSync()) {
      throw StateError('Localizations directory not found: $localizationsDir');
    }

    final localeUnits = <LocaleUnit>[];
    for (final fse in appsDir.listSync()) {
      if (fse is! File) continue;
      final locale = fse.uri.pathSegments.last.split('.').first;
      localeUnits.add(LocaleUnit(locale: locale, rootPath: rootPath));
    }

    if (localeUnits.isEmpty) {
      throw StateError('No localization files found in $localizationsDir');
    }

    // メインのロケールを設定する
    if (localeUnits.length == 1) {
      localeUnits.first.isMainLocale = true;
    } else {
      // `firstWhere` without `orElse` threw a bare StateError when the app had
      // no en-US.json, which said nothing about what was actually wrong.
      final main = localeUnits.where((e) => e.locale == mainLocale).firstOrNull;
      if (main == null) {
        throw StateError(
          'Main locale "$mainLocale" not found in $localizationsDir. '
          'Available: ${localeUnits.map((e) => e.locale).join(', ')}. '
          'Pass `mainLocale` to pick a different one.',
        );
      }
      main.isMainLocale = true;
    }

    IOSNameLocalization(
      rootPath: rootPath,
    ).fitAppSupportLocales(localeUnits.map((e) => e.locale).toList());

    return localeUnits;
  }

  /// Reads `minimum_version` from the app's pubspec, or null when unset.
  String? getMinimumVersion() {
    final pubspecYaml = File('$rootPath/pubspec.yaml');
    if (!pubspecYaml.existsSync()) {
      return null;
    }

    final pubspecYamlContent = pubspecYaml.readAsStringSync();
    final pubspecYamlMap = loadYaml(pubspecYamlContent);
    if (pubspecYamlMap is! YamlMap) return null;
    return pubspecYamlMap['minimum_version'] as String?;
  }

  /// Finds every app directory under `words_set/apps`.
  ///
  /// Each returned [LocaleApp] carries the directory it was found in;
  /// previously this returned a list of identical `const LocaleApp()` values,
  /// which discarded the very information it was collecting.
  static List<LocaleApp> getLocaleApps({String rootPath = 'words_set/apps'}) {
    final appsDir = Directory(rootPath);
    if (!appsDir.existsSync()) {
      throw StateError('Apps directory not found: $rootPath');
    }

    return appsDir
        .listSync()
        .whereType<Directory>()
        .map((dir) => LocaleApp(rootPath: dir.path))
        .toList();
  }
}
