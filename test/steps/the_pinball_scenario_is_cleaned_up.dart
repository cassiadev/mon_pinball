import 'package:flutter_test/flutter_test.dart';

import '../support/pinball_test_harness.dart';

/// Usage: the pinball scenario is cleaned up
Future<void> thePinballScenarioIsCleanedUp(WidgetTester tester) async {
  await disposePinballScenario(tester);
}
