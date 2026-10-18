import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/moonlit_boss.dart';
import 'package:mon_pinball/pinball_game.dart';

import 'support/pinball_test_harness.dart';

void main() {
  configurePinballTestBinding();

  Future<MonPinballGame> load(WidgetTester tester) async {
    final game = await pumpPinballApp(tester, pauseGame: true);
    addTearDown(() => disposePinballScenario(tester));
    game.world.gravity = Vector2.zero();
    _ball(game).body.linearDamping = 0;
    return game;
  }

  testWidgets('waiting and charging render the boss without starting attacks', (
    tester,
  ) async {
    final game = await load(tester);
    expect(game.world.children.whereType<MoonlitBoss>(), hasLength(1));
    final boss = game.boss;
    final initial = boss.position;
    game.startLauncherCharge();
    for (var frame = 0; frame < 240; frame++) {
      game.stepEngine();
    }
    expect(boss.position.distanceTo(initial), greaterThan(0.1));
    expect(boss.active, isFalse);
    expect(boss.petals, isEmpty);
    expect(boss.health, 16000);
    expect(_ball(game).body.bodyType, BodyType.static);
    game.releaseLauncher();
    expect(boss.active, isTrue);
    expect(game.hud.value.status, 'Launched');
  });

  testWidgets(
    'a fast grazing crossing uses the real ball radius and no impulse',
    (tester) async {
      final game = await load(tester);
      game.releaseLauncher();
      final boss = game.boss;
      final ball = _ball(game);
      final center = boss.position;
      const reach = 1.35 + PinballBall.radius;
      final from = center + Vector2(-0.7, reach - 0.05);
      ball.body.setTransform(from, 0);
      ball.body.linearVelocity = Vector2(120, 0);
      game.stepEngine();

      expect(from.distanceTo(center), greaterThan(reach));
      expect(ball.position.distanceTo(boss.position), greaterThan(reach));
      expect(boss.health, 14720);
      expect(ball.body.linearVelocity.x, closeTo(120, 0.001));
      expect(ball.body.linearVelocity.y, closeTo(0, 0.001));
      expect(game.hud.value.score, 1280);
      expect(game.hud.value.bossHealth, 14720);
      expect(game.hud.value.combo, 1);
    },
  );

  testWidgets('continuous overlap scores once until the ball leaves', (
    tester,
  ) async {
    final game = await load(tester);
    game.releaseLauncher();
    final boss = game.boss;
    _place(game, boss.position);
    for (var frame = 0; frame < 10; frame++) {
      game.stepEngine();
    }
    expect(boss.health, 14720);
    expect(game.hud.value.score, 1280);
    _place(game, boss.position + Vector2(4, 0));
    game.stepEngine();
    _place(game, boss.position);
    game.stepEngine();
    expect(boss.health, 13440);
    expect(game.hud.value.score, 2560);
  });

  testWidgets('a body hit scores less than the brooch and says so', (
    tester,
  ) async {
    final game = await load(tester);
    game.releaseLauncher();
    final boss = game.boss;
    final ball = _ball(game);
    // One fast step across the forehead, well clear of the brooch.
    ball.body.setTransform(boss.position + Vector2(-3.5, -3.2), 0);
    ball.body.linearVelocity = Vector2(120, 0);
    game.stepEngine();
    expect(boss.health, 16000 - boss.bodyDamage);
    expect(boss.lastHitCritical, isFalse);
    expect(game.hud.value.score, boss.bodyDamage);
    expect(game.hud.value.status, contains('몸통'));
    game.stepEngine();
    expect(
      game.world.children.whereType<BossDamagePopup>().single.critical,
      isFalse,
    );
  });

  testWidgets('teleporting outside does not fabricate a previous-frame hit', (
    tester,
  ) async {
    final game = await load(tester);
    game.releaseLauncher();
    final boss = game.boss;
    // Both sides lie outside the brooch and the body.
    _place(game, boss.position + Vector2(-6, 0));
    game.stepEngine();
    _place(game, boss.position + Vector2(6, 0));
    game.stepEngine();
    expect(boss.health, 16000);
    expect(game.hud.value.score, 0);
  });

  testWidgets('drain keeps damage but clears attack, recoil, combo and popup', (
    tester,
  ) async {
    final game = await load(tester);
    game.releaseLauncher();
    final boss = game.boss;
    boss.update(3.2);
    expect(boss.petals, isNotEmpty);
    _place(game, boss.position);
    game.stepEngine();
    expect(boss.health, 14720);
    expect(boss.hurtProgress, greaterThan(0));
    _place(game, Vector2(14, MonPinballGame.boardHeight + 5));
    game.stepEngine();
    game.stepEngine();
    expect(boss.health, 14720);
    expect(boss.active, isFalse);
    expect(boss.petals, isEmpty);
    expect(boss.hurtProgress, 0);
    expect(game.hud.value.combo, 0);
    expect(game.hud.value.lives, 2);
    expect(game.world.children.whereType<BossDamagePopup>(), isEmpty);
    game.releaseLauncher();
    expect(boss.active, isTrue);
    game.restartGame();
    expect(boss.health, 16000);
    expect(boss.active, isFalse);
    expect(game.hud.value.score, 0);
    expect(game.hud.value.lives, 3);
    expect(game.hud.value.combo, 0);
  });

  for (final restart in [true, false]) {
    for (final mountEffects in [false, true]) {
      testWidgets(
        '${restart ? 'restart' : 'drain'} clears ${mountEffects ? 'mounted' : 'queued'} score effects',
        (tester) async {
          final game = await load(tester);
          game.releaseLauncher();
          _place(game, game.boss.position);
          game.stepEngine();
          expect(game.hud.value.score, 1280);
          if (mountEffects) {
            game.stepEngine();
            expect(game.world.children.whereType<PulseRing>(), hasLength(1));
            expect(
              game.world.children.whereType<BossDamagePopup>(),
              hasLength(1),
            );
          }

          if (restart) {
            game.restartGame();
          } else {
            _place(game, Vector2(14, MonPinballGame.boardHeight + 5));
            game.stepEngine();
            expect(game.hud.value.lives, 2);
          }
          // Flush additions and removals without waiting out either animation.
          for (var frame = 0; frame < 3; frame++) {
            game.stepEngine();
            await tester.pump();
          }
          expect(game.world.children.whereType<PulseRing>(), isEmpty);
          expect(game.world.children.whereType<BossDamagePopup>(), isEmpty);
        },
      );
    }
  }

  testWidgets(
    'defeat holds the ball, preserves lives and ignores extra scores',
    (tester) async {
      final game = await load(tester);
      game.releaseLauncher();
      final boss = game.boss;
      for (var hit = 0; hit < 13; hit++) {
        _place(game, boss.position + Vector2(4, 0));
        game.stepEngine();
        _place(game, boss.position);
        game.stepEngine();
      }
      expect(boss.defeated, isTrue);
      expect(boss.active, isFalse);
      expect(boss.petals, isEmpty);
      expect(game.hud.value.bossDefeated, isTrue);
      expect(game.hud.value.status, contains('승리'));
      expect(game.hud.value.lives, 3);
      expect(game.hud.value.score, 16000);
      expect(game.hud.value.gameOver, isFalse);
      expect(_ball(game).body.bodyType, BodyType.static);
      game.nudge();
      game.addScore(
        250,
        Vector2(14, 10),
        const Color(0xFFFFFFFF),
        'late contact',
      );
      expect(boss.vanished, isFalse);
      for (var frame = 0; frame < 120; frame++) {
        game.stepEngine();
      }
      // The exit has finished: the boss no longer draws or attacks.
      expect(boss.vanished, isTrue);
      expect(boss.petals, isEmpty);
      expect(game.hud.value.score, 16000);
      expect(game.hud.value.lives, 3);
      expect(game.hud.value.status, contains('승리'));
      expect(
        _ball(game).position.distanceTo(game.launchPosition),
        lessThan(0.001),
      );
      game.startLauncherCharge(timed: false);
      expect(boss.defeated, isFalse);
      expect(boss.vanished, isFalse);
      expect(boss.health, 16000);
      expect(game.hud.value.score, 0);
      game.releaseLauncher();
      expect(boss.active, isTrue);
    },
  );
}

PinballBall _ball(MonPinballGame game) =>
    game.world.children.whereType<PinballBall>().single;
void _place(MonPinballGame game, Vector2 position) {
  final ball = _ball(game);
  ball.body.setTransform(position, 0);
  ball.body.linearVelocity = Vector2.zero();
}
