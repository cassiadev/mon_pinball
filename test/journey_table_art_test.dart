import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/journey_table.dart';
import 'package:mon_pinball/pinball_progress.dart';

import 'support/pinball_test_harness.dart';
import 'world_obstacles_test.dart' show loadWorld;

void main() {
  configurePinballTestBinding();

  for (final world in [PinballWorld.neon, PinballWorld.abyss]) {
    testWidgets(
      '${world.name} art reuses its image until camera scale changes',
      (tester) async {
        final game = await loadWorld(tester, world);
        final table = game.world.children.whereType<JourneyTable>().single;
        final first = table.bakedArt;
        expect(first, isNotNull);

        for (var frame = 0; frame < 3; frame++) {
          game.stepEngine();
          await tester.pump();
          expect(identical(table.bakedArt, first), isTrue);
        }

        await tester.binding.setSurfaceSize(const Size(844, 390));
        game.stepEngine(stepTime: 0);
        await tester.pump();
        await tester.pump();
        expect(table.bakedArt, isNotNull);
        expect(identical(table.bakedArt, first), isFalse);

        table.removeFromParent();
        game.stepEngine(stepTime: 0);
        expect(table.bakedArt, isNull);
      },
    );
  }
}
