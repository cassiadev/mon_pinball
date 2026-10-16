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

    // Native Dart integers (including Android) are signed 64-bit values.
    // The last sample is a display boundary case, not a gameplay score cap.
    for (final sample in const [
      (8, 12_345_678),
      (9, 123_456_789),
      (19, 9_223_372_036_854_775_807),
    ]) {
      testWidgets('renders ${sample.$1}-digit score without clipping', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          final boundaryKey = await _pumpGoldenGame(
            tester,
            arrange: (game) {
              game.hud.value = PinballSnapshot(
                score: sample.$2,
                lives: 3,
                launchCharge: 0,
                status: 'Drag right plunger',
                gameOver: false,
              );
            },
          );

          expect(find.bySemanticsLabel('점수 ${sample.$2}점'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await _expectGolden(
            tester,
            boundaryKey,
            'goldens/pinball_score_${sample.$1}_digits.png',
          );
        } finally {
          semantics.dispose();
        }
      }, tags: ['golden']);
    }

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

    testWidgets('renders the wide table and side instruments', (tester) async {
      final boundaryKey = await _pumpGoldenGame(
        tester,
        size: const Size(1280, 800),
      );

      await _expectGolden(tester, boundaryKey, 'goldens/pinball_desktop.png');
    }, tags: ['golden']);

    testWidgets('fits a long score and status on a narrow screen', (
      tester,
    ) async {
      final boundaryKey = await _pumpGoldenGame(
        tester,
        size: const Size(320, 740),
        arrange: (game) {
          game.hud.value = const PinballSnapshot(
            score: 12345678,
            lives: 0,
            launchCharge: 0,
            status: 'Game over - tap launch or R',
            gameOver: true,
          );
        },
      );

      await _expectGolden(tester, boundaryKey, 'goldens/pinball_narrow.png');
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
  Size size = pinballTestSurfaceSize,
  void Function(MonPinballGame game)? arrange,
}) async {
  final boundaryKey = GlobalKey();
  await preparePinballTestSurface(tester, size: size);
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
  // Paint component changes even though the simulation clock is frozen.
  game.stepEngine(stepTime: 0);
  await tester.pump();

  return boundaryKey;
}
