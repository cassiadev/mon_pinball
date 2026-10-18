import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';

enum BossMotion { idle, moving, attacking, hurt, defeated }

/// A decorative petal in board coordinates, with its angle in radians.
class BossPetal {
  const BossPetal(this.x, this.y, this.angle, this.age);

  final double x;
  final double y;
  final double angle;
  final double age;
}

/// Deterministic encounter state shared by rendering and the weak-point sensor.
class BossEncounter {
  static const _attackPeriod = 3.5;
  static const _burstTime = 3.15;
  static const _petalLifetime = 6.0;
  static const _hurtDuration = 0.45;

  /// Length of the defeat flash and fade before the figure leaves the board.
  static const defeatDuration = 1.4;

  int _health = 16000;
  bool _active = false;
  double _elapsed = 0;
  double _activeElapsed = 0;
  double _activeOriginElapsed = 0;
  double _hurtUntil = 0;
  double _defeatedAt = 0;
  bool _overlapping = false;
  Vector2 _position = Vector2(14, 8.6);
  Vector2 _previousPosition = Vector2(14, 8.6);
  List<BossPetal> _petals = const [];

  int get maxHealth => 16000;
  int get hitDamage => 1280;
  int get health => _health;
  bool get active => _active;
  bool get defeated => _health == 0;
  Vector2 get position => _position.clone();
  double get weakPointRadius => 1.35;
  double get elapsed => _elapsed;
  double get poseTime => _elapsed;
  List<BossPetal> get petals => _petals;

  /// Zero until defeat, then 0..1 across the exit; the figure is gone at one.
  double get defeatProgress => defeated
      ? ((_elapsed - _defeatedAt) / defeatDuration).clamp(0.0, 1.0)
      : 0;

  /// Whether the defeated figure has finished leaving and draws nothing.
  bool get vanished => defeatProgress >= 1;

  /// Zero outside an attack; 0..1 across anticipation, burst and recovery.
  double get attackProgress {
    if (!active) return 0;
    final phase = _activeElapsed % _attackPeriod;
    return phase < 2.8 ? 0 : (phase - 2.8) / 0.7;
  }

  /// Recoil strength, falling from one to zero after a hit.
  double get hurtProgress =>
      ((_hurtUntil - _elapsed) / _hurtDuration).clamp(0.0, 1.0);

  BossMotion get motion {
    if (defeated) return BossMotion.defeated;
    if (!active) return BossMotion.idle;
    if (hurtProgress > 0) return BossMotion.hurt;
    if (attackProgress > 0) return BossMotion.attacking;
    return _activeElapsed < 0.8 ? BossMotion.idle : BossMotion.moving;
  }

  void start() {
    if (defeated || active) return;
    _active = true;
    _activeElapsed = 0;
    _activeOriginElapsed = _elapsed;
    _previousPosition = _position.clone();
    _overlapping = false;
  }

  /// Ends the current ball's attack cycle; the next launch starts a fresh one.
  void pause() {
    _active = false;
    _activeElapsed = 0;
    _petals = const [];
    _hurtUntil = 0;
    _overlapping = false;
    _previousPosition = _position.clone();
  }

  void reset() {
    pause();
    _health = maxHealth;
    _elapsed = 0;
    _activeOriginElapsed = 0;
    _position = Vector2(14, 8.6);
    _previousPosition = _position.clone();
  }

  void update(double dt) {
    if (!dt.isFinite || dt <= 0) return;
    _previousPosition = _position.clone();
    _elapsed += dt;
    // A defeated figure holds its place while it dissolves.
    if (!defeated) _position = _positionAt(_elapsed);
    if (!active) return;
    _activeElapsed += dt;
    _updatePetals();
  }

  /// Returns actual damage. The caller retains control of ball velocity.
  ///
  /// The relative segment includes the boss's movement since the last update.
  /// A continuous overlap is suppressed until the ball ends outside the sensor.
  int checkHit(Vector2 from, Vector2 to, {double ballRadius = 0.55}) {
    if (!active || defeated || !ballRadius.isFinite || ballRadius < 0) {
      return 0;
    }
    final start = from - _previousPosition;
    final end = to - _position;
    _previousPosition = _position.clone();
    final radius = weakPointRadius + ballRadius;
    final radiusSquared = radius * radius;
    final endInside = end.length2 <= radiusSquared;
    if (_overlapping) {
      _overlapping = endInside;
      return 0;
    }
    final segment = end - start;
    final fraction = segment.length2 == 0
        ? 0.0
        : (-start.dot(segment) / segment.length2).clamp(0.0, 1.0);
    if ((start + segment * fraction).length2 > radiusSquared) return 0;
    _overlapping = endInside;
    final damage = math.min(hitDamage, _health);
    _health -= damage;
    _hurtUntil = _elapsed + _hurtDuration;
    if (defeated) {
      _defeatedAt = _elapsed;
      pause();
    }
    return damage;
  }

  Vector2 _positionAt(double time) => Vector2(
    14 + math.sin(time * 0.55) * 1.6,
    8.6 + math.sin(time * 1.1) * 0.6,
  );

  void _updatePetals() {
    final petals = <BossPetal>[];
    // Only reconstruct live bursts: even a long suspended frame costs <=28 petals.
    final lastBurst = ((_activeElapsed - _burstTime) / _attackPeriod).floor();
    final firstBurst = math.max(
      0,
      ((_activeElapsed - _petalLifetime - _burstTime) / _attackPeriod).ceil(),
    );
    for (var burst = firstBurst; burst <= lastBurst; burst++) {
      final birth = _burstTime + burst * _attackPeriod;
      final age = _activeElapsed - birth;
      final origin = _positionAt(_activeOriginElapsed + birth);
      for (final side in [-1, 1]) {
        for (var index = 0; index < 7; index++) {
          final angle = 0.28 + index * 0.16;
          final vx = side * math.sin(angle) * 3.2;
          final vy = math.cos(angle) * 3.2;
          final curve = side * 0.18;
          final x = origin.x + side * 1.8 + vx * age + curve * age * age;
          final y = origin.y + 1.2 + vy * age;
          if (x < -2 || x > 30 || y < -2 || y > 52) continue;
          petals.add(
            BossPetal(x, y, math.atan2(vy, vx + 2 * curve * age), age),
          );
        }
      }
    }
    _petals = List.unmodifiable(petals);
  }
}
