import 'package:app_lang_selector/app_lang_selector.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppLangSelectTile extends ConsumerWidget {
  const AppLangSelectTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _ = ref.watch<String?>(selectingLangProvider);

    return ListTile(
      leading: const Icon(Icons.language),
      title: Text('select_lang'.tr()),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => const AppLangSelectPage(),
          ),
        );
      },
    );
  }
}
