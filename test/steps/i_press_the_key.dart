import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I press the {'W'} key
Future<void> iPressTheKey(WidgetTester tester, String param1) async {
  final key = switch (param1.toUpperCase()) {
    'W' => LogicalKeyboardKey.keyW,
    'R' => LogicalKeyboardKey.keyR,
    'A' => LogicalKeyboardKey.keyA,
    'D' => LogicalKeyboardKey.keyD,
    final invalid => throw ArgumentError.value(invalid, 'key'),
  };
  await tester.sendKeyDownEvent(key);
  await tester.pump();
  await tester.sendKeyUpEvent(key);
  await tester.pump();
}
