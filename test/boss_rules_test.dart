import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/boss_encounter.dart';

void main() {
  test('shield requires target hits before the boss can take damage', () {
    final boss = createBoss();
    boss.chargeShield();
    expect(boss.shieldCharge, 0);
    boss.start();
    expect(boss.takeHit(boss.position, boss.position), 0);
    expect(boss.health, 6400);
    boss.chargeShield();
    expect(boss.shieldCharge, 1);
    expect(boss.shieldState, BossShieldState.shielded);
    boss.chargeShield();
    expect(boss.requiredShieldHits, 2);
    expect(boss.shieldState, BossShieldState.exposed);
    expect(boss.exposureRemaining, 5);
    expect(boss.takeHit(boss.position, boss.position), 1280);
    expect(boss.health, 5120);
    expect(boss.takeHit(boss.position, boss.position), 0);
  });

  test('exposure expiry resets target charge and the continuous hit latch', () {
    final boss = createBoss()..start();
    exposeBoss(boss);
    expect(boss.takeHit(boss.position, boss.position), 1280);
    boss.update(5);
    expect(boss.shieldState, BossShieldState.shielded);
    expect(boss.shieldCharge, 0);
    expect(boss.exposureRemaining, 0);
    expect(boss.takeHit(boss.position, boss.position), 0);
    exposeBoss(boss);
    expect(boss.takeHit(boss.position, boss.position), 1280);
    boss.chargeShield();
    expect(boss.exposureRemaining, 5);
    boss.update(2);
    boss.chargeShield();
    expect(boss.exposureRemaining, 3);
  });

  test('exposed body hits retain the existing normal damage sweep', () {
    final boss = createBoss()..start();
    exposeBoss(boss);
    final head = boss.position + Vector2(0, -3.5);
    expect(boss.takeHit(head + Vector2(-6, 0), head + Vector2(6, 0)), 320);
    expect(boss.lastHitCritical, isFalse);
  });

  test('attack telegraph lasts 1.8 seconds and retains partial charge', () {
    final boss = createBoss()..start();
    boss.chargeShield();
    boss.update(10);
    expect(boss.shieldState, BossShieldState.shielded);
    boss.update(0.3);
    expect(boss.shieldState, BossShieldState.attacking);
    expect(boss.attackProgress, closeTo(1 / 18, 1e-9));
    expect(boss.takeHit(boss.position, boss.position), 0);
    boss.update(0.6);
    expect(boss.petals, hasLength(14));
    boss.update(1.2);
    expect(boss.shieldState, BossShieldState.shielded);
    expect(boss.shieldCharge, 1);
    expect(boss.attackProgress, 0);
    boss.chargeShield();
    expect(boss.shieldState, BossShieldState.exposed);
    expect(boss.petals, isEmpty);
  });

  test(
    'phase thresholds seal the lane during attacks and speed final cycles',
    () {
      final boss = createBoss()..start();
      exposeBoss(boss);
      strikeBoss(boss);
      expect(boss.phase, 1);
      strikeBoss(boss);
      expect(boss.health, 3840);
      expect(boss.phase, 2);
      expect(boss.laneSealed, isFalse);
      boss.update(15.3);
      expect(boss.shieldState, BossShieldState.attacking);
      expect(boss.laneSealed, isTrue);
      exposeBoss(boss);
      strikeBoss(boss);
      strikeBoss(boss);
      expect(boss.health, 1280);
      expect(boss.phase, 3);
      boss.update(12.9);
      expect(boss.shieldState, BossShieldState.attacking);
      expect(boss.laneSealed, isTrue);
    },
  );

  test(
    'pause clears exposure and attacks while reset restores configured health',
    () {
      final boss = createBoss()..start();
      boss.chargeShield();
      boss.pause();
      expect(boss.shieldCharge, 1);
      boss.start();
      boss.chargeShield();
      strikeBoss(boss);
      boss.pause();
      expect(boss.health, 5120);
      expect(boss.shieldCharge, 0);
      expect(boss.exposureRemaining, 0);
      expect(boss.shieldState, BossShieldState.shielded);
      expect(boss.attackProgress, 0);
      boss.start();
      boss.update(10.3);
      expect(boss.shieldState, BossShieldState.attacking);
      boss.pause();
      expect(boss.shieldState, BossShieldState.shielded);
      boss.reset();
      expect(boss.health, 6400);
      expect(boss.maxHealth, 6400);
      expect(boss.phase, 1);
      expect(boss.shieldCharge, 0);
      expect(boss.active, isFalse);
      expect(boss.usesShield, isTrue);
    },
  );

  test('configured defeat is terminal until reset', () {
    final boss = createBoss()..start();
    exposeBoss(boss);
    for (var hit = 0; hit < 5; hit++) {
      strikeBoss(boss);
    }
    expect(boss.health, 0);
    expect(boss.shieldState, BossShieldState.defeated);
    expect(boss.laneSealed, isFalse);
    boss.chargeShield();
    boss.start();
    expect(boss.active, isFalse);
    boss.reset();
    expect(boss.shieldState, BossShieldState.shielded);
    expect(boss.health, 6400);
  });

  test(
    'time partitioning and stalled frames preserve bounded shield state',
    () {
      final largeStep = createBoss()..start();
      final smallSteps = createBoss()..start();
      exposeBoss(largeStep);
      exposeBoss(smallSteps);
      largeStep.update(15.9);
      for (var tick = 0; tick < 159; tick++) {
        smallSteps.update(0.1);
      }
      expect(largeStep.shieldState, smallSteps.shieldState);
      expect(largeStep.exposureRemaining, smallSteps.exposureRemaining);
      expect(
        largeStep.attackProgress,
        closeTo(smallSteps.attackProgress, 1e-9),
      );
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
      largeStep.update(100000);
      expect(largeStep.petals.length, lessThanOrEqualTo(28));
      final elapsed = largeStep.elapsed;
      for (final dt in [0.0, -1.0, double.nan, double.infinity]) {
        largeStep.update(dt);
      }
      expect(largeStep.elapsed, elapsed);
      expect(largeStep.attackProgress.isFinite, isTrue);
    },
  );

  test(
    'fractional frames cross exposure and attack boundaries consistently',
    () {
      final boss = createBoss()..start();
      exposeBoss(boss);
      for (var tick = 0; tick < 50; tick++) {
        boss.update(0.1);
      }
      expect(boss.exposureRemaining, 0);
      expect(boss.shieldState, BossShieldState.shielded);
      for (var tick = 0; tick < 120; tick++) {
        boss.update(0.1);
      }
      expect(boss.shieldState, BossShieldState.shielded);
      expect(boss.attackProgress, 0);
    },
  );

  test(
    'configuration rejects rules that cannot produce a finite encounter',
    () {
      final boss = BossEncounter();
      expect(
        () => boss.configure(
          shieldHits: 0,
          exposureSeconds: 5,
          attackInterval: 12,
        ),
        throwsArgumentError,
      );
      expect(
        () => boss.configure(
          shieldHits: 2,
          exposureSeconds: double.nan,
          attackInterval: 12,
        ),
        throwsArgumentError,
      );
      expect(
        () => boss.configure(
          shieldHits: 2,
          exposureSeconds: 5,
          attackInterval: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => boss.configure(
          shieldHits: 2,
          exposureSeconds: 5,
          attackInterval: 12,
          maxHealth: 0,
        ),
        throwsArgumentError,
      );
      expect(boss.maxHealth, 16000);
      expect(boss.usesShield, isFalse);
    },
  );
}

BossEncounter createBoss() =>
    BossEncounter()
      ..configure(shieldHits: 2, exposureSeconds: 5, attackInterval: 12);

void exposeBoss(BossEncounter boss) {
  for (var hit = 0; hit < boss.requiredShieldHits; hit++) {
    boss.chargeShield();
  }
}

void strikeBoss(BossEncounter boss) {
  final center = boss.position;
  boss.takeHit(center + Vector2(-8, 0), center + Vector2(8, 0));
}
