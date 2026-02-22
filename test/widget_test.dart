// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safesight/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // We must wrap the app in ProviderScope just like in main()
    await tester.pumpWidget(const ProviderScope(child: SafeSightApp()));

    // Verify that the Splash Screen text renders
    expect(find.text('Safe'), findsOneWidget);
    expect(find.text('Sight'), findsOneWidget);
  });
}