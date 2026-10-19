import 'package:flutter/material.dart';

abstract final class PinballStyle {
  static const background = Color(0xFF070B20);
  static const panel = Color(0xFF11162F);
  static const line = Color(0xFF544B83);
  static const text = Color(0xFFF4EDD7);
  static const muted = Color(0xFFBFB8DE);
  static const cyan = Color(0xFF61DDC5);
  static const yellow = Color(0xFFEAC66F);
  static const red = Color(0xFFF389AC);
  static const coral = Color(0xFFFF684E);
  static const chrome = Color(0xFFD7B771);
  static const violet = Color(0xFFA38AEA);
  static const gold = Color(0xFFD7B771);
  static const neon = Color(0xFF8E9BFF);
  static const pink = Color(0xFFE77BC8);

  static Paint metal(Rect bounds) => Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFFEAB1),
        Color(0xFFD8BA78),
        Color(0xFF8E6D39),
        Color(0xFFFFEBC2),
        Color(0xFFC6A566),
        Color(0xFF70532E),
        Color(0xFFE6CA89),
      ],
      stops: [0, 0.16, 0.35, 0.48, 0.61, 0.82, 1],
    ).createShader(bounds);

  static Paint lens(Rect bounds, Color color, double flash) =>
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.36, -0.48),
          radius: 0.8,
          colors: [
            Color.lerp(color, Colors.white, 0.7 + flash * 0.3)!,
            Color.lerp(color, Colors.white, flash * 0.8)!,
            Color.lerp(color, Colors.black, 0.4 - flash * 0.3)!,
          ],
          stops: const [0, 0.35, 1],
        ).createShader(bounds);
}

class DotMatrixScore extends StatelessWidget {
  const DotMatrixScore({required this.score, super.key});

  final int score;

  @override
  Widget build(BuildContext context) {
    final digits = score.toString().padLeft(8, '0');
    return Semantics(
      label: '점수 $score점',
      child: SizedBox(
        height: 42,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: CustomPaint(
              size: Size((digits.length * 6 - 1) * 6, 42),
              painter: _DotMatrixPainter(digits),
            ),
          ),
        ),
      ),
    );
  }
}

class _DotMatrixPainter extends CustomPainter {
  const _DotMatrixPainter(this.digits);

  final String digits;

  // The same 5 x 7 glyphs as the approved design's review.js.
  static const _glyphs = [
    '01110100011001110101110011000101110',
    '00100011000010000100001000010001110',
    '01110100010000100010001000100011111',
    '11110000010000101110000010000111110',
    '00010001100101010010111110001000010',
    '11111100001000011110000010000111110',
    '01110100001000011110100011000101110',
    '11111000010001000100010000100001000',
    '01110100011000101110100011000101110',
    '01110100011000101111000010000101110',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // A wide translucent dot instead of a blurred glow keeps this cheap to
    // redraw every frame.
    final glow = Paint()..color = const Color(0x40F2B84B);
    final on = Paint()..color = const Color(0xFFFFD98A);
    final off = Paint()..color = const Color(0xFF2B2638);
    for (var digit = 0; digit < digits.length; digit++) {
      final glyph = _glyphs[int.parse(digits[digit])];
      for (var row = 0; row < 7; row++) {
        for (var col = 0; col < 5; col++) {
          final center = Offset((digit * 6 + col + 0.5) * 6, (row + 0.5) * 6);
          if (glyph[row * 5 + col] == '1') {
            // Lit dots nearly touch so digits stay legible at header size.
            canvas.drawCircle(center, 3.3, glow);
            canvas.drawCircle(center, 2.55, on);
          } else {
            canvas.drawCircle(center, 1.7, off);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DotMatrixPainter oldDelegate) =>
      digits != oldDelegate.digits;
}

/// Remaining balls drawn as ivory pinballs; lost balls stay as dim outlines.
class LivesIndicator extends StatelessWidget {
  const LivesIndicator({
    required this.lives,
    this.capacity = 3,
    this.size = 15,
    super.key,
  });

  final int lives;
  final int capacity;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < capacity; index++)
          Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : size * 0.35),
            child: CustomPaint(
              size: Size.square(size),
              painter: _BallPainter(lit: index < lives),
            ),
          ),
      ],
    );
  }
}

class _BallPainter extends CustomPainter {
  const _BallPainter({required this.lit});

  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    if (!lit) {
      canvas.drawCircle(
        center,
        radius - 0.75,
        Paint()
          ..color = PinballStyle.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      return;
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: const [Colors.white, Color(0xFFFFF3D2), Color(0xFFC9BC94)],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_BallPainter oldDelegate) => lit != oldDelegate.lit;
}

/// The gold crescent used as the title mark.
class CrescentMark extends StatelessWidget {
  const CrescentMark({this.size = 26, super.key});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _CrescentPainter());
}

class _CrescentPainter extends CustomPainter {
  const _CrescentPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.92)),
      Path()..addOval(
        Rect.fromCircle(
          center: c + Offset(r * 0.42, -r * 0.2),
          radius: r * 0.78,
        ),
      ),
    );
    canvas.drawPath(moon, Paint()..color = PinballStyle.gold);
  }

  @override
  bool shouldRepaint(_CrescentPainter oldDelegate) => false;
}

/// A gold-rimmed bar filled with a violet-to-pink gradient up to [value].
///
/// It paints the gradient directly rather than masking a progress indicator,
/// which would need an offscreen layer every frame.
class HealthBar extends StatelessWidget {
  const HealthBar({required this.value, this.defeated = false, super.key});

  final double value;
  final bool defeated;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.fromHeight(11),
      painter: _HealthBarPainter(value.clamp(0.0, 1.0), defeated),
    );
  }
}

class _HealthBarPainter extends CustomPainter {
  const _HealthBarPainter(this.value, this.defeated);

  final double value;
  final bool defeated;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(6),
    );
    canvas.drawRRect(frame, Paint()..color = const Color(0xE6090C22));
    final track = Offset.zero & size;
    final inner = track.deflate(2);
    if (value > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            inner.left,
            inner.top,
            inner.width * value,
            inner.height,
          ),
          const Radius.circular(4),
        ),
        Paint()
          ..shader = LinearGradient(
            colors: defeated
                ? const [PinballStyle.gold, PinballStyle.gold]
                : const [Color(0xFF9B7CF2), PinballStyle.pink],
          ).createShader(inner),
      );
    }
    canvas.drawRRect(
      frame.deflate(0.5),
      Paint()
        ..color = PinballStyle.gold.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_HealthBarPainter oldDelegate) =>
      value != oldDelegate.value || defeated != oldDelegate.defeated;
}
