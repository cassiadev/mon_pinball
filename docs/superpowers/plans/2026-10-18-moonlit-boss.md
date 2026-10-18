# Moonlit Boss Implementation Plan

> Execute tasks in order with Superpowers test-driven development, stage commits
> and a final independent review. The user explicitly approved implementation.

**Goal:** Implement the approved moonlit garden pinball boss encounter.
**Architecture:** A deterministic encounter model controls motion, health,
weak-point detection and decorative petals; a layered Flame renderer displays
local art, and existing physics/input/Flutter instruments consume that model.
**Tech Stack:** Existing Flutter, Flame and Forge2D; no new dependencies.
**Spec:** Approved conversation; binding design requirements are recorded below.

## Global Constraints

- Large jewel obstacles stay on the physical table; the big boss floats across
  them on an independent layer rather than forcing the table downwards.
- Jade bumper, moon emblem and flipper gap share board center x=14.
- Include articulated idle, movement, attack anticipation/recovery and hurt
  motion using separate art parts, not only whole-image translation.
- Use a moving weak-point sensor, not a solid giant boss body. Fast ball
  crossings count; continuous overlap must not cause repeated damage.
- Keep launch waiting/charging and controls, responsive layout and accessibility.
- First version has one non-physical petal pattern; higher-difficulty physical
  petals and elaborate entrance/defeat sequences remain deferred as agreed.
- Local bundled assets only. Preserve existing tests; intentional visuals get
  new golden references after inspection.
- Commit verified stages with existing English Conventional Commit titles,
  behavior/rationale and actual validation in the body. No push/merge.
- Android real-device validation only; wait for unlock before device interaction.

## Rulings for open game rules

One boss per round. Health 16000, weak-point damage 1280. A hit leaves ball
velocity unchanged. Defeat stops attacks and offers replay without consuming
lives. Boss attacks start after launch, pause/clear on drain, and reset on replay.
First art can use separate mirrored wing/sleeve parts plus body and trailing hem;
independent transforms provide breathing, lag, attack and recoil poses.

## Review Focus

Fast swept hits; repeated overlaps; inactive ball/defeat/restart cleanup;
art loading and fixed center axis; accessible narrow/large-text/landscape UI;
bounded petal count and time-based animation.

### Task 1: Encounter state and motion timing

Create `lib/boss_encounter.dart` and `test/boss_encounter_test.dart`.
Interface: deterministic `BossEncounter` with board-space position, health,
active/defeated state, time, motion pose, petals and start/update/reset/pause.
Swept segment weak-point hit method returns damage or zero. No game/UI imports
except existing Vector2 math. Rendering and hit detection use the same position.

- [x] Write/run failing behavior tests for activation, changing motion phases,
  swept hits, overlap suppression, defeat, pause/cleanup and reset.
- [x] Implement minimal model; pass tests and analysis.
- [x] Commit `feat: add moonlit boss encounter and motion state`.

### Task 2: Garden art and articulated rendering

Create `assets/images/moonlit/`, `lib/moonlit_boss.dart`,
`lib/moonlit_table.dart`; modify `pubspec.yaml`, `lib/pinball_style.dart` and
existing table render methods. Renderer consumes `BossEncounter`; body, wings,
sleeves and hem animate independently. Generated art must have real transparency.

- [x] Generate/inspect/save production assets and provenance.
- [x] Apply garden palette and readable jewel art without compromising physics.
- [x] Verify asset loading and idle/move/attack/hurt rendering.
- [x] Commit `feat: render the moonlit garden and articulated boss`.

### Task 3: Combat integration and instruments

Modify `lib/pinball_game.dart`, `lib/main.dart`, related tests. Game owns encounter
and checks the launched ball segment after physics steps. Extend `PinballSnapshot`
with backwards-compatible optional health/combo/encounter fields.

- [x] Write/run failing real-game tests for sensor hits, unchanged velocity,
  reset/drain/defeat cleanup and accessible health display.
- [x] Connect renderer, motion, petals, health, damage popup and replay.
- [x] Pass relevant tests; inspect/update intentional golden references.
- [x] Commit `feat: connect boss weak points and petal attacks`.

### Task 4: Verification and documentation

Update English/Korean README and final regression/golden coverage.

- [x] Full tests, static analysis and debug Android build.
- [x] Inspect initial/attack/hurt/defeat images and center alignment.
- [x] Physical-device launch/flippers, animation, visibility, hit/restart checks.
- [x] Independent whole-change review; fix substantive findings and verify.
- [x] Commit `test: verify moonlit boss gameplay and document controls`.

## Verification record

Host: 66 tests passed, including 11 golden comparisons; full static analysis
reported no issues. Debug Android build succeeded. On the unlocked Galaxy
SM-M336K, manual play confirmed launch, articulated flight, scoring/health
changes, damage preserved on drain, victory and replay. All 20 combat,
instrument and responsive/input tests also passed through the live widget test
binding on that physical device; device output counted 22 including setup and
teardown. Normal `lib/main.dart` was restored afterward for playing.

Independent final review and one scoped fix review passed. Follow-up commit
`4886d49` exposes combo/defeat to screen readers and disposes popup painters.
No emulator, remote push or merge was used.

## Implementation decisions

- The managed checkout could not be edited under the workspace permissions;
  archive that empty checkout and keep the named feature branch in the original
  writable workspace. This shares that workspace with the user's local work.
- Use the approved conversation as the specification and record open rules here
  without a new approval loop. A misunderstood rule would require adjustment.
- Move the rose bumper 0.4 units left to keep a full ball passage at its large
  radius. This changes its horizontal composition slightly, preserving center
  alignment and leaving obstacle heights unchanged.
