import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the launcher charge is greater than {0}
Future<void> theLauncherChargeIsGreaterThan(
  WidgetTester tester,
  num param1,
) async {
  final progress = tester.widget<LinearProgressIndicator>(
    find.byKey(const ValueKey('pinball-launch-charge')),
  );
  expect(progress.value, greaterThan(param1.toDouble()));
}
