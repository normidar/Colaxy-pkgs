import 'package:app_info_tile/app_info_tile.dart';
import 'package:app_lang_selector/app_lang_selector.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_helper/riverpod_helper.dart';

// app_info_tile

class AppInfoTile extends ConsumerWidget {
  const AppInfoTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _ = ref.watch(selectingLangProvider);
    final appInfo = ref.watch(appInfoPodProvider);
    return switch (appInfo) {
      AsyncData(:final value) => ListTile(
          leading: const Icon(Icons.info),
          title: const Text('app_info_tile_title').tr(),
          onTap: () => showDialog<void>(
            context: context,
            builder: (con) => getAlertDialog(packageInfo: value, context: con),
          ),
        ),
      AsyncLoading() => const Center(child: CircularProgressIndicator()),
      AsyncError(:final error, :final stackTrace) => RiverpodErrorView(
          widgetName: '$AppInfoTile',
          error: error,
          stackTrace: stackTrace,
        ),
    };
  }

  Widget getAlertDialog({
    required PackageInfo packageInfo,
    required BuildContext context,
  }) {
    return AlertDialog(
      title: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('app_name'.tr()),
            Text('${packageInfo.version}-${packageInfo.buildNumber}'),
          ],
        ),
      ),
      content: Text('license_hint'.tr()),
      actions: [
        TextButton(
          onPressed: () {
            showLicensePage(
              applicationName: 'app_name'.tr(),
              applicationVersion: packageInfo.version,
              context: context,
            );
          },
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.all<Color>(Colors.blue),
          ),
          child: const Text('view_license').tr(),
        ),
      ],
      actionsAlignment: MainAxisAlignment.center,
    );
  }
}
