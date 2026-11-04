import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';

enum BossMotion { idle, moving, attacking, hurt, defeated }

enum BossShieldState { shielded, exposed, attacking, defeated }

enum BossPattern { garden, neon, abyss }

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
  static const _shieldAttackDuration = 1.8;
  static const _timeTolerance = 1e-9;

  /// Length of the defeat flash and fade before the figure leaves the board.
  static const defeatDuration = 1.4;

  int _health = 16000;
  int _maxHealth = 16000;
  BossPattern _pattern = BossPattern.garden;
  int _requiredShieldHits = 0;
  int _shieldCharge = 0;
  double _exposureSeconds = 0;
  double _exposureRemaining = 0;
  double _shieldAttackInterval = 12;
  double _shieldAttackElapsed = 0;
  double _shieldAttackOriginElapsed = 0;
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

  /// Whether the encounter should appear on the current stage.
  bool visible = true;

  int get maxHealth => _maxHealth;
  BossPattern get pattern => _pattern;
  bool get usesShield => _requiredShieldHits > 0;
  int get shieldCharge => _shieldCharge;
  int get requiredShieldHits => _requiredShieldHits;
  double get exposureRemaining => _exposureRemaining;
  int get phase => _health > maxHealth * 0.6
      ? 1
      : _health > maxHealth * 0.3
      ? 2
      : 3;

  BossShieldState get shieldState {
    if (defeated) return BossShieldState.defeated;
    if (!usesShield || _exposureRemaining > 0) return BossShieldState.exposed;
    if (active &&
        _shieldCycleElapsed + _timeTolerance >=
            _configuredAttackPeriod - _shieldAttackDuration) {
      return BossShieldState.attacking;
    }
    return BossShieldState.shielded;
  }

  bool get _isLaneAttack =>
      usesShield &&
      active &&
      shieldState == BossShieldState.attacking &&
      phase >= 2;

  /// Whether either side gate currently obstructs a lane.
  bool get laneSealed => sealsLeftLane || sealsRightLane;

  bool get sealsLeftLane => _isLaneAttack && !_isWarning && _targetsLeftLane;
  bool get sealsRightLane => _isLaneAttack && !_isWarning && _targetsRightLane;

  /// The announced gates stay open until their warning has finished.
  bool get warnsLeftLane => _isLaneAttack && _isWarning && _targetsLeftLane;
  bool get warnsRightLane => _isLaneAttack && _isWarning && _targetsRightLane;

  /// Zero outside anticipation, then 0..1 before a new pattern's gate closes.
  /// Phase one uses the same anticipation for decorative attacks only.
  double get attackWarningProgress =>
      _isWarning ? (_shieldAttackAge / _warningDuration).clamp(0.0, 1.0) : 0;

  bool get _targetsLeftLane =>
      pattern != BossPattern.neon || !_targetsRightLane;

  bool get _targetsRightLane =>
      pattern == BossPattern.abyss ||
      pattern == BossPattern.neon &&
          ((_shieldAttackElapsed + _timeTolerance) / _configuredAttackPeriod)
              .floor()
              .isOdd;

  double get _warningDuration => pattern == BossPattern.abyss ? 0.85 : 0.6;

  bool get _isWarning =>
      pattern != BossPattern.garden &&
      usesShield &&
      shieldState == BossShieldState.attacking &&
      _shieldAttackAge + _timeTolerance < _warningDuration;

  double get _shieldAttackAge =>
      _shieldCycleElapsed - (_configuredAttackPeriod - _shieldAttackDuration);

  double get _configuredAttackPeriod =>
      _shieldAttackInterval * (phase == 3 ? 0.8 : 1);

  double get _shieldCycleElapsed {
    final cycle = _shieldAttackElapsed % _configuredAttackPeriod;
    return cycle >= _configuredAttackPeriod - _timeTolerance ? 0 : cycle;
  }

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
    if (usesShield) {
      if (shieldState != BossShieldState.attacking) return 0;
      return (_shieldAttackAge / _shieldAttackDuration).clamp(0.0, 1.0);
    }
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
    if (attackProgress > 0 ||
        usesShield && shieldState == BossShieldState.attacking) {
      return BossMotion.attacking;
    }
    return _activeElapsed < 0.8 ? BossMotion.idle : BossMotion.moving;
  }

  /// Enables target-charged shielding and begins a fresh configured encounter.
  /// The final phase shortens the attack interval by twenty percent.
  void configure({
    required int shieldHits,
    required double exposureSeconds,
    required double attackInterval,
    int maxHealth = 6400,
    BossPattern pattern = BossPattern.garden,
  }) {
    if (shieldHits <= 0) throw ArgumentError.value(shieldHits, 'shieldHits');
    if (!exposureSeconds.isFinite || exposureSeconds <= 0) {
      throw ArgumentError.value(exposureSeconds, 'exposureSeconds');
    }
    if (!attackInterval.isFinite ||
        attackInterval <= _shieldAttackDuration / 0.8) {
      throw ArgumentError.value(attackInterval, 'attackInterval');
    }
    if (maxHealth <= 0) throw ArgumentError.value(maxHealth, 'maxHealth');
    _requiredShieldHits = shieldHits;
    _exposureSeconds = exposureSeconds;
    _shieldAttackInterval = attackInterval;
    _maxHealth = maxHealth;
    _pattern = pattern;
    reset();
  }

  /// Each eligible target hit counts, including hits during an attack.
  void chargeShield() {
    if (!usesShield || !active || defeated || _exposureRemaining > 0) return;
    _shieldCharge++;
    if (_shieldCharge < _requiredShieldHits) return;
    _exposureRemaining = _exposureSeconds;
    _shieldAttackElapsed = 0;
    _shieldAttackOriginElapsed = _elapsed + _exposureSeconds;
    _petals = const [];
    _overlapping = false;
    _bodyOverlapping = false;
    _previousPosition = _position.clone();
  }

  void start() {
    if (defeated || active) return;
    _active = true;
    _activeElapsed = 0;
    _activeOriginElapsed = _elapsed;
    _shieldAttackElapsed = 0;
    _shieldAttackOriginElapsed = _elapsed;
    _previousPosition = _position.clone();
    _overlapping = false;
    _bodyOverlapping = false;
  }

  /// Ends the current ball's attack cycle; the next launch starts a fresh one.
  void pause() {
    if (_exposureRemaining > 0) _shieldCharge = 0;
    _exposureRemaining = 0;
    _shieldAttackElapsed = 0;
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
    _shieldCharge = 0;
    _elapsed = 0;
    _activeOriginElapsed = 0;
    _position = Vector2(14, 8.6);
    _previousPosition = _position.clone();
  }

  void update(double dt) {
    if (!dt.isFinite || dt <= 0) return;
    if (!(_elapsed + dt).isFinite || !(_activeElapsed + dt).isFinite) return;
    _previousPosition = _position.clone();
    _elapsed += dt;
    // A defeated figure holds its place while it dissolves.
    if (!defeated) _position = _positionAt(_elapsed);
    if (!active) return;
    _activeElapsed += dt;
    if (usesShield) {
      final exposedTime = math.min(dt, _exposureRemaining);
      _exposureRemaining -= exposedTime;
      if (_exposureRemaining < _timeTolerance) _exposureRemaining = 0;
      _shieldAttackElapsed += dt - exposedTime;
      if (exposedTime > 0 && _exposureRemaining == 0) {
        _shieldCharge = 0;
        _overlapping = false;
        _bodyOverlapping = false;
      }
    }
    _updatePetals();
  }

  /// Returns actual damage. The caller retains control of ball velocity.
  ///
  /// The relative segment includes the boss's movement since the last update.
  /// A brooch crossing is critical and takes priority over the body. Each zone
  /// counts a continuous overlap once, until the ball ends outside it.
  int takeHit(Vector2 from, Vector2 to, {double ballRadius = 0.55}) {
    if (!active ||
        defeated ||
        usesShield && shieldState != BossShieldState.exposed ||
        !ballRadius.isFinite ||
        ballRadius < 0) {
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
    if (usesShield && _exposureRemaining > 0) {
      _petals = const [];
      return;
    }
    final period = usesShield ? _configuredAttackPeriod : _attackPeriod;
    final burstTime = usesShield ? period - 1.1 : _burstTime;
    final elapsed = usesShield ? _shieldAttackElapsed : _activeElapsed;
    final originElapsed = usesShield
        ? _shieldAttackOriginElapsed
        : _activeOriginElapsed;
    final tolerance = usesShield ? _timeTolerance : 0;
    final petals = <BossPetal>[];
    // Reconstruct only live bursts, bounding work even after a suspended frame.
    final lastBurst = ((elapsed - burstTime + tolerance) / period).floor();
    final firstBurst = math.max(
      0,
      ((elapsed - _petalLifetime - burstTime - tolerance) / period).ceil(),
    );
    for (var burst = firstBurst; burst <= lastBurst; burst++) {
      final birth = burstTime + burst * period;
      final rawAge = elapsed - birth;
      final age = usesShield ? rawAge.clamp(0.0, _petalLifetime) : rawAge;
      final origin = _positionAt(originElapsed + birth);
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
      // A finite double may exceed the integer range used for burst indices.
      if (burst == lastBurst) break;
    }
    _petals = List.unmodifiable(petals);
  }
}
