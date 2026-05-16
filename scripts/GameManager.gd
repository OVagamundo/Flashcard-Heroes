# res://scripts/GameManager.gd
extends Node

const SHOP_SCENE = preload("res://scenes/Shop.tscn")
const BLACK_MARKET_SCENE = preload("res://scenes/BlackMarket.tscn")
const REST_SITE_SCENE = preload("res://scenes/RestSite.tscn")

## Manages the persistent state of the current run by holding a RunState resource.
## Also acts as the single source of truth for the game's battle state.

var run_state: RunState
var is_in_battle: bool = false # The global authority on whether a battle is active.
var is_test_mode: bool = false # Global flag for test environment
var _active_battle_manager: Node = null # ADD THIS LINE

var director: WeightedPoolDirector = WeightedPoolDirector.new()
var director_run_state: DirectorRunState = DirectorRunState.new()

var _temporary_reward_master_dict: Dictionary = {}
var _temporary_reward_container: DataContainer = null # Will hold a FixedArrayContainer for rewards
var _temporary_gold_reward: int = 0
var _reward_reroll_cost: int = 1 # Reward reroll cost (resets per battle)

# Temporary shop state
var _temporary_shop_master_dict: Dictionary = {}
var _temporary_shop_container: DataContainer = null
var _reroll_cost: int = 1

var _active_main_node: Node = null # ADD THIS LINE
var loading_from_save: bool = false # Flag to prevent double day increment on load

# These functions are deprecated - use get_instance_from_location instead

func _ready() -> void:
	# Connect to signals to manage the run and battle state.
	SignalBus.start_run_requested.connect(_on_start_run_requested)
	SignalBus.battle_state_changed.connect(func(in_battle): is_in_battle = in_battle)
	SignalBus.title_scene_requested.connect(_on_return_to_title)
	SignalBus.battle_victory_acknowledged.connect(_on_battle_victory_acknowledged)
	SignalBus.battle_start_requested.connect(_on_battle_start_requested)
	SignalBus.battle_won_rewards_pending.connect(_on_battle_won_rewards_pending)
	SignalBus.battle_ended.connect(_on_battle_ended)

	SignalBus.reward_chosen.connect(_on_reward_chosen)
	SignalBus.node_selected.connect(_on_node_selected)
	SignalBus.shop_purchase_requested.connect(_on_shop_purchase_requested)
	SignalBus.shop_reroll_requested.connect(_on_shop_reroll_requested)
	SignalBus.reward_reroll_requested.connect(_on_reward_reroll_requested)

# ADD THESE TWO FUNCTIONS
func register_battle_manager(bm: Node) -> void:
	_active_battle_manager = bm

func unregister_battle_manager() -> void:
	_active_battle_manager = null

func register_main_node(node: Node) -> void:
	_active_main_node = node

func unregister_main_node() -> void:
	_active_main_node = null

func get_pending_rewards() -> Dictionary:
	return {
		"reward_instances": _temporary_reward_master_dict.values(),
		"gold_amount": _temporary_gold_reward,
		"reroll_cost": _reward_reroll_cost,
		"is_special_victory": run_state.current_boss_level > 0 or run_state.current_elite_level > 0
	}

func _on_start_run_requested(hero_def_id: StringName, deck_id: StringName) -> void:
	# User Requirement: Start fresh tutorials every run if enabled
	if TutorialManager:
		TutorialManager.reset_all_tutorials()
		
	run_state = RunState.new()
	run_state.initialize_run(hero_def_id, deck_id)
	SignalBus.emit_signal("main_scene_requested")

func _on_new_game_requested() -> void:
	# Default to first hero and deck if called without parameters
	var hero_defs = Database.get_hero_definitions()
	var deck_meta = Database.get_all_deck_metadata()
	if hero_defs.size() > 0 and deck_meta.size() > 0:
		_on_start_run_requested(hero_defs[0].id, deck_meta[0].deck_id)
	else:
		return

func _on_battle_ended(results: Dictionary) -> void:
	print("[GameManager] _on_battle_ended called with results: ", results)
	# Centralize post-battle handling per GIR.
	# 1) Flip global battle state off and broadcast.
	is_in_battle = false
	SignalBus.emit_signal("battle_state_changed", false)
	var is_victory: bool = bool(results.get("victory", false))
	
	# Track boss defeat
	if is_victory and run_state.current_boss_level > 0:
		print("[GameManager] Boss victory detected! Level: ", run_state.current_boss_level)
		run_state.bosses_defeated += 1
		
		# Check for Boss 5 victory (run complete)
		if run_state.current_boss_level == 5:
			_show_run_complete_popup()
			return

	# 3) If victory, pre-generate rewards now so the modal can be instant.
	if is_victory:
		if run_state.current_boss_level > 0:
			run_state.bosses_defeated += 1
		if run_state.current_elite_level > 0:
			run_state.elites_defeated += 1
			
		run_state.total_enemies_defeated += 1
		
		# Emit the signal. The levels are NOT reset here, ensuring that 
		# _on_battle_won_rewards_pending can correctly identify the encounter type.
		print("[GameManager] Victory confirmed, emitting battle_won_rewards_pending. EliteLvl: ", run_state.current_elite_level)
		SignalBus.emit_signal("battle_won_rewards_pending")
	
	# 4) Open the hermetic end-of-battle modal.
	WindowManager.open_modal_window(&"EndBattlePopup", {"is_victory": is_victory})

func _show_run_complete_popup() -> void:
	var context = {
		"days": run_state.day,
		"bosses_defeated": run_state.bosses_defeated,
		"enemies_defeated": run_state.total_enemies_defeated,
		"gold_earned": run_state.total_gold_earned
	}
	WindowManager.open_modal_window(&"RunCompletePopup", context)

func _update_director_run_state(purpose: int = DirectorRunState.Purpose.ANY) -> void:
	if not is_instance_valid(run_state):
		return
	director_run_state.current_day = run_state.day
	director_run_state.player_gold = run_state.gold
	director_run_state.current_purpose = purpose as DirectorRunState.Purpose
	# flashcard_mastery calculation could go here if available
	director_run_state.unlocked_recipes.clear()
	for r_id in run_state.unlocked_recipes.keys():
		if run_state.unlocked_recipes[r_id]:
			director_run_state.unlocked_recipes.append(String(r_id))

func _on_battle_start_requested(_encounter_def: EncounterDefinition) -> void:
	pass

func _on_battle_won_rewards_pending() -> void:
	# Detect if this was a boss or elite victory (both get trinket rewards)
	var is_special_victory = run_state.current_boss_level > 0 or run_state.current_elite_level > 0
	print("[RewardDebug] Victory rewards pending. Special: ", is_special_victory)
	
	# Reset reward reroll cost for new rewards
	_reward_reroll_cost = 1
	
	# Generate rewards for the victory and store them.
	_temporary_reward_master_dict.clear()
	_temporary_reward_container = preload("res://scripts/FixedArrayContainer.gd").new(3)
	
	if is_special_victory:
		# Boss rewards: 3 random trinkets (use Director if they are WeightableEntities)
		var all_trinkets = Database.trinkets.values().duplicate()
		_update_director_run_state(DirectorRunState.Purpose.REWARD)
		var drawn_trinkets = director.draw_unique_items(all_trinkets, director_run_state, 3)
		
		for i in range(drawn_trinkets.size()):
			var inst = GachaBallInstance.new()
			inst.initialize_from_trinket(drawn_trinkets[i])
			inst.location_container_tag = &"Rewards"
			inst.location_slot_index = i
			_temporary_reward_master_dict[inst.ball_uuid] = inst
			_temporary_reward_container.set_uuid(i, inst.ball_uuid)
	else:
		# Regular rewards: gacha balls from dynamic pool using Director
		var all_defs = Database.get_all_pool_definitions()
		if all_defs.is_empty():
			push_error("[GameManager] Reward pool definitions are empty!")
			return
			
		_update_director_run_state(DirectorRunState.Purpose.REWARD)
		var drawn_rewards = director.draw_unique_items(all_defs, director_run_state, 3)
		
		for i in range(drawn_rewards.size()):
			var inst = GachaBallInstance.new()
			inst.initialize(drawn_rewards[i])
			inst.location_container_tag = &"Rewards"
			inst.location_slot_index = i
			_temporary_reward_master_dict[inst.ball_uuid] = inst
			_temporary_reward_container.set_uuid(i, inst.ball_uuid)

func get_reward_instance(index: int) -> GachaBallInstance:
	if not is_instance_valid(_temporary_reward_container):
		return null
	var uuid = _temporary_reward_container.get_uuid(index)
	if uuid:
		return _temporary_reward_master_dict.get(uuid)
	return null

func _on_return_to_title() -> void:
	# Clear the run state and any pending rewards when returning to the title screen
	run_state = null
	# Clear any temporary rewards if the player quits or loses.
	_temporary_reward_master_dict.clear()
	_temporary_reward_container = null


func _on_battle_victory_acknowledged() -> void:
	# Day should only increment when path choice scene loads, not here
	
	# Calculate gold reward based on reward type
	var is_special = run_state.current_boss_level > 0 or run_state.current_elite_level > 0
			
	if is_special:
		_temporary_gold_reward = 10
	else:
		# Regular rewards: calculate from cost (average cost of the 3 rewards)
		var sum_costs = 0
		for inst in _temporary_reward_master_dict.values():
			var def = inst.get_definition()
			if is_instance_valid(def):
				sum_costs += get_item_cost(def)
		
		_temporary_gold_reward = max(1, int(round(float(sum_costs) / 3.0)))

	# Signal the UI to display the pre-generated rewards.
	var context: Dictionary = get_pending_rewards()
	SignalBus.emit_signal("reward_scene_requested", context)

func _on_reward_chosen(payload) -> void:
	# --- STALE SELECTION FIX ---
	# The action is complete. Clear the interaction state immediately.
	SignalBus.emit_signal("selection_clear_requested")

	if payload.type == "gachaball":
		var chosen_uuid: String = payload.get("instance_uuid", "")
		if chosen_uuid and _temporary_reward_master_dict.has(chosen_uuid):
			var selected_instance = _temporary_reward_master_dict[chosen_uuid]
			var def = selected_instance.get_definition()
			
			# Clear the temporary reward location before adding to run state
			selected_instance.location_container_tag = &""
			selected_instance.location_slot_index = -1
			
			# Route based on category/type; Trinkets go to dedicated player trinkets container
			var container_name: StringName
			if is_instance_valid(def) and def.category == &"TRINKET":
				container_name = RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS
			else:
				var tier_val: int = (int(def.tier) if (def is GachaBallDefinition) else 1)
				container_name = &"RunInventoryT%d" % tier_val
			# Atomic add handles index/registry/truth updates and signals
			run_state.add_instance(selected_instance, container_name, -1)
			
			# Unlock recipes for this acquired gachaball
			if is_instance_valid(def):
				run_state.unlock_recipe_for_result(def.id)
			
	elif payload.type == "gold":
		run_state.add_gold(payload.get("amount", 0))

	# --- TRANSITION LOGIC REMOVED ---
	# The scene transition is now handled by the new button in Reward.gd.
	# We still need to clean up the temporary data and signal that the run data has changed.
	
	# Reset levels ONLY AFTER the choice is processed and data is cleared
	run_state.current_boss_level = 0
	run_state.current_elite_level = 0

## Temporary debug function to inspect the pending reward master dictionary
# Removed redundant functions that were replaced by the new temporary instance system

## Retrieves a GachaBallInstance from any location, whether in battle or not.
## This is the central, authoritative function for resolving a LocationIdentifier to an instance.
## Returns null if the location is invalid or the instance cannot be found.
## Central helper to calculate the gold cost of a definition based on the 1/2/4 economy model.
func get_item_cost(def: Resource) -> int:
	if not is_instance_valid(def): return 1
	
	var tier: int = 1
	if "tier" in def:
		tier = int(def.tier)
	
	# Trinkets are valued as Tier 3 base
	if "category" in def and def.category == &"TRINKET":
		tier = 3
	
	# Base cost per tier: T1=1, T2=2, T3+=4
	var base_cost: int = 1
	if tier >= 3:
		base_cost = 4
	elif tier == 2:
		base_cost = 2
	
	# Valuation scales by 2^(Level-1)
	# T1L1=1, T1L2=2, T1L3=4
	# T3L1=4, T3L2=8, T3L3=16
	var level: int = 1
	if "level" in def:
		level = int(def.level)
		
	var multiplier: int = int(pow(2, level - 1))
	return base_cost * multiplier

## Central authoritative function to find any instance by its UUID.
## This should be used instead of direct lookups in BattleManager or RunState.
func get_instance_by_uuid(uuid: String) -> GachaBallInstance:
	if uuid.is_empty():
		return null

	# 1. Check temporary context first (e.g., rewards, shop)
	if _temporary_reward_master_dict.has(uuid):
		return _temporary_reward_master_dict[uuid]

	if _temporary_shop_master_dict.has(uuid):
		return _temporary_shop_master_dict[uuid]

	# 2. Check battle or run context
	if is_in_battle and is_instance_valid(_active_battle_manager):
		return _active_battle_manager.get_instance(uuid)
	else:
		if is_instance_valid(run_state):
			return run_state.get_instance_by_uuid(uuid)
	
	# 3. Fallback if not found anywhere
	return null

## Gets an instance from a location identifier
func get_instance_from_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc):
		return null

	# NEW: Check for the temporary reward context FIRST.
	if loc.container == &"Rewards":
		if _temporary_reward_container and _temporary_reward_master_dict:
			var uuid = _temporary_reward_container.get_uuid(loc.index)
			if not uuid.is_empty():
				return _temporary_reward_master_dict.get(uuid)
		return null # Return null if the reward context is not active or slot is empty.

	# NEW: Check for the temporary shop context.
	if loc.container == &"Shop":
		if _temporary_shop_container and _temporary_shop_master_dict:
			var uuid = _temporary_shop_container.get_uuid(loc.index)
			if not uuid.is_empty():
				return _temporary_shop_master_dict.get(uuid)
		return null # Return null if the shop context is not active or slot is empty.

	# Step 1: Determine the current context (battle or run) to get the right data source.
	var data_owner: Object
	if is_in_battle:
		data_owner = _active_battle_manager
	else:
		data_owner = run_state

	if not is_instance_valid(data_owner):
		return null

	# Step 2: Apply contextual understanding based on the location type.
	
	# Case A: The location is for an equipped item (a conceptual location).
	if loc.container == C.CONTAINER_EQUIPPED_ITEM:
		if loc.unit_uuid.is_empty():
			return null
		
		var all_instances_db = data_owner.get_all_instances()
		var parent_unit: GachaBallInstance = all_instances_db.get(loc.unit_uuid)
		
		if not is_instance_valid(parent_unit):
			return null
		
		var item_uuid = parent_unit.get_equipped_item_uuid(loc.index)
		if item_uuid.is_empty():
			return null # The slot is empty.
		
		return all_instances_db.get(item_uuid)

	# Case B: The location is a standard physical container.
	# Delegate the simple lookup to the appropriate data owner.
	else:
		if data_owner.has_method("get_instance_by_location"):
			return data_owner.get_instance_by_location(loc)

	# Fallback if no valid case is met.
	return null

func _on_node_selected(node_def: PathNodeDefinition) -> void:
	match node_def.node_type:
		"BATTLE":
			var encounter_def: EncounterDefinition
			# Standardized budget formula: base 3 + 1 per day after first
			var daily_budget: int = 3 + (run_state.day - 1) * 1
			
			if node_def.subtype == "BOSS":
				# Boss encounter - boss is free, support units use daily budget
				var boss_level: int = node_def.difficulty
				encounter_def = EncounterGenerator.generate_boss_encounter(boss_level, daily_budget, run_state.day)
				# Track current boss level for victory handling
				run_state.current_boss_level = boss_level
				run_state.current_elite_level = 0
			elif node_def.subtype == "ELITE":
				# Elite encounter - uses standard daily budget (has free elite unit)
				# Pass history for weighted pity system
				var budget: int = daily_budget
				encounter_def = EncounterGenerator.generate_elite_encounter(budget, run_state.elite_encounter_history, run_state.last_elite_id)
				
				# Record encounter in history immediately upon generation/selection
				var elite_id = encounter_def.get_meta("elite_boss_id")
				if elite_id is StringName:
					run_state.record_elite_encounter(elite_id)
				
				# Track elite level for victory handling (trinket rewards)
				run_state.current_elite_level = 1
				run_state.current_boss_level = 0
			else:
				# Regular encounter - uses daily budget
				encounter_def = EncounterGenerator.generate_encounter(daily_budget)
				run_state.current_boss_level = 0
				run_state.current_elite_level = 0
			
			# Use registered Main node
			if is_instance_valid(_active_main_node):
				_active_main_node._on_battle_start_requested(encounter_def)
		"SHOP":
			_enter_shop()
		"BLACK_MARKET":
			if is_instance_valid(_active_main_node):
				_active_main_node.load_content(BLACK_MARKET_SCENE)
		"REST":
			if is_instance_valid(_active_main_node):
				var inst = _active_main_node.load_content(REST_SITE_SCENE)
				if inst is ResourceSite:
					inst.site_type = ResourceSite.SiteType.HP
					inst.setup_site()
		"DOJO":
			if is_instance_valid(_active_main_node):
				var inst = _active_main_node.load_content(REST_SITE_SCENE)
				if inst is ResourceSite:
					inst.site_type = ResourceSite.SiteType.PWR
					inst.setup_site()
		"GOLD":
			if is_instance_valid(_active_main_node):
				var inst = _active_main_node.load_content(REST_SITE_SCENE)
				if inst is ResourceSite:
					inst.site_type = ResourceSite.SiteType.GOLD
					inst.setup_site()
		"SURPRISE":
			if is_instance_valid(_active_main_node):
				var options = [
					preload("res://scenes/UnitTrainingGround.tscn"),
					preload("res://scenes/MergeEncounter.tscn")
				]
				var chosen_scene = options[randi() % options.size()]
				_active_main_node.load_content(chosen_scene)

func _enter_shop() -> void:
	_reroll_cost = 1
	_generate_shop_stock()
	var context: Dictionary = {"shop_instances": _temporary_shop_master_dict.values(), "reroll_cost": _reroll_cost}
	# Use registered Main node
	if is_instance_valid(_active_main_node):
		_active_main_node._on_shop_scene_requested(context)

func _generate_shop_stock() -> void:
	_temporary_shop_master_dict.clear()
	_temporary_shop_container = preload("res://scripts/FixedArrayContainer.gd").new(3)
	
	var all_defs = Database.get_all_pool_definitions()
	if all_defs.is_empty(): return
	
	_update_director_run_state(DirectorRunState.Purpose.SHOP)
	var drawn_shop_items = director.draw_unique_items(all_defs, director_run_state, 3)
	
	for i in range(drawn_shop_items.size()):
		var def = drawn_shop_items[i]
		var inst = GachaBallInstance.new()
		inst.initialize(def)
		
		inst.location_container_tag = &"Shop"
		inst.location_slot_index = i
		
		_temporary_shop_master_dict[inst.ball_uuid] = inst
		_temporary_shop_container.set_uuid(i, inst.ball_uuid)

func _on_shop_purchase_requested(instance_uuid: String, cost: int) -> void:
	if not _temporary_shop_master_dict.has(instance_uuid): return
	if not run_state.spend_gold(cost): return

	var purchased_instance = _temporary_shop_master_dict[instance_uuid]
	var def = purchased_instance.get_definition()
	# Route based on category/type; Trinkets go to dedicated player trinkets container
	var container_name: StringName
	if is_instance_valid(def) and def.category == &"TRINKET":
		container_name = RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS
	else:
		var tier_val: int = (int(def.tier) if (def is GachaBallDefinition) else 1)
		container_name = &"RunInventoryT%d" % tier_val
	# Atomic add handles container slot selection and registry updates
	run_state.add_instance(purchased_instance, container_name, -1)
	
	# Unlock recipes for this acquired gachaball
	if is_instance_valid(def):
		run_state.unlock_recipe_for_result(def.id)

	_temporary_shop_master_dict.erase(instance_uuid)
	var temp_slot = _temporary_shop_container.get_all_uuids().find(instance_uuid)
	if temp_slot != -1:
		_temporary_shop_container.set_uuid(temp_slot, "")

	SignalBus.emit_signal("selection_clear_requested")

	# Avoid duplicate run_data_changed; atomic APIs already emitted above
	var context: Dictionary = {"shop_instances": _temporary_shop_master_dict.values(), "reroll_cost": _reroll_cost}
	SignalBus.emit_signal("shop_stock_refreshed", context)

func _on_shop_reroll_requested() -> void:
	if not run_state.spend_gold(_reroll_cost): return
	_reroll_cost += 1

	_generate_shop_stock()

	# Avoid duplicate run_data_changed; spend_gold already emitted
	var context: Dictionary = {"shop_instances": _temporary_shop_master_dict.values(), "reroll_cost": _reroll_cost}
	SignalBus.emit_signal("shop_stock_refreshed", context)

func _on_reward_reroll_requested() -> void:
	if not run_state.spend_gold(_reward_reroll_cost): return
	_reward_reroll_cost += 1
	
	print("[RewardDebug] Reroll requested. Cost paid. Generating new stock...")
	_generate_reward_stock()

	# Refresh the reward scene with new rewards
	var context: Dictionary = get_pending_rewards()
	SignalBus.emit_signal("reward_stock_refreshed", context)

func _generate_reward_stock() -> void:
	# Regenerate rewards (reroll functionality)
	print("[RewardDebug] generate_reward_stock. Special: ", run_state.current_boss_level > 0 or run_state.current_elite_level > 0)
	
	_temporary_reward_master_dict.clear()
	_temporary_reward_container = preload("res://scripts/FixedArrayContainer.gd").new(3)
	
	if run_state.current_boss_level > 0 or run_state.current_elite_level > 0:
		# Boss/Elite rewards: 3 random trinkets using Director
		var all_trinkets = Database.trinkets.values().duplicate()
		_update_director_run_state(DirectorRunState.Purpose.REWARD)
		var drawn_trinkets = director.draw_unique_items(all_trinkets, director_run_state, 3)
		
		for i in range(drawn_trinkets.size()):
			var inst = GachaBallInstance.new()
			inst.initialize_from_trinket(drawn_trinkets[i])
			inst.location_container_tag = &"Rewards"
			inst.location_slot_index = i
			_temporary_reward_master_dict[inst.ball_uuid] = inst
			_temporary_reward_container.set_uuid(i, inst.ball_uuid)
	else:
		# Regular rewards: gacha balls from dynamic pool using Director
		var all_defs = Database.get_all_pool_definitions()
		if all_defs.is_empty(): return
		
		_update_director_run_state(DirectorRunState.Purpose.REWARD)
		var drawn_rewards = director.draw_unique_items(all_defs, director_run_state, 3)
		
		for i in range(drawn_rewards.size()):
			var inst = GachaBallInstance.new()
			inst.initialize(drawn_rewards[i])
			inst.location_container_tag = &"Rewards"
			inst.location_slot_index = i
			_temporary_reward_master_dict[inst.ball_uuid] = inst
			_temporary_reward_container.set_uuid(i, inst.ball_uuid)
