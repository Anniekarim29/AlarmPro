// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:alarm_pro/main.dart';

void main() {
  testWidgets('AlarmPro build smoke test', (WidgetTester tester) async {
    // Set portrait mobile dimensions to prevent landscape overflow in test environment
    tester.view.physicalSize = const Size(1800, 3000); // 600x1000 logical pixels
    tester.view.devicePixelRatio = 3.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AlarmState(),
        child: const AlarmProApp(),
      ),
    );

    // Verify that the title is rendered.
    expect(find.text('RISE & GRIND.'), findsOneWidget);
  });
}
