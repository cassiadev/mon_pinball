import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/pinball_style.dart';

/// Usage: the score is {0}
Future<void> theScoreIs(WidgetTester tester, num param1) async {
  final scoreDisplay = tester.widget<DotMatrixScore>(
    find.byKey(const ValueKey('pinball-score')),
  );
  expect(scoreDisplay.score, param1.toInt());
}
