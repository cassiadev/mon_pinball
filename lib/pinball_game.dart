import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pinball_style.dart';

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
  Color backgroundColor() => PinballStyle.background;

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
        color: PinballStyle.red,
      ),
      Slingshot(
        vertices: [
          Vector2(22.8, 34.7),
          Vector2(18.6, 37.3),
          Vector2(21.5, 39.2),
        ],
        color: PinballStyle.yellow,
      ),
      Slingshot(
        vertices: [Vector2(5.4, 14.0), Vector2(9.2, 17.5), Vector2(4.8, 20.1)],
        color: PinballStyle.cyan,
      ),
    ];
  }

  List<Component> _buildBumpers() {
    return [
      Bumper(
        bumperCenter: Vector2(10.0, 12.0),
        radius: 1.65,
        points: 250,
        color: PinballStyle.yellow,
      ),
      Bumper(
        bumperCenter: Vector2(17.2, 14.8),
        radius: 1.65,
        points: 250,
        color: PinballStyle.red,
      ),
      Bumper(
        bumperCenter: Vector2(13.2, 22.0),
        radius: 1.9,
        points: 400,
        color: PinballStyle.cyan,
      ),
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

  ui.Picture? _art;

  @override
  void render(Canvas canvas) {
    // The lacquer, print, and screws never change during a game.
    canvas.drawPicture(_art ??= _recordArt());
  }

  @override
  void onRemove() {
    _art?.dispose();
    _art = null;
    super.onRemove();
  }

  ui.Picture _recordArt() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const board = Rect.fromLTWH(0, 0, 28, 48);
    final outline = RRect.fromRectAndRadius(
      board.deflate(0.28),
      const Radius.circular(2.2),
    );
    canvas.drawRRect(
      outline,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(18, 48),
          const [Color(0xFF644B39), Color(0xFF4B3328), Color(0xFF34221B)],
          const [0, 0.48, 1],
        ),
    );
    final bevel = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        board.bottomRight,
        const [
          Color(0xFFF6F9FF),
          Color(0xFFADBDCF),
          Color(0xFFF7FBFF),
          Color(0xFF6A7B92),
          Color(0xFFB8C8D9),
          Color(0xFF293340),
        ],
        const [0, 0.18, 0.34, 0.52, 0.72, 1],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.26;
    canvas.drawRRect(outline, bevel);
    canvas.drawRRect(
      RRect.fromRectAndRadius(board.deflate(0.48), const Radius.circular(2)),
      bevel..strokeWidth = 0.12,
    );

    final ink = Paint()
      ..color = const Color(0x8C8A6750)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.055;
    canvas.drawOval(const Rect.fromLTWH(5, 4.9, 16.8, 23.2), ink);
    canvas.drawOval(
      const Rect.fromLTWH(6.6, 7.1, 13.6, 18.8),
      Paint()
        ..color = const Color(0x448A6750)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.045,
    );
    final print = Path()
      ..moveTo(3, 7)
      ..lineTo(18, 7)
      ..lineTo(20, 9)
      ..moveTo(3, 7)
      ..lineTo(3, 10)
      ..lineTo(5, 10)
      ..moveTo(3, 22)
      ..lineTo(3, 27)
      ..lineTo(6, 27)
      ..moveTo(3, 29)
      ..lineTo(3, 33)
      ..lineTo(4.5, 33)
      ..moveTo(16, 4)
      ..lineTo(19, 4)
      ..lineTo(21, 6)
      ..moveTo(24, 9)
      ..lineTo(24, 33)
      ..moveTo(6, 23.5)
      ..lineTo(20, 10.3)
      ..moveTo(5.3, 10.5)
      ..lineTo(20, 24)
      ..moveTo(10.5, 35.2)
      ..lineTo(14, 33)
      ..lineTo(17.5, 35.2)
      ..lineTo(14, 39)
      ..close()
      ..moveTo(12, 35.3)
      ..lineTo(14, 34)
      ..lineTo(16, 35.3)
      ..lineTo(14, 37.7)
      ..close();
    for (var y = 27.4; y < 28.3; y += 0.4) {
      print
        ..moveTo(11.5, y)
        ..lineTo(15.5, y);
    }
    canvas.drawPath(print, ink);
    for (final label in const [
      ('MON PINBALL', Offset(13.2, 5.2), 0.65, 0.25),
      ('ORBITAL SYSTEMS', Offset(13.2, 6.3), 0.42, 0.15),
      ('REACTOR ARRAY', Offset(13.2, 29), 0.4, 0.12),
      ('OC', Offset(14, 36), 0.5, 0.12),
      ('FLIGHT DECK', Offset(14, 45.4), 0.42, 0.12),
    ]) {
      final text = TextPainter(
        text: TextSpan(
          text: label.$1,
          style: TextStyle(
            fontFamily: 'IBMPlexMono',
            fontSize: label.$3 * 100,
            letterSpacing: label.$4 * 100,
            color: const Color(0xFFC5AE97),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // Shape small world-space labels at a normal font size before scaling.
      canvas.save();
      canvas.translate(label.$2.dx, label.$2.dy);
      canvas.scale(0.01);
      text.paint(canvas, Offset(-text.width / 2, -text.height));
      canvas.restore();
      text.dispose();
    }
    for (final screw in const [
      Offset(4.5, 4),
      Offset(22, 4.5),
      Offset(3, 33),
      Offset(24.9, 35),
      Offset(8, 44.5),
      Offset(20, 44.5),
    ]) {
      canvas.drawCircle(
        screw,
        0.12,
        PinballStyle.metal(Rect.fromCircle(center: screw, radius: 0.12)),
      );
      canvas.drawLine(
        screw - const Offset(0.06, 0),
        screw + const Offset(0.06, 0),
        Paint()
          ..color = PinballStyle.background
          ..strokeWidth = 0.03,
      );
    }
    return recorder.endRecording();
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
    canvas.drawLine(
      p1 + const Offset(0, 0.12),
      p2 + const Offset(0, 0.12),
      Paint()
        ..color = const Color(0xFF020612)
        ..strokeWidth = width + 0.24
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      p1,
      p2,
      Paint()
        ..color = const Color(0xFF344963)
        ..strokeWidth = width + 0.12
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      p1,
      p2,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(28, 48),
          const [
            Color(0xFFFAFCFF),
            Color(0xFFA8B7CC),
            Colors.white,
            Color(0xFF344861),
            Color(0xFFC8D6E5),
            Color(0xFF75879F),
          ],
          const [0, 0.25, 0.43, 0.56, 0.76, 1],
        )
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      p1 - const Offset(0, 0.05),
      p2 - const Offset(0, 0.05),
      Paint()
        ..color = const Color(0xFFD9E9F4)
        ..strokeWidth = 0.05
        ..strokeCap = StrokeCap.round,
    );
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
    final points = vertices.map((v) => v.toOffset()).toList();
    final path = Path()..addPolygon(points, true);
    final bounds = path.getBounds();
    canvas.drawPath(
      path.shift(const Offset(0, 0.12)),
      Paint()
        ..color = const Color(0xDD020613)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.3,
    );
    canvas.drawPath(path, PinballStyle.metal(bounds));
    final center = _center.toOffset();
    final face = Path()
      ..addPolygon(
        points.map((p) => center + (p - center) * 0.78).toList(),
        true,
      );
    canvas.drawPath(face, PinballStyle.lens(bounds, color, _flash));
    canvas.drawPath(
      face,
      Paint()
        ..color = const Color(0xFF70839E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.06,
    );
    canvas.drawLine(
      points[0],
      points[1],
      Paint()
        ..color = Color.lerp(color, Colors.white, _flash * 0.7)!
        ..strokeWidth = 0.13,
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
    required this.color,
  }) : super(priority: 5, renderBody: false);

  final Vector2 bumperCenter;
  final double radius;
  final int points;
  final Color color;
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
    final bounds = Rect.fromCircle(center: Offset.zero, radius: radius);
    canvas.drawCircle(
      const Offset(0, 0.16),
      radius + 0.12,
      Paint()..color = const Color(0xD9020613),
    );
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()..color = const Color(0xFF1B2946),
    );
    canvas.drawCircle(Offset.zero, radius - 0.05, PinballStyle.metal(bounds));
    canvas.drawCircle(
      Offset.zero,
      radius - 0.05,
      Paint()
        ..color = const Color(0xFFD2DCE9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.065,
    );
    canvas.drawCircle(
      Offset.zero,
      radius * 0.72,
      Paint()..color = const Color(0xFF10182D),
    );
    canvas.drawCircle(
      Offset.zero,
      radius * 0.64,
      PinballStyle.lens(bounds, color, _flash),
    );
    canvas.drawCircle(
      Offset.zero,
      radius * 0.67,
      Paint()
        ..color = Color.lerp(color, Colors.white, _flash)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.1,
    );
    canvas.drawCircle(
      Offset.zero,
      radius * 0.53,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.035,
    );
    for (final x in [-1, 1]) {
      for (final y in [-1, 1]) {
        final screw = Offset(x * radius * 0.565, y * radius * 0.565);
        canvas.drawCircle(
          screw,
          0.075,
          Paint()..color = const Color(0xFF111B30),
        );
        canvas.drawLine(
          screw - const Offset(0.04, 0),
          screw + const Offset(0.04, 0),
          Paint()
            ..color = PinballStyle.chrome
            ..strokeWidth = 0.024,
        );
      }
    }
    final reflection = Path()
      ..moveTo(-radius * 0.48, -radius * 0.13)
      ..quadraticBezierTo(
        -radius * 0.4,
        -radius * 0.58,
        radius * 0.16,
        -radius * 0.47,
      );
    canvas.drawPath(
      reflection,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.11
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset.zero,
      radius * 0.23,
      Paint()..color = Color.lerp(color, Colors.white, _flash * 0.7)!,
    );
    final mark = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 0.055;
    canvas.drawLine(Offset(-radius * 0.16, 0), Offset(radius * 0.16, 0), mark);
    canvas.drawLine(Offset(0, -radius * 0.16), Offset(0, radius * 0.16), mark);
    if (_flash > 0) {
      canvas.drawCircle(
        Offset.zero,
        radius + 0.3,
        Paint()
          ..color = color.withValues(alpha: _flash * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.09,
      );
    }
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
      game.addScore(points, position, PinballStyle.cyan, 'spinner');
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
    canvas.save();
    canvas.rotate(0.45 + _spin * math.pi * 2);
    const bounds = Rect.fromLTWH(-1.8, -0.22, 3.6, 0.44);
    final blade = RRect.fromRectAndRadius(bounds, const Radius.circular(0.13));
    canvas.drawRRect(
      blade.shift(const Offset(0, 0.15)),
      Paint()..color = const Color(0xFF030712),
    );
    canvas.drawRRect(blade, PinballStyle.metal(bounds));
    final accent = Paint()
      ..color = PinballStyle.cyan
      ..strokeWidth = 0.11;
    canvas.drawLine(const Offset(-1.5, 0), const Offset(-0.6, 0), accent);
    canvas.drawLine(const Offset(0.6, 0), const Offset(1.5, 0), accent);
    canvas.drawCircle(
      Offset.zero,
      0.32,
      PinballStyle.metal(const Rect.fromLTWH(-0.32, -0.32, 0.64, 0.64)),
    );
    canvas.drawCircle(Offset.zero, 0.17, Paint()..color = PinballStyle.panel);
    canvas.restore();
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
      game.addScore(125, position, PinballStyle.red, 'target');
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
    const bounds = Rect.fromLTWH(-1.05, -0.34, 2.1, 0.68);
    final rect = RRect.fromRectAndRadius(bounds, const Radius.circular(0.09));
    canvas.drawRRect(
      rect.shift(const Offset(0, 0.12)),
      Paint()..color = const Color(0xFF020613),
    );
    canvas.drawRRect(rect, PinballStyle.metal(bounds));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bounds.deflate(0.12),
        const Radius.circular(0.045),
      ),
      Paint()..color = const Color(0xFFC8403C),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bounds.deflate(0.19),
        const Radius.circular(0.04),
      ),
      Paint()..color = Color.lerp(PinballStyle.red, Colors.white, _flash)!,
    );
    canvas.drawLine(
      const Offset(-0.54, -0.08),
      const Offset(0.54, -0.08),
      Paint()
        ..color = const Color(0xFFFFD6CD)
        ..strokeWidth = 0.03,
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
    final direction = isLeft ? 1.0 : -1.0;
    final tip = Offset(direction * _length, 0);
    canvas.drawLine(
      const Offset(0, 0.13),
      tip + const Offset(0, 0.13),
      Paint()
        ..color = const Color(0xFF030712)
        ..strokeWidth = 0.95
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset.zero,
      tip,
      Paint()
        ..color = const Color(0xFF25364F)
        ..strokeWidth = _thickness
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(0, -0.04),
      tip - const Offset(0, 0.04),
      PinballStyle.metal(
          Rect.fromPoints(
            Offset(math.min(0, tip.dx), -0.4),
            Offset(math.max(0, tip.dx), 0.4),
          ),
        )
        ..strokeWidth = 0.64
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(direction * 0.5, -0.18),
      Offset(direction * 4.7, -0.18),
      Paint()
        ..color = const Color(0xFFF0F7FF)
        ..strokeWidth = 0.065
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(direction * 0.65, 0.05),
      Offset(direction * 4.6, 0.05),
      Paint()
        ..color = isPressed ? Colors.white : PinballStyle.cyan
        ..strokeWidth = isPressed ? 0.16 : 0.11
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset.zero,
      0.38,
      PinballStyle.metal(const Rect.fromLTWH(-0.38, -0.38, 0.76, 0.76)),
    );
    canvas.drawCircle(Offset.zero, 0.19, Paint()..color = PinballStyle.panel);
    canvas.drawCircle(Offset.zero, 0.08, Paint()..color = PinballStyle.chrome);
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
    canvas.drawOval(
      const Rect.fromLTWH(-0.66, 0.18, 1.32, 0.58),
      Paint()..color = const Color(0xE6020512),
    );
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(-0.28, -0.3),
          radius * 1.6,
          const [
            Colors.white,
            Color(0xFFECF9FF),
            Color(0xFFB5C3D4),
            Color(0xFF475C78),
            Color(0xFFC4D3E7),
            Color(0xFF445C78),
          ],
          const [0, 0.16, 0.36, 0.52, 0.72, 1],
        ),
    );
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = const Color(0xFFE2F4FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.045,
    );
    canvas.drawOval(
      const Rect.fromLTWH(-0.39, -0.35, 0.4, 0.22),
      Paint()..color = Colors.white,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-0.39, 0.29)
        ..quadraticBezierTo(0, 0.52, 0.37, 0.24),
      Paint()
        ..color = const Color(0xFF80B9CF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.07,
    );
  }
}

class LauncherView extends Component {
  LauncherView() : super(priority: 15);

  double charge = 0;

  @override
  void render(Canvas canvas) {
    const bounds = Rect.fromLTWH(24.15, 37, 1.7, 8.4);
    final track = RRect.fromRectAndRadius(bounds, const Radius.circular(0.65));
    canvas.drawRRect(track, Paint()..color = const Color(0xFF070C19));
    canvas.drawRRect(
      track,
      Paint()
        ..color = const Color(0xFF45647D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.07,
    );
    for (var y = 42.0; y < 45; y += 0.34) {
      canvas.drawPath(
        Path()
          ..moveTo(24.65, y)
          ..lineTo(25.35, y + 0.17)
          ..lineTo(24.65, y + 0.34),
        Paint()
          ..color = const Color(0xFFA3B3C9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.07,
      );
    }
    final plungerTop = 44.5 - charge * 5.8;
    canvas.drawLine(
      const Offset(25, 45.4),
      Offset(25, plungerTop),
      PinballStyle.metal(bounds)..strokeWidth = 0.55,
    );
    canvas.drawCircle(
      Offset(25, plungerTop),
      0.52,
      PinballStyle.metal(
        Rect.fromCircle(center: Offset(25, plungerTop), radius: 0.52),
      ),
    );
    canvas.drawLine(
      const Offset(24.4, 44),
      const Offset(24.4, 38.4),
      Paint()
        ..color = PinballStyle.cyan.withValues(alpha: 0.25 + charge * 0.75)
        ..strokeWidth = 0.1,
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
