import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import 'pinball_game.dart';
import 'pinball_progress.dart';

/// A motor-driven electrode. Its painted arms are its two physical rectangles.
class NeonElectrode extends BodyComponent<MonPinballGame> {
  NeonElectrode() : super(priority: 5, renderBody: false);

  static const halfLength = 3.5;
  static const halfThickness = 0.18;
  static final electrodeCenter = Vector2(14, 28.8);

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef(
        type: BodyType.kinematic,
        position: electrodeCenter,
        active: game.currentWorld == PinballWorld.neon,
        allowSleep: false,
      ),
    );
    for (final angle in [0.0, math.pi / 2]) {
      body.createFixture(
        FixtureDef(
          PolygonShape()
            ..setAsBox(halfLength, halfThickness, Vector2.zero(), angle),
          friction: 0.05,
          restitution: 0.9,
        ),
      );
    }
    return body;
  }

  void selectWorld() {
    body.setActive(game.currentWorld == PinballWorld.neon);
    body.setTransform(electrodeCenter, 0);
    body.angularVelocity = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!body.isActive) return;
    body.angularVelocity = switch (game.configuration!.difficulty) {
      PinballDifficulty.easy => 0.8,
      PinballDifficulty.normal => 0.95,
      PinballDifficulty.hard => 1.1,
    };
  }

  @override
  void render(Canvas canvas) {
    if (!body.isActive) return;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.055
      ..color = const Color(0xFF98FFFF);
    for (var arm = 0; arm < 2; arm++) {
      const bounds = Rect.fromLTRB(
        -halfLength,
        -halfThickness,
        halfLength,
        halfThickness,
      );
      canvas.drawRect(bounds, Paint()..color = const Color(0xFF174C65));
      canvas.drawRect(bounds, edge);
      for (final end in [-1.0, 1.0]) {
        canvas.drawLine(
          Offset(end * 2.85, -halfThickness),
          Offset(end * 2.85, halfThickness),
          edge..color = const Color(0xFFFF87DD),
        );
      }
      canvas.rotate(math.pi / 2);
    }
    canvas.drawCircle(
      Offset.zero,
      0.42,
      Paint()..color = const Color(0xFF16394C),
    );
    canvas.drawCircle(
      Offset.zero,
      0.28,
      Paint()..color = const Color(0xFF83F8ED),
    );
  }
}

/// Slow side-to-side stone gates leave both the center and wall lanes open.
class AbyssSluice extends BodyComponent<MonPinballGame> {
  AbyssSluice({required this.right}) : super(priority: 5, renderBody: false);

  static const halfWidth = 0.28;
  static const halfHeight = 2.4;
  static const travel = 0.8;
  static const period = 5.0;
  final bool right;
  double _elapsed = 0;

  Vector2 get _center => Vector2(right ? 21 : 6.5, 29);
  double get _direction => right ? -1 : 1;

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef(
        type: BodyType.kinematic,
        position: _center,
        linearVelocity: Vector2(_direction * travel * math.pi * 2 / period, 0),
        active: game.currentWorld == PinballWorld.abyss,
        allowSleep: false,
      ),
    );
    body.createFixture(
      FixtureDef(
        PolygonShape()..setAsBoxXY(halfWidth, halfHeight),
        friction: 0.08,
        restitution: 0.85,
      ),
    );
    return body;
  }

  void selectWorld() {
    _elapsed = 0;
    body.setActive(game.currentWorld == PinballWorld.abyss);
    body.setTransform(_center, 0);
    body.linearVelocity = Vector2(
      body.isActive ? _direction * travel * math.pi * 2 / period : 0,
      0,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!body.isActive || dt <= 0) return;
    _elapsed += dt;
    final nextX =
        _center.x +
        _direction * travel * math.sin((_elapsed + dt) * math.pi * 2 / period);
    body.linearVelocity = Vector2((nextX - position.x) / dt, 0);
  }

  @override
  void render(Canvas canvas) {
    if (!body.isActive) return;
    const bounds = Rect.fromLTRB(
      -halfWidth,
      -halfHeight,
      halfWidth,
      halfHeight,
    );
    canvas.drawRect(bounds, Paint()..color = const Color(0xFF526B73));
    canvas.drawRect(
      bounds,
      Paint()
        ..color = const Color(0xFFB5D7CB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.06,
    );
    final rune = Paint()
      ..color = const Color(0xFF77E4DD)
      ..strokeWidth = 0.07;
    for (var y = -1.8; y < 2; y += 0.9) {
      canvas.drawLine(Offset(-0.15, y), Offset(0.15, y + 0.2), rune);
      canvas.drawLine(Offset(0, y - 0.17), Offset(0, y + 0.37), rune);
    }
  }
}

/// Circular trim follows the same silhouette as the existing circle fixture.
void drawWorldBumper(
  Canvas canvas,
  PinballWorld world,
  BumperStyle style,
  double radius,
  double flash,
) {
  final neon = world == PinballWorld.neon;
  final accent = neon ? const Color(0xFF83FFF4) : const Color(0xFF82DCD2);
  canvas.drawCircle(
    Offset.zero,
    radius,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: neon
            ? [const Color(0xFF235C78), const Color(0xFF111D39)]
            : [const Color(0xFF708B87), const Color(0xFF263B49)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius)),
  );
  final edge = Paint()
    ..color = Color.lerp(accent, Colors.white, flash)!
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.1;
  canvas.drawCircle(Offset.zero, radius - 0.05, edge);
  canvas.drawCircle(Offset.zero, radius * 0.72, edge..strokeWidth = 0.055);
  if (neon) {
    final inset = radius * 0.42;
    for (final side in [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(side * inset, -radius * 0.42),
        Offset(side * inset, radius * 0.42),
        edge..strokeWidth = style == BumperStyle.post ? 0.1 : 0.2,
      );
    }
    canvas.drawLine(Offset(-inset, 0), Offset(inset, 0), edge);
  } else {
    final rune = Path()
      ..moveTo(0, -radius * 0.48)
      ..lineTo(radius * 0.32, 0)
      ..lineTo(0, radius * 0.48)
      ..lineTo(-radius * 0.32, 0)
      ..close();
    canvas.drawPath(rune, edge..strokeWidth = 0.13);
    canvas.drawLine(Offset(0, -radius * 0.48), Offset(0, radius * 0.48), edge);
  }
}

void drawWorldSlingshot(
  Canvas canvas,
  PinballWorld world,
  List<Vector2> vertices,
  double flash,
) {
  final neon = world == PinballWorld.neon;
  final points = vertices.map((vertex) => Offset(vertex.x, vertex.y)).toList();
  final center = points.reduce((a, b) => a + b) / points.length.toDouble();
  final outline = Path()..addPolygon(points, true);
  final inset = points
      .map((point) => center + (point - center) * 0.78)
      .toList();
  canvas.drawPath(
    outline,
    Paint()..color = neon ? const Color(0xFF172840) : const Color(0xFF617872),
  );
  canvas.drawPath(
    Path()..addPolygon(inset, true),
    Paint()..color = neon ? const Color(0xFF102539) : const Color(0xFF354C4D),
  );
  final accent = neon ? const Color(0xFF7EF4EB) : const Color(0xFFB3C5A0);
  final line = Paint()
    ..color = Color.lerp(accent, Colors.white, flash)!
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.095
    ..strokeJoin = StrokeJoin.round;
  canvas.drawPath(outline, line);
  if (neon) {
    for (var i = 0; i < inset.length; i++) {
      final from = inset[i];
      final end = center + (inset[(i + 1) % inset.length] - center) * 0.45;
      canvas.drawPath(
        Path()
          ..moveTo(from.dx, from.dy)
          ..lineTo(center.dx, from.dy)
          ..lineTo(center.dx, end.dy),
        line..strokeWidth = 0.055,
      );
      canvas.drawCircle(from, 0.12, Paint()..color = const Color(0xFFFF8DDD));
    }
  } else {
    final rune = Path()
      ..moveTo(center.dx, center.dy - 0.65)
      ..lineTo(center.dx + 0.4, center.dy)
      ..lineTo(center.dx, center.dy + 0.65)
      ..lineTo(center.dx - 0.4, center.dy)
      ..close();
    canvas.drawPath(rune, line..strokeWidth = 0.1);
    for (final point in inset) {
      canvas.drawLine(point, center + (point - center) * 0.62, line);
    }
  }
}

void drawWorldTarget(
  Canvas canvas,
  PinballWorld world,
  Rect bounds,
  double flash,
) {
  final neon = world == PinballWorld.neon;
  final accent = neon ? const Color(0xFF83FFF4) : const Color(0xFF8CE0C7);
  canvas.drawRect(
    bounds,
    Paint()..color = neon ? const Color(0xFF1D3048) : const Color(0xFF627870),
  );
  final line = Paint()
    ..color = Color.lerp(accent, Colors.white, flash)!
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.07;
  canvas.drawRect(bounds.deflate(0.035), line);
  if (neon) {
    for (final side in [-1.0, 1.0]) {
      final cap = Rect.fromCenter(
        center: Offset(side * 1.14, 0),
        width: 0.45,
        height: 0.8,
      );
      canvas.drawRect(cap, Paint()..color = const Color(0xFF55778A));
      canvas.drawLine(Offset(side * 0.9, 0), Offset(side * 0.5, 0), line);
    }
    canvas.drawRect(const Rect.fromLTWH(-0.52, -0.23, 1.04, 0.46), line);
    canvas.drawLine(const Offset(-0.4, 0.12), const Offset(0.4, -0.12), line);
  } else {
    for (final x in [-0.75, 0.0, 0.75]) {
      canvas.drawPath(
        Path()
          ..moveTo(x - 0.2, -0.23)
          ..lineTo(x, 0)
          ..lineTo(x + 0.2, -0.23)
          ..moveTo(x, 0)
          ..lineTo(x, 0.3),
        line,
      );
    }
    canvas.drawLine(
      Offset(bounds.left + 0.15, bounds.bottom - 0.1),
      Offset(bounds.left + 0.8, bounds.bottom - 0.1),
      Paint()
        ..color = const Color(0xFF79A06F)
        ..strokeWidth = 0.1,
    );
  }
}
