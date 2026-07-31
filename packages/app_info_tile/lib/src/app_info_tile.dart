import 'package:app_info_tile/app_info_tile.dart';
import 'package:app_lang_selector/app_lang_selector.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_helper/riverpod_helper.dart';

// app_info_tile

/// A [ListTile] that opens a dialog showing the app's name and version, with a
/// shortcut to the bundled license page.
class AppInfoTile extends ConsumerWidget {
  /// Creates an app info tile.
  const AppInfoTile({
    this.appName,
    this.applicationIcon,
    this.applicationLegalese,
    super.key,
  });

  /// The name to show for the app.
  ///
  /// Defaults to the name reported by the platform (`PackageInfo.appName`), so
  /// nothing has to be configured for the common case. Pass a value to show a
  /// localized name instead, e.g. `'my_app_name'.tr()`.
  final String? appName;

  /// Icon shown on the license page. Forwarded to [showLicensePage].
  final Widget? applicationIcon;

  /// Legalese shown on the license page. Forwarded to [showLicensePage].
  final String? applicationLegalese;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched so the tile rebuilds when the language changes and `.tr()` is
    // re-evaluated.
    ref.watch(selectingLangProvider);
    final appInfo = ref.watch(appInfoPodProvider);
    return switch (appInfo) {
      AsyncData(:final value) => ListTile(
          leading: const Icon(Icons.info),
          title: const Text('app_info_tile:title').tr(),
          onTap: () => showDialog<void>(
            context: context,
            builder: (con) => _buildAlertDialog(
              packageInfo: value,
              context: con,
            ),
          ),
        ),
      // Keep the same shape as the loaded tile so the surrounding list does not
      // jump once the package info resolves.
      AsyncLoading() => const ListTile(
          leading: Icon(Icons.info),
          title: LinearProgressIndicator(),
        ),
      AsyncError(:final error, :final stackTrace) => RiverpodErrorView(
          widgetName: '$AppInfoTile',
          error: error,
          stackTrace: stackTrace,
        ),
    };
  }

  Widget _buildAlertDialog({
    required PackageInfo packageInfo,
    required BuildContext context,
  }) {
    final name = appName ?? packageInfo.appName;
    return AlertDialog(
      title: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(name),
            Text('${packageInfo.version}-${packageInfo.buildNumber}'),
          ],
        ),
      ),
      content: Text('app_info_tile:license_hint'.tr()),
      actions: [
        TextButton(
          onPressed: () {
            showLicensePage(
              applicationName: name,
              applicationVersion: packageInfo.version,
              applicationIcon: applicationIcon,
              applicationLegalese: applicationLegalese,
              context: context,
            );
          },
          child: const Text('app_info_tile:view_license').tr(),
        ),
      ],
      actionsAlignment: MainAxisAlignment.center,
    );
  }
}
