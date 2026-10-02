import 'package:flutter_test/flutter_test.dart';

import '../support/pinball_test_harness.dart';

/// Usage: I release the `<side>` playfield
Future<void> iReleaseThePlayfield(WidgetTester tester, dynamic side) async {
  expect(currentGestureTarget, side);
  final gesture = currentPinballGesture;
  if (gesture == null) {
    throw StateError('There is no active playfield gesture to release.');
  }
  await gesture.up();
  currentPinballGesture = null;
  currentGestureTarget = null;
  await tester.pump();
}
