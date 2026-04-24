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
- **Incorrect answer / Skip:** Mastery decreases by 1 (min 1).
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

1. **Card Introduction (if applicable):** 
   
   **Initial 6 Cards:** The first 6 cards (5 starting + 1 from the first minigame) form the active deck at run start. They are formally introduced via the new card popup **one by one, in order**, each time a minigame is started until all 6 have been introduced. This initial sequential introduction happens **even if the player does not have the mastery levels required** for deck expansion.
   
   **Deck Expansion (Cards 7+):** New cards beyond the initial 6 are added to the active deck one at a time whenever the player has leveled *all* currently active cards to at least **Mastery Level 3**. When a new card is added, the new card popup shows it.
   
   **Priority Cards Preview:** The popup displays 10 clickable card buttons at the bottom showing the highest-priority cards from the active deck (sorted by SRS weight without RNG). Each button is colored according to its mastery level. Clicking a button switches the main display to show that card's information. This allows players to preview or study cards before they are formally introduced.

2. **Start Timer:** A session begins with the title **"Get Tokens!"** ("Ganhar Fichas!" in Portuguese). The modal window disables all other interactions.

3. **Question Loop:**
   - **Select Question:** Uses SRS algorithm (see Section 5).
   - **Display:** Shows question with 6 multiple-choice answers in a 2x3 grid.
   - **Player Answers:**
     - ✓ Correct: Button highlights **Green**, Panel flashes **white**, mastery +1, timer +0.5s, spawns token VFX, next question after 0.05s.
     - ✗ Incorrect: Button highlights **Red**, correct answer highlights **Green**, Panel flashes **red**, mastery −1, NO token, next question after 1.0s.
     - ⏭ Skip: Correct answer highlights **Green**, timer +0.5s, NO token, mastery -1, next question after 0.5s.
   - **Input Locking**: Inputs are strictly locked at the very start of the `_on_choice_selected` and `_on_skip_pressed` handlers. Any subsequent attempts to interact with the minigame are ignored until the visual transition completes and the **new** answer buttons are spawned.

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

**Question & Answer Layout:**
- **Structure**: Uses a side-by-side layout for Question and Answer labels.
- **Font**: Must use **32px Black Composite** font for clarity.
- **Tints**: The entire panel inherits a color tint based on the current card's **Mastery Level** (e.g., Red for Level 1, Blue for Level 5).
- **Style**: Uses textured theme buttons for the 2x3 answer grid.

**Flash Feedback:**
- Correct: Flash white (0.15s)
- Incorrect: Flash red (0.15s)

---

## 7. Context-Sensitive Rewards

Rewards are handled by the calling system, not the FlashcardManager:

**In Battle (BattleManager):**
- **Correct Answer**: = 1 Gacha Token (temporary, resets after battle).
- **Incorrect/Skip**: NO Token.

**At Rest Sites (RestSite.gd):**
- **Correct Answer**: Provides tokens used to draw Permanent Hero Base Stat increases.
- **Incorrect/Skip**: NO Token.