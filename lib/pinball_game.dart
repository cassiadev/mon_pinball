import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinballSnapshot {
  const PinballSnapshot({
    required this.score,
    required this.lives,
    required this.launchCharge,
    required this.status,
    required this.gameOver,
  });

  final int score;
  final int lives;
  final double launchCharge;
  final String status;
  final bool gameOver;
}

class MonPinballGame extends Forge2DGame with KeyboardEvents {
  MonPinballGame()
    : hud = ValueNotifier<PinballSnapshot>(
        const PinballSnapshot(
          score: 0,
          lives: _initialLives,
          launchCharge: 0,
          status: 'Drag right plunger',
          gameOver: false,
        ),
      ),
      super(gravity: Vector2(0, 32), zoom: 12);

  static const double boardWidth = 28;
  static const double boardHeight = 48;
  static const int _initialLives = 3;

  final ValueNotifier<PinballSnapshot> hud;

  @visibleForTesting
  bool get isLeftFlipperPressed =>
      _leftFlipper.isMounted && _leftFlipper.isPressed;

  @visibleForTesting
  bool get isRightFlipperPressed =>
      _rightFlipper.isMounted && _rightFlipper.isPressed;

  late final PinballBall _ball;
  late final Flipper _leftFlipper;
  late final Flipper _rightFlipper;
  late final LauncherView _launcherView;

  int _score = 0;
  int _lives = _initialLives;
  double _launchCharge = 0;
  bool _isChargingLauncher = false;
  bool _keyboardLauncherDown = false;
  bool _gameOver = false;
  String _status = 'Drag right plunger';

  @override
  Color backgroundColor() => const Color(0xFF050714);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    camera.viewfinder.position = Vector2(boardWidth / 2, boardHeight / 2);
    camera.viewfinder.anchor = Anchor.center;

    world.add(TableBackdrop());
    world.addAll(_buildRails());
    world.addAll(_buildBumpers());
    world.addAll(_buildTargets());

    _leftFlipper = Flipper.left(Vector2(8.4, 41.4));
    _rightFlipper = Flipper.right(Vector2(19.6, 41.4));
    world.add(_leftFlipper);
    world.add(_rightFlipper);

    _launcherView = LauncherView();
    world.add(_launcherView);

    _ball = PinballBall(startPosition: _launchPosition());
    world.add(_ball);

    _emitHud();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final zoomX = size.x / boardWidth;
    final zoomY = size.y / boardHeight;
    camera.viewfinder.zoom = math.min(zoomX, zoomY) * 0.96;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_isChargingLauncher && !_gameOver) {
      _launchCharge = (_launchCharge + dt * 0.8).clamp(0.0, 1.0);
      _launcherView.charge = _launchCharge;
      _emitHud();
    }

    if (!_gameOver && _ball.isMounted && _ball.position.y > boardHeight + 4) {
      _drainBall();
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final leftPressed =
        keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA);
    final rightPressed =
        keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD);
    setLeftFlipper(leftPressed);
    setRightFlipper(rightPressed);

    final launcherPressed =
        keysPressed.contains(LogicalKeyboardKey.space) ||
        keysPressed.contains(LogicalKeyboardKey.arrowDown) ||
        keysPressed.contains(LogicalKeyboardKey.keyS);
    if (launcherPressed && !_keyboardLauncherDown) {
      startLauncherCharge();
    } else if (!launcherPressed && _keyboardLauncherDown) {
      releaseLauncher();
    }
    _keyboardLauncherDown = launcherPressed;

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyR) {
        restartGame();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.keyW) {
        nudge();
      }
    }

    return KeyEventResult.handled;
  }

  void setLeftFlipper(bool pressed) {
    if (_leftFlipper.isMounted) {
      _leftFlipper.isPressed = pressed;
    }
  }

  void setRightFlipper(bool pressed) {
    if (_rightFlipper.isMounted) {
      _rightFlipper.isPressed = pressed;
    }
  }

  bool isLauncherTouch(Offset screenPosition) {
    final worldPosition = screenToWorld(
      Vector2(screenPosition.dx, screenPosition.dy),
    );
    return worldPosition.x >= 23.0 &&
        worldPosition.x <= 27.4 &&
        worldPosition.y >= 34.5 &&
        worldPosition.y <= 47.6;
  }

  double launcherChargeFromDrag({
    required Offset startScreenPosition,
    required Offset currentScreenPosition,
  }) {
    final startWorld = screenToWorld(
      Vector2(startScreenPosition.dx, startScreenPosition.dy),
    );
    final currentWorld = screenToWorld(
      Vector2(currentScreenPosition.dx, currentScreenPosition.dy),
    );
    return ((currentWorld.y - startWorld.y) / 6.2).clamp(0.0, 1.0);
  }

  void startLauncherCharge({bool timed = true}) {
    if (_gameOver) {
      restartGame();
      if (!timed) {
        return;
      }
    }
    _isChargingLauncher = timed;
    _status = 'Charging launcher';
    _emitHud();
  }

  void setLauncherDragCharge(double charge) {
    if (_gameOver) {
      restartGame();
    }
    _isChargingLauncher = false;
    _launchCharge = charge.clamp(0.0, 1.0);
    _launcherView.charge = _launchCharge;
    _status = _launchCharge <= 0 ? 'Pull plunger down' : 'Release to launch';
    _emitHud();
  }

  void releaseLauncher() {
    if (_gameOver) {
      restartGame();
      return;
    }

    final power = math.max(_launchCharge, 0.2);
    _isChargingLauncher = false;
    _launchCharge = 0;
    _launcherView.charge = 0;

    if (_ball.isMounted && _ball.position.x > 22) {
      _ball.launch(power);
      _status = 'Launched';
    } else if (_ball.isMounted) {
      _ball.body.applyLinearImpulse(Vector2(0, -7));
      _status = 'Nudged upward';
    }
    _emitHud();
  }

  void nudge() {
    if (_gameOver || !_ball.isMounted) {
      return;
    }
    _ball.body.applyLinearImpulse(Vector2(0, -10));
    _status = 'Table nudge';
    _emitHud();
  }

  void addScore(int points, Vector2 at, Color color, String reason) {
    if (_gameOver) {
      return;
    }
    _score += points;
    _status = '+$points $reason';
    world.add(PulseRing(position: at.clone(), color: color));
    _emitHud();
  }

  void restartGame() {
    _score = 0;
    _lives = _initialLives;
    _gameOver = false;
    _status = 'Drag right plunger';
    _launchCharge = 0;
    _isChargingLauncher = false;
    _launcherView.charge = 0;
    _resetBall();
    _emitHud();
  }

  List<Component> _buildRails() {
    return [
      TableRail(Vector2(4.0, 2.0), Vector2(22.0, 2.0), width: 0.34),
      TableRail(Vector2(1.4, 6.2), Vector2(4.0, 2.0), width: 0.34),
      TableRail(Vector2(22.0, 2.0), Vector2(27.0, 7.8), width: 0.34),
      TableRail(Vector2(1.4, 6.2), Vector2(1.4, 41.4), width: 0.38),
      TableRail(Vector2(26.6, 6.8), Vector2(26.6, 47.0), width: 0.38),
      TableRail(Vector2(1.4, 41.4), Vector2(7.2, 46.2), width: 0.42),
      TableRail(Vector2(20.8, 46.2), Vector2(23.7, 42.4), width: 0.42),
      TableRail(Vector2(22.35, 16.8), Vector2(22.35, 43.2), width: 0.3),
      TableRail(Vector2(22.35, 16.8), Vector2(18.9, 11.2), width: 0.3),
      TableRail(Vector2(21.7, 7.0), Vector2(18.9, 11.2), width: 0.3),
      LaunchLaneExit(),
      Slingshot(
        vertices: [Vector2(5.2, 34.7), Vector2(9.4, 37.3), Vector2(6.5, 39.2)],
        color: const Color(0xFFFF7043),
      ),
      Slingshot(
        vertices: [
          Vector2(22.8, 34.7),
          Vector2(18.6, 37.3),
          Vector2(21.5, 39.2),
        ],
        color: const Color(0xFFFF7043),
      ),
      Slingshot(
        vertices: [Vector2(5.4, 14.0), Vector2(9.2, 17.5), Vector2(4.8, 20.1)],
        color: const Color(0xFF36D1DC),
      ),
    ];
  }

  List<Component> _buildBumpers() {
    return [
      Bumper(bumperCenter: Vector2(10.0, 12.0), radius: 1.65, points: 250),
      Bumper(bumperCenter: Vector2(17.2, 14.8), radius: 1.65, points: 250),
      Bumper(bumperCenter: Vector2(13.2, 22.0), radius: 1.9, points: 400),
      Spinner(spinnerCenter: Vector2(7.0, 25.8), points: 150),
      Spinner(spinnerCenter: Vector2(20.7, 25.6), points: 150),
    ];
  }

  List<Component> _buildTargets() {
    return [
      DropTarget(targetCenter: Vector2(7.2, 30.1), targetAngle: -0.35),
      DropTarget(targetCenter: Vector2(10.2, 31.3), targetAngle: -0.25),
      DropTarget(targetCenter: Vector2(17.6, 31.3), targetAngle: 0.25),
      DropTarget(targetCenter: Vector2(20.6, 30.1), targetAngle: 0.35),
    ];
  }

  void _drainBall() {
    _lives -= 1;
    if (_lives <= 0) {
      _gameOver = true;
      _status = 'Game over - tap launch or R';
      _resetBall();
    } else {
      _status = 'Ball drained - $_lives left';
      _resetBall();
    }
    _emitHud();
  }

  void _resetBall() {
    if (!_ball.isMounted) {
      return;
    }
    _ball.body.setTransform(_launchPosition(), 0);
    _ball.body.linearVelocity = Vector2.zero();
    _ball.body.angularVelocity = 0;
  }

  Vector2 _launchPosition() => Vector2(25.0, 43.0);

  void _emitHud() {
    hud.value = PinballSnapshot(
      score: _score,
      lives: _lives,
      launchCharge: _launchCharge,
      status: _status,
      gameOver: _gameOver,
    );
  }
}

class TableBackdrop extends Component {
  TableBackdrop() : super(priority: -100);

  @override
  void render(Canvas canvas) {
    final board = Rect.fromLTWH(
      0,
      0,
      MonPinballGame.boardWidth,
      MonPinballGame.boardHeight,
    );
    final background = Paint()
      ..shader = ui.Gradient.linear(
        board.topLeft,
        board.bottomRight,
        const [Color(0xFF111A35), Color(0xFF07101E), Color(0xFF2A120F)],
        const [0.0, 0.62, 1.0],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(board.deflate(0.28), const Radius.circular(2.2)),
      background,
    );

    final gridPaint = Paint()
      ..color = const Color(0x2236D1DC)
      ..strokeWidth = 0.045;
    for (var y = 6.0; y < MonPinballGame.boardHeight; y += 4) {
      canvas.drawLine(Offset(2, y), Offset(26, y - 3), gridPaint);
    }

    final lanePaint = Paint()
      ..color = const Color(0x3329ABE2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.14;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(23.65, 6.0, 2.42, 40.4),
        const Radius.circular(1.1),
      ),
      lanePaint,
    );
  }
}

class TableRail extends BodyComponent<MonPinballGame> {
  TableRail(this.start, this.end, {this.width = 0.24})
    : super(
        priority: -10,
        paint: Paint()
          ..color = const Color(0xFFB9F7FF)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );

  final Vector2 start;
  final Vector2 end;
  final double width;

  @override
  Body createBody() {
    final shape = EdgeShape()..set(start, end);
    final fixtureDef = FixtureDef(shape, friction: 0.08, restitution: 0.86);
    return world.createBody(BodyDef())..createFixture(fixtureDef);
  }

  @override
  void renderEdge(Canvas canvas, Offset p1, Offset p2) {
    final glow = Paint()
      ..color = const Color(0x4436D1DC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p1, p2, glow);
    paint.strokeWidth = width;
    canvas.drawLine(p1, p2, paint);
  }
}

class LaunchLaneExit extends BodyComponent<MonPinballGame>
    with ContactCallbacks {
  LaunchLaneExit() : super(priority: -5, renderBody: false);

  double _cooldown = 0;

  @override
  Body createBody() {
    final shape = PolygonShape()..setAsBoxXY(2.1, 1.35);
    final body = world.createBody(
      BodyDef(position: Vector2(24.35, 7.7), userData: this),
    );
    body.createFixture(FixtureDef(shape, userData: this, isSensor: true));
    return body;
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (other is! PinballBall || _cooldown > 0 || other.position.x < 22.0) {
      return;
    }

    _cooldown = 0.7;
    other.body.linearVelocity = Vector2(-30, -8);
    other.body.angularVelocity = -18;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _cooldown = math.max(0, _cooldown - dt);
  }
}

class Slingshot extends BodyComponent<MonPinballGame> with ContactCallbacks {
  Slingshot({required this.vertices, required this.color})
    : super(priority: 1, renderBody: false);

  final List<Vector2> vertices;
  final Color color;
  double _flash = 0;
  late final Vector2 _center = _calculateCenter();

  @override
  Body createBody() {
    final shape = PolygonShape()..set(vertices);
    final body = world.createBody(BodyDef(userData: this));
    body.createFixture(
      FixtureDef(shape, userData: this, friction: 0.2, restitution: 1.25),
    );
    return body;
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (other is PinballBall) {
      _flash = 1;
      game.addScore(75, _center, color, 'slingshot');
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _flash = math.max(0, _flash - dt * 4.8);
  }

  @override
  void render(Canvas canvas) {
    final path = Path()
      ..addPolygon(vertices.map((v) => v.toOffset()).toList(), true);
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.lerp(color, Colors.white, _flash * 0.65)!
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xDDFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.12,
    );
  }

  Vector2 _calculateCenter() {
    final center = Vector2.zero();
    for (final vertex in vertices) {
      center.add(vertex);
    }
    return center..scale(1 / vertices.length);
  }
}

class Bumper extends BodyComponent<MonPinballGame> with ContactCallbacks {
  Bumper({
    required this.bumperCenter,
    required this.radius,
    required this.points,
  }) : super(priority: 5, renderBody: false);

  final Vector2 bumperCenter;
  final double radius;
  final int points;
  final Color color = const Color(0xFFFFD54F);
  double _flash = 0;
  double _cooldown = 0;

  @override
  Body createBody() {
    final shape = CircleShape()..radius = radius;
    final body = world.createBody(
      BodyDef(position: bumperCenter, userData: this),
    );
    body.createFixture(
      FixtureDef(shape, userData: this, friction: 0.02, restitution: 1.55),
    );
    return body;
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (other is PinballBall && _cooldown <= 0) {
      _flash = 1;
      _cooldown = 0.18;
      final push = other.position - position;
      if (push.length2 > 0) {
        push.normalize();
        other.body.applyLinearImpulse(push..scale(22));
      }
      game.addScore(points, position, color, 'bumper');
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _flash = math.max(0, _flash - dt * 4.5);
    _cooldown = math.max(0, _cooldown - dt);
  }

  @override
  void render(Canvas canvas) {
    final fill = Color.lerp(color, Colors.white, _flash)!;
    canvas.drawCircle(
      Offset.zero,
      radius + 0.28 + _flash * 0.35,
      Paint()..color = color.withValues(alpha: 0.18 + _flash * 0.2),
    );
    canvas.drawCircle(Offset.zero, radius, Paint()..color = fill);
    canvas.drawCircle(
      Offset.zero,
      radius * 0.58,
      Paint()..color = const Color(0xFF44240A),
    );
    canvas.drawCircle(
      Offset(-radius * 0.28, -radius * 0.35),
      radius * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }
}

class Spinner extends BodyComponent<MonPinballGame> with ContactCallbacks {
  Spinner({required this.spinnerCenter, required this.points})
    : super(priority: 4, renderBody: false);

  final Vector2 spinnerCenter;
  final int points;
  double _spin = 0;
  double _cooldown = 0;

  @override
  Body createBody() {
    final shape = PolygonShape()..setAsBox(1.8, 0.22, Vector2.zero(), 0.45);
    final body = world.createBody(
      BodyDef(position: spinnerCenter, userData: this),
    );
    body.createFixture(
      FixtureDef(shape, userData: this, friction: 0.05, restitution: 1.1),
    );
    return body;
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (other is PinballBall && _cooldown <= 0) {
      _spin = 1;
      _cooldown = 0.12;
      game.addScore(points, position, const Color(0xFF8CF7E2), 'spinner');
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _spin = math.max(0, _spin - dt * 2.8);
    _cooldown = math.max(0, _cooldown - dt);
  }

  @override
  void render(Canvas canvas) {
    canvas.rotate(_spin * math.pi * 2);
    final blade = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-1.9, -0.28, 3.8, 0.56),
      const Radius.circular(0.22),
    );
    canvas.drawRRect(blade, Paint()..color = const Color(0xFF8CF7E2));
    canvas.drawCircle(
      Offset.zero,
      0.46,
      Paint()..color = const Color(0xFF062C34),
    );
  }
}

class DropTarget extends BodyComponent<MonPinballGame> with ContactCallbacks {
  DropTarget({required this.targetCenter, required this.targetAngle})
    : super(priority: 4, renderBody: false);

  final Vector2 targetCenter;
  final double targetAngle;
  double _flash = 0;
  double _cooldown = 0;

  @override
  Body createBody() {
    final shape = PolygonShape()..setAsBoxXY(1.05, 0.34);
    final body = world.createBody(
      BodyDef(position: targetCenter, angle: targetAngle, userData: this),
    );
    body.createFixture(
      FixtureDef(shape, userData: this, friction: 0.15, restitution: 1.0),
    );
    return body;
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (other is PinballBall && _cooldown <= 0) {
      _flash = 1;
      _cooldown = 0.2;
      game.addScore(125, position, const Color(0xFFFF5EA8), 'target');
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _flash = math.max(0, _flash - dt * 5);
    _cooldown = math.max(0, _cooldown - dt);
  }

  @override
  void render(Canvas canvas) {
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-1.05, -0.34, 2.1, 0.68),
      const Radius.circular(0.16),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = Color.lerp(const Color(0xFFFF5EA8), Colors.white, _flash)!,
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = const Color(0xEEFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.08,
    );
  }
}

class Flipper extends BodyComponent<MonPinballGame> {
  Flipper._({
    required this.pivot,
    required this.isLeft,
    required this.restAngle,
    required this.activeAngle,
  }) : super(priority: 10, renderBody: false);

  factory Flipper.left(Vector2 pivot) => Flipper._(
    pivot: pivot,
    isLeft: true,
    restAngle: 0.28,
    activeAngle: -0.76,
  );

  factory Flipper.right(Vector2 pivot) => Flipper._(
    pivot: pivot,
    isLeft: false,
    restAngle: -0.28,
    activeAngle: 0.76,
  );

  static const double _length = 5.0;
  static const double _thickness = 0.7;

  final Vector2 pivot;
  final bool isLeft;
  final double restAngle;
  final double activeAngle;
  bool isPressed = false;

  @override
  Body createBody() {
    final centerOffset = Vector2(isLeft ? _length / 2 : -_length / 2, 0);
    final shape = PolygonShape()
      ..setAsBox(_length / 2, _thickness / 2, centerOffset, 0);
    final body = world.createBody(
      BodyDef(
        type: BodyType.kinematic,
        position: pivot,
        angle: restAngle,
        allowSleep: false,
      ),
    );
    body.createFixture(
      FixtureDef(shape, density: 4, friction: 0.22, restitution: 0.18),
    );
    return body;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final target = isPressed ? activeAngle : restAngle;
    final delta = target - body.angle;
    if (delta.abs() < 0.025) {
      body.angularVelocity = 0;
      if (!world.physicsWorld.isLocked) {
        body.setTransform(pivot, target);
      }
      return;
    }
    body.angularVelocity = (delta * 24).clamp(-24.0, 24.0);
  }

  @override
  void render(Canvas canvas) {
    final tip = Offset(isLeft ? _length : -_length, 0);
    final basePaint = Paint()
      ..color = const Color(0xFFEDF7FF)
      ..strokeWidth = _thickness
      ..strokeCap = StrokeCap.round;
    final accentPaint = Paint()
      ..color = isPressed ? const Color(0xFFFF5EA8) : const Color(0xFF36D1DC)
      ..strokeWidth = _thickness * 0.45
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset.zero, tip, basePaint);
    canvas.drawLine(Offset.zero, tip, accentPaint);
    canvas.drawCircle(
      Offset.zero,
      0.58,
      Paint()..color = const Color(0xFF0A172A),
    );
    canvas.drawCircle(
      Offset.zero,
      0.46,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.12,
    );
  }
}

class PinballBall extends BodyComponent<MonPinballGame> with ContactCallbacks {
  PinballBall({required this.startPosition})
    : super(priority: 20, renderBody: false);

  final Vector2 startPosition;
  static const double radius = 0.62;

  @override
  Body createBody() {
    final shape = CircleShape()..radius = radius;
    final body = world.createBody(
      BodyDef(
        type: BodyType.dynamic,
        position: startPosition,
        linearDamping: 0.08,
        angularDamping: 0.18,
        bullet: true,
        allowSleep: false,
        userData: this,
      ),
    );
    body.createFixture(
      FixtureDef(
        shape,
        userData: this,
        density: 2.3,
        friction: 0.18,
        restitution: 0.72,
      ),
    );
    return body;
  }

  void launch(double power) {
    body.setAwake(true);
    body.linearVelocity = Vector2(0, -35 - 48 * power);
    body.angularVelocity = 18 * power;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(
      Offset.zero,
      radius + 0.12,
      Paint()..color = const Color(0x5536D1DC),
    );
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()..color = const Color(0xFFE8F7FF),
    );
    canvas.drawCircle(
      const Offset(-0.18, -0.22),
      radius * 0.34,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = const Color(0xFF79AFC3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.07,
    );
  }
}

class LauncherView extends Component {
  LauncherView() : super(priority: 30);

  double charge = 0;

  @override
  void render(Canvas canvas) {
    final track = RRect.fromRectAndRadius(
      const Rect.fromLTWH(24.15, 37.0, 1.7, 8.4),
      const Radius.circular(0.65),
    );
    canvas.drawRRect(
      track,
      Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      track,
      Paint()
        ..color = const Color(0xAA36D1DC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.08,
    );

    final plungerTop = 44.5 - charge * 5.8;
    canvas.drawLine(
      Offset(25.0, 45.4),
      Offset(25.0, plungerTop),
      Paint()
        ..color = Color.lerp(
          const Color(0xFF36D1DC),
          const Color(0xFFFFD54F),
          charge,
        )!
        ..strokeWidth = 0.55
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(25.0, plungerTop),
      0.52,
      Paint()..color = const Color(0xFFE8F7FF),
    );
  }
}

class PulseRing extends PositionComponent {
  PulseRing({required Vector2 position, required this.color})
    : super(position: position, priority: 50);

  final Color color;
  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= 0.45) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / 0.45).clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset.zero,
      0.8 + t * 2.2,
      Paint()
        ..color = color.withValues(alpha: (1 - t) * 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.16,
    );
  }
}
