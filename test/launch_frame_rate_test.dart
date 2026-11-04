import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/main.dart';
import 'package:mon_pinball/pinball_game.dart';
import 'package:mon_pinball/pinball_progress.dart';

import 'support/pinball_test_harness.dart';

void main() {
  configurePinballTestBinding();

  for (final fps in [120, 90, 60, 30, 20, 15]) {
    testWidgets(
      'configured full launch enters playfield at $fps frames per second',
      (tester) async {
        final game = await loadGame(tester);
        final ball = game.world.children.whereType<PinballBall>().single;
        game.setLauncherDragCharge(1);
        game.releaseLauncher();
        var enteredPlayfield = false;
        var minY = ball.position.y;
        var firstVelocity = 0.0;
        for (var frame = 0; frame < fps * 5; frame++) {
          game.stepEngine(stepTime: 1 / fps);
          if (frame == 0) firstVelocity = ball.body.linearVelocity.y;
          minY = math.min(minY, ball.position.y);
          if (ball.position.x < 18 && ball.position.y < 12) {
            enteredPlayfield = true;
            break;
          }
        }
        final evidence =
            'fps=$fps firstVy=$firstVelocity minY=$minY score=${game.hud.value.score} status=${game.hud.value.status}';
        expect(enteredPlayfield, isTrue, reason: evidence);
      },
    );
  }

  testWidgets('one slow first frame does not remove full launch energy', (
    tester,
  ) async {
    final game = await loadGame(tester);
    final ball = game.world.children.whereType<PinballBall>().single;
    game.setLauncherDragCharge(1);
    game.releaseLauncher();
    game.stepEngine(stepTime: 0.1);
    final firstVelocity = ball.body.linearVelocity.y;
    var minY = ball.position.y;
    var enteredPlayfield = false;
    for (var frame = 0; frame < 300; frame++) {
      game.stepEngine(stepTime: 1 / 60);
      minY = math.min(minY, ball.position.y);
      if (ball.position.x < 18 && ball.position.y < 12) {
        enteredPlayfield = true;
        break;
      }
    }
    final evidence =
        'first dt=0.1 then60fps firstVy=$firstVelocity minY=$minY score=${game.hud.value.score} status=${game.hud.value.status}';
    expect(enteredPlayfield, isTrue, reason: evidence);
  });
}

Future<MonPinballGame> loadGame(WidgetTester tester) async {
  await preparePinballTestSurface(tester);
  final game = MonPinballGame(
    configuration: const RunConfiguration(),
    progress: PinballProgress.memory(),
  );
  currentPinballGame = game;
  await loadPinballGameArt(tester, game);
  await tester.pumpWidget(MonPinballApp(gameFactory: () => game));
  await tester.pump();
  await tester.runAsync(() => game.loaded);
  await tester.pump(const Duration(milliseconds: 16));
  game.pauseEngine();
  addTearDown(() => disposePinballScenario(tester));
  return game;
}
