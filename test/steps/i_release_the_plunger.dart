import 'package:flutter_test/flutter_test.dart';

import '../support/pinball_test_harness.dart';

/// Usage: I release the plunger
Future<void> iReleaseThePlunger(WidgetTester tester) async {
  expect(currentGestureTarget, 'plunger');
  final gesture = currentPinballGesture;
  if (gesture == null) {
    throw StateError('There is no active plunger gesture to release.');
  }
  await gesture.up();
  currentPinballGesture = null;
  currentGestureTarget = null;
  await tester.pump();
}
