import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import 'boss_encounter.dart';
import 'moonlit_table.dart';

/// One articulated atlas cell placed at its own uniform scale.
///
/// [pivot] is in atlas-cell pixels and lands on [attachment], in board units
/// relative to the brooch. Every part keeps its drawn aspect ratio; only the
/// whole figure breathes, so no part is ever squashed on one axis.
class _Rig {
  const _Rig({
    required this.cell,
    required this.pivot,
    required this.unitsPerPixel,
    required this.attachment,
    this.restAngle = 0,
    this.crop = const Rect.fromLTWH(0, 0, 512, 512),
  });

  final int cell;
  final Offset pivot;
  final double unitsPerPixel;
  final Offset attachment;
  final double restAngle;
  final Rect crop;
}

/// Articulated atlas parts drawn in board coordinates around the weak point.
///
/// The figure sits beneath the physical obstacles so jewels, targets and the
/// ball always read on top of her, as in the approved mockup.
class MoonlitBoss extends Component {
  MoonlitBoss(this.encounter) : super(priority: -20);

  // Measured from the atlas: wing roots, shoulder seams, the skirt waistband
  // and the brooch, composed to the final floating-boss mockup.
  static const _leftWing = _Rig(
    cell: 1,
    pivot: Offset(395, 378),
    unitsPerPixel: 0.0225,
    attachment: Offset(-1.4, -1),
    restAngle: -0.08,
  );
  static const _rightWing = _Rig(
    cell: 2,
    pivot: Offset(65, 378),
    unitsPerPixel: 0.0225,
    attachment: Offset(1.4, -1),
    restAngle: 0.08,
  );
  // The hem crosses its nominal cell edge: crop it out of the right sleeve
  // and include its left edge here.
  static const _skirt = _Rig(
    cell: 5,
    pivot: Offset(215, 110),
    unitsPerPixel: 0.029,
    attachment: Offset(0, 0.7),
    crop: Rect.fromLTWH(-48, 0, 560, 512),
  );
  static const _body = _Rig(
    cell: 0,
    pivot: Offset(273, 253),
    unitsPerPixel: 0.031,
    attachment: Offset.zero,
  );
  static const _leftSleeve = _Rig(
    cell: 3,
    pivot: Offset(430, 40),
    unitsPerPixel: 0.0235,
    attachment: Offset(-2.1, -1.9),
    restAngle: 0.26,
  );
  static const _rightSleeve = _Rig(
    cell: 4,
    pivot: Offset(48, 40),
    unitsPerPixel: 0.0235,
    attachment: Offset(2.1, -1.9),
    restAngle: -0.26,
    crop: Rect.fromLTWH(0, 0, 448, 512),
  );

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
    canvas.clipRRect(MoonlitTable.playfield);
    canvas.translate(center.x, center.y);
    // All body motion pivots on the atlas brooch, never on a bounding-box center.
    canvas.rotate(drift * 0.03 + hurt * 0.1);
    final recoil = 1 - hurt * 0.05;
    final defeatScale = encounter.defeated ? 0.94 : 1.0;
    final size = (1 + breath * 0.012) * recoil * defeatScale;
    canvas.scale(size, size);

    final wing = breath * 0.06 + opening * 0.22 - hurt * 0.18;
    _part(canvas, atlas, _leftWing, -wing + 0.03 * drift, 0.94 * fade);
    _part(canvas, atlas, _rightWing, wing + 0.03 * drift, 0.94 * fade);
    // The trailing fabric lags behind both flight and the attack gesture.
    _part(
      canvas,
      atlas,
      _skirt,
      math.sin(time * 2.1 - 0.7) * 0.03 + drift * 0.02,
      fade,
    );
    _part(canvas, atlas, _body, 0, fade);
    final sleeve = math.sin(time * 2.1 - 0.4) * 0.04 + opening * 0.26;
    _part(canvas, atlas, _leftSleeve, sleeve - hurt * 0.14, fade);
    _part(canvas, atlas, _rightSleeve, -sleeve + hurt * 0.14, fade);
    canvas.restore();
  }

  void _part(
    Canvas canvas,
    Image atlas,
    _Rig rig,
    double angle,
    double opacity,
  ) {
    canvas.save();
    canvas.translate(rig.attachment.dx, rig.attachment.dy);
    canvas.rotate(rig.restAngle + angle);
    _paint.color = Color.fromRGBO(255, 255, 255, opacity);
    final scale = rig.unitsPerPixel;
    canvas.drawImageRect(
      atlas,
      rig.crop.shift(Offset((rig.cell % 3) * 512.0, (rig.cell ~/ 3) * 512.0)),
      Rect.fromLTWH(
        (rig.crop.left - rig.pivot.dx) * scale,
        (rig.crop.top - rig.pivot.dy) * scale,
        rig.crop.width * scale,
        rig.crop.height * scale,
      ),
      _paint,
    );
    canvas.restore();
  }
}

/// The petal attack, drawn above the obstacles but below the ball.
class BossPetals extends Component {
  BossPetals(this.encounter) : super(priority: 60);

  final BossEncounter encounter;

  static final _shape = Path()
    ..moveTo(0.55, 0)
    ..cubicTo(0.15, -0.34, -0.38, -0.32, -0.42, 0)
    ..cubicTo(-0.38, 0.32, 0.15, 0.34, 0.55, 0)
    ..close();

  @override
  void render(Canvas canvas) {
    for (final petal in encounter.petals) {
      // Keep decorative projectiles out of the lower flipper approach.
      if (petal.y > 34) continue;
      final opacity = ((6 - petal.age) / 0.8).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(petal.x, petal.y);
      canvas.rotate(petal.angle);
      canvas.drawLine(
        const Offset(-1.4, 0),
        const Offset(-0.45, 0),
        Paint()
          ..color = Color.fromRGBO(214, 170, 255, opacity * 0.35)
          ..strokeWidth = 0.06
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        _shape,
        Paint()
          ..color = Color.fromRGBO(196, 92, 255, opacity * 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.22),
      );
      canvas.drawPath(
        _shape,
        Paint()
          ..shader = Gradient.radial(
            const Offset(0.12, 0),
            0.6,
            [
              Color.fromRGBO(255, 244, 255, opacity),
              Color.fromRGBO(226, 140, 255, opacity),
              Color.fromRGBO(150, 64, 214, opacity),
            ],
            const [0, 0.45, 1],
          ),
      );
      canvas.restore();
    }
  }
}
