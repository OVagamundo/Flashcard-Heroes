# Implementation Specification: Encounter System & Banner Trinket Architecture Refactor

**Status:** Canonical Implementation Specification (Ready for Execution)  
**Authoritative Design References:**  
- [EncounterSystem.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/EncounterSystem.md)  
- [Encounter_Synergies_and_Pairs_Reference.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/Encounter_Synergies_and_Pairs_Reference.md)  
- [AGENTS.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/AGENTS.md)  

---

## 0. Architectural Laws & Non-Negotiable Constraints

Every developer or AI agent executing this plan **MUST** obey these core architectural laws without exception:

1. **Fail-Fast Law (Zero Defensive Code):**
   - **NEVER** write defensive masks or duck-typing guards (`if has_method(...)`, `if SignalBus.has_signal(...)`, `if is_instance_valid(self)`, `if "property" in obj` when the type is known).
   - Use strict static typing (`var x: Type = ...`), typed arrays (`Array[StringName]`, `Array[Dictionary]`), typed dictionaries, and explicit `assert()` invariants.
   - Broken contracts must fail immediately with an actionable stack trace.
2. **No Symptom Patching:**
   - Do not use `set_meta` / `get_meta` on resources to smuggle combat or encounter state (`current_day`, `elite_stat_scale`, `elite_boss_id`). Define explicit typed properties on [`EncounterDefinition`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EncounterDefinition.gd).
3. **Data ↔ Presentation Decoupling:**
   - Simulation and Data domains (`EncounterGenerator`, `EncounterDefinition`, `RunState`, `BattleState`, `BattleSetup`, `GachaBallInstance`, `EffectDefinition`) must **never** reference UI nodes, `BattleAnimator`, `SlotView`, shaders, or `Audio`.
   - Every mid-combat mutation (summons, stat buffs, heals, status applications, slot ignitions) must emit canonical `CombatEvent`s with `CombatPayload`s so `BattleAnimator` plays them back deterministically.
4. **Seeded PRNG Stream Isolation:**
   - Pre-battle map node generation and initial encounter drafting in `EncounterGenerator` **must** use `RNGManager.map_rng`.
   - Mid-combat reinforcement drafting and in-combat boss/elite abilities **must** use `RNGManager.combat_rng`.
   - **Never** call global `randf()`, `randi()`, or `Array.pick_random()`.
5. **Trinket Economy & Cap Invariants:**
   - Player and Enemy Trinket bars remain capped at **9 slots** (`Constants.PLAYER_TRINKET_CAP = 9`, `Constants.ENEMY_TRINKET_CAP = 9`).
   - Shops **never** offer Trinkets (Trinkets are exclusive to Elite and Boss reward scenes).
   - Enemy teams **never** receive free auto-injected `trinket_trait_*` crests; enemies only hold their 0-Gold **Banner Trinket** plus any **5-Gold Secondary Trinkets** explicitly purchased by their Banner's budget engine (or granted innately by `trinket_banner_toughmon`).
6. **Asset Dimensional & Palette Strictness:**
   - All new sprites (Units, Items, Trinkets) **must be strictly 64x64 pixels** (`(64, 64)` PNG).
   - Must strictly adhere to the authentic 19-color PICO-8 / extended palette matching the 4 Tier 1 Universal Base Units (`Tier1AirUnit.png`, `Tier1EarthUnit.png`, `Tier1FireUnit.png`, `Tier1WaterUnit.png`):
     `#000000`, `#1d2b53`, `#7e2553`, `#008751`, `#ab5236`, `#5f574f`, `#c2c3c7`, `#fff1e8`, `#ff004d`, `#ffa300`, `#ffec27`, `#00e436`, `#29adff`, `#83769c`, `#ff77a8`, `#ffccaa`, `#00ffff`, `#ff00ff`, `#1b001a`.
   - Primary sprite assets are authored and saved under `assets/PixelArt/sprites/` (`units/`, `trinkets/`, `items/`).
7. **Zero Legacy Artifact Retention:**
   - All obsolete legacy bosses (`Boss1..5.tres`), obsolete dust elites (`Tier1..3DustEliteUnit.tres`), their deprecated abilities, obsolete summon scripts, and old generator test remnants **must be completely removed from the project** to prevent developer and agent confusion.

---

## 1. Phase 1: Existing Resource & Schema Reconciliation

### 1.1 Existing Unit & Trinket `.tres` Fixes
Fix the following flags in existing resource files so all 25 Universal Neutral Base Units and all Secondary Trinkets in [`Encounter_Synergies_and_Pairs_Reference.md`](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/Encounter_Synergies_and_Pairs_Reference.md) are valid for enemy drafting:

| File Path | Resource `id` | Property Change | Reason |
| :--- | :--- | :--- | :--- |
| [resources/units/EWAASpePlaApp.tres](file:///Users/danhh/Desktop/Flashcard%20Heroes/resources/units/EWAASpePlaApp.tres) | `&"EWAASpeApp"` (Sojikun) | `is_player_exclusive = true` $\rightarrow$ `false` | Base Neutral T3 unit used in enemy synergy pairs. |
| [resources/units/FWAASupToy.tres](file:///Users/danhh/Desktop/Flashcard%20Heroes/resources/units/FWAASupToy.tres) | `&"FWAASpeToy"` (Wind-up-kun) | `is_player_exclusive = true` $\rightarrow$ `false` | Base Neutral T3 unit used in enemy synergy pairs. |
| [resources/units/WATnkPlaAni.tres](file:///Users/danhh/Desktop/Flashcard%20Heroes/resources/units/WATnkPlaAni.tres) | `&"WATnkAni"` (Soliwhale) | `min_day = 10` $\rightarrow$ `min_day = 1` | Required on Day 1+ for `trinket_banner_lone_whale`. |
| [resources/trinkets/trinket_trait_specialist.tres](file:///Users/danhh/Desktop/Flashcard%20Heroes/resources/trinkets/trinket_trait_specialist.tres) | `&"trinket_trait_specialist"` | `is_player_exclusive = true` $\rightarrow$ `false` | Voted on by Specialist units in enemy encounters. |
| [resources/trinkets/trinket_twin_charm.tres](file:///Users/danhh/Desktop/Flashcard%20Heroes/resources/trinkets/trinket_twin_charm.tres) | `&"trinket_twin_charm"` | `is_player_exclusive = true` $\rightarrow$ `false` | Voted on by `EFWASpeFod` (BubbleGunger) in enemy encounters. |

### 1.2 [`TrinketDefinition.gd`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/TrinketDefinition.gd) Valuation & Banner Flag
Update `scripts/TrinketDefinition.gd`:
1. Change `const DEFAULT_TRINKET_COST: int = 10` to `const DEFAULT_TRINKET_COST: int = 5` (all Secondary Trinkets cost **5 Gold** in encounter generation).
2. Add `@export var is_banner: bool = false`.
3. Update the `cost` getter:
   ```gdscript
   var cost: int:
       get:
           return 0 if is_banner else DEFAULT_TRINKET_COST
   ```
4. Every Banner Trinket (`trinket_banner_*`) must set both `is_banner = true` and `is_enemy_exclusive = true` (which automatically excludes Banner Trinkets from `Database.get_eligible_trinkets_for_reward()`).

### 1.3 [`EncounterDefinition.gd`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EncounterDefinition.gd) Schema Upgrade
Add explicit, strongly-typed properties to `scripts/EncounterDefinition.gd` and eliminate all `set_meta` usage:
```gdscript
## Authoritative Banner Trinket ID governing this encounter
@export var banner_trinket_id: StringName = &""

## Selected Boss or Elite unit ID (empty for Regular encounters)
@export var boss_or_elite_unit_id: StringName = &""

## Calendar day and Daily Budget (B) when this encounter was generated
@export var encounter_day: int = 1
@export var daily_budget: int = 3
```
Each dictionary in `enemy_placements: Array[Dictionary]` **must** follow this exact schema:
```gdscript
{
    "id": StringName,              # Unit definition ID
    "position": int,               # Lineup slot index (0..4)
    "level": int,                  # Unit level (1, 2, or 3)
    "items": Array[StringName],    # Equipped item definition IDs (max 1)
    "bonus_hp": int,               # Extra HP from Stat Overflow or Boss/Elite dynamic scaling
    "bonus_pwr": int               # Extra PWR from Stat Overflow or Boss/Elite dynamic scaling
}
```

### 1.4 [`GachaBallInstance.gd`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/GachaBallInstance.gd) Leveling & Encounter Stat Helpers
Currently, `EffectHandlers.gd:972` calls `new_unit.level_up()`, which does not exist on `GachaBallInstance` and will crash whenever a summoned unit has `level > 1`. Add these two authoritative methods to `scripts/GachaBallInstance.gd`:

```gdscript
## Sets this unit's level (1..3) and updates its persistent LEVEL_BONUS StatComponent (+1/+1 per level above 1).
func set_unit_level(target_level: int) -> void:
	assert(target_level >= 1 and target_level <= 3, "GachaBallInstance.set_unit_level: invalid level %d" % target_level)
	self.level = target_level
	var level_delta_bonus: int = target_level - 1
	if level_delta_bonus > 0:
		add_or_update_stat_component(
			&"level_bonus",
			&"LEVEL_BONUS",
			"level_scaling",
			level_delta_bonus,
			level_delta_bonus,
			false,
			"Level Bonus",
			"Stat bonus from unit level"
		)
	reset_battle_stats_silent()

func level_up() -> void:
	if self.level < 3:
		set_unit_level(self.level + 1)

## Applies persistent encounter stat overflow or dynamic Boss/Elite budget scaling.
func apply_encounter_stat_bonus(bonus_hp: int, bonus_pwr: int) -> void:
	if bonus_hp == 0 and bonus_pwr == 0:
		return
	add_or_update_stat_component(
		&"encounter_scaling",
		&"ENCOUNTER_SCALING",
		"encounter_budget",
		bonus_hp,
		bonus_pwr,
		false,
		"Encounter Scaling",
		"Bonus stats from encounter budget scaling"
	)
	reset_battle_stats_silent()
```

### 1.5 [`BattleSetup.gd`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/BattleSetup.gd), [`BattleManager.gd`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BattleManager.gd), & [`EffectHandlers.gd`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/EffectHandlers.gd) Cleanup
1. **Remove Free Auto-Injected Trait Crests:**
   - Delete `_append_required_trait_trinkets` and `_accumulate_trait_souls` from `scripts/EncounterGenerator.gd` (`L370, 383–427`).
   - Delete `_append_missing_enemy_trait_trinkets` and `_accumulate_trait_souls` from `scripts/battle/BattleSetup.gd` (`L275, 289–339`).
2. **Remove Broken `elite_stat_scale` (0.33 Stat Shrinking):**
   - Remove `elite_stat_scale` metadata reads/writes from `EncounterGenerator.gd:134`, `BattleSetup.gd:207–212, 239–247`, and `BattleManager.gd:3781–3785`.
3. **Wire `level`, `bonus_hp`, and `bonus_pwr` into Enemy Setup & Entrance:**
   - In `BattleSetup.stage_enemy_lineup`: copy `"level": int(placement.get("level", 1))`, `"bonus_hp": int(placement.get("bonus_hp", 0))`, and `"bonus_pwr": int(placement.get("bonus_pwr", 0))` into `state.staged_enemy_placements`.
   - In both `BattleSetup.setup_enemy_lineup` (`L235–247`) and `BattleManager.execute_enemy_entrance_sequence` (`L3778–3785`):
     ```gdscript
     var enemy_inst := GachaBallInstance.new()
     enemy_inst.initialize(unit_def)
     var unit_level: int = int(placement.get("level", 1))
     if unit_level > 1:
         enemy_inst.set_unit_level(unit_level)
     var b_hp: int = int(placement.get("bonus_hp", 0))
     var b_pwr: int = int(placement.get("bonus_pwr", 0))
     if b_hp != 0 or b_pwr != 0:
         enemy_inst.apply_encounter_stat_bonus(b_hp, b_pwr)
     ```
4. **Targeted Slot Support in `EffectHandlers.handle_summon_units` (`L958–974`):**
   - If `summon_data.has("slot")`: check if `int(summon_data["slot"])` is between `0` and `4`, is empty in `target_container`, and is not in `filled_slots`. If valid, use `int(summon_data["slot"])`; otherwise fall back to `find_best_summon_slot(...)`.
   - If `summon_data.has("bonus_hp") or summon_data.has("bonus_pwr")`: call `new_unit.apply_encounter_stat_bonus(int(summon_data.get("bonus_hp", 0)), int(summon_data.get("bonus_pwr", 0)))`.

---

## 2. Phase 2: Encounter Selection & Unified Pity System

### 2.1 Unified Decay Weight Formula (Regular Banners, Elites, and Bosses)
All three encounter categories—**Regular Banners** (3 options), **Elite Banners** (2 options), and **Boss Banners** (3 options)—use the same unified weighted selection algorithm on `RNGManager.map_rng`:
- Every option in a category starts at **Base Weight = `100.0`**.
- Each time an option is selected in a run, its selection count increments in `RunState`.
- Weight formula for option $i$ with run count $C_i$:
  $$W_i = \frac{100.0}{1.0 + (C_i \times 2.0)} \times \begin{cases} 0.20 & \text{if } i == \text{last\_selected\_id} \\ 1.00 & \text{otherwise} \end{cases}$$
- **Why `0.20` instead of `0.0` for `last_selected_id`:**
  - Keeps back-to-back repeats rare (~4%–16% depending on prior counts) without forcing deterministic `A -> B -> A -> B` alternation when only 2 Elites (`Slimeblob` and `Burnie`) exist.

### 2.2 [`RunState.gd`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/RunState.gd) Tracking Properties
Ensure `RunState.gd` persists (in `to_save_dict()` and `from_save_dict()`, and resets in `reset()`):
- `regular_banner_history: Dictionary = {}` (`StringName -> int`) and `last_regular_banner_id: StringName = &""`
- `elite_encounter_history: Dictionary = {}` (`StringName -> int`) and `last_elite_id: StringName = &""`
- `boss_encounter_history: Dictionary = {}` (`StringName -> int`) and `last_boss_id: StringName = &""`

### 2.3 Elite Quota in [`GameManager.gd`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/GameManager.gd)
- In `GameManager.gd:1162–1167`:
  - Keep `MAX_TIER_ELITES: int = 4`.
  - Update `MAX_RUN_ELITES: int = 12` (per `EncounterSystem.md` §3.2).
  - Keep `Constants.PLAYER_TRINKET_CAP = 9` and `Constants.ENEMY_TRINKET_CAP = 9`.

---

## 3. Phase 3: The Modular Synergy Pairs & Trinket Voting Data Registry

Create a new, pure-data static registry class `scripts/systems/EncounterSynergyRegistry.gd` (`class_name EncounterSynergyRegistry extends RefCounted`) that encodes the exact tables from [`docs/Encounter_Synergies_and_Pairs_Reference.md`](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/Encounter_Synergies_and_Pairs_Reference.md).

### 3.1 Unit Synergy Metadata Schema
`EncounterSynergyRegistry.UNIT_PROFILES` maps each of the 25 Neutral Base Unit IDs (`StringName`) to its exact positional and equipment rules:

```gdscript
const UNIT_PROFILES: Dictionary = {
	# ==================== TIER 1 (Cost 1G) ====================
	&"ETnkPla": { # Stumpling
		"preferred_slots": [0, 1],
		"mandatory_front": false,
		"mandatory_behind": false,
		"front_partners": [&"ASpeFod", &"EMPTY"],
		"behind_partners": [&"WSupAni", &"FWFigFod", &"ASpeFod", &"FFigMec", &"FASpeApp", &"EEFWSupPla", &"EFFWSpeApp", &"EWAASpeApp"],
		"items": [&"item_t1_a", &"item_t2_c", &"item_t3_a"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_plant", &"trinket_trait_tank", &"trinket_purifying_pendant"],
		"slot_0_trinket_votes": [&"trinket_spiked_armor"]
	},
	&"FFigMec": { # Vulcannon
		"preferred_slots": [0, 3, 4],
		"mandatory_front": false,
		"mandatory_behind": false,
		"front_partners": [&"ASpeFod", &"ETnkPla", &"EFTnkMec", &"FFWASupMec", &"FWFigFod", &"WSupAni", &"EMPTY"],
		"behind_partners": [&"WSupAni", &"EWFigCos"],
		"items": [&"item_t1_b", &"item_t2_b", &"item_t3_b"],
		"trinket_votes": [&"trinket_trait_fire", &"trinket_trait_mecha", &"trinket_trait_fighter", &"trinket_vengeance"]
	},
	&"WSupAni": { # Ripplepup (NEVER place in Slot 0!)
		"preferred_slots": [1, 2, 3],
		"forbidden_slots": [0],
		"mandatory_front": true,
		"mandatory_behind": false,
		"front_partners": [&"EFTnkMec", &"ETnkPla", &"FFigMec", &"EFWATnkApp", &"EWFigCos", &"FASpeApp"],
		"behind_partners": [&"FWFigFod", &"ASpeFod", &"FFigMec"],
		"items": [&"item_t1_a", &"item_t2_a", &"item_t3_a"],
		"trinket_votes": [&"trinket_trait_water", &"trinket_trait_animal", &"trinket_trait_support", &"trinket_vengeance"]
	},
	&"ASpeFod": { # Puffcorn
		"preferred_slots": [0, 3, 4],
		"mandatory_front": false,
		"mandatory_behind_if_slot_0": true,
		"front_partners": [&"EMPTY", &"ETnkPla", &"EFTnkMec", &"ASpeFod", &"FWFigFod", &"WSupAni"],
		"behind_partners": [&"FFigMec", &"EWFigCos", &"EFTnkMec", &"ETnkPla", &"EASupToy", &"FASpeApp", &"ASpeFod"],
		"items": [&"item_t1_b", &"item_t3_e"],
		"trinket_votes": [&"trinket_trait_air", &"trinket_trait_food", &"trinket_trait_specialist", &"trinket_vengeance"]
	},
	# ==================== TIER 2 (Cost 2G) ====================
	&"EWFigCos": { # Bogmantle
		"preferred_slots": [1, 2, 3],
		"front_partners": [&"ASpeFod", &"EASupToy", &"EFAASupToy", &"FFigMec", &"EEFWSupPla", &"FFWASupMec"],
		"behind_partners": [&"FWWATnkFod", &"WSupAni"],
		"items": [&"item_t2_b", &"item_t3_c", &"item_t1_b"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_water", &"trinket_trait_fighter", &"trinket_trait_costume", &"trinket_vengeance", &"trinket_soul_echo"]
	},
	&"FASpeApp": { # Furnair
		"preferred_slots": [2, 3],
		"front_partners": [&"ETnkPla", &"EFTnkMec", &"ASpeFod"],
		"behind_partners": [&"WSupAni", &"EFWAFigMec"],
		"items": [&"item_t1_b", &"item_t2_b", &"item_t3_b"],
		"trinket_votes": [&"trinket_trait_fire", &"trinket_trait_air", &"trinket_trait_specialist", &"trinket_trait_appliance"]
	},
	&"EASupToy": { # Matryodust
		"preferred_slots": [0, 1],
		"front_partners": [&"EMPTY", &"ASpeFod"],
		"behind_partners": [&"EWFigCos", &"EFFASupMec"],
		"items": [&"item_t2_a", &"item_t3_e", &"item_t1_a"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_air", &"trinket_trait_support", &"trinket_trait_toy", &"trinket_vengeance"]
	},
	&"WATnkAni": { # Soliwhale (Pairs with empty space in front or behind!)
		"preferred_slots": [0], # Highest priority at Slot 0, but valid in any slot with empty adjacent neighbor(s)
		"forbidden_slots": [], # Allowed in any slot that has an empty neighbor (front or behind)
		"front_partners": [&"EMPTY"],
		"behind_partners": [&"EMPTY"],
		"items": [&"item_t2_c", &"item_t3_b", &"item_t3_c", &"item_t3_d", &"item_t1_a"],
		"trinket_votes": [&"trinket_underdog_emblem", &"trinket_spiked_armor", &"trinket_polished_plate", &"trinket_aegis", &"trinket_rusty_ring"]
	},
	&"EFTnkMec": { # Branblee
		"preferred_slots": [0, 1],
		"front_partners": [&"ASpeFod", &"EMPTY"],
		"behind_partners": [&"WSupAni", &"FWFigFod", &"FFigMec", &"ASpeFod", &"FASpeApp", &"EEFASpeCos", &"EEFWSupPla", &"EEWAFigAni", &"EFFWSpeApp", &"EFWASpeFod", &"EFWWFigCos", &"EWWATnkToy", &"FWAASpeToy", &"EWAASpeApp"],
		"items": [&"item_t1_a", &"item_t2_c", &"item_t3_b"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_fire", &"trinket_trait_tank", &"trinket_trait_mecha", &"trinket_spiked_armor", &"trinket_polished_plate"]
	},
	&"FWFigFod": { # Pepspray
		"preferred_slots": [2, 3],
		"front_partners": [&"ETnkPla", &"WSupAni", &"EFTnkMec"],
		"behind_partners": [&"ASpeFod", &"FFigMec"],
		"items": [&"item_t1_a", &"item_t3_c"],
		"trinket_votes": [&"trinket_trait_fire", &"trinket_trait_water", &"trinket_trait_fighter", &"trinket_trait_food"]
	},
	# ==================== TIER 3 (Cost 4G) ====================
	&"EEFASpeCos": { # Mimicloak
		"preferred_slots": [0, 1, 2],
		"front_partners": [&"EFTnkMec", &"EWWATnkToy", &"EMPTY"],
		"behind_partners": [&"EWAASpeApp"],
		"items": [&"item_t2_b", &"item_t1_b", &"item_t3_b"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_fire", &"trinket_trait_air", &"trinket_trait_specialist", &"trinket_trait_costume"]
	},
	&"EEFWSupPla": { # Oakbark
		"preferred_slots": [1, 2],
		"forbidden_slots": [0, 3, 4],
		"front_partners": [&"ETnkPla", &"EFTnkMec"],
		"behind_partners": [&"FWWATnkFod", &"EWFigCos"],
		"items": [&"item_t1_a", &"item_t2_c", &"item_t3_a"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_fire", &"trinket_trait_water", &"trinket_trait_support", &"trinket_trait_plant", &"trinket_armor_aura"]
	},
	&"EEWAFigAni": { # Griffoam
		"preferred_slots": [2, 3, 4],
		"front_partners": [&"EFTnkMec", &"EFWATnkApp", &"EWWATnkToy"],
		"behind_partners": [&"EFWAFigMec"],
		"items": [&"item_t1_b", &"item_t2_b", &"item_t3_f"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_water", &"trinket_trait_air", &"trinket_trait_fighter", &"trinket_trait_animal"]
	},
	&"EFAASupToy": { # Matryoshkan
		"preferred_slots": [0, 1],
		"front_partners": [&"EMPTY"],
		"behind_partners": [&"EWFigCos", &"EFFASupMec"],
		"items": [&"item_t2_a", &"item_t3_e", &"item_t2_c"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_fire", &"trinket_trait_air", &"trinket_trait_support", &"trinket_trait_toy", &"trinket_vengeance"]
	},
	&"EFFASupMec": { # Mechamom
		"preferred_slots": [3, 4],
		"front_partners": [&"EASupToy", &"EFAASupToy"],
		"behind_partners": [&"EFWAFigMec"],
		"items": [&"item_t1_a", &"item_t2_a"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_fire", &"trinket_trait_air", &"trinket_trait_support", &"trinket_trait_mecha"]
	},
	&"EFFWSpeApp": { # Blendroid
		"preferred_slots": [1, 2],
		"front_partners": [&"ETnkPla", &"EFTnkMec"],
		"behind_partners": [&"FWWATnkFod"],
		"items": [&"item_t2_b", &"item_t3_b", &"item_t3_c"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_fire", &"trinket_trait_water", &"trinket_trait_specialist", &"trinket_trait_appliance"]
	},
	&"EFWAFigMec": { # Pachinkannon
		"preferred_slots": [3, 4],
		"forbidden_slots": [0, 1, 2],
		"front_partners": [&"EWWATnkToy", &"EFWATnkApp", &"EEWAFigAni", &"EFFASupMec", &"FASpeApp"],
		"behind_partners": [&"EMPTY"],
		"items": [&"item_t3_f", &"item_t2_b", &"item_t1_b"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_fire", &"trinket_trait_water", &"trinket_trait_air", &"trinket_trait_fighter", &"trinket_trait_mecha"]
	},
	&"EFWASpeFod": { # BubbleGunger
		"preferred_slots": [1, 2, 3],
		"front_partners": [&"EFWASpeFod", &"EFTnkMec"],
		"behind_partners": [&"EFWASpeFod"],
		"items": [&"item_t1_b", &"item_t2_b", &"item_t3_b"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_fire", &"trinket_trait_water", &"trinket_trait_air", &"trinket_trait_specialist", &"trinket_trait_food", &"trinket_twin_charm"]
	},
	&"EFWATnkApp": { # Reizokun
		"preferred_slots": [0],
		"front_partners": [&"EMPTY"],
		"behind_partners": [&"WSupAni", &"EWWATnkToy", &"EFWWFigCos", &"EEWAFigAni", &"EFWAFigMec", &"FWAASpeToy", &"EWAASpeApp"],
		"items": [&"item_t2_c", &"item_t3_b", &"item_t1_a"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_fire", &"trinket_trait_water", &"trinket_trait_air", &"trinket_trait_tank", &"trinket_spiked_armor", &"trinket_polished_plate"]
	},
	&"EFWWFigCos": { # Tsunamantle
		"preferred_slots": [1, 2],
		"front_partners": [&"FFWASupMec", &"EFWATnkApp", &"EFTnkMec", &"EWWATnkToy"],
		"behind_partners": [&"FWWATnkFod"],
		"items": [&"item_t2_b", &"item_t3_b", &"item_t1_b"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_fire", &"trinket_trait_water", &"trinket_trait_fighter", &"trinket_trait_costume"]
	},
	&"EWAASpeApp": { # Sojikun
		"preferred_slots": [2, 3],
		"front_partners": [&"EEFASpeCos", &"ETnkPla", &"EFTnkMec", &"EFWATnkApp", &"EWWATnkToy"],
		"behind_partners": [&"EMPTY"],
		"items": [&"item_t1_b", &"item_t3_c", &"item_t3_f"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_water", &"trinket_trait_air", &"trinket_trait_specialist", &"trinket_trait_appliance"]
	},
	&"EWWATnkToy": { # Komatop
		"preferred_slots": [1, 2],
		"front_partners": [&"EFWATnkApp", &"EFTnkMec"],
		"behind_partners": [&"EFWAFigMec", &"EFWWFigCos", &"EEFASpeCos", &"EEWAFigAni", &"EWAASpeApp"],
		"items": [&"item_t2_c", &"item_t3_b", &"item_t1_a"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_water", &"trinket_trait_air", &"trinket_trait_tank", &"trinket_trait_toy", &"trinket_aegis", &"trinket_polished_plate"]
	},
	&"FFWASupMec": { # Relaytron
		"preferred_slots": [0, 1],
		"mandatory_behind": true,
		"front_partners": [&"EMPTY"],
		"behind_partners": [&"EFWWFigCos", &"EWFigCos", &"FFigMec"],
		"items": [&"item_t2_b", &"item_t3_b", &"item_t3_c"],
		"trinket_votes": [&"trinket_trait_fire", &"trinket_trait_water", &"trinket_trait_air", &"trinket_trait_support", &"trinket_trait_mecha", &"trinket_vengeance"]
	},
	&"FWAASpeToy": { # Wind-up-kun
		"preferred_slots": [1],
		"front_partners": [&"EFTnkMec", &"EFWATnkApp"],
		"behind_partners": [&"FWWATnkFod"],
		"items": [&"item_t2_b", &"item_t3_c", &"item_t1_b"],
		"trinket_votes": [&"trinket_trait_fire", &"trinket_trait_water", &"trinket_trait_air", &"trinket_trait_specialist", &"trinket_trait_toy"]
	},
	&"FWWATnkFod": { # Nuton
		"preferred_slots": [2],
		"front_partners": [&"EEFWSupPla", &"EWFigCos", &"EFFWSpeApp", &"EFWWFigCos", &"FWAASpeToy"],
		"behind_partners": [&"EMPTY"],
		"items": [&"item_t1_a", &"item_t2_c", &"item_t3_b"],
		"trinket_votes": [&"trinket_trait_fire", &"trinket_trait_water", &"trinket_trait_air", &"trinket_trait_tank", &"trinket_trait_food", &"trinket_armor_aura"]
	}
}
```
> [!IMPORTANT]
> **Authoritative Soliwhale Rule (Confirmed by User):**  
> `&"WATnkAni"` (Soliwhale) is **NOT** restricted to Lone Whale or Toughmon — it **IS** a valid draft candidate in general encounters whenever empty slot(s) will be present adjacent to it (in front of or behind it).  
> Soliwhale's synergy "partners" are literally empty slots (`&"EMPTY"`), reflecting its solitary passive (`ability_solitary` / empty slot stat scaling).  
> In pair scoring and formation drafting, Soliwhale pairs with empty space (e.g., `[&"EMPTY", &"WATnkAni"]` or `[&"WATnkAni", &"EMPTY"]`). Whenever an encounter has fewer than 5 units (e.g., Days 1–7 with 1–4 units, or Lone Whale / Swarms with deliberate gaps), Soliwhale can be drafted into any slot where its adjacent neighbor(s) remain empty.

### 3.2 Adjacent Pair Scoring & Best-Fit Slot Evaluation
Provide helper methods on `EncounterSynergyRegistry`:
1. `is_valid_slot_for_unit(unit_id: StringName, slot: int, board: Dictionary) -> bool`:
   - Rejects if `slot` is in `forbidden_slots`.
   - Rejects if `mandatory_front` is true and `slot == 0`.
   - Rejects if `mandatory_behind` (or `mandatory_behind_if_slot_0` when `slot == 0`) is true and `slot == 4`.
   - **Soliwhale Solitary Guard:** If `unit_id == &"WATnkAni"`, rejects if both `slot - 1` (when `slot > 0`) and `slot + 1` (when `slot < 4`) are already occupied by units on `board` (Soliwhale requires at least one adjacent empty slot in front or behind to function).
2. `score_unit_in_slot(unit_id: StringName, slot: int, board: Dictionary, active_trinket_ids: Array[StringName]) -> float`:
   - Base weight = `10.0` if `slot in preferred_slots` else `3.0`.
   - Check `front_neighbor = board.get(slot - 1, &"")`:
     - If `slot == 0` or `front_neighbor == &""`:
       - If `&"EMPTY" in profile.front_partners`: `+25.0` (Rewards units like Soliwhale that thrive with empty space in front!).
     - Else (`front_neighbor != &""`):
       - If `front_neighbor in profile.front_partners`: `+25.0`.
       - If `unit_id in get_behind_partners(front_neighbor)`: `+25.0`.
   - Check `behind_neighbor = board.get(slot + 1, &"")`:
     - If `slot == 4` or `behind_neighbor == &""`:
       - If `&"EMPTY" in profile.behind_partners`: `+25.0` (Rewards units like Soliwhale that thrive with empty space behind!).
     - Else (`behind_neighbor != &""`):
       - If `behind_neighbor in profile.behind_partners`: `+25.0`.
       - If `unit_id in get_front_partners(behind_neighbor)`: `+25.0`.
   - **Bidirectional Trinket Weighting (`EncounterSystem.md` §4.2 / §5.2.3):**
     - For each active secondary trinket in `active_trinket_ids`: if `trinket_id in profile.trinket_votes`, multiply total weight by **`3.0`**.
3. `select_best_voted_trinket(board: Dictionary, owned_trinkets: Array[StringName], rng: SeededRNG) -> StringName`:
   - Tallies 1 vote for each `trinket_id` in `profile.trinket_votes` for every unit on `board` (plus `slot_0_trinket_votes` if that unit is in Slot 0), excluding any trinket already in `owned_trinkets`.
   - For Trait Crests (`trinket_trait_*`), also verify the board has at least 2 matching trait souls/units so a crest is never bought for a single 1-soul unit.
   - Returns the highest-voted eligible 5G secondary trinket (breaking ties with `rng`).

---

## 4. Phase 4: Visual Asset Specifications, Banner Trinkets & Bespoke Content

### 4.0 Visual Asset Specifications & PICO-8 Palette Standards
All sprites authored for this refactor (Units, Trinkets, Items) **must strictly conform** to these visual rules:
1. **Dimensions:** Strictly **64x64 pixels** (`(64, 64)` PNG) with RGBA transparency.
2. **Palette Standard:** Must strictly use colors from the authentic 19-color PICO-8 / extended palette matching the 4 Tier 1 Universal Base Units (`Tier1AirUnit.png`, `Tier1EarthUnit.png`, `Tier1FireUnit.png`, `Tier1WaterUnit.png`):
   - `#000000` — Deep Black (outlines, eye pupils, base drop shadows)
   - `#1d2b53` — Dark Navy Blue (deep water shading, mecha joints, cool shadows)
   - `#7e2553` — Dark Plum / Wine (arcane shading, costume accents)
   - `#008751` — Dark Forest Green (plant foliage shadows, deep moss)
   - `#ab5236` — Earthy Rust / Brown (bark, soil, wood, animal fur)
   - `#5f574f` — Dark Neutral Grey (stone, steel, mechanical chassis)
   - `#c2c3c7` — Light Neutral Grey (metallic highlights, blades, appliance bodies)
   - `#fff1e8` — Light Warm Cream / White (specular glints, teeth, light fur)
   - `#ff004d` — Vibrant Fire Red (core flame, danger signals, hot cores)
   - `#ffa300` — Bright Flame Orange (fire gradients, warm accents)
   - `#ffec27` — Pure Sun Yellow (sparks, lightning, golden trims, fire crests)
   - `#00e436` — Vibrant Leaf Green (living plant sprouts, acid, slime glows)
   - `#29adff` — Bright Cyan-Blue (water currents, glass, crystal energy)
   - `#83769c` — Soft Lavender / Slate (ethereal mist, dust clouds, mystic cloth)
   - `#ff77a8` — Bubblegum Pink (food glazes, gummy creatures, cute cheeks)
   - `#ffccaa` — Soft Peach (organic skin, cooked pastry, warm highlights)
   - `#00ffff` — Pure Cyan Glow (ice runes, plasma, intense elemental auras)
   - `#ff00ff` — Arcane Magenta (magical distortion, mirror gleam, void runes)
   - `#1b001a` — Deep Obsidian (darkest shadows, boss silhouettes)
3. **Style & Readability:**
   - 1-pixel dark outlines (`#000000` or `#1d2b53`).
   - Clean, readable silhouettes at native 1x (64x64) and scaled 2x/4x UI views.
   - Clear elemental and trait iconography (Fire horns/crests, Tank shell plates, Slime translucency).
4. **Target File Locations:**
   - **Units:** `assets/PixelArt/sprites/units/{unit_id}.png`
   - **Trinkets:** `assets/PixelArt/sprites/trinkets/{trinket_id}.png`
   - **Items:** `assets/PixelArt/sprites/items/{item_id}.png`

### 4.1 The 8 Banner Trinkets (`resources/trinkets/trinket_banner_*.tres`)
Create 8 `TrinketDefinition` `.tres` files in `resources/trinkets/`. All 8 must have:
- `category = &"TRINKET"`
- `is_banner = true` (Cost = 0G)
- `is_enemy_exclusive = true`
- `is_player_exclusive = false`

| Resource Filename & `id` | Type | Reinforcements (`at_turn_end`, Odd Turns `1, 3, 5, 7...`) | Ability / Effect Resource | 64x64 PixelArt Sprite Path |
| :--- | :---: | :--- | :--- | :--- |
| `trinket_banner_lone_whale.tres`<br>`&"trinket_banner_lone_whale"` | Regular | **None** (`0.0x`) | None (passive commander blueprint) | `res://assets/PixelArt/sprites/trinkets/trinket_banner_lone_whale.png` |
| `trinket_banner_swarm.tres`<br>`&"trinket_banner_swarm"` | Regular | **33% Daily Budget** (`0.33x`) | `ability_banner_reinforce_swarm.tres` (`EffectBannerReinforce.gd`) | `res://assets/PixelArt/sprites/trinkets/trinket_banner_swarm.png` |
| `trinket_banner_fire_phalanx.tres`<br>`&"trinket_banner_fire_phalanx"` | Regular | **50% Daily Budget** (`0.50x`, Fire/Surprise filter) | `ability_banner_reinforce_fire.tres` (`EffectBannerReinforce.gd`) | `res://assets/PixelArt/sprites/trinkets/trinket_banner_fire_phalanx.png` |
| `trinket_banner_dustmon.tres`<br>`&"trinket_banner_dustmon"` | Boss | **33% Daily Budget** (`0.33x`, low-cost pair fodder) | `ability_banner_reinforce_dustmon.tres` (`EffectBannerReinforce.gd`) | `res://assets/PixelArt/sprites/trinkets/trinket_banner_dustmon.png` |
| `trinket_banner_toughmon.tres`<br>`&"trinket_banner_toughmon"` | Boss | **33% Daily Budget** (`0.33x`, strictly `Tank` units) | `ability_banner_reinforce_toughmon.tres` (`EffectBannerReinforce.gd`) | `res://assets/PixelArt/sprites/trinkets/trinket_banner_toughmon.png` |
| `trinket_banner_doppelkun.tres`<br>`&"trinket_banner_doppelkun"` | Boss | **33% Daily Budget** (`0.33x`, 1 scaled `EEFASpeCos`) | `ability_banner_reinforce_doppelkun.tres` (`EffectBannerReinforce.gd`) | `res://assets/PixelArt/sprites/trinkets/trinket_banner_doppelkun.png` |
| `trinket_banner_slimeblob.tres`<br>`&"trinket_banner_slimeblob"` | Elite | **None** (Driven by Slimeblob's Mitosis & Turn-Start Clock) | None | `res://assets/PixelArt/sprites/trinkets/trinket_banner_slimeblob.png` |
| `trinket_banner_burnie.tres`<br>`&"trinket_banner_burnie"` | Elite | **50% Daily Budget** (`0.50x`, inherits `fire_phalanx` engine) | `ability_banner_reinforce_fire.tres` (`EffectBannerReinforce.gd`) | `res://assets/PixelArt/sprites/trinkets/trinket_banner_burnie.png` |

#### `scripts/effects/EffectBannerReinforce.gd` Specification
Replaces legacy `EffectBossSummon.gd`. Attached to the Banner Trinkets via `trigger = &"at_turn_end"`, `sub_phase = 250` (`C.SubPhase.END_OF_TURN_SUMMON`):
1. **Cadence Guard:** Reads `var turn_num: int = battle_manager._current_turn`. If `turn_num % 2 == 0` (even turn), return `EffectResult.empty()`. (Fires on all odd turns: `1, 3, 5, 7...`).
2. **Board Inspection:** Inspects `EnemyLineup` (`0..4`) to build `current_board: Dictionary` (`slot_idx -> unit_definition_id`) and `empty_slots: Array[int]`. If `empty_slots.is_empty()`, return `EffectResult.empty()`.
3. **Active Secondary Trinkets:** Collects all `inst.definition_id` in `EnemyTrinkets` where `not inst.get_definition().is_banner`.
4. **Delegation to `EncounterGenerator`:** Calls `EncounterGenerator.generate_banner_reinforcements(banner_id, daily_budget, current_board, empty_slots, active_secondary_trinkets, RNGManager.combat_rng)` which returns `Array[Dictionary]` of `{"unit_id": StringName, "slot": int, "level": int, "items": Array[StringName], "bonus_hp": int, "bonus_pwr": int}`.
5. **Return `EffectResult`:** Populates `result.summon_units_request = summon_data` and `result.summon_team = "ENEMY"`.

---

### 4.2 The 3 Boss Units & Abilities (`resources/units/`)

#### Boss 1: Dustmon (`resources/units/BossDustmon.tres`, `id = &"boss_dustmon"`)
- **Icon:** `res://assets/PixelArt/sprites/units/boss_dustmon.png` (64x64 PICO-8 palette).
- **Placement:** Slot 4 (Backline).
- **Base Stats:** `base_hp = 4`, `base_pwr = 3`, `tier = 3`, `tags = [&"BOSS", &"HIDDEN"]`.
- **Dynamic Budget Scaling (applied at Encounter Generation):**
  $$\text{bonus\_hp} = \lfloor B \times 0.4 \rfloor, \quad \text{bonus\_pwr} = \lfloor B \times 0.2 \rfloor$$
- **Abilities:**
  1. `BasicAttack.tres` (Melee).
  2. **Dust Spore Injection (`ability_dustmon_spore_injection.tres`):**
     - `trigger = &"when_ally_knocked_out"`, `sub_phase = 35`.
     - Script `scripts/effects/EffectDustmonSporeInjection.gd`:
       - Checks `BattleInventoryT1`, `BattleInventoryT2`, `BattleInventoryT3`.
       - A machine $T \in \{1, 2, 3\}$ is eligible iff `inventory.find_first_empty_slot() != -1` AND `inventory.get_all_non_empty_uuids().size() >= 1` (contains at least 1 gachaball).
       - Reads `var last_machine: int = source.get_status_effect_amount(&"dustmon_last_machine")`. If `eligible_tiers.size() > 1 and eligible_tiers.has(last_machine)`, removes `last_machine` from candidates so it **never selects the same machine twice in a row**.
       - Picks `chosen_tier` via `RNGManager.combat_rng`, updates `source.add_status_effect_silent(&"dustmon_last_machine", chosen_tier - last_machine)`, and returns `result.summon_request` for `&"unit_dust_t%d" % chosen_tier` into `BattleInventoryT%d`.
  3. **Vampiric Attrition (`ability_dustmon_vampiric_attrition.tres`):**
     - `trigger = &"when_ally_knocked_out"`, `sub_phase = 60`.
     - Script `scripts/effects/EffectDustmonVampiricHeal.gd`:
       - Resolves the knocked-out ally from `context.knocked_out_uuid` (or `context.triggering_uuid`).
       - Reads knocked-out ally's `tier` (`1`, `2`, or `3`) and heals Dustmon for `tier` HP (`1 / 2 / 3 HP`), emitting `CombatEvent.Type.HEAL`.
  4. **Twin Resonance (`ability_dustmon_twin_resonance.tres`):**
     - `trigger = &"on_board_state_changed"` (also triggered by `on_enter_board` / `on_gacha_draw` / `when_any_unit_knocked_out` via `AbilityResolver`), `sub_phase = 64`.
     - Script `scripts/effects/EffectDustmonTwinResonance.gd`:
       - Counts all instances in player containers (`BattleInventoryT1`, `BattleInventoryT2`, `BattleInventoryT3`, `PlayerShelf`, `PlayerLineup`, `DiscardPile`) where `inst.definition_id in [&"unit_dust_t1", &"unit_dust_t2", &"unit_dust_t3"]` and `not battle_manager.is_dead_this_turn(inst.ball_uuid)`.
       - Tracks delta against `source.get_status_effect_amount(&"dustmon_resonance_bonus")` and applies `delta` to Dustmon's PWR (+1 PWR per 1 Dust unit), emitting `CombatEvent.Type.BUFF` / `DEBUFF` exactly like `EffectTwinCharmScaling.gd`.
- **Dust Units (`Tier1DustUnit.tres`, `Tier2DustUnit.tres`, `Tier3DustUnit.tres`):**
  - Attach `ability_dust_enter_board.tres` (`trigger = &"on_enter_board"`, `sub_phase = 64`, script `scripts/effects/EffectDustEnterBoard.gd`):
    - Also invoke `AbilityResolver.process_trigger(C.TRIGGER_ON_ENTER_BOARD, enter_ctx)` in `BattleManager._process_lineup_entry` when a unit moves/swaps from `PlayerShelf` to `PlayerLineup`.
    - In `EffectDustEnterBoard.gd`: Only executes if `source.location_container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP` and `not source.has_tag(&"dust_status_applied")`.
    - Marks `source.add_tag(&"dust_status_applied")` (which is automatically preserved across merges by `MergeManager.gd:97–106` so merging never re-triggers status generation!).
    - Grants `tier` stacks of `burn` (`1 / 2 / 3`) and `tier` stacks of `static` (`1 / 2 / 3`) to `source`, emitting `CombatEvent.Type.STATUS_EFFECT`.

#### Boss 2: Toughmon (`resources/units/BossToughmon.tres`, `id = &"boss_toughmon"`)
- **Icon:** `res://assets/PixelArt/sprites/units/boss_toughmon.png` (64x64 PICO-8 palette).
- **Placement:** Slot 4 (Backline).
- **Base Stats:** `base_hp = 4`, `base_pwr = 1`, `tier = 3`, `tags = [&"BOSS", &"HIDDEN", &"Tank"]`.
- **Dynamic Budget Scaling:**
  $$\text{bonus\_hp} = \lfloor B \times 0.3 \rfloor, \quad \text{bonus\_pwr} = \lfloor B \times 0.1 \rfloor$$
- **Innate Secondary Trinket:** `EncounterGenerator` always adds `&"trinket_trait_tank"` to `encounter.enemy_trinket_ids` at 0 Gold cost.
- **Abilities:**
  1. `BasicAttack.tres` (Melee).
  2. **Self-Preservation Armor & Toughmon's Command (`ability_toughmon_command.tres`):**
     - `trigger = &"at_turn_start"`, `sub_phase = 200`.
     - Script `scripts/effects/EffectToughmonTurnStart.gd`:
       - Queries all living allied units in `EnemyLineup` excluding Toughmon (`ally.ball_uuid != source_uuid and ally.current_hp > 0`).
       - **Self-Preservation Armor:** Grants Toughmon `2 * surviving_allies.size()` Armor.
       - **Toughmon's Command:** Grants every living ally in front of Toughmon (`ally.location_slot_index < source.location_slot_index`) **+2 Armor** and **+1 Spikes**, emitting `CombatEvent.Type.STATUS_EFFECT` events.

#### Boss 3: Doppelkun (`resources/units/BossDoppelkun.tres`, `id = &"boss_doppelkun"`)
- **Icon:** `res://assets/PixelArt/sprites/units/boss_doppelkun.png` (64x64 PICO-8 palette).
- **Placement:** Slot 0 (Frontline).
- **Base Stats:** `base_hp = 4`, `base_pwr = 2`, `tier = 3`, `tags = [&"BOSS", &"HIDDEN"]`.
- **Abilities:**
  1. `BasicAttack.tres` (Melee).
  2. **Heroic Mirror (`ability_doppelkun_heroic_mirror.tres`):**
     - `trigger = &"pre_combat"`, `sub_phase = 98` (`C.SubPhase.PRE_COMBAT_PRIORITY`).
     - Script `scripts/effects/EffectDoppelkunMirror.gd`:
       - Finds the Player's Hero instance in `PlayerLineup` or `PlayerShelf` (`BattleSetup.is_hero_definition(inst.get_definition())`).
       - Calculates `hp_delta = hero_inst.current_hp - source.current_hp` and `pwr_delta = hero_inst.current_pwr - source.current_pwr`.
       - Applies `hp_delta` and `pwr_delta` to Doppelkun via `battle_manager.apply_stat_delta(...)` and emits a `CombatEvent.Type.BUFF` (`CombatPayload.both_stats_change`) so the stat copy animates visibly at Pre-Battle.

---

### 4.3 The 2 Elite Units + Spikeslime Token Unit (`resources/units/`)

#### Token Unit: Spikeslime (`resources/units/UnitSpikeslime.tres`, `id = &"unit_spikeslime"`)
- **Icon:** `res://assets/PixelArt/sprites/units/unit_spikeslime.png` (64x64 PICO-8 palette).
- **Base Stats:** `base_hp = 1`, `base_pwr = 1`, `tier = 1`, `tags = [&"TOKEN", &"HIDDEN", &"Tank"]`.
- **Abilities:**
  1. `BasicAttack.tres` (Melee).
  2. **Innate Spikes (`ability_spikeslime_spikes.tres`):**
     - `trigger = &"on_enter_board"`, `sub_phase = 64`.
     - Script `scripts/effects/EffectSpikeslimeEnter.gd`: If `not source.has_tag(&"spikeslime_initialized")`, adds tag `&"spikeslime_initialized"` and grants `source.level` (`1 / 2 / 3`) stacks of `spikes`.

#### Elite 1: Slimeblob (`resources/units/EliteSlimeblob.tres`, `id = &"elite_slimeblob"`)
- **Icon:** `res://assets/PixelArt/sprites/units/elite_slimeblob.png` (64x64 PICO-8 palette).
- **Placement:** Slot 2 (or Slot 3).
- **Base Stats:** `base_hp = 6`, `base_pwr = 2`, `tier = 3`, `tags = [&"BOSS", &"HIDDEN"]`.
- **Dynamic Budget Scaling:**
  $$\text{bonus\_hp} = \lfloor B \times 0.5 \rfloor, \quad \text{bonus\_pwr} = \lfloor B \times 0.15 \rfloor$$
- **Abilities:**
  1. `BasicAttack.tres` (Melee).
  2. **Reactive Mitosis (`ability_slimeblob_mitosis.tres`):**
     - `trigger = &"when_taking_damage"`, `sub_phase = 61` (`C.SubPhase.ON_DAMAGE_TAKEN`), condition: `NonLethalDamageCondition.tres` (`source.current_hp > 0`).
     - Script `scripts/effects/EffectSlimeblobMitosis.gd`:
       - Checks `source.current_hp > 0` (suppressed on lethal blow).
       - Finds the first empty slot in `EnemyLineup` (`0..4`, front-to-back). If none empty, returns `EffectResult.empty()`.
       - Summons 1 Level 1 `&"unit_spikeslime"` into that slot via `result.summon_units_request`.
  3. **Escalating Evolution Clock (`ability_slimeblob_evolution.tres`):**
     - `trigger = &"at_turn_start"`, `sub_phase = 200`.
     - Script `scripts/effects/EffectSlimeblobEvolution.gd`:
       - Evaluates `EnemyLineup` (`0..4`):
       - **Step 1 (Any slot empty):** Summons a Level 1 `&"unit_spikeslime"` into the frontmost empty slot (`0..4`).
       - **Step 2 (All 5 slots full, any Spikeslime `< Level 3`):** Iterates Slot `0` to `4`, finds the first living `&"unit_spikeslime"` with `inst.level < 3`, increments `inst.level += 1`, grants `+1 HP` and `+1 PWR` via `apply_stat_delta`, and grants `+1 Spikes` (`apply_stat_delta(inst, "spikes_stacks", 1, source_uuid)`), emitting `BUFF` and `STATUS_EFFECT` events.
       - **Step 3 (All 5 slots full and all Spikeslimes are Level 3):** Targets the frontmost Spikeslime (Slot 0, or first living Spikeslime), heals it for **3 HP** (`C.ACTION_HEAL`) and grants it **+2 Spikes**, emitting `HEAL` and `STATUS_EFFECT` events.

#### Elite 2: Burnie (`resources/units/EliteBurnie.tres`, `id = &"elite_burnie"`)
- **Icon:** `res://assets/PixelArt/sprites/units/elite_burnie.png` (64x64 PICO-8 palette).
- **Placement:** Slot 2 (Center of Fire Phalanx).
- **Base Stats:** `base_hp = 4`, `base_pwr = 3`, `tier = 3`, `tags = [&"BOSS", &"HIDDEN", &"SOUL_FIRE", &"SOUL_FIRE", &"SOUL_FIRE", &"SOUL_FIRE", &"Fighter"]` (**4x Fire Souls**).
- **Dynamic Budget Scaling:**
  $$\text{bonus\_hp} = \lfloor B \times 0.4 \rfloor, \quad \text{bonus\_pwr} = \lfloor B \times 0.2 \rfloor$$
- **Abilities:**
  1. **Combustion & Pyre Strike (`ability_burnie_attack.tres`):**
     - Uses `BasicAttackEffect.gd` (`replaces_basic_attack = true`, `trigger = &"basic_attack"`).
     - In `BasicAttackEffect.gd`:
       - **Combustion Strike (`L110`):** Add `or (is_instance_valid(source_instance) and source_instance.definition_id == &"elite_burnie")` to the Fire L4 bonus damage check so Burnie always adds `target_instance.get_status_effect_amount(&"burn")` to its attack `damage` without consuming Burn stacks!
       - **Pyre Strike (Post-Impact Slot Ignition):** In `BasicAttackEffect.gd`, right after `apply_damage` (`L213`), if `is_instance_valid(source_instance) and source_instance.definition_id == &"elite_burnie"` and `is_instance_valid(final_target)`:
         - Look up `target_loc = battle_manager.get_location_for_uuid(final_target.ball_uuid)`.
         - If `target_loc.container == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP` (or `ENEMY_LINEUP`):
           - Check the corresponding `slot_effects` array on `battle_manager._state` (`player_slot_effects` or `enemy_slot_effects`).
           - If `slot_effects[target_loc.index] != &"burn"`:
             - Record `prev_eff = slot_effects[target_loc.index]`.
             - Mutate `slot_effects[target_loc.index] = &"burn"`.
             - Append `CombatEvent.new(CombatEvent.Type.SLOT_EFFECT_CHANGE, {"visual_payload": CombatPayload.slot_effect_change(target_loc.container, target_loc.index, prev_eff, &"burn")})` to `impact_events`!

---

## 5. Phase 5: `EncounterGenerator.gd` Banner Drafting Engines

Refactor `scripts/EncounterGenerator.gd` so every encounter is generated through its authoritative **Banner Trinket Engine**.

### 5.1 Entry Points in `EncounterGenerator.gd`
1. `generate_encounter(daily_budget: int) -> EncounterDefinition`:
   - Uses the Unified Decay Weight Formula (§2.1) on `RNGManager.map_rng` to pick one of `[&"trinket_banner_lone_whale", &"trinket_banner_swarm", &"trinket_banner_fire_phalanx"]` using `run_state.regular_banner_history` and `run_state.last_regular_banner_id`.
   - Updates `run_state.regular_banner_history` and `run_state.last_regular_banner_id`.
   - Generates battlefield slot effects (`_generate_slot_effects`), computing `effective_budget = maxi(1, daily_budget + budget_delta)`.
   - Dispatches to `_draft_lone_whale_banner`, `_draft_swarm_banner`, or `_draft_fire_phalanx_banner`.
2. `generate_elite_encounter(daily_budget: int, history: Dictionary = {}, last_elite_id: StringName = &"") -> EncounterDefinition`:
   - Uses the Unified Decay Weight Formula (§2.1) on `RNGManager.map_rng` to pick between `[&"elite_slimeblob", &"elite_burnie"]`.
   - Generates battlefield slot effects on `support_budget = maxi(1, int(floor(daily_budget * 0.85)) + budget_delta)`.
   - Dispatches to `_draft_slimeblob_banner` or `_draft_burnie_banner`.
3. `generate_boss_encounter(_boss_level: int, daily_budget: int, current_day: int) -> EncounterDefinition`:
   - Uses the Unified Decay Weight Formula (§2.1) on `RNGManager.map_rng` to pick between `[&"boss_dustmon", &"boss_toughmon", &"boss_doppelkun"]` using `run_state.boss_encounter_history` and `run_state.last_boss_id`.
   - Updates `run_state.boss_encounter_history` and `run_state.last_boss_id`.
   - Generates battlefield slot effects on `support_budget = maxi(1, int(floor(daily_budget * 0.85)) + budget_delta)`.
   - Dispatches to `_draft_dustmon_banner`, `_draft_toughmon_banner`, or `_draft_doppelkun_banner`.

### 5.2 Exact Banner Drafting Specifications

#### Engine 1: `_draft_lone_whale_banner(budget: int)` (`trinket_banner_lone_whale`)
- Places `trinket_banner_lone_whale` in `enemy_trinket_ids[0]`.
- Places `&"WATnkAni"` (Soliwhale, base cost 2G) at **Slot 0**, `level = 1`. `remaining = budget - 2` (if `budget < 2`, `remaining = 0`).
- **Step 1 (Level Up):**
  - If `remaining >= 6` (total budget $\ge 8$): upgrade Soliwhale to `level = 3` (`cost += 6`, total unit cost 8G).
  - Else if `remaining >= 2` (total budget $\ge 4$): upgrade Soliwhale to `level = 2` (`cost += 2`, total unit cost 4G).
- **Step 2 (Synergistic Item):**
  - If `remaining >= 4`: equip T3 item from `[&"item_t3_b", &"item_t3_c", &"item_t3_d"]` (`remaining -= 4`).
  - Else if `remaining >= 2`: equip `&"item_t2_c"` (Anvil, `remaining -= 2`).
  - Else if `remaining >= 1`: equip `&"item_t1_a"` (Candy, `remaining -= 1`).
- **Step 3 (Secondary Trinket - 5G):**
  - While `remaining >= 5` and `enemy_trinket_ids.size() < MAX_TRINKETS`: pick an unowned trinket from Soliwhale's vote list `[&"trinket_underdog_emblem", &"trinket_spiked_armor", &"trinket_polished_plate", &"trinket_aegis"]` (`remaining -= 5`).
- **Step 4 (Stat Overflow):**
  - Convert any `remaining > 0` into `bonus_hp = remaining * 2`, `bonus_pwr = remaining * 1` on Soliwhale.

#### Engine 2: `_draft_swarm_banner(budget: int, reserved_slots: Dictionary = {}, unit_filter: Callable = Callable(), allow_trinkets: bool = true, rng: SeededRNG = RNGManager.map_rng)` (`trinket_banner_swarm` & shared modular drafter)
- Used by **Swarm Banner**, **Dustmon Support**, **Toughmon Support** (filtered to `Tank` tag), **Doppelkun Support**, and **Mid-Combat Reinforcements**.
- Runs a loop while `remaining > 0`:
  - Evaluates which of the 4 weighted actions are currently valid and affordable:
    1. **Draft Synergy Unit / Pair (`Weight = 100`):** Valid if at least 1 empty slot (`0..4`) exists and at least 1 eligible unit has `cost <= remaining` and satisfies `EncounterSynergyRegistry.is_valid_slot_for_unit`.
       - If the board is empty (no anchor unit yet), picks an anchor unit and places it in one of its `preferred_slots`. If `remaining` allows, immediately pairs it with an adjacent `front_partner` or `behind_partner`!
       - If units already exist on the board, evaluates all empty slots adjacent to existing units and selects `(unit_id, slot)` weighted by `EncounterSynergyRegistry.score_unit_in_slot(...)`.
       - **Soliwhale Pairing:** `&"WATnkAni"` (Soliwhale) is evaluated as a valid candidate for any open slot that leaves at least one adjacent slot empty (pairing with `&"EMPTY"` space in front or behind, honoring its solitary trait).
    2. **Draft Secondary Trinket (`Weight = 30`):** Valid if `allow_trinkets == true`, `remaining >= 5`, `board.size() >= 2`, and `enemy_trinket_ids.size() < MAX_TRINKETS`.
       - Calls `EncounterSynergyRegistry.select_best_voted_trinket(board, enemy_trinket_ids, rng)` (`remaining -= 5`).
    3. **Equip Synergistic Item (`Weight = 30`):** Valid if at least 1 drafted unit has `items.is_empty()` and an affordable item (`cost <= remaining`) in its `profile.items`.
       - Equips highest-tier affordable item from `profile.items` (`remaining -= item_cost`).
    4. **Level Up Unit (`Weight = 25`):** Valid if at least 1 drafted unit has `level < 3` and upgrade cost (`base_cost * (1 << (level - 1))`, i.e., +base_cost for L1$\rightarrow$L2, +2$\times$base_cost for L2$\rightarrow$L3) $\le$ `remaining`.
       - Increments `unit.level += 1` (`remaining -= upgrade_cost`).
  - **Fallback — Stat Overflow Allocation:**
    - When none of the 4 actions above are valid/affordable and `remaining > 0`, distributes `remaining` Gold evenly across all drafted units (`+2 HP / +1 PWR` per 1 Gold).

#### Engine 3: `_draft_fire_phalanx_banner(budget: int, preplaced_burnie_slot: int = -1)` (`trinket_banner_fire_phalanx` & `trinket_banner_burnie`)
- Innate Secondary Trinket: Automatically receives `&"trinket_trait_fire"` (Fire Crest) for FREE (0G) in `enemy_trinket_ids`.
- Follows the exact 5-Slot Preferential Formation Blueprint in `EncounterSystem.md` §5 Banner 3:
  - **Low Budget ($B < 7$):**
    - Drafts Slot 0: `&"FFigMec"` (Vulcannon, 1G) and Slot 1: `&"EFTnkMec"` (Branblee, 2G).
    - If `remaining >= 1` and Slot 2 is open (or Slot 3 if Burnie is in Slot 2): drafts 1 **Procedural Surprise Unit** (`WSupAni`, `ETnkPla`, or `ASpeFod`, 1G) that matches the Front/Behind pairs of its neighbors.
    - **Surprise Unit Fire Emblem Rule (Confirmed by User):** If `remaining >= 1` (or bundled free when budget is tight), equips the Surprise Unit with `&"item_emblem_fire"` at **1G encounter cost** (or 0G if `remaining == 0`), converting it into a Fire Soul unit.
  - **Mid Budget ($7 \le B < 10$):**
    - Drafts core frontline (`FFigMec` 1G, `EFTnkMec` 2G, `FWFigFod` Pepspray 2G) and 1 Surprise Unit w/ `item_emblem_fire` as budget permits.
  - **High Budget ($B \ge 10$):**
    - Deploys high-budget blueprint: Slot 0 `&"EFTnkMec"` (L2 if budget allows), Slot 1 `&"FFWASupMec"` (Relaytron, 4G, prioritized for `item_t2_b` Scythe or `item_t3_b` HardCandy), Slot 2 `&"FWFigFod"` or Surprise Unit w/ `item_emblem_fire` (unless occupied by Burnie), Slot 3 `&"EFWWFigCos"` (Tsunamantle, 4G), Slot 4 `&"EFWAFigMec"` (Pachinkannon, 4G).
  - Any leftover budget is spent on unit levels, synergistic items, and even Stat Overflow (`+2 HP / +1 PWR` per 1G).
- **Fire Phalanx / Burnie Reinforcements (`50% Daily Budget`):**
  - If Slot 0 is empty: prioritizes summoning `&"EFTnkMec"` (Branblee, 2G) or `&"FFigMec"` (Vulcannon, 1G).
  - For middle/rear empty slots: summons Fire units (`&"FWFigFod"`, `&"FASpeApp"`, `&"EFWWFigCos"`, `&"EFWAFigMec"`, `&"FFigMec"`) OR at most **1** non-Fire Surprise Unit equipped with `&"item_emblem_fire"` (bundled at 1G cost) that matches adjacent Front/Behind pairs.

#### Engine 4: Boss & Elite Specific Drafters
1. **Dustmon (`_draft_dustmon_banner`):**
   - Places `trinket_banner_dustmon` in `enemy_trinket_ids[0]`.
   - Places `&"boss_dustmon"` in **Slot 4** (Cost 0G, `bonus_hp = int(floor(daily_budget * 0.4))`, `bonus_pwr = int(floor(daily_budget * 0.2))`).
   - Calls `_draft_swarm_banner` with `support_budget = int(floor(daily_budget * 0.85)) + budget_delta` across Slots `0..3`.
   - Reinforcements (`33% Daily Budget`): Prioritizes low-cost T1/T2 units into best-fit pairing slots to feed allied deaths.
2. **Toughmon (`_draft_toughmon_banner`):**
   - Places `trinket_banner_toughmon` and innate `&"trinket_trait_tank"` in `enemy_trinket_ids` (Cost 0G).
   - Places `&"boss_toughmon"` in **Slot 4** (Cost 0G, `bonus_hp = int(floor(daily_budget * 0.3))`, `bonus_pwr = int(floor(daily_budget * 0.1))`).
   - Calls `_draft_swarm_banner` with `support_budget` across Slots `0..3` filtered **strictly to Tank-tagged units** (`ETnkPla`, `EFTnkMec`, `WATnkAni`, `EFWATnkApp`, `EWWATnkToy`, `FWWATnkFod`).
   - Reinforcements (`33% Daily Budget`): Strictly Tank-tagged units into best-fit slots, leveling or equipping defensive items (`Candy`, `Anvil`, `HardCandy`) with remaining wave budget.
3. **Doppelkun (`_draft_doppelkun_banner`):**
   - Places `trinket_banner_doppelkun` in `enemy_trinket_ids[0]`.
   - Places `&"boss_doppelkun"` in **Slot 0** (Cost 0G).
   - Calls `_draft_swarm_banner` with `support_budget` across Slots `1..4`.
   - Reinforcements (`33% Daily Budget`): Summons **1 `&"EEFASpeCos"` (Mimicloak)** into the best-fit empty slot (`1..4`). Note that even if `wave_budget < 4`, Doppelkun's Banner guarantees 1 L1 `EEFASpeCos`; if `wave_budget >= 8`, upgrades it to Level 2; if leftover budget remains, equips an offensive item (`Wakizashi`, `Scythe`, or `HardCandy`) or applies Stat Overflow.
4. **Slimeblob (`_draft_slimeblob_banner`):**
   - Places `trinket_banner_slimeblob` in `enemy_trinket_ids[0]`.
   - Places `&"elite_slimeblob"` in **Slot 2** (Cost 0G, `bonus_hp = int(floor(daily_budget * 0.5))`, `bonus_pwr = int(floor(daily_budget * 0.15))`).
   - Deploys 1 Level 1 `&"unit_spikeslime"` in **Slot 0** (1G) and, if `support_budget >= 2`, a second Level 1 `&"unit_spikeslime"` in **Slot 1** (1G), leaving Slots 3 and 4 empty for Mitosis/Evolution.
   - Spends remaining `support_budget` (Confirmed by User) on:
     1. Up to 2 Secondary Trinkets (5G each, from `[&"trinket_spiked_armor", &"trinket_polished_plate", &"trinket_trait_tank", &"trinket_armor_aura"]`).
     2. A synergistic defensive item on Slimeblob (`item_t1_a` Candy 1G, `item_t2_c` Anvil 2G, or `item_t3_a` Ramune / `item_t3_b` HardCandy 4G).
     3. Remaining budget converted into Stat Overflow (`+2 HP / +1 PWR` per 1G) on Slimeblob.
5. **Burnie (`_draft_burnie_banner`):**
   - Places `trinket_banner_burnie` in `enemy_trinket_ids[0]`.
   - Places `&"elite_burnie"` in **Slot 2** (Cost 0G, `bonus_hp = int(floor(daily_budget * 0.4))`, `bonus_pwr = int(floor(daily_budget * 0.2))`).
   - Calls `_draft_fire_phalanx_banner(support_budget, 2)` to populate Slots `0, 1, 3, 4` using the Fire Phalanx blueprint.

---

## 6. Phase 6: Localization & Legacy Cleanup

### 6.1 Localization Keys (`localization/game.csv`)
Add English and Brazilian Portuguese (`pt_BR`) entries to `localization/game.csv` for:
- All 8 Banner Trinkets (`trinket_banner_lone_whale.name` / `.desc`, `trinket_banner_swarm.name` / `.desc`, `trinket_banner_fire_phalanx.name` / `.desc`, `trinket_banner_dustmon.name` / `.desc`, `trinket_banner_toughmon.name` / `.desc`, `trinket_banner_doppelkun.name` / `.desc`, `trinket_banner_slimeblob.name` / `.desc`, `trinket_banner_burnie.name` / `.desc`).
- All 3 Bosses (`boss_dustmon.name` / `.desc`, `boss_toughmon.name` / `.desc`, `boss_doppelkun.name` / `.desc`).
- All 2 Elites + Token (`elite_slimeblob.name` / `.desc`, `elite_burnie.name` / `.desc`, `unit_spikeslime.name` / `.desc`).
- All new ability descriptions (`ability.dustmon_spore.desc`, `ability.dustmon_vampiric.desc`, `ability.dustmon_resonance.desc`, `ability.dust_enter_board.desc`, `ability.toughmon_command.desc`, `ability.doppelkun_mirror.desc`, `ability.slimeblob_mitosis.desc`, `ability.slimeblob_evolution.desc`, `ability.burnie_attack.desc`, `ability.banner_reinforce.desc`).
- Run `python3 scripts/utils/sync_translations.py` to compile `localization/en.po` and `localization/pt_BR.po`.

### 6.2 Complete Obsolete Content & Asset Deprecation Checklist
To eliminate confusion in all future development and AI sessions, all legacy bosses, obsolete dust elites, deprecated abilities, legacy summon scripts, and obsolete generator remnants **must be completely deleted** from the repository as part of Phase 6:

#### 6.2.1 Obsolete Boss Content (Boss 1 to Boss 5)
- **Delete Unit Resources:**
  - `resources/units/Boss1.tres`
  - `resources/units/Boss2.tres`
  - `resources/units/Boss3.tres`
  - `resources/units/Boss4.tres`
  - `resources/units/Boss5.tres`
- **Delete Ability & Effect Resources:**
  - `resources/abilities/ability_boss_1_summon.tres`
  - `resources/abilities/ability_boss_2_summon.tres`
  - `resources/abilities/ability_boss_3_summon.tres`
  - `resources/abilities/ability_boss_4_summon.tres`
  - `resources/abilities/ability_boss_5_summon.tres`
  - `resources/abilities/ability_boss_summon.tres`
  - `resources/abilities/ability_boss_1_passive_draw_drain.tres`
  - `resources/abilities/ability_boss_2_passive_token_drain.tres`
  - `resources/abilities/ability_boss_3_passive_ally_growth.tres`
  - `resources/effects/effect_boss_summon.tres`
- **Delete Obsolete Scripts:**
  - `scripts/EffectBossSummon.gd` (fully superseded by `scripts/effects/EffectBannerReinforce.gd`)
- **Delete Obsolete Legacy Boss Sprites:**
  - `assets/PixelArt/sprites/units/boss01.png` (and `.import`)
  - `assets/PixelArt/sprites/units/boss02.png` (and `.import`)
  - `assets/PixelArt/sprites/units/boss03.png` (and `.import`)
  - `assets/PixelArt/sprites/units/boss04.png` (and `.import`)
  - `assets/PixelArt/sprites/units/boss05.png` (and `.import`)
  - `assets/Realistic/sprites/units/boss01.png` (and `.import`)
  - `assets/Realistic/sprites/units/boss02.png` (and `.import`)
  - `assets/Realistic/sprites/units/boss03.png` (and `.import`)
  - `assets/Realistic/sprites/units/boss04.png` (and `.import`)
  - `assets/Realistic/sprites/units/boss05.png` (and `.import`)
- **Clean Registry Entries (`scripts/AbilitiesRegistry.gd`):**
  - Remove registry entries for `"All Bosses"` (`L434`), `"The Awakened Guardian (Boss 1)"` (`L441`), and `"The Shadow Warden (Boss 2)"` (`L448`).

#### 6.2.2 Obsolete Dust Elite Content
- **Delete Unit Resources:**
  - `resources/units/Tier1DustEliteUnit.tres` (`unit_dust_elite_t1`)
  - `resources/units/Tier2DustEliteUnit.tres` (`unit_dust_elite_t2`)
  - `resources/units/Tier3DustEliteUnit.tres` (`unit_dust_elite_t3`)
- **Delete Ability Resources:**
  - `resources/abilities/ability_dust_elite1_spawn_attack.tres`
  - `resources/abilities/ability_dust_elite1_spawn_death.tres`
  - `resources/abilities/ability_dust_elite1_spawn_turn.tres`
  - `resources/abilities/ability_dust_elite2_spawn_attack.tres`
  - `resources/abilities/ability_dust_elite2_spawn_death.tres`
  - `resources/abilities/ability_dust_elite2_spawn_hurt.tres`
  - `resources/abilities/ability_dust_elite2_spawn_turn.tres`
  - `resources/abilities/ability_dust_elite_growth.tres`
  - `resources/abilities/ability_dust_elite_spawn_attack.tres`
  - `resources/abilities/ability_dust_elite_spawn_death.tres`
  - `resources/abilities/ability_dust_elite_spawn_hurt.tres`
  - `resources/abilities/ability_dust_elite_spawn_turn.tres`
- **Delete Obsolete Scripts:**
  - `scripts/effects/EffectDustEliteSpawn.gd` (and `.uid`)
  - `scripts/effects/EffectDustEliteSpawn1.gd` (and `.uid`)
  - `scripts/effects/EffectDustEliteSpawn2.gd` (and `.uid`)
- **Delete Obsolete Dust Elite Sprites:**
  - `assets/PixelArt/sprites/units/Tier1DustEliteUnit.png` (and `.import`)
  - `assets/PixelArt/sprites/units/Tier2DustEliteUnit.png` (and `.import`)
  - `assets/PixelArt/sprites/units/Tier3DustEliteUnit.png` (and `.import`)
  - `assets/Realistic/sprites/units/Tier1DustEliteUnit.png` (and `.import`)
  - `assets/Realistic/sprites/units/Tier2DustEliteUnit.png` (and `.import`)
  - `assets/Realistic/sprites/units/Tier3DustEliteUnit.png` (and `.import`)
- **Clean Code References:**
  - `scripts/battle/BattleSetup.gd`: Remove lines 210 and 242–243 checking `id_str.contains("unit_dust_elite")`.
  - `scripts/EncounterGenerator.gd`: Remove lines 75–79 hardcoded selection pool of `unit_dust_elite_t1/t2/t3`.
  - `scripts/Database.gd`: Line 376 sanitize `if unit_id_lower.contains("dust") or unit_id_lower.contains("elite"):` to check unit tags (`BOSS`, `TOKEN`, `HIDDEN`) rather than fragile substring matching.
- **Retained Dust Units Invariant:**
  - `resources/units/Tier1DustUnit.tres`, `Tier2DustUnit.tres`, `Tier3DustUnit.tres` (`unit_dust_t1`, `unit_dust_t2`, `unit_dust_t3`) and their sprites are **retained** because they are active token units utilized by `boss_dustmon`'s "Dust Kingdom" ability.
  - `resources/conditions/cond_dying_unit_is_dust.tres` is **retained** because it checks for dying Dust units for Dustmon.

#### 6.2.3 Obsolete Encounter Generator Remnants & Mimicloak Boss Guard
- **Mimicloak Boss Guard (`scripts/effects/EffectMirrorTransform.gd:50–52`):**
  - Update Boss guard from `if target_def.id.begins_with("boss_")` to:
    ```gdscript
    if target_def.tags.has(&"BOSS") or target_def.id == &"enemy_hero":
    ```
    ensuring Mimicloak never transforms into Boss or Elite units (`boss_*` or `elite_*`).
- **Remove Obsolete Test Files:**
  - Delete any legacy test scripts or mock scenes referencing the old encounter generation logic.

---

## 7. Phase 7: Verification & Regression Test Suite

1. **Headless Compilation & Boot Verification:**
   ```bash
   .agents/skills/verify-headless/scripts/run_headless.sh
   ```
   Must exit with code `0` and zero GDScript parse or resource load errors.
2. **Automated Encounter & Combat Verification Script (`scratch/test_encounter_refactor.gd`):**
   Write and execute a headless verification test verifying:
   - **Budget & Cost Invariants:** Across Days 1, 2, 3, 5, 8, 12, 20, every Regular Banner (`Lone Whale`, `Swarm`, `Fire Phalanx`), Elite Banner (`Slimeblob`, `Burnie`), and Boss Banner (`Dustmon`, `Toughmon`, `Doppelkun`) spends 100% of its target budget (accounting for unit levels, item costs, 5G secondary trinkets, and `+2 HP / +1 PWR` stat overflow), never includes `is_player_exclusive` or Hero Set entities, and never auto-injects free unpurchased trait crests.
   - **Positional Invariants:** `WSupAni` (Ripplepup) never spawns in Slot 0; `WATnkAni` (Soliwhale) spawns in Slot 0 alone under `trinket_banner_lone_whale`; `EEFWSupPla` (Oakbark) only spawns in Slot 1 or 2; `EFWAFigMec` (Pachinkannon) only spawns in Slot 3 or 4.
   - **Pity & Decay Distribution:** Simulating 30 consecutive Regular, Elite, and Boss selections confirms weight decay (`100 / (1 + C * 2)`) and the `0.20x` consecutive repeat penalty prevent repetitive streaks while keeping all options reachable.
   - **Combat Mechanics Verification:**
     - **Dustmon:** Ally death injects tier-matched Dust unit into non-empty Gacha Machine without repeating the same machine twice in a row, heals Dustmon `1/2/3 HP`, scales Dustmon PWR by `+1` per Dust unit across all player containers, and drawing/fielding a Dust unit applies `1/2/3 Static + Burn` once without re-triggering on merge.
     - **Toughmon:** Turn start grants `2 * surviving_allies` Armor to self and `+2 Armor / +1 Spikes` to allies in front; reinforcements only summon `Tank` units.
     - **Doppelkun:** Pre-Battle copies Player Hero's HP and PWR; odd-turn reinforcements summon `EEFASpeCos` (Mimicloak).
     - **Slimeblob:** Non-lethal hit triggers Mitosis (summons L1 Spikeslime); lethal hit suppresses Mitosis; Turn-Start Evolution Clock spawns/levels/buffs Spikeslimes.
     - **Burnie:** Attacks deal bonus damage equal to target's Burn stacks without consuming Burn, and ignite the target's slot into a `&"burn"` slot emitting `SLOT_EFFECT_CHANGE`.
     - **Banner Reinforcements:** Fire at `at_turn_end` on odd turns (`1, 3, 5...`) even if the Boss/Elite unit was knocked out earlier while other enemies remain alive.
   - Delete temporary scripts in `scratch/` after all assertions pass.
