import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'pinball_game.dart';
import 'pinball_style.dart';

void main() {
  runApp(const MonPinballApp());
}

typedef PinballGameFactory = MonPinballGame Function();

class MonPinballApp extends StatelessWidget {
  const MonPinballApp({super.key, this.gameFactory = MonPinballGame.new});

  final PinballGameFactory gameFactory;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mon Pinball',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: PinballStyle.cyan,
          brightness: Brightness.dark,
          surface: PinballStyle.panel,
        ),
        scaffoldBackgroundColor: PinballStyle.background,
        fontFamily: 'IBMPlexMono',
        fontFamilyFallback: const ['sans-serif'],
      ),
      home: PinballScreen(gameFactory: gameFactory),
    );
  }
}

class PinballScreen extends StatefulWidget {
  const PinballScreen({required this.gameFactory, super.key});

  final PinballGameFactory gameFactory;

  @override
  State<PinballScreen> createState() => _PinballScreenState();
}

class _PinballScreenState extends State<PinballScreen> {
  late final MonPinballGame _game = widget.gameFactory();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _GardenBackdrop(game: _game),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide =
                      constraints.maxWidth >= 700 ||
                      constraints.maxWidth > constraints.maxHeight;
                  final sidebarWidth = (constraints.maxWidth * 0.4)
                      .clamp(200.0, 280.0)
                      .toDouble();
                  // Keep the GameWidget mounted when changing orientation. Only
                  // the Flex direction changes; input remains local to its
                  // viewport.
                  return Flex(
                    direction: wide ? Axis.horizontal : Axis.vertical,
                    textDirection: TextDirection.rtl,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: wide ? sidebarWidth : null,
                        child: ConstrainedBox(
                          // Large text can scroll without consuming the table.
                          constraints: BoxConstraints(
                            maxHeight: wide
                                ? constraints.maxHeight
                                : constraints.maxHeight * 0.42,
                          ),
                          child: SingleChildScrollView(
                            child: _Dashboard(game: _game, wide: wide),
                          ),
                        ),
                      ),
                      SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio:
                                      MonPinballGame.boardWidth /
                                      MonPinballGame.boardHeight,
                                  child: GameWidget<MonPinballGame>(
                                    game: _game,
                                    initialActiveOverlays: const ['hud'],
                                    overlayBuilderMap: {
                                      'hud': (context, game) =>
                                          PinballHud(game: game),
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The garden plate behind the whole screen; wisteria and lanterns frame the
/// table as in the mockup. It reuses the texture the game already decoded.
class _GardenBackdrop extends StatelessWidget {
  const _GardenBackdrop({required this.game});

  final MonPinballGame game;

  static const _key = 'moonlit/garden.png';

  @override
  Widget build(BuildContext context) {
    if (game.images.containsKey(_key)) {
      return _paint(game.images.fromCache(_key));
    }
    return FutureBuilder<ui.Image>(
      future: game.images.load(_key),
      builder: (context, snapshot) => snapshot.hasData
          ? _paint(snapshot.data!)
          : const ColoredBox(color: PinballStyle.background),
    );
  }

  Widget _paint(ui.Image image) =>
      CustomPaint(painter: _BackdropPainter(image));
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final source = Size(image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(BoxFit.cover, source, size);
    // One pass: the plate is dimmed as it is drawn, so the header and board
    // stay the brightest layer without a second full-screen fill.
    canvas.drawImageRect(
      image,
      Alignment.center.inscribe(fitted.source, Offset.zero & source),
      Alignment.center.inscribe(fitted.destination, bounds),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = const ColorFilter.mode(
          Color(0x7A050817),
          BlendMode.srcATop,
        ),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) =>
      image != oldDelegate.image;
}

/// Routes touch input within the game viewport and labels the controls on
/// the table itself. Instruments are rendered separately by [_Dashboard].
class PinballHud extends StatefulWidget {
  const PinballHud({required this.game, super.key});

  final MonPinballGame game;

  @override
  State<PinballHud> createState() => _PinballHudState();
}

class _PinballHudState extends State<PinballHud> {
  final Map<int, _TouchAction> _activeTouches = {};
  final Map<int, _LauncherDrag> _launcherDrags = {};

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(child: _TableLabels(size: constraints.biggest)),
            Positioned.fill(
              child: Listener(
                key: const ValueKey('pinball-input-surface'),
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) => _activatePointer(
                  event.pointer,
                  event.localPosition,
                  constraints,
                ),
                onPointerUp: (event) => _deactivatePointer(event.pointer),
                onPointerCancel: (event) => _deactivatePointer(event.pointer),
                onPointerMove: (event) =>
                    _updatePointer(event.pointer, event.localPosition),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        );
      },
    );
  }

  void _activatePointer(
    int pointer,
    Offset localPosition,
    BoxConstraints constraints,
  ) {
    final width = constraints.maxWidth;
    final action = widget.game.isLauncherTouch(localPosition)
        ? _TouchAction.launcher
        : localPosition.dx < width * 0.5
        ? _TouchAction.left
        : _TouchAction.right;

    _activeTouches[pointer] = action;
    switch (action) {
      case _TouchAction.left:
        widget.game.setLeftFlipper(true);
      case _TouchAction.right:
        widget.game.setRightFlipper(true);
      case _TouchAction.launcher:
        _launcherDrags[pointer] = _LauncherDrag(localPosition);
        widget.game.startLauncherCharge(timed: false);
        widget.game.setLauncherDragCharge(0);
    }
  }

  void _updatePointer(int pointer, Offset localPosition) {
    final action = _activeTouches[pointer];
    if (action != _TouchAction.launcher) {
      return;
    }

    final drag = _launcherDrags[pointer];
    if (drag == null) {
      return;
    }

    final charge = widget.game.launcherChargeFromDrag(
      startScreenPosition: drag.startPosition,
      currentScreenPosition: localPosition,
    );
    widget.game.setLauncherDragCharge(charge);
  }

  void _deactivatePointer(int pointer) {
    final action = _activeTouches.remove(pointer);
    if (action == null) {
      return;
    }

    switch (action) {
      case _TouchAction.left:
        if (!_activeTouches.containsValue(_TouchAction.left)) {
          widget.game.setLeftFlipper(false);
        }
      case _TouchAction.right:
        if (!_activeTouches.containsValue(_TouchAction.right)) {
          widget.game.setRightFlipper(false);
        }
      case _TouchAction.launcher:
        _launcherDrags.remove(pointer);
        if (!_activeTouches.containsValue(_TouchAction.launcher)) {
          widget.game.releaseLauncher();
        }
    }
  }
}

enum _TouchAction { left, right, launcher }

class _LauncherDrag {
  const _LauncherDrag(this.startPosition);

  final Offset startPosition;
}

/// Flipper and plunger captions printed on the table under each control.
class _TableLabels extends StatelessWidget {
  const _TableLabels({required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) {
    final unit =
        math.min(
          size.width / MonPinballGame.boardWidth,
          size.height / MonPinballGame.boardHeight,
        ) *
        MonPinballGame.boardFill;
    final style = TextStyle(
      fontSize: unit * 0.78,
      height: 1.15,
      color: PinballStyle.text.withValues(alpha: 0.9),
      shadows: const [Shadow(color: Colors.black, offset: Offset(0, 1))],
    );
    Widget caption(Offset board, Widget child) {
      final at = MonPinballGame.boardToViewport(board, size);
      return Positioned(
        left: at.dx - unit * 4,
        top: at.dy,
        width: unit * 8,
        child: Center(child: child),
      );
    }

    Widget arrow(AxisDirection direction) => Padding(
      padding: EdgeInsets.symmetric(horizontal: unit * 0.2),
      child: CustomPaint(
        size: Size.square(unit * 0.8),
        painter: _ArrowBadgePainter(direction),
      ),
    );

    return IgnorePointer(
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: ExcludeSemantics(
          child: Stack(
            key: const ValueKey('pinball-controls-hint'),
            children: [
              caption(
                const Offset(8.3, 53.95),
                Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        arrow(AxisDirection.left),
                        Text('왼쪽', style: style),
                      ],
                    ),
                    Text('플리퍼', style: style),
                  ],
                ),
              ),
              caption(
                const Offset(19.7, 53.95),
                Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('오른쪽', style: style),
                        arrow(AxisDirection.right),
                      ],
                    ),
                    Text('플리퍼', style: style),
                  ],
                ),
              ),
              caption(
                Offset(
                  MonPinballGame.launchLane.center.dx - 0.45,
                  MonPinballGame.launchLane.bottom + 5.9,
                ),
                Column(
                  children: [
                    arrow(AxisDirection.up),
                    Text('당겨서 발사', style: style, softWrap: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrowBadgePainter extends CustomPainter {
  const _ArrowBadgePainter(this.direction);

  final AxisDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    if (direction != AxisDirection.up) {
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFFB8A6F2));
    }
    final s = direction == AxisDirection.up ? r * 0.8 : r * 0.5;
    final (tip, base1, base2) = switch (direction) {
      AxisDirection.left => (
        c + Offset(-s, 0),
        c + Offset(s * 0.8, -s),
        c + Offset(s * 0.8, s),
      ),
      AxisDirection.right => (
        c + Offset(s, 0),
        c + Offset(-s * 0.8, -s),
        c + Offset(-s * 0.8, s),
      ),
      _ => (
        c + Offset(0, -s),
        c + Offset(-s * 1.1, s * 0.7),
        c + Offset(s * 1.1, s * 0.7),
      ),
    };
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(base1.dx, base1.dy)
        ..lineTo(base2.dx, base2.dy)
        ..close(),
      Paint()
        ..color = direction == AxisDirection.up
            ? PinballStyle.text
            : const Color(0xFF1B1835),
    );
  }

  @override
  bool shouldRepaint(_ArrowBadgePainter oldDelegate) =>
      direction != oldDelegate.direction;
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.game, required this.wide});

  final MonPinballGame game;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PinballSnapshot>(
      valueListenable: game.hud,
      builder: (context, snapshot, _) => wide
          ? _Sidebar(game: game, snapshot: snapshot)
          : _MoonlitHeader(game: game, snapshot: snapshot),
    );
  }
}

/// Portrait header from the mockup: title, score and restart; balls and
/// combo; then the boss's remaining health.
class _MoonlitHeader extends StatelessWidget {
  const _MoonlitHeader({required this.game, required this.snapshot});

  final MonPinballGame game;
  final PinballSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The mockup leaves the middle of the balls row free; the live status
        // uses it unless the screen is too narrow for a readable line.
        final inlineStatus = constraints.maxWidth >= 350;
        final status = _StatusLine(snapshot: snapshot, compact: true);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Flexible(
                  flex: 5,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: _TitleMark(compact: true),
                  ),
                ),
                const _Divider(height: 34),
                Expanded(flex: 4, child: _ScoreReadout(snapshot: snapshot)),
                const SizedBox(width: 8),
                _RestartButton(onPressed: game.restartGame),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const SizedBox(width: 6),
                _Lives(snapshot: snapshot),
                if (inlineStatus) ...[
                  const _Divider(height: 14),
                  Expanded(child: status),
                  const SizedBox(width: 10),
                ] else
                  const Spacer(),
                _ComboBadge(snapshot: snapshot),
                const SizedBox(width: 6),
              ],
            ),
            if (!inlineStatus)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 3, 6, 0),
                child: status,
              ),
            const SizedBox(height: 4),
            _BossHealth(snapshot: snapshot),
          ],
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.game, required this.snapshot});

  final MonPinballGame game;
  final PinballSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _TitleMark(compact: false),
              ),
            ),
            const SizedBox(width: 8),
            _RestartButton(onPressed: game.restartGame),
          ],
        ),
        const SizedBox(height: 12),
        _InstrumentPanel(child: _ScoreReadout(snapshot: snapshot, height: 34)),
        const SizedBox(height: 12),
        _InstrumentPanel(
          child: Row(
            children: [
              _Lives(snapshot: snapshot),
              const Spacer(),
              _ComboBadge(snapshot: snapshot),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _InstrumentPanel(child: _BossHealth(snapshot: snapshot)),
        const SizedBox(height: 12),
        _InstrumentPanel(child: _StatusLine(snapshot: snapshot)),
        const SizedBox(height: 12),
        const _ControlsList(),
      ],
    );
  }
}

class _TitleMark extends StatelessWidget {
  const _TitleMark({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CrescentMark(size: compact ? 26 : 30),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'MON PINBALL',
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: compact ? 19 : 26,
                fontWeight: FontWeight.w600,
                letterSpacing: compact ? 2.2 : 2.6,
                height: 1.1,
                color: PinballStyle.text,
              ),
            ),
            Text(
              '달빛 정원',
              style: TextStyle(
                fontSize: compact ? 11 : 13,
                letterSpacing: 4,
                height: 1.3,
                color: const Color(0xFFC9B5F5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScoreReadout extends StatelessWidget {
  const _ScoreReadout({required this.snapshot, this.height = 21});

  final PinballSnapshot snapshot;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '점수',
          style: TextStyle(
            fontSize: 10,
            height: 1.3,
            color: PinballStyle.muted,
          ),
        ),
        SizedBox(
          height: height,
          child: Align(
            alignment: Alignment.centerLeft,
            child: DotMatrixScore(
              key: const ValueKey('pinball-score'),
              score: snapshot.score,
            ),
          ),
        ),
      ],
    );
  }
}

class _RestartButton extends StatelessWidget {
  const _RestartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const ValueKey('pinball-restart'),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: PinballStyle.text,
        // A full 44 px target without Material's extra 48 px padding row.
        minimumSize: const Size(44, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        backgroundColor: const Color(0xCC0B0E26),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: PinballStyle.gold, width: 1.2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CustomPaint(size: Size.square(15), painter: _ReplayPainter()),
          const SizedBox(width: 6),
          const Text('다시 시작', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _ReplayPainter extends CustomPainter {
  const _ReplayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.38;
    final stroke = Paint()
      ..color = PinballStyle.text
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi * 0.35,
      math.pi * 1.6,
      false,
      stroke,
    );
    final head =
        c + Offset(math.cos(-math.pi * 0.35), math.sin(-math.pi * 0.35)) * r;
    canvas.drawPath(
      Path()
        ..moveTo(head.dx + 2.6, head.dy - 3.2)
        ..lineTo(head.dx + 2.2, head.dy + 1.2)
        ..lineTo(head.dx - 2, head.dy - 0.4)
        ..close(),
      Paint()..color = PinballStyle.text,
    );
  }

  @override
  bool shouldRepaint(_ReplayPainter oldDelegate) => false;
}

class _Lives extends StatelessWidget {
  const _Lives({required this.snapshot});

  final PinballSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '남은 공 ${snapshot.lives}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '공',
            style: TextStyle(
              fontSize: 13,
              color: snapshot.gameOver ? PinballStyle.coral : PinballStyle.text,
            ),
          ),
          const SizedBox(width: 10),
          LivesIndicator(
            key: const ValueKey('pinball-lives'),
            lives: snapshot.lives,
          ),
        ],
      ),
    );
  }
}

/// The combo count in a lilac ring; screen readers get it from the boss bar.
class _ComboBadge extends StatelessWidget {
  const _ComboBadge({required this.snapshot});

  final PinballSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        key: const ValueKey('pinball-combo'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            padding: const EdgeInsets.symmetric(horizontal: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: PinballStyle.pink, width: 1.6),
              color: const Color(0xCC1A1036),
              boxShadow: [
                BoxShadow(
                  color: PinballStyle.pink.withValues(alpha: 0.35),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Text(
              '${snapshot.combo}',
              style: const TextStyle(
                fontSize: 13,
                height: 1,
                color: Color(0xFFF2B8E4),
              ),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            snapshot.bossDefeated ? '격파' : 'COMBO',
            style: TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
              color: snapshot.bossDefeated
                  ? PinballStyle.gold
                  : PinballStyle.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _BossHealth extends StatelessWidget {
  const _BossHealth({required this.snapshot});

  final PinballSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final remaining = snapshot.bossMaxHealth > 0
        ? (snapshot.bossHealth / snapshot.bossMaxHealth).clamp(0.0, 1.0)
        : 0.0;
    return Semantics(
      label: '츠키비나 남은 체력 ${snapshot.bossHealth} / ${snapshot.bossMaxHealth}',
      value: '${snapshot.combo} 콤보${snapshot.bossDefeated ? ', 격파' : ''}',
      excludeSemantics: true,
      child: Row(
        children: [
          const _Ornament(),
          const SizedBox(width: 6),
          const Text(
            '츠키비나',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: PinballStyle.text,
            ),
          ),
          const _Divider(height: 14),
          const Text(
            '남은 체력',
            style: TextStyle(fontSize: 10, color: PinballStyle.muted),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: HealthBar(
              key: const ValueKey('pinball-boss-health'),
              value: remaining,
              defeated: snapshot.bossDefeated,
            ),
          ),
          const SizedBox(width: 6),
          const _Ornament(),
        ],
      ),
    );
  }
}

class _Ornament extends StatelessWidget {
  const _Ornament();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: PinballStyle.gold,
          border: Border.all(color: const Color(0xFF6E5428), width: 0.8),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 9),
      color: PinballStyle.line,
    );
  }
}

/// Live status and launch charge; in portrait it shares the balls row.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.snapshot, this.compact = false});

  final PinballSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final percent = '${(snapshot.launchCharge * 100).round()}%';
    return Row(
      children: [
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              snapshot.status,
              key: const ValueKey('pinball-status'),
              style: TextStyle(
                fontSize: compact ? 10.5 : 11,
                height: 1.3,
                color: snapshot.gameOver
                    ? PinballStyle.coral
                    : PinballStyle.muted,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: compact ? 30 : 44,
          child: LinearProgressIndicator(
            key: const ValueKey('pinball-launch-charge'),
            value: snapshot.launchCharge,
            minHeight: 3,
            backgroundColor: PinballStyle.line,
            color: PinballStyle.cyan,
            semanticsLabel: '발사 충전',
            semanticsValue: percent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 6),
          Text(
            percent,
            style: const TextStyle(fontSize: 11, color: PinballStyle.cyan),
          ),
        ],
      ],
    );
  }
}

class _InstrumentPanel extends StatelessWidget {
  const _InstrumentPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PinballStyle.panel.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PinballStyle.line),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class _ControlsList extends StatelessWidget {
  const _ControlsList();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: _InstrumentPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'FLIGHT CONTROLS',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: PinballStyle.muted,
              ),
            ),
            const SizedBox(height: 12),
            for (final control in const [
              ('A / ←', '왼쪽 플리퍼'),
              ('D / →', '오른쪽 플리퍼'),
              ('Space / ↓', '충전 · 발사'),
              ('W / ↑', '테이블 넛지'),
              ('R', '다시 시작'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 104,
                      child: Text(
                        control.$1,
                        style: const TextStyle(
                          fontSize: 13,
                          color: PinballStyle.chrome,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        control.$2,
                        style: const TextStyle(
                          fontSize: 13,
                          color: PinballStyle.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              '발사 레인을 아래로 당겼다 놓으세요.',
              style: TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
