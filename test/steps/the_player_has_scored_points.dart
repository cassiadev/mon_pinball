import 'package:flutter_test/flutter_test.dart';

import '../support/pinball_test_harness.dart';

/// Usage: the player has scored {750} points
Future<void> thePlayerHasScoredPoints(WidgetTester tester, num param1) async {
  addTestScore(param1.toInt());
  await tester.pump();
}
