import 'package:flutter/material.dart';

import 'boss_encounter.dart';
import 'main.dart' show PinballScreen;
import 'pinball_game.dart';
import 'pinball_progress.dart';
import 'pinball_style.dart';

Color _selectAccent(PinballWorld world) => switch (world) {
  PinballWorld.garden => const Color(0xFFD0B6F7),
  PinballWorld.neon => const Color(0xFF6DEBE4),
  PinballWorld.abyss => const Color(0xFFA3B5FF),
};

IconData _selectWorldIcon(PinballWorld world) => switch (world) {
  PinballWorld.garden => Icons.nightlight_round,
  PinballWorld.neon => Icons.bolt_rounded,
  PinballWorld.abyss => Icons.waves_rounded,
};

String _formatScore(int score) => score.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (match) => '${match[1]},',
);

/// Campaign selection and records share the same local progress instance.
class JourneyHome extends StatefulWidget {
  const JourneyHome({this.progress, super.key});

  final PinballProgress? progress;

  @override
  State<JourneyHome> createState() => _JourneyHomeState();
}

class _JourneyHomeState extends State<JourneyHome> {
  PinballProgress? _progress;
  PinballMode _mode = PinballMode.stage;
  PinballDifficulty _difficulty = PinballDifficulty.normal;
  PinballWorld _world = PinballWorld.garden;
  int _stageIndex = 0;

  @override
  void initState() {
    super.initState();
    _progress = widget.progress;
    if (_progress == null) _loadProgress();
  }

  Future<void> _loadProgress() async {
    final progress = await PinballProgress.load();
    if (mounted) setState(() => _progress = progress);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return Scaffold(
      key: const ValueKey('journey-home'),
      body: progress == null
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: progress,
              builder: (context, _) => _buildHome(context, progress),
            ),
      bottomNavigationBar: progress == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('journey-start'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          backgroundColor: _selectAccent(_world),
                          foregroundColor: const Color(0xFF15182C),
                        ),
                        onPressed: () => _startRun(progress),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          _mode == PinballMode.stage
                              ? '${pinballStages[_stageIndex].number} 스테이지 시작'
                              : '${_world.label} 아케이드 시작',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHome(BuildContext context, PinballProgress progress) {
    final accent = _selectAccent(_world);
    final stage = pinballStages[_stageIndex];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.13), PinballStyle.background],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'MON PINBALL',
                    style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '달빛을 넘어, 한 판 더.',
                    style: TextStyle(color: PinballStyle.muted, height: 1.6),
                  ),
                  const SizedBox(height: 24),
                  _WorldBanner(world: _world, mode: _mode),
                  const SizedBox(height: 24),
                  const _SectionLabel('플레이 모드'),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      for (final mode in PinballMode.values)
                        ChoiceChip(
                          key: ValueKey('mode-${mode.name}'),
                          selected: _mode == mode,
                          label: Text(
                            mode == PinballMode.stage
                                ? '스테이지 · 여정'
                                : '아케이드 · 기록',
                          ),
                          onSelected: (_) => setState(() => _mode = mode),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _mode == PinballMode.stage
                        ? '목표를 달성해 다음 스테이지와 새로운 세계를 여세요.'
                        : '열린 세계에서 한 판을 오래 이어가세요. 보스를 쓰러뜨리면 다시 등장합니다.',
                    style: const TextStyle(
                      color: PinballStyle.muted,
                      height: 1.6,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel('세 개의 세계'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final world in PinballWorld.values)
                        ChoiceChip(
                          key: ValueKey('world-${world.name}'),
                          avatar: Icon(
                            progress.isWorldUnlocked(world)
                                ? _selectWorldIcon(world)
                                : Icons.lock_outline_rounded,
                            size: 18,
                          ),
                          selected: _world == world,
                          label: Text(world.label),
                          tooltip: progress.isWorldUnlocked(world)
                              ? world.tagline
                              : '앞 세계의 마지막 스테이지를 클리어하면 열립니다.',
                          onSelected: progress.isWorldUnlocked(world)
                              ? (_) => setState(() {
                                  _world = world;
                                  _stageIndex = pinballStages.indexWhere(
                                    (candidate) => candidate.world == world,
                                  );
                                })
                              : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel('난이도'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final difficulty in PinballDifficulty.values)
                        ChoiceChip(
                          key: ValueKey('difficulty-${difficulty.name}'),
                          label: Text(difficulty.label),
                          selected: _difficulty == difficulty,
                          onSelected: (_) =>
                              setState(() => _difficulty = difficulty),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '공 ${_difficulty.balls}개 · 방패 ${_difficulty.shieldHits + _world.shieldBonus}회 · '
                    '약점 노출 ${(_difficulty.exposureSeconds * _world.exposureScale).toStringAsFixed(_world == PinballWorld.garden ? 0 : 1)}초',
                    key: const ValueKey('journey-difficulty-summary'),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: PinballStyle.muted,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (_mode == PinballMode.stage) ...[
                    const _SectionLabel('스테이지 선택'),
                    for (var i = 0; i < pinballStages.length; i++)
                      if (pinballStages[i].world == _world)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _StageCard(
                            index: i,
                            selected: _stageIndex == i,
                            unlocked: progress.isStageUnlocked(i),
                            stars: progress.findStageStars(i, _difficulty),
                            best: progress.findBestStageScore(i, _difficulty),
                            onTap: () => setState(() => _stageIndex = i),
                          ),
                        ),
                    const SizedBox(height: 8),
                    _InfoPanel(
                      icon: Icons.flag_outlined,
                      title: '${stage.number} · ${stage.title}',
                      body: stage.hint,
                      accent: accent,
                    ),
                  ] else
                    _InfoPanel(
                      icon: Icons.emoji_events_outlined,
                      title: '${_difficulty.label} 최고 기록',
                      body:
                          '${_formatScore(progress.findBestArcadeScore(_world, _difficulty))}점'
                          '  ·  최고 ${progress.findBestArcadeCombo(_world, _difficulty)} 콤보\n'
                          '난이도별로 기록됩니다. 공을 모두 잃으면 한 판이 끝납니다.',
                      accent: accent,
                    ),
                  const SizedBox(height: 20),
                  const _InfoPanel(
                    icon: Icons.touch_app_outlined,
                    title: '공 하나로 시작하는 모험',
                    body:
                        '오른쪽 발사대를 아래로 당겼다 놓으세요.\n'
                        '화면 왼쪽과 오른쪽을 누르면 각각 플리퍼가 움직입니다.\n'
                        '좌우 보석·하단 타깃으로 방어막을 열고 약점을 노리세요.\n'
                        '클리어 별: 공 손실 0개 ★★★ · 1개 ★★ · 2개 이상 ★',
                    accent: PinballStyle.gold,
                  ),
                  if (progress.storageError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      progress.storageError!,
                      style: const TextStyle(
                        color: PinballStyle.coral,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startRun(PinballProgress progress) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => JourneyPlayScreen(
          progress: progress,
          configuration: RunConfiguration(
            mode: _mode,
            difficulty: _difficulty,
            world: _world,
            stageIndex: _stageIndex,
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }
}

class _WorldBanner extends StatelessWidget {
  const _WorldBanner({required this.world, required this.mode});

  final PinballWorld world;
  final PinballMode mode;

  @override
  Widget build(BuildContext context) {
    final accent = _selectAccent(world);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.23), const Color(0xFF12192C)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mode == PinballMode.stage
                      ? 'THE JOURNEY / 9 STAGES'
                      : 'ONE MORE RUN',
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  world.label,
                  style: const TextStyle(fontSize: 26, height: 1.3),
                ),
                const SizedBox(height: 8),
                Text(
                  world.tagline,
                  style: const TextStyle(
                    color: PinballStyle.muted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ExcludeSemantics(
            child: Icon(_selectWorldIcon(world), size: 44, color: accent),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      label,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.index,
    required this.selected,
    required this.unlocked,
    required this.stars,
    required this.best,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final bool unlocked;
  final int stars;
  final int best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stage = pinballStages[index];
    final accent = _selectAccent(stage.world);
    return Material(
      color: selected ? accent.withValues(alpha: 0.14) : PinballStyle.panel,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('stage-$index'),
        borderRadius: BorderRadius.circular(12),
        onTap: unlocked ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? accent : PinballStyle.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  !unlocked
                      ? Icons.lock_outline_rounded
                      : selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: unlocked ? accent : PinballStyle.muted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${stage.number}  ${stage.title}',
                      style: TextStyle(
                        height: 1.5,
                        color: unlocked
                            ? PinballStyle.text
                            : PinballStyle.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (unlocked)
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Semantics(
                            label: '별 $stars개',
                            child: ExcludeSemantics(
                              child: Text(
                                '${'★' * stars}${'☆' * (3 - stars)}',
                                style: const TextStyle(
                                  color: PinballStyle.gold,
                                  letterSpacing: 3,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            best == 0
                                ? '첫 기록을 남겨보세요'
                                : '최고 ${_formatScore(best)}점',
                            style: const TextStyle(
                              color: PinballStyle.muted,
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                        ],
                      )
                    else
                      const Text(
                        '이전 스테이지 클리어 후 열림',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.5,
                          color: PinballStyle.muted,
                        ),
                      ),
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

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: PinballStyle.panel.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(icon, color: accent, size: 18),
            Text(title, style: TextStyle(color: accent, height: 1.5)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: const TextStyle(
            fontSize: 12,
            height: 1.8,
            color: PinballStyle.muted,
          ),
        ),
      ],
    ),
  );
}

/// The existing table and touch controls stay mounted through pause and results.
class JourneyPlayScreen extends StatefulWidget {
  const JourneyPlayScreen({
    required this.configuration,
    required this.progress,
    super.key,
  });

  final RunConfiguration configuration;
  final PinballProgress progress;

  @override
  State<JourneyPlayScreen> createState() => _JourneyPlayScreenState();
}

class _JourneyPlayScreenState extends State<JourneyPlayScreen>
    with WidgetsBindingObserver {
  late final _game = MonPinballGame(
    configuration: widget.configuration,
    progress: widget.progress,
  );
  bool _paused = false;
  bool _allowExit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game.pauseEngine();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_paused) _pauseRun();
  }

  void _pauseRun() {
    _game.cancelAllInput();
    _game.pauseEngine();
    if (mounted) setState(() => _paused = true);
  }

  void _resumeRun() {
    setState(() => _paused = false);
    _game.resumeEngine();
  }

  void _retryRun() {
    _game.restartGame();
    _resumeRun();
  }

  void _leaveRun() {
    _game.cancelAllInput();
    _game.pauseEngine();
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowExit,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _pauseRun();
    },
    child: PinballScreen(
      gameFactory: () => _game,
      dashboardBuilder: (game, wide) => _buildDashboard(context, wide),
      overlayBuilder: (context, game) => ValueListenableBuilder(
        valueListenable: game.hud,
        builder: (context, snapshot, _) {
          if (_paused || game.stageCleared || snapshot.gameOver) {
            return _buildRunOverlay(context, snapshot);
          }
          return const SizedBox.shrink();
        },
      ),
    ),
  );

  Widget _buildDashboard(
    BuildContext context,
    bool wide,
  ) => ValueListenableBuilder(
    valueListenable: _game.hud,
    builder: (context, snapshot, _) {
      final configuration = _game.configuration!;
      final arcade = configuration.mode == PinballMode.arcade;
      final world = _game.currentWorld;
      final accent = _selectAccent(world);
      final boss = _game.boss;
      final bossStatus = switch (boss.shieldState) {
        BossShieldState.shielded =>
          '방패 ${boss.shieldCharge}/${boss.requiredShieldHits} · 좌우 보석·하단 타깃을 노리세요',
        BossShieldState.exposed =>
          '약점 노출 ${boss.exposureRemaining.toStringAsFixed(1)}초 · 보스를 노리세요',
        BossShieldState.attacking =>
          boss.sealsLeftLane && boss.sealsRightLane
              ? '양쪽 레인 봉쇄 · 중앙 길을 노리세요'
              : boss.sealsRightLane
              ? '오른쪽 레인 봉쇄 · 왼쪽 경로를 노리세요'
              : boss.sealsLeftLane
              ? '왼쪽 레인 봉쇄 · 오른쪽 경로를 노리세요'
              : boss.warnsLeftLane && boss.warnsRightLane
              ? '촉수 예고 · 중앙 길로 이동하세요'
              : boss.warnsRightLane
              ? '오른쪽 조준 · 반대편을 노리세요'
              : boss.warnsLeftLane
              ? '왼쪽 조준 · 반대편을 노리세요'
              : '공격 예고 · 공을 살려두세요',
        BossShieldState.defeated => '보스 격파!',
      };
      return Padding(
        padding: EdgeInsets.fromLTRB(4, 0, 4, wide ? 8 : 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    arcade
                        ? '${world.label} · 아케이드'
                        : '${configuration.stage.number} ${configuration.stage.title}',
                    style: TextStyle(color: accent, fontSize: 13, height: 1.4),
                  ),
                ),
                IconButton(
                  tooltip: '일시정지',
                  onPressed: _pauseRun,
                  icon: const Icon(Icons.pause_rounded),
                ),
              ],
            ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Semantics(
                  label: '점수 ${snapshot.score}점',
                  child: Text(
                    _formatScore(snapshot.score),
                    style: const TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 29,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
                Text(
                  '● ${snapshot.lives}  ·  ${snapshot.combo} COMBO',
                  style: const TextStyle(
                    color: PinballStyle.gold,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              arcade
                  ? '${configuration.difficulty.label} · 보스 ${_game.arcadeBossesDefeated}회 격파'
                  : _game.missionDescription,
              style: const TextStyle(fontSize: 11, height: 1.5),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: arcade
                  ? snapshot.bossHealth / snapshot.bossMaxHealth
                  : _game.missionProgress,
              color: accent,
              minHeight: 3,
              backgroundColor: PinballStyle.line,
              borderRadius: BorderRadius.circular(3),
              semanticsLabel: arcade ? '보스 남은 체력' : '스테이지 진행',
            ),
            const SizedBox(height: 4),
            Text(
              boss.visible
                  ? '$bossStatus · 체력 ${_formatScore(snapshot.bossHealth)}'
                  : snapshot.status,
              style: TextStyle(
                fontSize: 10,
                height: 1.5,
                color: boss.shieldState == BossShieldState.exposed
                    ? PinballStyle.gold
                    : PinballStyle.muted,
              ),
            ),
            if (_game.ballSaveRemaining > 0)
              Text(
                '볼 세이브 ${_game.ballSaveRemaining.toStringAsFixed(1)}초 · 한 번 자동 복귀',
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.5,
                  color: PinballStyle.cyan,
                ),
              ),
            if (wide) ...[
              const SizedBox(height: 18),
              _InfoPanel(
                icon: Icons.touch_app_outlined,
                title: '플레이 안내',
                body:
                    '발사대를 아래로 당겼다 놓기\n'
                    '왼쪽 / 오른쪽 터치로 플리퍼\n'
                    '키보드: A / D, Space 발사\n'
                    '${configuration.difficulty.label} · 공 ${configuration.difficulty.balls}개',
                accent: accent,
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget _buildRunOverlay(BuildContext context, PinballSnapshot snapshot) {
    final configuration = _game.configuration!;
    final cleared = _game.stageCleared;
    final lastStage = configuration.stageIndex >= pinballStages.length - 1;
    final arcade = configuration.mode == PinballMode.arcade;
    final accent = _selectAccent(_game.currentWorld);
    return BlockSemantics(
      child: ColoredBox(
        color: const Color(0xDF080C1A),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: PinballStyle.panel,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        _paused
                            ? Icons.pause_circle_outline_rounded
                            : cleared
                            ? Icons.auto_awesome_rounded
                            : Icons.nightlight_round,
                        color: accent,
                        size: 40,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _paused
                            ? '잠시 쉬어가기'
                            : cleared
                            ? lastStage
                                  ? '세 세계의 여정 완료!'
                                  : '스테이지 클리어!'
                            : '멋진 한 판이었어요',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 23, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      if (!_paused && cleared)
                        Semantics(
                          label: '별 ${_game.stageStars}개 획득',
                          child: Text(
                            '${'★' * _game.stageStars}${'☆' * (3 - _game.stageStars)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 32,
                              color: PinballStyle.gold,
                              letterSpacing: 6,
                            ),
                          ),
                        ),
                      Text(
                        _paused
                            ? '${configuration.difficulty.label} · 진행 중인 공은 그대로 기다립니다.'
                            : '${_formatScore(snapshot.score)}점 · 최고 ${_game.bestCombo} 콤보\n'
                                  '${arcade ? '아케이드 기록' : '스테이지 기록'}에 반영했습니다.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: PinballStyle.muted,
                          fontSize: 12,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_paused)
                        FilledButton.icon(
                          onPressed: _resumeRun,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('계속 플레이'),
                        )
                      else if (cleared)
                        FilledButton.icon(
                          onPressed: lastStage
                              ? _leaveRun
                              : () {
                                  _game.advanceStage();
                                  setState(() {});
                                  _game.resumeEngine();
                                },
                          icon: Icon(
                            lastStage
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                          label: Text(lastStage ? '여정으로 돌아가기' : '다음 스테이지'),
                        )
                      else
                        FilledButton.icon(
                          onPressed: _retryRun,
                          icon: const Icon(Icons.replay_rounded),
                          label: const Text('다시 도전'),
                        ),
                      if (_paused || cleared) ...[
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _retryRun,
                          child: const Text('처음부터 다시'),
                        ),
                      ],
                      if (_paused || !cleared || !lastStage) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _leaveRun,
                          child: const Text('여정으로 돌아가기'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
