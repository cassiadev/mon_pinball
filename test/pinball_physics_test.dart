import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/pinball_game.dart';

import 'support/pinball_test_harness.dart';

void main() {
  configurePinballTestBinding();

  testWidgets('unlaunched ball stays in the launcher without losing lives', (
    tester,
  ) async {
    final game = await pumpPinballApp(tester, pauseGame: true);
    addTearDown(() => disposePinballScenario(tester));
    final ball = game.world.children.whereType<PinballBall>().single;

    _advancePhysics(game, 30);

    expect(game.hud.value.lives, 3);
    expect(game.hud.value.gameOver, isFalse);
    expect(ball.position.x, closeTo(25, 0.001));
    expect(ball.position.y, closeTo(43, 0.001));

    game.nudge();
    _advancePhysics(game, 5);

    expect(ball.position.y, closeTo(43, 0.001));
    expect(game.hud.value.lives, 3);
  });

  testWidgets('charging holds each new ball until launch and drain', (
    tester,
  ) async {
    final game = await pumpPinballApp(tester, pauseGame: true);
    addTearDown(() => disposePinballScenario(tester));
    final ball = game.world.children.whereType<PinballBall>().single;

    for (var remainingLives = 2; remainingLives >= 0; remainingLives--) {
      game.startLauncherCharge();
      _advancePhysics(game, 5);

      expect(game.hud.value.launchCharge, 1);
      expect(game.hud.value.lives, remainingLives + 1);
      expect(ball.position.y, closeTo(43, 0.001));

      game.setLauncherDragCharge(0.75);
      _advancePhysics(game, 5);
      expect(game.hud.value.launchCharge, 0.75);
      expect(ball.position.y, closeTo(43, 0.001));

      game.releaseLauncher();
      game.stepEngine();
      expect(game.hud.value.status, 'Launched');
      expect(ball.position.y, lessThan(43));
      expect(ball.body.linearVelocity.y, lessThan(0));

      // Send the launched ball through the drain without a random playthrough.
      ball.body.setTransform(Vector2(14, 53), 0);
      ball.body.linearVelocity = Vector2.zero();
      game.stepEngine();
      expect(game.hud.value.lives, remainingLives);
      expect(game.hud.value.gameOver, remainingLives == 0);

      _advancePhysics(game, 30);
      expect(game.hud.value.lives, remainingLives);
      expect(ball.position.y, closeTo(43, 0.001));
    }

    game.restartGame();
    _advancePhysics(game, 30);
    expect(game.hud.value.lives, 3);
    expect(game.hud.value.gameOver, isFalse);
    expect(ball.position.y, closeTo(43, 0.001));
  });

  testWidgets('restarting a moving ball restores launch waiting state', (
    tester,
  ) async {
    final game = await pumpPinballApp(tester, pauseGame: true);
    addTearDown(() => disposePinballScenario(tester));
    final ball = game.world.children.whereType<PinballBall>().single;
    game.releaseLauncher();
    _advancePhysics(game, 0.2);
    expect(ball.position.y, lessThan(43));

    game.restartGame();
    _advancePhysics(game, 30);

    expect(game.hud.value.lives, 3);
    expect(game.hud.value.status, 'Drag right plunger');
    expect(ball.position.x, closeTo(25, 0.001));
    expect(ball.position.y, closeTo(43, 0.001));

    game.releaseLauncher();
    game.stepEngine();
    expect(ball.position.y, lessThan(43));
  });
}

void _advancePhysics(MonPinballGame game, double seconds) {
  for (var frame = 0; frame < (seconds * 60).round(); frame++) {
    game.stepEngine();
  }
}
