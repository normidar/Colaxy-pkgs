import 'dart:async';

import 'package:app_lang_selector/app_lang_selector.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppLangSelectTile extends ConsumerWidget {
  const AppLangSelectTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched so the tile re-translates when the language changes.
    ref.watch<String?>(selectingLangProvider);

    return ListTile(
      leading: const Icon(Icons.language),
      title: Text('app_lang_selector:select_lang'.tr()),
      onTap: () {
        unawaited(
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => const AppLangSelectPage(),
            ),
          ),
        );
      },
    );
  }
}
