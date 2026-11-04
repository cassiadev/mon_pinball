// Explicit trajectory probe, not an event-only balance result.
import 'dart:convert';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/pinball_progress.dart';
import 'package:mon_pinball/world_devices.dart';
import 'world_obstacles_test.dart' show loadWorld, placeBall;
import 'support/pinball_test_harness.dart';

void main() {
  configurePinballTestBinding();
  testWidgets('probe release trajectories against the real garden obstacles', (
    tester,
  ) async {
    final game = await loadWorld(tester, PinballWorld.garden);
    game.world.gravity = Vector2(0, 36);
    final results = <Map<String, dynamic>>[];
    for (final vx in [8, 12, 14, 18, 22, 26, 30]) {
      for (final vy in [35, 40, 45, 50, 55, 60, 65]) {
        game.restartGame();
        for (var i = 0; i < 30; i++) {
          game.stepEngine();
        }
        game.restartGame();
        final ball = placeBall(
          game,
          Vector2(14, 28.8),
          Vector2(-vx.toDouble(), -vy.toDouble()),
        );
        ball.body.linearDamping = 0.08;
        var minY = ball.position.y;
        for (var frame = 0; frame < 90; frame++) {
          game.stepEngine();
          if (ball.position.y < minY) minY = ball.position.y;
          if (game.world.children
              .whereType<GardenLotusScoop>()
              .single
              .isHolding) {
            break;
          }
        }
        results.add({'vx': vx, 'vy': vy, 'minY': minY});
      }
    }
    // ignore: avoid_print
    print('LOTUS_PROBE ${jsonEncode(results)}');
  });
}
