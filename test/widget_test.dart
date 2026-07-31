import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campus_events/screens/shared/splash_screen.dart';

void main() {
  testWidgets('Splash screen shows Alpha1.0', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.text('Alpha1.0'), findsOneWidget);
  });
}
