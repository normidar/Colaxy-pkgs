import 'dart:async';

import 'package:app_lang_selector/app_lang_selector.dart';
import 'package:app_theme_picker/app_theme_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A [ListTile] that opens the [PickThemePage].
class ThemePickTile extends ConsumerWidget {
  /// Creates a theme picker tile.
  const ThemePickTile({this.availableSchemes, this.size = 70, super.key});

  /// If not null, only the schemes in the set are available.
  final Set<FlexScheme>? availableSchemes;

  /// Size of each colour swatch on the page this tile opens.
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched so the tile re-translates when the language changes.
    ref.watch(selectingLangProvider);
    return ListTile(
      leading: const Icon(Icons.palette),
      title: const Text('app_theme_picker:tile_title').tr(),
      onTap: () {
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => PickThemePage(
                availableSchemes: availableSchemes,
                size: size,
              ),
            ),
          ),
        );
      },
    );
  }
}
