# Mon Pinball

Flutter + Flame + Forge2D로 만든 작은 핀볼 게임입니다. Flutter 위젯은 앱 셸과 HUD/입력을 담당하고, Flame/Forge2D는 게임 루프와 물리 월드를 담당합니다.

## Run

```sh
flutter pub get
flutter run
```

## Controls

- Touch left side: left flipper
- Touch right side outside the plunger lane: right flipper
- Drag the right plunger lane downward, then release to shoot
- Keyboard: `A`/left arrow, `D`/right arrow, `Space`/down arrow to launch, `W`/up arrow to nudge, `R` to restart

## Checks

```sh
flutter analyze
flutter test
flutter build apk --debug
```

### Test Suites

Android Studio의 실행 설정에서 `Pinball - All Tests`,
`Pinball - Controls Tests`, `Pinball - Golden Tests`를 선택하면
컴퓨터의 Flutter 테스트 러너로 실행됩니다. 게임을 직접 플레이할 때는
기존 `main.dart` 실행 설정을 사용하세요.

테스트 파일을 기기 대상으로 Run하면 테스트가 실행되는 동안만 화면이
표시됩니다. 실행이 끝난 뒤에는 플레이 가능한 게임 화면이 남지 않습니다.
기기에서 조작 테스트를 실행할 수 있지만, 골든 테스트는 화면만 렌더링하고
이미지 비교를 명시적으로 건너뜁니다. 기준 이미지와의 실제 비교는
`Pinball - Golden Tests` 또는 `flutter test --tags golden`으로 실행하세요.
테스트용 폰트는 컴퓨터에서만 로드하므로 기기에는 추가 자산이 필요 없습니다.

```sh
# Gherkin scenarios only
flutter test --tags gherkin

# Golden comparisons only
flutter test --tags golden

# Regenerate golden baselines after an intentional UI change
flutter test test/golden/pinball_screen_golden_test.dart --update-goldens

# Regenerate Dart widget tests after editing a .feature file
dart run build_runner build
```

The golden suite renders the real Flame/Forge2D table at a fixed `390 x 844`
surface. It covers the initial HUD, a charged launcher, and game-over. A bundled
test-only Roboto Mono font keeps text deterministic and readable.

The Gherkin source of truth is
`test/features/pinball_controls.feature`. `bdd_widget_test` generates the
corresponding Flutter widget test, while reusable step implementations live in
`test/steps/`. The scenarios exercise the initial HUD, both touch-controlled
flippers, launcher drag/release, restart, and keyboard nudge.

## Project Structure

```text
lib/
  main.dart          Flutter app, GameWidget host, HUD overlay, touch input routing
  pinball_game.dart  Flame/Forge2D game, physics bodies, scoring, rendering

test/
  features/          Gherkin feature and generated Flutter widget test
  fonts/             Deterministic test-only golden font
  golden/            Golden tests and committed PNG baselines
  steps/             Executable Gherkin step definitions
  support/           Shared game/widget test harness
  widget_test.dart   Smoke test for app/HUD rendering
```

## Architecture

Android 개발자 관점으로 보면 `main.dart`는 Activity/Fragment + overlay UI에 가깝고, `pinball_game.dart`는 custom game view + physics engine에 가깝습니다.

```mermaid
graph TD
  A[MonPinballApp] --> B[PinballScreen]
  B --> C["GameWidget of MonPinballGame"]
  C --> D[MonPinballGame]
  C --> E[PinballHud overlay]
  E --> F[Pointer input routing]
  F --> D
  D --> G[Forge2DWorld]
  G --> H[BodyComponent objects]
  H --> I[Ball, rails, flippers, bumpers, targets]
  D --> J[ValueNotifier<PinballSnapshot>]
  J --> E
```

### Layer Responsibilities

| Layer | File | Responsibility |
| --- | --- | --- |
| App shell | `lib/main.dart` | `MaterialApp`, screen setup, `GameWidget` mounting |
| HUD overlay | `lib/main.dart` | Score/lives/status/launcher charge UI |
| Touch input | `lib/main.dart` | Pointer down/move/up events, launcher drag tracking, flipper press state |
| Game state | `lib/pinball_game.dart` | Score, lives, launcher charge, game over, HUD snapshots |
| Physics world | `lib/pinball_game.dart` | Forge2D gravity, bodies, fixtures, collision callbacks |
| Rendered table | `lib/pinball_game.dart` | Board background, rails, bumpers, slingshots, ball, effects |

## Runtime Flow

Flame이 매 frame마다 `update(dt)`와 `render(canvas)`를 호출합니다. Android의 `Choreographer` + custom `View.onDraw()`를 game framework가 대신 관리한다고 보면 됩니다.

```mermaid
sequenceDiagram
  participant Flutter as Flutter Widget Tree
  participant GameWidget as Flame GameWidget
  participant Game as MonPinballGame
  participant World as Forge2DWorld
  participant HUD as PinballHud

  Flutter->>GameWidget: build()
  GameWidget->>Game: create MonPinballGame
  GameWidget->>Game: onLoad()
  Game->>World: add rails, bumpers, flippers, ball
  Game->>HUD: publish PinballSnapshot

  loop every frame
    GameWidget->>Game: update(dt)
    Game->>World: physics step
    World->>World: resolve contacts
    Game->>Game: drain check, launcher charge update
    Game->>HUD: ValueNotifier update if state changed
    GameWidget->>Game: render(canvas)
  end
```

## Main Classes

### `MonPinballGame`

`MonPinballGame` extends `Forge2DGame` and is the central game controller.

Responsibilities:

- Creates the fixed-size board world: `28 x 48`
- Owns score, lives, launcher charge, status, game-over state
- Publishes HUD data through `ValueNotifier<PinballSnapshot>`
- Handles keyboard input through Flame `KeyboardEvents`
- Builds rails, bumpers, targets, flippers, launcher, ball
- Detects drain when the ball falls below the table

Important methods:

| Method | Purpose |
| --- | --- |
| `onLoad()` | Initial world setup and component creation |
| `onGameResize()` | Fits the fixed world into the current screen |
| `update(dt)` | Per-frame launcher charge and drain detection |
| `isLauncherTouch()` | Converts screen coordinate to world coordinate and checks plunger zone |
| `launcherChargeFromDrag()` | Converts downward drag distance into charge `0.0..1.0` |
| `releaseLauncher()` | Applies launch velocity to the ball |
| `addScore()` | Updates score and spawns a pulse effect |
| `restartGame()` | Resets score/lives/ball/launcher state |

### `PinballHud`

`PinballHud` is a Flutter overlay on top of the Flame canvas. It uses `ValueListenableBuilder` to redraw when `MonPinballGame.hud` changes.

It also routes touch input:

- Left half: left flipper
- Right half outside plunger lane: right flipper
- Right plunger lane: drag launcher

The important design choice is that pointer input is handled in Flutter overlay code, but game intent is delegated into `MonPinballGame`. This keeps UI concerns out of the physics classes.

### Physics Components

Most table objects extend `BodyComponent<MonPinballGame>`. `BodyComponent` is the Flame/Forge2D bridge: it owns a Forge2D `Body`, renders it, and receives updates in the Flame component tree.

| Class | Body Type | Purpose |
| --- | --- | --- |
| `PinballBall` | dynamic | Main ball affected by gravity, impulse, collisions |
| `TableRail` | static edge | Table boundaries and lane rails |
| `Flipper` | kinematic | Player-controlled rotating flipper body |
| `Bumper` | static circle | Scores points and pushes the ball away |
| `Spinner` | static polygon | Scores points and renders spin feedback |
| `DropTarget` | static polygon | Scores target hits |
| `Slingshot` | static polygon | Triangle rebound zones near flippers |
| `LaunchLaneExit` | static sensor | Nudges launched ball from plunger lane into the playfield |
| `LauncherView` | visual only | Draws plunger track and charge position |
| `PulseRing` | visual only | Temporary score hit effect |

## Input Flow

### Touch: Flippers And Launcher

```mermaid
sequenceDiagram
  participant User
  participant HUD as PinballHud Listener
  participant Game as MonPinballGame
  participant Flipper
  participant Ball

  User->>HUD: pointer down
  HUD->>Game: isLauncherTouch(screen position)

  alt pointer is in plunger lane
    HUD->>Game: startLauncherCharge(timed: false)
    HUD->>Game: setLauncherDragCharge(0)
    User->>HUD: drag downward
    HUD->>Game: launcherChargeFromDrag(start, current)
    HUD->>Game: setLauncherDragCharge(charge)
    User->>HUD: pointer up
    HUD->>Game: releaseLauncher()
    Game->>Ball: launch(power)
  else left screen
    HUD->>Game: setLeftFlipper(true)
    Game->>Flipper: isPressed = true
    User->>HUD: pointer up
    HUD->>Game: setLeftFlipper(false)
  else right screen outside plunger lane
    HUD->>Game: setRightFlipper(true)
    Game->>Flipper: isPressed = true
    User->>HUD: pointer up
    HUD->>Game: setRightFlipper(false)
  end
```

### Keyboard

```mermaid
sequenceDiagram
  participant Keyboard
  participant GameWidget
  participant Game as MonPinballGame

  Keyboard->>GameWidget: key event
  GameWidget->>Game: onKeyEvent(event, keysPressed)
  Game->>Game: A/Left sets left flipper
  Game->>Game: D/Right sets right flipper
  Game->>Game: Space/Down/S charges or releases launcher
  Game->>Game: W/Up nudges ball
  Game->>Game: R restarts game
```

## Launcher Algorithm

Mobile launcher behavior intentionally uses drag distance instead of tap duration. This makes the control feel like pulling an actual spring.

```text
onPointerDown(position):
  if position is inside launcher lane:
    remember drag start position
    set charge to 0
    mark action as launcher
  else if x is left half:
    press left flipper
  else:
    press right flipper

onPointerMove(position):
  if current action is launcher:
    startWorld = screenToWorld(dragStart)
    currentWorld = screenToWorld(position)
    charge = clamp((currentWorld.y - startWorld.y) / 6.2, 0, 1)
    update HUD charge
    update LauncherView.charge

onPointerUp:
  if current action is launcher:
    power = max(charge, 0.2)
    ball.velocity = Vector2(0, -35 - 48 * power)
    reset charge to 0
```

Why `currentWorld.y - startWorld.y`:

- In this board coordinate system, larger `y` means lower on the table.
- Pulling the finger downward increases `y`.
- That maps naturally to stronger spring tension.

## Ball Launch And Lane Exit

The launcher lane is on the right side. The ball starts near the bottom of that lane. When launched, it travels upward. The top lane is intentionally widened, and `LaunchLaneExit` acts as a sensor to push the ball left into the playfield.

```mermaid
graph TD
  A[Ball starts at x=25, y=43] --> B[Player drags plunger down]
  B --> C[releaseLauncher]
  C --> D[PinballBall.launch]
  D --> E[Ball moves upward in right lane]
  E --> F[LaunchLaneExit sensor near top]
  F --> G[Set velocity to left/up]
  G --> H[Ball enters playfield]
```

The sensor does not physically block the ball because its fixture is `isSensor: true`. It detects contact and rewrites the ball velocity once, with a cooldown to avoid repeated impulses.

## Collision And Scoring

Forge2D contact callbacks are delivered through `ContactCallbacks`. Score objects mix in `ContactCallbacks` and implement `beginContact`.

```mermaid
sequenceDiagram
  participant World as Forge2DWorld
  participant Object as Bumper/Target/Spinner/Slingshot
  participant Game as MonPinballGame
  participant HUD as PinballHud

  World->>Object: beginContact(other, contact)
  Object->>Object: verify other is PinballBall
  Object->>Game: addScore(points, position, color, reason)
  Game->>Game: score += points
  Game->>World: add PulseRing effect
  Game->>HUD: publish PinballSnapshot
```

Scoring safeguards:

- Bumpers, spinners, and targets use short cooldowns to prevent score spam from a single contact cluster.
- `gameOver` prevents new score updates.
- Hit effects are separate `PulseRing` components so scoring does not depend on UI overlay rendering.

## Flipper Algorithm

The flippers are Forge2D kinematic bodies. They do not use a revolute joint yet. Instead, they rotate toward a target angle by setting angular velocity.

```text
update(dt):
  targetAngle = isPressed ? activeAngle : restAngle
  delta = targetAngle - currentAngle

  if abs(delta) is small:
    angularVelocity = 0
    snap transform to targetAngle if world is not locked
  else:
    angularVelocity = clamp(delta * 24, -24, 24)
```

Tradeoff:

- This is simpler and stable enough for the first version.
- A more realistic version can replace it with Forge2D `RevoluteJoint` and motor limits.

## Drain And Reset Flow

```mermaid
sequenceDiagram
  participant Game as MonPinballGame
  participant Ball as PinballBall
  participant HUD as PinballHud

  Game->>Game: update(dt)
  Game->>Ball: check ball.position.y
  alt y > boardHeight + 4
    Game->>Game: lives -= 1
    alt lives <= 0
      Game->>Game: gameOver = true
      Game->>Game: reset ball to launcher
    else lives remain
      Game->>Game: reset ball to launcher
    end
    Game->>HUD: publish PinballSnapshot
  end
```

## Coordinate System

The game uses a fixed world size and adapts camera zoom to screen size.

```text
World size: 28 x 48
Origin: top-left-ish table coordinate space
x increases to the right
y increases downward
Camera: centered at board center
Zoom: min(screenWidth / 28, screenHeight / 48) * 0.96
```

This means physics tuning is independent of phone resolution. The Flutter pointer position is converted back into world coordinates when checking the launcher lane.

## Current Limitations

- Flippers are kinematic angle-driven bodies, not joint-driven motors.
- There is no sound yet.
- There are no image assets. Everything is drawn with Canvas primitives.
- Table layout is hardcoded in world coordinates.
- Golden and Gherkin suites cover rendering and player controls, but low-level
  collision scoring and drain timing still rely on the Forge2D runtime.

## Good Next Refactors

1. Split `pinball_game.dart` into `components/`, `input/`, and `state/` folders once the table grows.
2. Replace flippers with `RevoluteJoint` + motor limits for more realistic physical response.
3. Add sound effects through `flame_audio`.
4. Add deterministic Forge2D component tests around collision scoring and
   drain/reset timing.
5. Extract table coordinates into a data object so levels can be tuned without editing component code.

## Initial Commit Checklist

```sh
flutter analyze
flutter test
git init
git add .
git commit -m "Initial Flame pinball game"
```
