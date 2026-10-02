import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I tap the restart control
Future<void> iTapTheRestartControl(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('pinball-restart')));
  await tester.pump();
}
