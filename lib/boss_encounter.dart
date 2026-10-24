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

/// Deterministic encounter state shared by rendering and the hit sensors.
///
/// The golden brooch is a weak point that takes critical damage; the head and
/// torso around it take normal damage. The skirt and sleeves never count, so
/// bumper rallies beneath her do not wear her down.
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
  bool _bodyOverlapping = false;
  bool _lastHitCritical = false;
  double _hurtScale = 1;
  Vector2 _position = Vector2(14, 8.6);
  Vector2 _previousPosition = Vector2(14, 8.6);
  List<BossPetal> _petals = const [];

  int get maxHealth => 16000;

  /// Critical damage for a ball crossing the brooch.
  int get hitDamage => 1280;

  /// Normal damage for a ball striking the head or torso.
  int get bodyDamage => 320;

  /// Head and torso around the brooch, as half-axes relative to it.
  static final bodyCenter = Vector2(0, -0.6);
  static const bodyRadiusX = 2.4;
  static const bodyRadiusY = 4.4;

  /// Whether the latest damaging hit struck the brooch.
  bool get lastHitCritical => _lastHitCritical;
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

  /// Recoil strength, falling to zero after a hit; body hits recoil half as
  /// far as critical ones.
  double get hurtProgress =>
      ((_hurtUntil - _elapsed) / _hurtDuration).clamp(0.0, 1.0) * _hurtScale;

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
    _bodyOverlapping = false;
  }

  /// Ends the current ball's attack cycle; the next launch starts a fresh one.
  void pause() {
    _active = false;
    _activeElapsed = 0;
    _petals = const [];
    _hurtUntil = 0;
    _overlapping = false;
    _bodyOverlapping = false;
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
  /// A brooch crossing is critical and takes priority over the body. Each zone
  /// counts a continuous overlap once, until the ball ends outside it.
  int takeHit(Vector2 from, Vector2 to, {double ballRadius = 0.55}) {
    if (!active || defeated || !ballRadius.isFinite || ballRadius < 0) {
      return 0;
    }
    final start = from - _previousPosition;
    final end = to - _position;
    _previousPosition = _position.clone();

    final reach = weakPointRadius + ballRadius;
    final (weakSwept, weakInside) = _sweep(
      start,
      end,
      Vector2.zero(),
      reach,
      reach,
    );
    final critical = weakSwept && !_overlapping;
    _overlapping = weakInside;
    final (bodySwept, bodyInside) = _sweep(
      start,
      end,
      bodyCenter,
      bodyRadiusX + ballRadius,
      bodyRadiusY + ballRadius,
    );
    final body = bodySwept && !_bodyOverlapping;
    _bodyOverlapping = bodyInside;
    if (!critical && !body) return 0;

    final damage = math.min(critical ? hitDamage : bodyDamage, _health);
    _health -= damage;
    _lastHitCritical = critical;
    _hurtScale = critical ? 1 : 0.5;
    _hurtUntil = _elapsed + _hurtDuration;
    if (defeated) {
      _defeatedAt = _elapsed;
      pause();
    }
    return damage;
  }

  /// Whether a segment crosses an axis-aligned ellipse, and ends inside it.
  static (bool, bool) _sweep(
    Vector2 start,
    Vector2 end,
    Vector2 center,
    double radiusX,
    double radiusY,
  ) {
    Vector2 toLocal(Vector2 point) =>
        Vector2((point.x - center.x) / radiusX, (point.y - center.y) / radiusY);
    final a = toLocal(start);
    final b = toLocal(end);
    final segment = b - a;
    final fraction = segment.length2 == 0
        ? 0.0
        : (-a.dot(segment) / segment.length2).clamp(0.0, 1.0);
    return ((a + segment * fraction).length2 <= 1, b.length2 <= 1);
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
