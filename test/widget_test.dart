import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';

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
    await tester.pumpWidget(const AlarmProApp());

    // Verify that the payment option text is rendered on launch.
    expect(find.textContaining('Pay \$19.00 to Stop Alarm'), findsOneWidget);
  });
}
