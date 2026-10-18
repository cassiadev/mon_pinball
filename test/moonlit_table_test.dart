import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/pinball_game.dart';
import 'package:mon_pinball/moonlit_table.dart';
import 'package:mon_pinball/pinball_style.dart';

import 'support/pinball_test_harness.dart';

void main() {
  configurePinballTestBinding();

  testWidgets('large rose bumper leaves a full ball passage beside the rail', (
    tester,
  ) async {
    final game = await pumpPinballApp(tester, pauseGame: true);
    addTearDown(() => disposePinballScenario(tester));
    final rose = game.world.children.whereType<Bumper>().singleWhere(
      (bumper) => bumper.color == PinballStyle.red,
    );
    final rail = game.world.children.whereType<TableRail>().singleWhere(
      (rail) =>
          (rail.start.x - 22.35).abs() < 0.001 &&
          (rail.end.x - 18.9).abs() < 0.001,
    );
    final edge = rail.end - rail.start;
    final offset = rose.body.position - rail.start;
    final distance =
        (offset.x * edge.y - offset.y * edge.x).abs() / math.sqrt(edge.length2);
    expect(distance - rose.radius, greaterThan(PinballBall.radius * 2 + 0.08));
  });

  testWidgets('visible flipper face covers its physical tip contact area', (
    tester,
  ) async {
    final game = await pumpPinballApp(tester, pauseGame: true);
    addTearDown(() => disposePinballScenario(tester));
    final flipper = game.world.children.whereType<Flipper>().firstWhere(
      (f) => f.isLeft,
    );
    final point = Vector2(4.8, 0.25);
    expect(
      flipper.body.fixtures.single.testPoint(flipper.body.worldPoint(point)),
      isTrue,
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..translate(20, 30)
      ..scale(30);
    flipper.render(canvas);
    final picture = recorder.endRecording();
    final image = await tester.runAsync(() => picture.toImage(200, 70));
    final bytes = await tester.runAsync(() => image!.toByteData());
    final pixel =
        ((30 + point.y * 30).round() * 200 + (20 + point.x * 30).round()) * 4;
    expect(bytes!.getUint8(pixel + 1), greaterThan(80));
    image!.dispose();
    picture.dispose();
  });

  testWidgets('jade bumper shares the symmetric flipper center axis', (
    tester,
  ) async {
    final game = await pumpPinballApp(tester, pauseGame: true);
    addTearDown(() => disposePinballScenario(tester));
    final jade = game.world.children.whereType<Bumper>().singleWhere(
      (bumper) => bumper.color == PinballStyle.cyan,
    );
    final flippers = game.world.children.whereType<Flipper>().toList();
    final center = (flippers[0].pivot.x + flippers[1].pivot.x) / 2;
    expect(jade.body.position.x, closeTo(center, 0.00001));
    expect(MoonlitTable.moonCenter.dx, closeTo(center, 0.00001));
    expect(jade.radius, greaterThanOrEqualTo(1.9));
  });
}
