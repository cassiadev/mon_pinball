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

- [ ] Write/run failing behavior tests for activation, changing motion phases,
  swept hits, overlap suppression, defeat, pause/cleanup and reset.
- [ ] Implement minimal model; pass tests and analysis.
- [ ] Commit `feat: add moonlit boss encounter and motion state`.

### Task 2: Garden art and articulated rendering

Create `assets/images/moonlit/`, `lib/moonlit_boss.dart`,
`lib/moonlit_table.dart`; modify `pubspec.yaml`, `lib/pinball_style.dart` and
existing table render methods. Renderer consumes `BossEncounter`; body, wings,
sleeves and hem animate independently. Generated art must have real transparency.

- [ ] Generate/inspect/save production assets and provenance.
- [ ] Apply garden palette and readable jewel art without compromising physics.
- [ ] Verify asset loading and idle/move/attack/hurt rendering.
- [ ] Commit `feat: render the moonlit garden and articulated boss`.

### Task 3: Combat integration and instruments

Modify `lib/pinball_game.dart`, `lib/main.dart`, related tests. Game owns encounter
and checks the launched ball segment after physics steps. Extend `PinballSnapshot`
with backwards-compatible optional health/combo/encounter fields.

- [ ] Write/run failing real-game tests for sensor hits, unchanged velocity,
  reset/drain/defeat cleanup and accessible health display.
- [ ] Connect renderer, motion, petals, health, damage popup and replay.
- [ ] Pass relevant tests; inspect/update intentional golden references.
- [ ] Commit `feat: connect boss weak points and petal attacks`.

### Task 4: Verification and documentation

Update English/Korean README and final regression/golden coverage.

- [ ] Full tests, static analysis and debug Android build.
- [ ] Inspect initial/attack/hurt/defeat images and center alignment.
- [ ] Physical-device launch/flippers, animation, visibility, hit/restart checks.
- [ ] Independent whole-change review; fix substantive findings and verify.
- [ ] Commit `test: verify moonlit boss gameplay and document controls`.
