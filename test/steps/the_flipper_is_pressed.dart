import 'package:flutter_test/flutter_test.dart';

import '../support/pinball_test_harness.dart';

/// Usage: the `<side>` flipper is pressed
Future<void> theFlipperIsPressed(WidgetTester tester, dynamic side) async {
  final game = requirePinballGame();
  final isPressed = switch (side as String) {
    'left' => game.isLeftFlipperPressed,
    'right' => game.isRightFlipperPressed,
    final invalid => throw ArgumentError.value(invalid, 'side'),
  };
  expect(isPressed, isTrue);
}
