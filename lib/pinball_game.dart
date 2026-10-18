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
  static const double boardHeight = 48;
  static const int _initialLives = 3;

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

  @override
  Color backgroundColor() => PinballStyle.background;

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
    world.add(MoonlitBoss(boss));
    world.add(BossWeakPoint(boss));
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
        _awardScore(damage, boss.position, PinballStyle.gold, '약점 격파');
        _damagePopup?.removeFromParent();
        _damagePopup = BossDamagePopup(
          damage: damage,
          position: boss.position + Vector2(2.2, -2.3),
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
      _launcherView.charge = _launchCharge;
      _emitHud();
    }

    if (!_gameOver &&
        !boss.defeated &&
        _ball.isMounted &&
        _ball.body.bodyType == BodyType.dynamic &&
        _ball.position.y > boardHeight + 4) {
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
    _launcherView.charge = _launchCharge;
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
        radius: 2.15,
        points: 250,
        color: PinballStyle.yellow,
      ),
      Bumper(
        // Preserve a full ball-width passage beside the diagonal launch rail.
        bumperCenter: Vector2(16.8, 14.8),
        radius: 2.15,
        points: 250,
        color: PinballStyle.red,
      ),
      Bumper(
        bumperCenter: Vector2(MoonlitTable.centerX, 22.0),
        radius: 2.15,
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

  void _clearCombatEffects() {
    _damagePopup?.removeFromParent();
    _damagePopup = null;
    for (final pulse in _scorePulses) {
      pulse.removeFromParent();
    }
    _scorePulses.clear();
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

  Vector2 _launchPosition() => Vector2(25.0, 43.0);

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

class BossDamagePopup extends PositionComponent {
  BossDamagePopup({required this.damage, required super.position})
    : super(priority: 120);

  final int damage;
  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    position.y -= dt * 1.2;
    if (_age >= 0.9) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final opacity = ((0.9 - _age) / 0.3).clamp(0.0, 1.0);
    final text = TextPainter(
      text: TextSpan(
        text: '−$damage',
        children: const [
          TextSpan(text: '\n약점 격파', style: TextStyle(fontSize: 0.8)),
        ],
        style: TextStyle(
          color: PinballStyle.gold.withValues(alpha: opacity),
          fontFamily: 'Rajdhani',
          fontFamilyFallback: const ['sans-serif'],
          fontSize: 1.3,
          fontWeight: FontWeight.w600,
          height: 1.1,
          shadows: const [Shadow(color: Colors.black, blurRadius: 0.2)],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
    text.dispose();
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
            Color(0xFFFFE9AF),
            Color(0xFFBDA36D),
            Color(0xFFFFF1CE),
            Color(0xFF745832),
            Color(0xFFE4C384),
            Color(0xFFAB8B54),
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
    if (other is! PinballBall ||
        _cooldown > 0 ||
        other.position.x < 22.0 ||
        other.body.linearVelocity.y >= 0) {
      return;
    }

    _cooldown = 0.7;
    // Keep the upward launch speed to clear the tip of the inner rail.
    other.body.linearVelocity = Vector2(-30, other.body.linearVelocity.y);
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
  void render(Canvas canvas) => drawJewelBumper(canvas, radius, color, _flash);
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
    final shape = Path()
      ..moveTo(0, -_thickness / 2)
      ..lineTo(tip.dx, -_thickness / 2)
      ..lineTo(tip.dx, _thickness / 2)
      ..lineTo(0, _thickness / 2)
      ..close();
    canvas.drawPath(
      shape.shift(const Offset(0, 0.13)),
      Paint()..color = Colors.black,
    );
    canvas.drawPath(
      shape,
      PinballStyle.lens(
        shape.getBounds(),
        PinballStyle.cyan,
        isPressed ? 0.6 : 0,
      ),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..color = PinballStyle.text
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.06,
    );
    canvas.drawLine(
      Offset(direction * 0.5, -0.19),
      tip - const Offset(0, 0.08),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..strokeWidth = 0.035,
    );
    canvas.drawCircle(Offset.zero, 0.4, Paint()..color = PinballStyle.gold);
    canvas.drawCircle(Offset.zero, 0.3, Paint()..color = PinballStyle.panel);
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5;
      canvas.drawCircle(
        Offset(math.cos(a), math.sin(a)) * 0.16,
        0.095,
        Paint()..color = PinballStyle.text,
      );
    }
    canvas.drawCircle(Offset.zero, 0.07, Paint()..color = PinballStyle.gold);
  }
}

class PinballBall extends BodyComponent<MonPinballGame> with ContactCallbacks {
  PinballBall({required this.startPosition})
    : super(priority: 80, renderBody: false);

  final Vector2 startPosition;
  static const double radius = 0.62;

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
    body.linearVelocity = Vector2(0, -55 - 48 * power);
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

class LauncherView extends Component {
  LauncherView() : super(priority: 15);

  double charge = 0;

  @override
  void render(Canvas canvas) {
    const bounds = Rect.fromLTWH(24.15, 37, 1.7, 9.7);
    final track = RRect.fromRectAndRadius(bounds, const Radius.circular(0.65));
    canvas.drawRRect(track, Paint()..color = const Color(0xFF070C19));
    canvas.drawRRect(
      track,
      Paint()
        ..color = const Color(0xFF45647D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.07,
    );
    final plungerTop = 43.85 + charge * 1.5;
    final springTop = plungerTop + 0.22;
    const springBottom = 46.2;
    canvas.drawLine(
      Offset(25, springTop),
      const Offset(25, springBottom),
      PinballStyle.metal(bounds)..strokeWidth = 0.14,
    );
    const turns = 7;
    final coilHeight = (springBottom - springTop) / turns;
    final spring = Path()..moveTo(25, springTop);
    for (var turn = 0; turn < turns; turn++) {
      spring
        ..lineTo(24.55, springTop + (turn + 0.25) * coilHeight)
        ..lineTo(25.45, springTop + (turn + 0.75) * coilHeight);
    }
    spring.lineTo(25, springBottom);
    canvas.drawPath(
      spring,
      Paint()
        ..color = const Color(0xFFA3B3C9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.07,
    );
    final cap = Rect.fromLTWH(24.35, plungerTop - 0.22, 1.3, 0.44);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cap, const Radius.circular(0.12)),
      PinballStyle.metal(cap),
    );
    const base = Rect.fromLTWH(24.35, springBottom, 1.3, 0.3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(base, const Radius.circular(0.1)),
      PinballStyle.metal(base),
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
