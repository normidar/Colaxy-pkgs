import 'package:app_info_tile/app_info_tile.dart' as ait;
import 'package:app_lang_selector/app_lang_selector.dart' as als;
import 'package:app_theme_picker/app_theme_picker.dart' as atp;
import 'package:colaxy_tutorial/colaxy_tutorial.dart' as ct;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Groups the settings tile each package contributes: theme picking,
/// language selection, tutorial reset and app info.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _SectionHeader('settings_section_appearance'.tr()),
        const atp.ThemePickTile(),
        _SectionHeader('settings_section_language'.tr()),
        const als.AppLangSelectTile(),
        _SectionHeader('settings_section_help'.tr()),
        const ct.TutorialResetTile(),
        _SectionHeader('settings_section_about'.tr()),
        const ait.AppInfoTile(),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
