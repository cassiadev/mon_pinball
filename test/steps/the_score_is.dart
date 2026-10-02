import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the score is {0}
Future<void> theScoreIs(WidgetTester tester, num param1) async {
  final scoreText = tester.widget<Text>(
    find.byKey(const ValueKey('pinball-score')),
  );
  final score = int.parse(scoreText.data!);
  expect(score, param1.toInt());
}
