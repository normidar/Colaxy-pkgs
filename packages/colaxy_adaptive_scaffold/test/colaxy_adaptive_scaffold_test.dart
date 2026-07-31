import 'package:colaxy_adaptive_scaffold/colaxy_adaptive_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A page that records how many times its State has been created.
class _CountingPage extends StatefulWidget {
  const _CountingPage(this.label);

  final String label;

  @override
  State<_CountingPage> createState() => _CountingPageState();
}

class _CountingPageState extends State<_CountingPage> {
  static final initCounts = <String, int>{};

  int taps = 0;

  @override
  void initState() {
    super.initState();
    initCounts.update(widget.label, (v) => v + 1, ifAbsent: () => 1);
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => setState(() => taps++),
      child: Text('${widget.label}:$taps'),
    );
  }
}

List<NavigationItem> _items(int count) => [
  for (var i = 0; i < count; i++)
    NavigationItem(
      name: 'Item$i',
      icon: const Icon(Icons.circle_outlined),
      selectedIcon: const Icon(Icons.circle),
      page: _CountingPage('Page$i'),
    ),
];

/// Sizes the test surface so a specific layout branch is chosen.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required Size size,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
}

const _portrait = Size(400, 800); // aspect 0.5 -> bottom navigation
const _landscape = Size(1200, 800); // aspect 1.5 -> rail

void main() {
  setUp(_CountingPageState.initCounts.clear);

  testWidgets('renders bottom navigation on portrait layouts', (tester) async {
    await _pump(tester, AdaptiveScaffold(items: _items(3)), size: _portrait);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('renders a rail on landscape layouts', (tester) async {
    await _pump(tester, AdaptiveScaffold(items: _items(3)), size: _landscape);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('falls back to a drawer past maxBottomNavigationItems', (
    tester,
  ) async {
    await _pump(tester, AdaptiveScaffold(items: _items(5)), size: _portrait);

    // The Drawer widget is only built once opened, so assert on the Scaffold's
    // configuration rather than on the drawer being in the tree.
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).drawer,
      isNotNull,
    );
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('drawer header only appears when drawerTitle is given', (
    tester,
  ) async {
    Future<void> openDrawer() async {
      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();
    }

    await _pump(tester, AdaptiveScaffold(items: _items(5)), size: _portrait);
    await openDrawer();
    expect(find.byType(DrawerHeader), findsNothing);

    await _pump(
      tester,
      AdaptiveScaffold(items: _items(5), drawerTitle: 'Menu'),
      size: _portrait,
    );
    await openDrawer();
    expect(find.byType(DrawerHeader), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget);
  });

  testWidgets('keeps page state when switching destinations', (tester) async {
    await _pump(tester, AdaptiveScaffold(items: _items(2)), size: _portrait);

    // Put some state on the first page.
    await tester.tap(find.text('Page0:0'));
    await tester.pump();
    expect(find.text('Page0:1'), findsOneWidget);

    // Move away and back again.
    await tester.tap(find.text('Item1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Item0'));
    await tester.pumpAndSettle();

    // The counter survived, and the State was never recreated.
    expect(find.text('Page0:1'), findsOneWidget);
    expect(_CountingPageState.initCounts['Page0'], 1);
  });

  testWidgets('only builds a page once it is first selected', (tester) async {
    await _pump(tester, AdaptiveScaffold(items: _items(3)), size: _portrait);

    // An IndexedStack builds every child, which would run each page's
    // initState (and anything it kicks off) at launch.
    expect(_CountingPageState.initCounts.keys, ['Page0']);

    await tester.tap(find.text('Item2'));
    await tester.pumpAndSettle();

    expect(_CountingPageState.initCounts.keys, ['Page0', 'Page2']);
    // Page0 is still alive, not rebuilt.
    expect(_CountingPageState.initCounts['Page0'], 1);
  });

  testWidgets('lazy: false builds every page up front', (tester) async {
    await _pump(
      tester,
      AdaptiveScaffold(items: _items(3), lazy: false),
      size: _portrait,
    );

    expect(_CountingPageState.initCounts.keys, ['Page0', 'Page1', 'Page2']);
  });

  testWidgets('reports selection changes through onDestinationSelected', (
    tester,
  ) async {
    final selected = <int>[];
    await _pump(
      tester,
      AdaptiveScaffold(items: _items(2), onDestinationSelected: selected.add),
      size: _portrait,
    );

    await tester.tap(find.text('Item1'));
    await tester.pumpAndSettle();

    expect(selected, [1]);
  });

  testWidgets('clamps an out-of-range initialIndex', (tester) async {
    await _pump(
      tester,
      AdaptiveScaffold(items: _items(2), initialIndex: 99),
      size: _portrait,
    );

    expect(find.text('Page1:0'), findsOneWidget);
  });

  testWidgets('an empty item list trips the debug assert, not clamp', (
    tester,
  ) async {
    // In release builds the assert is stripped; `initialIndex.clamp(0, -1)`
    // used to throw an ArgumentError there. The guard added to `_clampIndex`
    // and `build` handles that path, so the only failure left is this
    // developer-facing assert.
    await _pump(tester, const AdaptiveScaffold(items: []), size: _portrait);

    final error = tester.takeException();
    expect(error, isAssertionError);
    expect(
      (error as AssertionError).message,
      'items must contain at least one item',
    );
  });

  testWidgets('keeps the selection valid when items shrink', (tester) async {
    await _pump(
      tester,
      AdaptiveScaffold(items: _items(3), initialIndex: 2),
      size: _portrait,
    );
    expect(find.text('Page2:0'), findsOneWidget);

    await _pump(tester, AdaptiveScaffold(items: _items(2)), size: _portrait);

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
