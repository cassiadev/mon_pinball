import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/boss_encounter.dart';
import 'package:mon_pinball/moonlit_boss.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loads transparent articulated art and draws an opaque face and brooch',
    () async {
      final encounter = BossEncounter();
      final boss = MoonlitBoss(encounter);
      await boss.onLoad();
      final atlas = Flame.images.fromCache('moonlit/tsukibina-atlas.png');
      final pixels = (await atlas.toByteData())!;
      expect(pixels.getUint8(3), lessThan(5));
      expect(
        pixels.getUint8((253 * atlas.width + 273) * 4 + 3),
        greaterThan(200),
      );

      final frame = await _render(boss, encounter);
      // The brooch is at the physical weak point; the face is above it.
      expect(_countGoldPixels(frame, 290, 290, 310, 310), greaterThan(150));
      expect(_countOpaquePixels(frame, 285, 210, 315, 235), greaterThan(500));
      // Atlas padding must not turn the board into six rectangular pictures.
      expect(_countOpaquePixels(frame, 0, 130, 25, 160), 0);
    },
  );

  test('each part keeps the drawn aspect ratio of its atlas cell', () async {
    final encounter = BossEncounter();
    final boss = MoonlitBoss(encounter);
    await boss.onLoad();
    final frame = await _render(boss, encounter);
    final bounds = _findOpaqueBounds(frame);
    // The finished figure spreads wide like the mockup instead of a thin
    // column: wings and sleeves span far more than the body is tall.
    expect(bounds.width / bounds.height, greaterThan(1.1));
    expect(bounds.width, greaterThan(20 * 20));
  });

  test(
    'idle breathing changes the limbs even after recentering the flight path',
    () async {
      final encounter = BossEncounter();
      final boss = MoonlitBoss(encounter);
      await boss.onLoad();
      final first = await _render(boss, encounter);
      encounter.update(0.5);
      final breathing = await _render(boss, encounter);
      expect(
        _countChangedPixels(first, breathing, 80, 140, 250, 450),
        greaterThan(500),
      );
    },
  );

  test('the right sleeve crop stops in the gap before the next hem', () async {
    final encounter = BossEncounter();
    final boss = MoonlitBoss(encounter);
    await boss.onLoad();
    final atlas = Flame.images.fromCache('moonlit/tsukibina-atlas.png');
    final pixels = (await atlas.toByteData())!;
    int decodeAlpha(int x, int y) =>
        pixels.getUint8((y * atlas.width + x) * 4 + 3);
    // Cell 4 starts at (512, 512); the sleeve is cropped at local x = 448.
    for (var y = 512; y < 1024; y++) {
      expect(decodeAlpha(512 + 448, y), lessThan(17));
    }
    var hem = 0;
    for (var y = 512; y < 1024; y++) {
      for (var x = 512 + 462; x < 1024; x++) {
        if (decodeAlpha(x, y) > 16) hem++;
      }
    }
    expect(hem, greaterThan(1000));
  });

  test(
    'attack opens wings and sleeves, then returns to the resting pose',
    () async {
      final idle = BossEncounter()..update(3.05);
      final attacking = BossEncounter()
        ..start()
        ..update(3.05);
      final idleBoss = MoonlitBoss(idle);
      final attackBoss = MoonlitBoss(attacking);
      await idleBoss.onLoad();
      await attackBoss.onLoad();
      final idleFrame = await _render(idleBoss, idle);
      final attackFrame = await _render(attackBoss, attacking);
      expect(
        _countChangedPixels(idleFrame, attackFrame, 70, 120, 260, 450),
        greaterThan(2000),
      );
      idle.update(0.5);
      attacking.update(0.5);
      expect(
        _countChangedPixels(
          await _render(attackBoss, attacking),
          await _render(idleBoss, idle),
          70,
          120,
          260,
          300,
        ),
        0,
      );
    },
  );

  test(
    'hurt recoils the articulated art while the brooch stays on the sensor',
    () async {
      final encounter = BossEncounter()
        ..start()
        ..update(1.2);
      final boss = MoonlitBoss(encounter);
      await boss.onLoad();
      final before = await _render(boss, encounter);
      final center = encounter.position;
      encounter.checkHit(center - Vector2(8, 0), center);
      final hurt = await _render(boss, encounter);
      expect(
        _countChangedPixels(before, hurt, 100, 130, 500, 500),
        greaterThan(2000),
      );
      expect(_countGoldPixels(hurt, 290, 290, 310, 310), greaterThan(150));
    },
  );

  test(
    'a real burst draws glowing lilac petals that vanish when paused',
    () async {
      final encounter = BossEncounter()
        ..start()
        ..update(4.9);
      final petals = BossPetals(encounter);
      final burst = await _render(petals, encounter);
      encounter.pause();
      final cleared = await _render(petals, encounter);
      expect(
        _countChangedPixels(burst, cleared, 0, 300, 600, 600),
        greaterThan(200),
      );
    },
  );

  test(
    'defeat flashes, fades the figure out, then draws nothing until reset',
    () async {
      final encounter = BossEncounter()..start();
      final boss = MoonlitBoss(encounter);
      await boss.onLoad();
      final before = await _render(boss, encounter);
      for (var hit = 0; hit < 13; hit++) {
        final center = encounter.position;
        encounter.checkHit(center - Vector2(8, 0), center);
        encounter.checkHit(center, center + Vector2(8, 0));
      }
      expect(encounter.defeated, isTrue);
      // The exit starts from the full figure plus the brooch flash.
      final flash = await _render(boss, encounter);
      expect(
        _countPixels(flash, 0, 0, 600, 600, (i) => flash[i + 3] > 30),
        greaterThan(
          _countPixels(before, 0, 0, 600, 600, (i) => before[i + 3] > 30) ~/ 2,
        ),
      );
      encounter.update(BossEncounter.defeatDuration * 0.6);
      final fading = await _render(boss, encounter);
      expect(
        _countOpaquePixels(fading, 0, 0, 600, 600),
        lessThan(_countOpaquePixels(before, 0, 0, 600, 600) ~/ 3),
      );
      encounter.update(BossEncounter.defeatDuration);
      final gone = await _render(boss, encounter);
      expect(_countPixels(gone, 0, 0, 600, 600, (i) => gone[i + 3] > 0), 0);

      encounter.reset();
      final restored = await _render(boss, encounter);
      expect(
        _countOpaquePixels(restored, 280, 280, 320, 320),
        greaterThan(500),
      );
    },
  );
}

Future<Uint8List> _render(Component layer, BossEncounter encounter) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.translate(
    300 - encounter.position.x * 20,
    300 - encounter.position.y * 20,
  );
  canvas.scale(20);
  layer.render(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(600, 600);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  image.dispose();
  picture.dispose();
  return bytes;
}

int _countGoldPixels(Uint8List frame, int x0, int y0, int x1, int y1) =>
    _countPixels(
      frame,
      x0,
      y0,
      x1,
      y1,
      (i) =>
          frame[i] > 140 &&
          frame[i + 1] > 100 &&
          frame[i + 2] < 170 &&
          frame[i + 3] > 200,
    );

ui.Rect _findOpaqueBounds(Uint8List frame) {
  var left = 600, top = 600, right = 0, bottom = 0;
  for (var y = 0; y < 600; y++) {
    for (var x = 0; x < 600; x++) {
      if (frame[(y * 600 + x) * 4 + 3] > 200) {
        left = x < left ? x : left;
        right = x > right ? x : right;
        top = y < top ? y : top;
        bottom = y > bottom ? y : bottom;
      }
    }
  }
  return ui.Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    right.toDouble(),
    bottom.toDouble(),
  );
}

int _countOpaquePixels(Uint8List frame, int x0, int y0, int x1, int y1) =>
    _countPixels(frame, x0, y0, x1, y1, (i) => frame[i + 3] > 200);

int _countChangedPixels(
  Uint8List a,
  Uint8List b,
  int x0,
  int y0,
  int x1,
  int y1,
) => _countPixels(
  a,
  x0,
  y0,
  x1,
  y1,
  (i) =>
      (a[i] - b[i]).abs() +
          (a[i + 1] - b[i + 1]).abs() +
          (a[i + 2] - b[i + 2]).abs() +
          (a[i + 3] - b[i + 3]).abs() >
      50,
);

int _countPixels(
  Uint8List frame,
  int x0,
  int y0,
  int x1,
  int y1,
  bool Function(int) matches,
) {
  var count = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      if (matches((y * 600 + x) * 4)) count++;
    }
  }
  return count;
}
