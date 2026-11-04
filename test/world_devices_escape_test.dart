import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/pinball_progress.dart';
import 'package:mon_pinball/world_devices.dart';

import 'support/pinball_test_harness.dart';
import 'world_obstacles_test.dart' show loadWorld, placeBall;

void main() {
  configurePinballTestBinding();
  testWidgets('both leaves release resting balls under production gravity', (
    tester,
  ) async {
    final game = await loadWorld(tester, PinballWorld.garden);
    game.world.gravity = Vector2(0, 36);
    final leaves = game.world.children.whereType<GardenPetalFlap>().toList();
    final stuck = <String>[];
    for (final leaf in leaves) {
      for (final x in [-1.8, -0.8, 0.8, 1.8]) {
        game.restartGame();
        final ball = placeBall(
          game,
          leaf.position + Vector2(x, -1.6),
          Vector2.zero(),
        );
        ball.body.linearDamping = 0.08;
        var stillFrames = 0;
        for (var frame = 0; frame < 720; frame++) {
          game.stepEngine();
          if (ball.body.bodyType == BodyType.static) {
            if (game.world.children
                .whereType<GardenLotusScoop>()
                .single
                .isHolding) {
              continue;
            }
            break;
          }
          stillFrames = ball.body.linearVelocity.length < 0.05
              ? stillFrames + 1
              : 0;
          if (stillFrames > 90) {
            stuck.add(
              '${leaf.right ? "right" : "left"} offset $x at ${ball.position}',
            );
            break;
          }
        }
      }
    }
    expect(stuck, isEmpty);
  });
}
