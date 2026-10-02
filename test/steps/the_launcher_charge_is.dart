import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the launcher charge is {0}
Future<void> theLauncherChargeIs(WidgetTester tester, num param1) async {
  final progress = tester.widget<LinearProgressIndicator>(
    find.byKey(const ValueKey('pinball-launch-charge')),
  );
  expect(progress.value, param1.toDouble());
}
