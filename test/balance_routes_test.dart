import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/pinball_progress.dart';
import 'package:mon_pinball/world_devices.dart';

import 'support/balance_simulation.dart';
import 'support/pinball_test_harness.dart';
import 'world_obstacles_test.dart' show loadWorld, placeBall;

void main() {
  configurePinballTestBinding();

  testWidgets(
    'easy abyss allows a full natural-play victory within the trial window',
    (tester) async {
      final game = await loadBalanceGame(
        tester,
        const RunConfiguration(
          stageIndex: 8,
          difficulty: PinballDifficulty.easy,
        ),
      );
      final result = await runBalanceEpisode(
        game,
        policy: BalancePolicy.reactive,
        seed: 1009,
        maxSeconds: 180,
      );
      expect(result.outcome, 'cleared');
      expect(result.nudges, 0);
    },
  );

  testWidgets('neon combo challenge outlasts the automatic launch rally', (
    tester,
  ) async {
    final game = await loadBalanceGame(
      tester,
      const RunConfiguration(stageIndex: 4),
    );
    final result = await runBalanceEpisode(
      game,
      policy: BalancePolicy.launchOnly,
      seed: 1009,
      maxSeconds: 10,
    );
    expect(result.outcome, 'timeout');
    expect(game.stageCleared, isFalse);
  });

  testWidgets(
    'lotus ejects a caught ball high enough to reach the upper field',
    (tester) async {
      final game = await loadWorld(tester, PinballWorld.garden);
      game.world.gravity = Vector2(0, 36);
      final lotus = game.world.children.whereType<GardenLotusScoop>().single;
      final ball = placeBall(game, Vector2(14, 28.1), Vector2(0, 10));
      ball.body.linearDamping = 0.08;
      game.stepEngine();
      expect(lotus.isHolding, isTrue);
      for (var frame = 0; frame < 19; frame++) {
        game.stepEngine();
      }
      expect(lotus.isHolding, isFalse);
      var minimumY = ball.position.y;
      for (var frame = 0; frame < 72; frame++) {
        game.stepEngine();
        if (ball.position.y < minimumY) minimumY = ball.position.y;
      }
      expect(minimumY, lessThan(14));
    },
  );

  testWidgets(
    'abyss central return reaches the current without a moon ricochet',
    (tester) async {
      final game = await loadWorld(tester, PinballWorld.abyss);
      game.world.gravity = Vector2(0, 36);
      final ball = placeBall(game, Vector2(14, 41), Vector2(0, -40));
      ball.body.linearDamping = 0.08;
      var crossed = false;
      for (var frame = 0; frame < 30; frame++) {
        game.stepEngine();
        if (ball.position.y < 31.5) {
          crossed = true;
          break;
        }
      }
      expect(crossed, isTrue);
    },
  );

  testWidgets('lotus rightward release also reaches the upper field', (
    tester,
  ) async {
    final game = await loadWorld(tester, PinballWorld.garden);
    game.world.gravity = Vector2(0, 36);
    final ball = placeBall(game, Vector2(13.8, 28.1), Vector2(0, 10));
    ball.body.linearDamping = 0.08;
    game.stepEngine();
    for (var frame = 0; frame < 19; frame++) {
      game.stepEngine();
    }
    expect(ball.body.linearVelocity.x, greaterThan(0));
    var minimumY = ball.position.y;
    for (var frame = 0; frame < 72; frame++) {
      game.stepEngine();
      if (ball.position.y < minimumY) minimumY = ball.position.y;
    }
    expect(minimumY, lessThan(14));
  });

  testWidgets(
    'abyss relocated moon leaves no resting trap above required targets',
    (tester) async {
      final game = await loadWorld(tester, PinballWorld.abyss);
      game.world.gravity = Vector2(0, 36);
      for (final at in [
        Vector2(9.9, 39.5),
        Vector2(11, 39.8),
        Vector2(13.4, 36.8),
        Vector2(8.5, 34.5),
      ]) {
        game.restartGame();
        final ball = placeBall(game, at, Vector2.zero());
        ball.body.linearDamping = 0.08;
        var still = 0;
        for (var frame = 0; frame < 600; frame++) {
          game.stepEngine();
          if (ball.body.bodyType == BodyType.static) break;
          still = ball.body.linearVelocity.length < 0.05 ? still + 1 : 0;
          expect(still, lessThan(90), reason: 'Resting at $at');
        }
      }
    },
  );
}
