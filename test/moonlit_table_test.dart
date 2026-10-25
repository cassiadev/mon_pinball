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
          final distance = _calculateDistanceToSegment(
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
    Vector2 calculateBarEnd(Spinner spinner, double side) =>
        spinner.body.worldPoint(
          Vector2(math.cos(spinner.barAngle), math.sin(spinner.barAngle)) *
              (side * Spinner.halfLength),
        );
    expect(
      calculateBarEnd(left, 1).y,
      greaterThan(calculateBarEnd(left, -1).y),
    );
    expect(calculateBarEnd(right, 1).y, lessThan(calculateBarEnd(right, -1).y));
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

  for (final left in [true, false]) {
    testWidgets(
      'the ${left ? 'left' : 'right'} flipper strikes with its drawn tip',
      (tester) async {
        final game = await pumpPinballApp(tester, pauseGame: true);
        addTearDown(() => disposePinballScenario(tester));
        game.world.gravity = Vector2.zero();
        final flipper = game.world.children.whereType<Flipper>().singleWhere(
          (f) => f.isLeft == left,
        );
        final side = left ? 1.0 : -1.0;
        // The blade's contact area reaches the rounded end that is drawn.
        final tipEnd = Vector2(
          side * (Flipper.length + Flipper.tipRadius - 0.05),
          0,
        );
        expect(
          flipper.body.fixtures.any(
            (fixture) => fixture.testPoint(flipper.body.worldPoint(tipEnd)),
          ),
          isTrue,
        );

        // Only the outermost part of the tip can reach this ball: a blade cut
        // short by even half a ball never touches it.
        final ball = game.world.children.whereType<PinballBall>().single;
        ball.body.setType(BodyType.dynamic);
        ball.body.setTransform(
          flipper.body.worldPoint(Vector2(side * 6.15, -1.17)),
          0,
        );
        ball.body.linearVelocity = Vector2.zero();
        if (left) {
          game.setLeftFlipper(true);
        } else {
          game.setRightFlipper(true);
        }
        for (var frame = 0; frame < 12; frame++) {
          game.stepEngine();
        }
        expect(ball.body.linearVelocity.y, lessThan(-5));
      },
    );
  }

  testWidgets('every bumper, moon and gold post bounces the ball and scores', (
    tester,
  ) async {
    final game = await pumpPinballApp(tester, pauseGame: true);
    addTearDown(() => disposePinballScenario(tester));
    game.world.gravity = Vector2.zero();
    final ball = game.world.children.whereType<PinballBall>().single;
    final bumpers = game.world.children.whereType<Bumper>().toList();
    expect(bumpers, hasLength(6));
    expect(
      bumpers.map((bumper) => bumper.style),
      containsAll(BumperStyle.values),
    );

    for (final bumper in bumpers) {
      game.restartGame();
      ball.body.setType(BodyType.dynamic);
      // Drop straight onto the top of the bumper from open space above it.
      ball.body.setTransform(
        bumper.body.position -
            Vector2(0, bumper.radius + PinballBall.radius + 1.5),
        0,
      );
      ball.body.linearVelocity = Vector2(0, 20);
      for (var frame = 0; frame < 60 && game.hud.value.score == 0; frame++) {
        game.stepEngine();
      }
      game.stepEngine();
      final where = '${bumper.style.name} at ${bumper.bumperCenter}';
      expect(game.hud.value.score, bumper.points, reason: where);
      expect(ball.body.linearVelocity.y, lessThan(-10), reason: where);
    }
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

double _calculateDistanceToSegment(Vector2 point, Vector2 start, Vector2 end) {
  final edge = end - start;
  final t = ((point - start).dot(edge) / edge.length2).clamp(0.0, 1.0);
  return point.distanceTo(start + edge * t);
}
