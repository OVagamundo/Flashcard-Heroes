# Implementation Mandate: Headless QA Bot

## 1. Commander's Intent & Context
We are implementing an automated QA Bot designed to stress-test the game's fully deterministic `ActionQueue` architecture. The bot will run completely "headless" (without UI or visual overhead) to execute runs as fast as the CPU allows. Its primary goals are to find edge-case bugs, crashes, soft-locks, and **game balance issues** (such as broken builds or overpowered combos) across millions of simulated runs.

Because the game is fully deterministic, the bot's output is highly valuable: any crash or soft-lock it finds can be perfectly reproduced by loading its generated `.mcr` replay file into the normal visual game client.

---

## 2. Bot Autonomy (The Chaos Strategy)
The bot operates strictly as a random stress-tester ("monkey on a keyboard"). 
* **State Evaluation:** Whenever the game state requires player input (Run Map, Shop, Battle, etc.), the bot queries the current state for a list of all theoretically valid `GameAction`s.
* **Random Selection:** It selects one valid action completely at random using a dedicated, isolated `SeededRNG` stream (e.g., `qa_bot_rng`) so that the bot's decisions are deterministically reproducible.
* **Execution:** It instantiates the `GameAction` and pushes it to the `ActionQueue`.

---

## 3. Headless Pacing & Visual Replayability
The bot must execute at maximum CPU speed without breaking the deterministic rules.
* **Headless Bypass:** When the game is launched with the `--qa-bot` flag, no visual scenes or UI nodes are loaded. The `ActionQueue` MUST bypass the `AnimationCompletionTracker` entirely, popping and resolving actions instantly without waiting for any physical time or tweens.
* **Bot Time Delta:** Because the bot calculates decisions instantly, the real-world time elapsed between actions is effectively 0 seconds. To ensure replays remain human-watchable, the bot MUST inject a standardized `time_delta` (e.g., `1.0` seconds) into every serialized `.mcr` payload instead of 0.0. **Critical Pacing Rule:** The injected `time_delta` is ONLY written to the text file. The bot itself must NEVER actually `await` or sleep; it must push the next action instantly on the same frame to maintain maximum CPU execution speed.
* **Visual Replayability:** The bot still serializes every action into a standard `.mcr` replay file. Since the engine is deterministic, developers can load a bot's `.mcr` file into the normal game client. The normal Replay Viewer will apply the injected `time_delta` rules and animation blocking, allowing the developer to watch the bot's chaotic 100x speed run organically at normal or controllable speeds to visually see how the game broke.

---

## 4. Telemetry & Success Metrics
When a bot concludes a run, it must output a complete package of data to `user://qa_runs/`:
1. **The Replay File (`.mcr` & `.log`):** The exact standard playback files required to visually replay the run.
2. **Statistical Telemetry (`.json`):** A detailed data dump containing:
   * Run Seed
   * Win/Loss/Crash outcome
   * Floor reached
   * Statistical aggregates (purchases made, units merged, total damage dealt, etc.)

3. **Outlier & Balance Flagging:** If a run exceeds predefined mathematical thresholds (e.g., dealing >10,000 damage in a single turn, clearing a boss in 1 round, or achieving infinite loops), the bot must flag this run with a `BALANCE_WARNING` tag. This allows developers to easily search for and replay anomalous "broken builds" that the chaos monkey managed to construct.

---

## 5. Soft-Lock Detection & Crash Dumping
A soft-lock occurs when the game is waiting for player input, but no valid moves exist.
* **Detection Rule:** After evaluating the game state, if the game requires a choice but there are **exactly 0 valid `GameAction`s** available to the bot, it must instantly throw a `SOFTLOCK_ERROR`.
* **Preservation:** Upon detecting a soft-lock, the bot instantly flushes the active `.mcr` and `.log` files and dumps the exact current `RunState` into the telemetry JSON. This guarantees developers have the exact replay file leading up to the freeze.
