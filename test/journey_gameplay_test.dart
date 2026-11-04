import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/main.dart';
import 'package:mon_pinball/pinball_game.dart';
import 'package:mon_pinball/pinball_progress.dart';

import 'support/pinball_test_harness.dart';

void main() {
  configurePinballTestBinding();

  test('restart requested before art loads leaves a usable initial run', () {
    final game = MonPinballGame(configuration: const RunConfiguration());
    expect(game.restartGame, returnsNormally);
    expect(game.hud.value.gameOver, isFalse);
  });

  Future<MonPinballGame> load(
    WidgetTester tester, {
    RunConfiguration configuration = const RunConfiguration(),
  }) async {
    await preparePinballTestSurface(tester);
    final game = MonPinballGame(
      configuration: configuration,
      progress: PinballProgress.memory(),
    );
    currentPinballGame = game;
    await loadPinballGameArt(tester, game);
    await tester.pumpWidget(MonPinballApp(gameFactory: () => game));
    await tester.pump();
    await tester.runAsync(() => game.loaded);
    await tester.pump(const Duration(milliseconds: 16));
    game.pauseEngine();
    game.world.gravity = Vector2.zero();
    addTearDown(() => disposePinballScenario(tester));
    return game;
  }

  testWidgets(
    'score mission clears and next stage resets its balls and score',
    (tester) async {
      final game = await load(tester);
      game.releaseLauncher();
      expect(game.boss.active, isFalse);
      for (var hit = 0; hit < 20; hit++) {
        game.addScore(
          250,
          Vector2(9.6, 13.7),
          const Color(0xFFFFFFFF),
          'bumper',
        );
      }
      game.stepEngine(stepTime: 0);
      expect(game.stageCleared, isTrue);
      expect(game.stageStars, 3);
      expect(game.progress!.isStageUnlocked(1), isTrue);
      game.advanceStage();
      expect(game.configuration!.stageIndex, 1);
      expect(game.hud.value.score, 0);
      expect(game.hud.value.lives, 3);
      expect(game.stageCleared, isFalse);
    },
  );

  testWidgets('easy ball save prevents one early drain but expires', (
    tester,
  ) async {
    final game = await load(
      tester,
      configuration: const RunConfiguration(difficulty: PinballDifficulty.easy),
    );
    expect(game.hud.value.lives, 5);
    game.releaseLauncher();
    final ball = game.world.children.whereType<PinballBall>().single;
    ball.body.setTransform(Vector2(14, 62), 0);
    game.stepEngine(stepTime: 0);
    expect(game.hud.value.lives, 5);
    expect(game.hud.value.status, contains('세이브'));
    game.releaseLauncher();
    ball.body.setTransform(Vector2(14, 58), 0);
    ball.body.linearVelocity = Vector2.zero();
    for (var frame = 0; frame < 13 * 60; frame++) {
      game.stepEngine();
    }
    ball.body.setTransform(Vector2(14, 62), 0);
    game.stepEngine(stepTime: 0);
    expect(game.hud.value.lives, 4);
  });

  testWidgets('arcade boss bonus keeps balls and continues the same run', (
    tester,
  ) async {
    final game = await load(
      tester,
      configuration: const RunConfiguration(mode: PinballMode.arcade),
    );
    game.releaseLauncher();
    final ball = game.world.children.whereType<PinballBall>().single;
    for (var hit = 0; hit < 3; hit++) {
      game.boss.chargeShield();
    }
    for (var hit = 0; hit < 5; hit++) {
      ball.body.setTransform(game.boss.position + Vector2(5, 0), 0);
      ball.body.linearVelocity = Vector2.zero();
      game.stepEngine(stepTime: 0);
      ball.body.setTransform(game.boss.position, 0);
      game.stepEngine(stepTime: 0);
    }
    expect(game.hud.value.score, greaterThanOrEqualTo(50000));
    expect(game.hud.value.lives, 3);
    expect(game.hud.value.gameOver, isFalse);
    expect(game.stageCleared, isFalse);
    for (var frame = 0; frame < 2 * 60; frame++) {
      game.stepEngine();
    }
    expect(game.boss.defeated, isFalse);
    expect(game.boss.active, isTrue);
  });

  testWidgets('a boss hit completing ten combos earns the same combo bonus', (
    tester,
  ) async {
    final game = await load(
      tester,
      configuration: const RunConfiguration(mode: PinballMode.arcade),
    );
    game.releaseLauncher();
    for (var hit = 0; hit < 9; hit++) {
      game.addScore(100, Vector2(14, 30), const Color(0xFFFFFFFF), 'bumper');
    }
    for (var hit = 0; hit < 3; hit++) {
      game.boss.chargeShield();
    }
    final ball = game.world.children.whereType<PinballBall>().single;
    ball.body.setTransform(game.boss.position, 0);
    ball.body.linearVelocity = Vector2.zero();
    game.stepEngine(stepTime: 0);
    expect(game.hud.value.combo, 10);
    expect(game.hud.value.score, 29280);
  });
}
