import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'pinball_style.dart';

/// Static garden art contains no collision objects: physics stays independent.
class MoonlitTable extends Component {
  MoonlitTable(this.garden) : super(priority: -100);

  static const double centerX = 14;
  static const moonCenter = Offset(centerX, 36.8);
  static const board = Rect.fromLTWH(0, 0, 28, 56);

  /// The inside of the gold frame; the boss is clipped to it.
  static final playfield = RRect.fromRectAndRadius(
    board.deflate(0.16),
    const Radius.circular(3),
  );

  final ui.Image garden;

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.clipRRect(playfield);
    // Cover the portrait board, keeping the garden's centre line on x = 14.
    final sourceWidth = garden.height * board.width / board.height;
    canvas.drawImageRect(
      garden,
      Rect.fromLTWH(
        (garden.width - sourceWidth) / 2,
        0,
        sourceWidth,
        garden.height.toDouble(),
      ),
      board,
      Paint()..filterQuality = FilterQuality.medium,
    );
    // Quiet the middle so balls and jewels read; foliage stays at the rim.
    canvas.drawRect(
      board,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.15),
          radius: 0.95,
          colors: [Color(0xA6070D26), Color(0x70070D26), Color(0x18070D26)],
          stops: [0, 0.62, 1],
        ).createShader(board),
    );
    _drawGuides(canvas);
    canvas.restore();

    canvas.drawRRect(
      playfield,
      Paint()
        ..color = const Color(0xFF030614)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
    canvas.drawRRect(
      playfield,
      PinballStyle.metal(board)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.32,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(board.deflate(0.42), const Radius.circular(2.8)),
      Paint()
        ..color = PinballStyle.gold.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.05,
    );
  }

  void _drawGuides(Canvas canvas) {
    final faint = Paint()
      ..color = PinballStyle.cyan.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.04;
    for (final radius in [3.4, 4.4, 6.2]) {
      canvas.drawCircle(moonCenter, radius, faint);
    }
    canvas.drawLine(
      const Offset(centerX, 20.4),
      const Offset(centerX, 52),
      Paint()
        ..color = PinballStyle.gold.withValues(alpha: 0.28)
        ..strokeWidth = 0.035,
    );
    _diamond(canvas, const Offset(centerX, 22.6), 0.32, PinballStyle.gold);
    _diamond(canvas, const Offset(centerX, 24.7), 0.24, PinballStyle.red);
    _diamond(canvas, const Offset(centerX, 44.2), 0.18, PinballStyle.gold);
    // Hanging lamps above the two spinners.
    for (final lamp in const [(5.75, 24.6, 28.6), (20.7, 22.4, 28.6)]) {
      canvas.drawLine(
        Offset(lamp.$1, lamp.$2),
        Offset(lamp.$1, lamp.$3),
        Paint()
          ..color = PinballStyle.gold.withValues(alpha: 0.45)
          ..strokeWidth = 0.03,
      );
      _diamond(canvas, Offset(lamp.$1, lamp.$2), 0.34, PinballStyle.text);
    }
    for (final flower in const [
      Offset(4.6, 26.6),
      Offset(9.8, 33.4),
      Offset(18.2, 33.4),
      Offset(9.4, 36.8),
      Offset(18.6, 36.8),
    ]) {
      _sakura(canvas, flower, 0.42);
    }
  }
}

/// Gold trim above the walls: the crest arch and the rail rivets.
class TableTrim extends Component {
  TableTrim() : super(priority: -8);

  @override
  void render(Canvas canvas) {
    final arch = Path()
      ..moveTo(9.4, 0.2)
      ..cubicTo(10.4, -0.85, 17.6, -0.85, 18.6, 0.2);
    for (final (width, color) in [
      (0.5, const Color(0xFF030614)),
      (0.24, PinballStyle.gold),
    ]) {
      canvas.drawPath(
        arch,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(10.2, 0.35)
        ..cubicTo(11.2, -0.4, 16.8, -0.4, 17.8, 0.35),
      Paint()
        ..color = PinballStyle.gold.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.06,
    );
    _stud(canvas, const Offset(centerX, -0.55), 0.3);

    for (final rivet in const [
      Offset(1.1, 17.5),
      Offset(1.1, 24.7),
      Offset(1.1, 28.2),
      Offset(1.1, 40.6),
      Offset(26.9, 17.5),
      Offset(26.9, 24.7),
      Offset(26.9, 35.3),
      Offset(2.2, 2.4),
      Offset(25.8, 2.4),
      Offset(7.2, 0.6),
      Offset(20.8, 0.6),
    ]) {
      canvas.drawCircle(rivet, 0.36, Paint()..color = const Color(0xFF0A0E22));
      canvas.drawCircle(
        rivet,
        0.32,
        Paint()
          ..color = PinballStyle.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.09,
      );
    }
    // The lane's inner wall ends in a gold cap where the orbit drops back in.
    canvas.drawLine(
      const Offset(24.4, 21.05),
      const Offset(24.4, 24.4),
      Paint()
        ..color = PinballStyle.gold
        ..strokeWidth = 0.16
        ..strokeCap = StrokeCap.round,
    );
    _stud(canvas, const Offset(24.4, 21), 0.24);
  }

  static const double centerX = MoonlitTable.centerX;
}

void _stud(Canvas canvas, Offset center, double radius) {
  canvas.drawCircle(
    center,
    radius,
    PinballStyle.metal(Rect.fromCircle(center: center, radius: radius)),
  );
  canvas.drawCircle(
    center - Offset(radius, radius) * 0.3,
    radius * 0.3,
    Paint()..color = Colors.white.withValues(alpha: 0.55),
  );
}

void _diamond(Canvas canvas, Offset center, double size, Color color) {
  final path = Path()
    ..moveTo(center.dx, center.dy - size)
    ..lineTo(center.dx + size * 0.7, center.dy)
    ..lineTo(center.dx, center.dy + size)
    ..lineTo(center.dx - size * 0.7, center.dy)
    ..close();
  canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.85));
  canvas.drawPath(
    path,
    Paint()
      ..color = PinballStyle.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05,
  );
}

void _sakura(Canvas canvas, Offset center, double radius) {
  final petal = Paint()..color = const Color(0xFF9C7DC4).withValues(alpha: 0.7);
  for (var i = 0; i < 5; i++) {
    final a = -math.pi / 2 + i * math.pi * 2 / 5;
    canvas.drawCircle(
      center + Offset(math.cos(a), math.sin(a)) * radius * 0.5,
      radius * 0.36,
      petal,
    );
  }
  canvas.drawCircle(
    center,
    radius * 0.18,
    Paint()..color = PinballStyle.gold.withValues(alpha: 0.8),
  );
}

/// The moon emblem bumper, drawn around its own centre; it brightens on hits.
void drawMoonBumper(Canvas canvas, double radius, double flash) {
  canvas.save();
  canvas.scale(radius / 2.6);
  const center = Offset.zero;
  canvas.drawCircle(center, 2.6, Paint()..color = const Color(0xE60B2633));
  canvas.drawCircle(
    center,
    2.6,
    PinballStyle.metal(Rect.fromCircle(center: center, radius: 2.6))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.14,
  );
  canvas.save();
  canvas.clipPath(
    Path()..addOval(Rect.fromCircle(center: center, radius: 1.25)),
  );
  canvas.drawCircle(center, 1.25, Paint()..color = PinballStyle.text);
  final wave = Paint()
    ..color = const Color(0xFF2F5866)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.16;
  for (final dy in [-0.5, 0.05, 0.6]) {
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - 1.4, center.dy + dy)
        ..cubicTo(
          center.dx - 0.4,
          center.dy - 0.7 + dy,
          center.dx + 0.4,
          center.dy + 0.7 + dy,
          center.dx + 1.4,
          center.dy + dy,
        ),
      wave,
    );
  }
  canvas.restore();
  // Two reed-like ripples under the disc.
  final ripple = Paint()
    ..color = PinballStyle.cyan.withValues(alpha: 0.35)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.05;
  for (final width in [2.4, 3.4]) {
    canvas.drawArc(
      Rect.fromCenter(
        center: center + const Offset(0, 1.75),
        width: width,
        height: 0.6,
      ),
      0,
      math.pi,
      false,
      ripple,
    );
  }
  if (flash > 0) {
    canvas.drawCircle(
      center,
      2.95,
      Paint()
        ..color = PinballStyle.text.withValues(alpha: flash * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.12,
    );
  }
  canvas.restore();
}

/// A small gold post with a coloured lens, for the mid-field mini bumpers.
void drawGoldPost(Canvas canvas, double radius, Color color, double flash) {
  final bounds = Rect.fromCircle(center: Offset.zero, radius: radius);
  canvas.drawCircle(
    const Offset(0, 0.14),
    radius,
    Paint()..color = const Color(0xDD020613),
  );
  canvas.drawCircle(Offset.zero, radius, PinballStyle.metal(bounds));
  canvas.drawCircle(
    Offset.zero,
    radius * 0.62,
    Paint()..color = const Color(0xFF14102A),
  );
  canvas.drawCircle(
    Offset.zero,
    radius * 0.5,
    PinballStyle.lens(bounds.deflate(radius * 0.5), color, flash),
  );
  if (flash > 0) {
    canvas.drawCircle(
      Offset.zero,
      radius + 0.2,
      Paint()
        ..color = color.withValues(alpha: flash * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.08,
    );
  }
}

/// Draw a jewel inside the physical bumper's existing circular footprint.
void drawJewelBumper(Canvas canvas, double radius, Color color, double flash) {
  final outline = Path();
  for (var i = 0; i < 8; i++) {
    final angle = math.pi / 8 + i * math.pi / 4;
    final p = Offset(math.cos(angle), math.sin(angle)) * radius;
    if (i == 0) {
      outline.moveTo(p.dx, p.dy);
    } else {
      outline.lineTo(p.dx, p.dy);
    }
  }
  outline.close();
  canvas.drawPath(
    outline.shift(const Offset(0, 0.14)),
    Paint()..color = Colors.black,
  );
  canvas.drawPath(outline, Paint()..color = const Color(0xFF090B1C));
  canvas.drawPath(
    outline,
    Paint()
      ..color = PinballStyle.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.085,
  );
  for (var i = 0; i < 8; i++) {
    final a = math.pi / 8 + i * math.pi / 4;
    final b = a + math.pi / 4;
    final p1 = Offset(math.cos(a), math.sin(a)) * radius * 0.86;
    final p2 = Offset(math.cos(b), math.sin(b)) * radius * 0.86;
    final facet = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p2.dx * 0.52, p2.dy * 0.52)
      ..lineTo(p1.dx * 0.52, p1.dy * 0.52)
      ..close();
    canvas.drawPath(
      facet,
      Paint()
        ..color = Color.lerp(color, i < 4 ? Colors.black : Colors.white, 0.2)!,
    );
    canvas.drawPath(
      facet,
      Paint()
        ..color = const Color(0xFF101528)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.045,
    );
  }
  final lens = Rect.fromCircle(center: Offset.zero, radius: radius * 0.43);
  canvas.drawCircle(
    Offset.zero,
    radius * 0.46,
    Paint()..color = PinballStyle.text,
  );
  canvas.drawCircle(
    Offset.zero,
    radius * 0.42,
    PinballStyle.lens(lens, color, flash),
  );
  if (flash > 0) {
    canvas.drawCircle(
      Offset.zero,
      radius + 0.25,
      Paint()
        ..color = color.withValues(alpha: flash * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.08,
    );
  }
}
