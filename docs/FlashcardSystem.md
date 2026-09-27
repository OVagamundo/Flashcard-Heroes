# Flashcard System

## 1. Purpose & Architectural Overview

The Flashcard System is a core gameplay mechanic in *Flashcard Heroes* that integrates an *Anki*-style Spaced Repetition System (SRS) as the primary engine for encounter resource generation (Gacha Tokens). 

The system follows a strictly decoupled architecture:
- **Authoritative Data & Logic (`FlashcardManager.gd`)**: A persistent singleton managing minigame sessions, question generation, timer progression, SRS algorithmic weighting, streak tracking, and token calculation.
- **Run Progression & Persistence (`RunState.gd`)**: Stores the run's deck pool (`ordered_deck_pool`), currently unlocked cards (`active_deck_ids`), presentation progress (`cards_presented_count`), and per-card mastery records (`flashcard_progress`).
- **Modal Presentation (`FlashcardMinigame.gd`)**: Pure visual and input layer opened via `WindowManager`. Handles 2x3 answer grids, review popups, animations, particle VFX, audio hooks, and non-blocking celebration banners.
- **Command Pipeline Integration (`ActionQueue`)**: Supports deterministic player command execution via `GameAction` subclasses (`AcknowledgeFlashcardIntroAction`, `SubmitFlashcardAnswerAction`, `SkipFlashcardAction`), enabling both headless testing and animated gameplay without state desynchronization.

---

## 2. Card Definitions & Mastery Model

### Card Definition Schema
All flashcards are registered in `Database.flashcard_definitions` (keyed by `StringName` ID):
- `question: String`: The prompt displayed in the Japanese/Korean/Thai typography (e.g., `"火"`, `"猫"`).
- `answer: String`: The correct translation/romanization (e.g., `"Fire"`, `"Neko"`).
- `explanation: String`: Contextual or grammatical notes displayed during card introductions.
- `audio_file`: Audio cue mapped via `Audio.play_sfx("pronunciation_" + romaji/card_id)`.

### Mastery Progress (`FlashcardProgress.gd`)
Mastery is tracked dynamically per card for the active run:
- `card_id: StringName`: Unique identifier of the card.
- `mastery_level: int`: Value from 1 to 5 (clamped between `MASTERY_MIN = 1` and `MASTERY_MAX = 5`).
- `last_review_day: int`: The run day index when the card was last answered.
- `correct_count: int`: Total correct submissions in the run.
- `incorrect_count: int`: Total incorrect submissions in the run.

| Level | Label | Color | SRS Description |
|:---:|:---:|:---:|:---|
| **1** | Very Hard | Red `Color(0.9, 0.2, 0.2)` | Brand new card or frequently missed |
| **2** | Hard | Orange `Color(0.95, 0.5, 0.1)` | In training; moderate errors |
| **3** | Medium | Yellow `Color(0.95, 0.8, 0.1)` | Moderate familiarity |
| **4** | Easy | Green `Color(0.2, 0.8, 0.2)` | Well understood; low error rate |
| **5** | Very Easy | Blue `Color(0.2, 0.4, 0.9)` | Mastered; heavy weight dampening |

**Mastery Progression Rules:**
- All newly introduced cards initialize at Level 1 (`MASTERY_MIN`).
- **Correct answer:** `mastery_level += 1` (capped at 5).
- **Incorrect answer / Skip:** `mastery_level -= 1` (floored at 1).
- **Run Reset:** Mastery progress does not persist across separate runs.

---

## 3. Deck Progression & Architecture

Flashcard decks advance systematically across a run:

1. **`ordered_deck_pool: Array[StringName]`**:
   - The full sequence of cards selected at run start ("Full" or "Quick/Half" deck size).
   - Card order is immutable throughout the run.
2. **`active_deck_ids: Array[StringName]`**:
   - Unlocked cards available for question generation.
   - Initialized with the first 6 cards at run start (5 starter cards + 1 card unlocked by the first minigame's start expansion).
   - New cards append to this array either via start-of-minigame expansion or mid-mini game unlock.
3. **`cards_presented_count: int`**:
   - Tracks how many active cards have been formally introduced to the player.
   - If `cards_presented_count < active_deck_ids.size()`, the start-of-minigame review popup triggers.
   - Mid-mini game unlocks increment `cards_presented_count` synchronously to ensure subsequent mini games introduce the *next* card in the pool.
4. **Deck Expansion (`RunState.check_deck_expansion()`)**:
   - Called at the start of every mini-game encounter.
   - If `active_deck_ids.size() < ordered_deck_pool.size()`, unlocks `ordered_deck_pool[active_deck_ids.size()]`, initializes its progress at `MASTERY_MIN`, appends it to `active_deck_ids`, and emits `run_data_changed`.

---

## 4. The Flashcard Manager API & Session State

`FlashcardManager` is an autoload singleton orchestrating the session lifecycle:

### Public API
- `start_minigame(run_state: RunState, active_deck: Array[StringName]) -> void`
  - Validates card definitions, triggers start deck expansion, configures session timers and counters, creates the first question, and opens the UI modal (if not in headless mode).
- `submit_minigame_answer(question_id: StringName, selected_answer_id: StringName, think_time: float = 0.0) -> Dictionary`
  - Authoritatively processes answer submissions, adjusts mastery, tracks streaks, evaluates mid-mini game unlocks, updates timer (+0.5s on correct, +1.0s bonus if unlock triggers), increments token count, and queues next question.
- `skip_minigame_question(question_id: StringName, think_time: float = 0.0) -> Dictionary`
  - Authoritatively skips the question, decreases mastery by 1, preserves current streak, grants +0.5s timer extension, and queues next question.
- `get_next_question() -> Dictionary`
  - Selects next card using the weighted SRS algorithm, picks 5 random distractors from `_active_deck_ids`, and returns `{"question_id": StringName, "choices": Array[StringName]}`.
- `get_question_for_card(card_id: StringName) -> Dictionary`
  - Forces question generation for a specific card (used for mid-mini game unlocks) with 5 random distractors from `_active_deck_ids`.
- `acknowledge_intro() -> void`
  - Transitions from review popup to active question answering, increments `cards_presented_count`, and sets `is_sprint_active = true`.
- `advance_session_timer(seconds: float) -> void`
  - Decrements countdown timer. Triggers session completion when reaching 0.
- `get_deck_statistics() -> Dictionary`
  - Returns debug dictionary containing total cards, average mastery, and card distribution across mastery levels 1-5.

### Authoritative Session Variables
- `is_session_active: bool`: True while the modal window lifecycle is running.
- `is_sprint_active: bool`: Internal state flag; true while the player is actively answering questions (as opposed to reviewing cards).
- `is_introducing_new_card: bool`: True while the start-of-minigame review popup is displayed.
- `introduced_card_id: StringName`: ID of the card featured in the start-of-minigame review popup.
- `has_unlocked_midgame_card: bool`: Reset to `false` at minigame start; tracks whether a mid-mini game unlock has triggered in the active session.
- `session_timer: float`: Current countdown timer in seconds.
- `session_duration: float`: Base duration configured for the session (7.0s base; +2.0s with Sprint Charm).
- `correct_answers: int`: Total correct answers in the session.
- `total_answers: int`: Total questions answered or skipped.
- `current_streak: int`: Consecutive correct answers without an incorrect answer or skip.
- `tokens_earned: int`: Total tokens earned during the session.
- `current_question: Dictionary`: Active question payload `{"question_id": StringName, "choices": Array[StringName]}`.

### Public Signals
- `minigame_finished(results: Dictionary)`: Fired on session termination. Payload: `{ "correct_answers": int, "incorrect_answers": int, "total_answers": int, "tokens_earned": int }`.
- `session_timer_updated(current_time: float, max_time: float)`: Emitted whenever the timer changes.
- `session_question_changed(question_data: Dictionary)`: Emitted when the active question changes.

---

## 5. Mini-Game Flow & Lifecycle

The mini-game operates in four sequential phases:

```
[start_minigame]
       │
       ▼
[Phase 1: Card Introduction / Review Popup] (If cards_presented_count < active_deck_ids.size())
       │   - Displays card details & audio pronunciation
       │   - Displays 10 clickable priority cards sorted by SRS weight (no RNG)
       │   - Clicking "Ready!" calls acknowledge_intro()
       ▼
[Phase 2: Timed Question Loop]
       │   - Session timer begins (7.0s base; 9.0s with Sprint Charm)
       │   - Displays question and 6 choices in a 2x3 grid
       │   - Immediate input lock prevents double-tap race conditions
       │   - Correct: +1 Mastery, +0.5s time, token awarded, streak++, next after 0.05s
       │   - Incorrect: -1 Mastery, streak reset, next after 1.0s
       │   - Skip: -1 Mastery, +0.5s time, streak preserved, next after 0.5s
       │
       ├─► [Phase 3: Mid-Mini Game Unlock] (Triggers at streak == 3 if locked cards remain)
       │       - Unlocks next card, adds +1.0s bonus time, queues card as next question
       │       - Plays fireworks, golden panel flash, white timer buff pop, and banner
       ▼
[Phase 4: Session End & Cleanup]
       │   - Timer reaches 0.0s
       │   - Starter Hero minimum guarantee evaluated (awards up to 3 tokens if correct < 3)
       │   - Emits gacha_tokens_changed and minigame_finished signals
       │   - Modal window closed via queue_free()
```

---

## 6. Mid-Mini Game Card Unlock Specification

### Trigger Conditions & Guard
- Evaluated inside `submit_minigame_answer` when `was_correct == true`.
- Condition: `current_streak == 3` AND `not has_unlocked_midgame_card`.
- Guard: Evaluates `RunState.has_locked_cards()`. If `active_deck_ids.size() >= ordered_deck_pool.size()`, no card is unlocked and no timer bonus is granted.
- Limit: Strictly **once per mini-game session** (`has_unlocked_midgame_card` set to `true`).

### Unlocking & State Synchronization Contract
- Calls `RunState.unlock_next_deck_card()`:
  1. Appends next card from `ordered_deck_pool` to `active_deck_ids`.
  2. Initializes `flashcard_progress` for the card at `MASTERY_MIN` (1).
  3. Increments `cards_presented_count += 1` to mark the card as presented immediately.
  4. Emits `SignalBus.run_data_changed`.
- Synchronizes `FlashcardManager._active_deck_ids = _run_state_ref.active_deck_ids.duplicate()`.

### Immediate Question Queueing
- Calls `FlashcardManager.get_question_for_card(unlocked_card_id)`.
- Distractors: 5 cards picked randomly from `_active_deck_ids` (excluding the new card).
- Sets `current_question` to this new card and returns `midgame_unlocked_card_id` in the `submit_minigame_answer` return dictionary.
- Bypasses weighted SRS selection for this single turn to guarantee immediate presentation.

### Reward Rules
- **+1.0s Bonus Time**: Adds `+1.0s` to `session_timer` (combined with standard `+0.5s` for a correct answer, yielding `+1.5s` on the triggering question).
- **Standard Token Yield**: Answering the triggering question awards standard tokens (no additional tokens for the unlock itself).

### Audio-Visual Feedback Sequence (`FlashcardMinigame.gd`)
1. **Timer Bar Flash**: `_flash_timer_bar_bonus(Color.WHITE)` flashes the timer bar in bright white, fading back to green over 0.4s.
2. **Timer Buff Popup**: `_show_timer_buff_popup("+1.0s")` spawns a glowing white `+1.0s` label directly over `timer_label`, snapping to 1.5x scale and floating 60px upward over 0.7s; `timer_label` punches to 1.35x scale.
3. **Transition**: After 0.05s feedback pause, `_show_next_question_with_data` displays the newly unlocked card.
4. **Celebration Fanfare**:
   - **Fireworks (`FireworksCelebrationVFX`)**: 6 staggered radial particle explosions with additive blending across window edges and center.
   - **Golden Window Flash**: Modulates main panel to `Color(1.8, 1.6, 0.7)` with 0.35s fade into the card's mastery color.
   - **Screen Shake**: `SignalBus.screen_shake_requested.emit(0.2)`.
   - **Audio**: Plays `ui_merge` celebratory chime.
   - **Celebration Banner (`_show_midgame_unlock_banner`)**: Non-blocking floating banner displaying `★ NEW CARD UNLOCKED! ★` (`ui.midgame_card_unlocked`) and `+1.0s TIME BONUS!` (`ui.midgame_bonus_info`), with elastic overshoot pop (`0.4 -> 1.1 -> 1.0`) and upward float.

### Subsequent Mini-Game Progression Contract
- Because `cards_presented_count` was incremented during the mid-mini game unlock, `cards_presented_count` matches `active_deck_ids.size()`.
- At the start of the next mini-game, `check_deck_expansion()` adds the *following* card from the pool, which is introduced in the review popup.
- Result: Up to 2 cards unlocked per mini-game encounter (1 at start review popup + 1 mid-mini game), cleanly doubling deck progression pace.

---

## 7. Spaced Repetition System (SRS) Algorithm

Question selection calculates priority weights for every eligible card in `_active_deck_ids`:

$$\text{Weight} = \text{MasteryComponent} + \text{TimeComponent} + \text{RandomComponent}$$

1. **Mastery Component (Priority 1 - High)**:
   $$\text{MasteryComponent} = (6 - \text{mastery\_level})^2$$
2. **Recency Component (Priority 2 - Medium)**:
   $$\text{TimeComponent} = (\text{current\_day} - \text{last\_review\_day}) \times 1.0$$
3. **Random Component (Priority 3 - Low)**:
   $$\text{RandomComponent} = \text{randf}() \times 0.1$$

### Mastery Dampening Multipliers
To ensure mastered cards do not crowd out active study material, selection weights are dampened:
- **Level 5 (Very Easy)**: Weight multiplied by `0.02` (98% reduction).
- **Level 4 (Easy)**: Weight multiplied by `0.15` (85% reduction).
- **Level 3 (Medium)**: Weight multiplied by `0.40` (60% reduction).
- **Level 1 & 2**: No dampening (100% full weight).

### Selection Rules & Distractors
- **No Immediate Repeats**: The card matching `_last_shown_card_id` is excluded from candidate selection unless the active deck has only 1 card.
- **Distractor Selection**: Exactly 5 distractors are picked randomly from `_active_deck_ids` (excluding the question card). The question and distractors are shuffled together into 6 choices.
- **SRS Bypass**: When a mid-mini game unlock occurs, weighted SRS selection is bypassed for that single turn to immediately present the unlocked card via `get_question_for_card()`.

---

## 8. Visual Presentation & Audio Polish (Juice)

### Typography & Layout
- **Font**: `NotoSansJP-Black.ttf` for question prompts, choices, and intro labels.
- **Question Prompt**: 120pt font size; cool black `Color(0.15, 0.17, 0.22)` with warm white outline `Color(0.98, 0.96, 0.92)` (outline size 8).
- **Choices Grid**: 2x3 grid using textured theme buttons with 32px composite font.
- **Dynamic Mastery Panel Tint**: The panel background modulates smoothly to the color of the current card's mastery level.

### Dynamic Audio Feedback
- **Correct SFX Pitch**: `minigame_correct` sound pitch scales upwards by `+0.05` per streak level (capped at `1.5x` at streak 10+), creating a rising melody.
- **BGM Tempo Escalation**: Active `BGM_MINIGAME` track pitch and tempo increase by `+0.02` per streak level (capped at `1.2x` at streak 10+). Incorrect answers reset BGM pitch immediately to `1.0`.

### Dynamic Visual Feedback (Juice)
- **Minigame Aura VFX (`MinigameAuraVFX.tscn`)**: Edge border fire frames the outer boundaries of the panel using 4 particle emitters:
  - Particle amount, speed, and spread scale linearly with correct streak.
  - Border fire shifts colors across streak tiers:
    - **Streak 1–2**: Cyan
    - **Streak 3–5**: Purple
    - **Streak 6–8**: Gold
    - **Streak 9+**: Magenta
  - Renders behind the main panel (`show_behind_parent = true`).
- **Token Pop VFX**: Currency pop-up particles scale amount, size, and spin velocity with current streak tier.

### UI Token Counter Layering Exemption
- To allow the player to observe live token changes during the mini-game, `_setup_token_counter_exemption()` reparents `%TokenGroup` to `%ModalLayer` above the modal backdrop dimming layer, restoring it to its original parent on window exit.

---

## 9. Context-Sensitive Rewards & Synergies

### Encounter Contexts
- **In Battle (`BattleManager`)**:
  - Each correct answer awards **1 Gacha Token** (temporary currency for drawing units/items in the Management Phase; resets after battle).
  - Incorrect / Skip: 0 Tokens.
- **At Rest Sites (`RestSite.gd`)**:
  - Correct answers award Rest Site Tokens used at stat shrines for permanent Hero base stat increases.

### Trinket & Hero Modifiers
- **Starter Hero Guarantee (`hero_starter`)**:
  - If the active hero is `hero_starter` and the player achieves fewer than 3 correct answers, a bonus of `3 - correct` tokens is awarded upon session completion, ensuring a baseline of at least 3 tokens.
- **Beginner's Charm (`trinket_beginners_charm`)**:
  - Awards **2 Gacha Tokens** instead of 1 when answering a card at Level 1 mastery (`MASTERY_MIN`).
- **Sprint Charm (`trinket_time_sprint_charm`)**:
  - When in battle, increases base session duration by **+2.0s** (7.0s base $\rightarrow$ 9.0s).

---

## 10. Command Pipeline & Headless Architecture

The Flashcard System fully supports the deterministic command pipeline:

- **`AcknowledgeFlashcardIntroAction`**: Validates dismissal of the start review popup and transitions state to active question answering.
- **`SubmitFlashcardAnswerAction`**: Dispatches `question_id`, `selected_answer_id`, and `think_time`, routed through `submit_minigame_answer()`.
- **`SkipFlashcardAction`**: Dispatches `question_id` and `think_time`, routed through `skip_minigame_question()`.
- **Headless Mode**: When `ActionQueue.is_headless_mode() == true`, `FlashcardManager` bypasses UI modal instantiation, allowing test suites and headless QA simulation bots to execute full mini-game sessions with synthetic think times.
- **Deadlock Safeguard**: `_on_minigame_complete()` automatically finishes any pending flashcard action in `ActionQueue` when the session timer expires.