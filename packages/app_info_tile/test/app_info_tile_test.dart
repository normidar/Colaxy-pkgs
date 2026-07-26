import 'dart:async';

import 'package:app_info_tile/app_info_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_helper/riverpod_helper.dart';

class _FakeAppInfoPod extends AppInfoPod {
  @override
  Future<PackageInfo> build() async {
    return PackageInfo(
      appName: 'Test App',
      packageName: 'com.example.test',
      version: '1.2.3',
      buildNumber: '45',
    );
  }
}

class _LoadingAppInfoPod extends AppInfoPod {
  @override
  Future<PackageInfo> build() {
    return Completer<PackageInfo>().future;
  }
}

class _ErrorAppInfoPod extends AppInfoPod {
  @override
  Future<PackageInfo> build() async {
    throw Exception('failed to load package info');
  }
}

void main() {
  test('packageName constant matches the package', () {
    expect(packageName, 'app_info_tile');
  });

  group('AppInfoTile', () {
    testWidgets('shows a ListTile when app info is available', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appInfoPodProvider.overrideWith(_FakeAppInfoPod.new),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AppInfoTile()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byIcon(Icons.info), findsOneWidget);
    });

    testWidgets('opens the info dialog on tap', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appInfoPodProvider.overrideWith(_FakeAppInfoPod.new),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AppInfoTile()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('1.2.3-45'), findsOneWidget);
    });

    testWidgets('shows a progress indicator while loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appInfoPodProvider.overrideWith(_LoadingAppInfoPod.new),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AppInfoTile()),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows an error view when loading fails', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appInfoPodProvider.overrideWith(_ErrorAppInfoPod.new),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AppInfoTile()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RiverpodErrorView), findsOneWidget);
      expect(
        find.textContaining('failed to load package info'),
        findsOneWidget,
      );
    });
  });
}
