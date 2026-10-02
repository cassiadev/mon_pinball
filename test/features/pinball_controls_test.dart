// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@Tags(['gherkin'])
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/hooks.dart';
import './../steps/the_pinball_app_is_running.dart';
import './../steps/the_pinball_scenario_is_cleaned_up.dart';
import './../steps/the_score_is.dart';
import './../steps/the_lives_count_is.dart';
import './../steps/the_status_is.dart';
import './../steps/i_hold_the_playfield.dart';
import './../steps/the_flipper_is_pressed.dart';
import './../steps/i_release_the_playfield.dart';
import './../steps/the_flipper_is_released.dart';
import './../steps/i_pull_the_plunger_down_by_pixels.dart';
import './../steps/the_launcher_charge_is_greater_than.dart';
import './../steps/i_release_the_plunger.dart';
import './../steps/the_launcher_charge_is.dart';
import './../steps/the_player_has_scored_points.dart';
import './../steps/i_tap_the_restart_control.dart';
import './../steps/i_press_the_key.dart';

void main() {
  setUpAll(() async {
    await Hooks.beforeAll();
  });
  tearDownAll(() async {
    await Hooks.afterAll();
  });

  group('''Pinball player controls''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await thePinballAppIsRunning(tester);
    }

    Future<void> bddTearDown(WidgetTester tester) async {
      await thePinballScenarioIsCleanedUp(tester);
    }

    Future<void> beforeEach(String title, [List<String>? tags]) async {
      await Hooks.beforeEach(title, tags);
    }

    Future<void> afterEach(String title, bool success,
        [List<String>? tags]) async {
      await Hooks.afterEach(title, success, tags);
    }

    testWidgets('''The game starts with a fresh HUD''', (tester) async {
      var success = true;
      try {
        await beforeEach('''The game starts with a fresh HUD''');
        await bddSetUp(tester);
        await theScoreIs(tester, 0);
        await theLivesCountIs(tester, 3);
        await theStatusIs(tester, 'Drag right plunger');
      } catch (_) {
        success = false;
        rethrow;
      } finally {
        await bddTearDown(tester);
        await afterEach(
          '''The game starts with a fresh HUD''',
          success,
        );
      }
    });
    testWidgets(
        '''Outline: Either playfield side controls its flipper ('left')''',
        (tester) async {
      var success = true;
      try {
        await beforeEach(
            '''Outline: Either playfield side controls its flipper ('left')''');
        await bddSetUp(tester);
        await iHoldThePlayfield(tester, 'left');
        await theFlipperIsPressed(tester, 'left');
        await iReleaseThePlayfield(tester, 'left');
        await theFlipperIsReleased(tester, 'left');
      } catch (_) {
        success = false;
        rethrow;
      } finally {
        await bddTearDown(tester);
        await afterEach(
          '''Outline: Either playfield side controls its flipper ('left')''',
          success,
        );
      }
    });
    testWidgets(
        '''Outline: Either playfield side controls its flipper ('right')''',
        (tester) async {
      var success = true;
      try {
        await beforeEach(
            '''Outline: Either playfield side controls its flipper ('right')''');
        await bddSetUp(tester);
        await iHoldThePlayfield(tester, 'right');
        await theFlipperIsPressed(tester, 'right');
        await iReleaseThePlayfield(tester, 'right');
        await theFlipperIsReleased(tester, 'right');
      } catch (_) {
        success = false;
        rethrow;
      } finally {
        await bddTearDown(tester);
        await afterEach(
          '''Outline: Either playfield side controls its flipper ('right')''',
          success,
        );
      }
    });
    testWidgets('''Pulling and releasing the plunger launches the ball''',
        (tester) async {
      var success = true;
      try {
        await beforeEach(
            '''Pulling and releasing the plunger launches the ball''');
        await bddSetUp(tester);
        await iPullThePlungerDownByPixels(tester, 80);
        await theLauncherChargeIsGreaterThan(tester, 0);
        await theStatusIs(tester, 'Release to launch');
        await iReleaseThePlunger(tester);
        await theLauncherChargeIs(tester, 0);
        await theStatusIs(tester, 'Launched');
      } catch (_) {
        success = false;
        rethrow;
      } finally {
        await bddTearDown(tester);
        await afterEach(
          '''Pulling and releasing the plunger launches the ball''',
          success,
        );
      }
    });
    testWidgets('''The restart control clears the current run''',
        (tester) async {
      var success = true;
      try {
        await beforeEach('''The restart control clears the current run''');
        await bddSetUp(tester);
        await thePlayerHasScoredPoints(tester, 750);
        await iTapTheRestartControl(tester);
        await theScoreIs(tester, 0);
        await theLivesCountIs(tester, 3);
        await theStatusIs(tester, 'Drag right plunger');
      } catch (_) {
        success = false;
        rethrow;
      } finally {
        await bddTearDown(tester);
        await afterEach(
          '''The restart control clears the current run''',
          success,
        );
      }
    });
    testWidgets('''The keyboard can nudge the table''', (tester) async {
      var success = true;
      try {
        await beforeEach('''The keyboard can nudge the table''');
        await bddSetUp(tester);
        await iPressTheKey(tester, 'W');
        await theStatusIs(tester, 'Table nudge');
      } catch (_) {
        success = false;
        rethrow;
      } finally {
        await bddTearDown(tester);
        await afterEach(
          '''The keyboard can nudge the table''',
          success,
        );
      }
    });
  });
}
