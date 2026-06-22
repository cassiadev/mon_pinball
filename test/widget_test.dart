import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/main.dart';

void main() {
  testWidgets('pinball app renders HUD', (WidgetTester tester) async {
    await tester.pumpWidget(const MonPinballApp());
    await tester.pump();

    expect(find.text('MON PINBALL'), findsOneWidget);
    expect(find.textContaining('Lives'), findsOneWidget);
  });
}
