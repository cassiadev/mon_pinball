import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/moonlit_boss.dart';
import 'package:mon_pinball/pinball_game.dart';
import 'package:mon_pinball/moonlit_table.dart';
import 'package:mon_pinball/pinball_style.dart';

import 'support/pinball_test_harness.dart';

void main() {
  configurePinballTestBinding();

  testWidgets('every jewel bumper leaves full ball passages around it', (
    tester,
  ) async {
    final game = await pumpPinballApp(tester, pauseGame: true);
    addTearDown(() => disposePinballScenario(tester));
    final bumpers = game.world.children.whereType<Bumper>().toList();
    final walls = game.world.children.whereType<TableWall>().toList();
    const passage = PinballBall.radius * 2 + 0.08;

    for (final bumper in bumpers) {
      for (final wall in walls) {
        for (var i = 1; i < wall.points.length; i++) {
          final distance = _segmentDistance(
            bumper.body.position,
            wall.points[i - 1],
            wall.points[i],
          );
          expect(distance - bumper.radius, greaterThan(passage));
        }
      }
      for (final other in bumpers.where((b) => b != bumper)) {
        final gap =
            bumper.body.position.distanceTo(other.body.position) -
            bumper.radius -
            other.radius;
        expect(gap, greaterThan(passage));
      }
    }
  });

  testWidgets('the right spinner mirrors the left one as / beside \\', (
    tester,
  ) async {
    final game = await pumpPinballApp(tester, pauseGame: true);
    addTearDown(() => disposePinballScenario(tester));
    final spinners = game.world.children.whereType<Spinner>().toList()
      ..sort((a, b) => a.spinnerCenter.x.compareTo(b.spinnerCenter.x));
    final (left, right) = (spinners.first, spinners.last);
    expect(left.barAngle, closeTo(-right.barAngle, 1e-9));
    // Screen y grows downward: \ falls to the right and / rises to the right.
    Vector2 end(Spinner spinner, double side) => spinner.body.worldPoint(
      Vector2(math.cos(spinner.barAngle), math.sin(spinner.barAngle)) *
          (side * Spinner.halfLength),
    );
    expect(end(left, 1).y, greaterThan(end(left, -1).y));
    expect(end(right, 1).y, lessThan(end(right, -1).y));
  });

  testWidgets('obstacles draw over the boss; petals stay under the ball', (
    tester,
  ) async {
    final game = await pumpPinballApp(tester, pauseGame: true);
    addTearDown(() => disposePinballScenario(tester));
    final children = game.world.children;
    final boss = children.whereType<MoonlitBoss>().single.priority;
    final petals = children.whereType<BossPetals>().single.priority;
    final ball = children.whereType<PinballBall>().single.priority;
    final obstacles = [
      ...children.whereType<Bumper>(),
      ...children.whereType<Slingshot>(),
      ...children.whereType<Spinner>(),
      ...children.whereType<DropTarget>(),
      ...children.whereType<Flipper>(),
      ...children.whereType<TableWall>(),
    ];
    for (final obstacle in obstacles) {
      expect(obstacle.priority, greaterThan(boss));
      expect(obstacle.priority, lessThan(petals));
    }
    expect(petals, lessThan(ball));
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
      flipper.body.fixtures.any(
        (fixture) => fixture.testPoint(flipper.body.worldPoint(point)),
      ),
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

double _segmentDistance(Vector2 point, Vector2 start, Vector2 end) {
  final edge = end - start;
  final t = ((point - start).dot(edge) / edge.length2).clamp(0.0, 1.0);
  return point.distanceTo(start + edge * t);
}
