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
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: PinballStyle.text,
            minimumSize: const Size(44, 44),
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: PinballStyle.line),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth >= 700 ||
                  constraints.maxWidth > constraints.maxHeight;
              final sidebarWidth = (constraints.maxWidth * 0.4)
                  .clamp(200.0, 280.0)
                  .toDouble();
              // Keep the GameWidget mounted when changing orientation. Only the
              // Flex direction changes; input remains local to its viewport.
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
                  SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 8),
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
                        if (!wide) ...[
                          const SizedBox(height: 4),
                          const _ControlsHint(compact: true),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Routes touch input within the game viewport.
/// Visible score and other instruments are rendered separately by [_Dashboard].
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
        return Listener(
          key: const ValueKey('pinball-input-surface'),
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) =>
              _activatePointer(event.pointer, event.localPosition, constraints),
          onPointerUp: (event) => _deactivatePointer(event.pointer),
          onPointerCancel: (event) => _deactivatePointer(event.pointer),
          onPointerMove: (event) =>
              _updatePointer(event.pointer, event.localPosition),
          child: const SizedBox.expand(),
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

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.game, required this.wide});

  final MonPinballGame game;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PinballSnapshot>(
      valueListenable: game.hud,
      builder: (context, snapshot, _) {
        if (!wide) {
          return _CompactDashboard(game: game, snapshot: snapshot);
        }
        final score = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _InstrumentLabel('SCORE · 점수'),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF100B08),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF4B3328)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                child: DotMatrixScore(
                  key: const ValueKey('pinball-score'),
                  score: snapshot.score,
                ),
              ),
            ),
          ],
        );
        final lives = Semantics(
          label: '남은 공 ${snapshot.lives}',
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _InstrumentLabel('남은 공'),
              const SizedBox(height: 4),
              Text(
                snapshot.lives.toString().padLeft(2, '0'),
                key: const ValueKey('pinball-lives'),
                style: TextStyle(
                  fontSize: 30,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                  color: snapshot.gameOver
                      ? PinballStyle.coral
                      : PinballStyle.text,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (index) => Padding(
                    padding: const EdgeInsets.only(right: 5, top: 4),
                    child: SizedBox.square(
                      dimension: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < snapshot.lives
                              ? PinballStyle.chrome
                              : PinballStyle.line,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
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
                    child: Text(
                      'MON PINBALL',
                      style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  key: const ValueKey('pinball-restart'),
                  onPressed: game.restartGame,
                  child: const Text('다시 시작'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InstrumentPanel(child: score),
            const SizedBox(height: 12),
            _InstrumentPanel(child: lives),
            const SizedBox(height: 12),
            _InstrumentPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(child: _InstrumentLabel('발사 충전')),
                      Text(
                        '${(snapshot.launchCharge * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: PinballStyle.cyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    key: const ValueKey('pinball-launch-charge'),
                    value: snapshot.launchCharge,
                    minHeight: 5,
                    backgroundColor: PinballStyle.line,
                    color: PinballStyle.cyan,
                    semanticsLabel: '발사 충전',
                    semanticsValue: '${(snapshot.launchCharge * 100).round()}%',
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      snapshot.status,
                      key: const ValueKey('pinball-status'),
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: snapshot.gameOver
                            ? PinballStyle.coral
                            : PinballStyle.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _ControlsHint(compact: false),
          ],
        );
      },
    );
  }
}

class _CompactDashboard extends StatelessWidget {
  const _CompactDashboard({required this.game, required this.snapshot});

  final MonPinballGame game;
  final PinballSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'MON PINBALL',
                  style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              label: '남은 공 ${snapshot.lives}',
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '공',
                    style: TextStyle(fontSize: 12, color: PinballStyle.muted),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    snapshot.lives.toString().padLeft(2, '0'),
                    key: const ValueKey('pinball-lives'),
                    style: TextStyle(
                      fontSize: 16,
                      color: snapshot.gameOver
                          ? PinballStyle.coral
                          : PinballStyle.text,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: const ValueKey('pinball-restart'),
              onPressed: game.restartGame,
              child: const Text('다시 시작', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF100B08),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF4B3328)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: SizedBox(
              height: 32,
              child: DotMatrixScore(
                key: const ValueKey('pinball-score'),
                score: snapshot.score,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  snapshot.status,
                  key: const ValueKey('pinball-status'),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: snapshot.gameOver
                        ? PinballStyle.coral
                        : PinballStyle.muted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              child: LinearProgressIndicator(
                key: const ValueKey('pinball-launch-charge'),
                value: snapshot.launchCharge,
                minHeight: 3,
                backgroundColor: PinballStyle.line,
                color: PinballStyle.cyan,
                semanticsLabel: '발사 충전',
                semanticsValue: '${(snapshot.launchCharge * 100).round()}%',
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(snapshot.launchCharge * 100).round()}%',
              style: const TextStyle(fontSize: 11, color: PinballStyle.cyan),
            ),
          ],
        ),
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
        color: PinballStyle.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PinballStyle.line),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class _InstrumentLabel extends StatelessWidget {
  const _InstrumentLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        height: 1.4,
        color: PinballStyle.muted,
      ),
    );
  }
}

class _ControlsHint extends StatelessWidget {
  const _ControlsHint({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: compact
          ? const Row(
              key: ValueKey('pinball-controls-hint'),
              children: [
                Expanded(
                  child: Text(
                    '왼쪽 · 플리퍼',
                    style: TextStyle(fontSize: 12, color: PinballStyle.muted),
                  ),
                ),
                Expanded(
                  child: Text(
                    '오른쪽 · 플리퍼',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: PinballStyle.muted),
                  ),
                ),
              ],
            )
          : _InstrumentPanel(
              child: Column(
                key: const ValueKey('pinball-controls-hint'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _InstrumentLabel('FLIGHT CONTROLS'),
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
