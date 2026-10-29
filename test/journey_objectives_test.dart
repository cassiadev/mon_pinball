import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/boss_encounter.dart';
import 'package:mon_pinball/main.dart';
import 'package:mon_pinball/pinball_game.dart';
import 'package:mon_pinball/pinball_progress.dart';

import 'support/pinball_test_harness.dart';

void main() {
  configurePinballTestBinding();

  Future<MonPinballGame> load(
    WidgetTester tester, {
    RunConfiguration? configuration,
  }) async {
    await preparePinballTestSurface(tester);
    final game = MonPinballGame(configuration: configuration);
    currentPinballGame = game;
    await loadPinballGameArt(tester, game);
    await tester.pumpWidget(MonPinballApp(gameFactory: () => game));
    await tester.pump();
    await tester.runAsync(() => game.loaded);
    await tester.pump(const Duration(milliseconds: 16));
    game.pauseEngine();
    game.world.gravity = Vector2.zero();
    findBall(game).body.linearDamping = 0;
    addTearDown(() => disposePinballScenario(tester));
    return game;
  }

  testWidgets('bloom needs three distinct jewels before a gate visit clears', (
    tester,
  ) async {
    final game = await load(
      tester,
      configuration: const RunConfiguration(stageIndex: 1),
    );
    game.releaseLauncher();
    placeBall(game, Vector2(14, 4));
    game.stepEngine(stepTime: 0);
    expect(game.stageCleared, isFalse);

    for (var hit = 0; hit < 4; hit++) {
      scoreHit(game, 'jewel-left');
    }
    scoreHit(game, 'target-0');
    expect(game.missionProgress, closeTo(1 / 3, 0.0001));
    expect(game.gateArmed, isFalse);
    scoreHit(game, 'jewel-right');
    expect(game.gateArmed, isFalse);
    scoreHit(game, 'jewel-center');
    expect(game.gateArmed, isTrue);
    expect(game.stageCleared, isFalse);
    expect(game.boss.active, isFalse);
    game.stepEngine(stepTime: 0);
    expect(game.stageCleared, isTrue);
    expect(findBall(game).body.bodyType, BodyType.static);

    final clearedScore = game.hud.value.score;
    scoreHit(game, 'jewel-left');
    game.releaseLauncher();
    expect(game.hud.value.score, clearedScore);
    expect(findBall(game).body.bodyType, BodyType.static);
  });

  testWidgets('abyss needs four distinct targets and a moving gate crossing', (
    tester,
  ) async {
    final game = await load(
      tester,
      configuration: const RunConfiguration(stageIndex: 7),
    );
    game.releaseLauncher();
    for (var hit = 0; hit < 4; hit++) {
      scoreHit(game, 'target-0');
    }
    scoreHit(game, 'jewel-left');
    expect(game.missionProgress, 0.25);
    for (final id in ['target-1', 'target-2']) {
      scoreHit(game, id);
    }
    expect(game.gateArmed, isFalse);
    scoreHit(game, 'target-3');
    expect(game.gateArmed, isTrue);
    expect(game.stageCleared, isFalse);

    placeBall(game, Vector2(10, 4), velocity: Vector2(80, 0));
    for (var frame = 0; frame < 8 && !game.stageCleared; frame++) {
      game.stepEngine();
    }
    expect(game.stageCleared, isTrue);
    expect(game.currentWorld, PinballWorld.abyss);
    expect(game.hud.value.lives, 3);
  });

  testWidgets('physical jewel contacts light their distinct mission ids', (
    tester,
  ) async {
    final game = await load(
      tester,
      configuration: const RunConfiguration(stageIndex: 1),
    );
    game.releaseLauncher();
    final jewels = game.world.children
        .whereType<Bumper>()
        .where((bumper) => bumper.style == BumperStyle.jewel)
        .toList();
    expect(jewels, hasLength(3));
    final expectedIds = ['jewel-left', 'jewel-right', 'jewel-center'];
    for (var index = 0; index < jewels.length; index++) {
      final jewel = jewels[index];
      final id = expectedIds[index];
      final previousScore = game.hud.value.score;
      placeBall(
        game,
        jewel.bumperCenter -
            Vector2(0, jewel.radius + PinballBall.radius + 0.3),
        velocity: Vector2(0, 20),
      );
      for (var frame = 0; frame < 30 && !game.isMissionHitLit(id); frame++) {
        game.stepEngine();
      }
      expect(game.isMissionHitLit(id), isTrue, reason: id);
      expect(game.hud.value.score - previousScore, jewel.points * 20);
      expect(findBall(game).body.linearVelocity.y, lessThan(0));
    }
    expect(game.missionProgress, 1);
    expect(game.gateArmed, isTrue);
    expect(game.stageCleared, isFalse);
  });

  testWidgets('neon combo objective resets on a drain before a later clear', (
    tester,
  ) async {
    final game = await load(
      tester,
      configuration: const RunConfiguration(stageIndex: 4),
    );
    game.releaseLauncher();
    // This is a neutral wait between objectives, outside the neon rotor sweep.
    placeBall(game, Vector2(14, 33.25));
    for (var hit = 0; hit < 59; hit++) {
      scoreHit(game, 'target-0');
    }
    expect(game.stageCleared, isFalse);
    expect(game.hud.value.combo, 59);
    for (var frame = 0; frame < 8 * 60; frame++) {
      game.stepEngine();
    }
    placeBall(game, Vector2(14, 62));
    game.stepEngine(stepTime: 0);
    expect(game.hud.value.combo, 0);
    expect(game.hud.value.lives, 2);
    expect(game.stageCleared, isFalse);

    game.releaseLauncher();
    for (var hit = 0; hit < 60; hit++) {
      scoreHit(game, 'target-0');
    }
    game.stepEngine(stepTime: 0);
    expect(game.stageCleared, isTrue);
    expect(game.stageStars, 2);
    expect(game.hud.value.combo, 60);
  });

  testWidgets('boss launch and eligible hits control shielded damage', (
    tester,
  ) async {
    final game = await load(
      tester,
      configuration: const RunConfiguration(stageIndex: 2),
    );
    expect(game.boss.active, isFalse);
    game.releaseLauncher();
    expect(game.boss.active, isTrue);
    expect(game.boss.shieldState, BossShieldState.shielded);
    placeBall(game, game.boss.position);
    game.stepEngine(stepTime: 0);
    expect(game.boss.health, 6400);

    scoreHit(game, 'jewel-center');
    scoreHit(game, 'spinner');
    expect(game.boss.shieldCharge, 0);
    for (final id in ['jewel-left', 'target-0']) {
      scoreHit(game, id);
    }
    expect(game.boss.shieldCharge, 2);
    game.stepEngine(stepTime: 0);
    expect(game.boss.health, 6400);
    scoreHit(game, 'jewel-right');
    expect(game.boss.shieldState, BossShieldState.exposed);
    expect(game.boss.exposureRemaining, 5);
    game.stepEngine(stepTime: 0);
    expect(game.boss.health, 5120);
    expect(game.hud.value.score, 5 * 250 * 20 + 1280);
    expect(game.stageCleared, isFalse);
  });

  testWidgets('phase two attack makes the left gate solid until re-exposure', (
    tester,
  ) async {
    final game = await load(
      tester,
      configuration: const RunConfiguration(stageIndex: 2),
    );
    game.releaseLauncher();
    final gate = game.world.children.whereType<EncounterLaneGate>().single;
    final fixture = gate.body.fixtures.single;
    expect(fixture.isSensor, isTrue);
    crossLeftGate(game, gate);
    expect(findBall(game).position.y, greaterThan(gate.position.y));

    exposeBossWithTargets(game);
    for (var hit = 0; hit < 2; hit++) {
      placeBall(game, game.boss.position + Vector2(5, 0));
      game.stepEngine(stepTime: 0);
      placeBall(game, game.boss.position);
      game.stepEngine(stepTime: 0);
    }
    expect(game.boss.phase, 2);
    placeBall(game, Vector2(14, 32));
    // Five exposed seconds expire, then the nine-second cycle telegraphs at 7.2.
    for (var frame = 0; frame < 738; frame++) {
      game.stepEngine();
    }
    expect(game.boss.shieldState, BossShieldState.attacking);
    expect(game.boss.laneSealed, isTrue);
    expect(fixture.isSensor, isFalse);
    crossLeftGate(game, gate);
    expect(findBall(game).position.y, lessThan(gate.position.y));
    expect(findBall(game).body.linearVelocity.y, lessThan(0));

    exposeBossWithTargets(game);
    game.stepEngine(stepTime: 0);
    expect(game.boss.laneSealed, isFalse);
    expect(fixture.isSensor, isTrue);
    crossLeftGate(game, gate);
    expect(findBall(game).position.y, greaterThan(gate.position.y));
    expect(findBall(game).body.linearVelocity.y, greaterThan(0));
  });

  for (final sample in <(String, RunConfiguration?, int)>[
    ('stage', const RunConfiguration(stageIndex: 1), 25000),
    ('arcade', const RunConfiguration(mode: PinballMode.arcade), 25000),
    ('legacy', null, 750),
  ]) {
    testWidgets('${sample.$1} uses its own score scale and combo bonus', (
      tester,
    ) async {
      final game = await load(tester, configuration: sample.$2);
      game.releaseLauncher();
      for (var hit = 0; hit < 10; hit++) {
        game.addScore(
          75,
          Vector2(14, 32),
          const Color(0xFFFFFFFF),
          'slingshot',
        );
      }
      expect(game.hud.value.score, sample.$3);
      expect(game.hud.value.combo, 10);
      expect(game.stageCleared, isFalse);
      expect(game.gateArmed, isFalse);
      expect(game.boss.shieldCharge, 0);
    });
  }
}

PinballBall findBall(MonPinballGame game) =>
    game.world.children.whereType<PinballBall>().single;

void placeBall(MonPinballGame game, Vector2 at, {Vector2? velocity}) {
  final ball = findBall(game);
  ball.body.setTransform(at, 0);
  ball.body.linearVelocity = velocity ?? Vector2.zero();
}

void scoreHit(MonPinballGame game, String id) {
  game.addScore(
    250,
    Vector2(14, 32),
    const Color(0xFFFFFFFF),
    'target',
    hitId: id,
  );
}

void exposeBossWithTargets(MonPinballGame game) {
  for (var hit = 0; hit < game.boss.requiredShieldHits; hit++) {
    scoreHit(game, 'target-$hit');
  }
}

void crossLeftGate(MonPinballGame game, EncounterLaneGate gate) {
  placeBall(game, gate.position - Vector2(0, 1.4), velocity: Vector2(0, 20));
  for (var frame = 0; frame < 6; frame++) {
    game.stepEngine();
  }
}
