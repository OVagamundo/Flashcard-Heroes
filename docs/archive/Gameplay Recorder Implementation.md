# Gameplay Recorder & Replay Implementation: The Event-Driven Architecture

## 1. Architectural Foundation: The Slay the Spire 2 Event-Driven Machine

This implementation is founded on the **pure event-driven state machine architecture** of *Slay the Spire 2*:

> **The game does not possess a free-running continuous game loop that mutates state or presentation behind the scenes. The game advances strictly and exclusively through an ordered sequence of discrete Actions.**
> 
> **ANY player input or system trigger that produces ANY visual or gamestate consequence—including UI drawer opening/closing, entity inspections, tutorial page progression, valid transactions, and even failed/rejected attempts (such as an invalid drag drop that snaps back with rejection VFX)—MUST go through `GameAction` and `ActionQueue`.**

### Why This Makes Recording and Playback Trivial
When this architectural principle is enforced with zero bypass:
1. **Recording is Trivial:** `GameplayRecorder` simply observes `ActionQueue.action_started` and appends the serialized JSON payload of each action to the `.mcr` file.
2. **Playback is Trivial:** `ReplayController` simply reads the serialized actions from the `.mcr` file in sequence and dispatches them back into `ActionQueue.request(action)`.
3. **Identical Visual and State Reproduction:** Because the game’s presentation layer (views, animations, drawers, VFX) and domain data model (`RunState`, `GameManager`) react exclusively to resolved actions from the queue, dispatching the exact same action stream automatically reproduces the exact same visual choreography and state transitions without special-case playback shims.

### Elimination of Fragmentation ("This or That Interaction")
Previous documentation and implementations failed because they became bogged down in enumerating individual rooms and interactions with ad-hoc exceptions, caveats, and UI bypasses. Under the STS2 model, there are no special cases:
* Opening or closing the inventory drawer is an action (`OpenInventoryAction` / `CloseInventoryAction`).
* Inspecting an entity or closing an inspection is an action (`InspectEntityAction` / `CloseInspectionAction`).
* Dragging an item to an illegal slot or dropping it without resources is an action that resolves with rejection VFX and snap-back presentation.
* Buying an item, selecting a path, rolling stats, or submitting answers are actions.
* Autonomous transitions (like minigame timeouts or phase steps) enter the queue as scheduled system-origin actions.

No UI node, button callback, or background click may ever mutate state or change visible window state directly. They must all submit a `GameAction` through `ActionQueue`.

The project has two divergent copies of this document. This file is the requested `res://docs/Gameplay Recorder Implementation.md`; keep it as the implementation reference and reconcile `localization/docs/Gameplay Recorder Implementation.md` before using that copy as guidance.

### Implementation status (2026-10-01)

Schema 3 is the **currently implemented, action-only** format. It records typed actions, pre-action and completed-action digests, and initial `GameManager` state. Playback restores the captured `RunState` and manager snapshot, submits the same typed actions through `ActionQueue`, checks the current question and selected answer for flashcard actions, and stops before an ordinary action if its pre-state differs. The digest includes logical run/RNG state, battle state, temporary room data, flow/modal state, deterministic run-scoped IDs, and the active flashcard question. Cosmetic RNG and continuously changing countdown values are excluded. Schema 3 is not outcome-complete: explicit inventory/inspection/tutorial interactions, some automatic outcomes, and complete gameplay RNG verification are still missing.

Several action-refactor gaps were corrected while investigating divergence: flashcard answer/skip actions now commit through `FlashcardManager` using the recorded question ID before the view animates, and the view callbacks no longer have a fallback that can commit a second answer outside the action; study-once flags, room-entry resets, and reward-room setup are manager-owned rather than being established only in UI `_ready()`; and path/shop actions validate the intended target. Schema 3 also captures the initial `GameManager` transient and director state created while generating the first map. Continue checkpoints carry the same manager state needed to resume the action stream. Schema 1 and 2 replays lack one or more of these verification fields, so the current controller rejects them. If Continue finds only a schema 1 or 2 replay, it creates a new schema 3 checkpoint replay rather than appending unverifiable events to the old file.

This still needs runtime verification. No end-to-end replay, Continue, timing, or speed run has been performed in this change. The header records Godot version and playback rejects a mismatch; the project has no configured game/content version, so its `dev` fallback cannot detect content changes. The replay target is the same gameplay outcomes plus ordered, explicit interface choices that determine what is open, inspected, or available next. Pixel/audio equivalence is not required. Current schema 3 does not yet capture all required interface choices, automatic outcomes, or gameplay RNG state.

Replay isolation remains active on completion or desync until the spectator exits. Playback time scale and animation speed are restored on completion/error; exit also restores the saved timer, tutorial state, and manager settings.

## 1.1 Replay Gap Audit (2026-10-01)

### Finding and scope

**Readiness: not ready for outcome-reliable replay.** This is a static source audit, not proof that every mutation site has been enumerated. The screenshot supplied with the report shows a mismatch **before `StartTrainingAction`, sequence 2**, after the replay has reached the Training Ground. Therefore the training action itself has not yet executed at the failing boundary. The screenshot does not identify which field differs: the UI reports only two opaque digest values, while day, gold, tokens, and elapsed time are just a small subset of the state. The exact cause needs a path-by-path comparison of the recording and current replay state.

The current recorder observes accepted `ActionQueue` actions. That is a useful command log, but it is not a complete event log of every mutation. The refactor's source-neutral action path is necessary; it does not automatically capture timers, signals, scene setup, UI-local state, tweens, physics, or random draws that occur outside an action.

### Confirmed gaps and risks

| Priority | Evidence in current code | Why replay can diverge | Required change |
|---|---|---|---|
| **P0 — state coverage** | `GameplayRecorder` writes `action_started` and `action_completed` events. `GameManager.get_replay_state_snapshot()` is a hand-selected projection, not a full state inventory. It omits elapsed run time and deliberately removes the `cosmetic` RNG stream; `FlashcardManager.get_replay_state_snapshot()` omits the countdown. Inventory open/close, locked inspection, focus/selection, and some modal state have no ordered replay event. | A gameplay value, timer boundary, or explicit UI choice can differ without a useful checkpoint. The current digest cannot diagnose the first difference. | Checkpoint canonical authoritative state, flow/input availability, gameplay RNG streams, and time-dependent outcomes. Record or derive explicit interface choices that affect what is open, inspected, or available next. Do not record every UI property, cursor position, tween, physics frame, cosmetic RNG draw, pixel, or audio sample unless it changes gameplay or input availability. |
| **P0 — non-action state transitions** | `FlashcardMinigame._process()` advances the session timer; `FlashcardManager.advance_session_timer()` can call `_on_minigame_complete()` at zero. `FlashcardMinigame._end_minigame()` also calls completion directly. These time-driven transitions are not `GameAction`s. `TutorialPopup._on_next_pressed()` changes its page directly; `WindowManager` opens/closes inspection and inventory UI through direct calls/signals. | A timeout can change rewards or battle flow without a recorded cause. Tutorial page changes and opening/closing inventory or inspection can be absent even though they determine the screen and next available interaction. | Resolve gameplay-changing automatic events through a typed system-origin action or deterministic, causally recorded consequence. Route explicit player interface choices through the same ordered input/event boundary as gameplay actions; they need not mutate the domain model. Derive passive visual updates from canonical state instead of logging every redraw or animation. |
| **P0 — alternate mutation routes** | `PathChoice._on_node_selected()` has a no-queue fallback that clears `available_path_nodes` and emits `node_selected`; `GameManager` still listens to `node_selected` and performs room selection. Similar fallback routes exist in shop, reward, training, rest-site, and tutorial UI. `GameManager` still has signal listeners for shop purchase/reroll, reward selection, black-market operations, and path selection. | `ActionQueue` is a request gate, not a mutation firewall. A legacy signal or fallback can mutate state without appearing in the replay stream. These branches may be rare with autoloads present, but their existence violates the zero-bypass contract and needs verification. | Remove mutation fallbacks or make them fail closed. Require an active action transaction for authoritative writes; inventory every `SignalBus` emitter/listener and public state-mutating API, then prove each game-changing edge has exactly one recorded source. |
| **P0 — UI/headless execution split** | Some actions branch on whether a view exists and whether headless mode is enabled. For example, `UpgradeRestSiteAction` / `ClaimRestSiteGoldAction` call `RestSite.execute_upgrade_visuals()` in visual mode, where `_apply_prize()` calls `GameManager.claim_rest_site_prize()`, and call the manager directly in headless mode. `CollectRewardAction` similarly delegates visual collection to the view, which emits `reward_chosen`; its headless route emits that signal itself. | The action type is shared, but the state commit and timing are not owned at one invariant boundary. UI destruction, missing views, scene timing, or callback ordering can change the result or leave an action pending. | Have each action commit once through a model transaction that returns a resolved result. Give that result to the view for presentation only. Headless execution should call the same transaction and skip only presentation. |
| **P1 — gameplay RNG completeness** | Runtime scripts mostly use `RNGManager` streams. `FlashcardManager` consumes `map_rng` for spaced-repetition selection, distractors, and answer shuffles, sharing draws with map/encounter/deck generation. `FireworksCelebrationVFX` uses native `PALETTES.pick_random()`, which is cosmetic. | A missed gameplay draw can shift later maps, encounters, rewards, training rolls, or questions. Cosmetic RNG differences alone are acceptable under the current fidelity target. | Ensure every gameplay-affecting random result comes from a recorded, restorable stream or is stored in the resolving action result. Prefer subsystem-specific gameplay streams where call-order coupling is unnecessary. Include gameplay stream state/call counts and PRNG/content versions in diagnostics. Native cosmetic randomization need not be deterministic unless it can affect gameplay. |
| **P1 — asynchronous and time-driven work** | Gameplay and UI use `_process`/`_physics_process`, timers, deferred calls, tweens, and animation-completion signals. `ActionQueue` timestamps actions on one global timer, but `is_busy()` is not a general gameplay/UI-settled barrier. | A timer or callback can change game flow while replay is waiting for the next player choice. Frame differences matter only when they change a timeout, commit an authoritative result, or determine when an input becomes legal. | Give gameplay-changing automatic consequences a stable causal ID and deterministic simulation-time boundary. Wait for consequences that affect state or input eligibility before dispatching the next choice. Do not require identical tween or decorative-frame completion. |
| **P1 — weak diagnostics and compatibility guard** | `ReplayStateDigest.digest()` hashes normalized JSON into one `hash()` value. On mismatch, the viewer prints expected/got hashes and a few run fields, not the differing path. Header `game_version` falls back to `dev` because no project version is configured. | A hash detects some differences but cannot explain them and can theoretically collide. Replays can be attempted against changed game code or data with no useful compatibility diagnosis. | Store canonical state checkpoints (or stable per-component hashes plus a structured diff source), report the first differing field and RNG stream, and record a build/content fingerprint. Reject incompatible files before playback. |

### RNG audit details

The repository-wide GDScript/C# search found one remaining native array randomizer in runtime scripts: `PALETTES.pick_random()` in `FireworksCelebrationVFX`. It affects decoration, not gameplay results, so it does not need to be replayed exactly. `RNGManager.initialize(-1)` uses `randomize()` / global `randi()` only to choose the normal-play master seed; that bootstrap is expected, but the resulting master seed must be captured (it is). `SeededRNG` state is serialized, including its large state as an exact decimal string, which addresses the JSON precision bug. This still does **not** establish full gameplay RNG determinism: call order depends on every gameplay random draw being covered, and flashcards share `map_rng` with map/encounter generation. Cosmetic stream differences are acceptable unless a cosmetic call can influence a gameplay stream or outcome. The tool-only asset generator has a local RNG and is outside runtime playback.

### Required diagnosis for the supplied divergence

Do not infer from the screenshot that `StartTrainingAction` or its reward roll caused this mismatch: the pre-action digest check stops before executing it. Compare the first two `GameAction` records and their corresponding result records in the `.mcr` against a structured snapshot from playback immediately before action sequence 2. Report the first differing path, then inspect RNG stream states/call counts and pending timers/signals since the prior action. Until the digest reports a path and the pre-action snapshot is saved, `expected state …, got …` confirms divergence but not its source.

### Revised fidelity contract

The required replay target is **the same authoritative gameplay results and the same meaningful sequence of available choices and explicit interface interactions** under a compatible build/content version. This includes inventory/trinket changes, currencies, unit stats, rewards, map and room progression, battle and flashcard outcomes, and explicit opening/closing/inspection actions that determine what the player can see or do next. Reproduce timeouts or other automatic events when they can alter those results or input opportunities. The replay does not need to reproduce exact pixels, audio samples, decorative random choices, or animation frames. Pure scratch and presentation state can be omitted when it cannot affect a future gameplay decision, result, or available input. Do not describe the current schema as outcome-verified until gameplay RNG, automatic consequences, interface-action coverage, and structured mismatch diagnostics are implemented and verified.

### Implementation order after this audit

1. Build a mutation/source inventory for `RunState`, `GameManager`, battle/flashcard managers, global signals, UI entry points, timers, deferred callbacks, and RNG calls. Classify each authoritative mutation as a player action or a system-origin consequence with one causal owner. Classify explicit interface choices (inventory open/close, inspection focus/close, tutorial page changes, and blocking modal choices) as ordered replay events when they affect visible state or the next available input. Do not log passive redraws, decorative tweens, audio, or cursor motion. Close every unclassified gameplay write or input transition.
2. Make actions own one authoritative transaction and return resolved results. Remove direct UI fallbacks and eliminate unguarded legacy mutation signals.
3. Add canonical gameplay snapshots and structured first-difference diagnostics for authoritative state, game flow/input availability, timer boundaries, and gameplay RNG state. Checkpoint at each gameplay or replay-relevant interface event boundary.
4. Audit every gameplay RNG draw, isolate streams where useful, and fingerprint the PRNG/content version. Cosmetic draws need not be captured when they cannot feed back into gameplay.
5. Implement the ordered interface interactions and deterministic automatic outcomes needed by the outcome-focused contract. Then verify replay from the first event through inventory-heavy paths, minigames, room transitions, Continue, and supported playback speeds before calling the feature outcome-verified.

## 1.2 Concrete Action-Path Trace and Required Fixes

### Confirmed alternate routes and ownership gaps

These are code paths to fix or explicitly prove unreachable. An `ActionQueue` null-check fallback is still an architectural bypass even if the autoload normally exists: the fallback makes the same input behave differently precisely when the queue is unavailable.

| Code path | Current behavior | Classification | Fix needed |
|---|---|---|---|
| `PathChoice._on_node_selected()` | The normal path requests `SelectPathAction`; the `else` path clears `available_path_nodes` and emits `node_selected`, which is connected to `GameManager._on_node_selected()` and performs node selection / RNG / room transition directly. | **Confirmed bypass fallback.** | Remove the fallback mutation and signal. Fail closed with a clear error if the action queue is unavailable. Keep `_on_node_selected()` reachable only through the action resolver. |
| `GlobalInteractionRouter._execute_request_action()` and `ChoiceWindow._on_choice_made()` | Normal drag/merge/swap paths request typed actions. Queue-unavailable branches emit `try_inventory_action` / `choice_made`; `InventoryManager` still listens to both and mutates inventory. | **Confirmed bypass fallback.** | Remove both legacy listener routes or convert the signals into pure requests that are accepted only by `ActionQueue`. Reject and clean up the drag when no queue is available. |
| `Shop` purchase/reroll callbacks | Normal buttons request `BuyShopAction` / `RerollShopAction`; animation callbacks retain branches that emit `shop_purchase_requested` / `shop_reroll_requested`. `GameManager` listens to those signals and mutates stock/gold. | **Confirmed fallback route.** | Have the action transaction commit once and return its result to the view. Remove UI-to-GameManager mutation signals and preserve the coin-first choreography as presentation around the transaction. |
| `EndBattlePopup`, `RunCompletePopup`, `TutorialPopup`, room UIs | These controls usually request actions, but queue-unavailable branches directly emit flow signals, clear saves, mark tutorials complete, sell/collect, train, claim prizes, or advance scenes. | **Confirmed fallback family.** | No fallback may perform a game or flow mutation. Require the queue, or display an actionable failure while leaving state untouched. Audit each branch rather than treating queue availability as a harmless convenience. |
| `BlackMarket` and reward collection views | The user intent enters as `RemoveBlackMarketAction`, `TransformBlackMarketAction`, `CollectRewardAction`, or `SellRewardAction`, but view callbacks later emit `black_market_action_requested` / `reward_chosen`; `GameManager` performs the authoritative write from those signals. | **Not an unrecorded player command, but wrong mutation owner.** The callback is causally downstream of the recorded action, yet the view controls when and whether the transaction commits. | Move the authoritative commit into an action-owned transaction. Return a resolved result to the view and let the view animate that result; keep only explicitly required delayed commits inside a queue-owned transaction with a stable completion token. |
| `UpgradeRestSiteAction` / `ClaimRestSiteGoldAction` | In visual mode the action hands off to `RestSite.execute_upgrade_visuals()`, and `_apply_prize()` calls `GameManager.claim_rest_site_prize()`. In headless/missing-view mode the action calls that manager method itself. | **Split visual/headless transaction.** | Resolve/claim once in the action or a shared model transaction; pass the same result to either presentation mode. Validate prize existence/type in the action, not only `slot_index >= 0`. |
| `FlashcardMinigame._process()` → `FlashcardManager.advance_session_timer()` | A frame timer changes session state and directly calls `_on_minigame_complete()` at zero. `BattleManager._on_flashcard_completed()` then emits `results_acknowledged`, whose listener advances the battle without a `GameAction`. | **Confirmed automatic flow bypass.** | Model expiry/completion as an idempotent system-origin `GameAction` with a recorded simulation-time boundary. Battle phase changes caused by completion must be part of that action’s causal transaction and settle before its result checkpoint. |
| `TutorialPopup._on_next_pressed()` and `WindowManager` open/close APIs | Tutorial page changes and inventory/inspection window lifecycle are directly mutated by controls or signals. The recorder has no ordered input event for these explicit choices. | **Replay-relevant interface gap.** | Add typed interface actions (or an equivalent ordered event accepted at the same input boundary) for inventory open/close, locked inspection focus/close, tutorial page advance, and blocking modal choices. Derive passive redraws and decorative presentation from state. |
| `SceneManager._change_scene_to()` | After adding a destination scene it calls `ActionQueue.finish_action(ActionQueue.get_active_action())`, finishing whichever action is active without a transition-specific ownership token or explicit destination-ready acknowledgement. | **Completion-boundary hazard.** | Finish only the transition action that requested that scene, and only after the destination has declared gameplay and presentation state ready. Do not use “some scene was added” as the settle signal. |
| `GameManager` signal listeners | `GameManager._ready()` still connects mutating handlers for `node_selected`, shop purchase/reroll, reward reroll, and black-market actions. Some emitters are valid action consequences; some are legacy fallbacks; `reward_reroll_requested` has no runtime emitter in the searched GDScript tree. | **Unenforced mutation API / stale endpoint.** | Inventory every emitter/listener pair. Replace state-mutating signals with typed action results or private transaction calls. Remove dead endpoints and assert an active action transaction at each remaining authoritative mutation entry point. |

A behavior-contract cross-check found one more discrepancy: after End Turn, the intended automatic battle phases allow only pause and inspection. `BattleView` disables inventory inspection during COMBAT but leaves combat speed buttons enabled in every phase. The behavior and action-plan documents now record the intended restriction and the code gap; speed controls need phase gating if that contract is authoritative.

The search also found direct `RunState` writes in `BattleManager`, `BattleState`, `DeathProcessor`, inventory/effect resolvers, and `GameManager`. **Do not mechanically turn each assignment into its own action.** A damage, death, token, or inventory mutation can be a legitimate causal consequence of a root `EndTurnAction`, `MoveInventoryAction`, or other command. The rule should be: every authoritative write happens inside an active action transaction, including transactions initiated by system-origin actions, with a causal ID and one result boundary. A write made by a free-running callback, signal listener, timer, or view with no such context is a bypass. Add a development-time mutation guard/instrumentation so this distinction is enforced rather than inferred from names.

### Can live play and replay really use the same path?

**Yes for game rules and action resolution, with a narrower infrastructure exception.** A live input producer and the replay reader can both create the same serialized `GameAction`; the queue can validate and execute it identically. The game-rule layer does not need to know who chose the action. Autonomous game transitions must enter as system-created actions through the same queue, while rendering consumes resolved action/event results. This preserves the refactor's intended model.

The application shell still needs to know the source for input ownership, recording, and external side effects. Current code does: `ActionQueue.RequestSource.REPLAY` blocks live requests; `GameplayRecorder` suppresses recording while replaying; and `GameManager.is_replay_run` branches around `SaveManager.save_run()` / `clear_save()` in path generation and end-of-run actions. Those are not different game outcomes, but they mean the literal claim “the game does not know it is replaying” is not currently true. Move persistence/telemetry decisions behind shell-level policies or adapters. Keep the source tag at ingress and never branch in validation, transaction resolution, RNG choice, or gameplay progression.

“Every change must be driven by `GameAction`” is achievable for authoritative gameplay and explicit player choices, including interface actions that affect which windows or objects are active. Timer expiry and autonomous progression must be deterministic consequences of an existing action or typed system-origin actions through the same queue. A mutation can be a causal effect within one transaction; every field assignment or redraw does not need a separate action. The game-rule layer can use the same validation and resolution path for live and replay input; the application shell still distinguishes source for input gating, recording, and persistence. Exact pixels and audio are outside the replay contract.

## 2. Goals and Fidelity Boundary

1. Record a run after initialization, including the post-loadout starting state, accepted gameplay and explicit interface actions, and deterministic automatic outcomes that change gameplay or input availability.
2. Replay by restoring the run’s initial state and submitting deserialized actions through `ActionQueue`, preserving the existing action validation and execution path.
3. Wait for action/scene readiness before submitting ordinary actions. Stop and report a desync instead of silently skipping a rejected action.
4. Offer pause and speed controls for spectators without changing the recorded event order or outcomes.
5. Append continued play to the same run recording, keyed by the existing `run_id`.
6. Keep action payloads to logical serializable values. Identify inspected objects and windows by stable logical IDs; never store engine object references or pixel coordinates. Do not capture frames, audio samples, cursor paths, or decorative animation state.

### Fidelity promise

The required guarantee is **the same gameplay results and the same meaningful sequence of available choices and explicit interface interactions** under a compatible build/content version. Replays must preserve accepted gameplay actions, gameplay RNG outcomes, automatic results such as timeouts, and explicit window/inspection/modal actions that affect what the player can see or do next. They do not need to reproduce exact pixels, audio, cursor movement, decorative random choices, or animation frames. Compare canonical gameplay and flow/input checkpoints and report the first differing field. Record a format version and build/content fingerprint and reject incompatible data.

Synchronous flushes provide a useful crash boundary, but are not zero-overhead: filesystem stalls can briefly delay the main thread. Recording must not change gameplay state if a write fails; report the recorder error and keep the game’s action path intact.

## 3. Recorder and Replay Data Contract

### Replay driver (`.mcr`)

Store line-delimited JSON under `user://replays/`. Use one header followed by ordered event lines. A minimal contract is:

**Run header** — written after the run has been initialized and before the first player action:

```json
{
  "event_class": "RunHeader",
  "schema_version": 4,
  "run_id": "...",
  "run_seed": 88888,
  "hero_def_id": "hero_ironclad",
  "deck_id": "starter_deck",
  "deck_order": "REGULAR",
  "deck_size": "FULL",
  "game_version": "...",
  "initial_state": {
    "rng_state": {},
    "uuid_state": {}
  },
  "initial_manager_state": {
    "director_run_state": {},
    "encounter_director_run_state": {},
    "temporary_rewards": [],
    "temporary_shop": []
  }
}
```

Capture the selected loadout values before they are lost, and capture the post-initialization state at the Floor 1 map boundary. `initial_state` stores `RunState.to_save_dict()` including RNG and UUID state. `initial_manager_state` stores run-local flags, directors, room transients, and playback settings after initial map generation; restore both before loading Main. Do not rely on a seed-only header if deterministic initialization can change with content or code updates.

**Action event** — use the action’s own serializer:

```json
{
  "event_class": "GameAction",
  "source": "LIVE",
  "action_type": "BuyShopAction",
  "timestamp": 14.52,
  "idle_time": 1.25,
  "pre_state_digest": "...",
  "slot_index": 0,
  "cost": 5,
  "expected_definition_id": "unit_t1_a"
}
```

`GameplayRecorder` should serialize the accepted `GameAction` with `to_dict()` on `ActionQueue.action_started` and flush the line. `ActionQueue.action_requested` includes requests that may subsequently be rejected and is not the recording boundary. Include a line number in reader/desync diagnostics. `ActionFactory.create_from_dict()` already reconstructs the typed action via the action’s `from_dict()`.

Schema 3 is action-only and is insufficient for the outcome-focused guarantee. The next format revision must add ordered system-origin actions and state checkpoints, plus typed interface actions for explicit player choices such as opening/closing inventory, locking/changing/closing inspections, advancing tutorial pages, and dismissing blocking prompts. Use a monotonically increasing event sequence, simulation-time positions where deadlines affect outcomes, stable source/event IDs, and versioned payloads. Timer expiry and automatic progression that changes authoritative state or input availability must run through the same action queue as typed system-origin actions or deterministic consequences of the active action. Passive redraws and decorative animation are derived presentation, not replay events.

After each completed gameplay or interface `GameAction`, and each gameplay-changing system-origin action, write an `EventResult` referencing its global source-event sequence and action type, with a fast digest and canonical gameplay/flow checkpoint sufficient to produce a structured diff. Pure system deadline markers need no result because they cannot mutate game state:

```json
{
  "event_class": "EventResult",
  "source_event_sequence": 12,
  "source_event_class": "GameAction",
  "action_type": "SubmitFlashcardAnswerAction",
  "state_digest": "...",
  "state_checkpoint": {"authoritative": {}, "flow": {}, "presentation": {}, "rng": {}}
}
```

The pre-state is checked before dispatch. A mismatch must report the first differing state path and expected/actual values, not just opaque hash integers. The result checkpoint is taken after the action and all causally related visual/scene work settle. Random outcomes may be recomputed only when their entire input state and RNG call order are covered; otherwise record the resolved random result as part of the event.

For pause/speed meta-actions, preserve their ordering relative to the active action if they are included in replay fidelity. They cannot be normalized into ordinary “next action after idle” events. An alternative is to exclude those controls from the game-action stream and let the viewer own pause/speed; document the selected behavior in the file format.

### Location and presentation data

Keep JSON payloads to primitive serializable values: `int`, `float`, `String`, `bool`, `Dictionary`, and `Array`. `StringName` values serialize as strings. Location-bearing actions already serialize locations with `LocationIdentifier.to_dict()` and reconstruct them with `LocationIdentifier.create_from_dict()`. Replay-relevant interface actions should identify windows and inspected entities with stable logical IDs; they must not contain `Control` references, instance IDs, or runtime pointers. Pixel coordinates are unnecessary for the current outcome-focused contract.

Never put screen coordinates or engine objects into an action. An interface action should identify the logical window or entity, and the view should look it up at playback time from canonical state.

### Narrative log (`.log`)

Write a companion human-readable log with the run ID, selected loadout, simulation timestamp, action name, and useful resolved context. Keep it diagnostic: narration must not be an input to replay. If no safe description is available, log the action type and serialized logical payload rather than querying presentation objects from the recorder.

## 4. Action Coverage and Timing Rules

`ActionFactory` registers all concrete action classes, including both domain gameplay actions and replay-relevant interface actions. Each implements `to_dict()` and `from_dict()`.

The action set includes:

| Actions | Serialized fields |
|---|---|
| `SelectPathAction` | `node_index: int`, expected node type/subtype/encounter/boss/difficulty |
| `MoveInventoryAction` | `source_loc: Dictionary`, `target_loc: Dictionary` |
| `ConfirmMergeAction` | `source_loc`, `target_loc`, `recipe_id` |
| `ConfirmSwapAction` | `source_loc`, `target_loc` |
| `MergeEncounterAction` | `source_loc`, `target_loc`, `recipe_id` |
| `DrawGachaAction`, `DrawRewardAction`, `DrawRestSiteAction` | `tier: int` |
| `EndTurnAction`, `AcknowledgeRunCompleteAction`, `RerollShopAction`, `LeaveShopAction`, `StudyRewardAction`, `LeaveRewardAction`, `StudyRestSiteAction`, `LeaveRestSiteAction`, `CloseTrainingPopupAction`, `LeaveTrainingAction`, `LeaveBlackMarketAction`, `LeaveMergeEncounterAction` | no action-specific fields |
| `AcknowledgeBattleResultsAction` | `is_victory: bool` |
| `SetCombatSpeedAction` | `speed: float` (meta-action) |
| `PauseRunAction` | `is_paused: bool` (meta-action) |
| `AcknowledgeFlashcardIntroAction` | no action-specific fields |
| `SelectFlashcardIntroCardAction` | `card_id: String` |
| `SubmitFlashcardAnswerAction` | `question_id: String`, `selected_answer_id: String`, `think_time: float` |
| `SkipFlashcardAction` | `question_id: String`, `think_time: float` |
| `DismissTutorialAction` | `tutorial_id: String` |
| `BuyShopAction` | `slot_index: int`, `cost: int`, `expected_definition_id: String` |
| `CollectRewardAction`, `SellRewardAction` | `instance_uuid: String` |
| `UpgradeRestSiteAction` | `slot_index: int` |
| `ClaimRestSiteGoldAction` | `prize_index: int` |
| `StartTrainingAction` | `target_unit_uuid: String`, `stat_type: String` |
| `TrainUnitStatAction` | `token_cost: int` |
| `RemoveBlackMarketAction`, `TransformBlackMarketAction` | `target_uuid: String`, `cost: int` |
| `OpenInventoryAction` | `kind: String` (`"RUN"` or `"BATTLE"`) |
| `CloseInventoryAction` | `kind: String` (`"RUN"` or `"BATTLE"`) |
| `SelectEntityAction` | `location: Dictionary`, `entity_uuid: String` |
| `DeselectAction` | no action-specific fields |
| `InspectEntityAction` | `entity_uuid: String`, `definition_id: String`, `context: String` |
| `CloseInspectionAction` | `window_id: int`, `close_all: bool` |
| `AdvanceTutorialPageAction` | `tutorial_id: String`, `page_index: int` |
| `OpenDiscardPileAction`, `CloseDiscardPileAction` | no action-specific fields |
| `CancelDragAction` | `source_loc: Dictionary`, `target_loc: Dictionary`, `reason: String` |

The list above groups actions for readability; the action classes and their serializers define the actual field types and defaults. Interface actions ensure that explicit UI choices (opening/closing inventory drawers, inspection windows, entity selection, tutorial page flips, failed drag attempts) are recorded in the `.mcr` stream so replay playback visually and structurally matches live play.

Continuous pointer motion and transient hover previews (e.g. hovering an item to see its tooltip without clicking) are non-authoritative presentation effects; they open locally via `WindowManager` without going through `ActionQueue`, and are muted during replay playback (`is_vcr_playing()`). In contrast, discrete player clicks (selection, deselection, locked inspection, window close) must always flow through `ActionQueue` as first-class `GameAction`s.

### Timing and action completion

- Pace ordinary actions against their recorded `timestamp`, but never dispatch while the queue or scene is still resolving. If visual work runs past the target timestamp, dispatch as soon as the queue is idle; retain `idle_time` for diagnostics.
- Ordinary playback waits for the prior action’s completion and for the destination input state to be ready. `ActionQueue.is_busy()` alone is not an explicit scene/modal readiness API; add a readiness signal or verified gate for transitions where necessary.
- Handle synchronous actions carefully: non-yielding actions may emit `action_completed` inside `ActionQueue.request()` before it returns.
- Do not assume `idle_time` is valid for meta-action pacing. Meta-actions bypass the busy gate and do not advance the queue’s last-action timestamp. `PauseRunAction` stops the global run timer, so its elapsed wall time cannot be recovered from that timer.
- Flashcard answer/skip actions identify the exact current question. `validate()` checks that question against `FlashcardManager` and the visible minigame before execution; action execution commits the answer/skip centrally, then the view presents the result. `think_time` remains an optional serialized input and is passed unchanged to the manager in visual and headless execution.
- A presentation callback such as `execute_acknowledge_intro()`, `execute_choice_selected()`, or `execute_skip()` must not mutate authoritative manager/run state. The action owns the model change; the view consumes the committed result for animation and labels. Do not add a direct UI fallback that applies the same result when the queue is unavailable.

## 5. Run Start, Continue, and Replay Isolation

### Run start

The current live start flow receives hero, deck, order, and size from `Loadout`, but the `GameManager` start handler generates a fresh seed internally. Add a replay-only startup/restore method that accepts a validated header or complete initial state. Do not alter the normal loadout start defaults. At playback start, reset `loading_from_save`, queue busy state, run timer, replay state, run-local `GameManager` values, and combat speed to known defaults.

### Save and continue

**Current behavior:** `Title._on_continue_pressed()` restores the serialized `RunState`, including RNG, deterministic UUID counter, and elapsed simulation time, then resumes the timer. Schema 3 can append a checkpoint containing the full `RunState` plus transient manager state, including temporary room instances and director state; playback restores it and reloads Main before later actions. A schema 1 or 2 recording is not extended: Continue starts a new schema 3 replay at the saved checkpoint, preserving the old file. A save without a matching replay also starts a checkpoint replay.

**Outcome-focused target:** schema 4 checkpoints must include canonical gameplay state, flow/input availability, gameplay RNG state, and pending gameplay-changing system events with their simulation-time deadlines. Explicit inventory/inspection/tutorial interactions must be in the ordered event stream. Existing schema 3 recordings may be offered as reduced-coverage playback or rejected when verified outcome replay is selected; do not silently label them verified. Continue must append only when the checkpoint and format are compatible, otherwise begin a new checkpoint recording without modifying the old one.

### Replay-only input gate

During playback, block live gameplay requests at the input/action boundary, including keyboard shortcuts and meta-actions. Permit requests from the replay controller and controls from the replay viewer. A full-screen mouse blocker is useful for pointer input, but does not block global `_input` handlers or prevent a meta-action from reaching `ActionQueue`. Do not reuse `GlobalInteractionRouter.is_vcr_playing()` as the replay flag; it currently indicates battle animation activity.

Use an explicit request source/mode or equivalent gate so live requests are rejected while replay requests still pass through the same `validate()` and `execute()` path. Add a `SYSTEM` ingress for autonomous transitions (expiry, scheduled phase changes, and similar events); it should construct typed actions and use the same validation/transaction path, not mutate state directly. Keep `LIVE`, `REPLAY`, and `SYSTEM` as orchestration metadata. No gameplay rule, validation result, transaction resolution, RNG choice, or progression branch should depend on which source submitted an otherwise identical action.

## 6. Playback Controller Contract

Suggested controller states:

1. **Load**: validate schema/game version, restore the replay initial state, set replay mode, set the recorded run clock, and start playback with controls at 1x.
2. **Wait for readiness**: wait for the previous action and any scene transition to complete; do not poll only a continuous timer.
3. **Pace**: apply the chosen idle pacing only when the event has a valid recorded delay. Do not count down through a paused recorded run clock.
4. **Dispatch**: create the typed action with `ActionFactory.create_from_dict()` and submit it through `ActionQueue` as a replay-sourced request.
5. **Await completion**: for ordinary actions, wait for completion and destination readiness. For recorded meta-actions, preserve their event order/offset while allowing the queue’s intended meta-action behavior.
6. **Desync / complete**: on parse failure, rejection, or an unexpected state, pause immediately and report file line, action type, rejection reason, and a small logical-state diagnostic. At EOF, emit completion, restore playback speed immediately, and keep the replay input gate active until the spectator exits.

Playback speed uses global `Engine.time_scale`, while recorded `SetCombatSpeedAction`s continue to control the selected combat visuals through `AnimationConstants.speed_factor`. Global time scaling affects timers, tweens, and other processing too. Do not claim speed parity until recorded actions produce the same logical outcomes at each supported speed and the prior `Engine.time_scale` / animation speed are restored on exit, error, and completion.

## 7. Suggested Code Layout

Match the repository’s existing `scripts/` layout and use `.gd` files:

```text
scripts/
└── engine/
    ├── recorder/
    │   ├── GameplayRecorder.gd
    │   └── NarrativeLogWriter.gd
    └── replay/
        ├── ReplayController.gd
        └── ReplayReader.gd
scenes/
└── ui/
    ├── ReplayBrowser.tscn
    ├── ReplayBrowser.gd
    ├── ReplayViewer.tscn
    └── ReplayViewer.gd
```

### ReplayViewer Presentation & Control Specification
- **Minimalist Spectator Overlay:** No top/bottom bars, scrubber sliders, or on-screen playback control buttons.
- **Spectator Input Blocker:** Full-screen transparent overlay (`mouse_filter = STOP`) prevents clicks from interacting with the underlying game scene during playback.
- **Discreet Action Indicator:** Positioned in the top-right corner, displaying `Action #<N>`. Automatically updates whenever an action begins execution.
- **Tab Key:** Toggles visibility of the action indicator on and off.
- **Esc Key:** Pauses playback and opens a centered modal dialog with options to "Resume Playback" or "Exit to Title Screen" (also shown on completion or error).
- **Speed Controls (Keys 1 to 0):** Speed is controlled exclusively via the number row and numpad keys `1` through `0` (`1` = 1x, `2` = 2x, ..., `9` = 9x, `0` = 10x).

The recorder should observe accepted queue actions plus queued presentation events and own file I/O. Add a `ReplayStateRegistry` that names and serializes all state in the fidelity contract, and a development-only mutation guard that rejects authoritative writes without an active action transaction (including system-origin actions). Instrument transaction IDs and causal event IDs so legitimate effects (for example, damage and death caused by `EndTurnAction`) remain one causal action result instead of becoming arbitrary extra player actions. The replay controller should own parsing, startup, event scheduling, and replay mode. The viewer should own spectator controls and its visual input blocker. Put save/telemetry suppression behind shell adapters, not game-rule branches. Keep file I/O out of `GameAction.execute()` methods.

## 8. Verification and Readiness Gates

The current schema 3 implementation includes recorder startup/flushes, action events, replay-only input gating, initial-state restoration, Continue handling, pause/speed controls, desync reporting, and cleanup. These features do not establish the revised outcome-focused contract. Before relying on deterministic playback, verify:

1. A normal run and its replay match canonical gameplay state, flow/input availability, gameplay RNG state, and explicit interface-event order at every checkpoint.
2. Continue works from both an up-to-date save and a save that predates later recorded actions; playback should restore the checkpoint and then continue.
3. Scene/modal handoffs, flashcard answer timing, and meta-actions during a busy visual action do not dispatch early or deadlock.
4. Playback at 1x, 2x, 4x, and 8x produces the same gameplay outcomes and preserves legal input order; exit/error/completion restore engine timing, tutorial settings, timer state, and input isolation as described above.
5. A recording write failure leaves the live action accepted and the game state unchanged; malformed/truncated files show a useful error.

These runtime checks have not been run. The implementation uses `ActionQueue` completion as its ordinary-action boundary; if any scene transition completes after that signal, add an explicit readiness contract before treating playback as reliable. Static diff/parse checks do not replace these runtime comparisons.

## 9. Definition of Done

1. Every accepted action is stored as a valid JSON line, flushed, and reconstructs through `ActionFactory`.
2. Replays restore the captured initial state and reproduce the outcome-focused contract under the same build/content fingerprint.
3. The next outcome-verified format preserves its checkpoint across Continue. Existing schema 3 files remain action-only and must be labeled reduced-coverage or rejected for verified outcome replay; older files remain untouched.
4. All replay dispatches use `ActionQueue`; rejected actions produce a pause and actionable line-numbered diagnostic.
5. Live gameplay input cannot affect a replay, while viewer controls and replay-sourced actions work.
6. Pause/speed behavior and timing semantics are explicit and match the selected fidelity promise.
7. Replay exit restores timer, speed, tutorial, and manager state. Completion and desync restore playback speed immediately and retain the replay input gate until the spectator exits.
8. `GameAction` payloads contain no volatile engine references or node trees; presentation metadata (such as discrete `interaction_type` and `drop_pos` recorded only at the moment of drop) is strictly serializable, stable, and normalized.
9. Every gameplay mutation and explicit replay-relevant input has an audited source: player action, interface action, or system-origin consequence. No unclassified timer, signal, callback, scene setup, UI handler, gameplay RNG draw, or mutable field can affect replay outcomes or input availability.

## 10. Interaction Modality & Presentation Parity (Mouse & Touch)

### 10.1 Pointer Input Unification
To guarantee identical behavior across PC and mobile / touch platforms without streaming continuous pointer coordinates every frame:
* All pointer inputs (`InputEventMouseButton`, `InputEventMouseMotion`, `InputEventScreenTouch`, `InputEventScreenDrag`) are routed through `InputUtils` and tracked centrally in `GlobalInteractionRouter._input()`.
* Drag operations are tracked locally in UI view components during input drafting (`_is_dragging`, deformation physics, rubber-toy spring simulation) without generating actions per frame.
* Touch gestures (short tap, tap-and-tap, touch drag, and touch long-press peek) map to the exact same semantic interactions as desktop mouse interactions (single click, click-and-click, mouse drag, and mouse hover).

### 10.2 Drag-and-Drop vs. Tap/Click Distinction
Certain game visual effects (such as coin animations, bounce feedback, and cancelled drag snap-backs) originate from where an item was dropped rather than its home slot:
* When an action is committed via drag-and-drop (mouse or touch drag), the action (`MoveInventoryAction`, `BuyShopAction`, `CollectRewardAction`, `SellRewardAction`, `RemoveBlackMarketAction`, `TransformBlackMarketAction`, `StartTrainingAction`, `CancelDragAction`) records:
  * `interaction_type`: `"DRAG"`
  * `drop_pos`: `Vector2` (captured at the drop target coordinates)
* When committed via click-and-click or tap-and-tap, the action records:
  * `interaction_type`: `"CLICK"`
  * `drop_pos`: `Vector2.ZERO`
* During replay playback, the view executes identical visual choreography: if `interaction_type == "DRAG"` and `drop_pos != Vector2.ZERO`, the animation originates from `drop_pos`; if `interaction_type == "CLICK"`, it originates from the source slot center.

### 10.3 Decoupled State Verification Hash
`GameManager.get_replay_state_snapshot()` strictly verifies pure authoritative simulation data (`run_state`, `rng_state`, `temporary_shop`, `temporary_rewards`, `rest_site_prizes`, `director_run_state`, `encounter_director_run_state`, `tutorial_state`, `flashcard_state`, `battle_state`).
* Presentation UI trees (`content_scene`, `modal_stack`, `is_inventory_open`, `run_timer_running`) are completely excluded from state digests.
* This ensures that 100% deterministic simulation parity is asserted without false divergence alarms caused by sub-frame animation settling, asynchronous transition delays, or layout rendering jitter.

