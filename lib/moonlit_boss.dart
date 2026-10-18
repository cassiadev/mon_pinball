import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import 'boss_encounter.dart';

/// Articulated atlas parts drawn in board coordinates around the weak point.
class MoonlitBoss extends Component {
  MoonlitBoss(this.encounter) : super(priority: 30);

  final BossEncounter encounter;
  Image? _atlas;
  final _paint = Paint()..filterQuality = FilterQuality.high;

  @override
  Future<void> onLoad() async {
    _atlas = await Flame.images.load('moonlit/tsukibina-atlas.png');
  }

  @override
  void render(Canvas canvas) {
    final atlas = _atlas;
    if (atlas == null) return;

    final time = encounter.poseTime;
    final breath = math.sin(time * 2.1);
    final drift = math.cos(time * 0.55);
    final opening = math.sin(encounter.attackProgress * math.pi);
    final hurt = encounter.hurtProgress;
    final fade = encounter.defeated ? 0.36 : 1.0;
    final center = encounter.position;

    canvas.save();
    canvas.translate(center.x, center.y);
    // All body motion pivots on the atlas brooch, never on a bounding-box center.
    canvas.rotate(drift * 0.045 + hurt * 0.13);
    final recoil = 1 - hurt * 0.055;
    final defeatScale = encounter.defeated ? 0.94 : 1.0;
    canvas.scale(
      (1 + breath * 0.012) * recoil * defeatScale,
      (1 + breath * 0.018) * recoil * defeatScale,
    );

    final wing = breath * 0.065 + opening * 0.25 - hurt * 0.2;
    _part(
      canvas,
      atlas,
      1,
      const Offset(393, 376),
      const Size(10.5, 8.2),
      const Offset(-1.3, -1),
      wing + 0.035 * drift,
      0.72 * fade,
    );
    _part(
      canvas,
      atlas,
      2,
      const Offset(66, 376),
      const Size(10.5, 8.2),
      const Offset(1.3, -1),
      -wing + 0.035 * drift,
      0.72 * fade,
    );

    // The trailing fabric lags behind both flight and the attack gesture.
    _part(
      canvas,
      atlas,
      5,
      const Offset(256, 50),
      const Size(15, 10),
      const Offset(0, 2),
      math.sin(time * 2.1 - 0.7) * 0.04 + drift * 0.025,
      0.30 * fade,
    );
    final sleeve = math.sin(time * 2.1 - 0.4) * 0.045 + opening * 0.3;
    _part(
      canvas,
      atlas,
      3,
      const Offset(432, 34),
      const Size(10, 10),
      const Offset(-1.3, -0.8),
      sleeve + hurt * 0.16,
      0.40 * fade,
    );
    _part(
      canvas,
      atlas,
      4,
      const Offset(60, 28),
      const Size(10, 10),
      const Offset(1.3, -0.8),
      -sleeve - hurt * 0.16,
      0.40 * fade,
    );
    _part(
      canvas,
      atlas,
      0,
      const Offset(273, 253),
      const Size(8, 13),
      Offset.zero,
      0,
      fade,
    );
    canvas.restore();
    _renderPetals(canvas);
  }

  void _renderPetals(Canvas canvas) {
    final shape = Path()
      ..moveTo(0.3, 0)
      ..cubicTo(0.04, -0.19, -0.23, -0.18, -0.25, 0)
      ..cubicTo(-0.23, 0.18, 0.04, 0.19, 0.3, 0)
      ..close();
    for (final petal in encounter.petals) {
      // Keep decorative projectiles out of the lower flipper approach.
      if (petal.y > 35) continue;
      final opacity = ((6 - petal.age) / 0.8).clamp(0.0, 0.85);
      canvas.save();
      canvas.translate(petal.x, petal.y);
      canvas.rotate(petal.angle);
      canvas.drawLine(
        const Offset(-0.85, 0),
        const Offset(-0.22, 0),
        Paint()
          ..color = Color.fromRGBO(171, 132, 208, opacity * 0.4)
          ..strokeWidth = 0.045
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        shape,
        Paint()..color = Color.fromRGBO(218, 184, 239, opacity),
      );
      canvas.drawPath(
        shape,
        Paint()
          ..color = Color.fromRGBO(151, 102, 183, opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.035,
      );
      canvas.restore();
    }
  }

  void _part(
    Canvas canvas,
    Image atlas,
    int cell,
    Offset pivot,
    Size size,
    Offset attachment,
    double angle,
    double opacity,
  ) {
    canvas.save();
    canvas.translate(attachment.dx, attachment.dy);
    canvas.rotate(angle);
    _paint.color = Color.fromRGBO(255, 255, 255, opacity);
    // The hem crosses its nominal cell edge. Crop it out of the sleeve and
    // include its left edge in the hem, retaining the original waist pivot.
    final crop = switch (cell) {
      4 => const Rect.fromLTWH(0, 0, 448, 512),
      5 => const Rect.fromLTWH(-48, 0, 560, 512),
      _ => const Rect.fromLTWH(0, 0, 512, 512),
    };
    canvas.drawImageRect(
      atlas,
      crop.shift(Offset((cell % 3) * 512.0, (cell ~/ 3) * 512.0)),
      Rect.fromLTWH(
        (crop.left - pivot.dx) / 512 * size.width,
        (crop.top - pivot.dy) / 512 * size.height,
        crop.width / 512 * size.width,
        crop.height / 512 * size.height,
      ),
      _paint,
    );
    canvas.restore();
  }
}
