import 'package:flutter_test/flutter_test.dart';

import '../support/pinball_test_harness.dart';

/// Usage: the pinball app is running
Future<void> thePinballAppIsRunning(WidgetTester tester) async {
  await pumpPinballApp(tester);
}
