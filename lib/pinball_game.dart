import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame/input.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pinball_style.dart';
import 'moonlit_table.dart';
import 'boss_encounter.dart';
import 'moonlit_boss.dart';

class PinballSnapshot {
  const PinballSnapshot({
    required this.score,
    required this.lives,
    required this.launchCharge,
    required this.status,
    required this.gameOver,
    this.bossHealth = 16000,
    this.bossMaxHealth = 16000,
    this.bossDefeated = false,
    this.combo = 0,
  });

  final int score;
  final int lives;
  final double launchCharge;
  final String status;
  final bool gameOver;
  final int bossHealth;
  final int bossMaxHealth;
  final bool bossDefeated;
  final int combo;
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
  static const double boardHeight = 56;
  static const int _initialLives = 3;

  /// Share of the game viewport the board occupies, leaving room for trim.
  static const double boardFill = 0.96;

  /// Maps a board point to the game widget's local coordinates.
  static Offset boardToViewport(Offset board, Size viewport) {
    final zoom =
        math.min(viewport.width / boardWidth, viewport.height / boardHeight) *
        boardFill;
    return viewport.center(Offset.zero) +
        (board - const Offset(boardWidth / 2, boardHeight / 2)) * zoom;
  }

  /// The plunger lane between its inner wall and the right wall, in board
  /// units; its bottom is the plunger face the waiting ball rests on.
  static const launchLane = Rect.fromLTRB(24.4, 21, 26.9, 46.2);

  /// How far a full pull draws the plunger head (and the waiting ball) down.
  static const double plungerTravel = 2.2;

  /// One continuous boundary, so no two wall pieces meet at a ball-sized gap:
  /// left inlane guide, rounded top, right wall and the plunger face.
  static final List<Vector2> outerWall = [
    // The guide ends just above the flipper's top face, right of its pivot,
    // so a rolling ball drops onto the flipper instead of cradling beside it.
    Vector2(7.1, 50.95),
    Vector2(1.1, 44),
    ..._arc(Vector2(5.1, 4.6), math.pi, math.pi * 1.5),
    ..._arc(Vector2(22.9, 4.6), math.pi * 1.5, math.pi * 2),
    Vector2(26.9, launchLane.bottom),
    Vector2(launchLane.left, launchLane.bottom),
  ];

  /// The lane's inner wall runs straight into the right inlane guide, which
  /// mirrors the left guide about the shared centre line x = 14.
  static final List<Vector2> laneWall = [
    Vector2(launchLane.left, launchLane.top),
    Vector2(launchLane.left, 46.896),
    Vector2(20.9, 50.95),
  ];

  static List<Vector2> _arc(Vector2 center, double from, double to) => [
    for (var i = 0; i <= 8; i++)
      center +
          Vector2(
                math.cos(from + (to - from) * i / 8),
                math.sin(from + (to - from) * i / 8),
              ) *
              4,
  ];

  final ValueNotifier<PinballSnapshot> hud;
  final BossEncounter boss = BossEncounter();

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
  int _combo = 0;
  int _lives = _initialLives;
  double _launchCharge = 0;
  bool _isChargingLauncher = false;
  bool _keyboardLauncherDown = false;
  bool _gameOver = false;
  String _status = 'Drag right plunger';
  BossDamagePopup? _damagePopup;
  final _scorePulses = <PulseRing>{};

  // The Flutter garden backdrop shows around the board.
  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    camera.viewfinder.position = Vector2(boardWidth / 2, boardHeight / 2);
    camera.viewfinder.anchor = Anchor.center;

    final art = await Future.wait([
      images.load('moonlit/garden.png'),
      Flame.images.load('moonlit/tsukibina-atlas.png'),
    ]);
    world.add(MoonlitTable(art.first));
    world.add(TableTrim());
    world.add(MoonlitBoss(boss));
    world.add(BossPetals(boss));
    world.add(BossWeakPoint(boss));
    world.addAll(_buildWalls());
    world.addAll(_buildBumpers());
    world.addAll(_buildTargets());

    _leftFlipper = Flipper.left(Vector2(6.6, 52.3));
    _rightFlipper = Flipper.right(Vector2(21.4, 52.3));
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
    camera.viewfinder.zoom = math.min(zoomX, zoomY) * boardFill;
  }

  @override
  void update(double dt) {
    final from =
        isLoaded && _ball.isMounted && _ball.body.bodyType == BodyType.dynamic
        ? _ball.position.clone()
        : null;
    boss.update(dt);
    super.update(dt);
    _scorePulses.removeWhere((pulse) => pulse.parent == null);

    if (from != null && boss.active && !_gameOver) {
      final damage = boss.checkHit(
        from,
        _ball.position,
        ballRadius: PinballBall.radius,
      );
      if (damage > 0) {
        final critical = boss.lastHitCritical;
        _awardScore(
          damage,
          critical ? boss.position : _ball.position.clone(),
          critical ? PinballStyle.gold : PinballStyle.violet,
          critical ? '약점 격파' : '몸통 적중',
        );
        _damagePopup?.removeFromParent();
        _damagePopup = BossDamagePopup(
          damage: damage,
          critical: critical,
          position: critical
              ? boss.position + Vector2(2.2, -2.3)
              : _ball.position + Vector2(0, -1.6),
        );
        world.add(_damagePopup!);
        if (boss.defeated) {
          _isChargingLauncher = false;
          _launchCharge = 0;
          _launcherView.charge = 0;
          _resetBall();
          _status = '승리! 츠키비나 격파 · 다시 시작';
          _emitHud();
        }
      }
    }

    if (_isChargingLauncher && !_gameOver) {
      _launchCharge = (_launchCharge + dt * 0.8).clamp(0.0, 1.0);
      _showCharge();
      _emitHud();
    }

    if (!_gameOver &&
        !boss.defeated &&
        _ball.isMounted &&
        _ball.body.bodyType == BodyType.dynamic) {
      if (_ball.position.y > boardHeight + 4) {
        _drainBall();
      } else if (_isRestingOnPlunger()) {
        _rearmBall();
      }
    }
  }

  /// A ball that rolls back down the lane settles on the plunger face.
  bool _isRestingOnPlunger() =>
      _ball.position.x > launchLane.left &&
      _ball.position.y > launchLane.bottom - PinballBall.radius - 0.3 &&
      _ball.body.linearVelocity.length2 < 2.25;

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
    return worldPosition.x >= 24.0 &&
        worldPosition.x <= boardWidth &&
        worldPosition.y >= 38 &&
        worldPosition.y <= boardHeight;
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

  bool get _canLaunchBall =>
      _ball.isMounted && _ball.body.bodyType == BodyType.static;

  void startLauncherCharge({bool timed = true}) {
    if (_gameOver || boss.defeated) {
      restartGame();
      if (!timed) {
        return;
      }
    }
    if (!_canLaunchBall) {
      return;
    }
    _isChargingLauncher = timed;
    _status = 'Charging launcher';
    _emitHud();
  }

  void setLauncherDragCharge(double charge) {
    if (_gameOver || boss.defeated) {
      restartGame();
    }
    if (!_canLaunchBall) {
      return;
    }
    _isChargingLauncher = false;
    _launchCharge = charge.clamp(0.0, 1.0);
    _showCharge();
    _status = _launchCharge <= 0 ? 'Pull plunger down' : 'Release to launch';
    _emitHud();
  }

  void releaseLauncher() {
    if (_gameOver || boss.defeated) {
      restartGame();
      return;
    }
    if (!_canLaunchBall) {
      return;
    }

    final power = math.max(_launchCharge, 0.2);
    _isChargingLauncher = false;
    _launchCharge = 0;
    _launcherView.charge = 0;

    // The head snaps back to the lane floor and strikes the ball from there.
    _ball.body.setTransform(launchPosition, 0);
    _ball.launch(power);
    boss.start();
    _status = 'Launched';
    _emitHud();
  }

  void nudge() {
    if (_gameOver || boss.defeated || !_ball.isMounted) {
      return;
    }
    _ball.body.applyLinearImpulse(Vector2(0, -10));
    _status = 'Table nudge';
    _emitHud();
  }

  void addScore(int points, Vector2 at, Color color, String reason) {
    if (_gameOver || boss.defeated) {
      return;
    }
    _awardScore(points, at, color, reason);
  }

  void _awardScore(int points, Vector2 at, Color color, String reason) {
    _score += points;
    // Every scoring hit counts toward the current ball's combo.
    _combo += 1;
    _status = '+$points $reason';
    final pulse = PulseRing(position: at.clone(), color: color);
    _scorePulses.add(pulse);
    world.add(pulse);
    _emitHud();
  }

  void restartGame() {
    boss.reset();
    _clearCombatEffects();
    _score = 0;
    _combo = 0;
    _lives = _initialLives;
    _gameOver = false;
    _status = 'Drag right plunger';
    _launchCharge = 0;
    _isChargingLauncher = false;
    _launcherView.charge = 0;
    _resetBall();
    _emitHud();
  }

  List<Component> _buildWalls() {
    return [
      TableWall(outerWall),
      TableWall(laneWall),
      Slingshot(
        vertices: [Vector2(2.9, 18.9), Vector2(7.1, 21.5), Vector2(3.65, 23.8)],
        color: PinballStyle.cyan,
      ),
      // Each lower slingshot keeps a full-ball inlane channel beside its guide.
      Slingshot(
        vertices: [Vector2(4.8, 43.4), Vector2(9.4, 46), Vector2(7.9, 49)],
        color: PinballStyle.red,
      ),
      Slingshot(
        vertices: [
          // Flush with the lane wall: a ball against the wall lands on the
          // sloping top face instead of balancing on the corner.
          Vector2(23.9, 43.4),
          Vector2(18.6, 46),
          Vector2(20.1, 49),
        ],
        color: PinballStyle.yellow,
      ),
    ];
  }

  List<Component> _buildBumpers() {
    return [
      Bumper(
        bumperCenter: Vector2(9.6, 13.7),
        radius: 2.0,
        points: 250,
        color: PinballStyle.yellow,
      ),
      Bumper(
        bumperCenter: Vector2(18.4, 13.7),
        radius: 2.0,
        points: 250,
        color: PinballStyle.red,
      ),
      Bumper(
        bumperCenter: Vector2(MoonlitTable.centerX, 18.1),
        radius: 2.0,
        points: 400,
        color: PinballStyle.cyan,
      ),
      // Mirrored bars: the left one reads as \ and the right one as /.
      Spinner(spinnerCenter: Vector2(5.75, 30.15), barAngle: 0.5, points: 150),
      Spinner(spinnerCenter: Vector2(20.7, 30.15), barAngle: -0.5, points: 150),
    ];
  }

  List<Component> _buildTargets() {
    return [
      // Paired targets leave a full ball width between them; a narrower gap
      // lets the ball balance on both corners.
      DropTarget(targetCenter: Vector2(5.25, 39.3), targetAngle: 0.42),
      DropTarget(targetCenter: Vector2(9.9, 40.85), targetAngle: 0.25),
      DropTarget(targetCenter: Vector2(18.1, 40.85), targetAngle: -0.25),
      // Its upper corner passes the centre of a ball resting on the wall.
      DropTarget(targetCenter: Vector2(22.75, 39.3), targetAngle: -0.42),
    ];
  }

  void _drainBall() {
    boss.pause();
    _clearCombatEffects();
    _combo = 0;
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

  void _rearmBall() {
    boss.pause();
    _resetBall();
    _status = 'Ball returned - drag plunger';
    _emitHud();
  }

  void _clearCombatEffects() {
    _damagePopup?.removeFromParent();
    _damagePopup = null;
    for (final pulse in _scorePulses) {
      pulse.removeFromParent();
    }
    _scorePulses.clear();
  }

  /// Draws the plunger head down and lets the waiting ball ride on it.
  void _showCharge() {
    _launcherView.charge = _launchCharge;
    if (_canLaunchBall) {
      _ball.body.setTransform(
        launchPosition + Vector2(0, _launchCharge * plungerTravel),
        0,
      );
    }
  }

  void _resetBall() {
    if (!_ball.isMounted) {
      return;
    }
    _ball.body.setType(BodyType.static);
    _ball.body.setTransform(_launchPosition(), 0);
    _ball.body.linearVelocity = Vector2.zero();
    _ball.body.angularVelocity = 0;
  }

  Vector2 get launchPosition =>
      Vector2(launchLane.center.dx, launchLane.bottom - PinballBall.radius);

  Vector2 _launchPosition() => launchPosition;

  void _emitHud() {
    hud.value = PinballSnapshot(
      score: _score,
      lives: _lives,
      launchCharge: _launchCharge,
      status: _status,
      gameOver: _gameOver,
      bossHealth: boss.health,
      bossMaxHealth: boss.maxHealth,
      bossDefeated: boss.defeated,
      combo: _combo,
    );
  }
}

/// The outline shares the exact center and radius used by the hit sensor.
class BossWeakPoint extends Component {
  BossWeakPoint(this.boss) : super(priority: 40);

  final BossEncounter boss;

  @override
  void render(Canvas canvas) {
    if (boss.defeated) return;
    final center = boss.position.toOffset();
    canvas.drawCircle(
      center,
      boss.weakPointRadius,
      Paint()
        ..color = PinballStyle.gold.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.055,
    );
    final glint = Paint()
      ..color = PinballStyle.gold.withValues(alpha: 0.8)
      ..strokeWidth = 0.045;
    canvas.drawLine(
      center - const Offset(0.22, 0),
      center + const Offset(0.22, 0),
      glint,
    );
    canvas.drawLine(
      center - const Offset(0, 0.3),
      center + const Offset(0, 0.3),
      glint,
    );
  }
}

/// A rising damage number: gold and large for a brooch critical, lilac and
/// smaller for a body hit.
class BossDamagePopup extends PositionComponent {
  BossDamagePopup({
    required this.damage,
    required super.position,
    this.critical = true,
  }) : super(priority: 120);

  final int damage;
  final bool critical;
  double _age = 0;
  TextPainter? _text;
  double _textOpacity = -1;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    position.y -= dt * 1.2;
    if (_age >= 0.9) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    // Fade in coarse steps so the text is laid out a few times, not per frame.
    final opacity =
        (((0.9 - _age) / 0.3).clamp(0.0, 1.0) * 8).roundToDouble() / 8;
    if (opacity != _textOpacity) {
      _text?.dispose();
      _text = _layout(opacity);
      _textOpacity = opacity;
    }
    final text = _text!;
    text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
  }

  TextPainter _layout(double opacity) {
    final color = critical ? PinballStyle.gold : const Color(0xFFD9C2FF);
    return TextPainter(
      text: TextSpan(
        text: '−$damage',
        children: [
          if (critical)
            const TextSpan(text: '\n약점 격파', style: TextStyle(fontSize: 0.8)),
        ],
        style: TextStyle(
          color: color.withValues(alpha: opacity),
          fontFamily: 'Rajdhani',
          fontFamilyFallback: const ['sans-serif'],
          fontSize: critical ? 1.3 : 0.95,
          fontWeight: FontWeight.w600,
          height: 1.1,
          shadows: const [Shadow(color: Colors.black, blurRadius: 0.2)],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
  }

  @override
  void onRemove() {
    _text?.dispose();
    _text = null;
    super.onRemove();
  }
}

/// A continuous neon guide. Chain vertices share endpoints, so the ball can
/// never wedge between two separately placed rail pieces.
class TableWall extends BodyComponent<MonPinballGame> {
  TableWall(this.points) : super(priority: -10, renderBody: false);

  final List<Vector2> points;

  @override
  Body createBody() {
    final shape = ChainShape()..createChain(points);
    return world.createBody(BodyDef())
      ..createFixture(FixtureDef(shape, friction: 0.08, restitution: 0.6));
  }

  @override
  void render(Canvas canvas) {
    final path = Path()..moveTo(points.first.x, points.first.y);
    for (final point in points.skip(1)) {
      path.lineTo(point.x, point.y);
    }
    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      path.shift(const Offset(0, 0.1)),
      stroke(const Color(0xCC020612), 0.42),
    );
    canvas.drawPath(
      path,
      stroke(PinballStyle.neon.withValues(alpha: 0.45), 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.16),
    );
    canvas.drawPath(path, stroke(PinballStyle.neon, 0.13));
    canvas.drawPath(path, stroke(const Color(0xFFE7ECFF), 0.04));
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
    final center = _center.toOffset();
    final path = Path()..addPolygon(points, true);
    final bounds = path.getBounds();
    canvas.drawPath(
      path.shift(const Offset(0, 0.14)),
      Paint()..color = const Color(0xDD020613),
    );
    // A gold setting around a faceted glass face, as in the table mockup.
    canvas.drawPath(path, PinballStyle.metal(bounds));
    final inset = [for (final point in points) center + (point - center) * 0.8];
    final face = Path()..addPolygon(inset, true);
    canvas.drawPath(face, PinballStyle.lens(bounds, color, _flash));
    final facet = Paint()
      ..color = Colors.white.withValues(alpha: 0.32 + _flash * 0.45)
      ..strokeWidth = 0.045;
    for (var i = 0; i < 3; i++) {
      final opposite = (inset[(i + 1) % 3] + inset[(i + 2) % 3]) / 2;
      canvas.drawLine(inset[i], opposite, facet);
    }
    canvas.drawPath(
      face,
      Paint()
        ..color = Color.lerp(color, Colors.black, 0.55)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.06,
    );
    for (final point in points) {
      _drawGoldStud(canvas, point, 0.22);
    }
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
  void render(Canvas canvas) => drawJewelBumper(canvas, radius, color, _flash);
}

/// A pivoting bar beside the moon: hits spin it once and score.
class Spinner extends BodyComponent<MonPinballGame> with ContactCallbacks {
  Spinner({
    required this.spinnerCenter,
    required this.barAngle,
    required this.points,
  }) : super(priority: 4, renderBody: false);

  static const double halfLength = 1.75;
  static const double halfThickness = 0.3;

  final Vector2 spinnerCenter;

  /// Rest angle in radians; positive reads as \ on screen, negative as /.
  final double barAngle;
  final int points;
  double _spin = 0;
  double _cooldown = 0;

  @override
  Body createBody() {
    final shape = PolygonShape()
      ..setAsBox(halfLength, halfThickness, Vector2.zero(), barAngle);
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
    canvas.rotate(barAngle + _spin * math.pi * 2);
    const bounds = Rect.fromLTRB(
      -halfLength,
      -halfThickness,
      halfLength,
      halfThickness,
    );
    final capsule = RRect.fromRectAndRadius(
      bounds,
      const Radius.circular(halfThickness),
    );
    canvas.drawRRect(
      capsule.shift(const Offset(0, 0.15)),
      Paint()..color = const Color(0xDD030712),
    );
    canvas.drawRRect(capsule, PinballStyle.lens(bounds, PinballStyle.cyan, 0));
    canvas.drawRRect(
      capsule,
      Paint()
        ..color = const Color(0xFF0E3C3A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.06,
    );
    canvas.drawLine(
      const Offset(-halfLength + 0.45, -0.12),
      const Offset(halfLength - 0.45, -0.12),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = 0.05
        ..strokeCap = StrokeCap.round,
    );
    for (final end in const [-1.0, 1.0]) {
      final cap = Offset(end * (halfLength - 0.3), 0);
      _drawGoldStud(canvas, cap, 0.36);
      canvas.drawCircle(cap, 0.15, Paint()..color = const Color(0xFF1B1630));
    }
    canvas.restore();
  }
}

class DropTarget extends BodyComponent<MonPinballGame> with ContactCallbacks {
  DropTarget({required this.targetCenter, required this.targetAngle})
    : super(priority: 4, renderBody: false);

  static const double halfLength = 1.5;
  static const double halfHeight = 0.55;

  final Vector2 targetCenter;
  final double targetAngle;
  double _flash = 0;
  double _cooldown = 0;

  @override
  Body createBody() {
    final shape = PolygonShape()..setAsBoxXY(halfLength, halfHeight);
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
    const bounds = Rect.fromLTRB(
      -halfLength,
      -halfHeight,
      halfLength,
      halfHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bounds.shift(const Offset(0, 0.14)),
        const Radius.circular(0.14),
      ),
      Paint()..color = const Color(0xDD020613),
    );
    // A lacquered red tag between two gold caps with a stitched seam.
    final tag = bounds.deflate(0.06);
    canvas.drawRRect(
      RRect.fromRectAndRadius(tag, const Radius.circular(0.1)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(const Color(0xFFF0605A), Colors.white, _flash * 0.6)!,
            Color.lerp(const Color(0xFFC3302E), Colors.white, _flash * 0.4)!,
          ],
        ).createShader(tag),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tag, const Radius.circular(0.1)),
      Paint()
        ..color = const Color(0xFF6B1418)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.05,
    );
    final seam = Paint()
      ..color = const Color(0xFF5A1015)
      ..strokeWidth = 0.06
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-0.75, 0), const Offset(0.75, 0), seam);
    for (var i = 0; i < 4; i++) {
      final x = -0.42 + i * 0.28;
      canvas.drawLine(Offset(x + 0.08, -0.26), Offset(x - 0.08, 0.26), seam);
    }
    for (final end in const [-1.0, 1.0]) {
      final cap = Rect.fromCenter(
        center: Offset(end * (halfLength - 0.2), 0),
        width: 0.42,
        height: halfHeight * 2 + 0.06,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(cap, const Radius.circular(0.12)),
        PinballStyle.metal(cap),
      );
    }
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
    restAngle: 0.44,
    activeAngle: -0.42,
  );

  factory Flipper.right(Vector2 pivot) => Flipper._(
    pivot: pivot,
    isLeft: false,
    restAngle: -0.44,
    activeAngle: 0.42,
  );

  static const double length = 5.9;
  static const double baseRadius = 0.75;
  static const double tipRadius = 0.42;

  final Vector2 pivot;
  final bool isLeft;
  final double restAngle;
  final double activeAngle;
  bool isPressed = false;

  double get _direction => isLeft ? 1.0 : -1.0;

  /// Outer tangents of the base and tip circles, clockwise from the base top.
  List<Vector2> get _tangents {
    final sine = (baseRadius - tipRadius) / length;
    final cosine = math.sqrt(1 - sine * sine);
    final dx = _direction;
    return [
      Vector2(dx * baseRadius * sine, -baseRadius * cosine),
      Vector2(dx * (length + tipRadius * sine), -tipRadius * cosine),
      Vector2(dx * (length + tipRadius * sine), tipRadius * cosine),
      Vector2(dx * baseRadius * sine, baseRadius * cosine),
    ];
  }

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef(
        type: BodyType.kinematic,
        position: pivot,
        angle: restAngle,
        allowSleep: false,
      ),
    );
    // The tapered blade: a rounded base, a rounded tip and the hull between.
    for (final shape in <Shape>[
      CircleShape(radius: baseRadius),
      CircleShape(radius: tipRadius, position: Vector2(_direction * length, 0)),
      PolygonShape()..set(_tangents),
    ]) {
      body.createFixture(
        FixtureDef(shape, density: 4, friction: 0.22, restitution: 0.18),
      );
    }
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
    final tip = Offset(_direction * length, 0);
    final t = _tangents.map((v) => v.toOffset()).toList();
    final shape = Path()
      ..moveTo(t[0].dx, t[0].dy)
      ..lineTo(t[1].dx, t[1].dy)
      ..arcToPoint(
        t[2],
        radius: const Radius.circular(tipRadius),
        clockwise: isLeft,
      )
      ..lineTo(t[3].dx, t[3].dy)
      ..arcToPoint(
        t[0],
        radius: const Radius.circular(baseRadius),
        clockwise: isLeft,
      )
      ..close();
    canvas.drawPath(
      shape.shift(const Offset(0, 0.16)),
      Paint()..color = const Color(0xDD000000),
    );
    canvas.drawPath(
      shape,
      PinballStyle.lens(
        shape.getBounds(),
        PinballStyle.cyan,
        isPressed ? 0.5 : 0,
      ),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..color = PinballStyle.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.08,
    );
    canvas.drawLine(
      Offset(_direction * 1.1, -0.36),
      tip + Offset(-_direction * 0.4, -0.24),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..strokeWidth = 0.06
        ..strokeCap = StrokeCap.round,
    );
    _drawGoldStud(canvas, tip, 0.3);
    // Gold mon cap with a five-petal flower over the pivot.
    _drawGoldStud(canvas, Offset.zero, 0.64);
    canvas.drawCircle(
      Offset.zero,
      0.48,
      Paint()..color = const Color(0xFF1A1733),
    );
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * math.pi * 2 / 5;
      canvas.drawCircle(
        Offset(math.cos(a), math.sin(a)) * 0.2,
        0.13,
        Paint()..color = PinballStyle.text,
      );
    }
    canvas.drawCircle(Offset.zero, 0.08, Paint()..color = PinballStyle.gold);
  }
}

class PinballBall extends BodyComponent<MonPinballGame> with ContactCallbacks {
  PinballBall({required this.startPosition})
    : super(priority: 80, renderBody: false);

  final Vector2 startPosition;
  static const double radius = 0.7;

  @override
  Body createBody() {
    final shape = CircleShape()..radius = radius;
    final body = world.createBody(
      BodyDef(
        // Hold the ball at the plunger until the player launches it.
        type: BodyType.static,
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
    body.setType(BodyType.dynamic);
    body.setAwake(true);
    body.linearVelocity = Vector2(0, -57.5 - 42.5 * power);
    body.angularVelocity = 18 * power;
  }

  @override
  void render(Canvas canvas) {
    final velocity = body.linearVelocity;
    if (body.bodyType == BodyType.dynamic && velocity.length2 > 4) {
      final a = body.angle;
      final local = Offset(
        velocity.x * math.cos(a) + velocity.y * math.sin(a),
        -velocity.x * math.sin(a) + velocity.y * math.cos(a),
      );
      final unit = local / local.distance;
      final tail = unit * -(local.distance * 0.05).clamp(0.2, 3.0);
      final side = Offset(-unit.dy, unit.dx) * 0.32;
      canvas.drawPath(
        Path()
          ..moveTo(tail.dx, tail.dy)
          ..lineTo(side.dx, side.dy)
          ..lineTo(-side.dx, -side.dy)
          ..close(),
        Paint()
          ..shader = ui.Gradient.linear(tail, Offset.zero, [
            PinballStyle.cyan.withValues(alpha: 0),
            PinballStyle.text.withValues(alpha: 0.65),
          ]),
      );
    }
    canvas.drawCircle(
      Offset.zero,
      radius + 0.12,
      Paint()..color = const Color(0xFF090C20),
    );
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(-0.2, -0.2),
          radius * 1.5,
          const [Colors.white, Color(0xFFFFF6CF), Color(0xFFD8CEA5)],
          const [0, 0.6, 1],
        ),
    );
  }
}

/// The plunger housing below the lane floor, with charge ticks above it.
class LauncherView extends Component {
  LauncherView() : super(priority: 15);

  double charge = 0;

  @override
  void render(Canvas canvas) {
    const lane = MonPinballGame.launchLane;
    final x = lane.center.dx;
    for (var tick = 0; tick < 5; tick++) {
      final lit = charge * 5 > tick;
      canvas.drawLine(
        Offset(x - 0.42, lane.bottom - 1.8 - tick * 0.9),
        Offset(x + 0.42, lane.bottom - 1.8 - tick * 0.9),
        Paint()
          ..color = PinballStyle.cyan.withValues(alpha: lit ? 0.95 : 0.3)
          ..strokeWidth = 0.14,
      );
    }

    // Pulling draws the head down and compresses the coil on a fixed base.
    final housing = Rect.fromLTRB(
      lane.left + 0.15,
      lane.bottom + 0.15,
      lane.right - 0.15,
      lane.bottom + 5.6,
    );
    final capsule = RRect.fromRectAndRadius(
      housing,
      const Radius.circular(0.55),
    );
    canvas.drawRRect(capsule, Paint()..color = const Color(0xFF070B1A));
    canvas.drawRRect(
      capsule,
      PinballStyle.metal(housing)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.16,
    );
    final headTop = lane.bottom + charge * MonPinballGame.plungerTravel;
    final springTop = headTop + 0.62;
    final base = Rect.fromLTRB(
      x - 0.6,
      housing.bottom - 0.62,
      x + 0.6,
      housing.bottom - 0.2,
    );
    canvas.drawLine(
      Offset(x, springTop),
      Offset(x, base.top),
      Paint()
        ..color = const Color(0xFF6F7C92)
        ..strokeWidth = 0.14,
    );
    const turns = 8;
    final coil = (base.top - springTop) / turns;
    final spring = Path()..moveTo(x, springTop);
    for (var turn = 0; turn < turns; turn++) {
      spring
        ..lineTo(x - 0.62, springTop + (turn + 0.25) * coil)
        ..lineTo(x + 0.62, springTop + (turn + 0.75) * coil);
    }
    spring.lineTo(x, base.top);
    canvas.drawPath(
      spring,
      Paint()
        ..color = Color.lerp(
          const Color(0xFFC9D3E6),
          PinballStyle.cyan,
          charge * 0.5,
        )!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(base, const Radius.circular(0.1)),
      PinballStyle.metal(base),
    );
    final head = Rect.fromLTWH(x - 0.72, headTop - 0.04, 1.44, 0.66);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        head,
        topLeft: const Radius.circular(0.3),
        topRight: const Radius.circular(0.3),
        bottomLeft: const Radius.circular(0.12),
        bottomRight: const Radius.circular(0.12),
      ),
      PinballStyle.metal(head),
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

void _drawGoldStud(Canvas canvas, Offset center, double radius) {
  final bounds = Rect.fromCircle(center: center, radius: radius);
  canvas.drawCircle(center, radius, PinballStyle.metal(bounds));
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = const Color(0xFF5B421F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.16,
  );
  canvas.drawCircle(
    center - Offset(radius, radius) * 0.3,
    radius * 0.25,
    Paint()..color = Colors.white.withValues(alpha: 0.55),
  );
}
