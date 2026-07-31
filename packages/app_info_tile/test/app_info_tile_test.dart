import 'package:app_info_tile/app_info_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAppInfo extends AppInfoPod {
  _StubAppInfo(this.info);

  final PackageInfo info;

  @override
  Future<PackageInfo> build() async => info;
}

final _packageInfo = PackageInfo(
  appName: 'Platform App Name',
  packageName: 'com.example.app',
  version: '1.2.3',
  buildNumber: '42',
);

Future<void> _pump(WidgetTester tester, {String? appName}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appInfoPodProvider.overrideWith(() => _StubAppInfo(_packageInfo)),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        home: Scaffold(
          body: ListView(children: [AppInfoTile(appName: appName)]),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders as a ListTile once the package info resolves', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byType(ListTile), findsOneWidget);
    expect(find.byIcon(Icons.info), findsOneWidget);
  });

  testWidgets('shows the platform app name by default', (tester) async {
    // The dialog used to render `'app_name'.tr()`, a key this package does not
    // ship, so an app that had not defined it saw the literal "app_name".
    await _pump(tester);
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(find.text('Platform App Name'), findsOneWidget);
    expect(find.text('app_name'), findsNothing);
  });

  testWidgets('appName overrides the platform name', (tester) async {
    await _pump(tester, appName: 'Localized Name');
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(find.text('Localized Name'), findsOneWidget);
  });

  testWidgets('shows version and build number', (tester) async {
    await _pump(tester);
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(find.text('1.2.3-42'), findsOneWidget);
  });

  testWidgets('opens the license page', (tester) async {
    await _pump(tester);
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
  });
}
