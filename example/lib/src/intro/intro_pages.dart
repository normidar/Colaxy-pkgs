import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'intro_tutorial_page.dart';

/// The pages shown by `TutorialTool.guardTutorialPage` the first time the app
/// launches. `colaxy_tutorial` persists a "seen" flag under [introTutorialId],
/// so this only appears once per install — the "Reset" button behind
/// `TutorialResetTile` in Settings clears it again.
const introTutorialId = 'colaxy_example_intro';

List<Widget> buildIntroPages() {
  return [
    IntroTutorialPage(
      icon: Icons.view_sidebar_outlined,
      title: 'intro_page1_title'.tr(),
      body: 'intro_page1_body'.tr(),
      color: Colors.blue.shade50,
    ),
    IntroTutorialPage(
      icon: Icons.widgets_outlined,
      title: 'intro_page2_title'.tr(),
      body: 'intro_page2_body'.tr(),
      color: Colors.green.shade50,
    ),
  ];
}
