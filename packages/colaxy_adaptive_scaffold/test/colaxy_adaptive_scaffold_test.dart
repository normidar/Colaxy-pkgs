import 'package:colaxy_adaptive_scaffold/colaxy_adaptive_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AdaptiveScaffold builds correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveScaffold(
          items: [
            NavigationItem(
              name: 'Home',
              icon: const Icon(Icons.home),
              page: const Text('Home Page'),
            ),
            NavigationItem(
              name: 'Settings',
              icon: const Icon(Icons.settings),
              page: const Text('Settings Page'),
            ),
          ],
        ),
      ),
    );

    expect(find.text('Home Page'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
