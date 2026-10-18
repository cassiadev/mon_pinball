import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/pinball_game.dart';
import 'package:mon_pinball/pinball_style.dart';

import 'support/pinball_test_harness.dart';

void main() {
  configurePinballTestBinding();
  setUpAll(loadPinballTestFont);

  testWidgets('remaining boss health is visible and accessible before launch', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpPinballApp(tester, pauseGame: true);
      addTearDown(() => disposePinballScenario(tester));
      expect(find.bySemanticsLabel('츠키비나 남은 체력 16000 / 16000'), findsOneWidget);
      final bar = tester.widget<HealthBar>(
        find.byKey(const ValueKey('pinball-boss-health')),
      );
      expect(bar.value, 1);
      expectCompactInstrumentsLeaveTheTable(tester);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'health and combo follow the encounter snapshot without a percent label',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final game = await pumpPinballApp(tester, pauseGame: true);
        addTearDown(() => disposePinballScenario(tester));
        game.hud.value = const PinballSnapshot(
          score: 1280,
          lives: 3,
          launchCharge: 0,
          status: '약점 격파',
          gameOver: false,
          bossHealth: 14720,
          combo: 3,
        );
        await tester.pump();
        expect(
          tester
              .widget<HealthBar>(
                find.byKey(const ValueKey('pinball-boss-health')),
              )
              .value,
          closeTo(0.92, 0.0001),
        );
        expect(_comboText('3'), findsOneWidget);
        expect(
          find.bySemanticsLabel('츠키비나 남은 체력 14720 / 16000'),
          findsOneWidget,
        );
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('츠키비나 남은 체력 14720 / 16000'))
              .getSemanticsData()
              .value,
          '3 콤보',
        );
        expect(find.text('92%'), findsNothing);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'boss defeat is distinct from losing lives and replay restores health',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final game = await pumpPinballApp(tester, pauseGame: true);
        addTearDown(() => disposePinballScenario(tester));
        game.hud.value = const PinballSnapshot(
          score: 16000,
          lives: 2,
          launchCharge: 0,
          status: '정원 정화 완료',
          gameOver: false,
          bossHealth: 0,
          bossDefeated: true,
          combo: 13,
        );
        await tester.pump();
        expect(_comboText('격파'), findsOneWidget);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('츠키비나 남은 체력 0 / 16000'))
              .getSemanticsData()
              .value,
          '13 콤보, 격파',
        );
        expect(
          tester
              .widget<HealthBar>(
                find.byKey(const ValueKey('pinball-boss-health')),
              )
              .value,
          0,
        );
        await tester.tap(find.byKey(const ValueKey('pinball-restart')));
        await tester.pump();
        expect(game.hud.value.bossHealth, 16000);
        expect(game.hud.value.bossDefeated, isFalse);
        expect(_comboText('0'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );
}

Finder _comboText(String text) => find.descendant(
  of: find.byKey(const ValueKey('pinball-combo')),
  matching: find.text(text),
);
