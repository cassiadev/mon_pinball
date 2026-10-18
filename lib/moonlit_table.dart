import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'pinball_style.dart';

/// Static garden art contains no collision objects: physics stays independent.
class MoonlitTable extends Component {
  MoonlitTable(this.garden) : super(priority: -100);

  static const double centerX = 14;
  static const moonCenter = Offset(centerX, 28.5);

  final ui.Image garden;

  @override
  void render(Canvas canvas) {
    const board = Rect.fromLTWH(0, 0, 28, 48);
    final frame = RRect.fromRectAndRadius(
      board.deflate(0.28),
      const Radius.circular(2.1),
    );
    canvas.save();
    canvas.clipRRect(frame);
    canvas.drawImageRect(
      garden,
      Rect.fromLTWH(0, 0, garden.width.toDouble(), garden.height.toDouble()),
      board,
      Paint()..filterQuality = FilterQuality.medium,
    );
    // Fade printed art inside the table so actual ball/obstacles stay distinct.
    canvas.drawRRect(frame, Paint()..color = const Color(0x22060A20));
    _drawMoon(canvas);
    canvas.restore();
    canvas.drawRRect(
      frame,
      PinballStyle.metal(board)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.22,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(board.deflate(0.47), const Radius.circular(1.9)),
      Paint()
        ..color = PinballStyle.violet.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.045,
    );
  }

  void _drawMoon(Canvas canvas) {
    // All central objects share x=14, independent of the right launcher lane.
    const center = moonCenter;
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        center,
        2.65 + i * 0.44,
        Paint()
          ..color = (i == 0 ? PinballStyle.gold : PinballStyle.cyan).withValues(
            alpha: i == 0 ? 0.85 : 0.16,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == 0 ? 0.065 : 0.025,
      );
    }
    canvas.drawCircle(center, 2.56, Paint()..color = const Color(0xCC102B3D));
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: 1.13)),
    );
    canvas.drawCircle(center, 1.13, Paint()..color = PinballStyle.text);
    final wave = Paint()
      ..color = const Color(0xFF386271)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.12;
    for (final dy in [-0.48, 0.03, 0.54]) {
      canvas.drawPath(
        Path()
          ..moveTo(12.7, 28.5 + dy)
          ..cubicTo(13.7, 27.8 + dy, 14.3, 29.2 + dy, 15.3, 28.5 + dy),
        wave,
      );
    }
    canvas.restore();
    for (final y in [23.0, 24.3, 25.6, 32.6, 33.9]) {
      canvas.drawCircle(
        Offset(14, y),
        0.045,
        Paint()..color = PinballStyle.gold,
      );
    }
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
