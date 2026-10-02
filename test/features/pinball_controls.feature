@gherkin
Feature: Pinball player controls
  The HUD and controls should expose every player action described in the README.

  Background:
    Given the pinball app is running

  After:
    Then the pinball scenario is cleaned up

  Scenario: The game starts with a fresh HUD
    Then the score is {0}
    And the lives count is {3}
    And the status is {'Drag right plunger'}

  Scenario Outline: Either playfield side controls its flipper
    When I hold the <side> playfield
    Then the <side> flipper is pressed
    When I release the <side> playfield
    Then the <side> flipper is released

    Examples:
      | side    |
      | 'left'  |
      | 'right' |

  Scenario: Pulling and releasing the plunger launches the ball
    When I pull the plunger down by {80} pixels
    Then the launcher charge is greater than {0}
    And the status is {'Release to launch'}
    When I release the plunger
    Then the launcher charge is {0}
    And the status is {'Launched'}

  Scenario: The restart control clears the current run
    Given the player has scored {750} points
    When I tap the restart control
    Then the score is {0}
    And the lives count is {3}
    And the status is {'Drag right plunger'}

  Scenario: The keyboard can nudge the table
    When I press the {'W'} key
    Then the status is {'Table nudge'}
