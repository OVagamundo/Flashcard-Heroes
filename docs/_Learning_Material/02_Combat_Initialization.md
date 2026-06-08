# Module 2: The Combat Initialization

## The VCR Pipeline Boundary Delineation

> [!IMPORTANT]
> **VCR Boundary Delineation**
> In Flashcard Heroes: Gachamon, we strictly separate State Math from Visual Playback. 
> - **Silent Simulation Phase:** Code that mathematically calculates the battle (e.g., `BattleState.gd`, `CombatSimulator.gd`, `BattleSetup.gd`). This code executes instantly and never touches a sprite, tween, or timer.
> - **Loud Playback Phase:** Code that reads the mathematical logs and plays animations on screen (e.g., `BattleAnimator.gd`, `GachaBallView.gd`).
> 
> *The code broken down in this module belongs entirely to the **Silent Simulation Phase**.*

## The Initialization Pipeline

When the player clicks the "Battle!" button, the global state transitions into combat mode, and we must generate a "sandbox" version of the player's team so that taking damage or dying doesn't permanently ruin their `RunState` inventory.

```mermaid
flowchart TD
    %% Define the Layers
    subgraph Presentation_Layer [Presentation Layer (Loud Playback)]
        direction TB
        NodeView[NodeView UI Button]
    end

    subgraph Communication_Layer [Communication Layer]
        direction TB
        SB{SignalBus}
    end

    subgraph Logic_Layer [Silent Simulation Phase]
        direction TB
        GM[GameManager]
        BM[BattleManager]
        BSetup[BattleSetup.gd]
        BState[BattleState.gd]
    end

    %% The Flow
    NodeView -- "1. Player clicks node\nSignalBus.node_selected.emit(node_def)" --> SB
    SB -- "2. Routes to Main" --> GM
    GM -- "3. Main calls BM" --> BM
    BM -- "4. _setup_battle()" --> BSetup
    BSetup -- "5. create_battle_copies()" --> BState
    BSetup -- "6. setup_enemy_lineup()" --> BState
    BM -- "7. _trigger_battle_start_abilities()" --> BM
```

## Line-by-Line Mastery: How the Sandbox is Built

Let's look at exactly how `BattleManager.gd` and `BattleSetup.gd` execute the simulation initialization.

### 1. `BattleManager.start_battle()`
*File: `scripts/BattleManager.gd`*

```gdscript
func start_battle(encounter_def: EncounterDefinition) -> void:
	# Clear any existing selection when entering battle
	SignalBus.emit_signal("selection_clear_requested")
	# Create a fresh battle state with copies of units from run state.
	# IMPORTANT: The battle operates on these copies, leaving the original run state untouched.
	# Any changes to units during battle (HP, stats, etc.) will be discarded when the battle ends.
	_setup_battle(encounter_def)
	GameManager.is_in_battle = true
	SignalBus.emit_signal("battle_state_changed", true)
	SignalBus.emit_signal("battle_state_changed", true)
	_emit_battle_inventory_changed()
	
	# AUDIO HOOK: Battle BGM
	Audio.play_music(SoundRegistry.BGM_BATTLE)
	
	SignalBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
	
	# Emit unit_stat_changed for all units that have equipped items after UI is populated
	call_deferred("_emit_stats_changed_for_equipped_units")
	
	# Start the first turn with the mini-game
	# In test mode, stay in MANAGEMENT to allow user to spawn trinkets/units first
	if not is_test_mode:
		call_deferred("_change_phase", Phases.START_OF_TURN)
```

**Syntax Breakdown:**
- `SignalBus.emit_signal("signal_name")`: The Godot 3 / older style string-based emission. While Godot 4 allows `SignalBus.signal_name.emit()`, we observe this file currently using string emissions.
- `call_deferred("function_name")`: Defers the function call to the idle time of the current frame, ensuring the node tree is stable before continuing.

### 2. `BattleManager._setup_battle()`
*File: `scripts/BattleManager.gd`*

```gdscript
func _setup_battle(encounter_def: EncounterDefinition = null) -> void:
	# Clear all state
	_state.clear()
	_combat.clear()
	_battle_over_emitted = false
	_battle_over_deferred = false
	_current_turn = 0
	
	if is_instance_valid(encounter_def):
		if "player_slot_effects" in encounter_def and encounter_def.player_slot_effects.size() == 5:
			_state.player_slot_effects = encounter_def.player_slot_effects.duplicate()
		if "enemy_slot_effects" in encounter_def and encounter_def.enemy_slot_effects.size() == 5:
			_state.enemy_slot_effects = encounter_def.enemy_slot_effects.duplicate()

	
	# Create battle copies from run state using BattleSetup
	var permanent_to_battle_uuid_map := BattleSetup.create_battle_copies_from_run_state(_state)
	
	# Place instances in containers
	BattleSetup.place_instances_from_run_state(_state, permanent_to_battle_uuid_map)
	
	# Setup board using BattleSetup
	BattleSetup.setup_enemy_lineup(_state, encounter_def)
	
	if not is_test_mode and is_instance_valid(encounter_def):
		BattleSetup.setup_enemy_trinkets(_state, encounter_def)
	
	# Copy player trinkets
	BattleSetup.setup_player_trinkets(_state)
	
	# Trigger on_battle_start for all units
	# 5. Connect to token changes for dynamic abilities (e.g., Templar)
	if not SignalBus.gacha_tokens_changed.is_connected(_on_gacha_tokens_changed):
		SignalBus.gacha_tokens_changed.connect(_on_gacha_tokens_changed)

	_trigger_battle_start_abilities()
```

### 3. Deep Dive: `BattleSetup.create_battle_copies_from_run_state()`
*File: `scripts/battle/BattleSetup.gd`*

Here is the exact code that duplicates the player's team and maps their equipped items line-by-line:

```gdscript
static func create_battle_copies_from_run_state(state: RefCounted) -> Dictionary:
	var permanent_to_battle_uuid_map: Dictionary = {}
	var run_state_instances: Array = GameManager.run_state.get_all_instances().values()

	for perm_inst in run_state_instances:
		var def = perm_inst.get_definition()
		var is_hero = is_hero_definition(def)
		
		if is_hero:
			var hero_battle_copy: GachaBallInstance = perm_inst.create_battle_copy()
			if is_instance_valid(hero_battle_copy):
				state.register_instance(hero_battle_copy)
				permanent_to_battle_uuid_map[perm_inst.ball_uuid] = hero_battle_copy.ball_uuid
			continue
		
		if is_trinket_definition(def):
			continue
			
		var battle_copy: GachaBallInstance = perm_inst.create_battle_copy()
		if not is_instance_valid(battle_copy):
			continue
		state.register_instance(battle_copy)
		permanent_to_battle_uuid_map[perm_inst.ball_uuid] = battle_copy.ball_uuid

	for battle_uuid in state.get_all_instances():
		var battle_inst = state.get_instance(battle_uuid)
		if battle_inst.get_definition().category != &"UNIT":
			continue
		var original_equipped_uuids = battle_inst.equipped_item_uuids.duplicate()
		battle_inst.equipped_item_uuids.clear()
		battle_inst.equipped_item_uuids.resize(original_equipped_uuids.size())
		battle_inst.equipped_item_uuids.fill("")
		for i in range(original_equipped_uuids.size()):
			var permanent_item_uuid = original_equipped_uuids[i]
			if not permanent_item_uuid.is_empty() and permanent_to_battle_uuid_map.has(permanent_item_uuid):
				var battle_item_uuid: String = permanent_to_battle_uuid_map[permanent_item_uuid]
				battle_inst.equipped_item_uuids[i] = battle_item_uuid
				var item_instance: GachaBallInstance = state.get_instance(battle_item_uuid)
				if is_instance_valid(item_instance):
					item_instance.equipped_on_uuid = battle_inst.ball_uuid
					item_instance.equipped_slot_index = i

	for battle_uuid in state.get_all_instances():
		var battle_inst: GachaBallInstance = state.get_instance(battle_uuid)
		if not is_instance_valid(battle_inst):
			continue
		var battle_def = battle_inst.get_definition()
		if is_instance_valid(battle_def) and battle_def.category == &"UNIT":
			battle_inst.current_hp = battle_inst.get_effective_starting_hp(state.get_all_instances())
			battle_inst.current_pwr = battle_inst.get_effective_starting_pwr(state.get_all_instances())

	return permanent_to_battle_uuid_map
```

**Syntax & Architecture Breakdown:**
- `static func`: This function belongs to the `BattleSetup` class itself, not an instance. We can call `BattleSetup.create_battle_copies_from_run_state()` without initializing the object.
- `&"UNIT"`: The `&` symbol creates a `StringName`. `StringNames` are unique, immutable strings that Godot handles internally as pointers. They are much faster for dictionary lookups and comparisons than regular strings.
- `duplicate()`: Creates a shallow copy of the equipped array. If we didn't do this, iterating and modifying the original array at the same time could cause errors or overwrite data.
- **Dynamic Array Sizing:** `battle_inst.equipped_item_uuids.resize(original_equipped_uuids.size())` dynamically resizes the array rather than enforcing a strict loop cap. This means if a unit has 1 slot, or 5 slots, the codebase scales dynamically without a hardcoded limit.
- `fill("")`: Populates the newly resized array with empty strings, initializing the state safely.

### Summary
By the time `_setup_battle()` finishes executing, the **Silent Simulation Phase** has constructed a perfectly mirrored sandbox containing the player's lineup, the enemies, and all dynamically scaled items equipped exactly as they were in the RunState. The math is ready to begin calculating the battle!
