import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/pinball_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';
// The platform fake exercises failed and delayed local writes at the boundary.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('stage clears unlock sequentially across difficulties', () async {
    final progress = PinballProgress.memory();
    expect(progress.isStageUnlocked(0), isTrue);
    expect(progress.isStageUnlocked(1), isFalse);
    expect(progress.isStageUnlocked(-1), isFalse);
    expect(progress.isStageUnlocked(9), isFalse);
    expect(progress.isWorldUnlocked(PinballWorld.garden), isTrue);
    expect(progress.isWorldUnlocked(PinballWorld.neon), isFalse);

    await progress.recordStageClear(
      stageIndex: 0,
      difficulty: PinballDifficulty.easy,
      stars: 3,
      score: 100000,
    );
    await progress.recordStageClear(
      stageIndex: 0,
      difficulty: PinballDifficulty.normal,
      stars: 1,
      score: 120000,
    );
    await progress.recordStageClear(
      stageIndex: 0,
      difficulty: PinballDifficulty.easy,
      stars: 1,
      score: 150000,
    );
    expect(progress.findStageStars(0, PinballDifficulty.easy), 3);
    expect(progress.findBestStageScore(0, PinballDifficulty.easy), 150000);
    expect(progress.findStageStars(0, PinballDifficulty.normal), 1);
    expect(progress.findBestStageScore(0, PinballDifficulty.normal), 120000);
    expect(progress.findStageStars(0, PinballDifficulty.hard), 0);
    expect(progress.isStageUnlocked(1), isTrue);
    expect(progress.isStageUnlocked(2), isFalse);

    for (final index in [1, 2]) {
      await progress.recordStageClear(
        stageIndex: index,
        difficulty: PinballDifficulty.hard,
        stars: 2,
        score: 200000,
      );
    }
    expect(progress.isStageUnlocked(3), isTrue);
    expect(progress.isWorldUnlocked(PinballWorld.neon), isTrue);
    expect(progress.isWorldUnlocked(PinballWorld.abyss), isFalse);
    await expectLater(
      progress.recordStageClear(
        stageIndex: 5,
        difficulty: PinballDifficulty.easy,
        stars: 3,
        score: 1000,
      ),
      throwsArgumentError,
    );
  });

  test(
    'local roundtrip retains stage and arcade records independently',
    () async {
      final progress = await PinballProgress.load();
      await progress.recordStageClear(
        stageIndex: 0,
        difficulty: PinballDifficulty.normal,
        stars: 2,
        score: 123456,
      );
      await progress.recordArcade(
        world: PinballWorld.garden,
        difficulty: PinballDifficulty.normal,
        score: 400000,
        combo: 18,
      );
      await progress.recordArcade(
        world: PinballWorld.garden,
        difficulty: PinballDifficulty.normal,
        score: 300000,
        combo: 24,
      );
      await progress.recordArcade(
        world: PinballWorld.neon,
        difficulty: PinballDifficulty.hard,
        score: 900000,
        combo: 9,
      );

      SharedPreferences.resetStatic();
      final restored = await PinballProgress.load();
      expect(restored.findStageStars(0, PinballDifficulty.normal), 2);
      expect(restored.findBestStageScore(0, PinballDifficulty.normal), 123456);
      expect(restored.isStageUnlocked(1), isTrue);
      expect(restored.findStageStars(0, PinballDifficulty.easy), 0);
      expect(
        restored.findBestArcadeScore(
          PinballWorld.garden,
          PinballDifficulty.normal,
        ),
        400000,
      );
      expect(
        restored.findBestArcadeCombo(
          PinballWorld.garden,
          PinballDifficulty.normal,
        ),
        24,
      );
      expect(
        restored.findBestArcadeScore(PinballWorld.neon, PinballDifficulty.hard),
        900000,
      );
      expect(
        restored.findBestArcadeScore(
          PinballWorld.garden,
          PinballDifficulty.hard,
        ),
        0,
      );
      expect(restored.storageError, isNull);
    },
  );

  test('overlapping saves cannot overwrite a newer record', () async {
    final store = _DelayedFirstWriteStore();
    SharedPreferencesStorePlatform.instance = store;
    SharedPreferences.resetStatic();
    final progress = await PinballProgress.load();
    final first = progress.recordArcade(
      world: PinballWorld.garden,
      difficulty: PinballDifficulty.easy,
      score: 100000,
      combo: 7,
    );
    await store.firstWriteStarted.future;
    final second = progress.recordArcade(
      world: PinballWorld.neon,
      difficulty: PinballDifficulty.hard,
      score: 200000,
      combo: 12,
    );
    store.releaseFirstWrite.complete();
    await Future.wait([first, second]);
    SharedPreferences.resetStatic();
    final restored = await PinballProgress.load();
    expect(
      restored.findBestArcadeScore(PinballWorld.garden, PinballDifficulty.easy),
      100000,
    );
    expect(
      restored.findBestArcadeScore(PinballWorld.neon, PinballDifficulty.hard),
      200000,
    );
  });

  for (final corrupt in [
    '{broken',
    '[]',
    '{"version":1,"stages":{"0.normal":{"stars":-1,"score":10}},"arcade":{}}',
  ]) {
    test(
      'malformed storage leaves a usable run and reports the problem: $corrupt',
      () async {
        SharedPreferences.setMockInitialValues({
          'pinball_progress_v1': corrupt,
        });
        final progress = await PinballProgress.load();
        expect(progress.storageError, isNotNull);
        expect(progress.isStageUnlocked(0), isTrue);
        expect(progress.findStageStars(0, PinballDifficulty.normal), 0);
        await progress.recordStageClear(
          stageIndex: 0,
          difficulty: PinballDifficulty.normal,
          stars: 1,
          score: 100000,
        );
        expect(progress.storageError, isNull);
        SharedPreferences.resetStatic();
        final restored = await PinballProgress.load();
        expect(restored.isStageUnlocked(1), isTrue);
      },
    );
  }

  for (final throwsOnWrite in [false, true]) {
    test(
      'failed ${throwsOnWrite ? 'throwing' : 'false'} write keeps memory and recovers on the next save',
      () async {
        final store = _FailingWriteStore(throwsOnWrite);
        SharedPreferencesStorePlatform.instance = store;
        SharedPreferences.resetStatic();
        final progress = await PinballProgress.load();
        final errors = <String?>[];
        progress.addListener(() => errors.add(progress.storageError));
        await progress.recordStageClear(
          stageIndex: 0,
          difficulty: PinballDifficulty.easy,
          stars: 3,
          score: 100000,
        );
        expect(progress.isStageUnlocked(1), isTrue);
        expect(progress.storageError, isNotNull);
        expect(errors.any((error) => error != null), isTrue);
        store.fail = false;
        await progress.recordArcade(
          world: PinballWorld.garden,
          difficulty: PinballDifficulty.easy,
          score: 200000,
          combo: 14,
        );
        expect(progress.storageError, isNull);
        SharedPreferences.resetStatic();
        final restored = await PinballProgress.load();
        expect(restored.findStageStars(0, PinballDifficulty.easy), 3);
        expect(
          restored.findBestArcadeScore(
            PinballWorld.garden,
            PinballDifficulty.easy,
          ),
          200000,
        );
      },
    );
  }

  test('unavailable storage leaves an observable in-memory run', () async {
    SharedPreferencesStorePlatform.instance = _UnavailableStore();
    SharedPreferences.resetStatic();
    final progress = await PinballProgress.load();
    expect(progress.storageError, isNotNull);
    await progress.recordStageClear(
      stageIndex: 0,
      difficulty: PinballDifficulty.normal,
      stars: 2,
      score: 100000,
    );
    expect(progress.isStageUnlocked(1), isTrue);
    expect(progress.findStageStars(0, PinballDifficulty.normal), 2);
    expect(progress.storageError, isNotNull);
  });
}

class _UnavailableStore extends InMemorySharedPreferencesStore {
  _UnavailableStore() : super.empty();

  @override
  Future<Map<String, Object>> getAll() async {
    throw StateError('Storage unavailable');
  }
}

class _DelayedFirstWriteStore extends InMemorySharedPreferencesStore {
  _DelayedFirstWriteStore() : super.empty();

  final firstWriteStarted = Completer<void>();
  final releaseFirstWrite = Completer<void>();
  bool _firstWrite = true;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (_firstWrite) {
      _firstWrite = false;
      firstWriteStarted.complete();
      await releaseFirstWrite.future;
    }
    return super.setValue(valueType, key, value);
  }
}

class _FailingWriteStore extends InMemorySharedPreferencesStore {
  _FailingWriteStore(this.throwsOnWrite) : super.empty();

  final bool throwsOnWrite;
  bool fail = true;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (fail) {
      if (throwsOnWrite) throw StateError('Storage unavailable');
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}
