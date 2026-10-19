import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/pinball_style.dart';

/// Usage: the lives count is {3}
Future<void> theLivesCountIs(WidgetTester tester, num param1) async {
  final lives = tester.widget<LivesIndicator>(
    find.byKey(const ValueKey('pinball-lives')),
  );
  expect(lives.lives, param1.toInt());
}
