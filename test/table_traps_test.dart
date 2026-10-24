import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/pinball_game.dart';

import 'support/pinball_test_harness.dart';

void main() {
  configurePinballTestBinding();

  // A ball that falls back down the launch lane must land on the plunger and
  // be launchable again, wherever it travels across the lane width.
  for (final (label, offset) in const [
    ('center', 0.0),
    ('inner wall', -1.0),
    ('outer wall', 1.0),
  ]) {
    testWidgets('a ball returning along the lane $label re-arms the plunger', (
      tester,
    ) async {
      final game = await pumpPinballApp(tester, pauseGame: true);
      addTearDown(() => disposePinballScenario(tester));
      final ball = _findBall(game);
      game.releaseLauncher();

      final lane = MonPinballGame.launchLane;
      final halfRoom = lane.width / 2 - PinballBall.radius - 0.05;
      final x = lane.center.dx + offset * halfRoom;
      ball.body.setTransform(Vector2(x, lane.top + 4), 0);
      ball.body.linearVelocity = Vector2(0, 6);

      for (var frame = 0; frame < 8 * 60; frame++) {
        game.stepEngine();
        if (ball.body.bodyType == BodyType.static) break;
      }

      expect(
        game.hud.value.lives,
        3,
        reason: 'The ball fell below the spring.',
      );
      expect(ball.body.bodyType, BodyType.static);
      expect(ball.position.distanceTo(game.launchPosition), lessThan(0.001));

      game.releaseLauncher();
      game.stepEngine();
      expect(ball.body.linearVelocity.y, lessThan(0));
    });
  }

  testWidgets('no table pocket holds a resting ball away from the plunger', (
    tester,
  ) async {
    final game = await pumpPinballApp(tester, pauseGame: true);
    addTearDown(() => disposePinballScenario(tester));
    final ball = _findBall(game);
    final stuck = <String>[];

    for (var y = 3.0; y < MonPinballGame.boardHeight - 1; y += 1.5) {
      for (var x = 1.5; x < MonPinballGame.boardWidth - 1; x += 1.0) {
        game.restartGame();
        game.releaseLauncher();
        ball.body.setTransform(Vector2(x, y), 0);
        ball.body.linearVelocity = Vector2.zero();
        ball.body.angularVelocity = 0;

        var still = 0;
        var outcome = 'timeout';
        for (var frame = 0; frame < 60 * 60; frame++) {
          game.stepEngine();
          if (game.hud.value.lives < 3) {
            outcome = 'drained';
            break;
          }
          if (ball.body.bodyType == BodyType.static) {
            outcome = 're-armed';
            break;
          }
          still = ball.body.linearVelocity.length < 0.05 ? still + 1 : 0;
          if (still > 90) {
            outcome = 'stuck';
            break;
          }
        }
        if (outcome == 'stuck' || outcome == 'timeout') {
          final at = ball.position;
          stuck.add(
            '($x, $y) -> $outcome at '
            '(${at.x.toStringAsFixed(2)}, ${at.y.toStringAsFixed(2)})',
          );
        }
      }
    }

    expect(stuck, isEmpty);
  });
}

PinballBall _findBall(MonPinballGame game) =>
    game.world.children.whereType<PinballBall>().single;
