Flashcard System
Version: 1.1
Status: Active
1. Purpose & Responsibility
The Flashcard System is a core gameplay mechanic designed to test player knowledge and serve as the primary driver for in-battle resource generation. The system is encapsulated within the FlashcardManager singleton.
Core Responsibilities:
Managing the lifecycle of the flashcard mini-game.
Presenting a high-speed, modal quiz to the player at specific gameplay moments.
Implementing a weighted Spaced Repetition System (SRS) to select questions.
Tracking and updating the player's mastery level for each card within a run.
Reporting the results of a mini-game session to the calling system.
2. The Flashcard Manager
The FlashcardManager is a persistent singleton that orchestrates the entire mini-game flow. It is a self-contained UI and logic system.
Public API:
start_minigame(run_state: RunState, active_deck_ids: Array[StringName])
The primary method used to initiate the mini-game. It is called by other systems like the BattleManager or RestSite.
Public Signals:
minigame_finished(results: Dictionary)
Fired when the mini-game's timer expires.
The results payload is a dictionary: { "correct_answers": int, "incorrect_answers": int }.
3. Mini-Game Flow
When start_minigame is called, the FlashcardManager executes the following sequence:
Card Introduction (If Applicable):
The manager now introduces **exactly one new card at the start of each mini‑game session** until every card from the main deck has been added.
The new card is shown on an introduction screen with its question, answer, and explanation. The player clicks "Got It!" to continue.
The card is permanently added to `RunState.active_deck_ids` and to the session's `_active_deck` list, ensuring it persists across runs.
Start Timer:
A global session timer of 3 seconds begins. This timer is for the entire quiz, not per question.
The mini-game UI appears as a large modal window, disabling all other game interactions.
Question Loop:
The manager enters a loop that continues until the timer expires.
Select Question: It uses the SRS algorithm (see Section 4) to select a card from the Active Deck.
Generate Choices: It displays the question and presents 9 multiple-choice options. The options are the correct answers from 9 other random cards in the Active Deck.
Player Answers: The player clicks an answer.
Correct: The answer flashes white. The card's mastery_level increases by 1 (clamped at 5). The next question appears instantly.
Incorrect: The answer flashes red. The card's mastery_level decreases by 1 (clamped at 1). The next question appears instantly. There is no other penalty.
Session End:
When the 3-second timer expires, the mini-game window closes immediately.
The FlashcardManager calculates the total number of correct and incorrect answers.
It emits the minigame_finished signal with the results.
4. Spaced Repetition System (SRS)
To optimize learning and challenge, the question selection is not purely random. It uses a weighted random selection algorithm based on the following factors:
Mastery Level (High Weight): Cards with a lower mastery level (1-5) are significantly more likely to be chosen. The formula pow(6 - mastery_level, 2) is used to give a strong preference to less-mastered cards.
Time Since Last Review (Medium Weight): Cards that have not been seen for a longer time (measured in game "Days") are more likely to appear.
Randomness (Low Weight): A small random factor is included to ensure any card can still appear, preventing predictability.
Rule: The same card will never be presented twice in a row during a single mini-game session.
5. Context-Sensitive Rewards
The rewards for the mini-game are not handled by the FlashcardManager. The manager simply reports the results, and the calling system determines the reward based on the context. This keeps the manager's responsibility focused.
In Battle (Called by BattleManager):
Each correct answer awards 1 Gacha Token.
These tokens are temporary and are reset to zero after the battle encounter is resolved.
At Rest Sites (Called by RestSite.gd):
The mini-game does not award Gacha Tokens.
Every two correct answers permanently increases the Hero's chosen stat (HP or PWR) by 1 for the rest of the run.