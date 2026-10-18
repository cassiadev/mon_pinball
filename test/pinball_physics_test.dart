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
    expect(ball.position.distanceTo(game.launchPosition), lessThan(0.001));

    game.nudge();
    _advancePhysics(game, 5);

    expect(ball.position.y, closeTo(game.launchPosition.y, 0.001));
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
      // The waiting ball rides the plunger head down as it is pulled.
      expect(ball.body.bodyType, BodyType.static);
      expect(
        ball.position.y,
        closeTo(game.launchPosition.y + MonPinballGame.plungerTravel, 0.001),
      );

      game.setLauncherDragCharge(0.75);
      _advancePhysics(game, 5);
      expect(game.hud.value.launchCharge, 0.75);
      expect(
        ball.position.y,
        closeTo(
          game.launchPosition.y + MonPinballGame.plungerTravel * 0.75,
          0.001,
        ),
      );

      game.releaseLauncher();
      game.stepEngine();
      expect(game.hud.value.status, 'Launched');
      expect(ball.position.y, lessThan(game.launchPosition.y));
      expect(ball.body.linearVelocity.y, lessThan(0));

      // Send the launched ball through the drain without a random playthrough.
      ball.body.setTransform(Vector2(14, MonPinballGame.boardHeight + 5), 0);
      ball.body.linearVelocity = Vector2.zero();
      game.stepEngine();
      expect(game.hud.value.lives, remainingLives);
      expect(game.hud.value.gameOver, remainingLives == 0);

      _advancePhysics(game, 30);
      expect(game.hud.value.lives, remainingLives);
      expect(ball.position.y, closeTo(game.launchPosition.y, 0.001));
    }

    game.restartGame();
    _advancePhysics(game, 30);
    expect(game.hud.value.lives, 3);
    expect(game.hud.value.gameOver, isFalse);
    expect(ball.position.y, closeTo(game.launchPosition.y, 0.001));
  });

  testWidgets('restarting a moving ball restores launch waiting state', (
    tester,
  ) async {
    final game = await pumpPinballApp(tester, pauseGame: true);
    addTearDown(() => disposePinballScenario(tester));
    final ball = game.world.children.whereType<PinballBall>().single;
    game.releaseLauncher();
    _advancePhysics(game, 0.2);
    expect(ball.position.y, lessThan(game.launchPosition.y));

    game.restartGame();
    _advancePhysics(game, 30);

    expect(game.hud.value.lives, 3);
    expect(game.hud.value.status, 'Drag right plunger');
    expect(ball.position.distanceTo(game.launchPosition), lessThan(0.001));

    game.releaseLauncher();
    game.stepEngine();
    expect(ball.position.y, lessThan(game.launchPosition.y));
  });

  for (final (label, charge) in const [('minimum', 0.0), ('full', 1.0)]) {
    testWidgets('$label launch power carries the ball into the playfield', (
      tester,
    ) async {
      final game = await pumpPinballApp(tester, pauseGame: true);
      addTearDown(() => disposePinballScenario(tester));
      final ball = game.world.children.whereType<PinballBall>().single;

      game.startLauncherCharge(timed: false);
      game.setLauncherDragCharge(charge);
      game.releaseLauncher();
      var enteredPlayfield = false;
      for (var frame = 0; frame < 120; frame++) {
        game.stepEngine();
        if (ball.position.x < 18 && ball.position.y < 12) {
          enteredPlayfield = true;
          break;
        }
      }

      expect(
        enteredPlayfield,
        isTrue,
        reason:
            'Ball must clear the inner rail, not just reach the exit sensor.',
      );
      expect(game.hud.value.lives, 3);
    });
  }

  for (final ballX in [25.65, 14.0]) {
    testWidgets('launcher cannot boost an airborne ball at x=$ballX', (
      tester,
    ) async {
      final game = await pumpPinballApp(tester, pauseGame: true);
      addTearDown(() => disposePinballScenario(tester));
      final ball = game.world.children.whereType<PinballBall>().single;
      game.releaseLauncher();
      ball.body.setTransform(Vector2(ballX, 30), 0);

      game.startLauncherCharge();
      game.stepEngine();
      expect(game.hud.value.launchCharge, 0);

      ball.body.linearVelocity = Vector2(4, 6);
      ball.body.angularVelocity = 2;
      for (var tap = 0; tap < 5; tap++) {
        final gesture = await tester.startGesture(plungerPosition(tester));
        await gesture.moveBy(const Offset(0, 80));
        await gesture.up();
      }

      expect(ball.body.linearVelocity.x, 4);
      expect(ball.body.linearVelocity.y, 6);
      expect(ball.body.angularVelocity, 2);
      expect(game.hud.value.launchCharge, 0);
      expect(game.hud.value.status, 'Launched');
    });
  }
}

void _advancePhysics(MonPinballGame game, double seconds) {
  for (var frame = 0; frame < (seconds * 60).round(); frame++) {
    game.stepEngine();
  }
}
