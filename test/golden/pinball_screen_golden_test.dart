import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/main.dart';
import 'package:mon_pinball/pinball_game.dart';

import '../support/pinball_test_harness.dart';

void main() {
  configurePinballTestBinding();
  setUpAll(loadPinballTestFont);

  group('Pinball screen golden tests', () {
    testWidgets('renders the initial table and HUD', (tester) async {
      final boundaryKey = await _pumpGoldenGame(tester);

      await _expectGolden(tester, boundaryKey, 'goldens/pinball_initial.png');
    }, tags: ['golden']);

    testWidgets('renders a charged launcher', (tester) async {
      final boundaryKey = await _pumpGoldenGame(
        tester,
        arrange: (game) => game.setLauncherDragCharge(0.78),
      );

      await _expectGolden(tester, boundaryKey, 'goldens/pinball_charged.png');
    }, tags: ['golden']);

    testWidgets('renders the game-over HUD', (tester) async {
      final boundaryKey = await _pumpGoldenGame(
        tester,
        arrange: (game) {
          game.hud.value = const PinballSnapshot(
            score: 4250,
            lives: 0,
            launchCharge: 0,
            status: 'Game over - tap launch or R',
            gameOver: true,
          );
        },
      );

      await _expectGolden(tester, boundaryKey, 'goldens/pinball_game_over.png');
    }, tags: ['golden']);
  });
}

Future<void> _expectGolden(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String baseline,
) async {
  if (tester.binding is LiveTestWidgetsFlutterBinding) {
    markTestSkipped(
      'Device runs render the scenario only. '
      'Run flutter test --tags golden on the host for pixel comparisons.',
    );
    return;
  }
  await expectLater(find.byKey(boundaryKey), matchesGoldenFile(baseline));
}

Future<GlobalKey> _pumpGoldenGame(
  WidgetTester tester, {
  void Function(MonPinballGame game)? arrange,
}) async {
  final boundaryKey = GlobalKey();
  await preparePinballTestSurface(tester);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final game = MonPinballGame();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: MonPinballApp(gameFactory: () => game),
    ),
  );
  await tester.pump();
  await game.loaded;

  // Mount every queued Forge2D component on one deterministic frame.
  await tester.pump(const Duration(milliseconds: 16));
  game.pauseEngine();
  arrange?.call(game);
  await tester.pump();

  return boundaryKey;
}
