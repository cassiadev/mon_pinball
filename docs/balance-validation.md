# Balance validation

2026-10-29. Repeated diagnostic players use the production launcher and flippers,
gravity and collisions. Episodes never move the ball or inject score, shield or
damage. Progress is memory-only; stage unlocks are prepared before each scenario.
The measured time is simulated game time at 60 frames per second. These players
are reproducible diagnostics and are not calibrated human skill models.

## Reproduce

```sh
flutter test --no-pub --dart-define=BALANCE_LABEL=baseline-normal test/balance_playthrough.dart
```

Defaults: nine NORMAL stages, eight seeds, four policies, a 180-second episode
cap (288 episodes). Policies are launch-only, periodic simultaneous pulses,
reactive pulses and predicted-intercept pulses. Seeded launch schedules are
independent of policy. Results include censored timeouts, score labels, loss
traces, mission hits and naturally occurring boss exposures. Every tenth hit's
label is replaced by the combo announcement; its base score is recorded as
unlabelled instead of attributing a guessed source.

Parameters: `BALANCE_RUNS`, `BALANCE_SECONDS`, `BALANCE_STAGES`,
`BALANCE_DIFFICULTIES`, `BALANCE_POLICIES`, `BALANCE_MODE`. Explicit pre-run
rule experiments use `BALANCE_TARGET` or `BALANCE_EXPOSURE_MS`; their values are
recorded in each result and do not represent the production rules.

Local raw results are saved under `build/qa/balance/<label>.json`.

## Baseline and experiments

Base production commit: `9daa248`. All 288 clean NORMAL baseline episodes ran;
the nine benchmark cases passed. A preliminary baseline artifact marked
`preflight-invalid` is excluded because later-stage memory unlocks were initially
missing and clear-record callbacks raised errors. The loader was fixed with a
failing-then-passing regression before the clean baseline was rerun.

| Scenario | Launch only | Three control policies | Observed implication |
| --- | --- | --- | --- |
| Neon 12-combo stage | 8/8 clear, median 4.0s | 24/24 clear, medians about 4.0s | Completes during automatic launch rally |
| Neon experimental 30-combo stage | 8/8 clear, median 15.9s | 24/24 clear | Adds time but little survival demand |
| Neon experimental 60-combo stage | 4/8 clear | 23/24 clear, medians 22–34s | Creates a stronger control/survival distinction |
| Garden boss | 0/8 clear | 5/24 clear | Intro boss is harder than the neon boss under these policies |
| Neon boss | 3/8 clear | 18/24 clear | Existing accelerator route supports upper-field return |
| Abyss boss | 0/8 clear | 1/24 clear | Low return/damage opportunities warrant route investigation |

Increasing exposure to seven seconds alone did not help: same-policy garden
clears changed from 5/32 to 4/32 and abyss from 1/32 to 0/32. For 127 fully
observed lower-field abyss openings, only 23 reached `y<16` within eight seconds;
60 did not reach `y<30`. This supports investigating the route before increasing
the timer or reducing health. An earlier-reacting control model did not remove
the garden/abyss gap.

The initial garden score stage remained an intentionally forgiving introduction:
all launch-only runs cleared, with control policies finishing sooner and often
using fewer balls. No single-device unlimited scoring loop was confirmed in the
sample. Product tuning and final device evidence will be added after comparison.
