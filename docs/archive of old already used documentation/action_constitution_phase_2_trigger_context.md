# Phase 2 Execution Plan: Strongly Typed `TriggerContext` Migration

**Master Roadmap:** [action_constitution_execution_roadmap.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/action_constitution_execution_roadmap.md)  
**Constitutional Spec:** [Action_Constitution_v1_Flashcard_Heroes.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/Action_Constitution_v1_Flashcard_Heroes.md) (Sections 4 and 9 — Phase 2)  
**Prerequisite:** Phase 1 `Complete`  
**Assigned Model:** `Gemini 3.8 Flash (High)`

## Phase Goal & Safety Guarantee

Eliminate every untyped `context: Dictionary` passed through `AbilityResolver.process_trigger`, `TargetResolver.resolve_target`, `TargetResolver.evaluate_conditions`, `EffectRequest`, `EffectHandlers`, `StatScaling`, and all **76 `EffectDefinition` subclasses**, replacing them with a strongly typed `TriggerContext` (`RefCounted`) object — while keeping `res://tests/run_fast_suite.tscn` **100% compiling and green at the end of every single Task Card** with **zero defensive code or duck typing**.

| Task | Assigned Model | Focus | Status |
| :--- | :--- | :--- | :---: |
| **2.1** | **Gemini 3.8 Flash (High)** | Author `scripts/battle/TriggerContext.gd` with Complete Pre-Verified Schema & `-1` Sentinels | `Complete` |
| **2.2** | **Gemini 3.8 Flash (High)** | Migrate Resolvers, `EffectRequest`, `EffectHandlers`, `BattleManager`, `CombatSimulator` & `run_fast_suite.gd` | `Complete` |
| **2.3** | **Gemini 3.8 Flash (High)** | Migrate `EffectDefinition`, `StatScaling`, `ability_dust_elite_growth.tres` & All 76 `Effect*.gd` Subclasses | `Complete` |

---

## Task 2.1 — Author `scripts/battle/TriggerContext.gd`
**Assigned Model:** `Gemini 3.8 Flash (High)`

### Objective
Create [TriggerContext.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/TriggerContext.gd) (`class_name TriggerContext extends RefCounted`) containing the **100% audited set of typed fields** across all combat, gacha, merge, item, trinket, and trait triggers, plus `duplicate_context() -> TriggerContext`, dynamic scaling helpers for `StatScaling`, and a temporary `to_legacy_dict() -> Dictionary` bridge used **only** during Task 2.2 (and deleted in Task 2.3).

### Pre-Verified Sentinel Invariants (CRITICAL — Do Not Change Defaults!)
Several existing callers distinguish between *"field was explicitly snapshotted in context (even if `0`)"* vs *"field was not set in context (`!context.has(...)`)"*. Using `0` as the default for those fields would silently break math! Use **`-1`** as the explicit unset sentinel on these exact 7 integer fields:
1. `source_pwr: int = -1` — [CombatSimulator.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/CombatSimulator.gd#L505) checks whether `DeathProcessor` snapshotted `source_pwr` before knockout (`request.trigger_context.source_pwr >= 0`).
2. `source_hp: int = -1` — Snapshotted by `CombatSimulator` immediately before `execute()`.
3. `gold_tens: int = -1` — [StatScaling.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/utils/StatScaling.gd#L76-L80) falls back to `int(GameManager.run_state.gold / 10)` when `gold_tens < 0`! Defaulting `gold_tens` to `0` would multiply all gold-scaling buffs by `0`!
4. `tokens_spent: int = -1` — `StatScaling.gd` falls back to `1` when `tokens_spent < 0`, while honoring `0` when a free gacha draw spends `0` tokens!
5. `ally_knocked_out_pwr: int = -1` — [EffectGainDeadAllyPwrAsHP.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/effects/EffectGainDeadAllyPwrAsHP.gd#L25) uses `ally_knocked_out_pwr` when `>= 0` (even if the ally had `0` PWR) and falls back to `dead_ally.current_pwr` when `< 0`.
6. `current_day: int = -1` — [EffectBossSummon.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectBossSummon.gd#L17) uses `current_day` when `> 0` and falls back to `GameManager.run_state.day` otherwise.
7. `damaged_slot_index: int = -1` and `dest_slot: int = -1` — Slot indices where `0` is valid slot 0 and `-1` means unset.

### Exact File to Create: `scripts/battle/TriggerContext.gd`

```gdscript
# res://scripts/battle/TriggerContext.gd
class_name TriggerContext
extends RefCounted

## Strongly typed payload replacing untyped `context: Dictionary` across all trigger
## routing, target/condition resolution, stat scaling, and EffectDefinition execution.

# --- Trigger & Execution Control Metadata ---
var trigger_type: StringName = &""
var trigger_cause: StringName = &""
var cause_id: StringName = &""
var ability_id: StringName = &""
var is_simulation: bool = false
var is_turn_initiated: bool = false
var is_counter: bool = false
var on_attack_already_triggered: bool = false
var attack_replaced: bool = false
var double_strike_executed: bool = false
var team: String = ""
var turn: int = 0
var current_day: int = -1
var gold_tens: int = -1

# --- Source / Actor / Holder Snapshot ---
var source_uuid: String = ""
var source_holder_uuid: String = ""
var source_category: StringName = &""
var source_consumable_id: StringName = &""
var consumable_uuid: String = ""
var source_pwr: int = -1
var source_hp: int = -1
var actor_uuid: String = ""
var triggering_uuid: String = ""

# --- Combat, Damage, Heal & Stat Modification ---
var attacker_uuid: String = ""
var defender_uuid: String = ""
var target_uuid: String = ""
var target_initial_hp: int = 0
var damaged_uuid: String = ""          # Replaces legacy `victim_uuid`
var damaged_team: String = ""          # Replaces legacy `victim_team`
var damaged_current_hp: int = 0        # Replaces legacy `victim_current_hp`
var damaged_category: StringName = &"" # Replaces legacy `victim_category`
var damaged_slot_index: int = -1       # Replaces legacy `victim_slot_index`
var damage_taken: int = 0
var damage_dealt: int = 0
var healed_uuid: String = ""
var healer_uuid: String = ""
var heal_amount: int = 0
var unit_uuid: String = ""
var stat: String = ""
var amount: int = 0
var is_stackable: bool = true
var is_echo: bool = false
var status_id: StringName = &""

# --- Knockout & Prevention (Constitutional Vocabulary) ---
var knocked_out_uuid: String = ""          # Replaces legacy `dying_uuid` and `killed_uuid`
var knocked_out_team: String = ""          # Replaces legacy `dying_team`
var knocked_out_location: LocationIdentifier = null # Replaces legacy `dying_location`
var knocked_out_tier: int = 0              # Replaces legacy `dying_tier`
var knocked_out_definition_id: String = "" # Replaces legacy `dying_definition_id`
var equipped_items: Array[Dictionary] = []
var killer_uuid: String = ""
var ally_knocked_out_uuid: String = ""     # Replaces legacy `fainting_ally_uuid`
var ally_knocked_out_team: String = ""     # Replaces legacy `fainting_ally_team`
var ally_knocked_out_location: LocationIdentifier = null # Replaces legacy `fainting_ally_location`
var ally_knocked_out_pwr: int = -1         # Replaces legacy `fainting_ally_pwr`

# --- Summon, Board, Gacha, Merge & Economy ---
var summoned_uuid: String = ""
var summoned_team: String = ""
var entered_uuid: String = ""
var drawn_uuid: String = ""
var dest_container: StringName = &""
var dest_slot: int = -1
var tier: int = 0
var tokens_spent: int = -1
var merged_uuid: String = ""
var merged_team: String = ""
var merge_container: StringName = &""
var merge_category: StringName = &""
var bounty_target_uuids: Array[String] = []


## Deep-copies all fields for isolated per-request execution in CombatSimulator.
func duplicate_context() -> TriggerContext:
	var copy := TriggerContext.new()
	copy.trigger_type = trigger_type
	copy.trigger_cause = trigger_cause
	copy.cause_id = cause_id
	copy.ability_id = ability_id
	copy.is_simulation = is_simulation
	copy.is_turn_initiated = is_turn_initiated
	copy.is_counter = is_counter
	copy.on_attack_already_triggered = on_attack_already_triggered
	copy.attack_replaced = attack_replaced
	copy.double_strike_executed = double_strike_executed
	copy.team = team
	copy.turn = turn
	copy.current_day = current_day
	copy.gold_tens = gold_tens

	copy.source_uuid = source_uuid
	copy.source_holder_uuid = source_holder_uuid
	copy.source_category = source_category
	copy.source_consumable_id = source_consumable_id
	copy.consumable_uuid = consumable_uuid
	copy.source_pwr = source_pwr
	copy.source_hp = source_hp
	copy.actor_uuid = actor_uuid
	copy.triggering_uuid = triggering_uuid

	copy.attacker_uuid = attacker_uuid
	copy.defender_uuid = defender_uuid
	copy.target_uuid = target_uuid
	copy.target_initial_hp = target_initial_hp
	copy.damaged_uuid = damaged_uuid
	copy.damaged_team = damaged_team
	copy.damaged_current_hp = damaged_current_hp
	copy.damaged_category = damaged_category
	copy.damaged_slot_index = damaged_slot_index
	copy.damage_taken = damage_taken
	copy.damage_dealt = damage_dealt
	copy.healed_uuid = healed_uuid
	copy.healer_uuid = healer_uuid
	copy.heal_amount = heal_amount
	copy.unit_uuid = unit_uuid
	copy.stat = stat
	copy.amount = amount
	copy.is_stackable = is_stackable
	copy.is_echo = is_echo
	copy.status_id = status_id

	copy.knocked_out_uuid = knocked_out_uuid
	copy.knocked_out_team = knocked_out_team
	copy.knocked_out_location = knocked_out_location
	copy.knocked_out_tier = knocked_out_tier
	copy.knocked_out_definition_id = knocked_out_definition_id
	copy.equipped_items = equipped_items.duplicate(true)
	copy.killer_uuid = killer_uuid
	copy.ally_knocked_out_uuid = ally_knocked_out_uuid
	copy.ally_knocked_out_team = ally_knocked_out_team
	copy.ally_knocked_out_location = ally_knocked_out_location
	copy.ally_knocked_out_pwr = ally_knocked_out_pwr

	copy.summoned_uuid = summoned_uuid
	copy.summoned_team = summoned_team
	copy.entered_uuid = entered_uuid
	copy.drawn_uuid = drawn_uuid
	copy.dest_container = dest_container
	copy.dest_slot = dest_slot
	copy.tier = tier
	copy.tokens_spent = tokens_spent
	copy.merged_uuid = merged_uuid
	copy.merged_team = merged_team
	copy.merge_container = merge_container
	copy.merge_category = merge_category
	copy.bounty_target_uuids = bounty_target_uuids.duplicate()
	return copy


## Used by StatScaling for data-driven `.tres` scaling keys (`context_multiplier_key` / `scaling_context_key`).
## Fails fast via `assert` if an unknown key is ever authored in a resource.
func has_scaling_value(key: String) -> bool:
	match key:
		"gold_tens":
			return gold_tens >= 0
		"tokens_spent":
			return tokens_spent >= 0
		"damage_dealt", "damage_taken", "heal_amount", "amount", "knocked_out_tier", "tier", "turn":
			return true
		"current_day":
			return current_day > 0
		"source_pwr":
			return source_pwr >= 0
		"source_hp":
			return source_hp >= 0
		_:
			assert(false, "TriggerContext.has_scaling_value: unknown scaling key '%s'" % key)
			return false


func get_scaling_value(key: String) -> int:
	match key:
		"gold_tens":
			return maxi(0, gold_tens)
		"tokens_spent":
			return maxi(0, tokens_spent)
		"damage_dealt":
			return damage_dealt
		"damage_taken":
			return damage_taken
		"heal_amount":
			return heal_amount
		"amount":
			return amount
		"knocked_out_tier":
			return knocked_out_tier
		"tier":
			return tier
		"turn":
			return turn
		"current_day":
			return maxi(1, current_day)
		"source_pwr":
			return maxi(0, source_pwr)
		"source_hp":
			return maxi(0, source_hp)
		_:
			assert(false, "TriggerContext.get_scaling_value: unknown scaling key '%s'" % key)
			return 0
```

Also add a **temporary** `to_legacy_dict() -> Dictionary` method at the bottom of `TriggerContext.gd` (exporting both new and legacy keys such as `"dying_uuid": knocked_out_uuid`, `"victim_uuid": damaged_uuid`, `"fainting_ally_uuid": ally_knocked_out_uuid`, `"killed_uuid": knocked_out_uuid`, and only setting `"gold_tens"`, `"tokens_spent"`, `"fainting_ally_pwr"`, `"current_day"`, `"source_pwr"` when `>= 0`). Mark it `# TEMPORARY FOR TASK 2.2 ONLY — DELETE IN TASK 2.3` so Task 2.2 compiles and passes 100% cleanly before Task 2.3 migrates the 76 `EffectDefinition` subclasses.

### Mandatory Verification Command
```zsh
.agents/skills/verify-headless/scripts/run_headless.sh --import --quit && \
.agents/skills/verify-headless/scripts/run_headless.sh res://tests/run_fast_suite.tscn
```

### Ready-to-Run Prompt (`Gemini 3.8 Flash (High)`)
> Execute **Task 2.1** from `docs/action_constitution_phase_2_trigger_context.md`. Create `scripts/battle/TriggerContext.gd` with the exact typed fields, `-1` sentinels, `duplicate_context()`, scaling helpers, and the temporary `to_legacy_dict()` bridge for Task 2.2. Run the Mandatory Verification Command and mark Task 2.1 `Complete`.

---

## Task 2.2 — Migrate Engine & Resolver Backbone to `TriggerContext` [Complete]
**Assigned Model:** `Gemini 3.8 Flash (High)`

### Objective
Switch `AbilityResolver.process_trigger`, `TargetResolver.resolve_target`, `TargetResolver.evaluate_conditions`, `EffectRequest`, `EffectHandlers`, `BattleManager`, `CombatSimulator`, `DeathProcessor`, `TurnAbilities`, `BattleHelpers`, `DamageCommand`, `InventoryManager`, and `tests/run_fast_suite.gd` to construct and pass `TriggerContext` everywhere, while `CombatSimulator.gd:512` calls `sim_ctx.to_legacy_dict()` for one turn until Task 2.3 migrates `EffectDefinition.execute`.

### Pre-Verified Complete List of Callers (Zero Missing Files!)
Every single caller of `process_trigger`, `resolve_target`, `evaluate_conditions`, and `EffectRequest.new` across the entire repository is in these **14** files:

1. **[EffectRequest.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectRequest.gd)**:
   - Change `var trigger_context: Dictionary` -> `var trigger_context: TriggerContext`.
   - Change `_init(..., p_context: TriggerContext = null, ...)` (`trigger_context = p_context if p_context != null else TriggerContext.new()`).
2. **[AbilityResolver.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/AbilityResolver.gd)**:
   - Change `process_trigger(trigger: StringName, context: TriggerContext = null) -> void` (`if context == null: context = TriggerContext.new()`, `context.trigger_type = trigger`).
   - Update `_should_unit_respond`, `_should_item_respond`, `_should_trinket_respond`, and `_activate_ability` to read typed `TriggerContext` properties directly (`context.knocked_out_uuid`, `context.ally_knocked_out_uuid`, `context.damaged_uuid`, `context.damaged_team`, `context.attacker_uuid`, `context.defender_uuid`, `context.summoned_team`, `context.merged_team`, `context.team`, etc.).
   - Line ~495: `var effect_context: TriggerContext = context.duplicate_context()`, `if ability.id.contains("counter"): effect_context.is_counter = true`.
   - Line ~517: `if ability_activated and ability.replaces_basic_attack and context.trigger_type == C.TRIGGER_WHEN_ATTACKING: context.attack_replaced = true`.
3. **[TargetResolver.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/TargetResolver.gd)**:
   - Change `resolve_target(source_uuid: String, target_type: StringName, context: TriggerContext, battle_manager: Node) -> Array[String]` and `evaluate_conditions(conditions: Array[ConditionDefinition], source_uuid: String, context: TriggerContext, battle_manager: Node) -> bool` (plus all private helper signatures in `TargetResolver.gd`).
   - Replace every `context.get(...)` with typed fields:
     - `victim_uuid` -> `context.damaged_uuid`, `victim_slot_index` -> `context.damaged_slot_index`
     - `dying_uuid` / `killed_uuid` -> `context.knocked_out_uuid`, `dying_team` -> `context.knocked_out_team`, `dying_location` -> `context.knocked_out_location`, `dying_definition_id` -> `context.knocked_out_definition_id`
     - `fainting_ally_uuid` -> `context.ally_knocked_out_uuid`, `fainting_ally_location` -> `context.ally_knocked_out_location`
     - `attacker_uuid`, `defender_uuid`, `target_uuid`, `target_initial_hp`, `healed_uuid`, `entered_uuid`, `drawn_uuid`, `merged_uuid`, `summoned_uuid`, `trigger_cause`, `cause_id`, `is_turn_initiated`, `team`, `source_holder_uuid`, etc.
4. **[EffectHandlers.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/EffectHandlers.gd)**:
   - Read `request.trigger_context` via typed fields at lines ~200, ~253–254, ~469, ~855–878 (`request.trigger_context.knocked_out_uuid`, `request.trigger_context.knocked_out_location`, `request.trigger_context.ally_knocked_out_location`, `request.trigger_context.team`, `request.trigger_context.ability_id`, etc.) and line ~977.
5. **[TurnAbilities.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/TurnAbilities.gd)**:
   - Construct `TriggerContext.new()` in every `trigger_*` helper (`trigger_on_hurt` sets `ctx.damaged_uuid`, `ctx.damaged_team`, `ctx.damaged_current_hp`, `ctx.damaged_category`, `ctx.damaged_slot_index`, `ctx.damage_taken`, `ctx.attacker_uuid`, `ctx.trigger_cause`, `ctx.status_id`; `trigger_on_kill` sets `ctx.killer_uuid` and `ctx.knocked_out_uuid`; etc.).
6. **[DeathProcessor.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/DeathProcessor.gd)**:
   - Construct `TriggerContext.new()` for all `WHEN_KNOCKED_OUT`, `BEFORE_BEING_KNOCKED_OUT`, `WHEN_ALLY_KNOCKED_OUT`, `WHEN_ANY_UNIT_KNOCKED_OUT`, `ON_BOARD_STATE_CHANGED`, and `ON_BOUNTY_CLAIMED` triggers (`ctx.knocked_out_uuid`, `ctx.knocked_out_team`, `ctx.knocked_out_location`, `ctx.knocked_out_tier`, `ctx.knocked_out_definition_id`, `ctx.equipped_items`, `ctx.source_pwr = unit.current_pwr`, `ctx.ally_knocked_out_uuid`, `ctx.ally_knocked_out_team`, `ctx.ally_knocked_out_location`, `ctx.ally_knocked_out_pwr`, `ctx.bounty_target_uuids`).
7. **[BattleHelpers.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/BattleHelpers.gd#L263)** & **[DamageCommand.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/commands/DamageCommand.gd#L45-L55)**:
   - Construct `TriggerContext.new()` for `TRIGGER_INTERCEPT_ATTACK` and `TRIGGER_BEFORE_TAKING_DAMAGE`.
8. **[CombatSimulator.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/CombatSimulator.gd)**:
   - Lines ~277 & ~700: Pass `TriggerContext.new()` to `AbilityResolver.process_trigger(...)`.
   - Lines ~480–512:
     ```gdscript
     var sim_ctx: TriggerContext = request.trigger_context.duplicate_context()
     sim_ctx.is_simulation = true
     sim_ctx.ability_id = request.ability_id
     # ... populate sim_ctx.source_category, sim_ctx.source_holder_uuid ...
     if is_instance_valid(stat_provider):
         if sim_ctx.source_category == &"":
             sim_ctx.source_category = stat_provider.get_definition().category if is_instance_valid(stat_provider.get_definition()) else &""
         sim_ctx.source_holder_uuid = stat_provider.equipped_on_uuid if sim_ctx.source_category == &"ITEM" else ""
         if stat_provider.current_hp <= 0 and request.trigger_context.source_pwr >= 0:
             sim_ctx.source_pwr = request.trigger_context.source_pwr
         else:
             sim_ctx.source_pwr = stat_provider.current_pwr
         sim_ctx.source_hp = stat_provider.current_hp
     var legacy_ctx: Dictionary = sim_ctx.to_legacy_dict()
     var res: EffectResult = request.effect_definition.execute(request.source_uuid, exec_targets, bm, legacy_ctx)
     if legacy_ctx.get("double_strike_executed", false):
         request.trigger_context.double_strike_executed = true
     ```
9. **[BattleManager.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BattleManager.gd)**:
   - Update `resolve_target(source_uuid: String, target_type: StringName, context: TriggerContext = null) -> Array[String]`.
   - Convert all `AbilityResolver.process_trigger(...)` and `EffectRequest.new(...)` call sites in `BattleManager.gd` to construct `TriggerContext.new()` (note line ~1670 checks `if context.attack_replaced:`).
10. **[InventoryManager.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/InventoryManager.gd#L232-L247)**:
    - Construct `var trig_context := TriggerContext.new()` (`source_category`, `source_holder_uuid`, `source_consumable_id`, `consumable_uuid`) and pass it to `EffectRequest.new(...)`.
11. **The 4 Effect Scripts That Call `process_trigger` / `resolve_target` / `EffectRequest.new` Directly** (update ONLY those inner calls in Task 2.2; their `func execute(..., context: Dictionary)` signature updates in Task 2.3):
    - [BasicAttackEffect.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BasicAttackEffect.gd#L43-L72) (`attack_context := TriggerContext.new()` and `before_attack_context := TriggerContext.new()`)
    - [EffectRetriggerTurnAttack.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectRetriggerTurnAttack.gd#L41-L85) (`TargetResolver.resolve_target`, `double_strike_context := TriggerContext.new()`, `if double_strike_context.attack_replaced:`, `EffectRequest.new(...)` — do **not** add `.has_method(` on line 35!)
    - [EffectCascadeAOE.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectCascadeAOE.gd#L93-L101) (`before_attack_context := TriggerContext.new()`)
    - [EffectDeathDamageHighestEnemy.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectDeathDamageHighestEnemy.gd#L25-L30) (`var target_ctx := TriggerContext.new(); target_ctx.team = dying_team`)
12. **[run_fast_suite.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/tests/run_fast_suite.gd#L281-L326)**:
    - Update lines `281–282` and `324–325` from `{}` to `TriggerContext.new()`.

### Mandatory Verification Command
```zsh
.agents/skills/verify-headless/scripts/run_headless.sh res://tests/run_fast_suite.tscn
```

### Ready-to-Run Prompt (`Gemini 3.8 Flash (High)`)
> Execute **Task 2.2** from `docs/action_constitution_phase_2_trigger_context.md`. Migrate all 14 listed files so `AbilityResolver`, `TargetResolver`, `EffectRequest`, `EffectHandlers`, `BattleManager`, `CombatSimulator`, `DeathProcessor`, `TurnAbilities`, `BattleHelpers`, `DamageCommand`, `InventoryManager`, and `tests/run_fast_suite.gd` use `TriggerContext` directly (keeping `sim_ctx.to_legacy_dict()` at `CombatSimulator.gd:512` until Task 2.3). Obey `pre_write_guard.py` (never add `has_method`, `SignalBus`, `get_tree`, or `await` in `scripts/battle/`). Run the Mandatory Verification Command and mark Task 2.2 `Complete`.

---

## Task 2.3 — Migrate `EffectDefinition`, `StatScaling`, `ability_dust_elite_growth.tres` & All 76 `Effect*.gd` Subclasses [Complete]
**Assigned Model:** `Gemini 3.8 Flash (High)`

### Objective
Complete Phase 2 by changing `EffectDefinition.execute(..., _context: TriggerContext)` and `StatScaling.calculate(..., context: TriggerContext)`, updating `ability_dust_elite_growth.tres`, migrating all **76 concrete `EffectDefinition` subclasses** to read typed `TriggerContext` properties, switching `CombatSimulator.gd:512` to pass `sim_ctx` directly, and **deleting `to_legacy_dict()` from `TriggerContext.gd`**.

### Pre-Verified Architecture Facts (Why All 76 Must Switch Together)
- In Godot 4 GDScript, every subclass overriding `EffectDefinition.execute(...)` **must match the exact parameter types of `EffectDefinition.execute(...)`**. Splitting the 76 subclasses across multiple turns would fail Godot compilation on `stop_verify_gate.py`.
- Out of the **76** `EffectDefinition` subclasses (`28` in `scripts/`, `1` in `scripts/abilities/`, `47` in `scripts/effects/`):
  - **58 subclasses** only read uniform metadata (`is_simulation`, `team`, `ability_id`, `trigger_type`, `source_pwr`, `source_holder_uuid`, `actor_uuid`, `heal_amount`, `summoned_uuid`, `merged_uuid`, `drawn_uuid`, `tier`) or pass `context` to `StatScaling.calculate(...)`.
  - **18 subclasses** read combat/knockout/hurt/economy-specific fields or mutate flags (`BasicAttackEffect.gd`, `EffectBossSummon.gd`, `EffectBuffDrawnUnit.gd`, `EffectBuffHighLevelUnit.gd`, `EffectCounterAttack.gd`, `EffectDeathDamageHighestEnemy.gd`, `EffectDeathTokenRefund.gd`, `EffectDuplicateToGacha.gd`, `EffectGainDeadAllyPwrAsHP.gd`, `EffectGainGold.gd`, `EffectModifyStat.gd`, `EffectPreventLethal.gd`, `EffectPurifyHeal.gd`, `EffectRepeatAdjacentBuff.gd`, `EffectResurrectFirstKilledUnit.gd`, `EffectRetriggerTurnAttack.gd`, `EffectSpendGold.gd`, `EffectSummonOnDeath.gd`, `EffectSummonT2OnDeath.gd`, `EffectTransferItemBehind.gd`).

### Exact Steps

1. **Update [EffectDefinition.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectDefinition.gd#L37)**:
   ```gdscript
   func execute(_source_uuid: String, _targets: Array[String], _battle_manager: Node, _context: TriggerContext) -> EffectResult:
       return EffectResult.empty()
   ```
2. **Update [StatScaling.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/utils/StatScaling.gd)**:
   - Change `calculate(param: Variant, context: TriggerContext, script_name: String = "StatScaling") -> int` and `_calculate_scaled(param_dict: Dictionary, context: TriggerContext, script_name: String) -> int`.
   - Read `var source_pwr: int = maxi(0, context.source_pwr)` and `var source_hp: int = maxi(0, context.source_hp)`.
   - For `multiplier_key`:
     ```gdscript
     if not multiplier_key.is_empty():
         var mult_val: int = 1
         if context.has_scaling_value(multiplier_key):
             mult_val = context.get_scaling_value(multiplier_key)
         elif multiplier_key == "gold_tens":
             mult_val = int(GameManager.run_state.gold / 10) if is_instance_valid(GameManager.run_state) else 0
         final_value *= float(mult_val)
     ```
   - For `scaling_key`:
     ```gdscript
     if not scaling_key.is_empty():
         var scale_val: int = context.get_scaling_value(scaling_key) if context.has_scaling_value(scaling_key) else 0
         final_value += float(scale_val) * scaling_multiplier
     ```
3. **Update [ability_dust_elite_growth.tres](file:///Users/danhh/Desktop/Flashcard%20Heroes/resources/abilities/ability_dust_elite_growth.tres#L13-L24)**:
   - Replace both occurrences of `"scaling_context_key": "dying_tier"` with `"scaling_context_key": "knocked_out_tier"`.
4. **Transform Signatures & Uniform Boilerplate Across All 76 `Effect*.gd` Files (`scratch/migrate_effects_phase2.py`)**:
   Write a temporary Python script in `scratch/migrate_effects_phase2.py` to:
   - Replace `func execute\(([^)]*?),\s*(_?context)\s*:\s*Dictionary\)` -> `func execute(\1, \2: TriggerContext)` across all 76 `EffectDefinition` subclasses (`scripts/BasicAttackEffect.gd`, `scripts/Effect*.gd` excluding `EffectDefinition.gd`/`EffectRequest.gd`/`EffectInspectionWindow.gd`, `scripts/abilities/EffectScald.gd`, and `scripts/effects/Effect*.gd`).
   - Replace uniform boilerplate expressions cleanly (`ctx.get("is_simulation", false)` -> `ctx.is_simulation`, `ctx.get("team", "")` -> `ctx.team`, `ctx.get("team", "PLAYER")` -> `(ctx.team if not ctx.team.is_empty() else "PLAYER")`, `ctx.get("ability_id", <default>)` -> `(ctx.ability_id if ctx.ability_id != &"" else <default>)`, `ctx.get("trigger_type", <default>)` -> `(ctx.trigger_type if ctx.trigger_type != &"" else <default>)`, `ctx.get("summoned_uuid", "")` -> `ctx.summoned_uuid`, `ctx.get("merged_uuid", "")` -> `ctx.merged_uuid`, `ctx.get("drawn_uuid", "")` -> `ctx.drawn_uuid`, `ctx.get("source_uuid", "")` -> `ctx.source_uuid`, `ctx.get("source_holder_uuid", "")` -> `ctx.source_holder_uuid`, `ctx.get("source_category", &"")` -> `ctx.source_category`, `ctx.get("source_consumable_id", &"")` -> `ctx.source_consumable_id`, `ctx.get("actor_uuid", "")` -> `ctx.actor_uuid`, `ctx.get("heal_amount", 0)` -> `ctx.heal_amount`, `ctx.get("tier", 0)` -> `ctx.tier`, `ctx.get("source_pwr", 0)` -> `maxi(0, ctx.source_pwr)`, `ctx.get("source_pwr", 1)` -> `(ctx.source_pwr if ctx.source_pwr >= 0 else 1)`).
5. **Apply Explicit Custom Field Mappings to the Remaining Custom `Effect*.gd` Files**:
   Inspect and cleanly update every remaining `context.get(...)` / `context.has(...)` / `context[...]` in:
   - [BasicAttackEffect.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BasicAttackEffect.gd): `_context.trigger_cause`, `_context.on_attack_already_triggered`
   - [EffectBossSummon.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectBossSummon.gd): Replace lines 17–25 with `if context.current_day > 0: current_day = context.current_day elif is_instance_valid(GameManager) and is_instance_valid(GameManager.run_state): current_day = GameManager.run_state.day` (also removing the dead `battle_manager.has_method("get_current_day")` branch!)
   - [EffectCounterAttack.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/effects/EffectCounterAttack.gd): `var attacker_uuid: String = context.attacker_uuid`, `var pwr: int = context.source_pwr if context.source_pwr >= 0 else source_instance.current_pwr`
   - [EffectDeathDamageHighestEnemy.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectDeathDamageHighestEnemy.gd): `context.knocked_out_uuid`, `context.knocked_out_location`, `context.knocked_out_team`
   - [EffectDeathTokenRefund.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectDeathTokenRefund.gd): `context.ally_knocked_out_team` (fallback `context.knocked_out_team`), `context.ally_knocked_out_uuid` (fallback `context.knocked_out_uuid`)
   - [EffectDuplicateToGacha.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/effects/EffectDuplicateToGacha.gd): `context.knocked_out_uuid` (fallback `source_uuid`), `context.knocked_out_team`, `context.equipped_items`
   - [EffectGainDeadAllyPwrAsHP.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/effects/EffectGainDeadAllyPwrAsHP.gd): `context.ally_knocked_out_uuid`, `if context.ally_knocked_out_pwr >= 0: current_pwr = context.ally_knocked_out_pwr`
   - [EffectGainGold.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectGainGold.gd): `context.knocked_out_uuid`, `context.source_holder_uuid`
   - [EffectPreventLethal.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectPreventLethal.gd): `context.damaged_uuid`, `context.damaged_team`, `(context.damaged_current_hp if context.damaged_uuid != "" else 1)`, `context.damaged_category`, `context.team`
   - [EffectPurifyHeal.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/effects/EffectPurifyHeal.gd): `context.trigger_cause`, `context.status_id`, `context.team`, `context.damaged_team`, `context.damaged_uuid`
   - [EffectRepeatAdjacentBuff.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/effects/EffectRepeatAdjacentBuff.gd): `context.is_stackable`, `context.is_echo`, `context.stat`, `context.amount`
   - [EffectResurrectFirstKilledUnit.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectResurrectFirstKilledUnit.gd): `context.ally_knocked_out_team`, `context.ally_knocked_out_location`, `context.ally_knocked_out_uuid`
   - [EffectRetriggerTurnAttack.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectRetriggerTurnAttack.gd): `if _context.double_strike_executed: return EffectResult.empty()`, `_context.double_strike_executed = true` (and propagate back to `request.trigger_context.double_strike_executed = sim_ctx.double_strike_executed` in `CombatSimulator.gd`!)
   - [EffectSpendGold.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/effects/EffectSpendGold.gd): `if not context.source_holder_uuid.is_empty():`
   - [EffectSummonOnDeath.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectSummonOnDeath.gd), [EffectSummonT2OnDeath.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectSummonT2OnDeath.gd), and [EffectTransferItemBehind.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectTransferItemBehind.gd): `context.knocked_out_location`, `context.knocked_out_uuid`, `context.knocked_out_team`, `context.equipped_items`
   - [EffectTwinCharmScaling.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/effects/EffectTwinCharmScaling.gd): `context.team if not context.team.is_empty() else _get_team_for_instance(source, battle_manager)`
6. **Finalize [CombatSimulator.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/CombatSimulator.gd#L512) & [TriggerContext.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/TriggerContext.gd)**:
   - In `CombatSimulator.gd:512`, call `request.effect_definition.execute(request.source_uuid, exec_targets, bm, sim_ctx)` directly and sync `if sim_ctx.double_strike_executed: request.trigger_context.double_strike_executed = true`.
   - Delete `to_legacy_dict()` from `TriggerContext.gd`.
   - Delete `scratch/migrate_effects_phase2.py`.

### Mandatory Verification Command
```zsh
.agents/skills/verify-headless/scripts/run_headless.sh res://tests/run_fast_suite.tscn && \
! grep -rn --exclude="EffectInspectionWindow.gd" "context: Dictionary\|_context: Dictionary\|to_legacy_dict\|dying_uuid\|fainting_ally_uuid\|victim_uuid\|dying_tier" scripts/EffectDefinition.gd scripts/BasicAttackEffect.gd scripts/Effect*.gd scripts/effects/ scripts/abilities/ scripts/battle/ scripts/AbilityResolver.gd scripts/utils/StatScaling.gd resources/abilities/ability_dust_elite_growth.tres && \
echo "PASS: Phase 2 TriggerContext migration 100% verified"
```

### Ready-to-Run Prompt (`Gemini 3.8 Flash (High)`)
> Execute **Task 2.3** from `docs/action_constitution_phase_2_trigger_context.md`. Update `EffectDefinition.gd`, `StatScaling.gd`, `ability_dust_elite_growth.tres`, and all 76 `EffectDefinition` subclasses to use `TriggerContext` directly, switch `CombatSimulator.gd:512` to pass `sim_ctx`, delete `to_legacy_dict()` from `TriggerContext.gd`, delete any `scratch/` script before finishing, run the Mandatory Verification Command, and mark Phase 2 `Complete` in both `docs/action_constitution_phase_2_trigger_context.md` and `docs/action_constitution_execution_roadmap.md`.

