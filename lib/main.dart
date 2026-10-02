import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'pinball_game.dart';

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
          seedColor: const Color(0xFF36D1DC),
          brightness: Brightness.dark,
        ),
        fontFamily: 'monospace',
      ),
      home: PinballScreen(gameFactory: gameFactory),
    );
  }
}

class PinballScreen extends StatelessWidget {
  const PinballScreen({required this.gameFactory, super.key});

  final PinballGameFactory gameFactory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050714),
      body: GameWidget<MonPinballGame>.controlled(
        gameFactory: gameFactory,
        initialActiveOverlays: const ['hud'],
        overlayBuilderMap: {'hud': (context, game) => PinballHud(game: game)},
      ),
    );
  }
}

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
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Listener(
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
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: ValueListenableBuilder<PinballSnapshot>(
              valueListenable: widget.game.hud,
              builder: (context, snapshot, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _GlassPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'MON PINBALL',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                snapshot.score.toString().padLeft(7, '0'),
                                key: const ValueKey('pinball-score'),
                                style: const TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _GlassPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Lives ${snapshot.lives}',
                                  key: const ValueKey('pinball-lives'),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: LinearProgressIndicator(
                                    key: const ValueKey(
                                      'pinball-launch-charge',
                                    ),
                                    minHeight: 8,
                                    value: snapshot.launchCharge,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.12,
                                    ),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color.lerp(
                                        const Color(0xFF36D1DC),
                                        const Color(0xFFFFD54F),
                                        snapshot.launchCharge,
                                      )!,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  snapshot.status,
                                  key: const ValueKey('pinball-status'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: snapshot.gameOver
                                        ? const Color(0xFFFFD54F)
                                        : Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _GlassPanel(
                          child: TextButton(
                            key: const ValueKey('pinball-restart'),
                            onPressed: widget.game.restartGame,
                            child: const Text('R'),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _ControlsHint(gameOver: snapshot.gameOver),
                  ],
                );
              },
            ),
          ),
        ),
      ],
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

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC07101E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: child,
      ),
    );
  }
}

class _ControlsHint extends StatelessWidget {
  const _ControlsHint({required this.gameOver});

  final bool gameOver;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: _GlassPanel(
        child: Text(
          gameOver
              ? 'GAME OVER  |  drag right plunger / Space / R to restart'
              : 'Hold left/right screen for flippers  |  drag right plunger down, release to launch  |  W/↑ nudges',
          key: const ValueKey('pinball-controls-hint'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
