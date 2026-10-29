import 'package:flutter_test/flutter_test.dart';
import 'package:mon_pinball/pinball_progress.dart';

import 'support/balance_simulation.dart';
import 'support/pinball_test_harness.dart';

void main() {
  configurePinballTestBinding();

  testWidgets('same seed repeats controls and measured natural play', (
    tester,
  ) async {
    final game = await loadBalanceGame(tester, const RunConfiguration());
    final first = await runBalanceEpisode(
      game,
      policy: BalancePolicy.reactive,
      seed: 17,
      maxSeconds: 15,
    );
    final repeated = await runBalanceEpisode(
      game,
      policy: BalancePolicy.reactive,
      seed: 17,
      maxSeconds: 15,
    );
    expect(repeated.toJson(), first.toJson());
    expect(game.world.gravity.y, 36);
    expect(first.launches, greaterThan(0));
  });

  testWidgets('launch-only baseline uses no flipper or nudge assistance', (
    tester,
  ) async {
    final game = await loadBalanceGame(
      tester,
      const RunConfiguration(stageIndex: 3),
    );
    final result = await runBalanceEpisode(
      game,
      policy: BalancePolicy.launchOnly,
      seed: 31,
      maxSeconds: 15,
    );
    expect(result.launches, greaterThan(0));
    expect(result.flipperPresses, 0);
    expect(result.nudges, 0);
    expect(result.score, greaterThan(0));
    expect(game.world.gravity.y, 36);
  });

  testWidgets('time limit is reported as censored rather than failure', (
    tester,
  ) async {
    final game = await loadBalanceGame(tester, const RunConfiguration());
    final result = await runBalanceEpisode(
      game,
      policy: BalancePolicy.launchOnly,
      seed: 1,
      maxSeconds: 0.1,
    );
    expect(result.outcome, 'timeout');
    expect(result.launches, 0);
    expect(result.seconds, closeTo(0.1, 0.001));
    expect(result.livesLost, 0);
  });

  testWidgets('later-stage measured clears use unlocked isolated progress', (
    tester,
  ) async {
    final game = await loadBalanceGame(
      tester,
      const RunConfiguration(stageIndex: 4),
    );
    final result = await runBalanceEpisode(
      game,
      policy: BalancePolicy.launchOnly,
      seed: 1009,
      maxSeconds: 15,
    );
    await tester.pump();
    expect(result.outcome, 'cleared');
    expect(tester.takeException(), isNull);
  });
}
