import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Landing tab: a welcome card plus a rundown of which package backs each
/// feature elsewhere in the app, so it's obvious what to go try.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const _packageKeys = [
    'home_package_adaptive_scaffold',
    'home_package_theme_picker',
    'home_package_lang_selector',
    'home_package_tutorial',
    'home_package_riverpod_helper',
    'home_package_info_tile',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'home_welcome_title'.tr(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'home_welcome_body'.tr(),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'home_packages_title'.tr(),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                for (final key in _packageKeys)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.check_circle_outline, size: 20),
                    title: Text(key.tr()),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
