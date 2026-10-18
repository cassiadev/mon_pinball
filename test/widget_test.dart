import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/pinball_game.dart';

import 'support/pinball_test_harness.dart';

void main() {
  setUpAll(loadPinballTestFont);

  testWidgets('pinball app renders HUD', (WidgetTester tester) async {
    await pumpPinballApp(tester, pauseGame: true);
    addTearDown(() => disposePinballScenario(tester));

    expect(find.text('MON PINBALL'), findsOneWidget);
    expect(find.byKey(const ValueKey('pinball-lives')), findsOneWidget);
  });

  testWidgets('portrait instruments leave the whole table unobscured', (
    tester,
  ) async {
    await pumpPinballApp(tester, pauseGame: true);
    addTearDown(() => disposePinballScenario(tester));

    final table = pinballInputRect(tester);
    final score = tester.getRect(find.byKey(const ValueKey('pinball-score')));
    final status = tester.getRect(find.byKey(const ValueKey('pinball-status')));

    expect(score.bottom, lessThanOrEqualTo(table.top));
    // The live status sits on its own line under the table, as in the mockup.
    expect(status.top, greaterThanOrEqualTo(table.bottom));
    expect(find.text('다시 시작'), findsOneWidget);
    expect(
      table.width / table.height,
      closeTo(MonPinballGame.boardWidth / MonPinballGame.boardHeight, 0.001),
    );
  });

  testWidgets('portrait table fills the available width', (tester) async {
    await pumpPinballApp(tester, pauseGame: true);
    addTearDown(() => disposePinballScenario(tester));

    expect(pinballInputRect(tester).width, greaterThanOrEqualTo(350));
  });

  testWidgets('narrow instruments show full status and an eight digit score', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final game = await pumpPinballApp(tester, pauseGame: true);
      addTearDown(() => disposePinballScenario(tester));
      await tester.binding.setSurfaceSize(const Size(320, 740));
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      game.hud.value = const PinballSnapshot(
        score: 12345678,
        lives: 0,
        launchCharge: 0,
        status: 'Game over - tap launch or R',
        gameOver: true,
      );
      await tester.pump();

      final status = tester.renderObject<RenderParagraph>(
        find.byKey(const ValueKey('pinball-status')),
      );
      expect(status.didExceedMaxLines, isFalse);
      expect(find.bySemanticsLabel('점수 12345678점'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(pinballInputRect(tester).height, greaterThan(200));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('wide instruments preserve the game and local launcher input', (
    tester,
  ) async {
    final game = await pumpPinballApp(tester, pauseGame: true);
    addTearDown(() => disposePinballScenario(tester));
    addTestScore(750);
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pump();

    final table = pinballInputRect(tester);
    final score = tester.getRect(find.byKey(const ValueKey('pinball-score')));
    expect(score.left, greaterThanOrEqualTo(table.right));
    expect(game.hud.value.score, 750);

    final gesture = await tester.startGesture(plungerPosition(tester));
    await gesture.moveBy(const Offset(0, 50));
    await tester.pump();
    expect(game.hud.value.launchCharge, greaterThan(0));
    await gesture.up();
    await tester.pump();
    expect(game.hud.value.status, 'Launched');
    expect(tester.takeException(), isNull);
  });

  for (final layout in const [(Size(568, 320), 1.0), (Size(320, 568), 2.0)]) {
    testWidgets(
      'keeps the table usable at ${layout.$1} and ${layout.$2}x text',
      (tester) async {
        final game = await pumpPinballApp(tester, pauseGame: true);
        addTearDown(() => disposePinballScenario(tester));
        await tester.binding.setSurfaceSize(layout.$1);
        tester.platformDispatcher.textScaleFactorTestValue = layout.$2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(pinballInputRect(tester).height, greaterThanOrEqualTo(200));
        final gesture = await tester.startGesture(
          playfieldPosition(tester, 'left'),
        );
        expect(game.isLeftFlipperPressed, isTrue);
        await gesture.up();
        expect(game.isLeftFlipperPressed, isFalse);
      },
    );
  }
}
