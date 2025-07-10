Phase 2: Core Logic & Manager Refactoring - Implementation Plan
Objective:
To refactor the singleton managers into stateless controllers that operate on the new data structures. We will implement the BattleManager as a complete state machine and ensure all data manipulation is context-aware and routed through the correct data owner (RunState or BattleManager).
Step 2.1: Revamp the EventBus
Instruction: Overwrite the EventBus.gd script to align it perfectly with the definitive list of signals from the TDD. This ensures all managers and UI components are speaking the same language.
<details>
<summary>Prompt for AI Code Editor</summary>
PROMPT:
Overwrite the file res://scripts/EventBus.gd with the following content:
# res://scripts/EventBus.gd
extends Node

## A global script containing only signal definitions for the entire game.
## All communication between major systems happens through these signals.

# --- Run/Scene Signals ---
signal start_run_requested
signal loadout_scene_requested
signal main_scene_requested
signal battle_start_requested
signal inspection_test_scene_requested
signal title_scene_requested

# --- Window/Modal Signals ---
signal inspect_inventory_requested
signal display_discard_pile_requested
signal close_modal_requested
signal background_clicked # For modal background blockers
signal global_background_clicked # For main content area background

# --- Action Signals ---
signal draw_gacha_requested(tier: int)
signal inventory_action_requested(source_loc: LocationIdentifier, target_loc: LocationIdentifier)
signal choice_made(choice_id: StringName)
signal inspection_requested(source_view: Control)

# --- Selection Signals ---
signal view_selected(view: Control, location: LocationIdentifier)
signal view_deselected(view: Control)
signal invalid_action_triggered(view: Control)
signal selection_changed(new_location: LocationIdentifier)

# --- State Change Signals ---
signal run_state_changed
signal battle_inventory_changed
signal battle_state_changed(is_in_battle: bool)
signal battle_phase_changed(phase_name: StringName)
signal gacha_tokens_changed(new_amount: int)
signal unit_stats_changed(unit_uuid: String)
signal unit_inventory_changed(unit_uuid: String)

</details>
Step 2.2: Refactor GameManager
Instruction: Overwrite GameManager.gd to simplify it according to the TDD. Its sole responsibilities are to hold the run_state and the global is_in_battle flag.
<details>
<summary>Prompt for AI Code Editor</summary>
PROMPT:
Overwrite the file res://scripts/GameManager.gd with the following content:
# res://scripts/GameManager.gd
extends Node

## Manages the persistent state of the current run by holding a RunState resource.
## Also acts as the single source of truth for the game's battle state.

var run_state: RunState
var is_in_battle: bool = false # The global authority on whether a battle is active.

func _ready() -> void:
	# Connect to signals to manage the run and battle state.
	EventBus.start_run_requested.connect(_on_start_run_requested)
	EventBus.battle_state_changed.connect(func(in_battle): is_in_battle = in_battle)
	EventBus.title_scene_requested.connect(_on_return_to_title)

func _on_start_run_requested() -> void:
	run_state = RunState.new()
	run_state.start_new_run()
	EventBus.emit_signal("run_state_changed") # Use the new signal
	EventBus.emit_signal("loadout_scene_requested")

func _on_return_to_title() -> void:
	# Clear the run state when returning to the title screen
	run_state = null

</details>
Step 2.3: Implement the BattleManager State Machine
Instruction: This is a complete rewrite. Overwrite BattleManager.gd with the new implementation. This version manages its own data containers, operates as a state machine, and handles combat resolution as defined in the TDD.
<details>
<summary>Prompt for AI Code Editor</summary>
PROMPT:
Overwrite the file res://scripts/BattleManager.gd with the following content:
# res://scripts/BattleManager.gd
extends Node
class_name BattleManager

# --- TDD: Battle State Machine ---
enum Phases { START_OF_TURN, MANAGEMENT, COMBAT, END_OF_TURN, BATTLE_OVER }
var _current_battle_phase: Phases

# --- TDD: Data-Driven State ---
# Master registry for all temporary battle instances (player and enemy)
var _battle_instances: Dictionary = {} # Key: ball_uuid (String), Value: GachaBallInstance
# Registry for all temporary battle containers
var _data_containers: Dictionary = {} # Key: container_name (StringName), Value: DataContainer

var _gacha_tokens: int = 0
var _draw_pools: Dictionary = { 1: [], 2: [], 3: [] } # Stores UUIDs for drawing

# --- UI Node References ---
@onready var end_turn_button: Button = get_owner().get_node("%EndTurnButton")
@onready var gacha_token_label: Label = get_owner().get_node("%GachaTokenLabel")
@onready var discard_pile_button: Button = get_owner().get_node("%DiscardPileButton")

func _ready():
	add_to_group("battle_manager")
	_setup_battle()
	_connect_signals()

	GameManager.is_in_battle = true
	EventBus.emit_signal("battle_state_changed", true)
	EventBus.emit_signal("battle_inventory_changed")

	_change_phase(Phases.START_OF_TURN)

func _exit_tree():
	GameManager.is_in_battle = false
	EventBus.emit_signal("battle_state_changed", false)

func _connect_signals():
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	EventBus.draw_gacha_requested.connect(_on_draw_gacha_requested)
	EventBus.unit_inventory_changed.connect(_on_unit_inventory_changed)
	discard_pile_button.pressed.connect(EventBus.display_discard_pile_requested.emit)

# --- Public API for Managers ---
func get_instance(uuid: String) -> GachaBallInstance:
	return _battle_instances.get(uuid)

func get_all_instances() -> Dictionary:
	return _battle_instances

func get_container(name: StringName) -> DataContainer:
	return _data_containers.get(name)

# --- Battle Setup ---
func _setup_battle():
	# 1. Initialize all temporary DataContainers as per TDD
	_data_containers[&"PlayerLineup"] = FixedArrayContainer.new(6)
	_data_containers[&"PlayerBench"] = FixedArrayContainer.new(3)
	_data_containers[&"ItemInventory"] = FixedArrayContainer.new(3)
	_data_containers[&"EnemyLineup"] = FixedArrayContainer.new(6)
	_data_containers[&"BattleInventoryT1"] = GridContainer.new(16)
	_data_containers[&"BattleInventoryT2"] = GridContainer.new(16)
	_data_containers[&"BattleInventoryT3"] = GridContainer.new(16)
	_data_containers[&"DiscardPile"] = GridContainer.new(16)

	# 2. Create battle copies of player's persistent hero and inventory
	var player_hero_copy = GameManager.run_state.hero_instance.create_battle_copy()
	_battle_instances[player_hero_copy.ball_uuid] = player_hero_copy
	_data_containers[&"PlayerLineup"].set_uuid(0, player_hero_copy.ball_uuid)

	for instance_uuid in GameManager.run_state.run_instances:
		var permanent_instance = GameManager.run_state.run_instances[instance_uuid]
		if is_instance_valid(permanent_instance):
			var battle_copy = permanent_instance.create_battle_copy()
			_battle_instances[battle_copy.ball_uuid] = battle_copy
			
			var def = battle_copy.get_definition()
			var container_name = &"BattleInventoryT%d" % def.tier
			var container = _data_containers[container_name]
			var empty_idx = container.find_first_empty_slot()
			container.set_uuid(empty_idx, battle_copy.ball_uuid)
			
			# Populate draw pools
			_draw_pools[def.tier].append(battle_copy.ball_uuid)

	# 3. Setup the enemy lineup
	_setup_enemy_lineup()
	
	# 4. Recalculate stats for all units now that they are all created
	for instance in _battle_instances.values():
		if instance.get_definition().category == &"UNIT":
			instance.recalculate_stats(_battle_instances)

func _setup_enemy_lineup():
	var enemy_unit_ids = [&"enemy_hero", &"unit_t1_a", &"unit_t1_b", &"unit_t2_c", &"unit_t3_d"]
	var all_item_defs = Database.items.values()
	var enemy_lineup = _data_containers[&"EnemyLineup"]

	for i in range(min(enemy_unit_ids.size(), 6)):
		var unit_def = Database.get_definition(enemy_unit_ids[i])
		if unit_def:
			var enemy_instance = GachaBallInstance.new()
			enemy_instance.initialize(unit_def)
			_battle_instances[enemy_instance.ball_uuid] = enemy_instance
			
			# Equip items
			for j in range(enemy_instance.equipped_item_uuids.size()):
				if not all_item_defs.is_empty():
					var item_def = all_item_defs.pick_random()
					var item_instance = GachaBallInstance.new()
					item_instance.initialize(item_def)
					_battle_instances[item_instance.ball_uuid] = item_instance
					enemy_instance.equipped_item_uuids[j] = item_instance.ball_uuid
			
			enemy_lineup.set_uuid(i, enemy_instance.ball_uuid)

# --- State Machine Logic ---
func _change_phase(new_phase: Phases):
	if _current_battle_phase == Phases.BATTLE_OVER: return

	_current_battle_phase = new_phase
	var phase_name = StringName(Phases.keys()[new_phase])
	EventBus.emit_signal("battle_phase_changed", phase_name)
	print("BattleManager: Entering phase -> ", phase_name)
	
	match _current_battle_phase:
		Phases.START_OF_TURN: _enter_start_of_turn_phase()
		Phases.MANAGEMENT: _enter_management_phase()
		Phases.COMBAT: _enter_combat_phase()
		Phases.END_OF_TURN: _enter_end_of_turn_phase()

func _enter_start_of_turn_phase():
	_gacha_tokens += 5
	EventBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
	_change_phase(Phases.MANAGEMENT)

func _enter_management_phase():
	end_turn_button.disabled = false
	_update_gacha_token_label()

func _enter_combat_phase():
	end_turn_button.disabled = true
	await _execute_combat_resolution()
	_change_phase(Phases.END_OF_TURN)

func _execute_combat_resolution():
	var basic_attack_def = Database.abilities.get(&"basic_attack")
	if not basic_attack_def:
		printerr("BasicAttack ability not found in Database.")
		return

	var player_lineup = _data_containers[&"PlayerLineup"].get_all_uuids()
	var enemy_lineup = _data_containers[&"EnemyLineup"].get_all_uuids()

	# Units act back-to-front (higher index to lower index)
	# Player Team's Turn
	for i in range(player_lineup.size() - 1, -1, -1):
		var attacker = get_instance(player_lineup[i])
		if is_instance_valid(attacker) and attacker.current_hp > 0:
			var target = _find_frontmost_target(false) # Find enemy target
			if is_instance_valid(target):
				AbilityResolver.execute_effect(basic_attack_def.effect, attacker, [target], _battle_instances)
				await get_tree().create_timer(0.3).timeout

	# Enemy Team's Turn
	for i in range(enemy_lineup.size() - 1, -1, -1):
		var attacker = get_instance(enemy_lineup[i])
		if is_instance_valid(attacker) and attacker.current_hp > 0:
			var target = _find_frontmost_target(true) # Find player target
			if is_instance_valid(target):
				AbilityResolver.execute_effect(basic_attack_def.effect, attacker, [target], _battle_instances)
				await get_tree().create_timer(0.3).timeout
	
	_check_for_deaths()

func _find_frontmost_target(is_player_team: bool) -> GachaBallInstance:
	var lineup_name = &"PlayerLineup" if is_player_team else &"EnemyLineup"
	var lineup_uuids = _data_containers[lineup_name].get_all_uuids()
	# Iterate front-to-back (low index to high index) to find first valid target
	for uuid in lineup_uuids:
		var unit = get_instance(uuid)
		if is_instance_valid(unit) and unit.current_hp > 0:
			return unit
	return null

func _check_for_deaths():
	var any_deaths = false
	for container in [_data_containers[&"PlayerLineup"], _data_containers[&"EnemyLineup"]]:
		var uuids = container.get_all_uuids()
		for i in range(uuids.size()):
			var unit = get_instance(uuids[i])
			if is_instance_valid(unit) and unit.current_hp <= 0:
				container.set_uuid(i, "") # Remove from lineup
				# For player units, move to discard, for enemies, just remove
				if unit.origin_uuid != "":
					_data_containers[&"DiscardPile"].set_uuid(
						_data_containers[&"DiscardPile"].find_first_empty_slot(),
						unit.ball_uuid
					)
				any_deaths = true
	if any_deaths:
		EventBus.emit_signal("battle_inventory_changed")

func _enter_end_of_turn_phase():
	var player_hero = get_instance(_data_containers[&"PlayerLineup"].get_uuid(0))
	var enemies_alive = _data_containers[&"EnemyLineup"].get_all_non_empty_uuids().size() > 0

	if not is_instance_valid(player_hero) or player_hero.current_hp <= 0:
		WindowManager.open_end_battle_popup(false) # Defeat
		_change_phase(Phases.BATTLE_OVER)
	elif not enemies_alive:
		WindowManager.open_end_battle_popup(true) # Victory
		_change_phase(Phases.BATTLE_OVER)
	else:
		_change_phase(Phases.START_OF_TURN)

# --- Signal Handlers ---
func _on_end_turn_button_pressed():
	if _current_battle_phase == Phases.MANAGEMENT:
		_change_phase(Phases.COMBAT)

func _on_draw_gacha_requested(tier: int):
	var cost = tier
	if _gacha_tokens < cost: return

	if _draw_pools[tier].is_empty():
		_reshuffle_discard_pile(tier)
		if _draw_pools[tier].is_empty(): return # Still no items to draw

	_gacha_tokens -= cost
	EventBus.emit_signal("gacha_tokens_changed", _gacha_tokens)

	var drawn_uuid = _draw_pools[tier].pick_random()
	_draw_pools[tier].erase(drawn_uuid)
	
	var drawn_instance = get_instance(drawn_uuid)
	var def = drawn_instance.get_definition()
	var target_container_name = &"PlayerBench" if def.category == &"UNIT" else &"ItemInventory"
	var target_container = _data_containers[target_container_name]
	
	var empty_idx = target_container.find_first_empty_slot()
	if empty_idx != -1:
		target_container.set_uuid(empty_idx, drawn_uuid)
	else:
		# Bench/Item inventory is full, move to discard
		var discard_container = _data_containers[&"DiscardPile"]
		discard_container.set_uuid(discard_container.find_first_empty_slot(), drawn_uuid)

	EventBus.emit_signal("battle_inventory_changed")

func _reshuffle_discard_pile(tier: int):
	var discard_uuids = _data_containers[&"DiscardPile"].get_all_uuids()
	var uuids_to_move: Array[String] = []
	for uuid in discard_uuids:
		if not uuid.is_empty():
			var instance = get_instance(uuid)
			if is_instance_valid(instance) and instance.get_definition().tier == tier:
				uuids_to_move.append(uuid)
	
	for uuid in uuids_to_move:
		# Add back to draw pool
		_draw_pools[tier].append(uuid)
		# Remove from discard pile
		var discard_container = _data_containers[&"DiscardPile"]
		var all_discard_uuids = discard_container.get_all_uuids()
		var idx_in_discard = all_discard_uuids.find(uuid)
		if idx_in_discard != -1:
			discard_container.set_uuid(idx_in_discard, "")

func _on_unit_inventory_changed(unit_uuid: String):
	var unit_instance = get_instance(unit_uuid)
	if is_instance_valid(unit_instance):
		unit_instance.recalculate_stats(_battle_instances)
		EventBus.emit_signal("unit_stats_changed", unit_uuid)

func _update_gacha_token_label():
	gacha_token_label.text = "Tokens: %d" % _gacha_tokens

</details>
Step 2.4: Refactor InventoryManager
Instruction: This is another complete rewrite. Overwrite InventoryManager.gd. The new version is a stateless controller that uses LocationIdentifier and routes all data operations to the correct owner (RunState or BattleManager) based on the is_in_battle context.
<details>
<summary>Prompt for AI Code Editor</summary>
PROMPT:
Overwrite the file res://scripts/InventoryManager.gd with the following content:
# res://scripts/InventoryManager.gd
extends Node

var _pending_action: Dictionary = {}

func _ready():
	EventBus.inventory_action_requested.connect(_on_inventory_action_requested)
	EventBus.choice_made.connect(_on_choice_made)

func _on_inventory_action_requested(source_loc: LocationIdentifier, target_loc: LocationIdentifier):
	InteractionManager.clear_selection()
	if source_loc.container == target_loc.container and source_loc.index == target_loc.index:
		InteractionManager.end_drag(false)
		return

	var data_owner = _get_data_owner()
	var all_instances = _get_all_instances(data_owner)

	var source_uuid = _get_uuid_from_loc(source_loc, data_owner)
	var target_uuid = _get_uuid_from_loc(target_loc, data_owner)
	var source_instance = all_instances.get(source_uuid)
	var target_instance = all_instances.get(target_uuid)
	
	# --- TDD UNIFIED ACTION DECISION TREE ---
	# 1. Is the target an empty slot? Intent is MOVE.
	if not is_instance_valid(target_instance):
		_handle_move(source_loc, target_loc, data_owner)
		return

	# From here on, the target is another GachaBall.
	var def_a = source_instance.get_definition()
	var def_b = target_instance.get_definition()

	# 2. Check for EQUIP intent (symmetrically).
	if (def_a.category == &"UNIT" and def_b.category == &"ITEM") or \
	   (def_a.category == &"ITEM" and def_b.category == &"UNIT"):
		var unit_loc = source_loc if def_a.category == &"UNIT" else target_loc
		var item_loc = target_loc if def_a.category == &"UNIT" else source_loc
		_handle_equip(item_loc, unit_loc, data_owner)
		return

	# 3. If not an Equip action, check for MERGE intent.
	var recipe = MergeManager.find_recipe(def_a.id, def_b.id)
	if recipe:
		_pending_action = { "source_loc": source_loc, "target_loc": target_loc }
		WindowManager.open_dialog_window(&"ChoiceWindow")
		return

	# 4. Fallback: If it's not Move, Equip, or Merge, the intent is SWAP.
	_handle_swap(source_loc, target_loc, data_owner)

func _on_choice_made(choice: StringName):
	var source_loc = _pending_action.get("source_loc")
	var target_loc = _pending_action.get("target_loc")
	if not source_loc or not target_loc: return

	var data_owner = _get_data_owner()
	if choice == &"MERGE": _handle_merge(source_loc, target_loc, data_owner)
	elif choice == &"SWAP": _handle_swap(source_loc, target_loc, data_owner)
	_pending_action.clear()

# --- Action Handlers ---
func _handle_move(source_loc: LocationIdentifier, target_loc: LocationIdentifier, data_owner):
	var source_uuid = _get_uuid_from_loc(source_loc, data_owner)
	_set_uuid_at_loc(target_loc, source_uuid, data_owner)
	_set_uuid_at_loc(source_loc, "", data_owner)
	_finish_action(true)

func _handle_swap(source_loc: LocationIdentifier, target_loc: LocationIdentifier, data_owner):
	var source_uuid = _get_uuid_from_loc(source_loc, data_owner)
	var target_uuid = _get_uuid_from_loc(target_loc, data_owner)
	_set_uuid_at_loc(target_loc, source_uuid, data_owner)
	_set_uuid_at_loc(source_loc, target_uuid, data_owner)
	_finish_action(true)

func _handle_equip(item_loc: LocationIdentifier, unit_loc: LocationIdentifier, data_owner):
	if not GameManager.is_in_battle: # Equip is only possible in battle
		_handle_swap(item_loc, unit_loc, data_owner)
		return

	var all_instances = _get_all_instances(data_owner)
	var item_uuid = _get_uuid_from_loc(item_loc, data_owner)
	var unit_uuid = _get_uuid_from_loc(unit_loc, data_owner)
	var unit_instance = all_instances.get(unit_uuid)
	
	var empty_slot_idx = unit_instance.equipped_item_uuids.find("")
	if empty_slot_idx == -1: # No empty slots
		_handle_swap(item_loc, unit_loc, data_owner)
		return

	# Action is valid
	unit_instance.equipped_item_uuids[empty_slot_idx] = item_uuid
	_set_uuid_at_loc(item_loc, "", data_owner) # Remove item from its board slot
	EventBus.emit_signal("unit_inventory_changed", unit_uuid)
	_finish_action(true)

func _handle_merge(source_loc: LocationIdentifier, target_loc: LocationIdentifier, data_owner):
	var all_instances = _get_all_instances(data_owner)
	var source_uuid = _get_uuid_from_loc(source_loc, data_owner)
	var target_uuid = _get_uuid_from_loc(target_loc, data_owner)
	var source_instance = all_instances.get(source_uuid)
	var target_instance = all_instances.get(target_uuid)

	var recipe = MergeManager.find_recipe(source_instance.definition_id, target_instance.definition_id)
	if not recipe: return

	var result_def = Database.get_definition(recipe.result_id)
	var new_instance = GachaBallInstance.new()
	new_instance.initialize(result_def)
	
	# Add new instance to master list
	all_instances[new_instance.ball_uuid] = new_instance

	# Remove parents from their slots
	_set_uuid_at_loc(source_loc, "", data_owner)
	_set_uuid_at_loc(target_loc, "", data_owner)
	
	# Remove parent instances from the master instance database to prevent orphans
	all_instances.erase(source_uuid)
	all_instances.erase(target_uuid)
	
	# Place result in target's location
	_set_uuid_at_loc(target_loc, new_instance.ball_uuid, data_owner)

	_finish_action(true)

# --- Helper Functions ---
func _get_data_owner():
	if GameManager.is_in_battle:
		return get_tree().get_first_node_in_group("battle_manager")
	else:
		return GameManager.run_state

func _get_all_instances(owner) -> Dictionary:
	if GameManager.is_in_battle:
		return owner._battle_instances
	else:
		return owner.run_instances

func _get_uuid_from_loc(loc: LocationIdentifier, owner) -> String:
	var container: DataContainer
	if GameManager.is_in_battle:
		container = owner.get_container(loc.container)
	else: # RunState
		container = owner.run_inventory_containers.get(loc.container)
	
	if is_instance_valid(container):
		return container.get_uuid(loc.index)
	return ""

func _set_uuid_at_loc(loc: LocationIdentifier, uuid: String, owner):
	var container: DataContainer
	if GameManager.is_in_battle:
		container = owner.get_container(loc.container)
	else: # RunState
		container = owner.run_inventory_containers.get(loc.container)
	
	if is_instance_valid(container):
		container.set_uuid(loc.index, uuid)

func _finish_action(was_handled: bool):
	InteractionManager.end_drag(was_handled)
	var signal_name = "battle_inventory_changed" if GameManager.is_in_battle else "run_state_changed"
	EventBus.emit_signal(signal_name)

</details>