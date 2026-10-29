// Explicit benchmark: flutter test --no-pub test/balance_playthrough.dart
// Device: flutter run --debug -d DEVICE -t test/balance_playthrough.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/pinball_progress.dart';

import 'support/balance_simulation.dart';
import 'support/pinball_test_harness.dart';

Future<void> main() async {
  await preparePinballTestEnvironment();
  const runs = int.fromEnvironment('BALANCE_RUNS', defaultValue: 8);
  const seconds = int.fromEnvironment('BALANCE_SECONDS', defaultValue: 180);
  const exposureOverride = int.fromEnvironment('BALANCE_EXPOSURE_MS');
  const targetOverride = int.fromEnvironment('BALANCE_TARGET');
  const modeText = String.fromEnvironment(
    'BALANCE_MODE',
    defaultValue: 'stage',
  );
  const label = String.fromEnvironment(
    'BALANCE_LABEL',
    defaultValue: 'baseline',
  );
  const stageText = String.fromEnvironment(
    'BALANCE_STAGES',
    defaultValue: '0,1,2,3,4,5,6,7,8',
  );
  const difficultyText = String.fromEnvironment(
    'BALANCE_DIFFICULTIES',
    defaultValue: 'normal',
  );
  const policyText = String.fromEnvironment(
    'BALANCE_POLICIES',
    defaultValue: 'launchOnly,periodic,reactive,predictive',
  );
  final policies = policyText
      .split(',')
      .map((name) => BalancePolicy.values.byName(name))
      .toList();
  final stages = stageText.split(',').map(int.parse).toList();
  final difficulties = difficultyText
      .split(',')
      .map((name) => PinballDifficulty.values.byName(name))
      .toList();
  final results = <Map<String, dynamic>>[];
  final live = configurePinballTestBinding() is LiveTestWidgetsFlutterBinding;
  for (final difficulty in difficulties) {
    for (final stage in stages) {
      testWidgets('${difficulty.name} stage $stage balance trials', (
        tester,
      ) async {
        final game = await loadBalanceGame(
          tester,
          BalanceConfiguration(
            stageIndex: stage,
            difficulty: difficulty,
            mode: PinballMode.values.byName(modeText),
            targetOverride: targetOverride == 0 ? null : targetOverride,
          ),
        );
        for (final policy in policies) {
          for (var trial = 0; trial < runs; trial++) {
            final result = await runBalanceEpisode(
              game,
              policy: policy,
              seed: 1009 + trial * 7919,
              maxSeconds: seconds.toDouble(),
              experimentalExposureSeconds: exposureOverride == 0
                  ? null
                  : exposureOverride / 1000,
              yieldFrame: live ? () => tester.pump() : null,
            );
            results.add(result.toJson());
            // ignore: avoid_print
            print(
              'BALANCE ${jsonEncode({...result.toJson()}..remove('losses'))}',
            );
          }
        }
      }, timeout: const Timeout(Duration(minutes: 15)));
    }
  }
  tearDownAll(() async {
    final report = {
      'label': label,
      'liveDevice': live,
      'runsPerCell': runs,
      'secondsPerRun': seconds,
      'results': results,
    };
    if (!live) {
      final file = File('build/qa/balance/$label.json');
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(report),
      );
    }
    // ignore: avoid_print
    print(
      'BALANCE_SUMMARY ${jsonEncode({'label': label, 'liveDevice': live, 'episodes': results.length, 'cleared': results.where((r) => r['outcome'] == 'cleared').length})}',
    );
  });
}

/// Test-only rule variants, fixed before any measured player input.
class BalanceConfiguration extends RunConfiguration {
  BalanceConfiguration({
    required super.stageIndex,
    required super.difficulty,
    required super.mode,
    this.targetOverride,
  }) : super(world: pinballStages[stageIndex].world);
  final int? targetOverride;

  @override
  StageDefinition get stage {
    final original = super.stage;
    if (targetOverride == null) return original;
    return StageDefinition(
      world: original.world,
      number: original.number,
      title: original.title,
      goal: original.goal,
      target: targetOverride!,
      hint: original.hint,
    );
  }
}
