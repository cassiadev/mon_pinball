import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart' show BodyType;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/main.dart';
import 'package:mon_pinball/journey_screen.dart';
import 'package:mon_pinball/pinball_progress.dart';
import 'package:mon_pinball/pinball_game.dart';

import 'support/pinball_test_harness.dart';

void main() {
  setUpAll(loadPinballTestFont);

  testWidgets('opens the journey menu before mounting a game', (tester) async {
    await tester.pumpWidget(const MonPinballApp());
    expect(find.byKey(const ValueKey('journey-home')), findsOneWidget);
    expect(find.byKey(const ValueKey('pinball-input-surface')), findsNothing);
  });

  testWidgets('locked selections preserve the playable first stage', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: JourneyHome(progress: PinballProgress.memory())),
    );
    final lockedWorld = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('world-neon')),
    );
    expect(lockedWorld.onSelected, isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('stage-1')));
    await tester.tap(find.byKey(const ValueKey('stage-1')));
    await tester.pump();
    expect(find.text('1-1 스테이지 시작'), findsOneWidget);
  });

  testWidgets('mode and difficulty select the corresponding local records', (
    tester,
  ) async {
    final progress = PinballProgress.memory();
    await progress.recordArcade(
      world: PinballWorld.garden,
      difficulty: PinballDifficulty.easy,
      score: 123450,
      combo: 8,
    );
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: JourneyHome(progress: progress)));
    await tester.tap(find.byKey(const ValueKey('mode-arcade')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('difficulty-easy')));
    await tester.tap(find.byKey(const ValueKey('difficulty-easy')));
    await tester.pump();
    await tester.ensureVisible(find.textContaining('123,450점'));
    expect(find.textContaining('최고 8 콤보'), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-0')), findsNothing);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('journey-difficulty-summary')),
          )
          .data,
      contains('공 5개'),
    );
  });

  testWidgets('home remains scrollable with narrow screens and large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(home: JourneyHome(progress: PinballProgress.memory())),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('stage-2')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('journey-start')), findsOneWidget);
  });

  testWidgets('later worlds show their stronger shield and exposure settings', (
    tester,
  ) async {
    final progress = PinballProgress.memory();
    for (var stage = 0; stage < 6; stage++) {
      await progress.recordStageClear(
        stageIndex: stage,
        difficulty: PinballDifficulty.normal,
        stars: 1,
        score: 100000,
      );
    }
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: JourneyHome(progress: progress)));
    await tester.ensureVisible(find.byKey(const ValueKey('world-neon')));
    await tester.tap(find.byKey(const ValueKey('world-neon')));
    await tester.pump();
    Text findSummary() => tester.widget<Text>(
      find.byKey(const ValueKey('journey-difficulty-summary')),
    );
    expect(findSummary().data, contains('방패 4회'));
    expect(findSummary().data, contains('약점 노출 4.3초'));
    await tester.ensureVisible(find.byKey(const ValueKey('world-abyss')));
    await tester.tap(find.byKey(const ValueKey('world-abyss')));
    await tester.pump();
    expect(findSummary().data, contains('방패 4회'));
    expect(findSummary().data, contains('약점 노출 3.6초'));
  });

  testWidgets(
    'pause and resume preserve the active run before returning home',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: JourneyHome(progress: PinballProgress.memory())),
      );
      await tester.tap(find.byKey(const ValueKey('journey-start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final game = tester
          .widget<GameWidget<MonPinballGame>>(
            find.byType(GameWidget<MonPinballGame>),
          )
          .game!;
      await tester.runAsync(() => game.loaded);
      await tester.pump(const Duration(milliseconds: 16));
      game.addScore(50, Vector2(14, 22), Colors.amber, '기록 유지');
      final originalSnapshot = game.hud.value;

      await tester.binding.setSurfaceSize(const Size(320, 568));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('pinball-input-surface')))
            .height,
        greaterThanOrEqualTo(200),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(game.paused, isTrue);
      expect(find.text('계속 플레이'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(game.paused, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump();
      expect(game.hud.value.score, originalSnapshot.score);
      await tester.tap(find.text('계속 플레이'));
      await tester.pump();
      expect(game.paused, isFalse);
      expect(game.hud.value.score, originalSnapshot.score);
      expect(game.hud.value.lives, originalSnapshot.lives);

      await tester.tap(find.byTooltip('일시정지'));
      await tester.pump();
      await tester.ensureVisible(find.text('여정으로 돌아가기'));
      await tester.tap(find.text('여정으로 돌아가기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('journey-home')), findsOneWidget);
      expect(find.byKey(const ValueKey('pinball-input-surface')), findsNothing);
    },
  );

  testWidgets('cancelled launcher gestures stay cancelled across pause', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: JourneyHome(progress: PinballProgress.memory())),
    );
    await tester.tap(find.byKey(const ValueKey('journey-start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final game = tester
        .widget<GameWidget<MonPinballGame>>(
          find.byType(GameWidget<MonPinballGame>),
        )
        .game!;
    await tester.runAsync(() => game.loaded);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final ball = game.world.children.whereType<PinballBall>().single;
    for (final resumeBeforeRelease in [false, true]) {
      final table = tester.getRect(
        find.byKey(const ValueKey('pinball-input-surface')),
      );
      final gesture = await tester.startGesture(
        table.topLeft + Offset(table.width * 0.88, table.height * 0.72),
      );
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(game.hud.value.launchCharge, greaterThan(0));
      await tester.tap(find.byTooltip('일시정지'));
      await tester.pump();
      if (resumeBeforeRelease) {
        await tester.tap(find.text('계속 플레이'));
        await tester.pump();
      }
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump();
      expect(game.hud.value.launchCharge, 0);
      await gesture.up();
      await tester.pump();
      expect(ball.body.bodyType, BodyType.static);
      if (!resumeBeforeRelease) {
        await tester.tap(find.text('계속 플레이'));
        await tester.pump();
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'stage result advances the mounted game and unlocks its next card',
    (tester) async {
      final progress = PinballProgress.memory();
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: JourneyHome(progress: progress)),
      );
      await tester.tap(find.byKey(const ValueKey('journey-start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final game = tester
          .widget<GameWidget<MonPinballGame>>(
            find.byType(GameWidget<MonPinballGame>),
          )
          .game!;
      await tester.runAsync(() => game.loaded);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      game.addScore(5000, Vector2(14, 22), Colors.amber, '목표 달성');
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump();
      expect(game.stageCleared, isTrue);
      expect(find.text('스테이지 클리어!'), findsOneWidget);
      expect(find.textContaining('스테이지 기록에 반영했습니다'), findsOneWidget);
      await tester.tap(find.text('다음 스테이지'));
      await tester.pump();
      expect(game.configuration!.stageIndex, 1);
      expect(game.stageCleared, isFalse);
      expect(game.hud.value.score, 0);
      expect(progress.findStageStars(0, PinballDifficulty.normal), 3);
      expect(
        tester
            .widget<GameWidget<MonPinballGame>>(
              find.byType(GameWidget<MonPinballGame>),
            )
            .game,
        same(game),
      );
      await tester.tap(find.byTooltip('일시정지'));
      await tester.pump();
      await tester.tap(find.text('여정으로 돌아가기'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<InkWell>(find.byKey(const ValueKey('stage-1'))).onTap,
        isNotNull,
      );
    },
  );

  for (final (mode, savedScore, recordClaim) in [
    (PinballMode.stage, 0, findsNothing),
    (PinballMode.arcade, 1000, findsOneWidget),
  ]) {
    testWidgets('${mode.name} game over claims only a record it saved', (
      tester,
    ) async {
      final progress = PinballProgress.memory();
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: JourneyPlayScreen(
            configuration: RunConfiguration(mode: mode),
            progress: progress,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final game = tester
          .widget<GameWidget<MonPinballGame>>(
            find.byType(GameWidget<MonPinballGame>),
          )
          .game!;
      await tester.runAsync(() => game.loaded);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      game.addScore(50, Vector2(14, 22), Colors.amber, '기록 확인');
      final ball = game.world.children.whereType<PinballBall>().single;
      // Launch ball saves return some drained balls before the run ends.
      for (var drain = 0; drain < 12 && !game.hud.value.gameOver; drain++) {
        game.releaseLauncher();
        ball.body.setTransform(Vector2(14, 62), 0);
        ball.body.linearVelocity = Vector2.zero();
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump();
      expect(game.hud.value.gameOver, isTrue);
      expect(find.text('멋진 한 판이었어요'), findsOneWidget);
      expect(find.textContaining('기록에 반영했습니다'), recordClaim);
      expect(
        mode == PinballMode.stage
            ? progress.findBestStageScore(0, PinballDifficulty.normal)
            : progress.findBestArcadeScore(
                PinballWorld.garden,
                PinballDifficulty.normal,
              ),
        savedScore,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
