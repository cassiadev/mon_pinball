import 'package:flutter_test/flutter_test.dart';

import '../support/pinball_test_harness.dart';

/// Usage: I hold the `<side>` playfield
Future<void> iHoldThePlayfield(WidgetTester tester, dynamic side) async {
  final target = side as String;
  currentPinballGesture = await tester.startGesture(
    playfieldPosition(tester, target),
  );
  currentGestureTarget = target;
  await tester.pump();
}
