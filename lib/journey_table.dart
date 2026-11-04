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

/// Illustrated backplates stay independent of the world's collision objects.
class JourneyTable extends Component with HasGameReference<MonPinballGame> {
  JourneyTable() : super(priority: -90);

  static const _bounds = Rect.fromLTWH(0.8, 0.4, 26.4, 55.2);
  static final _frame = RRect.fromRectAndRadius(
    _bounds,
    const Radius.circular(3),
  );
  static const _magenta = Color(0xFFE77CE6);
  static const _brass = Color(0xFFBAA46D);
  final _blit = Paint()..filterQuality = FilterQuality.low;
  final _motion = Paint()..style = PaintingStyle.stroke;
  ui.Image? _baked;
  PinballWorld? _bakedWorld;
  double _bakedScale = 0;
  double _time = 0;

  @visibleForTesting
  ui.Image? get bakedArt => _baked;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final world = game.currentWorld;
    if (world == PinballWorld.garden) return;
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    final scale =
        (canvas.getTransform()[0].abs() * (view?.devicePixelRatio ?? 1)).clamp(
          1.0,
          100.0,
        );
    if (_baked == null ||
        _bakedWorld != world ||
        (scale - _bakedScale).abs() > 0.5) {
      _baked?.dispose();
      _baked = _bakeArt(world, scale);
      _bakedWorld = world;
      _bakedScale = scale;
    }
    final image = _baked!;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      _bounds,
      _blit,
    );
    _drawAmbientMotion(canvas, world);
  }

  @override
  void onRemove() {
    _baked?.dispose();
    _baked = null;
    super.onRemove();
  }

  ui.Image _bakeArt(PinballWorld world, double scale) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(scale)
      ..translate(-_bounds.left, -_bounds.top);
    _drawBackplate(canvas, world);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      (_bounds.width * scale).ceil(),
      (_bounds.height * scale).ceil(),
    );
    picture.dispose();
    return image;
  }

  void _drawBackplate(Canvas canvas, PinballWorld world) {
    final neon = world == PinballWorld.neon;
    final accent = selectWorldAccent(world);
    canvas.save();
    canvas.clipRRect(_frame);
    canvas.drawRect(
      _bounds,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          const Offset(25, 56),
          neon
              ? const [Color(0xFF09152A), Color(0xFF20112F), Color(0xFF070C1B)]
              : const [Color(0xFF092A36), Color(0xFF081F2B), Color(0xFF06121F)],
          const [0, 0.52, 1],
        ),
    );
    if (neon) {
      _drawCity(canvas, accent);
      _drawCircuitFloor(canvas, accent);
    } else {
      _drawRuins(canvas, accent);
      _drawRelicFloor(canvas, accent);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        _bounds.deflate(0.28),
        const Radius.circular(2.7),
      ),
      Paint()
        ..color = accent.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.08,
    );
    _drawCaption(
      canvas,
      neon ? 'NEON CIRCUIT' : 'ABYSSAL RELIC',
      const Offset(14, 33.5),
      accent.withValues(alpha: 0.65),
      size: 0.65,
    );
    canvas.restore();
  }

  void _drawCity(Canvas canvas, Color accent) {
    final fill = Paint();
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.045;
    // A distant skyline leaves the boss silhouette and middle lanes quiet.
    for (var i = 0; i < 13; i++) {
      final x = 0.9 + i * 2.1;
      final h = 3.4 + (i * 7 % 8);
      canvas.drawRect(
        Rect.fromLTWH(x, 19 - h, 1.7, h),
        fill..color = const Color(0xFF153044).withValues(alpha: 0.5),
      );
      canvas.drawLine(
        Offset(x, 19 - h),
        Offset(x + 1.7, 19 - h),
        line..color = accent.withValues(alpha: 0.12),
      );
    }
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(14, 0);
      canvas.scale(side, 1);
      for (var i = 0; i < 4; i++) {
        final x = 9.4 + i * 0.8;
        final top = 5.6 + i * 3.8;
        final building = Rect.fromLTWH(x, top, 1.5, 25 - top);
        canvas.drawRect(building, fill..color = const Color(0xFF0A1427));
        canvas.drawRect(
          building,
          line..color = (i.isEven ? accent : _magenta).withValues(alpha: 0.28),
        );
        canvas.drawLine(Offset(x + 0.7, top - 1.5), Offset(x + 0.7, top), line);
        for (var row = 0; row < 9; row++) {
          final y = top + 0.9 + row * 1.5;
          if (y > 24) break;
          canvas.drawRect(
            Rect.fromLTWH(x + 0.22, y, 0.36, 0.45),
            fill..color = accent.withValues(alpha: row % 3 == 0 ? 0.38 : 0.12),
          );
        }
      }
      // Suspended sign and layered metal service panels along the perimeter.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(9.45, 14.3, 1.1, 5.2),
          const Radius.circular(0.15),
        ),
        fill..color = const Color(0xFF47264B),
      );
      for (var y = 15.0; y < 19; y += 0.9) {
        canvas.drawLine(
          Offset(9.7, y),
          Offset(10.25, y),
          line..color = _magenta.withValues(alpha: 0.7),
        );
      }
      for (var i = 0; i < 4; i++) {
        final panel = Rect.fromLTWH(10.1, 26.1 + i * 4.6, 2, 3.7);
        canvas.drawRRect(
          RRect.fromRectAndRadius(panel, const Radius.circular(0.25)),
          fill..color = const Color(0xFF172436),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            panel.deflate(0.17),
            const Radius.circular(0.15),
          ),
          line..color = accent.withValues(alpha: 0.23),
        );
        for (var vent = 0; vent < 3; vent++) {
          final y = panel.top + 0.8 + vent * 0.4;
          canvas.drawLine(Offset(10.6, y), Offset(11.5, y), line);
        }
      }
      canvas.restore();
    }
  }

  void _drawCircuitFloor(Canvas canvas, Color accent) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.055
      ..strokeJoin = StrokeJoin.round
      ..color = accent.withValues(alpha: 0.19);
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(14, 0);
      canvas.scale(side, 1);
      for (var route = 0; route < 3; route++) {
        final x = 4.6 + route * 1.3;
        canvas.drawPath(
          Path()
            ..moveTo(x, 17.0 + route)
            ..lineTo(x, 23.3 + route)
            ..lineTo(3.7 + route, 26.1 + route)
            ..lineTo(3.7 + route, 32.5 + route)
            ..lineTo(6.0 + route, 34.8 + route)
            ..lineTo(6.0 + route, 40.5),
          line,
        );
        canvas.drawCircle(Offset(x, 17.0 + route), 0.18, line);
        canvas.drawCircle(Offset(6.0 + route, 40.5), 0.15, line);
      }
      for (var i = 0; i < 4; i++) {
        final y = 24.2 + i * 2.9;
        canvas.drawPath(
          Path()
            ..moveTo(8.5, y)
            ..lineTo(7.85, y + 0.65)
            ..lineTo(8.5, y + 1.3),
          line..color = _magenta.withValues(alpha: 0.3),
        );
      }
      canvas.restore();
    }
    // A printed bearing and charge marks explain the moving central rotor.
    line.color = accent.withValues(alpha: 0.24);
    canvas.drawCircle(const Offset(14, 28.8), 4.2, line);
    canvas.drawCircle(const Offset(14, 28.8), 4.55, line);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      canvas.drawLine(
        Offset(14 + math.cos(a) * 4.2, 28.8 + math.sin(a) * 4.2),
        Offset(14 + math.cos(a) * 4.5, 28.8 + math.sin(a) * 4.5),
        line,
      );
    }
    _drawCaption(
      canvas,
      'POWER ROUTE',
      const Offset(14, 24.5),
      accent.withValues(alpha: 0.4),
      size: 0.46,
    );
  }

  void _drawRuins(Canvas canvas, Color accent) {
    final fill = Paint();
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.065
      ..color = _brass.withValues(alpha: 0.2);
    // Downward shafts are baked gradients, without an extra offscreen pass.
    for (final x in [4.0, 21.0]) {
      final shaft = Path()
        ..moveTo(x, 1)
        ..lineTo(x + 1.1, 1)
        ..lineTo(x + 5.2, 31)
        ..lineTo(x - 1.7, 31)
        ..close();
      canvas.drawPath(
        shaft,
        fill
          ..shader = ui.Gradient.linear(Offset(x, 1), Offset(x + 2, 31), const [
            Color(0x153AA8AC),
            Color(0x003AA8AC),
          ]),
      );
    }
    fill.shader = null;
    final arch = Path()
      ..moveTo(3.2, 24)
      ..lineTo(3.2, 12)
      ..cubicTo(3.2, 1.8, 24.8, 1.8, 24.8, 12)
      ..lineTo(24.8, 24);
    canvas.drawPath(
      arch,
      line
        ..strokeWidth = 1.2
        ..color = const Color(0xFF163C43),
    );
    canvas.drawPath(
      arch,
      line
        ..strokeWidth = 0.065
        ..color = _brass.withValues(alpha: 0.28),
    );
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(14, 0);
      canvas.scale(side, 1);
      for (var i = 0; i < 3; i++) {
        final x = 9.7 + i * 1.25;
        final top = 10.5 + i * 2.1;
        canvas.drawRect(
          Rect.fromLTWH(x, top, 1.25, 24.8 - top),
          fill
            ..color = Color.lerp(
              const Color(0xFF183B42),
              const Color(0xFF0D2932),
              i / 3,
            )!,
        );
        canvas.drawLine(
          Offset(x + 0.3, top),
          Offset(x + 0.3, 24.8),
          line..color = accent.withValues(alpha: 0.14),
        );
        for (final y in [top, 24.8]) {
          canvas.drawRect(
            Rect.fromLTWH(x - 0.25, y, 1.75, 0.5),
            fill..color = const Color(0xFF285055),
          );
          canvas.drawLine(
            Offset(x - 0.25, y),
            Offset(x + 1.5, y),
            line..color = _brass.withValues(alpha: 0.35),
          );
        }
      }
      for (var i = 0; i < 5; i++) {
        final x = 9.7 + i * 0.65;
        final bottom = 39.0 + i % 2 * 1.6;
        final height = 2.0 + i % 3 * 0.8;
        final coral = Path()
          ..moveTo(x, bottom)
          ..cubicTo(
            x - 0.4,
            bottom - 1,
            x + 0.4,
            bottom - height + 0.5,
            x,
            bottom - height,
          )
          ..moveTo(x, bottom - 1)
          ..quadraticBezierTo(x - 1, bottom - 1.3, x - 0.8, bottom - 2.4)
          ..moveTo(x + 0.1, bottom - 1.9)
          ..quadraticBezierTo(x + 1, bottom - 2.1, x + 0.8, bottom - 3.1);
        canvas.drawPath(
          coral,
          line
            ..strokeWidth = 0.19
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF397275).withValues(alpha: 0.65),
        );
      }
      canvas.restore();
    }
  }

  void _drawRelicFloor(Canvas canvas, Color accent) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.045
      ..color = _brass.withValues(alpha: 0.14);
    for (var i = -3; i <= 3; i++) {
      canvas.drawLine(Offset(14 + i * 1.6, 18), Offset(14 + i * 3.8, 45), line);
    }
    for (final y in [23.0, 26.0, 29.7, 34.0, 39.0, 44.0]) {
      canvas.drawLine(Offset(3, y), Offset(24, y), line);
    }
    for (final x in [6.5, 21.0]) {
      final track = Rect.fromCenter(
        center: Offset(x, 29),
        width: 2.4,
        height: 7.1,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(track, const Radius.circular(0.45)),
        Paint()..color = const Color(0xFF03141D),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(track, const Radius.circular(0.45)),
        line
          ..strokeWidth = 0.07
          ..color = _brass.withValues(alpha: 0.36),
      );
      for (final y in [24.8, 33.2]) {
        _drawDiamond(canvas, Offset(x, y), 0.3, _brass.withValues(alpha: 0.65));
      }
    }
    // Broken etched waves carry the water motif through the quiet centre.
    line
      ..strokeWidth = 0.045
      ..color = accent.withValues(alpha: 0.12);
    for (var i = 0; i < 5; i++) {
      final y = 19.7 + i * 3.9;
      canvas.drawPath(
        Path()
          ..moveTo(8.5, y)
          ..cubicTo(10.3, y - 0.8, 11.5, y + 0.8, 13.1, y)
          ..moveTo(15.1, y + 0.5)
          ..cubicTo(16.4, y - 0.5, 18.1, y + 1, 19.2, y),
        line,
      );
    }
    _drawCaption(
      canvas,
      'SEALED PASSAGE',
      const Offset(14, 26.5),
      _brass.withValues(alpha: 0.45),
      size: 0.46,
    );
  }

  void _drawAmbientMotion(Canvas canvas, PinballWorld world) {
    final neon = world == PinballWorld.neon;
    final accent = selectWorldAccent(world);
    _motion
      ..strokeWidth = neon ? 0.1 : 0.055
      ..color = accent.withValues(alpha: neon ? 0.5 : 0.27);
    // Only eight moving details, confined to the rails and backdrop margins.
    for (var i = 0; i < 8; i++) {
      final left = i.isEven;
      final x = left ? 3.5 + i % 3 * 0.45 : 23.0 + i % 3 * 0.4;
      final y = neon
          ? 20 + ((_time * 3.2 + i * 4.1) % 21)
          : 42 - ((_time * 1.25 + i * 4.7) % 29);
      if (neon) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 0.65), _motion);
      } else {
        canvas.drawCircle(
          Offset(x + math.sin(_time + i) * 0.18, y),
          0.11 + i % 3 * 0.045,
          _motion,
        );
      }
    }
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
    for (final id in const ['jewel-left', 'jewel-right', 'jewel-center']) {
      if (game.isMissionHitLit(id)) {
        final at = game.findMissionHitPosition(id);
        canvas.drawCircle(Offset(at.x, at.y), 2.5, paint..color = accent);
      }
    }
    for (var index = 0; index < 4; index++) {
      final id = 'target-$index';
      if (game.isMissionHitLit(id)) {
        final at = game.findMissionHitPosition(id);
        canvas.drawCircle(Offset(at.x, at.y), 1.9, paint..color = accent);
      }
    }
    if (!game.isGateMission) return;
    final active = game.gateArmed;
    final color = active ? accent : accent.withValues(alpha: 0.25);
    if (game.currentWorld == PinballWorld.garden) {
      canvas.drawOval(
        const Rect.fromLTWH(11.6, 2.5, 4.8, 3),
        paint..color = color,
      );
      canvas.drawOval(
        const Rect.fromLTWH(12, 2.8, 4, 2.4),
        paint..color = color.withValues(alpha: active ? 0.55 : 0.15),
      );
    } else {
      _drawGatePortal(canvas, accent, active);
    }
    _drawCaption(
      canvas,
      active ? 'GATE OPEN' : 'CHARGE',
      const Offset(14, 6.4),
      color,
      size: 0.65,
    );
  }

  void _drawGatePortal(Canvas canvas, Color accent, bool active) {
    final line = Paint()..style = PaintingStyle.stroke;
    const portal = Rect.fromLTWH(11.8, 2.2, 4.4, 3.6);
    canvas.drawOval(
      portal,
      Paint()..color = const Color(0xFF03101D).withValues(alpha: 0.85),
    );
    canvas.drawOval(
      portal,
      line
        ..strokeWidth = 0.32
        ..color = const Color(0xFF455868),
    );
    canvas.drawOval(
      portal.deflate(0.2),
      line
        ..strokeWidth = 0.09
        ..color = accent.withValues(alpha: active ? 1 : 0.3),
    );
    canvas.drawOval(
      portal.deflate(0.52),
      line
        ..strokeWidth = 0.06
        ..color = accent.withValues(alpha: active ? 0.55 : 0.12),
    );
    for (final side in [-1.0, 1.0]) {
      final bracket = Path()
        ..moveTo(14 + side * 1.8, 2.1)
        ..lineTo(14 + side * 2.6, 2.6)
        ..lineTo(14 + side * 2.6, 5.2)
        ..lineTo(14 + side * 1.8, 5.8);
      canvas.drawPath(
        bracket,
        line
          ..strokeWidth = 0.24
          ..color = const Color(0xFF455868),
      );
      canvas.drawLine(
        Offset(14 + side * 2.6, 3.1),
        Offset(14 + side * 2.6, 4.7),
        line
          ..strokeWidth = 0.09
          ..color = accent.withValues(alpha: active ? 0.9 : 0.25),
      );
    }
    if (active) {
      canvas.drawPath(
        Path()
          ..moveTo(13.2, 4.2)
          ..lineTo(14, 3.5)
          ..lineTo(14.8, 4.2),
        line
          ..strokeWidth = 0.11
          ..color = accent,
      );
    }
  }
}

void _drawDiamond(Canvas canvas, Offset at, double radius, Color color) {
  canvas.drawPath(
    Path()
      ..moveTo(at.dx, at.dy - radius)
      ..lineTo(at.dx + radius, at.dy)
      ..lineTo(at.dx, at.dy + radius)
      ..lineTo(at.dx - radius, at.dy)
      ..close(),
    Paint()..color = color,
  );
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
