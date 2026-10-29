// Host visual check: flutter test --no-pub test/device_world_gallery.dart
// Writes actual production-screen captures to build/qa/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/journey_screen.dart';
import 'package:mon_pinball/pinball_game.dart';
import 'package:mon_pinball/pinball_progress.dart';
import 'package:mon_pinball/pinball_style.dart';
import 'package:mon_pinball/world_devices.dart';

import 'support/pinball_test_harness.dart';
import 'world_obstacles_test.dart' show placeBall;

void main() {
  configurePinballTestBinding();
  setUpAll(loadPinballTestFont);
  for (final world in PinballWorld.values) {
    testWidgets('${world.name} renders its active device feedback', (
      tester,
    ) async {
      await preparePinballTestSurface(tester);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: PinballStyle.background,
            fontFamily: 'IBMPlexMono',
            fontFamilyFallback: const ['sans-serif'],
          ),
          home: RepaintBoundary(
            key: boundaryKey,
            child: JourneyPlayScreen(
              configuration: RunConfiguration(
                mode: PinballMode.arcade,
                world: world,
              ),
              progress: PinballProgress.memory(),
            ),
          ),
        ),
      );
      await tester.pump();
      final game = tester
          .widget<GameWidget<MonPinballGame>>(
            find.byType(GameWidget<MonPinballGame>),
          )
          .game!;
      currentPinballGame = game;
      addTearDown(() => disposePinballScenario(tester));
      await tester.runAsync(() => game.loaded);
        for (var frame = 0; frame < 4; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      game.pauseEngine();
      game.world.gravity = Vector2.zero();
      final ball = game.world.children.whereType<PinballBall>().single;
      ball.body.linearDamping = 0;
      switch (world) {
        case PinballWorld.garden:
          placeBall(game, Vector2(14, 28.1), Vector2(0, 10));
          game.stepEngine();
          expect(
            game.world.children.whereType<GardenLotusScoop>().single.isHolding,
            isTrue,
          );
        case PinballWorld.neon:
          placeBall(game, Vector2(21.3, 35.8), Vector2(-6, -9));
          game.stepEngine();
          expect(ball.body.linearVelocity.length, greaterThan(30));
        case PinballWorld.abyss:
          for (var frame = 0; frame < 160; frame++) {
            game.stepEngine();
          }
          placeBall(game, Vector2(14, 28), Vector2(0, 8));
          game.stepEngine();
          expect(ball.body.linearVelocity.x, greaterThan(0));
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File('build/qa/world-devices-${world.name}.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
      });
    });
  }
}
