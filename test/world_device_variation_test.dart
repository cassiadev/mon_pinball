import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/pinball_game.dart';
import 'package:mon_pinball/pinball_progress.dart';
import 'package:mon_pinball/world_devices.dart';

import 'support/pinball_test_harness.dart';
import 'world_obstacles_test.dart' show loadWorld, placeBall;

Future<void> main() async {
  await preparePinballTestEnvironment();

  for (final stage in [0, 1, 2, 3, 4, 5, 6, 7, 8]) {
    testWidgets('stage $stage introduces its authored device combination', (
      tester,
    ) async {
      final game = await loadWorld(
        tester,
        PinballWorld.garden,
        configuration: RunConfiguration(stageIndex: stage),
      );
      final flaps = game.world.children.whereType<GardenPetalFlap>();
      final lotus = game.world.children.whereType<GardenLotusScoop>().single;
      final rail = game.world.children.whereType<NeonBoostRail>().single;
      final current = game.world.children.whereType<AbyssCurrent>().single;
      expect(flaps.every((flap) => flap.body.isActive), stage < 3);
      expect(lotus.isActive, stage == 1 || stage == 2);
      expect(rail.isActive, stage == 4 || stage == 5);
      expect(current.isActive, stage == 7 || stage == 8);
      expect(
        game.world.children.whereType<Spinner>().every(
          (spinner) => !spinner.body.isActive,
        ),
        isTrue,
      );
    });
  }

  testWidgets('petal flap yields on impact and springs back without trapping', (
    tester,
  ) async {
    final game = await loadWorld(tester, PinballWorld.garden);
    final flap = game.world.children.whereType<GardenPetalFlap>().first;
    final rest = flap.body.angle;
    final ball = placeBall(
      game,
      flap.position + Vector2(1, -1.7),
      Vector2(0, 18),
    );
    var deflection = 0.0;
    for (var frame = 0; frame < 24; frame++) {
      game.stepEngine();
      deflection = (flap.body.angle - rest).abs() > deflection
          ? (flap.body.angle - rest).abs()
          : deflection;
    }
    expect(deflection, greaterThan(0.04));
    expect(deflection, lessThan(0.85));
    expect(ball.position.distanceTo(flap.position), greaterThan(1));
    ball.body.setType(BodyType.static);
    ball.body.setTransform(game.launchPosition, 0);
    for (var frame = 0; frame < 480; frame++) {
      game.stepEngine();
    }
    expect(flap.body.angle, closeTo(rest, 0.04));
  });

  testWidgets('lotus holds briefly then ejects upward and avoids recapture', (
    tester,
  ) async {
    final game = await loadWorld(tester, PinballWorld.garden);
    final lotus = game.world.children.whereType<GardenLotusScoop>().single;
    final ball = placeBall(game, Vector2(14, 28.1), Vector2(0, 10));
    game.stepEngine();
    expect(lotus.isHolding, isTrue);
    expect(ball.body.bodyType, BodyType.static);
    game.startLauncherCharge();
    game.setLauncherDragCharge(1);
    game.releaseLauncher();
    expect(ball.position.distanceTo(Vector2(14, 28.8)), lessThan(0.001));
    expect(ball.body.bodyType, BodyType.static);
    for (var frame = 0; frame < 24; frame++) {
      game.stepEngine();
    }
    expect(lotus.isHolding, isFalse);
    expect(ball.body.bodyType, BodyType.dynamic);
    expect(ball.body.linearVelocity.y, lessThan(-10));
    expect(ball.body.linearVelocity.x.abs(), greaterThan(4));
    placeBall(game, Vector2(14, 28.8), Vector2(0, 10));
    game.stepEngine();
    expect(lotus.isHolding, isFalse);
  });

  testWidgets('restart cancels a held ball without delayed teleport or shot', (
    tester,
  ) async {
    final game = await loadWorld(tester, PinballWorld.garden);
    final lotus = game.world.children.whereType<GardenLotusScoop>().single;
    final ball = placeBall(game, Vector2(14, 28.1), Vector2(0, 10));
    game.stepEngine();
    expect(lotus.isHolding, isTrue);
    game.restartGame();
    for (var frame = 0; frame < 60; frame++) {
      game.stepEngine();
    }
    expect(lotus.isHolding, isFalse);
    expect(ball.body.bodyType, BodyType.static);
    expect(ball.position.distanceTo(game.launchPosition), lessThan(0.001));
    expect(game.hud.value.score, 0);
    expect(game.hud.value.lives, 3);
  });

  testWidgets('ascending balls pass the lotus without being captured', (
    tester,
  ) async {
    final game = await loadWorld(tester, PinballWorld.garden);
    final lotus = game.world.children.whereType<GardenLotusScoop>().single;
    final ball = placeBall(game, Vector2(14, 29.5), Vector2(0, -25));
    for (var frame = 0; frame < 6; frame++) {
      game.stepEngine();
    }
    expect(lotus.isHolding, isFalse);
    expect(ball.body.bodyType, BodyType.dynamic);
    expect(ball.position.y, lessThan(28));
  });

  testWidgets(
    'pause freezes lotus hold and ball-save cancels pending release',
    (tester) async {
      final game = await loadWorld(tester, PinballWorld.garden);
      game.releaseLauncher();
      final lotus = game.world.children.whereType<GardenLotusScoop>().single;
      final ball = placeBall(game, Vector2(14, 28.1), Vector2(0, 10));
      game.stepEngine();
      expect(lotus.isHolding, isTrue);
      await tester.pump(const Duration(seconds: 1));
      expect(lotus.isHolding, isTrue);
      ball.body.setType(BodyType.dynamic);
      ball.body.setTransform(Vector2(14, 62), 0);
      game.stepEngine();
      for (var frame = 0; frame < 30; frame++) {
        game.stepEngine();
      }
      expect(lotus.isHolding, isFalse);
      expect(ball.body.bodyType, BodyType.static);
      expect(ball.position.distanceTo(game.launchPosition), lessThan(0.001));
      expect(game.hud.value.lives, 3);
      expect(game.hud.value.score, 0);
    },
  );

  testWidgets('removing leaf bodies also removes their hinge anchors', (
    tester,
  ) async {
    final game = await loadWorld(tester, PinballWorld.garden);
    final physics = game.world.physicsWorld;
    final bodyCount = physics.bodies.length;
    final jointCount = physics.joints.length;
    for (final flap
        in game.world.children.whereType<GardenPetalFlap>().toList()) {
      flap.removeFromParent();
    }
    game.stepEngine();
    await tester.pump();
    expect(physics.bodies.length, bodyCount - 4);
    expect(physics.joints.length, jointCount - 2);
  });

  testWidgets('rail boosts a forward passage once with a bounded exit speed', (
    tester,
  ) async {
    final game = await loadWorld(tester, PinballWorld.neon);
    final rail = game.world.children.whereType<NeonBoostRail>().single;
    final ball = placeBall(game, Vector2(21.3, 35.8), Vector2(-6, -9));
    game.stepEngine();
    expect(ball.body.linearVelocity.y, lessThan(-20));
    expect(ball.body.linearVelocity.x, lessThan(-10));
    expect(ball.body.linearVelocity.length, lessThanOrEqualTo(60));
    final score = game.hud.value.score;
    for (var frame = 0; frame < 12; frame++) {
      ball.body.setTransform(Vector2(20.3, 34.4), 0);
      ball.body.linearVelocity = Vector2(-6, -9);
      game.stepEngine();
    }
    expect(game.hud.value.score, score);
    expect(rail.isActive, isTrue);
  });

  testWidgets('reverse rail passage receives no boost', (tester) async {
    final game = await loadWorld(tester, PinballWorld.neon);
    final ball = placeBall(game, Vector2(20.3, 34.4), Vector2(6, 9));
    game.stepEngine();
    expect(ball.body.linearVelocity.x, closeTo(6, 0.01));
    expect(ball.body.linearVelocity.y, closeTo(9, 0.01));
    expect(game.hud.value.score, 0);
  });

  testWidgets(
    'fast rail entry is detected and restart clears its passage latch',
    (tester) async {
      final game = await loadWorld(tester, PinballWorld.neon);
      final ball = placeBall(game, Vector2(22.05, 37.02), Vector2(-60, -90));
      game.stepEngine();
      expect(game.hud.value.score, 2000);
      expect(ball.body.linearVelocity.length, lessThanOrEqualTo(60.001));
      game.restartGame();
      placeBall(game, Vector2(21.3, 35.8), Vector2(-6, -9));
      game.stepEngine();
      expect(game.hud.value.score, 2000);
      expect(ball.body.linearVelocity.y, lessThan(-20));
    },
  );

  testWidgets(
    'current bends horizontally, reverses and leaves vertical escape',
    (tester) async {
      final game = await loadWorld(tester, PinballWorld.abyss);
      final ball = placeBall(game, Vector2(14, 28), Vector2(0, 8));
      game.stepEngine();
      expect(ball.body.linearVelocity.x, greaterThan(0));
      expect(ball.body.linearVelocity.y, closeTo(8, 0.01));
      for (var frame = 0; frame < 35; frame++) {
        game.stepEngine();
      }
      expect(ball.position.y, greaterThan(31.5));
      ball.body.setType(BodyType.static);
      ball.body.setTransform(game.launchPosition, 0);
      for (var frame = 0; frame < 170; frame++) {
        game.stepEngine();
      }
      placeBall(game, Vector2(14, 28), Vector2(0, 8));
      game.stepEngine();
      expect(ball.body.linearVelocity.x, lessThan(0));
      expect(ball.body.linearVelocity.y, closeTo(8, 0.01));
      expect(ball.body.linearVelocity.x.abs(), lessThan(12));
    },
  );

  testWidgets(
    'legacy game retains its original spinners and has no new devices',
    (tester) async {
      final game = await pumpPinballApp(tester, pauseGame: true);
      addTearDown(() => disposePinballScenario(tester));
      expect(game.world.children.whereType<GardenPetalFlap>(), isEmpty);
      expect(game.world.children.whereType<GardenLotusScoop>(), isEmpty);
      expect(game.world.children.whereType<NeonBoostRail>(), isEmpty);
      expect(game.world.children.whereType<AbyssCurrent>(), isEmpty);
      expect(
        game.world.children.whereType<Spinner>().every(
          (spinner) => spinner.body.isActive,
        ),
        isTrue,
      );
    },
  );
}
