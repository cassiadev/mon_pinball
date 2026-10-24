import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/moonlit_table.dart';

import 'support/pinball_test_harness.dart';

void main() {
  configurePinballTestBinding();

  testWidgets('static table art is rendered once and reused until resized', (
    tester,
  ) async {
    final game = await pumpPinballApp(tester, pauseGame: true);
    addTearDown(() => disposePinballScenario(tester));
    final table = game.world.children.whereType<MoonlitTable>().single;
    Future<void> pumpFrame() async {
      game.stepEngine(stepTime: 0);
      await tester.pump();
    }

    await pumpFrame();
    final first = table.bakedArt;
    expect(first, isNotNull);
    for (var i = 0; i < 3; i++) {
      await pumpFrame();
      expect(identical(table.bakedArt, first), isTrue);
    }

    // A new zoom needs a sharper or smaller copy of the art.
    await tester.binding.setSurfaceSize(const Size(568, 320));
    await pumpFrame();
    await pumpFrame();
    expect(table.bakedArt, isNotNull);
    expect(identical(table.bakedArt, first), isFalse);
  });

  // Each of these needs an offscreen pass on every frame they are drawn,
  // which dropped the Galaxy SM-M336K to about 37 fps during petal attacks.
  test('drawing code avoids per-frame blur and mask passes', () {
    final lib = Directory('lib');
    if (!lib.existsSync()) {
      markTestSkipped('The source scan runs on the host only.');
      return;
    }
    final forbidden = {
      'MaskFilter.blur': RegExp(r'MaskFilter\.blur'),
      'ImageFilter.blur': RegExp(r'ImageFilter\.blur'),
      'BackdropFilter': RegExp(r'\bBackdropFilter\b'),
      'ShaderMask': RegExp(r'\bShaderMask\b'),
      'saveLayer': RegExp(r'\.saveLayer\('),
      // Box shadows on rounded rectangles have a cheap analytic path; text
      // and path shadows with blur do not.
      'blurred Shadow': RegExp(
        r'(?<!Box)Shadow\((?:(?!Shadow\().){0,200}?blurRadius',
        dotAll: true,
      ),
    };
    final hits = <String>[];
    for (final file in lib.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final MapEntry(key: name, value: pattern) in forbidden.entries) {
        for (final match in pattern.allMatches(source)) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length;
          hits.add('${file.path}:${line + 1} $name');
        }
      }
    }
    expect(hits, isEmpty, reason: 'See the rendering note in README.md.');
  });
}
