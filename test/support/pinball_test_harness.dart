import 'dart:async';
import 'dart:io';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/main.dart';
import 'package:mon_pinball/pinball_game.dart';

const pinballTestSurfaceSize = Size(390, 844);

MonPinballGame? currentPinballGame;
TestGesture? currentPinballGesture;
String? currentGestureTarget;

TestWidgetsFlutterBinding configurePinballTestBinding() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  if (binding is LiveTestWidgetsFlutterBinding) {
    // Keep the physics clock under test control when running on a device.
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  }
  return binding;
}

Future<void> preparePinballTestEnvironment() async {
  final binding = configurePinballTestBinding();
  if (binding is LiveTestWidgetsFlutterBinding) {
    // Wait before testWidgets paints its own initial placeholder frame.
    final startupTimer = Stopwatch()..start();
    while (binding.platformDispatcher.implicitView!.physicalSize.isEmpty) {
      if (startupTimer.elapsed > const Duration(seconds: 10)) {
        throw TimeoutException('The device viewport did not become ready.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }
}

Future<void> preparePinballTestSurface(WidgetTester tester) async {
  await preparePinballTestEnvironment();
  await tester.binding.setSurfaceSize(pinballTestSurfaceSize);
}

Future<void> loadPinballTestFont() async {
  await preparePinballTestEnvironment();
  if (configurePinballTestBinding() is LiveTestWidgetsFlutterBinding) {
    // This font is a host-only golden fixture, not a packaged app asset.
    return;
  }
  final fontBytes = await File(
    'test/fonts/RobotoMono-Regular.ttf',
  ).readAsBytes();
  final fontLoader = FontLoader('monospace')
    ..addFont(Future.value(ByteData.sublistView(fontBytes)));
  await fontLoader.load();
}

Future<MonPinballGame> pumpPinballApp(
  WidgetTester tester, {
  bool pauseGame = false,
}) async {
  await preparePinballTestSurface(tester);
  final game = MonPinballGame();
  currentPinballGame = game;

  await tester.pumpWidget(MonPinballApp(gameFactory: () => game));
  await tester.pump();
  await game.loaded;

  if (pauseGame) {
    game.pauseEngine();
  }
  await tester.pump();
  return game;
}

MonPinballGame requirePinballGame() {
  final game = currentPinballGame;
  if (game == null) {
    throw StateError('The pinball app has not been started for this scenario.');
  }
  return game;
}

Rect pinballInputRect(WidgetTester tester) {
  return tester.getRect(find.byKey(const ValueKey('pinball-input-surface')));
}

Offset playfieldPosition(WidgetTester tester, String side) {
  final rect = pinballInputRect(tester);
  final dx = switch (side) {
    'left' => rect.width * 0.25,
    'right' => rect.width * 0.70,
    _ => throw ArgumentError.value(side, 'side', 'Must be left or right.'),
  };
  return rect.topLeft + Offset(dx, rect.height * 0.78);
}

Offset plungerPosition(WidgetTester tester) {
  final rect = pinballInputRect(tester);
  return rect.topLeft + Offset(rect.width * 0.88, rect.height * 0.72);
}

void addTestScore(int points) {
  requirePinballGame().addScore(
    points,
    Vector2(14, 22),
    const Color(0xFFFFD54F),
    'test target',
  );
}

Future<void> disposePinballScenario(WidgetTester tester) async {
  final gesture = currentPinballGesture;
  if (gesture != null) {
    await gesture.cancel();
  }
  currentPinballGesture = null;
  currentGestureTarget = null;
  currentPinballGame = null;
  await tester.binding.setSurfaceSize(null);
}
