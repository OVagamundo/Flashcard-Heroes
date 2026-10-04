# res://scripts/GameManager.gd
extends Node

const SHOP_SCENE = preload("res://scenes/Shop.tscn")
const BLACK_MARKET_SCENE = preload("res://scenes/BlackMarket.tscn")
const REST_SITE_SCENE = preload("res://scenes/RestSite.tscn")

## Manages the persistent state of the current run by holding a RunState resource.
## Also acts as the single source of truth for the game's battle state.

var run_state: RunState
var is_in_battle: bool = false:
	set(val):
		is_in_battle = val
		AnimationConstants.is_in_battle = val
var is_test_mode: bool = false # Global flag for test environment
var _active_battle_manager: Node = null # ADD THIS LINE
var gacha_discounts_used: Dictionary = {1: false, 2: false, 3: false}

var director: WeightedPoolDirector = WeightedPoolDirector.new()
var director_run_state: DirectorRunState = DirectorRunState.new()

var _temporary_reward_master_dict: Dictionary = {}
var _temporary_reward_container: DataContainer = null # Will hold a FixedArrayContainer for rewards
var _temporary_gold_reward: int = 0
var _reward_reroll_cost: int = 1 # Reward reroll cost (resets per battle)
var _reward_room_active: bool = false
var _reward_study_used: bool = false

var _temporary_rest_site_prizes: Array[Dictionary] = []
var current_rest_site_type: int = 0 # 0: HP, 1: PWR, 2: GOLD
var _rest_site_active: bool = false
var _rest_site_study_used: bool = false
var _trinity_t1_drawn: bool = false
var _trinity_t2_drawn: bool = false
var _trinity_t3_drawn: bool = false
var _trinity_rewarded: bool = false

# Temporary shop state
var _temporary_shop_master_dict: Dictionary = {}
var _temporary_shop_container: DataContainer = null
var _reroll_cost: int = 1

var _active_main_node: Node = null # ADD THIS LINE
var loading_from_save: bool = false # Flag to prevent double day increment on load
var is_replay_run: bool = false
var run_metadata: Dictionary = {}

var test_starting_items: Array[StringName] = []

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
	SignalBus.black_market_action_requested.connect(_on_black_market_action_requested)
	SignalBus.path_choice_scene_requested.connect(_on_path_choice_scene_requested)

# ADD THESE TWO FUNCTIONS
func register_battle_manager(bm: Node) -> void:
	_active_battle_manager = bm

func unregister_battle_manager() -> void:
	_active_battle_manager = null

func register_main_node(node: Node) -> void:
	_active_main_node = node

func unregister_main_node() -> void:
	_active_main_node = null

func get_main_node() -> Node:
	return _active_main_node

func get_battle_manager() -> Node:
	return _active_battle_manager

func get_pending_rewards() -> Dictionary:
	return {
		"reward_instances": _temporary_reward_master_dict.values(),
		"gold_amount": _temporary_gold_reward,
		"reroll_cost": _reward_reroll_cost,
		"is_special_victory": run_state.current_boss_level > 0 or run_state.current_elite_level > 0
	}

## Returns logical and flow state used to verify each completed replay action.
## Presentation-only timing and cosmetic RNG are deliberately excluded.
func get_replay_state_snapshot() -> Dictionary:
	var run_snapshot: Dictionary = {}
	if is_instance_valid(run_state):
		run_snapshot = run_state.to_save_dict()
		run_snapshot.erase("elapsed_simulation_time")
		var rng_state: Dictionary = run_snapshot.get("rng_state", {}).duplicate(true)
		var rng_streams: Dictionary = rng_state.get("streams", {}).duplicate(true)
		rng_streams.erase("cosmetic")
		rng_state["streams"] = rng_streams
		run_snapshot["rng_state"] = rng_state

	var snapshot := {
		"run_state": run_snapshot,
		"is_in_battle": is_in_battle,
		"combat_speed_factor": AnimationConstants.speed_factor,
		"gacha_discounts_used": gacha_discounts_used.duplicate(true),
		"temporary_rewards": _snapshot_temporary_instances(_temporary_reward_master_dict),
		"temporary_shop": _snapshot_temporary_instances(_temporary_shop_master_dict),
		"temporary_gold_reward": _temporary_gold_reward,
		"reward_reroll_cost": _reward_reroll_cost,
		"reward_room_active": _reward_room_active,
		"reward_study_used": _reward_study_used,
		"shop_reroll_cost": _reroll_cost,
		"rest_site_type": current_rest_site_type,
		"rest_site_active": _rest_site_active,
		"rest_site_study_used": _rest_site_study_used,
		"rest_site_prizes": _temporary_rest_site_prizes.duplicate(true),
		"trinity_drawn": [_trinity_t1_drawn, _trinity_t2_drawn, _trinity_t3_drawn, _trinity_rewarded],
		"director_run_state": _snapshot_director_run_state_for_replay(director_run_state),
		"encounter_director_run_state": _snapshot_director_run_state_for_replay(EncounterGenerator.director_run_state),
		"tutorial_state": TutorialManager.get_state_snapshot() if is_instance_valid(TutorialManager) else {},
		"flashcard_state": FlashcardManager.get_replay_state_snapshot() if is_instance_valid(FlashcardManager) and FlashcardManager.has_method("get_replay_state_snapshot") else {},
		"battle_state": _active_battle_manager.get_replay_state_snapshot() if is_instance_valid(_active_battle_manager) and _active_battle_manager.has_method("get_replay_state_snapshot") else {}
	}
	return snapshot

func _snapshot_temporary_instances(instances: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var uuids: Array = instances.keys()
	uuids.sort()
	for uuid in uuids:
		var instance: Variant = instances[uuid]
		if is_instance_valid(instance) and instance.has_method("to_save_dict"):
			result.append({"uuid": String(uuid), "instance": instance.to_save_dict()})
	return result

## Captures non-RunState data needed to continue a replay from a save checkpoint.
func get_replay_manager_state() -> Dictionary:
	return {
		"gacha_discounts_used": gacha_discounts_used.duplicate(true),
		"temporary_rewards": _snapshot_temporary_instances(_temporary_reward_master_dict),
		"temporary_reward_container_size": _temporary_reward_container.get_size() if is_instance_valid(_temporary_reward_container) else 0,
		"temporary_shop": _snapshot_temporary_instances(_temporary_shop_master_dict),
		"temporary_shop_container_size": _temporary_shop_container.get_size() if is_instance_valid(_temporary_shop_container) else 0,
		"temporary_gold_reward": _temporary_gold_reward,
		"reward_reroll_cost": _reward_reroll_cost,
		"reward_room_active": _reward_room_active,
		"reward_study_used": _reward_study_used,
		"shop_reroll_cost": _reroll_cost,
		"rest_site_type": current_rest_site_type,
		"rest_site_active": _rest_site_active,
		"rest_site_study_used": _rest_site_study_used,
		"rest_site_prizes": _temporary_rest_site_prizes.duplicate(true),
		"trinity_drawn": [_trinity_t1_drawn, _trinity_t2_drawn, _trinity_t3_drawn, _trinity_rewarded],
		"is_in_battle": is_in_battle,
		"combat_speed_factor": AnimationConstants.speed_factor,
		"tutorial_state": TutorialManager.get_state_snapshot() if is_instance_valid(TutorialManager) else {},
		"director_run_state": _snapshot_director_run_state_for_replay(director_run_state),
		"encounter_director_run_state": _snapshot_director_run_state_for_replay(EncounterGenerator.director_run_state)
	}

func restore_replay_manager_state(data: Dictionary) -> void:
	_reset_replay_transient_state()
	var saved_discounts: Dictionary = data.get("gacha_discounts_used", {})
	gacha_discounts_used = {}
	for tier in [1, 2, 3]:
		gacha_discounts_used[tier] = bool(saved_discounts.get(str(tier), saved_discounts.get(tier, false)))
	_restore_temporary_instances(data.get("temporary_rewards", []), int(data.get("temporary_reward_container_size", 0)), true)
	_restore_temporary_instances(data.get("temporary_shop", []), int(data.get("temporary_shop_container_size", 0)), false)
	_temporary_gold_reward = int(data.get("temporary_gold_reward", 0))
	_reward_reroll_cost = int(data.get("reward_reroll_cost", 1))
	_reward_room_active = bool(data.get("reward_room_active", false))
	_reward_study_used = bool(data.get("reward_study_used", false))
	_reroll_cost = int(data.get("shop_reroll_cost", 1))
	current_rest_site_type = int(data.get("rest_site_type", 0))
	_rest_site_active = bool(data.get("rest_site_active", false))
	_rest_site_study_used = bool(data.get("rest_site_study_used", false))
	_temporary_rest_site_prizes.clear()
	for prize in data.get("rest_site_prizes", []):
		if prize is Dictionary:
			_temporary_rest_site_prizes.append(prize.duplicate(true))
	var trinity_state: Array = data.get("trinity_drawn", [false, false, false, false])
	_trinity_t1_drawn = bool(trinity_state[0]) if trinity_state.size() > 0 else false
	_trinity_t2_drawn = bool(trinity_state[1]) if trinity_state.size() > 1 else false
	_trinity_t3_drawn = bool(trinity_state[2]) if trinity_state.size() > 2 else false
	_trinity_rewarded = bool(trinity_state[3]) if trinity_state.size() > 3 else false
	is_in_battle = bool(data.get("is_in_battle", false))
	AnimationConstants.speed_factor = float(data.get("combat_speed_factor", 1.0))
	var tutorial_state: Variant = data.get("tutorial_state", {})
	if is_instance_valid(TutorialManager) and tutorial_state is Dictionary and not tutorial_state.is_empty():
		TutorialManager.set_temporary_replay_state(tutorial_state)
	director_run_state = _restore_director_run_state_from_replay(data.get("director_run_state", {}))
	EncounterGenerator.director_run_state = _restore_director_run_state_from_replay(data.get("encounter_director_run_state", {}))

func _restore_temporary_instances(serialized: Array, container_size: int, is_reward: bool) -> void:
	var instances: Dictionary = {}
	var container: DataContainer = null
	if container_size > 0:
		container = preload("res://scripts/FixedArrayContainer.gd").new(container_size)
	for entry in serialized:
		if not entry is Dictionary:
			continue
		var uuid := String(entry.get("uuid", ""))
		var instance_data: Variant = entry.get("instance", {})
		if uuid.is_empty() or not instance_data is Dictionary:
			continue
		var instance := GachaBallInstance.new()
		instance.from_save_dict(instance_data)
		instances[uuid] = instance
		if is_instance_valid(container):
			var slot := instance.location_slot_index
			if slot >= 0 and slot < container.get_size():
				container.set_uuid(slot, uuid)
	if is_reward:
		_temporary_reward_master_dict = instances
		_temporary_reward_container = container
	else:
		_temporary_shop_master_dict = instances
		_temporary_shop_container = container

func _snapshot_director_run_state_for_replay(state: DirectorRunState) -> Dictionary:
	if not is_instance_valid(state):
		return {}
	return {
		"current_purpose": int(state.current_purpose),
		"current_day": state.current_day,
		"player_gold": state.player_gold,
		"flashcard_mastery": state.flashcard_mastery,
		"unlock_percentage": state.unlock_percentage,
		"unlocked_recipes": state.unlocked_recipes.duplicate(),
		"encountered_bosses": state.encountered_bosses.duplicate(),
		"excluded_entity_ids": state.excluded_entity_ids.duplicate()
	}

func _restore_director_run_state_from_replay(data: Dictionary) -> DirectorRunState:
	var state := DirectorRunState.new()
	match int(data.get("current_purpose", DirectorRunState.Purpose.ANY)):
		DirectorRunState.Purpose.ENCOUNTER:
			state.current_purpose = DirectorRunState.Purpose.ENCOUNTER
		DirectorRunState.Purpose.SHOP:
			state.current_purpose = DirectorRunState.Purpose.SHOP
		DirectorRunState.Purpose.REWARD:
			state.current_purpose = DirectorRunState.Purpose.REWARD
		DirectorRunState.Purpose.NODE_GENERATION:
			state.current_purpose = DirectorRunState.Purpose.NODE_GENERATION
		_:
			state.current_purpose = DirectorRunState.Purpose.ANY
	state.current_day = int(data.get("current_day", 1))
	state.player_gold = int(data.get("player_gold", 0))
	state.flashcard_mastery = float(data.get("flashcard_mastery", 0.0))
	state.unlock_percentage = float(data.get("unlock_percentage", 0.0))
	for recipe_id in data.get("unlocked_recipes", []):
		state.unlocked_recipes.append(String(recipe_id))
	for boss_id in data.get("encountered_bosses", []):
		state.encountered_bosses.append(String(boss_id))
	for entity_id in data.get("excluded_entity_ids", []):
		state.excluded_entity_ids.append(StringName(entity_id))
	return state

func _on_start_run_requested(hero_def_id: StringName, deck_id: StringName, deck_order: String = "REGULAR", deck_size: String = "FULL") -> void:
	start_run_with_seed(hero_def_id, deck_id, deck_order, deck_size)

## Starts a normal run, or a deterministic replay fallback, using the same setup path.
## A seed of -1 preserves the existing random-seed behavior.
func start_run_with_seed(hero_def_id: StringName, deck_id: StringName, deck_order: String = "REGULAR", deck_size: String = "FULL", seed: int = -1, for_replay: bool = false, replay_run_id: String = "") -> void:
	# User Requirement: Start fresh tutorials every run if enabled
	if TutorialManager and not for_replay:
		TutorialManager.reset_all_tutorials()

	is_replay_run = for_replay
	loading_from_save = false
	var serialized_test_items: Array[String] = []
	for item_id in test_starting_items:
		serialized_test_items.append(String(item_id))
	run_metadata = {
		"hero_def_id": String(hero_def_id),
		"deck_id": String(deck_id),
		"deck_order": deck_order,
		"deck_size": deck_size,
		"run_options": {
			"tutorials_enabled": TutorialManager.tutorials_enabled if is_instance_valid(TutorialManager) else true,
			"is_test_mode": is_test_mode,
			"test_starting_items": serialized_test_items
		}
	}
	RNGManager.initialize(seed)
	UUIDUtils.clear_run_scope()
	_reset_replay_transient_state()
	run_state = RunState.new()
	run_state.initialize_run(hero_def_id, deck_id, deck_order, deck_size)
	run_state.run_seed = RNGManager.get_master_seed()
	run_state.run_id = replay_run_id if not replay_run_id.is_empty() else UUIDUtils.generate_uuid(&"run")
	UUIDUtils.begin_run_scope(run_state.run_id)
	reset_gacha_discounts()
	if is_instance_valid(ActionQueue):
		ActionQueue.reset_global_run_timer()
		ActionQueue.start_timer()
	generate_path_nodes()
	if not for_replay:
		SignalBus.run_initialized.emit(run_state, run_metadata.duplicate(true), false)
	SignalBus.emit_signal("main_scene_requested")

## Restores the recorded initial state before requesting the normal Main scene.
func start_replay_from_header(header: Dictionary) -> bool:
	is_replay_run = true
	loading_from_save = false
	ActionQueue.set_headless_mode(false)
	var options: Dictionary = header.get("run_options", {})
	is_test_mode = bool(options.get("is_test_mode", false))
	test_starting_items.clear()
	for item_id in options.get("test_starting_items", []):
		test_starting_items.append(StringName(item_id))
	run_metadata = {
		"hero_def_id": String(header.get("hero_def_id", header.get("hero_id", ""))),
		"deck_id": String(header.get("deck_id", "")),
		"deck_order": String(header.get("deck_order", "REGULAR")),
		"deck_size": String(header.get("deck_size", "FULL")),
		"run_options": options.duplicate(true)
	}
	if is_instance_valid(TutorialManager):
		TutorialManager.tutorials_enabled = bool(options.get("tutorials_enabled", TutorialManager.tutorials_enabled))

	_reset_replay_transient_state()
	var initial_state: Variant = header.get("initial_state", {})
	if initial_state is Dictionary and not initial_state.is_empty():
		RNGManager.initialize(int(header.get("run_seed", header.get("seed", 0))))
		run_state = RunState.new()
		run_state.from_save_dict(initial_state)
		if run_state.run_id.is_empty():
			run_state.run_id = String(header.get("run_id", ""))
		if run_state.run_seed == 0:
			run_state.run_seed = int(header.get("run_seed", header.get("seed", 0)))
		var initial_manager_state: Variant = header.get("initial_manager_state", {})
		if initial_manager_state is Dictionary:
			restore_replay_manager_state(initial_manager_state)
		else:
			reset_gacha_discounts()
		var start_time := float(initial_state.get("elapsed_simulation_time", 0.0))
		ActionQueue.reset_global_run_timer(start_time)
		ActionQueue.start_timer()
		SignalBus.emit_signal("main_scene_requested")
		return true

	# Backward-compatible path for older headers that only contain loadout and seed.
	var hero_id := StringName(header.get("hero_def_id", header.get("hero_id", "")))
	var deck_id := StringName(header.get("deck_id", ""))
	if hero_id.is_empty() or deck_id.is_empty():
		push_error("[GameManager] Replay header is missing its initial state and loadout.")
		return false
	start_run_with_seed(
		hero_id,
		deck_id,
		String(header.get("deck_order", "REGULAR")),
		String(header.get("deck_size", "FULL")),
		int(header.get("run_seed", header.get("seed", 0))),
		true,
		String(header.get("run_id", ""))
	)
	return true

func _reset_replay_transient_state() -> void:
	if is_instance_valid(FlashcardManager) and FlashcardManager.has_method("reset_session_state"):
		FlashcardManager.reset_session_state()
	_temporary_reward_master_dict.clear()
	_temporary_reward_container = null
	_temporary_gold_reward = 0
	_reward_reroll_cost = 1
	_reward_room_active = false
	_reward_study_used = false
	_temporary_rest_site_prizes.clear()
	current_rest_site_type = 0
	_rest_site_active = false
	_rest_site_study_used = false
	_trinity_t1_drawn = false
	_trinity_t2_drawn = false
	_trinity_t3_drawn = false
	_trinity_rewarded = false
	_temporary_shop_master_dict.clear()
	_temporary_shop_container = null
	_reroll_cost = 1
	reset_gacha_discounts()
	director_run_state = DirectorRunState.new()
	EncounterGenerator.director_run_state = DirectorRunState.new()
	is_in_battle = false

func resume_saved_run(loaded_state: RunState) -> void:
	if not is_instance_valid(loaded_state):
		return
	run_state = loaded_state
	is_replay_run = false
	loading_from_save = true
	run_metadata = {}
	if is_instance_valid(ActionQueue):
		ActionQueue.reset_global_run_timer(loaded_state.elapsed_simulation_time)
		ActionQueue.start_timer()
	SignalBus.run_initialized.emit(run_state, run_metadata, true)
	SignalBus.emit_signal("main_scene_requested")

## Replaces the live replay state at a recorded Continue checkpoint.
func restore_replay_checkpoint(state_data: Dictionary, manager_state: Dictionary = {}) -> bool:
	if state_data.is_empty():
		return false
	is_replay_run = true
	loading_from_save = true
	run_state = RunState.new()
	run_state.from_save_dict(state_data)
	if run_state.run_id.is_empty():
		run_state.run_id = String(manager_state.get("run_id", ""))
	restore_replay_manager_state(manager_state)
	ActionQueue.reset_global_run_timer(run_state.elapsed_simulation_time)
	ActionQueue.start_timer()
	return true

func _on_path_choice_scene_requested() -> void:
	if is_instance_valid(run_state) and run_state.available_path_nodes.is_empty():
		generate_path_nodes()

func _on_new_game_requested() -> void:
	# Default to first hero and deck if called without parameters
	var hero_defs = Database.get_hero_definitions()
	var deck_meta = Database.get_all_deck_metadata()
	if hero_defs.size() > 0 and deck_meta.size() > 0:
		_on_start_run_requested(hero_defs[0].id, deck_meta[0].deck_id, "REGULAR", "FULL")
	else:
		return

func _on_battle_ended(results: Dictionary) -> void:
	# Centralize post-battle handling per GIR.
	# 1) Flip global battle state off and broadcast.
	is_in_battle = false
	SignalBus.emit_signal("battle_state_changed", false)
	var is_victory: bool = bool(results.get("victory", false))
	
	# Track boss defeat
	if is_victory and run_state.current_boss_level > 0:
		run_state.bosses_defeated += 1
		
		var max_boss_level = 3 if run_state.is_half_deck else 5
		# Check for Boss victory (run complete)
		if run_state.current_boss_level == max_boss_level:
			_show_run_complete_popup()
			return

	# 3) If victory, pre-generate rewards now so the modal can be instant.
	if is_victory:
		if run_state.current_elite_level > 0:
			run_state.elites_defeated += 1
		
		# Emit the signal. The levels are NOT reset here, ensuring that 
		# _on_battle_won_rewards_pending can correctly identify the encounter type.
		SignalBus.emit_signal("battle_won_rewards_pending")
	
	# 4) Open the hermetic end-of-battle modal.
	WindowManager.open_modal_window(&"EndBattlePopup", {"is_victory": is_victory})

func _show_run_complete_popup() -> void:
	var flashcard_progress: Dictionary = {}
	if is_instance_valid(run_state) and run_state.flashcard_progress != null:
		flashcard_progress = run_state.flashcard_progress
		
	var context = {
		"days": run_state.day,
		"bosses_defeated": run_state.bosses_defeated,
		"enemies_defeated": run_state.total_enemies_defeated,
		"elites_defeated": run_state.elites_defeated,
		"gold_earned": run_state.total_gold_earned,
		"tokens_earned": run_state.total_tokens_earned,
		"flashcard_progress": flashcard_progress
	}
	WindowManager.open_modal_window(&"RunCompletePopup", context)

func _update_director_run_state(purpose: int = DirectorRunState.Purpose.ANY) -> void:
	if not is_instance_valid(run_state):
		return
	director_run_state.current_day = run_state.day
	director_run_state.player_gold = run_state.gold
	director_run_state.unlock_percentage = run_state.get_deck_unlock_percentage()
	director_run_state.current_purpose = purpose as DirectorRunState.Purpose
	# flashcard_mastery calculation could go here if available
	director_run_state.unlocked_recipes.clear()
	for r_id in run_state.unlocked_recipes.keys():
		if run_state.unlocked_recipes[r_id]:
			director_run_state.unlocked_recipes.append(String(r_id))
			
	director_run_state.clear_exclusions()
	var trinket_container = run_state.get_container(RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS)
	if is_instance_valid(trinket_container):
		for uuid in trinket_container.get_all_non_empty_uuids():
			var inst = run_state.get_instance_by_uuid(uuid)
			if is_instance_valid(inst):
				var def = inst.get_definition()
				if is_instance_valid(def):
					director_run_state.exclude_entity(def.id)

func _on_battle_start_requested(_encounter_def: EncounterDefinition) -> void:
	pass

func _on_battle_won_rewards_pending() -> void:
	# Detect if this was a boss or elite victory (both get trinket rewards)
	var is_special_victory = run_state.current_boss_level > 0 or run_state.current_elite_level > 0
	
	# Reset reward reroll cost for new rewards
	_reward_reroll_cost = 1
	_reward_study_used = false
	
	# Generate rewards for the victory and store them.
	_temporary_reward_master_dict.clear()
	_temporary_reward_container = preload("res://scripts/FixedArrayContainer.gd").new(3)
	
	if is_special_victory:
		# Boss rewards: 3 random trinkets (use Director if they are WeightableEntities)
		var eligible_trinkets: Array[Resource] = []
		for t in Database.trinkets.values():
			if t is TrinketDefinition and not t.is_enemy_exclusive:
				eligible_trinkets.append(t)
		_update_director_run_state(DirectorRunState.Purpose.REWARD)
		var drawn_trinkets = director.draw_unique_items(eligible_trinkets, director_run_state, 3)
		
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
	SignalBus.run_ending.emit("returned_to_title")
	if is_instance_valid(FlashcardManager) and FlashcardManager.has_method("reset_session_state"):
		FlashcardManager.reset_session_state()
	run_state = null
	if not (is_instance_valid(ActionQueue) and ActionQueue.is_replay_mode()):
		is_replay_run = false
	if is_instance_valid(ActionQueue):
		ActionQueue.pause_timer()
		ActionQueue.reset_global_run_timer()
	if is_instance_valid(WindowManager):
		WindowManager.close_all_windows()
	# Clear any temporary rewards if the player quits or loses.
	_temporary_reward_master_dict.clear()
	_temporary_reward_container = null
	_reward_room_active = false
	_reward_study_used = false
	_temporary_rest_site_prizes.clear()
	_rest_site_active = false
	_rest_site_study_used = false
	current_rest_site_type = 0
	_trinity_t1_drawn = false
	_trinity_t2_drawn = false
	_trinity_t3_drawn = false
	_trinity_rewarded = false



func _on_battle_victory_acknowledged() -> void:
	# Day should only increment when path choice scene loads, not here
	
	# Calculate gold reward based on reward type
	var is_special = run_state.current_boss_level > 0 or run_state.current_elite_level > 0
	_reward_room_active = true
			
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

	# The regular Reward scene draws fresh capsules. Prepare its data before
	# requesting the scene so the same state exists in visual and headless runs.
	# Preserve the existing generation/RNG calls above for behavior parity.
	var context: Dictionary = get_pending_rewards()
	if not is_special:
		_temporary_reward_master_dict.clear()
		_temporary_reward_container = preload("res://scripts/FixedArrayContainer.gd").new(5)
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
			
			if is_instance_valid(_temporary_reward_container):
				var slot_idx = _temporary_reward_container.get_index_of_uuid(chosen_uuid)
				if slot_idx != -1:
					_temporary_reward_container.set_uuid(slot_idx, "")
			
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

## Authoritative data method to sell a pending reward capsule, credit gold, and clear temporary containers.
func sell_reward_instance(instance_uuid: String) -> int:
	if not _temporary_reward_master_dict.has(instance_uuid):
		return 0
	var instance: GachaBallInstance = _temporary_reward_master_dict[instance_uuid]
	var gold_yield: int = 1
	if is_instance_valid(run_state) and (run_state.current_boss_level > 0 or run_state.current_elite_level > 0):
		gold_yield = 10
	elif is_instance_valid(instance):
		var unit_value = instance.get_gold_value()
		gold_yield = max(1, int(unit_value * 0.5))
	
	if is_instance_valid(run_state):
		run_state.add_gold(gold_yield)
		
	if is_instance_valid(_temporary_reward_container):
		var slot_idx = _temporary_reward_container.get_index_of_uuid(instance_uuid)
		if slot_idx != -1:
			_temporary_reward_container.set_uuid(slot_idx, "")
	_temporary_reward_master_dict.erase(instance_uuid)
	
	SignalBus.emit_signal("selection_clear_requested")
	return gold_yield

## Temporary debug function to inspect the pending reward master dictionary
# Removed redundant functions that were replaced by the new temporary instance system

## Retrieves a GachaBallInstance from any location, whether in battle or not.
## This is the central, authoritative function for resolving a LocationIdentifier to an instance.
## Returns null if the location is invalid or the instance cannot be found.
## Central helper to calculate the gold cost of a definition based on the 1/2/4 economy model.
func get_item_cost(def: Resource) -> int:
	if not is_instance_valid(def): return 1
	
	var base_cost: int = 1
	if "cost" in def:
		base_cost = int(def.cost)
	
	# Valuation scales by 2^(Level-1)
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
	if is_instance_valid(run_state):
		run_state.available_path_nodes.clear()
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
				_active_main_node.load_content(preload("res://scenes/MergeEncounter.tscn"))
		"DOJO":
			if is_instance_valid(run_state):
				run_state.current_room_tokens = 0
			if is_instance_valid(_active_main_node):
				_active_main_node.load_content(preload("res://scenes/UnitTrainingGround.tscn"))
		"GOLD":
			_prepare_rest_site_entry(2) # GOLD
			if is_instance_valid(_active_main_node):
				var inst = _active_main_node.load_content(REST_SITE_SCENE)
				if inst is ResourceSite:
					inst.site_type = ResourceSite.SiteType.GOLD
					inst.setup_site()
		"SURPRISE":
			var roll = RNGManager.map_rng.randi_range(0, 2)
			_prepare_rest_site_entry(0 if roll == 0 else (2 if roll == 1 else 1))
			if is_instance_valid(_active_main_node):
				var site_t = ResourceSite.SiteType.HP if roll == 0 else (ResourceSite.SiteType.GOLD if roll == 1 else ResourceSite.SiteType.PWR)
				var inst = _active_main_node.load_content(REST_SITE_SCENE)
				if inst is ResourceSite:
					inst.site_type = site_t
					inst.setup_site()

func _prepare_rest_site_entry(site_type: int) -> void:
	current_rest_site_type = site_type
	_rest_site_active = true
	_temporary_rest_site_prizes.clear()
	_rest_site_study_used = false
	if is_instance_valid(run_state) and is_instance_valid(run_state.hero_instance):
		var hero_definition: Resource = run_state.hero_instance.get_definition()
		if is_instance_valid(hero_definition) and hero_definition.id == &"hero_timekeeper":
			run_state.current_room_tokens = 5

func finish_rest_site_leave() -> void:
	_rest_site_active = false
	_rest_site_study_used = false
	_temporary_rest_site_prizes.clear()
	current_rest_site_type = 0

func finish_reward_room_leave() -> void:
	_reward_room_active = false
	_reward_study_used = false

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

## Simulates and executes an atomic shop purchase transaction.
## Returns a structured event log for presentation playback.
func simulate_shop_purchase(instance_uuid: String, cost: int) -> Dictionary:
	if not _temporary_shop_master_dict.has(instance_uuid):
		return {"success": false, "error": "Instance not found in shop"}
	if not is_instance_valid(run_state) or not run_state.spend_gold(cost):
		return {"success": false, "error": "Insufficient gold"}

	var purchased_instance: GachaBallInstance = _temporary_shop_master_dict[instance_uuid]
	var def = purchased_instance.get_definition()
	var container_name: StringName
	if is_instance_valid(def) and def.category == &"TRINKET":
		container_name = RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS
	else:
		var tier_val: int = (int(def.tier) if (def is GachaBallDefinition) else 1)
		container_name = &"RunInventoryT%d" % tier_val

	run_state.add_instance(purchased_instance, container_name, -1)

	if is_instance_valid(def):
		run_state.unlock_recipe_for_result(def.id)

	var slot_index: int = -1
	if is_instance_valid(_temporary_shop_container):
		slot_index = _temporary_shop_container.get_all_uuids().find(instance_uuid)
		if slot_index != -1:
			_temporary_shop_container.set_uuid(slot_index, "")

	_temporary_shop_master_dict.erase(instance_uuid)

	SignalBus.emit_signal("selection_clear_requested")

	var context: Dictionary = {"shop_instances": _temporary_shop_master_dict.values(), "reroll_cost": _reroll_cost}
	SignalBus.emit_signal("shop_stock_refreshed", context)

	return {
		"success": true,
		"transaction_type": &"SHOP_PURCHASE",
		"instance_uuid": instance_uuid,
		"purchased_instance": purchased_instance,
		"cost": cost,
		"slot_index": slot_index,
		"target_container": container_name,
		"remaining_gold": run_state.gold
	}

func _on_shop_purchase_requested(instance_uuid: String, cost: int) -> void:
	simulate_shop_purchase(instance_uuid, cost)

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
	
	_generate_reward_stock()

	# Refresh the reward scene with new rewards
	var context: Dictionary = get_pending_rewards()
	SignalBus.emit_signal("reward_stock_refreshed", context)

func _generate_reward_stock() -> void:
	# Regenerate rewards (reroll functionality)
	
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

func has_trinket(trinket_id: StringName) -> bool:
	if not is_instance_valid(run_state):
		return false
	var container = run_state.get_container(RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS)
	if not is_instance_valid(container):
		return false
	for uuid in container.get_all_non_empty_uuids():
		var inst = run_state.get_instance_by_uuid(uuid)
		if is_instance_valid(inst):
			var def = inst.get_definition()
			if is_instance_valid(def) and def.id == trinket_id:
				return true
	return false

func get_base_gacha_token_cost(tier: int) -> int:
	# Base cost could be affected by other things in the future
	return tier

func get_gacha_token_cost(tier: int) -> int:
	var base_cost = get_base_gacha_token_cost(tier)
	var cost = base_cost
	if is_bargain_charm_active(tier):
		cost -= 1
	return max(1, cost)

func is_bargain_charm_active(tier: int) -> bool:
	if not has_trinket(&"trinket_bargain_charm"):
		return false
	if gacha_discounts_used.get(tier, false):
		return false
	var base_cost = get_base_gacha_token_cost(tier)
	return max(1, base_cost - 1) < max(1, base_cost)

func use_gacha_discount(tier: int) -> void:
	gacha_discounts_used[tier] = true

func reset_gacha_discounts() -> void:
	gacha_discounts_used = {1: false, 2: false, 3: false}

func get_black_market_transform_cost() -> int:
	return 5

func get_transform_result(source_definition: GachaBallDefinition) -> GachaBallDefinition:
	var eligible: Array[GachaBallDefinition] = []
	for definition in Database.get_all_pool_definitions():
		if not is_instance_valid(definition):
			continue
		if definition.id == source_definition.id:
			continue
		if definition.tier != source_definition.tier:
			continue
		if definition.category != source_definition.category:
			continue
		eligible.append(definition)

	if eligible.is_empty():
		return null
	return RNGManager.gacha_rng.pick_random(eligible)

func _on_black_market_action_requested(payload: Dictionary) -> void:
	if not is_instance_valid(run_state):
		return
		
	if payload.type == "remove":
		var cost: int = payload.cost
		var instance_uuid: String = payload.instance_uuid
		if run_state.spend_gold(cost):
			run_state.remove_instance(instance_uuid)
			if run_state.has_method("increase_black_market_remove_cost"):
				run_state.increase_black_market_remove_cost()
				
	elif payload.type == "transform":
		var cost: int = payload.cost
		var instance_uuid: String = payload.instance_uuid
		var source_location: LocationIdentifier = payload.source_location
		var result_definition: GachaBallDefinition = payload.result_definition
		var source_level: int = payload.get("source_level", 1)
		
		if not is_instance_valid(result_definition): return
		
		if run_state.spend_gold(cost):
			run_state.remove_instance(instance_uuid)
			
			var new_instance := GachaBallInstance.new()
			new_instance.initialize(result_definition)
			new_instance.level = source_level
			run_state.add_instance(new_instance, source_location.container, source_location.index)
			run_state.unlock_recipe_for_result(result_definition.id)

func generate_path_nodes() -> Array[PathNodeDefinition]:
	if not is_instance_valid(run_state):
		return []
	
	if loading_from_save:
		loading_from_save = false
		if not run_state.available_path_nodes.is_empty():
			return run_state.available_path_nodes
	
	run_state.advance_day(1)
	
	_update_director_run_state(DirectorRunState.Purpose.NODE_GENERATION)
	
	var is_half_deck = run_state.is_half_deck
	var boss_level: int = run_state.bosses_defeated + 1
	var threshold: float = boss_level * 0.2
	var max_bosses: int = 5
	if is_half_deck:
		threshold = boss_level * 0.3333
		max_bosses = 3
	
	var selected_nodes: Array[PathNodeDefinition] = []
	if director_run_state.unlock_percentage >= (threshold - 0.001) and boss_level <= max_bosses:
		var node_def = PathNodeDefinition.new()
		node_def.node_type = "BATTLE"
		node_def.subtype = "BOSS"
		node_def.display_name_key = "ui.boss"
		node_def.boss_level = boss_level
		node_def.difficulty = boss_level
		selected_nodes.append(node_def)
	else:
		var types = [
			{"type": "BATTLE", "subtype": "", "name": "ui.battle_node"},
			{"type": "BATTLE", "subtype": "ELITE", "name": "ui.elite_battle_node"},
			{"type": "SHOP", "subtype": "", "name": "ui.shop_node"},
			{"type": "BLACK_MARKET", "subtype": "", "name": "ui.black_market_node"},
			{"type": "REST", "subtype": "", "name": "ui.rest_node"},
			{"type": "DOJO", "subtype": "", "name": "ui.training_grounds_node"},
			{"type": "SURPRISE", "subtype": "", "name": "ui.surprise_node"}
		]
		var pool: Array[PathNodeDefinition] = []
		var current_day = run_state.day
		for t in types:
			var base_w = 50
			if t.type == "BATTLE" and t.subtype == "":
				base_w = 100
			elif t.type == "BATTLE" and t.subtype == "ELITE":
				var elite_day_threshold = 3 if is_half_deck else 5
				if current_day < elite_day_threshold:
					base_w = 20
				else:
					base_w = 80
			var dict_key = t.type
			if t.subtype != "":
				dict_key += "_" + t.subtype
			var last_offered = run_state.encounter_last_offered_day.get(dict_key, 0)
			var days_since = current_day - last_offered
			var final_weight = base_w + (days_since * 20)
			
			var def = PathNodeDefinition.new()
			def.node_type = t.type
			def.subtype = t.subtype
			def.display_name_key = t.name
			def.base_weight = final_weight
			pool.append(def)
		
		for i in range(3):
			if pool.is_empty():
				break
			var drawn = director.draw_item(pool, director_run_state, RNGManager.map_rng)
			if is_instance_valid(drawn):
				selected_nodes.append(drawn)
				var next_pool: Array[PathNodeDefinition] = []
				for p in pool:
					if p.node_type != drawn.node_type or p.subtype != drawn.subtype:
						next_pool.append(p)
				pool = next_pool

	run_state.available_path_nodes = selected_nodes

	for node_def in selected_nodes:
		var dict_key = node_def.node_type
		if node_def.subtype != "":
			dict_key += "_" + node_def.subtype
		run_state.encounter_last_offered_day[dict_key] = run_state.day

	if not is_replay_run:
		SaveManager.save_run(run_state)

	return selected_nodes

func create_reward_draw(tier: int, slot_index: int = -1) -> GachaBallInstance:
	if not is_instance_valid(run_state):
		return null
	var cost = get_gacha_token_cost(tier)
	if run_state.get_room_tokens() < cost:
		return null
	
	run_state.spend_room_tokens(cost)
	use_gacha_discount(tier)
	
	if _temporary_reward_container == null:
		_temporary_reward_container = preload("res://scripts/FixedArrayContainer.gd").new(5)
	
	if slot_index == -1:
		slot_index = _temporary_reward_container.find_first_empty_slot()
		if slot_index == -1:
			return null
			
	var eligible: Array[GachaBallDefinition] = []
	for definition in Database.get_all_pool_definitions():
		if not is_instance_valid(definition): continue
		if definition.tier != tier: continue
		eligible.append(definition)
	
	if eligible.is_empty():
		return null
		
	var definition = RNGManager.reward_rng.pick_random(eligible)
	var instance = GachaBallInstance.new()
	instance.initialize(definition)
	instance.location_container_tag = &"Rewards"
	instance.location_slot_index = slot_index
	_temporary_reward_master_dict[instance.ball_uuid] = instance
	_temporary_reward_container.set_uuid(slot_index, instance.ball_uuid)
	
	if has_trinket(&"trinket_trinity_charm") and not _trinity_rewarded:
		if tier == 1: _trinity_t1_drawn = true
		elif tier == 2: _trinity_t2_drawn = true
		elif tier == 3: _trinity_t3_drawn = true
		if _trinity_t1_drawn and _trinity_t2_drawn and _trinity_t3_drawn:
			_trinity_rewarded = true
			run_state.add_room_tokens(1)
			
	return instance

## Rolls a training reward value (stat increase or gold) for a given tier (1, 2, or 3 tokens).
## Uses a middle-weighted bell curve distribution with rare 0s and rare top prizes:
## - Tier 1 (Cost 1): Range 0-2 (0: 10%, 1: 80%, 2: 10%)
## - Tier 2 (Cost 2): Range 0-3 (0: 10%, 1: 40%, 2: 40%, 3: 10%)
## - Tier 3 (Cost 3): Range 0-5 (0: 5%, 1: 15%, 2: 30%, 3: 30%, 4: 15%, 5: 5%)
func roll_training_reward(tier: int) -> int:
	var roll_pct = RNGManager.reward_rng.randi_range(1, 100)
	match tier:
		1:
			if roll_pct <= 10: return 0
			if roll_pct <= 90: return 1
			return 2
		2:
			if roll_pct <= 10: return 0
			if roll_pct <= 50: return 1
			if roll_pct <= 90: return 2
			return 3
		3:
			if roll_pct <= 5: return 0
			if roll_pct <= 20: return 1
			if roll_pct <= 50: return 2
			if roll_pct <= 80: return 3
			if roll_pct <= 95: return 4
			return 5
		_:
			assert(false, "roll_training_reward: Invalid tier %d" % tier)
			return 0

## Simulates and executes an atomic Rest Site draw transaction.
## Returns a structured event log for presentation playback.
func simulate_rest_site_draw(tier: int) -> Dictionary:
	if not is_instance_valid(run_state):
		return {"success": false, "error": "No active run_state"}
	var cost = tier
	if run_state.get_room_tokens() < cost:
		return {"success": false, "error": "Insufficient room tokens"}
	run_state.spend_room_tokens(cost)
	
	var value = roll_training_reward(tier)
	
	var slot_index = -1
	for i in range(4):
		var has_prize = false
		for p in _temporary_rest_site_prizes:
			if p.slot_index == i:
				has_prize = true
				break
		if not has_prize:
			slot_index = i
			break
			
	if slot_index == -1:
		if not _temporary_rest_site_prizes.is_empty():
			var oldest = _temporary_rest_site_prizes[0]
			_apply_rest_site_prize_data(oldest)
			_temporary_rest_site_prizes.remove_at(0)
			for rem in _temporary_rest_site_prizes:
				if rem.slot_index > 0:
					rem.slot_index -= 1
			slot_index = 3
		else:
			slot_index = 0
			
	var prize_data = {
		"slot_index": slot_index,
		"hp_value": value if current_rest_site_type == 0 else 0,
		"pwr_value": value if current_rest_site_type == 1 else 0,
		"gold_value": value if current_rest_site_type == 2 else 0
	}
	_temporary_rest_site_prizes.append(prize_data)
	return {
		"success": true,
		"transaction_type": &"REST_SITE_DRAW",
		"tier": tier,
		"cost": cost,
		"prize_data": prize_data,
		"remaining_tokens": run_state.get_room_tokens(),
		"prizes_snapshot": _temporary_rest_site_prizes.duplicate(true)
	}

func roll_rest_site_prize(tier: int) -> Dictionary:
	var res = simulate_rest_site_draw(tier)
	return res.get("prize_data", {})

## Simulates and executes an atomic Dojo training transaction.
## Returns a structured event log for presentation playback.
func simulate_dojo_training(token_cost: int) -> Dictionary:
	if not is_instance_valid(run_state):
		return {"success": false, "error": "No active run_state"}
	if run_state.get_room_tokens() < token_cost:
		return {"success": false, "error": "Insufficient room tokens"}
		
	run_state.spend_room_tokens(token_cost)
	var roll = roll_training_reward(token_cost)
	var uuid = run_state.training_unit_uuid
	var stat = run_state.training_stat
	var hp_delta = 0
	var pwr_delta = 0
	if uuid != "" and roll > 0:
		hp_delta = roll if stat == "hp" else 0
		pwr_delta = roll if stat == "pwr" else 0
		run_state.modify_unit_base_stats(uuid, hp_delta, pwr_delta)
		
	return {
		"success": true,
		"transaction_type": &"DOJO_TRAIN",
		"token_cost": token_cost,
		"roll": roll,
		"unit_uuid": uuid,
		"training_stat": stat,
		"hp_delta": hp_delta,
		"pwr_delta": pwr_delta,
		"remaining_tokens": run_state.get_room_tokens()
	}

func claim_rest_site_prize(slot_index: int) -> Dictionary:
	for i in range(_temporary_rest_site_prizes.size()):
		if _temporary_rest_site_prizes[i].slot_index == slot_index:
			var prize = _temporary_rest_site_prizes[i]
			_temporary_rest_site_prizes.remove_at(i)
			_apply_rest_site_prize_data(prize)
			return prize
	return {}

func _apply_rest_site_prize_data(prize_data: Dictionary) -> void:
	if not is_instance_valid(run_state):
		return
	if current_rest_site_type == 2: # GOLD
		run_state.add_gold(prize_data.get("gold_value", 0))
	elif is_instance_valid(run_state.hero_instance):
		var hero_uuid = run_state.hero_instance.ball_uuid
		run_state.modify_unit_base_stats(hero_uuid, prize_data.get("hp_value", 0), prize_data.get("pwr_value", 0))

func auto_claim_all_rest_site_prizes() -> void:
	while not _temporary_rest_site_prizes.is_empty():
		var p = _temporary_rest_site_prizes[0]
		_temporary_rest_site_prizes.remove_at(0)
		_apply_rest_site_prize_data(p)
