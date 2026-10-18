import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/boss_encounter.dart';

void main() {
  test('waiting boss animates without attacks or damage', () {
    final boss = BossEncounter();
    final initialPosition = boss.position;
    boss.update(4);
    expect(boss.elapsed, 4);
    expect(boss.poseTime, greaterThan(0));
    expect(boss.position.distanceTo(initialPosition), greaterThan(0.1));
    expect(boss.motion, BossMotion.idle);
    expect(boss.active, isFalse);
    expect(boss.petals, isEmpty);
    expect(boss.checkHit(Vector2(0, 10), Vector2(28, 10)), 0);
    expect(boss.health, 16000);
  });

  test('launch activates movement and anticipation before the petal burst', () {
    final boss = BossEncounter()..start();
    expect(boss.active, isTrue);
    boss.update(1);
    expect(boss.motion, BossMotion.moving);
    boss.update(1.9);
    expect(boss.motion, BossMotion.attacking);
    expect(boss.attackProgress, greaterThan(0));
    expect(boss.petals, isEmpty);
    boss.update(0.3);
    expect(boss.petals, hasLength(14));
    expect(boss.attackProgress, greaterThan(0.5));
    boss.update(0.4);
    expect(boss.motion, BossMotion.moving);
  });

  test('fast segment crossing damages even when both endpoints miss', () {
    final boss = BossEncounter()..start();
    expect(boss.checkHit(Vector2(2, 10), Vector2(26, 10)), 1280);
    expect(boss.health, 14720);
    expect(boss.motion, BossMotion.hurt);
    expect(boss.hurtProgress, 1);
    boss.update(0.5);
    expect(boss.hurtProgress, 0);
    expect(boss.motion, isNot(BossMotion.hurt));
  });

  test('continuous overlap counts once until the ball leaves the sensor', () {
    final boss = BossEncounter()..start();
    final center = boss.position;
    expect(boss.checkHit(center, center), 1280);
    expect(boss.checkHit(center, center), 0);
    expect(boss.checkHit(center, Vector2(26, 10)), 0);
    expect(boss.checkHit(Vector2(26, 10), center), 1280);
    expect(boss.health, 13440);
  });

  test('misses and ball-radius edge contacts use the moving weak point', () {
    final boss = BossEncounter()..start();
    final y = boss.position.y + 2;
    expect(boss.checkHit(Vector2(2, y), Vector2(26, y)), 0);
    expect(boss.checkHit(Vector2(2, y), Vector2(26, y), ballRadius: 0.7), 1280);
  });

  test('swept hits include movement of the boss past a stationary ball', () {
    // The flight path's left and right extremes straddle a centred ball.
    final boss = BossEncounter()..update(8.57);
    final ball = Vector2(14, 8.6);
    const reach = 1.35 + 0.1;
    expect(boss.position.distanceTo(ball), greaterThan(reach));
    boss.start();
    boss.update(5.71);
    expect(boss.position.distanceTo(ball), greaterThan(reach));
    expect(boss.checkHit(ball, ball, ballRadius: 0.1), 1280);
  });

  test('pause clears petals and collision latch while preserving health', () {
    final boss = BossEncounter()..start();
    boss.update(3.2);
    final center = boss.position;
    expect(boss.checkHit(center, center), 1280);
    boss.pause();
    expect(boss.active, isFalse);
    expect(boss.petals, isEmpty);
    expect(boss.motion, BossMotion.idle);
    boss.update(20);
    expect(boss.petals, isEmpty);
    expect(boss.health, 14720);
    expect(boss.checkHit(boss.position, boss.position), 0);
    boss.start();
    expect(boss.checkHit(boss.position, boss.position), 1280);
    boss.update(1);
    expect(boss.petals, isEmpty);
  });

  test('defeat clamps damage and stays terminal until reset', () {
    final boss = BossEncounter()..start();
    boss.update(3.2);
    var totalDamage = 0;
    for (var hit = 0; hit < 13; hit++) {
      final center = boss.position;
      totalDamage += boss.checkHit(center - Vector2(10, 0), center);
      boss.checkHit(center, center + Vector2(10, 0));
    }
    expect(totalDamage, 16000);
    expect(boss.health, 0);
    expect(boss.defeated, isTrue);
    expect(boss.active, isFalse);
    expect(boss.petals, isEmpty);
    boss.start();
    boss.update(30);
    expect(boss.motion, BossMotion.defeated);
    expect(boss.petals, isEmpty);
    expect(boss.active, isFalse);
    expect(boss.checkHit(Vector2(0, 10), Vector2(28, 10)), 0);
    boss.reset();
    expect(boss.health, 16000);
    expect(boss.defeated, isFalse);
    expect(boss.active, isFalse);
    expect(boss.elapsed, 0);
    expect(boss.position.x, 14);
    expect(boss.position.y, closeTo(8.6, 1e-6));
    expect(boss.motion, BossMotion.idle);
    boss.start();
    expect(boss.checkHit(boss.position, boss.position), 1280);
  });

  test('petals curve in two fans and expire within a bounded board area', () {
    final boss = BossEncounter()..start();
    boss.update(3.2);
    final first = boss.petals.first;
    expect(boss.petals.any((petal) => petal.x < boss.position.x), isTrue);
    expect(boss.petals.any((petal) => petal.x > boss.position.x), isTrue);
    boss.update(0.5);
    expect(boss.petals.first.age, greaterThan(first.age));
    expect(boss.petals.first.angle, isNot(first.angle));
    for (var tick = 0; tick < 400; tick++) {
      boss.update(0.1);
      expect(boss.petals.length, lessThanOrEqualTo(28));
      for (final petal in boss.petals) {
        expect(petal.x, inInclusiveRange(-2, 30));
        expect(petal.y, inInclusiveRange(-2, 52));
        expect(petal.age, lessThanOrEqualTo(6));
      }
    }
  });

  test(
    'time partitioning preserves deterministic petals and boss position',
    () {
      final largeStep = BossEncounter()..start();
      final smallSteps = BossEncounter()..start();
      largeStep.update(10);
      for (var tick = 0; tick < 100; tick++) {
        smallSteps.update(0.1);
      }
      expect(largeStep.position.x, closeTo(smallSteps.position.x, 1e-9));
      expect(largeStep.position.y, closeTo(smallSteps.position.y, 1e-9));
      expect(largeStep.petals.length, smallSteps.petals.length);
      for (var index = 0; index < largeStep.petals.length; index++) {
        expect(
          largeStep.petals[index].x,
          closeTo(smallSteps.petals[index].x, 1e-9),
        );
        expect(
          largeStep.petals[index].y,
          closeTo(smallSteps.petals[index].y, 1e-9),
        );
      }
    },
  );

  test('large elapsed gaps stay bounded and idle position stays on board', () {
    final boss = BossEncounter()..start();
    boss.update(100000);
    expect(boss.petals.length, lessThanOrEqualTo(28));
    for (var tick = 0; tick < 100; tick++) {
      boss.update(0.2);
      expect(boss.position.x, inInclusiveRange(12.39, 15.61));
      expect(boss.position.y, inInclusiveRange(7.99, 9.21));
    }
  });

  test('nonpositive or nonfinite updates cannot corrupt state', () {
    final boss = BossEncounter()..start();
    for (final dt in [0.0, -1.0, double.nan, double.infinity]) {
      boss.update(dt);
    }
    expect(boss.elapsed, 0);
    expect(boss.position.x, 14);
    expect(boss.petals, isEmpty);
  });
}
