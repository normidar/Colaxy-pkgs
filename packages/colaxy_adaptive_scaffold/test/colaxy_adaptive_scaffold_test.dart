import 'package:colaxy_adaptive_scaffold/colaxy_adaptive_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = [
  NavigationItem(
    name: 'Home',
    icon: Icon(Icons.home),
    page: Text('Home Page'),
  ),
  NavigationItem(
    name: 'Settings',
    icon: Icon(Icons.settings),
    page: Text('Settings Page'),
  ),
];

const List<NavigationItem> _manyItems = [
  ..._items,
  NavigationItem(
    name: 'Search',
    icon: Icon(Icons.search),
    page: Text('Search Page'),
  ),
  NavigationItem(
    name: 'Profile',
    icon: Icon(Icons.person),
    page: Text('Profile Page'),
  ),
  NavigationItem(
    name: 'More',
    icon: Icon(Icons.more_horiz),
    page: Text('More Page'),
  ),
];

Future<void> _pumpWithSize(
  WidgetTester tester,
  Widget child,
  Size size,
) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
}

void main() {
  testWidgets('AdaptiveScaffold builds correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdaptiveScaffold(items: _items),
      ),
    );

    expect(find.text('Home Page'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  group('layout selection', () {
    testWidgets('uses a NavigationBar on portrait screens', (tester) async {
      await _pumpWithSize(
        tester,
        const AdaptiveScaffold(items: _items),
        const Size(400, 800),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('uses a NavigationRail on landscape screens', (tester) async {
      await _pumpWithSize(
        tester,
        const AdaptiveScaffold(items: _items),
        const Size(1200, 800),
      );

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('respects a custom aspectRatioThreshold', (tester) async {
      // 1.5 aspect ratio with a threshold of 2.0 keeps bottom navigation.
      await _pumpWithSize(
        tester,
        const AdaptiveScaffold(items: _items, aspectRatioThreshold: 2),
        const Size(1200, 800),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('uses a Drawer when portrait items exceed the maximum', (
      tester,
    ) async {
      await _pumpWithSize(
        tester,
        const AdaptiveScaffold(items: _manyItems),
        const Size(400, 800),
      );

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);

      // Open the drawer and check every item is listed.
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.byType(Drawer), findsOneWidget);
      for (final item in _manyItems) {
        expect(find.text(item.name), findsWidgets);
      }
    });

    testWidgets('keeps the NavigationBar when items fit the maximum', (
      tester,
    ) async {
      await _pumpWithSize(
        tester,
        AdaptiveScaffold(
          items: _manyItems,
          maxBottomNavigationItems: _manyItems.length,
        ),
        const Size(400, 800),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('switches pages from the NavigationBar', (tester) async {
      await _pumpWithSize(
        tester,
        const AdaptiveScaffold(items: _items),
        const Size(400, 800),
      );

      expect(find.text('Home Page'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Settings Page'), findsOneWidget);
      expect(find.text('Home Page'), findsNothing);
    });

    testWidgets('switches pages from the NavigationRail', (tester) async {
      await _pumpWithSize(
        tester,
        const AdaptiveScaffold(items: _items),
        const Size(1200, 800),
      );

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Settings Page'), findsOneWidget);
    });

    testWidgets('switches pages from the Drawer', (tester) async {
      await _pumpWithSize(
        tester,
        const AdaptiveScaffold(items: _manyItems),
        const Size(400, 800),
      );

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search').last);
      await tester.pumpAndSettle();

      expect(find.text('Search Page'), findsOneWidget);
      // The drawer closes after selection.
      expect(find.byType(Drawer), findsNothing);
    });

    testWidgets('starts on initialIndex', (tester) async {
      await _pumpWithSize(
        tester,
        const AdaptiveScaffold(items: _items, initialIndex: 1),
        const Size(400, 800),
      );

      expect(find.text('Settings Page'), findsOneWidget);
    });

    testWidgets('clamps an out-of-range initialIndex', (tester) async {
      await _pumpWithSize(
        tester,
        const AdaptiveScaffold(items: _items, initialIndex: 10),
        const Size(400, 800),
      );

      // Clamped to the last item instead of throwing.
      expect(find.text('Settings Page'), findsOneWidget);
    });
  });

  group('options', () {
    testWidgets('shows the floating action button in both layouts', (
      tester,
    ) async {
      final fab = FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      );

      await _pumpWithSize(
        tester,
        AdaptiveScaffold(items: _items, floatingActionButton: fab),
        const Size(400, 800),
      );
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await _pumpWithSize(
        tester,
        AdaptiveScaffold(items: _items, floatingActionButton: fab),
        const Size(1200, 800),
      );
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('hides labels on short portrait screens', (tester) async {
      await _pumpWithSize(
        tester,
        const AdaptiveScaffold(items: _items),
        const Size(400, 500),
      );

      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(
        bar.labelBehavior,
        NavigationDestinationLabelBehavior.alwaysHide,
      );
    });
  });
}
