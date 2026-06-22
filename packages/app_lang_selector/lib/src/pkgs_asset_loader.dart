import 'dart:convert';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';

class PkgsAssetLoader extends AssetLoader {
  const PkgsAssetLoader({required this.packages});

  final List<String> packages;

  String getPackagePath(String packageName, Locale locale) {
    return 'packages/$packageName/assets/localizations/${locale.toStringWithSeparator(separator: "-")}.json';
  }

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final localeData = await loadLocale(path, locale);
    var packageDatas = <String, dynamic>{};
    for (final package in packages) {
      final packageData =
          ((await loadPackage(package, locale)) as Map<String, dynamic>?) ?? {};
      packageDatas = {...packageDatas, ...packageData};
    }
    final mergedData = {...localeData, ...packageDatas};
    EasyLocalization.logger.debug('Merged data: $mergedData');
    return mergedData;
  }

  Future<Map<String, dynamic>> loadLocale(
      String basePath, Locale locale) async {
    final localePath =
        '$basePath/${locale.toStringWithSeparator(separator: "-")}.json';
    EasyLocalization.logger.debug('Load asset from $localePath');
    return (json.decode(await rootBundle.loadString(localePath))
            as Map<String, dynamic>?) ??
        {};
  }

  Future<Map<String, dynamic>> loadPackage(
      String packageName, Locale locale) async {
    final localePath = getPackagePath(packageName, locale);
    EasyLocalization.logger.debug('Load asset from $localePath');
    return (json.decode(await rootBundle.loadString(localePath))
            as Map<String, dynamic>?) ??
        {};
  }
}
