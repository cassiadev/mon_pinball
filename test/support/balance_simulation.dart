import 'dart:collection';
import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/boss_encounter.dart';
import 'package:mon_pinball/main.dart';
import 'package:mon_pinball/pinball_game.dart';
import 'package:mon_pinball/pinball_progress.dart';

import 'pinball_test_harness.dart';

enum BalancePolicy {
  launchOnly,
  held,
  periodic,
  reactive,
  earlyReactive,
  predictive,
}

/// Diagnostic control models, not calibrated representations of human skill.
class BalancePlayer {
  BalancePlayer(this.policy, int seed)
    : _launchRandom = math.Random(seed),
      _reactionRandom = math.Random(seed ^ 0x51a7);

  final BalancePolicy policy;
  final math.Random _launchRandom;
  final math.Random _reactionRandom;
  int launches = 0;
  int flipperPresses = 0;
  int nudges = 0;
  final launchCharges = <double>[];
  int _launchWait = 0;
  int _leftUntil = 0;
  int _rightUntil = 0;
  int _readyAt = 0;
  int _scheduledAt = -1;
  int _scheduledSide = 0;
  bool _left = false;
  bool _right = false;
  static const _charges = [0.2, 0.35, 0.5, 0.65, 0.8, 1.0];

  void updateControls(MonPinballGame game, PinballBall ball, int frame) {
    if (game.hud.value.gameOver || game.stageCleared) return;
    final atLauncher =
        ball.body.bodyType == BodyType.static &&
        ball.position.distanceTo(game.launchPosition) < 0.05;
    if (atLauncher) {
      _setFlippers(game, false, false);
      if (_launchWait == 0) _launchWait = 12 + _launchRandom.nextInt(19);
      if (--_launchWait == 0) {
        final charge = _charges[_launchRandom.nextInt(_charges.length)];
        game.startLauncherCharge(timed: false);
        game.setLauncherDragCharge(charge);
        game.releaseLauncher();
        launches++;
        launchCharges.add(charge);
      }
      return;
    }
    _launchWait = 0;
    if (ball.body.bodyType != BodyType.dynamic) {
      _setFlippers(game, false, false);
      return;
    }
    final p = ball.position;
    final v = ball.body.linearVelocity;
    switch (policy) {
      case BalancePolicy.launchOnly:
        _setFlippers(game, false, false);
      case BalancePolicy.held:
        _setFlippers(game, true, true);
      case BalancePolicy.periodic:
        final pressed = p.y > 42 && frame % 20 < 10;
        _setFlippers(game, pressed, pressed);
      case BalancePolicy.reactive:
      case BalancePolicy.earlyReactive:
      case BalancePolicy.predictive:
        if (_scheduledAt >= 0 && frame >= _scheduledAt) {
          if (p.y > 45 && p.y < 55.8 && v.y > 0) {
            final hold = 7 + _reactionRandom.nextInt(5);
            if (_scheduledSide <= 0) _leftUntil = frame + hold;
            if (_scheduledSide >= 0) _rightUntil = frame + hold;
            _readyAt = frame + hold + 7;
          }
          _scheduledAt = -1;
        }
        if (frame >= _readyAt && _scheduledAt < 0 && v.y > 1 && p.x < 24) {
          final reaction = 2 + _reactionRandom.nextInt(4);
          final triggerHeight = policy == BalancePolicy.earlyReactive
              ? 46.5
              : 47.5;
          var trigger = p.y > triggerHeight && p.y < 54;
          var projectedX = p.x;
          if (policy == BalancePolicy.predictive && p.y > 40 && p.y < 51) {
            final time = (-v.y + math.sqrt(v.y * v.y + 72 * (51 - p.y))) / 36;
            projectedX = p.x + v.x * time;
            trigger =
                time <= 0.12 + reaction / 60 &&
                projectedX > 5 &&
                projectedX < 23;
          }
          if (trigger) {
            _scheduledAt = frame + reaction;
            _scheduledSide = projectedX > 12.5 && projectedX < 15.5
                ? 0
                : projectedX < 14
                ? -1
                : 1;
          }
        }
        _setFlippers(game, frame < _leftUntil, frame < _rightUntil);
    }
  }

  void _setFlippers(MonPinballGame game, bool left, bool right) {
    if (left && !_left) flipperPresses++;
    if (right && !_right) flipperPresses++;
    _left = left;
    _right = right;
    game.setLeftFlipper(left);
    game.setRightFlipper(right);
  }
}

class BalanceResult {
  BalanceResult(this.data);
  final Map<String, dynamic> data;
  int get launches => data['launches'] as int;
  int get flipperPresses => data['flipperPresses'] as int;
  int get nudges => data['nudges'] as int;
  int get score => data['score'] as int;
  int get livesLost => data['livesLost'] as int;
  double get seconds => data['seconds'] as double;
  String get outcome => data['outcome'] as String;
  Map<String, dynamic> toJson() => data;
}

Future<MonPinballGame> loadBalanceGame(
  WidgetTester tester,
  RunConfiguration configuration,
) async {
  await preparePinballTestSurface(tester);
  final progress = PinballProgress.memory();
  for (var stage = 0; stage < configuration.stageIndex; stage++) {
    await progress.recordStageClear(
      stageIndex: stage,
      difficulty: configuration.difficulty,
      stars: 1,
      score: 0,
    );
  }
  final game = MonPinballGame(configuration: configuration, progress: progress);
  currentPinballGame = game;
  await loadPinballGameArt(tester, game);
  await tester.pumpWidget(MonPinballApp(gameFactory: () => game));
  await tester.pump();
  await tester.runAsync(() => game.loaded);
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  game.pauseEngine();
  // Keep the production gravity/damping. Other test loaders deliberately
  // remove gravity, so they must not be reused for balance evidence.
  expect(game.world.gravity.x, 0);
  expect(game.world.gravity.y, 36);
  addTearDown(() => disposePinballScenario(tester));
  return game;
}

Future<BalanceResult> runBalanceEpisode(
  MonPinballGame game, {
  required BalancePolicy policy,
  required int seed,
  double maxSeconds = 180,
  double? experimentalExposureSeconds,
  Future<void> Function()? yieldFrame,
}) async {
  const dt = 1 / 60;
  // Settle old flipper strokes/contact cooldowns, then reset authored cycles.
  // No ball transform, score, shield, health, gravity or damping is injected.
  game.restartGame();
  for (var i = 0; i < 30; i++) {
    game.stepEngine();
  }
  game.restartGame();
  final config = game.configuration!;
  if (experimentalExposureSeconds != null) {
    // Explicit pre-run rule experiment, never a mid-run shield opening.
    final world = game.currentWorld;
    game.boss.configure(
      pattern: game.boss.pattern,
      maxHealth: world.bossHealth,
      shieldHits: config.difficulty.shieldHits + world.shieldBonus,
      exposureSeconds: experimentalExposureSeconds,
      attackInterval: config.difficulty.attackInterval * world.attackScale,
    );
  }
  final ball = game.world.children.whereType<PinballBall>().single;
  final player = BalancePlayer(policy, seed);
  final scoreSources = <String, int>{};
  var previousHud = game.hud.value;
  void observeScore() {
    final next = game.hud.value;
    var delta = next.score - previousHud.score;
    if (delta > 0) {
      if (next.combo > previousHud.combo && next.combo % 10 == 0) {
        final bonus = math.min(10000, delta);
        scoreSources.update(
          'comboBonus',
          (v) => v + bonus,
          ifAbsent: () => bonus,
        );
        delta -= bonus;
      }
      if (delta > 0) {
        // Every tenth hit replaces its label with a combo announcement. Keep
        // that base hit explicitly unlabelled rather than guessing a source.
        final kind = next.status.contains('콤보!')
            ? 'unlabelledComboHit'
            : next.status.replaceFirst(RegExp(r'^\+\d+\s*'), '');
        scoreSources.update(kind, (v) => v + delta, ifAbsent: () => delta);
      }
    }
    previousHud = next;
  }

  game.hud.addListener(observeScore);
  final firstHits = <String, double>{};
  final losses = <Map<String, dynamic>>[];
  final exposures = <Map<String, dynamic>>[];
  final recent = Queue<Map<String, dynamic>>();
  final followups = Queue<Map<String, dynamic>>();
  Map<String, dynamic>? exposure;
  Map<String, dynamic>? lastApproach;
  var frame = 0;
  var outcome = 'timeout';
  var activeFrames = 0;
  var exposedFrames = 0;
  var exposedUpperFrames = 0;
  var upperFrames = 0;
  var upperEntries = 0;
  var returnUpperEntries = 0;
  var lastLaunchFrame = 0;
  var healthRemoved = 0;
  var damageHits = 0;
  var shieldPeak = 0;
  var peakProgress = 0.0;
  var saves = 0;
  var rearms = 0;
  var stillFrames = 0;
  var gateArmedAt = -1.0;
  final frameLimit = (maxSeconds * 60).round();
  try {
    for (; frame < frameLimit; frame++) {
      if (game.stageCleared || game.hud.value.gameOver) break;
      final launchCount = player.launches;
      player.updateControls(game, ball, frame);
      if (player.launches != launchCount) lastLaunchFrame = frame;
      final before = ball.position.clone();
      final velocity = ball.body.linearVelocity.clone();
      final lives = game.hud.value.lives;
      final saveTime = game.ballSaveRemaining;
      final health = game.boss.health;
      final wasExposed = game.boss.shieldState == BossShieldState.exposed;
      if (ball.body.bodyType == BodyType.dynamic) activeFrames++;
      if (frame % 6 == 0) {
        recent.add({
          't': frame * dt,
          'x': before.x,
          'y': before.y,
          'vx': velocity.x,
          'vy': velocity.y,
          'left': game.isLeftFlipperPressed,
          'right': game.isRightFlipperPressed,
        });
        if (recent.length > 20) recent.removeFirst();
      }
      game.stepEngine();
      final elapsed = (frame + 1) * dt;
      if (ball.body.bodyType == BodyType.dynamic && ball.position.y < 16) {
        upperFrames++;
        if (before.y >= 16) {
          upperEntries++;
          if (frame - lastLaunchFrame > 5 * 60) returnUpperEntries++;
        }
      }
      for (final item in followups) {
        item['minYNext8Seconds'] = math.min(
          item['minYNext8Seconds'] as double,
          ball.position.y,
        );
        item['followupSeconds'] = elapsed - (item['openedAt'] as double);
      }
      while (followups.isNotEmpty &&
          elapsed - (followups.first['openedAt'] as double) >= 8) {
        followups.removeFirst();
      }
      if (before.y < 50 && ball.position.y >= 50 && velocity.y > 0) {
        lastApproach = {
          't': elapsed,
          'x': before.x,
          'vx': velocity.x,
          'vy': velocity.y,
          'left': game.isLeftFlipperPressed,
          'right': game.isRightFlipperPressed,
        };
      }
      final atLauncher =
          ball.body.bodyType == BodyType.static &&
          ball.position.distanceTo(game.launchPosition) < 0.05;
      if (game.hud.value.lives < lives ||
          (atLauncher &&
              before.y > 50 &&
              saveTime > 0 &&
              game.ballSaveRemaining == 0)) {
        final saved = game.hud.value.lives == lives;
        if (saved) saves++;
        losses.add({
          't': elapsed,
          'x': before.x,
          'y': before.y,
          'saved': saved,
          'approach': lastApproach,
          'trace': recent.toList(growable: false),
        });
        lastApproach = null;
        for (final item in followups) {
          item['followupEndedByLoss'] = true;
        }
        followups.clear();
      } else if (atLauncher && before.y > 40 && velocity.length2 > 0) {
        rearms++;
      }
      final nowExposed = game.boss.shieldState == BossShieldState.exposed;
      if (!wasExposed && nowExposed) {
        exposure = {
          'openedAt': elapsed,
          'x': before.x,
          'y': before.y,
          'damage': 0,
          'firstDamageAt': null,
          'minYNext8Seconds': ball.position.y,
          'followupSeconds': 0.0,
        };
        exposures.add(exposure);
        followups.add(exposure);
      }
      if (health > game.boss.health) {
        final damage = health - game.boss.health;
        healthRemoved += damage;
        damageHits++;
        if (exposure != null) {
          exposure['damage'] = (exposure['damage'] as int) + damage;
          exposure['firstDamageAt'] ??= elapsed;
        }
      }
      if (nowExposed) {
        exposedFrames++;
        if (ball.position.y < 16) exposedUpperFrames++;
      } else if (wasExposed) {
        exposure?['closedAt'] = elapsed;
        exposure = null;
      }
      shieldPeak = math.max(shieldPeak, game.boss.shieldCharge);
      peakProgress = math.max(peakProgress, game.missionProgress);
      if (game.gateArmed && gateArmedAt < 0) gateArmedAt = elapsed;
      for (final id in const [
        'jewel-left',
        'jewel-right',
        'jewel-center',
        'target-0',
        'target-1',
        'target-2',
        'target-3',
      ]) {
        if (!firstHits.containsKey(id) && game.isMissionHitLit(id)) {
          firstHits[id] = elapsed;
        }
      }
      stillFrames =
          ball.body.bodyType == BodyType.dynamic &&
              ball.body.linearVelocity.length < 0.05
          ? stillFrames + 1
          : 0;
      if (stillFrames >= 300) {
        outcome = 'stuck';
        frame++;
        break;
      }
      if (yieldFrame != null && frame % 120 == 119) await yieldFrame();
    }
    if (game.stageCleared) outcome = 'cleared';
    if (game.hud.value.gameOver) outcome = 'gameOver';
    return BalanceResult({
      'world': game.currentWorld.name,
      'stage': config.stageIndex,
      'mode': config.mode.name,
      'difficulty': config.difficulty.name,
      'policy': policy.name,
      'seed': seed,
      'limitSeconds': maxSeconds,
      'experimentalExposureSeconds': experimentalExposureSeconds,
      'target': config.stage.target,
      'outcome': outcome,
      'seconds': frame * dt,
      'activeSeconds': activeFrames * dt,
      'launches': player.launches,
      'launchCharges': player.launchCharges,
      'flipperPresses': player.flipperPresses,
      'nudges': player.nudges,
      'score': game.hud.value.score,
      'bestCombo': game.bestCombo,
      'livesLost': config.difficulty.balls - game.hud.value.lives,
      'saves': saves,
      'rearms': rearms,
      'losses': losses,
      'peakProgress': peakProgress,
      'firstMissionHits': firstHits,
      'gateArmedAt': gateArmedAt < 0 ? null : gateArmedAt,
      'bossDamage': healthRemoved,
      'bossDamageHits': damageHits,
      'shieldPeak': shieldPeak,
      'exposures': exposures,
      'exposedSeconds': exposedFrames * dt,
      'exposedUpperSeconds': exposedUpperFrames * dt,
      'upperSeconds': upperFrames * dt,
      'upperEntries': upperEntries,
      'returnUpperEntries': returnUpperEntries,
      'scoreSources': scoreSources,
    });
  } finally {
    game.hud.removeListener(observeScore);
    game.cancelAllInput();
  }
}
