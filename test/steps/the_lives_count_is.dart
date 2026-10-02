import 'package:flutter_test/flutter_test.dart';

/// Usage: the lives count is {3}
Future<void> theLivesCountIs(WidgetTester tester, num param1) async {
  expect(find.text('Lives ${param1.toInt()}'), findsOneWidget);
}
