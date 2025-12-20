# Flashcard System

**Version:** 1.2  
**Status:** Active

## 1. Purpose & Responsibility

The Flashcard System is a core gameplay mechanic designed to test player knowledge and serve as the primary driver for in-battle resource generation. The system is encapsulated within the FlashcardManager singleton.

**Core Responsibilities:**
- Managing the lifecycle of the flashcard mini-game.
- Presenting a high-speed, modal quiz to the player at specific gameplay moments.
- Implementing a weighted Spaced Repetition System (SRS) to select questions.
- Tracking and updating the player's mastery level for each card within a run.
- Reporting the results of a mini-game session to the calling system.

---

## 2. Mastery System

Each flashcard has a **mastery level** from 1 to 5, tracked per run (resets when starting a new run).

| Level | Label | Color | Description |
|-------|-------|-------|-------------|
| 1 | Very Hard | Red `Color(0.9, 0.2, 0.2)` | Card just added or frequently missed |
| 2 | Hard | Orange `Color(0.95, 0.5, 0.1)` | Still challenging |
| 3 | Medium | Yellow `Color(0.95, 0.8, 0.1)` | Moderate familiarity |
| 4 | Easy | Green `Color(0.2, 0.8, 0.2)` | Well understood |
| 5 | Very Easy | Blue `Color(0.2, 0.4, 0.9)` | Fully mastered |

**Mastery Progression:**
- All cards start at level 1 (Very Hard).
- **Correct answer:** Mastery increases by 1 (max 5).
- **Incorrect answer:** Mastery decreases by 1 (min 1).
- Mastery does **not** persist across runs.

---

## 3. The Flashcard Manager

The FlashcardManager is a persistent singleton that orchestrates the entire mini-game flow.

**Public API:**
- `start_minigame(run_state: RunState, active_deck_ids: Array[StringName])` - Initiates the mini-game.

**Public Signals:**
- `minigame_finished(results: Dictionary)` - Fired when the timer expires. Payload: `{ "correct_answers": int, "incorrect_answers": int }`.

---

## 4. Mini-Game Flow

When `start_minigame` is called:

1. **Card Introduction (if applicable):** One new card is introduced per session until all deck cards are active.

2. **Start Timer:** 5-second session begins. The modal window disables all other interactions.

3. **Question Loop:**
   - **Select Question:** Uses SRS algorithm (see Section 5).
   - **Display:** Shows question with 9 multiple-choice answers.
   - **Player Answers:**
     - ✓ Correct: Panel flashes **white**, mastery +1, next question instantly.
     - ✗ Incorrect: Panel flashes **red**, mastery −1, next question instantly.

4. **Session End:** Timer expires → window closes → `minigame_finished` signal emitted.

---

## 5. Spaced Repetition System (SRS)

Question selection uses weighted random selection with three priority factors:

| Priority | Factor | Weight Formula |
|----------|--------|----------------|
| 1 (High) | Mastery Level | `pow(6 - mastery_level, 2.0)` |
| 2 (Medium) | Recency | `(current_day - last_review_day) * 1.0` |
| 3 (Low) | Randomizer | `randf() * 0.1` |

**Rules:**
- Lower mastery = higher selection weight.
- The same card **never** appears twice in a row.

---

## 6. Visual Presentation

**Question Label:**
- Font: NotoSansJP-Black
- Size: 120pt
- Color: Cool black `Color(0.15, 0.17, 0.22)` with warm white outline `Color(0.98, 0.96, 0.92)`

**Panel Color:**
- Matches the current question's mastery level color.
- Changes after each answer to reflect the new question's mastery.

**Flash Feedback:**
- Correct: Flash white (0.15s)
- Incorrect: Flash red (0.15s)

---

## 7. Context-Sensitive Rewards

Rewards are handled by the calling system, not the FlashcardManager:

**In Battle (BattleManager):**
- Each correct answer = 1 Gacha Token (temporary, resets after battle).

**At Rest Sites (RestSite.gd):**
- Every 2 correct answers = +1 to Hero's chosen stat (HP or PWR).