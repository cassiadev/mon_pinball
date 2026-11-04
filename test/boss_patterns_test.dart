import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/boss_encounter.dart';

void main() {
  test('garden keeps its immediate left gate and has no new warning', () {
    final boss = _createBoss(BossPattern.garden)..start();
    _enterPhase(boss, 2);
    boss.update(11.2);
    expect(boss.pattern, BossPattern.garden);
    expect(boss.laneSealed, isTrue);
    expect(boss.sealsLeftLane, isTrue);
    expect(boss.sealsRightLane, isFalse);
    expect(boss.attackWarningProgress, 0);
    expect(boss.warnsLeftLane, isFalse);
    expect(boss.warnsRightLane, isFalse);
    boss.configure(shieldHits: 2, exposureSeconds: 1, attackInterval: 12);
    expect(boss.pattern, BossPattern.garden);
  });

  test('neon warns before alternating one side gate each attack', () {
    final boss = _createBoss(BossPattern.neon)..start();
    _enterPhase(boss, 2);
    boss.update(11.2);
    expect(boss.shieldState, BossShieldState.attacking);
    expect(boss.warnsLeftLane, isTrue);
    expect(boss.warnsRightLane, isFalse);
    expect(boss.laneSealed, isFalse);
    boss.update(0.3);
    expect(boss.attackWarningProgress, closeTo(0.5, 1e-9));
    expect(boss.laneSealed, isFalse);
    boss.update(0.3);
    expect(boss.attackWarningProgress, 0);
    expect(boss.warnsLeftLane, isFalse);
    expect(boss.sealsLeftLane, isTrue);
    expect(boss.sealsRightLane, isFalse);
    for (var tick = 0; tick < 11; tick++) {
      boss.update(0.1);
      expect(boss.sealsLeftLane, isTrue);
      expect(boss.sealsRightLane, isFalse);
    }
    boss.update(0.1);
    expect(boss.laneSealed, isFalse);
    boss.update(10.2);
    expect(boss.warnsLeftLane, isFalse);
    expect(boss.warnsRightLane, isTrue);
    expect(boss.laneSealed, isFalse);
    boss.update(0.6);
    expect(boss.sealsLeftLane, isFalse);
    expect(boss.sealsRightLane, isTrue);
  });

  test('abyss warns longer before closing both side gates', () {
    final boss = _createBoss(BossPattern.abyss)..start();
    _enterPhase(boss, 2);
    boss.update(11.2);
    expect(boss.warnsLeftLane, isTrue);
    expect(boss.warnsRightLane, isTrue);
    boss.update(0.425);
    expect(boss.attackWarningProgress, closeTo(0.5, 1e-9));
    expect(boss.laneSealed, isFalse);
    boss.update(0.425);
    expect(boss.attackWarningProgress, 0);
    expect(boss.sealsLeftLane, isTrue);
    expect(boss.sealsRightLane, isTrue);
    expect(boss.laneSealed, isTrue);
    boss.update(0.95);
    expect(boss.laneSealed, isFalse);
  });

  for (final pattern in [BossPattern.neon, BossPattern.abyss]) {
    test('${pattern.name} phase one attacks keep side gates open', () {
      final boss = _createBoss(pattern)..start();
      boss.update(10.4);
      expect(boss.shieldState, BossShieldState.attacking);
      expect(boss.attackWarningProgress, greaterThan(0));
      expect(boss.warnsLeftLane, isFalse);
      expect(boss.warnsRightLane, isFalse);
      boss.update(0.8);
      expect(boss.laneSealed, isFalse);
      expect(boss.sealsLeftLane, isFalse);
      expect(boss.sealsRightLane, isFalse);
      expect(boss.takeHit(boss.position, boss.position), 0);
    });

    test('${pattern.name} exposure and pause cancel an announced attack', () {
      final boss = _createBoss(pattern)..start();
      _enterPhase(boss, 2);
      boss.update(11.5);
      expect(boss.attackWarningProgress, greaterThan(0));
      _exposeBoss(boss);
      expect(boss.shieldState, BossShieldState.exposed);
      expect(boss.attackProgress, 0);
      expect(boss.attackWarningProgress, 0);
      expect(boss.warnsLeftLane, isFalse);
      expect(boss.warnsRightLane, isFalse);
      expect(boss.laneSealed, isFalse);
      boss.update(12.1);
      expect(boss.laneSealed, isTrue);
      final health = boss.health;
      boss.pause();
      boss.update(20);
      expect(boss.health, health);
      expect(boss.attackWarningProgress, 0);
      expect(boss.warnsLeftLane, isFalse);
      expect(boss.warnsRightLane, isFalse);
      expect(boss.sealsLeftLane, isFalse);
      expect(boss.sealsRightLane, isFalse);
      boss.start();
      expect(boss.shieldState, BossShieldState.shielded);
      expect(boss.attackProgress, 0);
    });

    test('${pattern.name} final phase shortens cycles after exposure', () {
      final boss = _createBoss(pattern)..start();
      _enterPhase(boss, 3);
      expect(boss.shieldState, BossShieldState.exposed);
      expect(boss.laneSealed, isFalse);
      boss.update(8.7);
      expect(boss.shieldState, BossShieldState.shielded);
      boss.update(0.2);
      expect(boss.shieldState, BossShieldState.attacking);
      expect(boss.attackWarningProgress, greaterThan(0));
      expect(boss.laneSealed, isFalse);
      boss.update(0.8);
      expect(boss.laneSealed, isTrue);
      final sealsLeft = boss.sealsLeftLane;
      final sealsRight = boss.sealsRightLane;
      boss.update(0.5);
      expect(boss.sealsLeftLane, sealsLeft);
      expect(boss.sealsRightLane, sealsRight);
      boss.update(0.4);
      expect(boss.shieldState, BossShieldState.shielded);
      expect(boss.laneSealed, isFalse);
    });

    for (final difficulty in [
      ('easy', 12.0, 2),
      ('normal', 9.0, 3),
      ('hard', 7.0, 4),
    ]) {
      test('${pattern.name} ${difficulty.$1} partitions preserve timing', () {
        final interval =
            difficulty.$2 * (pattern == BossPattern.neon ? 0.8 : 0.7);
        final large = _createBoss(
          pattern,
          attackInterval: interval,
          shieldHits: difficulty.$3 + 1,
        )..start();
        final small = _createBoss(
          pattern,
          attackInterval: interval,
          shieldHits: difficulty.$3 + 1,
        )..start();
        _enterPhase(large, 3);
        _enterPhase(small, 3);
        large.update(77.37);
        for (var tick = 0; tick < 7737; tick++) {
          small.update(0.01);
        }
        expect(large.shieldState, small.shieldState);
        expect(large.attackProgress, closeTo(small.attackProgress, 1e-8));
        expect(
          large.attackWarningProgress,
          closeTo(small.attackWarningProgress, 1e-8),
        );
        expect(large.sealsLeftLane, small.sealsLeftLane);
        expect(large.sealsRightLane, small.sealsRightLane);
        expect(large.warnsLeftLane, small.warnsLeftLane);
        expect(large.warnsRightLane, small.warnsRightLane);
        large.update(100000);
        for (final value in [
          large.attackProgress,
          large.attackWarningProgress,
        ]) {
          expect(value.isFinite, isTrue);
          expect(value, inInclusiveRange(0, 1));
        }
        final elapsed = large.elapsed;
        for (final dt in [0.0, -1.0, double.nan, double.infinity]) {
          large.update(dt);
        }
        expect(large.elapsed, elapsed);
      });
    }
  }
}

BossEncounter _createBoss(
  BossPattern pattern, {
  double attackInterval = 12,
  int shieldHits = 2,
}) => BossEncounter()
  ..configure(
    shieldHits: shieldHits,
    exposureSeconds: 1,
    attackInterval: attackInterval,
    pattern: pattern,
  );

void _exposeBoss(BossEncounter boss) {
  for (var hit = 0; hit < boss.requiredShieldHits; hit++) {
    boss.chargeShield();
  }
}

void _enterPhase(BossEncounter boss, int phase) {
  _exposeBoss(boss);
  while (boss.phase < phase) {
    final center = boss.position;
    boss.takeHit(center + Vector2(-8, 0), center + Vector2(8, 0));
  }
}
