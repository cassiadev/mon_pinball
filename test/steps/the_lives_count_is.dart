import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the lives count is {3}
Future<void> theLivesCountIs(WidgetTester tester, num param1) async {
  final lives = tester.widget<Text>(
    find.byKey(const ValueKey('pinball-lives')),
  );
  expect(int.parse(lives.data!), param1.toInt());
}
