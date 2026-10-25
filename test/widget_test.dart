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

    final table = findPinballInputRect(tester);
    final score = tester.getRect(find.byKey(const ValueKey('pinball-score')));
    final status = tester.getRect(find.byKey(const ValueKey('pinball-status')));

    expect(score.bottom, lessThanOrEqualTo(table.top));
    expect(status.bottom, lessThanOrEqualTo(table.top));
    expect(find.text('다시 시작'), findsOneWidget);
    expect(
      table.width / table.height,
      closeTo(MonPinballGame.boardWidth / MonPinballGame.boardHeight, 0.001),
    );
  });

  testWidgets('portrait table fills the space under compact instruments', (
    tester,
  ) async {
    await pumpPinballApp(tester, pauseGame: true);
    addTearDown(() => disposePinballScenario(tester));

    expectCompactInstrumentsLeaveTheTable(tester);
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
      expect(findPinballInputRect(tester).height, greaterThan(200));
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

    final table = findPinballInputRect(tester);
    final score = tester.getRect(find.byKey(const ValueKey('pinball-score')));
    expect(score.left, greaterThanOrEqualTo(table.right));
    expect(game.hud.value.score, 750);

    final gesture = await tester.startGesture(findPlungerPosition(tester));
    await gesture.moveBy(const Offset(0, 50));
    await tester.pump();
    expect(game.hud.value.launchCharge, greaterThan(0));
    await gesture.up();
    await tester.pump();
    expect(game.hud.value.status, 'Launched');
    expect(tester.takeException(), isNull);
  });

  // Landscape at large text once overflowed the balls/combo and boss health
  // rows by 22 and 45 px and squeezed the health bar to nothing.
  for (final layout in const [
    (Size(568, 320), 2.0),
    (Size(568, 320), 1.5),
    (Size(1280, 800), 2.0),
    (Size(320, 568), 2.0),
    (Size(390, 844), 2.0),
  ]) {
    testWidgets(
      'instruments fit and keep a readable health bar at ${layout.$1} and '
      '${layout.$2}x text',
      (tester) async {
        await pumpPinballApp(tester, pauseGame: true);
        addTearDown(() => disposePinballScenario(tester));
        await tester.binding.setSurfaceSize(layout.$1);
        tester.platformDispatcher.textScaleFactorTestValue = layout.$2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pump();

        expect(tester.takeException(), isNull);
        final bar = tester.getSize(
          find.byKey(const ValueKey('pinball-boss-health')),
        );
        expect(bar.width, greaterThanOrEqualTo(96));
        expect(find.byKey(const ValueKey('pinball-combo')), findsOneWidget);
      },
    );
  }

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
        expect(findPinballInputRect(tester).height, greaterThanOrEqualTo(200));
        final gesture = await tester.startGesture(
          findPlayfieldPosition(tester, 'left'),
        );
        expect(game.isLeftFlipperPressed, isTrue);
        await gesture.up();
        expect(game.isLeftFlipperPressed, isFalse);
      },
    );
  }
}
