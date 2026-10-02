import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the status is {'Table nudge'}
Future<void> theStatusIs(WidgetTester tester, String param1) async {
  final statusText = tester.widget<Text>(
    find.byKey(const ValueKey('pinball-status')),
  );
  expect(statusText.data, param1);
}
