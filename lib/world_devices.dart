import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import 'pinball_game.dart';
import 'pinball_progress.dart';

/// A yielding leaf: the picture and the bounded physical hinge turn together.
class GardenPetalFlap extends BodyComponent<MonPinballGame> {
  GardenPetalFlap({required this.right})
    : super(priority: 5, renderBody: false);

  final bool right;
  late Body _pivot;
  late RevoluteJoint _joint;
  double get _restAngle => right ? -0.5 : 0.5;
  Vector2 get _center => Vector2(right ? 20.7 : 5.75, 31.2);

  @override
  Body createBody() {
    final active = game.currentWorld == PinballWorld.garden;
    _pivot = world.createBody(BodyDef(position: _center, active: active));
    final leaf = world.createBody(
      BodyDef(
        type: BodyType.dynamic,
        position: _center,
        angle: _restAngle,
        active: active,
        gravityScale: Vector2.zero(),
        angularDamping: 1.5,
        userData: this,
      ),
    );
    leaf.createFixture(
      FixtureDef(
        PolygonShape()..setAsBoxXY(1.75, 0.28),
        density: 0.6,
        friction: 0.08,
        restitution: 0.45,
        userData: this,
      ),
    );
    _joint = RevoluteJoint(
      RevoluteJointDef()
        ..initialize(_pivot, leaf, _center)
        ..enableLimit = true
        ..lowerAngle = -0.65
        ..upperAngle = 0.65
        ..enableMotor = true
        ..motorSpeed = 0
        ..maxMotorTorque = 3,
    );
    world.createJoint(_joint);
    return leaf;
  }

  void selectLayout() {
    final active = game.currentWorld == PinballWorld.garden;
    _pivot.setActive(active);
    body.setActive(active);
    body.setTransform(_center, _restAngle);
    body.linearVelocity = Vector2.zero();
    body.angularVelocity = 0;
    _joint.motorSpeed = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (body.isActive) {
      _joint.motorSpeed = (-_joint.jointAngle() * 4).clamp(-2.0, 2.0);
    }
  }

  @override
  void render(Canvas canvas) {
    if (!body.isActive) return;
    const bounds = Rect.fromLTRB(-1.75, -0.28, 1.75, 0.28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(0.28)),
      Paint()..color = const Color(0xFF76C9AE),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(0.28)),
      Paint()
        ..color = const Color(0xFFE8D99D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.06,
    );
    final vein = Paint()
      ..color = const Color(0xFF285C57)
      ..strokeWidth = 0.055;
    canvas.drawLine(const Offset(-1.55, 0), const Offset(1.55, 0), vein);
    for (final x in [-1.1, -0.6, 0.6, 1.1]) {
      canvas.drawLine(Offset(x, 0), Offset(x + 0.2, -0.18), vein);
      canvas.drawLine(Offset(x, 0), Offset(x + 0.2, 0.18), vein);
    }
    canvas.drawCircle(
      Offset.zero,
      0.26,
      Paint()..color = const Color(0xFFE5C77D),
    );
    canvas.drawCircle(
      Offset.zero,
      0.11,
      Paint()..color = const Color(0xFF31534E),
    );
  }

  @override
  void onRemove() {
    // Destroying the extra anchor also destroys its joint, before the leaf.
    if (!world.isRemoving || world.destroyBodiesOnRemove) {
      world.destroyBody(_pivot);
    }
    super.onRemove();
  }
}

/// A short, visible catch and kick. It is a field, not a solid cup or a trap.
class GardenLotusScoop extends Component with HasGameReference<MonPinballGame> {
  GardenLotusScoop() : super(priority: 4);

  static final center = Vector2(14, 28.8);
  PinballBall? _heldBall;
  double _holdRemaining = 0;
  double _cooldown = 0;
  double _elapsed = 0;
  double _exitSide = 1;
  bool get isActive =>
      game.currentWorld == PinballWorld.garden && game.usesSecondaryWorldDevice;
  bool get isHolding => _heldBall != null;

  void resetBallState() {
    _heldBall = null;
    _holdRemaining = 0;
    _cooldown = 0;
  }

  void selectLayout() {
    resetBallState();
    _elapsed = 0;
  }

  void updateBall(PinballBall ball, Vector2? from, double dt) {
    if (!isActive || dt <= 0) return;
    _elapsed += dt;
    _cooldown = math.max(0, _cooldown - dt);
    if (_heldBall != null) {
      _holdRemaining -= dt;
      if (_holdRemaining <= 0) {
        _heldBall = null;
        _cooldown = 1.0;
        ball.body.setType(BodyType.dynamic);
        ball.body.setAwake(true);
        ball.body.linearVelocity = Vector2(_exitSide * 14, -30);
        game.addScore(150, center, const Color(0xFFFFBDE2), '수련 발사');
      }
      return;
    }
    if (_cooldown > 0 ||
        from == null ||
        ball.body.bodyType != BodyType.dynamic ||
        ball.body.linearVelocity.y <= 0 ||
        from.y > center.y + 0.4) {
      return;
    }
    final delta = ball.position - from;
    final t = delta.length2 == 0
        ? 0.0
        : ((center - from).dot(delta) / delta.length2).clamp(0.0, 1.0);
    if ((from + delta * t).distanceTo(center) > 1.05) return;
    _exitSide = from.x < center.x ? 1 : -1;
    _heldBall = ball;
    _holdRemaining = 0.3;
    ball.body.setType(BodyType.static);
    ball.body.setTransform(center, 0);
    ball.body.linearVelocity = Vector2.zero();
  }

  @override
  void render(Canvas canvas) {
    if (!isActive) return;
    canvas.save();
    canvas.translate(center.x, center.y);
    for (var petal = 0; petal < 8; petal++) {
      canvas.save();
      canvas.rotate(petal * math.pi / 4);
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(0, -0.92),
          width: isHolding ? 0.58 : 0.85,
          height: isHolding ? 1.05 : 1.45,
        ),
        Paint()
          ..color = petal.isEven
              ? const Color(0xFFE89CCB)
              : const Color(0xFFB37BAA),
      );
      canvas.restore();
    }
    canvas.drawCircle(
      Offset.zero,
      1.05,
      Paint()
        ..color = const Color(0xFF315C65)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset.zero,
      1.05,
      Paint()
        ..color = const Color(0xFFFFE3A8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHolding ? 0.14 : 0.06,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: 0.85),
      -math.pi / 2,
      math.pi * 2 * (isHolding ? _holdRemaining / 0.3 : 0.15),
      false,
      Paint()
        ..color = const Color(0xFFFFE9B5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.12,
    );
    final ripple = 1.8 + math.sin(_elapsed * 2) * 0.12;
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: ripple),
      0.2,
      math.pi * 0.7,
      false,
      Paint()
        ..color = const Color(0x5575CDBD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.045,
    );
    canvas.restore();
  }
}

/// A painted directional lane with one bounded kick for each forward entry.
class NeonBoostRail extends Component with HasGameReference<MonPinballGame> {
  NeonBoostRail() : super(priority: 3);

  static final start = Vector2(21.5, 36.2);
  static final end = Vector2(19.1, 32.6);
  static final _direction = (end - start)..normalize();
  static final _length = start.distanceTo(end);
  static final _angle = math.atan2(_direction.y, _direction.x);
  static const _region = Rect.fromLTRB(-0.3, -0.75, 4.63, 0.75);
  bool _inside = false;
  double _cooldown = 0;
  double _flash = 0;
  double _elapsed = 0;
  bool get isActive =>
      game.currentWorld == PinballWorld.neon && game.usesSecondaryWorldDevice;

  void resetBallState() {
    _inside = false;
    _cooldown = 0;
    _flash = 0;
  }

  void selectLayout() {
    resetBallState();
    _elapsed = 0;
  }

  Vector2 _toLocal(Vector2 at) {
    final delta = at - start;
    return Vector2(
      delta.dot(_direction),
      delta.x * -_direction.y + delta.y * _direction.x,
    );
  }

  void updateBall(PinballBall ball, Vector2? from, double dt) {
    if (!isActive || dt <= 0) return;
    _elapsed += dt;
    _cooldown = math.max(0, _cooldown - dt);
    _flash = math.max(0, _flash - dt * 3);
    if (from == null || ball.body.bodyType != BodyType.dynamic) return;
    final local = _toLocal(ball.position);
    final inside = _region.contains(Offset(local.x, local.y));
    if (!_inside &&
        _cooldown <= 0 &&
        _crossesRegion(_toLocal(from), local, _region) &&
        ball.body.linearVelocity.dot(_direction) > 2) {
      final speed = (ball.body.linearVelocity.length + 24).clamp(32.0, 60.0);
      ball.body.linearVelocity = _direction * speed;
      _cooldown = 0.35;
      _flash = 1;
      game.addScore(100, ball.position, const Color(0xFF7BFFF2), '가속 레일');
    }
    _inside = inside;
  }

  @override
  void render(Canvas canvas) {
    if (!isActive) return;
    canvas.save();
    canvas.translate(start.x, start.y);
    canvas.rotate(_angle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(_region, const Radius.circular(0.3)),
      Paint()..color = const Color(0x55235F76),
    );
    final edge = Paint()
      ..color = Color.lerp(const Color(0xFF46DAD3), Colors.white, _flash)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.07;
    canvas.drawRRect(
      RRect.fromRectAndRadius(_region, const Radius.circular(0.3)),
      edge,
    );
    final offset = (_elapsed * 1.8) % 1.1;
    for (var x = offset; x < _length; x += 1.1) {
      canvas.drawPath(
        Path()
          ..moveTo(x - 0.3, -0.4)
          ..lineTo(x + 0.15, 0)
          ..lineTo(x - 0.3, 0.4),
        edge,
      );
    }
    canvas.restore();
  }
}

/// A horizontal current; gravity and an open vertical escape stay intact.
class AbyssCurrent extends Component with HasGameReference<MonPinballGame> {
  AbyssCurrent() : super(priority: 2);

  static const region = Rect.fromLTRB(10, 26.5, 18, 31.5);
  double _elapsed = 0;
  bool get isActive =>
      game.currentWorld == PinballWorld.abyss && game.usesSecondaryWorldDevice;
  double get _direction => (_elapsed / 3).floor().isEven ? 1 : -1;

  void selectLayout() {
    _elapsed = 0;
  }

  void updateBall(PinballBall ball, Vector2? from, double dt) {
    if (!isActive || dt <= 0) return;
    _elapsed += dt;
    if (from == null ||
        ball.body.bodyType != BodyType.dynamic ||
        !region.contains(Offset(ball.position.x, ball.position.y))) {
      return;
    }
    // Accelerate toward a bounded horizontal flow rather than cancelling y.
    final velocity = ball.body.linearVelocity;
    final target = _direction * 10;
    final change = (target - velocity.x).clamp(-12 * dt, 12 * dt);
    ball.body.linearVelocity = Vector2(velocity.x + change, velocity.y);
  }

  @override
  void render(Canvas canvas) {
    if (!isActive) return;
    final warning = _elapsed % 3 > 2.4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(region, const Radius.circular(0.6)),
      Paint()..color = const Color(0x222B9FB8),
    );
    final flow = Paint()
      ..color = warning ? const Color(0xFFD6E8A5) : const Color(0xFF61BACB)
      ..strokeWidth = 0.065
      ..style = PaintingStyle.stroke;
    for (var row = 0; row < 3; row++) {
      final y = 27.3 + row * 1.5;
      for (var col = 0; col < 4; col++) {
        final x = 10.6 + (col * 1.9 + _elapsed * _direction) % 6.8;
        canvas.drawPath(
          Path()
            ..moveTo(x - _direction * 0.55, y)
            ..lineTo(x + _direction * 0.3, y)
            ..moveTo(x, y - 0.22)
            ..lineTo(x + _direction * 0.3, y)
            ..lineTo(x, y + 0.22),
          flow,
        );
      }
    }
    final remaining = 1 - (_elapsed % 3) / 3;
    canvas.drawLine(
      const Offset(10.4, 31.15),
      Offset(10.4 + 7.2 * remaining, 31.15),
      flow..strokeWidth = 0.1,
    );
  }
}

bool _crossesRegion(Vector2 from, Vector2 to, Rect region) {
  var low = 0.0;
  var high = 1.0;
  for (final axis in [
    (from.x, to.x - from.x, region.left, region.right),
    (from.y, to.y - from.y, region.top, region.bottom),
  ]) {
    if (axis.$2.abs() < 1e-9) {
      if (axis.$1 < axis.$3 || axis.$1 > axis.$4) return false;
      continue;
    }
    final first = (axis.$3 - axis.$1) / axis.$2;
    final last = (axis.$4 - axis.$1) / axis.$2;
    low = math.max(low, math.min(first, last));
    high = math.min(high, math.max(first, last));
    if (low > high) return false;
  }
  return true;
}
