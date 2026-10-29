import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PinballMode { stage, arcade }

enum PinballDifficulty {
  easy('EASY', 5, 2, 8, 12, 12),
  normal('NORMAL', 3, 3, 5, 9, 7),
  hard('HARD', 3, 4, 3, 7, 3);

  const PinballDifficulty(
    this.label,
    this.balls,
    this.shieldHits,
    this.exposureSeconds,
    this.attackInterval,
    this.ballSaveSeconds,
  );

  final String label;
  final int balls;
  final int shieldHits;
  final double exposureSeconds;
  final double attackInterval;
  final double ballSaveSeconds;
}

enum PinballWorld {
  garden('달의 정원', '젖혀지는 꽃잎과 수련의 발사로 꽃을 깨우세요', '월식의 수호자 · 츠키비나'),
  neon(
    '네온 도시',
    '회전 전극의 틈을 지나 가속 레일로 질주하세요',
    '네온 감시자',
    bossHealth: 8000,
    shieldBonus: 1,
    exposureScale: 0.85,
    attackScale: 0.8,
  ),
  abyss(
    '심해의 유적',
    '왕복 수문과 방향이 바뀌는 물살 사이로 길을 여세요',
    '심연의 파수꾼',
    bossHealth: 9600,
    shieldBonus: 1,
    exposureScale: 0.72,
    attackScale: 0.7,
  );

  const PinballWorld(
    this.label,
    this.tagline,
    this.bossName, {
    this.bossHealth = 6400,
    this.shieldBonus = 0,
    this.exposureScale = 1,
    this.attackScale = 1,
  });

  final String label;
  final String tagline;
  final String bossName;
  final int bossHealth;
  final int shieldBonus;
  final double exposureScale;
  final double attackScale;
}

enum StageGoal { score, bloom, combo, targets, boss }

class StageDefinition {
  const StageDefinition({
    required this.world,
    required this.number,
    required this.title,
    required this.goal,
    required this.target,
    required this.hint,
  });

  final PinballWorld world;
  final String number;
  final String title;
  final StageGoal goal;
  final int target;
  final String hint;
}

const pinballStages = [
  StageDefinition(
    world: PinballWorld.garden,
    number: '1-1',
    title: '달빛의 입구',
    goal: StageGoal.score,
    target: 100000,
    hint: '공에 밀려 젖혀지는 꽃잎을 지나 범퍼와 타깃으로 100,000점을 모으세요',
  ),
  StageDefinition(
    world: PinballWorld.garden,
    number: '1-2',
    title: '꽃이 피는 밤',
    goal: StageGoal.bloom,
    target: 3,
    hint: '수련은 내려오는 공을 받아 위로 쏩니다. 서로 다른 위쪽 보석 3개를 충전한 뒤 상단 게이트를 통과하세요',
  ),
  StageDefinition(
    world: PinballWorld.garden,
    number: '1-3',
    title: '월식의 수호자',
    goal: StageGoal.boss,
    target: 1,
    hint: '꽃잎과 수련의 발사를 활용하세요. 좌우 보석·하단 타깃으로 방어막을 열고 약점을 노리세요',
  ),
  StageDefinition(
    world: PinballWorld.neon,
    number: '2-1',
    title: '불빛의 거리',
    goal: StageGoal.score,
    target: 150000,
    hint: '회전 전극의 빈틈을 노려 도시의 장치로 150,000점을 모으세요',
  ),
  StageDefinition(
    world: PinballWorld.neon,
    number: '2-2',
    title: '이어지는 전류',
    goal: StageGoal.combo,
    target: 12,
    hint: '오른쪽 가속 레일의 화살표 방향으로 진입하세요. 공을 잃기 전에 12콤보를 이어가세요',
  ),
  StageDefinition(
    world: PinballWorld.neon,
    number: '2-3',
    title: '네온 감시자',
    goal: StageGoal.boss,
    target: 1,
    hint: '회전 전극과 가속 레일을 활용하세요. 좌우 보석·하단 타깃으로 방어막을 열고 약점을 노리세요',
  ),
  StageDefinition(
    world: PinballWorld.abyss,
    number: '3-1',
    title: '가라앉은 빛',
    goal: StageGoal.score,
    target: 200000,
    hint: '왕복 수문의 열린 통로를 골라 심해의 장치로 200,000점을 모으세요',
  ),
  StageDefinition(
    world: PinballWorld.abyss,
    number: '3-2',
    title: '네 개의 봉인',
    goal: StageGoal.targets,
    target: 4,
    hint: '중앙 물살은 3초마다 방향이 바뀝니다. 서로 다른 타깃 4개를 맞힌 뒤 상단 게이트를 통과하세요',
  ),
  StageDefinition(
    world: PinballWorld.abyss,
    number: '3-3',
    title: '심연의 파수꾼',
    goal: StageGoal.boss,
    target: 1,
    hint: '물살의 방향과 수문의 틈을 읽으세요. 좌우 보석·하단 타깃으로 방어막을 열고 약점을 노리세요',
  ),
];

class RunConfiguration {
  const RunConfiguration({
    this.mode = PinballMode.stage,
    this.difficulty = PinballDifficulty.normal,
    this.world = PinballWorld.garden,
    this.stageIndex = 0,
  });

  final PinballMode mode;
  final PinballDifficulty difficulty;
  final PinballWorld world;
  final int stageIndex;

  StageDefinition get stage => pinballStages[stageIndex];
}

class PinballProgress extends ChangeNotifier {
  PinballProgress.memory() : _preferences = null;

  PinballProgress._(this._preferences);

  static const _storageKey = 'pinball_progress_v1';
  static const _saveError = '기록을 기기에 저장하지 못했습니다. 이번 플레이에서는 유지됩니다.';

  static Future<PinballProgress> load() async {
    final SharedPreferences preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      return PinballProgress.memory()
        .._storageError = '저장소를 열지 못했습니다. 이번 플레이의 기록만 유지됩니다.';
    }
    final progress = PinballProgress._(preferences);
    try {
      final source = preferences.getString(_storageKey);
      if (source != null) progress._decodeProgress(source);
    } catch (_) {
      progress._stages.clear();
      progress._arcade.clear();
      progress._storageError = '저장된 기록을 읽지 못했습니다. 새 기록부터 저장합니다.';
    }
    return progress;
  }

  final SharedPreferences? _preferences;
  final _stages = <String, Map<String, int>>{};
  final _arcade = <String, Map<String, int>>{};
  Future<void> _pendingSave = Future.value();
  String? _storageError;

  String? get storageError => _storageError;

  bool isStageUnlocked(int stageIndex) {
    if (stageIndex < 0 || stageIndex >= pinballStages.length) return false;
    for (var index = 0; index < stageIndex; index++) {
      if (!PinballDifficulty.values.any(
        (difficulty) => findStageStars(index, difficulty) > 0,
      )) {
        return false;
      }
    }
    return true;
  }

  bool isWorldUnlocked(PinballWorld world) => isStageUnlocked(
    pinballStages.indexWhere((stage) => stage.world == world),
  );

  int findStageStars(int stageIndex, PinballDifficulty difficulty) =>
      _stages['$stageIndex.${difficulty.name}']?['stars'] ?? 0;

  int findBestStageScore(int stageIndex, PinballDifficulty difficulty) =>
      _stages['$stageIndex.${difficulty.name}']?['score'] ?? 0;

  int findBestArcadeScore(PinballWorld world, PinballDifficulty difficulty) =>
      _arcade['${world.name}.${difficulty.name}']?['score'] ?? 0;

  int findBestArcadeCombo(PinballWorld world, PinballDifficulty difficulty) =>
      _arcade['${world.name}.${difficulty.name}']?['combo'] ?? 0;

  Future<void> recordStageClear({
    required int stageIndex,
    required PinballDifficulty difficulty,
    required int stars,
    required int score,
  }) async {
    if (!isStageUnlocked(stageIndex) || stars < 1 || stars > 3 || score < 0) {
      throw ArgumentError(
        'A clear needs an unlocked stage, 1–3 stars and a nonnegative score.',
      );
    }
    _stages['$stageIndex.${difficulty.name}'] = {
      'stars': math.max(stars, findStageStars(stageIndex, difficulty)),
      'score': math.max(score, findBestStageScore(stageIndex, difficulty)),
    };
    notifyListeners();
    await _save();
  }

  Future<void> recordArcade({
    required PinballWorld world,
    required PinballDifficulty difficulty,
    required int score,
    required int combo,
  }) async {
    if (score < 0 || combo < 0) {
      throw ArgumentError('Arcade records must be nonnegative.');
    }
    _arcade['${world.name}.${difficulty.name}'] = {
      'score': math.max(score, findBestArcadeScore(world, difficulty)),
      'combo': math.max(combo, findBestArcadeCombo(world, difficulty)),
    };
    notifyListeners();
    await _save();
  }

  void _decodeProgress(String source) {
    final data = jsonDecode(source);
    if (data is! Map<String, dynamic> || data['version'] != 1) {
      throw const FormatException('Unknown progress format');
    }
    _stages.addAll(
      _decodeRecords(data['stages'], {
        for (var index = 0; index < pinballStages.length; index++)
          for (final difficulty in PinballDifficulty.values)
            '$index.${difficulty.name}',
      }, 'stars'),
    );
    _arcade.addAll(
      _decodeRecords(data['arcade'], {
        for (final world in PinballWorld.values)
          for (final difficulty in PinballDifficulty.values)
            '${world.name}.${difficulty.name}',
      }, 'combo'),
    );
  }

  Map<String, Map<String, int>> _decodeRecords(
    dynamic data,
    Set<String> allowedKeys,
    String metric,
  ) {
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing records');
    }
    return data.map((key, value) {
      if (!allowedKeys.contains(key) ||
          value is! Map<String, dynamic> ||
          value['score'] is! int ||
          value['score'] < 0 ||
          value[metric] is! int ||
          value[metric] < (metric == 'stars' ? 1 : 0) ||
          (metric == 'stars' && value[metric] > 3)) {
        throw const FormatException('Invalid record');
      }
      return MapEntry(key, {'score': value['score'], metric: value[metric]});
    });
  }

  Future<void> _save() {
    final preferences = _preferences;
    if (preferences == null) return Future.value();
    final source = jsonEncode({
      'version': 1,
      'stages': _stages,
      'arcade': _arcade,
    });
    // Serialize writes so an older snapshot cannot finish after a newer one.
    _pendingSave = _pendingSave.then((_) async {
      try {
        final saved = await preferences.setString(_storageKey, source);
        _setStorageError(saved ? null : _saveError);
      } catch (_) {
        _setStorageError(_saveError);
      }
    });
    return _pendingSave;
  }

  void _setStorageError(String? error) {
    if (_storageError == error) return;
    _storageError = error;
    notifyListeners();
  }
}
