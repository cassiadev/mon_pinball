import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'boss_encounter.dart';
import 'journey_table.dart';
import 'pinball_game.dart';
import 'pinball_progress.dart';

/// Illustrated guardians share the actual weak point with their reactor/pearl.
class JourneyBoss extends Component with HasGameReference<MonPinballGame> {
  JourneyBoss() : super(priority: -20);

  static const neonAsset = 'journey/neon-sentinel.png';
  static const abyssAsset = 'journey/abyss-guardian.png';
  // Measured against the generated artwork; artwork is uniformly scaled.
  static const _neonCore = Offset(0.5, 0.414);
  static const _abyssCore = Offset(0.501, 0.397);
  final _sprite = Paint()..filterQuality = FilterQuality.medium;
  final _line = Paint()..style = PaintingStyle.stroke;
  final _fill = Paint();

  @override
  void render(Canvas canvas) {
    final boss = game.boss;
    final neon = game.currentWorld == PinballWorld.neon;
    if (!boss.visible ||
        boss.vanished ||
        game.currentWorld == PinballWorld.garden) {
      return;
    }
    final key = neon ? neonAsset : abyssAsset;
    if (!game.images.containsKey(key)) return;
    final image = game.images.fromCache(key);
    final accent = selectWorldAccent(game.currentWorld);
    final fade = boss.defeated ? 1 - boss.defeatProgress : 1.0;
    final exposed = boss.shieldState == BossShieldState.exposed;
    final at = boss.position.toOffset();
    final time = boss.poseTime;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    _drawAura(canvas, accent, time, fade, exposed);
    if (neon) {
      _drawTurbines(canvas, accent, time, fade);
    } else {
      _drawTendrils(canvas, accent, time, fade);
    }
    canvas.save();
    canvas.rotate(
      math.sin(time * 1.1) * 0.025 +
          math.sin(time * 30) * boss.hurtProgress * 0.035,
    );
    final scale = 1 + math.sin(time * 1.7) * 0.013 + boss.hurtProgress * 0.025;
    canvas.scale(scale);
    final width = neon ? 18.5 : 19.2;
    final height = width * image.height / image.width;
    final anchor = neon ? _neonCore : _abyssCore;
    _sprite
      ..color = Colors.white.withValues(alpha: fade)
      ..colorFilter = boss.hurtProgress > 0.4
          ? ColorFilter.mode(
              Colors.white.withValues(alpha: boss.hurtProgress * 0.65),
              BlendMode.srcATop,
            )
          : null;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(-width * anchor.dx, -height * anchor.dy, width, height),
      _sprite,
    );
    canvas.restore();
    _drawCore(canvas, accent, fade, exposed, time);
    if (boss.defeated) {
      _line
        ..color = accent.withValues(alpha: fade)
        ..strokeWidth = 0.12;
      canvas.drawCircle(Offset.zero, 1 + boss.defeatProgress * 7, _line);
    }
    canvas.restore();
    if (boss.shieldState == BossShieldState.attacking) {
      _drawAttack(canvas, accent, neon, time);
    }
  }

  void _drawAura(
    Canvas canvas,
    Color accent,
    double time,
    double fade,
    bool exposed,
  ) {
    final boss = game.boss;
    _line
      ..color = accent.withValues(alpha: fade * (exposed ? 0.65 : 0.24))
      ..strokeWidth = exposed ? 0.075 : 0.04;
    for (var ring = 0; ring < 2; ring++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: 3.8 + ring * 0.45),
        time * (ring == 0 ? 0.35 : -0.2),
        math.pi * 1.4,
        false,
        _line,
      );
    }
    if (boss.phase == 3) {
      for (var index = 0; index < 10; index++) {
        final angle = time * 0.55 + index * math.pi / 5;
        final r = 4.6 + math.sin(time * 2 + index) * 0.25;
        final p = Offset(math.cos(angle) * r, math.sin(angle) * r * 0.82);
        canvas.drawCircle(
          p,
          0.08,
          _fill..color = accent.withValues(alpha: fade * 0.7),
        );
      }
    }
  }

  void _drawTurbines(Canvas canvas, Color accent, double time, double fade) {
    final attack = game.boss.attackProgress;
    for (final side in [-1.0, 1.0]) {
      final center = Offset(side * 5.3, -1.8);
      _line
        ..color = accent.withValues(alpha: fade * 0.85)
        ..strokeWidth = 0.055;
      canvas.drawCircle(center, 1.12 + attack * 0.2, _line);
      for (var index = 0; index < 5; index++) {
        final angle = time * side * (1.6 + attack * 5) + index * math.pi * 0.4;
        final inner = center + Offset(math.cos(angle), math.sin(angle)) * 0.85;
        final outer =
            center +
            Offset(math.cos(angle + 0.2), math.sin(angle + 0.2)) * 1.05;
        canvas.drawLine(inner, outer, _line);
      }
      final shutter = math.sin(time * 1.4) * 0.3 + attack * 0.65;
      final fin = Path()
        ..moveTo(side * 5.4, 2)
        ..lineTo(side * (8.4 + shutter), 3.9)
        ..lineTo(side * (7.5 + shutter), 4.3)
        ..lineTo(side * 4.7, 2.5)
        ..close();
      canvas.drawPath(
        fin,
        _fill..color = const Color(0xFF162D47).withValues(alpha: fade * 0.95),
      );
      canvas.drawPath(
        fin,
        _line..color = const Color(0xFFB59AEF).withValues(alpha: fade * 0.75),
      );
    }
  }

  void _drawTendrils(Canvas canvas, Color accent, double time, double fade) {
    final attack = game.boss.attackProgress;
    for (final side in [-1.0, 1.0]) {
      for (var index = 0; index < 3; index++) {
        final wave = math.sin(time * 1.5 + index * 0.9) * 0.6;
        final x = side * (7.7 + index * 0.45);
        final y = 4.5 + index * 1.15 + attack * 0.6;
        final root = Offset(side * 2.2, 0.8 + index * 0.4);
        final tip = Offset(x + side * wave, y);
        final curve = Path()
          ..moveTo(root.dx, root.dy)
          ..cubicTo(side * 6, 2 + wave, side * 10, y + 1.1, tip.dx, tip.dy);
        canvas.drawPath(
          curve,
          _line
            ..color = const Color(0xFF142B3C).withValues(alpha: fade)
            ..strokeWidth = 0.32,
        );
        canvas.drawPath(
          curve,
          _line
            ..color = accent.withValues(alpha: fade * 0.58)
            ..strokeWidth = 0.055,
        );
        canvas.drawCircle(
          tip,
          0.13 + attack * 0.08,
          _fill..color = accent.withValues(alpha: fade * 0.8),
        );
      }
    }
    for (var bubble = 0; bubble < 5; bubble++) {
      final age = (time * 0.35 + bubble * 0.21) % 1;
      final p = Offset(math.sin(bubble * 2.4) * 7, 5.5 - age * 10);
      canvas.drawCircle(
        p,
        0.07 + bubble * 0.025,
        _line
          ..color = accent.withValues(alpha: (1 - age) * fade * 0.5)
          ..strokeWidth = 0.035,
      );
    }
  }

  void _drawCore(
    Canvas canvas,
    Color accent,
    double fade,
    bool exposed,
    double time,
  ) {
    final radius = game.boss.weakPointRadius;
    _line
      ..color = (exposed ? const Color(0xFFFFE5A0) : accent).withValues(
        alpha: fade * 0.9,
      )
      ..strokeWidth = exposed ? 0.11 : 0.04;
    canvas.drawCircle(
      Offset.zero,
      radius * (1 + (exposed ? math.sin(time * 8) * 0.05 : 0)),
      _line,
    );
    if (!exposed) {
      for (var i = 0; i < game.boss.requiredShieldHits; i++) {
        final angle =
            -math.pi / 2 + i * math.pi * 2 / game.boss.requiredShieldHits;
        canvas.drawCircle(
          Offset(math.cos(angle), math.sin(angle)) * 1.72,
          0.11,
          _fill
            ..color =
                (i < game.boss.shieldCharge ? const Color(0xFFFFE5A0) : accent)
                    .withValues(
                      alpha: fade * (i < game.boss.shieldCharge ? 1 : 0.25),
                    ),
        );
      }
    }
  }

  void _drawAttack(Canvas canvas, Color accent, bool neon, double time) {
    final boss = game.boss;
    final at = boss.position.toOffset();
    if (neon) {
      for (final component in game.world.children) {
        if (component is! EncounterLaneGate || !component.isMounted) continue;
        final right = component.position.x > MonPinballGame.boardWidth / 2;
        final warning = right ? boss.warnsRightLane : boss.warnsLeftLane;
        final active = right ? boss.sealsRightLane : boss.sealsLeftLane;
        if (!warning && !active) continue;
        final start = at + Offset(right ? 5.3 : -5.3, -1.8);
        final end = component.position.toOffset();
        _drawTargetLine(canvas, start, end, accent, warning, time);
      }
    } else {
      // Pressure rings announce the side sluices; the central route stays clear.
      final phase = boss.attackProgress;
      for (var ring = 0; ring < 3; ring++) {
        final radius = 2 + ((phase * 2 + ring * 0.34) % 1) * 7;
        canvas.drawOval(
          Rect.fromCenter(
            center: at + const Offset(0, 1.5),
            width: radius * 2,
            height: radius * 0.7,
          ),
          _line
            ..color = accent.withValues(alpha: (1 - (radius - 2) / 7) * 0.45)
            ..strokeWidth = 0.06,
        );
      }
      for (final component in game.world.children) {
        if (component is! EncounterLaneGate || !component.isMounted) continue;
        final right = component.position.x > MonPinballGame.boardWidth / 2;
        final warning = right ? boss.warnsRightLane : boss.warnsLeftLane;
        final active = right ? boss.sealsRightLane : boss.sealsLeftLane;
        if (!warning && !active) continue;
        final start = at + Offset(right ? 6.3 : -6.3, 3.7);
        final end = component.position.toOffset();
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..cubicTo(
            start.dx + (right ? 2 : -2),
            start.dy + 6,
            end.dx + (right ? -1 : 1),
            end.dy - 5,
            end.dx,
            end.dy,
          );
        canvas.drawPath(
          path,
          _line
            ..color = const Color(0xFF173748).withValues(alpha: 0.8)
            ..strokeWidth = warning ? 0.22 : 0.48,
        );
        canvas.drawPath(
          path,
          _line
            ..color = accent.withValues(alpha: warning ? 0.55 : 0.9)
            ..strokeWidth = 0.055,
        );
      }
    }
  }

  void _drawTargetLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Color accent,
    bool warning,
    double time,
  ) {
    final delta = end - start;
    final distance = delta.distance;
    final direction = delta / distance;
    _line
      ..color = accent.withValues(alpha: warning ? 0.28 : 0.45)
      ..strokeWidth = 0.045;
    for (var along = (time * 2) % 0.7; along < distance; along += 0.7) {
      canvas.drawLine(
        start + direction * along,
        start + direction * math.min(along + 0.3, distance),
        _line,
      );
    }
    final reach = warning ? 0.8 + game.boss.attackWarningProgress * 0.45 : 0.8;
    _line
      ..color = (warning ? const Color(0xFFFFD693) : accent).withValues(
        alpha: 0.9,
      )
      ..strokeWidth = 0.07;
    canvas.drawCircle(end, reach, _line);
    canvas.drawLine(
      end - const Offset(0.6, 0),
      end + const Offset(0.6, 0),
      _line,
    );
    canvas.drawLine(
      end - const Offset(0, 0.6),
      end + const Offset(0, 0.6),
      _line,
    );
  }
}
