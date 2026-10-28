import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'pinball_game.dart';
import 'pinball_progress.dart';

Color selectWorldAccent(PinballWorld world) => switch (world) {
  PinballWorld.garden => const Color(0xFFEAC66F),
  PinballWorld.neon => const Color(0xFF71F3EE),
  PinballWorld.abyss => const Color(0xFF77B7F6),
};

/// New worlds keep the proven collision geometry and replace its painted plate.
class JourneyTable extends Component with HasGameReference<MonPinballGame> {
  JourneyTable() : super(priority: -90);

  @override
  void render(Canvas canvas) {
    final world = game.currentWorld;
    if (world == PinballWorld.garden) return;
    final accent = selectWorldAccent(world);
    const bounds = Rect.fromLTWH(0.8, 0.4, 26.4, 55.2);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(bounds, const Radius.circular(3)));
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          const Offset(28, 56),
          world == PinballWorld.neon
              ? const [Color(0xFF071228), Color(0xFF26113E), Color(0xFF060B1D)]
              : const [Color(0xFF06283B), Color(0xFF081A2C), Color(0xFF030C1C)],
          const [0, 0.5, 1],
        ),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.045
      ..color = accent.withValues(alpha: 0.16);
    if (world == PinballWorld.neon) {
      for (var x = 0.0; x < 30; x += 2) {
        canvas.drawLine(Offset(x, 0), Offset(x, 56), line);
      }
      for (var y = 0.0; y < 56; y += 2) {
        canvas.drawLine(Offset(0, y), Offset(28, y), line);
      }
      for (var i = 0; i < 9; i++) {
        final x = 2.0 + i * 3;
        final h = 4.0 + (i * 7 % 11);
        canvas.drawRect(
          Rect.fromLTWH(x, 25 - h, 1.8, h),
          Paint()..color = accent.withValues(alpha: 0.07),
        );
        canvas.drawLine(Offset(x, 25 - h), Offset(x + 1.8, 25 - h), line);
      }
      _drawCaption(canvas, 'NEON CIRCUIT', const Offset(14, 35), accent);
    } else {
      for (var ring = 0; ring < 7; ring++) {
        canvas.drawCircle(const Offset(14, 26), 3.0 + ring * 2.1, line);
      }
      for (var i = 0; i < 14; i++) {
        final x = 2.0 + (i * 17 % 24);
        final y = 4.0 + (i * 13 % 46);
        canvas.drawCircle(Offset(x, y), 0.12 + i % 3 * 0.07, line);
      }
      final pillar = Paint()..color = accent.withValues(alpha: 0.08);
      for (final x in [3.0, 23.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 5, 1.2, 32),
            const Radius.circular(0.2),
          ),
          pillar,
        );
      }
      _drawCaption(canvas, 'ABYSSAL RELIC', const Offset(14, 35), accent);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds.deflate(0.3), const Radius.circular(2.7)),
      line
        ..color = accent.withValues(alpha: 0.5)
        ..strokeWidth = 0.09,
    );
    canvas.restore();
  }
}

class JourneyObjectives extends Component
    with HasGameReference<MonPinballGame> {
  JourneyObjectives() : super(priority: 42);

  @override
  void render(Canvas canvas) {
    if (game.configuration == null) return;
    final accent = selectWorldAccent(game.currentWorld);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.12;
    for (final (id, at) in const [
      ('jewel-left', Offset(9.6, 13.7)),
      ('jewel-right', Offset(18.4, 13.7)),
      ('jewel-center', Offset(14, 18.1)),
    ]) {
      if (game.isMissionHitLit(id)) {
        canvas.drawCircle(at, 2.5, paint..color = accent);
      }
    }
    for (var index = 0; index < 4; index++) {
      if (game.isMissionHitLit('target-$index')) {
        final at = const [
          Offset(5.25, 39.3),
          Offset(9.9, 40.85),
          Offset(18.1, 40.85),
          Offset(22.75, 39.3),
        ][index];
        canvas.drawCircle(at, 1.9, paint..color = accent);
      }
    }
    if (game.isGateMission) {
      final active = game.gateArmed;
      final color = active ? accent : accent.withValues(alpha: 0.25);
      canvas.drawOval(
        const Rect.fromLTWH(11.6, 2.5, 4.8, 3),
        paint..color = color,
      );
      canvas.drawOval(
        const Rect.fromLTWH(12, 2.8, 4, 2.4),
        paint..color = color.withValues(alpha: active ? 0.55 : 0.15),
      );
      _drawCaption(
        canvas,
        active ? 'GATE OPEN' : 'CHARGE',
        const Offset(14, 6.4),
        color,
        size: 0.65,
      );
    }
  }
}

class JourneyBoss extends Component with HasGameReference<MonPinballGame> {
  JourneyBoss() : super(priority: -20);

  @override
  void render(Canvas canvas) {
    final boss = game.boss;
    if (!boss.visible ||
        boss.vanished ||
        game.currentWorld == PinballWorld.garden) {
      return;
    }
    final color = selectWorldAccent(game.currentWorld);
    final at = boss.position.toOffset();
    final fade = boss.defeated ? 1 - boss.defeatProgress : 1.0;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    final fill = Paint()
      ..shader = ui.Gradient.radial(const Offset(0, -1), 6, [
        color.withValues(alpha: fade * 0.75),
        const Color(0xFF0A1533).withValues(alpha: fade),
      ]);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.12
      ..color = color.withValues(alpha: fade);
    if (game.currentWorld == PinballWorld.neon) {
      final body = Path()
        ..moveTo(0, -4.8)
        ..lineTo(2.4, -3)
        ..lineTo(2, 2.5)
        ..lineTo(0, 3.5)
        ..lineTo(-2, 2.5)
        ..lineTo(-2.4, -3)
        ..close();
      canvas.drawPath(body, fill);
      canvas.drawPath(body, edge);
      for (final side in [-1.0, 1.0]) {
        final rotor = Offset(side * 4.2, -1.2);
        canvas.drawLine(Offset(side * 1.7, -1.5), rotor, edge);
        canvas.drawOval(
          Rect.fromCenter(center: rotor, width: 4.2, height: 1.2),
          edge,
        );
        canvas.drawLine(
          rotor + const Offset(-2, 0),
          rotor + const Offset(2, 0),
          edge,
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-1.35, -2.8, 2.7, 0.55),
          const Radius.circular(0.2),
        ),
        Paint()..color = const Color(0xFFFF77CF).withValues(alpha: fade),
      );
    } else {
      for (var i = 0; i < 6; i++) {
        final side = i < 3 ? -1.0 : 1.0;
        final reach = 3.0 + i % 3 * 1.1;
        final wave = math.sin(boss.poseTime * 1.5 + i) * 0.5;
        final tentacle = Path()
          ..moveTo(side * 1.3, 0.2)
          ..cubicTo(
            side * reach,
            1,
            side * (reach + 1),
            4 + wave,
            side * (reach - 0.4),
            6 + wave,
          );
        canvas.drawPath(tentacle, edge..strokeWidth = 0.28);
      }
      canvas.drawOval(const Rect.fromLTWH(-2.4, -4.8, 4.8, 7.8), fill);
      canvas.drawOval(
        const Rect.fromLTWH(-2.4, -4.8, 4.8, 7.8),
        edge..strokeWidth = 0.12,
      );
      for (final side in [-1.0, 1.0]) {
        canvas.drawCircle(
          Offset(side * 0.95, -2.5),
          0.28,
          Paint()..color = const Color(0xFFE4F8FF).withValues(alpha: fade),
        );
      }
    }
    canvas.restore();
  }
}

void _drawCaption(
  Canvas canvas,
  String text,
  Offset center,
  Color color, {
  double size = 0.85,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Rajdhani',
        color: color,
        fontSize: size,
        letterSpacing: 0.14,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  painter.dispose();
}
