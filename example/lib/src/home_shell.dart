import 'package:colaxy_adaptive_scaffold/colaxy_adaptive_scaffold.dart';
import 'package:colaxy_tutorial/colaxy_tutorial.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'favorites/favorites_page.dart';
import 'home/home_page.dart';
import 'intro/intro_pages.dart';
import 'settings/settings_page.dart';

/// Top-level navigation: three tabs (Home, Favorites, Settings) behind
/// [AdaptiveScaffold], gated behind the one-time intro tutorial.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return TutorialTool.guardTutorialPage(
      id: introTutorialId,
      pages: buildIntroPages(),
      nextPage: const _AdaptiveHomeShell(),
    );
  }
}

class _AdaptiveHomeShell extends StatefulWidget {
  const _AdaptiveHomeShell();

  @override
  State<_AdaptiveHomeShell> createState() => _AdaptiveHomeShellState();
}

class _AdaptiveHomeShellState extends State<_AdaptiveHomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final names = ['nav_home'.tr(), 'nav_favorites'.tr(), 'nav_settings'.tr()];

    return AdaptiveScaffold(
      drawerTitle: 'app_title'.tr(),
      appBar: AppBar(title: Text(names[_selectedIndex])),
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      items: [
        NavigationItem(
          name: names[0],
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home),
          page: const HomePage(),
        ),
        NavigationItem(
          name: names[1],
          icon: const Icon(Icons.favorite_border),
          selectedIcon: const Icon(Icons.favorite),
          page: const FavoritesPage(),
        ),
        NavigationItem(
          name: names[2],
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          page: const SettingsPage(),
        ),
      ],
    );
  }
}
