// Run natively with:
// flutter run --debug -d <physical-device> -t test/device_boss_validation.dart
// Uses isolated memory records and controlled ball/clock fixtures, not manual play.
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/journey_screen.dart';
import 'package:mon_pinball/pinball_game.dart';
import 'package:mon_pinball/pinball_progress.dart';
import 'package:mon_pinball/pinball_style.dart';

import 'support/pinball_test_harness.dart';

Future<void> main() async {
  await preparePinballTestEnvironment();
  // ignore: avoid_print
  print('DEVICE_BOSS_ENV ${configurePinballTestBinding().runtimeType}');
  for (final sample in [
    (PinballWorld.neon, 5, 2, 5.4, 3.96),
    (PinballWorld.abyss, 8, 3, 4.5, 3.24),
  ]) {
    testWidgets('${sample.$1.name}: native late attacks and stage victory', (
      tester,
    ) async {
      final progress = PinballProgress.memory();
      for (var stage = 0; stage < sample.$2; stage++) {
        await progress.recordStageClear(
          stageIndex: stage,
          difficulty: PinballDifficulty.normal,
          stars: 1,
          score: 1,
        );
      }
      final game = await loadScene(
        tester,
        RunConfiguration(stageIndex: sample.$2),
        progress,
      );
      game.releaseLauncher();
      exposeBoss(game);
      for (var hit = 0; hit < 3; hit++) {
        strikeBoss(game);
      }
      expect(game.boss.phase, 2);
      final gates = game.world.children.whereType<EncounterLaneGate>().toList();
      final left = gates.singleWhere((gate) => !gate.right);
      final right = gates.singleWhere((gate) => gate.right);
      parkBall(game);
      game.boss.update(game.boss.exposureRemaining + sample.$4 + 0.2);
      game.stepEngine(stepTime: 0);
      expect(game.boss.warnsLeftLane, isTrue);
      expect(game.boss.warnsRightLane, sample.$1 == PinballWorld.abyss);
      expect(gates.every((gate) => gate.body.fixtures.single.isSensor), isTrue);
      crossGate(game, left, blocked: false);
      await tester.pump();
      recordCheckpoint(
        '${sample.$1.name} phase2 warning: gate remains passable',
      );

      parkBall(game);
      game.boss.update(1);
      game.stepEngine(stepTime: 0);
      expect(left.body.fixtures.single.isSensor, isFalse);
      expect(
        right.body.fixtures.single.isSensor,
        sample.$1 == PinballWorld.neon,
      );
      crossGate(game, left, blocked: true);
      if (sample.$1 == PinballWorld.abyss) {
        crossGate(game, right, blocked: true);
        placeBall(game, Vector2(14, 32.3), Vector2(0, 10));
        for (var frame = 0; frame < 7; frame++) {
          game.stepEngine();
        }
        expect(findBall(game).position.y, greaterThan(33.4));
        expect(findBall(game).body.linearVelocity.y, greaterThan(0));
      }
      await tester.pump();
      recordCheckpoint(
        '${sample.$1.name} phase2 active: physical bounce verified',
      );

      exposeBoss(game);
      for (var hit = 0; hit < sample.$3; hit++) {
        strikeBoss(game);
      }
      expect(game.boss.phase, 3);
      parkBall(game);
      // Literal final-cycle starts verify the 20% interval reduction independently.
      game.boss.update(game.boss.exposureRemaining + sample.$5 + 0.2);
      game.stepEngine(stepTime: 0);
      expect(game.boss.attackWarningProgress, greaterThan(0));
      expect(gates.every((gate) => gate.body.fixtures.single.isSensor), isTrue);
      game.boss.update(1);
      game.stepEngine(stepTime: 0);
      expect(game.boss.laneSealed, isTrue);
      crossGate(game, left, blocked: true);
      await tester.pump();
      recordCheckpoint(
        '${sample.$1.name} phase3: faster warning and collision verified',
      );

      exposeBoss(game);
      strikeBoss(game);
      expect(game.boss.defeated, isFalse);
      strikeBoss(game);
      expect(game.boss.health, 0);
      expect(game.stageCleared, isTrue);
      expect(game.hud.value.lives, 3);
      expect(findBall(game).body.bodyType, BodyType.static);
      await tester.pump();
      expect(
        find.text(
          sample.$1 == PinballWorld.abyss ? '세 세계의 여정 완료!' : '스테이지 클리어!',
        ),
        findsOneWidget,
      );
      expect(progress.findStageStars(sample.$2, PinballDifficulty.normal), 3);
      for (var frame = 0; frame < 90; frame++) {
        game.stepEngine();
      }
      await tester.pump();
      expect(game.boss.vanished, isTrue);
      recordCheckpoint(
        '${sample.$1.name} defeated: victory UI, exit and stars verified',
      );
      if (sample.$1 == PinballWorld.neon) {
        await tester.tap(find.text('다음 스테이지'));
        await tester.pump();
        expect(game.configuration!.stageIndex, 6);
        expect(game.currentWorld, PinballWorld.abyss);
        expect(game.hud.value.score, 0);
        expect(game.hud.value.lives, 3);
      }
    });
  }

  testWidgets('abyss: native arcade defeat bonus and repeat summon', (
    tester,
  ) async {
    final progress = PinballProgress.memory();
    final game = await loadScene(
      tester,
      const RunConfiguration(
        mode: PinballMode.arcade,
        world: PinballWorld.abyss,
      ),
      progress,
    );
    game.releaseLauncher();
    exposeBoss(game);
    for (var hit = 0; hit < 8; hit++) {
      strikeBoss(game);
    }
    expect(game.boss.defeated, isTrue);
    expect(game.arcadeBossesDefeated, 1);
    expect(game.hud.value.score, 59600);
    expect(game.stageCleared, isFalse);
    expect(game.hud.value.lives, 3);
    expect(
      progress.findBestArcadeScore(
        PinballWorld.abyss,
        PinballDifficulty.normal,
      ),
      59600,
    );
    for (var frame = 0; frame < 90; frame++) {
      game.stepEngine();
    }
    await tester.pump();
    expect(game.boss.health, 9600);
    expect(game.boss.active, isTrue);
    expect(game.arcadeBossesDefeated, 1);
    expect(game.hud.value.score, 59600);
    expect(game.hud.value.lives, 3);
    recordCheckpoint('abyss arcade: +50000, record and next boss verified');
  });
}

Future<MonPinballGame> loadScene(
  WidgetTester tester,
  RunConfiguration configuration,
  PinballProgress progress,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: PinballStyle.cyan,
          brightness: Brightness.dark,
          surface: PinballStyle.panel,
        ),
        fontFamily: 'IBMPlexMono',
        fontFamilyFallback: const ['sans-serif'],
      ),
      home: JourneyPlayScreen(configuration: configuration, progress: progress),
    ),
  );
  await tester.pump();
  final game = tester
      .widget<GameWidget<MonPinballGame>>(
        find.byType(GameWidget<MonPinballGame>),
      )
      .game!;
  currentPinballGame = game;
  await tester.runAsync(() => game.loaded);
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  game.pauseEngine();
  game.world.gravity = Vector2.zero();
  findBall(game).body.linearDamping = 0;
  addTearDown(() => disposePinballScenario(tester));
  return game;
}

PinballBall findBall(MonPinballGame game) =>
    game.world.children.whereType<PinballBall>().single;

void placeBall(MonPinballGame game, Vector2 position, Vector2 velocity) {
  final ball = findBall(game);
  ball.body.setTransform(position, 0);
  ball.body.linearVelocity = velocity;
}

void parkBall(MonPinballGame game) =>
    placeBall(game, Vector2(14, 50), Vector2.zero());

void exposeBoss(MonPinballGame game) {
  // Arrange the shield fixture; hits below use production game damage handling.
  for (var hit = 0; hit < game.boss.requiredShieldHits; hit++) {
    game.boss.chargeShield();
  }
  game.stepEngine(stepTime: 0);
}

void strikeBoss(MonPinballGame game) {
  placeBall(game, game.boss.position + Vector2(5, 0), Vector2.zero());
  game.stepEngine(stepTime: 0);
  placeBall(game, game.boss.position, Vector2.zero());
  game.stepEngine(stepTime: 0);
}

void crossGate(
  MonPinballGame game,
  EncounterLaneGate gate, {
  required bool blocked,
}) {
  placeBall(game, gate.position - Vector2(0, 1.1), Vector2(0, 14));
  for (var frame = 0; frame < 3; frame++) {
    game.stepEngine();
  }
  expect(
    findBall(game).body.linearVelocity.y,
    blocked ? lessThan(0) : greaterThan(0),
  );
}

void recordCheckpoint(String message) {
  // ignore: avoid_print
  print('DEVICE_BOSS_PASS $message');
}
