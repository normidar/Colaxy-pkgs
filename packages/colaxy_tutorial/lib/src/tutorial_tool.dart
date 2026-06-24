import 'dart:ui';

import 'package:colaxy_tutorial/colaxy_tutorial.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Main utility class for managing tutorial functionality.
class TutorialTool {
  /// Controls whether tutorials should be visible globally.
  static bool tutorialVisible = true;

  /// Guard a tutorial page.
  ///
  /// If the tutorial page has been shown, return the [nextPage].
  /// If the tutorial page has not been shown,
  ///   show the tutorial page and return [nextPage] if it is not null.
  static Widget guardTutorialPage({
    required String id,
    required List<Widget> pages,
    required Widget nextPage,
  }) {
    return FutureBuilder<bool>(
      future: () async {
        final key = '$packageName:$id';
        final prefs = await SharedPreferences.getInstance();
        final showed = prefs.getBool(key) ?? false;
        return showed;
      }(),
      builder: (context, snapshot) => switch (snapshot.data) {
        true => nextPage,
        false => _TutorialPageView(pages: pages, nextPage: nextPage, id: id),
        null =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      },
    );
  }

  /// Navigates to a tutorial page with horizontal scrolling.
  ///
  /// Displays a PageView with the provided [pages], a Skip button
  /// in the top-right, and a Start button in the bottom-right on the last page.
  static Future<void> jumpToTutorialPage({
    required String id,
    required BuildContext buildContext,
    required List<Widget> pages,
  }) async {
    final key = '$packageName:$id';
    final prefs = await SharedPreferences.getInstance();

    final showed = prefs.getBool(key) ?? false;
    if (showed) {
      return;
    }

    if (buildContext.mounted) {
      await Navigator.of(buildContext).push(
        MaterialPageRoute<void>(
          builder: (context) =>
              _TutorialPageView(pages: pages, nextPage: null, id: id),
        ),
      );
    }
  }

  /// Resets all tutorial states, allowing them to be shown again.
  static Future<void> resetTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final showedIds = prefs.getStringList('$packageName:showed_ids') ?? [];
    for (final id in showedIds) {
      await prefs.remove('$packageName:$id');
    }
  }

  /// Saves the list of tutorial IDs that have been shown.
  static Future<void> saveShowedIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    for (final id in ids) {
      await prefs.setBool('$packageName:$id', true);
    }
    const key = '$packageName:showed_ids';
    await prefs.setStringList(
      key,
      <String>{...ids, ...(prefs.getStringList(key) ?? [])}.toList(),
    );
  }

  /// Shows a tutorial with the specified data sets.
  static Future<void> showTutorial({
    required List<TutorialDataSet> dataSets,
    required BuildContext buildContext,
  }) async {
    if (!tutorialVisible) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    final toShowIds = <String>[];

    /// ターゲットを作成する。
    final targets = <TargetFocus>[];
    for (final dataSet in dataSets) {
      final showed = prefs.getBool('$packageName:${dataSet.id}') ?? false;
      if (showed) {
        continue;
      }
      toShowIds.add(dataSet.id);
      targets.add(
        TargetFocus(
          // チュートリアルの背景色
          color: const Color.fromARGB(255, 195, 226, 240),
          identify: dataSet.id,
          keyTarget: dataSet.key,
          alignSkip: Alignment.topRight,
          enableOverlayTab: true,
          shape: dataSet.shape.shape,
          contents: [
            TargetContent(
              align: dataSet.align.contentAlign,
              builder: (context, _) => DefaultTextStyle(
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 21,
                ),
                child: dataSet.builder(context),
              ),
            ),
          ],
        ),
      );
    }

    if (toShowIds.isEmpty) {
      return;
    }

    final tutorialCoachMark = TutorialCoachMark(
      textSkip: '$packageName:skip'.tr(),
      textStyleSkip: TextStyle(color: Colors.red[300]),
      targets: targets,
      colorShadow: Colors.grey,
      opacityShadow: 0.5,
      imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
    );

    Future.delayed(const Duration(milliseconds: 300), () async {
      if (buildContext.mounted) {
        tutorialCoachMark.show(context: buildContext);
        await saveShowedIds(toShowIds);
      }
    });
  }

  /// By condition maybe show or not.
  static Future<void> showTutorialDialog({
    required String id,
    required BuildContext buildContext,
    required Widget child,
    required String title,
    required bool showDontShowAgain,
  }) async {
    final key = '$packageName:$id';

    final prefs = await SharedPreferences.getInstance();

    final showed = prefs.getBool(key) ?? false;
    if (showed) {
      return;
    }

    if (buildContext.mounted) {
      final dontShowAgain = await showDialog<bool>(
        context: buildContext,
        barrierDismissible: false,
        builder: (context) => TutorialToolNotifier(
          title: title,
          showDontShowAgain: showDontShowAgain,
          child: child,
        ),
      );
      if (dontShowAgain ?? false) {
        await saveShowedIds([id]);
      }
    }
  }
}

/// Internal widget for displaying tutorial pages with navigation controls.
class _TutorialPageView extends StatefulWidget {
  const _TutorialPageView({
    required this.pages,
    required this.nextPage,
    required this.id,
  });

  final List<Widget> pages;

  final Widget? nextPage;

  final String id;

  @override
  State<_TutorialPageView> createState() => _TutorialPageViewState();
}

class _TutorialPageViewState extends State<_TutorialPageView> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == widget.pages.length - 1;

    return Scaffold(
      body: Stack(
        children: [
          // PageView with tutorial pages
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: widget.pages,
          ),

          // Skip button (top-right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: TextButton(
              onPressed: _finish,
              style: TextButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: Text(
                '$packageName:skip'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Start button (bottom-right, only on last page)
          if (isLastPage)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              right: 24,
              child: ElevatedButton(
                onPressed: _finish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  '$packageName:start'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  void _finish() {
    TutorialTool.saveShowedIds([widget.id]);
    final nextPage = widget.nextPage;
    if (nextPage != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (context) => nextPage,
        ),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }
}
