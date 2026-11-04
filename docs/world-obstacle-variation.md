# Fixed world obstacle variation

후속 [밸런스 검증](balance-validation.md)에서 반복 플레이를 바탕으로 수련 발사,
심해 달 범퍼, 네온 콤보 목표와 쉬움 심해 체력을 조정했습니다. 아래는 추가 당시 기록입니다.

2026-10-29. Each world now has two mechanically different devices in an authored
layout. The first stage introduces the primary device, the second stage and boss
combine both types, and arcade enables both immediately.

| World | Primary device | Secondary device |
| --- | --- | --- |
| Moonlit garden | Two yielding petal flaps, with actual bounded hinges and spring return | A lotus scoop briefly catches a descending ball and ejects it upward diagonally |
| Neon city | The existing rotating physical electrode | A directional accelerator rail on the right side |
| Abyss ruins | The existing sliding stone sluices | A visible horizontal current that reverses every three seconds |

## Behavior

- Configured garden games replace the old fixed spinner bars with physical leaves.
  Each leaf has a dynamic rectangular body, a static anchor and a limited revolute
  joint. Its picture rotates with its collision shape. The weak restoring motor
  allows the ball to push the leaf aside.
- The lotus is a non-solid catch region centered at board position `(14, 28.8)`.
  It catches descending entries for at most 0.3 game seconds, then ejects diagonally
  upward and awards 3,000 points under the existing configured-game score scale.
  A one-second cooldown prevents immediate recapture. Launcher input cannot move
  or launch a ball while the lotus holds it. Pausing freezes the catch timer.
- The neon rail points from `(21.5, 36.2)` toward `(19.1, 32.6)`. Forward entries
  receive one boost and 2,000 points. Reverse entries do not boost. Entry detection
  checks the swept ball path, repeated frames inside do not repeatedly score, and
  boosted speed is capped at 60 board units per second.
- The abyss current occupies `x=10..18, y=26.5..31.5`. It accelerates horizontal
  velocity toward a bounded flow and leaves vertical velocity unchanged. Arrows
  show direction; their color changes in the final 0.6 seconds before reversal,
  and a small bar shows time remaining. The area has no solid collision wall.
- Restart and world changes reset device layout/cycles. Any return to the launcher,
  including ball save and stage completion, cancels lotus ownership and rail entry
  history. Removing a leaf also removes its extra anchor and joint.
- Stage hints, world introductions, the wide-screen guide and the pause menu explain
  active devices. Pause actions precede the guide so large text leaves the resume
  action near the top of the scrollable sheet.
- The shared launcher, outer walls, flippers, target objectives, gravity and saved
  progression remain compatible. The null-configuration legacy game keeps its
  original spinners and does not mount these new devices.

## Validation executed

The code started from `3afb6ce` on `feature/hybrid-pinball-poc`.

- Before changes: the full existing suite passed 171 tests.
- After changes: the full suite passed 192 tests; static analysis reported no issues.
- Twenty new device scenarios cover stage combinations, actual hinge impact/return,
  lotus capture/ejection, launcher exclusion during capture, pause/ball-save/restart
  safety, anchor cleanup, forward/reverse/fast rail entry, current reversal/escape
  and legacy isolation. All twenty also passed on the physical Galaxy SM-M336K,
  launched through `flutter run`, using controlled ball positions and physics time.
- An additional natural-gravity test samples four approach positions at each of
  the two leaves, checking for a resting ball that remains stuck. It passed on the
  host and is not included in the twenty physical-device scenarios.
- Three production-screen capture scenarios passed and were visually inspected.
  Captures are local artifacts in `build/qa/world-devices-{garden,neon,abyss}.png`.
- The normal Android debug build succeeded using Android Studio's bundled JBR
  (JetBrains Runtime), and the normal application was installed after the controlled
  native tests.
- In the normal app, direct launch and left/right flipper input were exercised in
  all three arcade worlds. Observed states: garden 24,600 points / 3 balls / boss
  health 4,800; neon 119,820 / 2 balls / 7,680; abyss 12,000 / 3 balls / 9,600.
  World selection, pause guidance and return-to-menu were also exercised.
- The normal application's filtered Flutter/AndroidRuntime error log was empty.
  The phone was left in a fresh abyss arcade run: score 0, three balls, shield 0/4,
  boss health 9,600, ball waiting on the launcher.
- The controlled native scenarios establish device behavior, not manual full-stage
  completion. The brief manual runs do not establish long-session balance or every
  mission's natural-play completion rate.

## Repeating checks

```sh
flutter test --no-pub
flutter analyze --no-pub
flutter test --no-pub test/device_world_gallery.dart
flutter run --debug --no-pub -d DEVICE_SERIAL -t test/world_device_variation_test.dart
```

The last command is an explicit test entrypoint on a connected physical device.
It does not use persistent progress. Afterwards build and install `lib/main.dart`
as the normal application again. `flutter test -d DEVICE_SERIAL` alone does not
prove these ordinary widget tests ran on the device.
