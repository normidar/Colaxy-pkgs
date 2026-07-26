import 'package:app_theme_picker/app_theme_picker.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeColorButton', () {
    testWidgets('renders and reports taps', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemeColorButton(
              schemeData: FlexColor.schemes[FlexScheme.sakura]!,
              onTap: () => tapped = true,
              selected: false,
            ),
          ),
        ),
      );

      expect(find.byType(ThemeColorButton), findsOneWidget);
      await tester.tap(find.byType(InkWell).first);
      expect(tapped, isTrue);
    });
  });

  group('ThemeModeButton', () {
    testWidgets('shows the icon for its mode and changes the mode on tap',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ThemeModeButton(mode: ThemeMode.dark),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Not selected yet: the default (light) mode is active.
      expect(find.byIcon(Icons.nights_stay_outlined), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      // After tapping, dark mode is selected and the filled icon shows.
      expect(find.byIcon(Icons.nights_stay), findsOneWidget);
    });
  });
}
