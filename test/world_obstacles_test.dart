import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/main.dart';
import 'package:mon_pinball/pinball_game.dart';
import 'package:mon_pinball/pinball_progress.dart';
import 'package:mon_pinball/world_obstacles.dart';

import 'support/pinball_test_harness.dart';

void main() {
  configurePinballTestBinding();

  testWidgets('neon electrode redirects a ball in the open midfield', (
    tester,
  ) async {
    final game = await loadWorld(tester, PinballWorld.neon);
    final ball = placeBall(game, Vector2(12, 26.8), Vector2(0, 20));
    for (var frame = 0; frame < 12; frame++) {
      game.stepEngine();
    }
    expect(ball.body.linearVelocity.y, lessThan(0));
    expect(ball.position.y, lessThan(28.8));
  });

  testWidgets('abyss stone sluice redirects a descending side-lane ball', (
    tester,
  ) async {
    final game = await loadWorld(tester, PinballWorld.abyss);
    final ball = placeBall(game, Vector2(6.5, 25.5), Vector2(0, 14));
    for (var frame = 0; frame < 8; frame++) {
      game.stepEngine();
    }
    expect(ball.body.linearVelocity.y, lessThan(0));
    expect(ball.position.y, lessThan(26.6));
  });

  for (final (world, health, hits, exposure) in [
    (PinballWorld.garden, 6400, 3, 5.0),
    (PinballWorld.neon, 8000, 4, 4.25),
    (PinballWorld.abyss, 9600, 4, 3.6),
  ]) {
    testWidgets('$world applies its boss health and shield challenge', (
      tester,
    ) async {
      final game = await loadWorld(tester, world);
      game.releaseLauncher();
      expect(game.boss.maxHealth, health);
      for (var hit = 0; hit < hits - 1; hit++) {
        game.boss.chargeShield();
      }
      expect(game.boss.exposureRemaining, 0);
      game.boss.chargeShield();
      expect(game.boss.exposureRemaining, closeTo(exposure, 0.0001));
    });
  }

  testWidgets(
    'abyss warns before both physical gates close and leaves center open',
    (tester) async {
      final game = await loadWorld(tester, PinballWorld.abyss);
      game.releaseLauncher();
      final gates = game.world.children.whereType<EncounterLaneGate>().toList();
      expect(gates, hasLength(2));
      for (var hit = 0; hit < game.boss.requiredShieldHits; hit++) {
        game.boss.chargeShield();
      }
      while (game.boss.phase == 1) {
        game.boss.takeHit(
          game.boss.position,
          game.boss.position + Vector2(5, 0),
        );
      }
      game.boss.update(3.6 + 6.3 - 1.8 + 0.05);
      game.stepEngine(stepTime: 0);
      expect(game.boss.attackWarningProgress, greaterThan(0));
      expect(gates.every((gate) => gate.body.fixtures.single.isSensor), isTrue);
      game.boss.update(0.9);
      game.stepEngine(stepTime: 0);
      expect(
        gates.every((gate) => !gate.body.fixtures.single.isSensor),
        isTrue,
      );
      for (final gate in gates) {
        final ball = placeBall(
          game,
          gate.position - Vector2(0, 1.1),
          Vector2(0, 14),
        );
        for (var frame = 0; frame < 3; frame++) {
          game.stepEngine();
        }
        expect(ball.body.linearVelocity.y, lessThan(0));
      }
      final ball = placeBall(game, Vector2(14, 32.3), Vector2(0, 10));
      for (var frame = 0; frame < 7; frame++) {
        game.stepEngine();
      }
      expect(ball.position.y, greaterThan(33.4));
      expect(ball.body.linearVelocity.y, greaterThan(0));
    },
  );

  for (final world in PinballWorld.values) {
    testWidgets('$world enables only its own moving devices', (tester) async {
      final game = await loadWorld(tester, world);
      final electrode = game.world.children.whereType<NeonElectrode>().single;
      final sluices = game.world.children.whereType<AbyssSluice>();
      expect(electrode.body.isActive, world == PinballWorld.neon);
      expect(
        sluices.every((gate) => gate.body.isActive),
        world == PinballWorld.abyss,
      );
      if (world != PinballWorld.neon) {
        final ball = placeBall(game, Vector2(14, 26.8), Vector2(0, 10));
        for (var frame = 0; frame < 20; frame++) {
          game.stepEngine();
        }
        expect(ball.position.y, greaterThan(30));
        expect(ball.body.linearVelocity.y, greaterThan(0));
      }
      if (world == PinballWorld.abyss) {
        expect(
          game.world.children.whereType<Spinner>().every(
            (bar) => !bar.body.isActive,
          ),
          isTrue,
        );
        expect(
          game.world.children
              .whereType<Bumper>()
              .where((bumper) => bumper.style == BumperStyle.post)
              .every((post) => !post.body.isActive),
          isTrue,
        );
      }
    });
  }

  testWidgets(
    'abyss sluices keep central and wall channels clear throughout travel',
    (tester) async {
      final game = await loadWorld(tester, PinballWorld.abyss);
      final sluices = game.world.children.whereType<AbyssSluice>().toList();
      for (var frame = 0; frame < 5 * 60; frame++) {
        game.stepEngine();
        for (final sluice in sluices) {
          final x = sluice.position.x;
          expect(
            x,
            inInclusiveRange(
              sluice.right ? 20.19 : 5.69,
              sluice.right ? 21.81 : 7.31,
            ),
          );
          expect(
            (x - 14).abs() - AbyssSluice.halfWidth,
            greaterThan(PinballBall.radius * 2),
          );
          final outerGap = sluice.right
              ? 24.4 - x - AbyssSluice.halfWidth
              : x - AbyssSluice.halfWidth - 3;
          expect(outerGap, greaterThan(PinballBall.radius * 2));
          expect(sluice.body.linearVelocity.length, lessThan(1.1));
        }
      }
    },
  );

  for (final world in [PinballWorld.neon, PinballWorld.abyss]) {
    testWidgets(
      '$world relocated jewels still award their physical mission hits',
      (tester) async {
        final game = await loadWorld(tester, world);
        final jewels = game.world.children
            .whereType<Bumper>()
            .where((bumper) => bumper.missionId != null)
            .toList();
        for (final jewel in jewels) {
          final previousScore = game.hud.value.score;
          final ball = placeBall(
            game,
            jewel.bumperCenter - Vector2(0, 3.2),
            Vector2(0, 14),
          );
          for (
            var frame = 0;
            frame < 8 && game.hud.value.score == previousScore;
            frame++
          ) {
            game.stepEngine();
          }
          expect(game.hud.value.score, previousScore + jewel.points * 20);
          expect(ball.body.linearVelocity.y, lessThan(0));
          expect(
            jewel.position.distanceTo(
              game.findMissionHitPosition(jewel.missionId!),
            ),
            lessThan(0.001),
          );
        }
      },
    );
  }

  testWidgets(
    'clearing garden and neon bosses selects devices on the same table',
    (tester) async {
      final game = await loadWorld(
        tester,
        PinballWorld.garden,
        configuration: const RunConfiguration(stageIndex: 2),
      );
      final ball = game.world.children.whereType<PinballBall>().single;
      final leftFlipper = game.world.children.whereType<Flipper>().first;
      for (final destination in [PinballWorld.neon, PinballWorld.abyss]) {
        if (game.configuration!.stage.goal == StageGoal.score) {
          game.addScore(
            1000000,
            Vector2(14, 33),
            const Color(0xFFFFFFFF),
            'test',
          );
          game.stepEngine(stepTime: 0);
          game.advanceStage();
        }
        if (game.configuration!.stage.goal == StageGoal.combo) {
          for (var hit = 0; hit < 12; hit++) {
            game.addScore(1, Vector2(14, 33), const Color(0xFFFFFFFF), 'test');
          }
          game.stepEngine(stepTime: 0);
          game.advanceStage();
        }
        game.releaseLauncher();
        for (var hit = 0; hit < game.boss.requiredShieldHits; hit++) {
          game.boss.chargeShield();
        }
        while (game.boss.health > game.boss.hitDamage) {
          game.boss.takeHit(
            game.boss.position,
            game.boss.position + Vector2(5, 0),
          );
        }
        placeBall(game, game.boss.position, Vector2.zero());
        game.stepEngine(stepTime: 0);
        expect(game.stageCleared, isTrue);
        game.advanceStage();
        await tester.pump(const Duration(milliseconds: 16));
        game.pauseEngine();
        expect(game.currentWorld, destination);
        expect(game.world.children.whereType<PinballBall>().single, same(ball));
        expect(
          game.world.children.whereType<Flipper>().first,
          same(leftFlipper),
        );
        expect(ball.body.bodyType, BodyType.static);
        expect(
          game.world.children.whereType<NeonElectrode>().single.body.isActive,
          destination == PinballWorld.neon,
        );
        expect(
          game.world.children.whereType<AbyssSluice>().every(
            (gate) => gate.body.isActive,
          ),
          destination == PinballWorld.abyss,
        );
      }
    },
  );

  for (final world in [PinballWorld.neon, PinballWorld.abyss]) {
    for (final framesPerSecond in [60, 30, 15]) {
      testWidgets(
        '$world full launch reaches playfield at $framesPerSecond frames per second',
        (tester) async {
          final game = await loadWorld(tester, world);
          game.world.gravity = Vector2(0, 36);
          final ball = game.world.children.whereType<PinballBall>().single;
          ball.body.linearDamping = 0.08;
          game.setLauncherDragCharge(1);
          game.releaseLauncher();
          var enteredPlayfield = false;
          for (var frame = 0; frame < framesPerSecond * 5; frame++) {
            game.stepEngine(stepTime: 1 / framesPerSecond);
            if (ball.position.x < 18 && ball.position.y < 12) {
              enteredPlayfield = true;
              break;
            }
          }
          expect(enteredPlayfield, isTrue);
        },
      );
    }
  }
}

Future<MonPinballGame> loadWorld(
  WidgetTester tester,
  PinballWorld world, {
  RunConfiguration? configuration,
}) async {
  await preparePinballTestSurface(tester);
  final game = MonPinballGame(
    configuration:
        configuration ??
        RunConfiguration(mode: PinballMode.arcade, world: world),
  );
  currentPinballGame = game;
  await loadPinballGameArt(tester, game);
  await tester.pumpWidget(MonPinballApp(gameFactory: () => game));
  await tester.pump();
  await tester.runAsync(() => game.loaded);
  await tester.pump(const Duration(milliseconds: 16));
  game.pauseEngine();
  game.world.gravity = Vector2.zero();
  final ball = game.world.children.whereType<PinballBall>().single;
  ball.body.linearDamping = 0;
  addTearDown(() => disposePinballScenario(tester));
  return game;
}

PinballBall placeBall(MonPinballGame game, Vector2 at, Vector2 velocity) {
  final ball = game.world.children.whereType<PinballBall>().single;
  ball.body.setType(BodyType.dynamic);
  ball.body.setTransform(at, 0);
  ball.body.linearVelocity = velocity;
  ball.body.angularVelocity = 0;
  return ball;
}
