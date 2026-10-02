import 'package:flutter_test/flutter_test.dart';

import '../support/pinball_test_harness.dart';

/// Usage: I pull the plunger down by {80} pixels
Future<void> iPullThePlungerDownByPixels(
  WidgetTester tester,
  num param1,
) async {
  currentPinballGesture = await tester.startGesture(plungerPosition(tester));
  currentGestureTarget = 'plunger';
  await tester.pump();
  await currentPinballGesture!.moveBy(Offset(0, param1.toDouble()));
  await tester.pump();
}
