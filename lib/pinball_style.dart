import 'package:flutter/material.dart';

abstract final class PinballStyle {
  static const background = Color(0xFF080D1C);
  static const panel = Color(0xFF101A35);
  static const line = Color(0xFF2C3954);
  static const text = Color(0xFFF2F5FC);
  static const muted = Color(0xFFB3BED3);
  static const cyan = Color(0xFF38DDE8);
  static const yellow = Color(0xFFFFD84A);
  static const red = Color(0xFFFF514A);
  static const coral = Color(0xFFFF684E);
  static const chrome = Color(0xFFC4CAD4);

  static Paint metal(Rect bounds) => Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFF3F6FC),
        Color(0xFFA3B0C4),
        Color(0xFF6F8099),
        Color(0xFFE8EDF5),
        Color(0xFF7F8FA7),
        Color(0xFF536782),
        Color(0xFF9FAFC1),
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
    final digits = score.toString().padLeft(7, '0');
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
    final on = Paint()..color = const Color(0xFFFF9B37);
    final off = Paint()..color = const Color(0xFF4B2813);
    for (var digit = 0; digit < digits.length; digit++) {
      final glyph = _glyphs[int.parse(digits[digit])];
      for (var row = 0; row < 7; row++) {
        for (var col = 0; col < 5; col++) {
          canvas.drawCircle(
            Offset((digit * 6 + col + 0.5) * 6, (row + 0.5) * 6),
            2.04,
            glyph[row * 5 + col] == '1' ? on : off,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DotMatrixPainter oldDelegate) =>
      digits != oldDelegate.digits;
}
