import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_helper/riverpod_helper.dart';

void main() {
  testWidgets('RiverpodErrorView shows widget name and error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RiverpodErrorView(
          widgetName: 'MyWidget',
          error: Exception('boom'),
          stackTrace: StackTrace.current,
        ),
      ),
    );

    expect(
      find.textContaining('MyWidget Error:'),
      findsOneWidget,
    );
    expect(find.textContaining('boom'), findsOneWidget);
  });
}
