# res://scripts/GameManager.gd
extends Node

const C = preload("res://scripts/Constants.gd")
const SHOP_SCENE = preload("res://scenes/Shop.tscn")
const SHRINE_SCENE = preload("res://scenes/Shrine.tscn")
const REST_SITE_SCENE = preload("res://scenes/RestSite.tscn")
const FixedArrayContainerScript = preload("res://scripts/FixedArrayContainer.gd")

## Manages the persistent state of the current run (RunState), scene/encounter flow,
## central location/UUID lookup, and coordinates replay/transaction subsystems.

var run_state: RunState
var is_in_battle: bool = false:
	set(val):
		is_in_battle = val
		AnimationConstants.is_in_battle = val
var _active_battle_manager: Node = null
var gacha_discounts_used: Dictionary = {1: false, 2: false, 3: false}

var director: WeightedPoolDirector = WeightedPoolDirector.new()
var director_run_state: DirectorRunState = DirectorRunState.new()

var _temporary_reward_master_dict: Dictionary = {}
var _temporary_reward_container: DataContainer = null
var _temporary_gold_reward: int = 0
var _reward_reroll_cost: int = 1
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

var _temporary_shop_master_dict: Dictionary = {}
var _temporary_shop_container: DataContainer = null
var _reroll_cost: int = 1

var _active_main_node: Node = null
var loading_from_save: bool = false
var is_replay_run: bool = false
var run_metadata: Dictionary = {}
var test_starting_items: Array[StringName] = []


func _ready() -> void:
	SignalBus.start_run_requested.connect(_on_start_run_requested)
	SignalBus.battle_state_changed.connect(func(in_battle: bool) -> void: is_in_battle = in_battle)
	SignalBus.title_scene_requested.connect(_on_return_to_title)
	SignalBus.battle_victory_acknowledged.connect(_on_battle_victory_acknowledged)
	SignalBus.battle_won_rewards_pending.connect(_on_battle_won_rewards_pending)
	SignalBus.battle_ended.connect(_on_battle_ended)

	SignalBus.reward_chosen.connect(_on_reward_chosen)
	SignalBus.node_selected.connect(_on_node_selected)
	SignalBus.shop_purchase_requested.connect(_on_shop_purchase_requested)
	SignalBus.shop_reroll_requested.connect(_on_shop_reroll_requested)
	SignalBus.reward_reroll_requested.connect(_on_reward_reroll_requested)
	SignalBus.shrine_action_requested.connect(_on_shrine_action_requested)
	SignalBus.path_choice_scene_requested.connect(_on_path_choice_scene_requested)


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
	var reroll_cost: int = run_state.get_elite_reward_reroll_cost() if is_instance_valid(run_state) else 5
	return {
		"reward_instances": _temporary_reward_master_dict.values(),
		"gold_amount": _temporary_gold_reward,
		"reroll_cost": reroll_cost,
		"is_special_victory": run_state.current_boss_level > 0 or run_state.current_elite_level > 0,
	}


# =============================================================================
# REPLAY & CHECKPOINT SERIALIZATION DELEGATES
# =============================================================================

func get_replay_state_snapshot() -> Dictionary:
	return ReplayStateSerializer.build_replay_state_snapshot(self)


func get_replay_manager_state() -> Dictionary:
	return ReplayStateSerializer.build_replay_manager_state(self)


func restore_replay_manager_state(data: Dictionary) -> void:
	ReplayStateSerializer.restore_replay_manager_state(self, data)


# =============================================================================
# RUN LIFECYCLE
# =============================================================================

func _on_start_run_requested(hero_def_id: StringName, deck_id: StringName, deck_order: String = "REGULAR", deck_size: String = "FULL") -> void:
	start_run_with_seed(hero_def_id, deck_id, deck_order, deck_size)


func start_run_with_seed(hero_def_id: StringName, deck_id: StringName, deck_order: String = "REGULAR", deck_size: String = "FULL", seed: int = -1, for_replay: bool = false, replay_run_id: String = "") -> void:
	if not for_replay:
		TutorialManager.reset_all_tutorials()

	is_replay_run = for_replay
	loading_from_save = false
	var serialized_test_items: Array[String] = []
	for item_id: StringName in test_starting_items:
		serialized_test_items.append(String(item_id))
	run_metadata = {
		"hero_def_id": String(hero_def_id),
		"deck_id": String(deck_id),
		"deck_order": deck_order,
		"deck_size": deck_size,
		"run_options": {
			"tutorials_enabled": TutorialManager.tutorials_enabled,
			"test_starting_items": serialized_test_items,
		},
	}
	if seed == -1 and not for_replay:
		seed = SaveManager.get_loadout_seed()
	RNGManager.initialize(seed)
	UUIDUtils.clear_run_scope()
	_reset_replay_transient_state()
	run_state = RunState.new()
	run_state.run_seed = RNGManager.get_master_seed()
	run_state.initialize_run(hero_def_id, deck_id, deck_order, deck_size)
	run_state.run_id = replay_run_id if not replay_run_id.is_empty() else UUIDUtils.generate_uuid(&"run")
	UUIDUtils.begin_run_scope(run_state.run_id)
	reset_gacha_discounts()
	ActionQueue.reset_global_run_timer()
	ActionQueue.start_timer()
	generate_path_nodes()
	if not for_replay:
		SignalBus.run_initialized.emit(run_state, run_metadata.duplicate(true), false)
	SignalBus.main_scene_requested.emit()


func start_replay_from_header(header: Dictionary) -> bool:
	is_replay_run = true
	loading_from_save = false
	ActionQueue.set_headless_mode(false)
	var options: Dictionary = header.get("run_options", {})
	test_starting_items.clear()
	for item_id in options.get("test_starting_items", []):
		test_starting_items.append(StringName(item_id))
	run_metadata = {
		"hero_def_id": String(header.get("hero_def_id", header.get("hero_id", ""))),
		"deck_id": String(header.get("deck_id", "")),
		"deck_order": String(header.get("deck_order", "REGULAR")),
		"deck_size": String(header.get("deck_size", "FULL")),
		"run_options": options.duplicate(true),
	}
	TutorialManager.tutorials_enabled = bool(options.get("tutorials_enabled", TutorialManager.tutorials_enabled))

	_reset_replay_transient_state()
	var initial_state: Variant = header.get("initial_state", {})
	if initial_state is Dictionary and not (initial_state as Dictionary).is_empty():
		RNGManager.initialize(int(header.get("run_seed", header.get("seed", 0))))
		run_state = RunState.new()
		run_state.from_save_dict(initial_state as Dictionary)
		if run_state.run_id.is_empty():
			run_state.run_id = String(header.get("run_id", ""))
		if run_state.run_seed == 0:
			run_state.run_seed = int(header.get("run_seed", header.get("seed", 0)))
		var initial_manager_state: Variant = header.get("initial_manager_state", {})
		if initial_manager_state is Dictionary:
			restore_replay_manager_state(initial_manager_state as Dictionary)
		else:
			reset_gacha_discounts()
		ActionQueue.reset_global_run_timer(float((initial_state as Dictionary).get("elapsed_simulation_time", 0.0)))
		ActionQueue.start_timer()
		SignalBus.main_scene_requested.emit()
		return true

	var hero_id: StringName = StringName(header.get("hero_def_id", header.get("hero_id", "")))
	var deck_id: StringName = StringName(header.get("deck_id", ""))
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
	FlashcardManager.reset_session_state()
	_temporary_reward_master_dict.clear()
	_temporary_reward_container = null
	_temporary_gold_reward = 0
	_reward_reroll_cost = 5
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
	ActionQueue.reset_global_run_timer(loaded_state.elapsed_simulation_time)
	ActionQueue.start_timer()
	SignalBus.run_initialized.emit(run_state, run_metadata, true)
	SignalBus.main_scene_requested.emit()


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


func _on_return_to_title() -> void:
	SignalBus.run_ending.emit("returned_to_title")
	FlashcardManager.reset_session_state()
	run_state = null
	if not ActionQueue.is_replay_mode():
		is_replay_run = false
	ActionQueue.pause_timer()
	ActionQueue.reset_global_run_timer()
	WindowManager.close_all_windows()
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


# =============================================================================
# BATTLE & NODE TRANSITIONS
# =============================================================================

func _on_battle_ended(results: Dictionary) -> void:
	if is_instance_valid(run_state):
		run_state.next_battle_minigame_bonus_time = 0.0
	SignalBus.minigame_bonus_time_changed.emit(0.0)
	is_in_battle = false
	SignalBus.battle_state_changed.emit(false)
	var is_victory: bool = bool(results.get("victory", false))

	if is_victory and run_state.current_boss_level > 0:
		var boss_level: int = run_state.current_boss_level
		run_state.defeated_boss_marker_positions[boss_level] = run_state.get_boss_marker_position(boss_level)
		run_state.bosses_defeated += 1
		run_state.refresh_boss_reveals()
		SignalBus.run_data_changed.emit()
		run_state.elites_encountered_in_tier = 0
		run_state.elite_milestones_offered.clear()
		if run_state.current_boss_level == run_state.get_boss_count():
			_show_run_complete_popup()
			return

	if is_victory:
		if run_state.current_elite_level > 0:
			run_state.elites_defeated += 1
		SignalBus.battle_won_rewards_pending.emit()

	WindowManager.open_modal_window(&"EndBattlePopup", {"is_victory": is_victory})


func _show_run_complete_popup() -> void:
	var flashcard_progress: Dictionary = run_state.flashcard_progress if (is_instance_valid(run_state) and run_state.flashcard_progress != null) else {}
	WindowManager.open_modal_window(&"RunCompletePopup", {
		"days": run_state.day,
		"bosses_defeated": run_state.bosses_defeated,
		"enemies_defeated": run_state.total_enemies_defeated,
		"elites_defeated": run_state.elites_defeated,
		"gold_earned": run_state.total_gold_earned,
		"tokens_earned": run_state.total_tokens_earned,
		"flashcard_progress": flashcard_progress,
	})


func _on_battle_won_rewards_pending() -> void:
	_reward_study_used = false
	EncounterTransactionEngine.generate_reward_stock(self)


func _on_battle_victory_acknowledged() -> void:
	var is_special: bool = run_state.current_boss_level > 0 or run_state.current_elite_level > 0
	_reward_room_active = true
	if is_instance_valid(run_state):
		run_state.reset_room_tokens()
	reset_gacha_discounts()
	_trinity_t1_drawn = false
	_trinity_t2_drawn = false
	_trinity_t3_drawn = false
	_trinity_rewarded = false

	if is_special:
		_temporary_gold_reward = 10
	else:
		var sum_costs: int = 0
		for inst in _temporary_reward_master_dict.values():
			var def: Resource = (inst as GachaBallInstance).get_definition()
			if is_instance_valid(def):
				sum_costs += get_item_cost(def)
		_temporary_gold_reward = maxi(1, int(round(float(sum_costs) / 3.0)))

	var context: Dictionary = get_pending_rewards()
	if not is_special:
		_temporary_reward_master_dict.clear()
		_temporary_reward_container = FixedArrayContainerScript.new(5)
	SignalBus.reward_scene_requested.emit(context)


func _on_node_selected(node_def: PathNodeDefinition) -> void:
	if is_instance_valid(run_state):
		run_state.available_path_nodes.clear()
		run_state.reset_room_tokens()
	match node_def.node_type:
		"BATTLE":
			var encounter_def: EncounterDefinition
			var daily_budget: int = 3 + (run_state.day - 1)
			if node_def.subtype == "BOSS":
				var boss_level: int = node_def.difficulty
				encounter_def = EncounterGenerator.generate_boss_encounter(boss_level, daily_budget, run_state.day, run_state.reveal_boss(boss_level))
				run_state.current_boss_level = boss_level
				run_state.current_elite_level = 0
			elif node_def.subtype == "ELITE":
				encounter_def = EncounterGenerator.generate_elite_encounter(daily_budget, run_state.elite_encounter_history, run_state.last_elite_id)
				if encounter_def.boss_or_elite_unit_id != &"":
					run_state.record_elite_encounter(encounter_def.boss_or_elite_unit_id)
				run_state.current_elite_level = 1
				run_state.current_boss_level = 0
				run_state.elites_encountered_in_tier += 1
			else:
				encounter_def = EncounterGenerator.generate_encounter(daily_budget)
				if encounter_def.banner_trinket_id != &"":
					run_state.record_regular_banner(encounter_def.banner_trinket_id)
				run_state.current_boss_level = 0
				run_state.current_elite_level = 0
			if is_instance_valid(_active_main_node):
				_active_main_node._on_battle_start_requested(encounter_def)
		"SHOP":
			_enter_shop()
		"SHRINE":
			if is_instance_valid(_active_main_node):
				_active_main_node.load_content(SHRINE_SCENE)
		"MERGE":
			if is_instance_valid(_active_main_node):
				_active_main_node.load_content(preload("res://scenes/MergeEncounter.tscn"))
		"DOJO":
			if is_instance_valid(_active_main_node):
				_active_main_node.load_content(preload("res://scenes/UnitTrainingGround.tscn"))
		"GOLD":
			_prepare_rest_site_entry(2)
			if is_instance_valid(_active_main_node):
				var inst: Node = _active_main_node.load_content(REST_SITE_SCENE)
				if inst is ResourceSite:
					(inst as ResourceSite).site_type = ResourceSite.SiteType.GOLD
					(inst as ResourceSite).setup_site()
		"SURPRISE":
			var roll: int = RNGManager.map_rng.randi_range(0, 2)
			_prepare_rest_site_entry(0 if roll == 0 else (2 if roll == 1 else 1))
			if is_instance_valid(_active_main_node):
				var site_t: ResourceSite.SiteType = ResourceSite.SiteType.HP if roll == 0 else (ResourceSite.SiteType.GOLD if roll == 1 else ResourceSite.SiteType.PWR)
				var inst: Node = _active_main_node.load_content(REST_SITE_SCENE)
				if inst is ResourceSite:
					(inst as ResourceSite).site_type = site_t
					(inst as ResourceSite).setup_site()


func _prepare_rest_site_entry(site_type: int) -> void:
	current_rest_site_type = site_type
	_rest_site_active = true
	_temporary_rest_site_prizes.clear()
	_rest_site_study_used = false
	if is_instance_valid(run_state):
		run_state.reset_room_tokens()
		if is_instance_valid(run_state.hero_instance):
			var hero_definition: Resource = run_state.hero_instance.get_definition()
			if is_instance_valid(hero_definition) and hero_definition.id == &"hero_timekeeper":
				run_state.current_room_tokens = 5


func finish_rest_site_leave() -> void:
	_rest_site_active = false
	_rest_site_study_used = false
	_temporary_rest_site_prizes.clear()
	current_rest_site_type = 0
	if is_instance_valid(run_state):
		run_state.reset_room_tokens()


func finish_reward_room_leave() -> void:
	_reward_room_active = false
	_reward_study_used = false
	reset_gacha_discounts()
	_trinity_t1_drawn = false
	_trinity_t2_drawn = false
	_trinity_t3_drawn = false
	_trinity_rewarded = false
	if is_instance_valid(run_state):
		run_state.reset_room_tokens()
		run_state.current_boss_level = 0
		run_state.current_elite_level = 0


func _enter_shop() -> void:
	_reroll_cost = 1
	EncounterTransactionEngine.generate_shop_stock(self)
	if is_instance_valid(_active_main_node):
		_active_main_node._on_shop_scene_requested({
			"shop_instances": _temporary_shop_master_dict.values(),
			"reroll_cost": _reroll_cost,
		})


# =============================================================================
# CENTRAL INSTANCE, ECONOMY & TRINKET QUERIES
# =============================================================================

func get_reward_instance(index: int) -> GachaBallInstance:
	if not is_instance_valid(_temporary_reward_container):
		return null
	var uuid: String = _temporary_reward_container.get_uuid(index)
	return _temporary_reward_master_dict.get(uuid) as GachaBallInstance if not uuid.is_empty() else null


func get_item_cost(def: Resource) -> int:
	if not is_instance_valid(def):
		return 1
	if "cost" in def:
		return int(def.cost)
	if "tier" in def:
		var tier_val: int = int(def.tier)
		if tier_val <= 0:
			return 0
		var level_val: int = maxi(1, int(def.level)) if "level" in def else 1
		return (1 << (tier_val - 1)) * (1 << (level_val - 1))
	return 1


func get_instance_by_uuid(uuid: String) -> GachaBallInstance:
	if uuid.is_empty():
		return null
	if _temporary_reward_master_dict.has(uuid):
		return _temporary_reward_master_dict[uuid] as GachaBallInstance
	if _temporary_shop_master_dict.has(uuid):
		return _temporary_shop_master_dict[uuid] as GachaBallInstance
	if is_in_battle and is_instance_valid(_active_battle_manager):
		return (_active_battle_manager as BattleManager).get_instance(uuid)
	if is_instance_valid(run_state):
		return run_state.get_instance_by_uuid(uuid)
	return null


func get_instance_from_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc):
		return null
	if loc.container == &"Rewards":
		if is_instance_valid(_temporary_reward_container):
			var uuid: String = _temporary_reward_container.get_uuid(loc.index)
			return _temporary_reward_master_dict.get(uuid) as GachaBallInstance if not uuid.is_empty() else null
		return null
	if loc.container == &"Shop":
		if is_instance_valid(_temporary_shop_container):
			var uuid: String = _temporary_shop_container.get_uuid(loc.index)
			return _temporary_shop_master_dict.get(uuid) as GachaBallInstance if not uuid.is_empty() else null
		return null

	var use_battle_owner: bool = is_in_battle and not String(loc.container).begins_with("RunInventoryT")
	var bm: BattleManager = _active_battle_manager as BattleManager if use_battle_owner else null
	var owner_valid: bool = is_instance_valid(bm) if use_battle_owner else is_instance_valid(run_state)
	if not owner_valid:
		return null

	if loc.container == C.CONTAINER_EQUIPPED_ITEM:
		if loc.unit_uuid.is_empty():
			return null
		var all_instances_db: Dictionary = bm.get_all_instances() if use_battle_owner else run_state.get_all_instances()
		var parent_unit: GachaBallInstance = all_instances_db.get(loc.unit_uuid) as GachaBallInstance
		if not is_instance_valid(parent_unit):
			return null
		var item_uuid: String = parent_unit.get_equipped_item_uuid(loc.index)
		return all_instances_db.get(item_uuid) as GachaBallInstance if not item_uuid.is_empty() else null

	return bm.get_instance_by_location(loc) if use_battle_owner else run_state.get_instance_by_location(loc)


func has_trinket(trinket_id: StringName) -> bool:
	if is_instance_valid(run_state):
		var container: DataContainer = run_state.get_container(RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS)
		if is_instance_valid(container):
			for uuid: String in container.get_all_non_empty_uuids():
				var inst: GachaBallInstance = run_state.get_instance_by_uuid(uuid)
				if is_instance_valid(inst):
					var def: Resource = inst.get_definition()
					if is_instance_valid(def) and def.id == trinket_id:
						return true
	if is_in_battle:
		var bm: BattleManager = _active_battle_manager as BattleManager
		if is_instance_valid(bm) and is_instance_valid(bm._state):
			var container: DataContainer = bm._state.get_container(&"PlayerTrinkets")
			if is_instance_valid(container):
				for uuid: String in container.get_all_non_empty_uuids():
					var inst: GachaBallInstance = bm.get_instance_by_uuid(uuid)
					if is_instance_valid(inst) and inst.definition_id == trinket_id:
						return true
	return false


func get_base_gacha_token_cost(tier: int) -> int:
	return tier


func get_gacha_token_cost(tier: int) -> int:
	var cost: int = get_base_gacha_token_cost(tier)
	if is_bargain_charm_active(tier):
		cost -= 1
	return maxi(1, cost)


func is_bargain_charm_active(tier: int) -> bool:
	if not has_trinket(&"trinket_bargain_charm") or gacha_discounts_used.get(tier, false):
		return false
	var base_cost: int = get_base_gacha_token_cost(tier)
	return maxi(1, base_cost - 1) < maxi(1, base_cost)


func use_gacha_discount(tier: int) -> void:
	gacha_discounts_used[tier] = true


func reset_gacha_discounts() -> void:
	gacha_discounts_used = {1: false, 2: false, 3: false}


func get_shrine_transform_cost() -> int:
	return 5


# =============================================================================
# ENCOUNTER TRANSACTION & PATH GENERATION DELEGATES
# =============================================================================

func generate_path_nodes() -> Array[PathNodeDefinition]:
	return PathNodeGenerator.generate_path_nodes(self)


func _on_reward_chosen(payload: Dictionary) -> void:
	EncounterTransactionEngine.handle_reward_chosen(self, payload)


func sell_reward_instance(instance_uuid: String) -> int:
	return EncounterTransactionEngine.sell_reward_instance(self, instance_uuid)


func simulate_reward_draw(tier: int, slot_index: int = -1) -> Dictionary:
	return EncounterTransactionEngine.simulate_reward_draw(self, tier, slot_index)


func simulate_shop_purchase(instance_uuid: String, cost: int) -> Dictionary:
	return EncounterTransactionEngine.simulate_shop_purchase(self, instance_uuid, cost)


func _on_shop_purchase_requested(instance_uuid: String, cost: int) -> void:
	simulate_shop_purchase(instance_uuid, cost)


func _on_shop_reroll_requested() -> void:
	EncounterTransactionEngine.reroll_shop(self)


func _on_reward_reroll_requested() -> void:
	EncounterTransactionEngine.reroll_reward(self)


func get_transform_result(source_definition: GachaBallDefinition) -> GachaBallDefinition:
	return EncounterTransactionEngine.get_transform_result(source_definition)


func _on_shrine_action_requested(payload: Dictionary) -> void:
	EncounterTransactionEngine.handle_shrine_action(self, payload)


func roll_training_reward(tier: int) -> int:
	return EncounterTransactionEngine.roll_training_reward(tier)


func simulate_rest_site_draw(tier: int) -> Dictionary:
	return EncounterTransactionEngine.simulate_rest_site_draw(self, tier)


func roll_rest_site_prize(tier: int) -> Dictionary:
	return simulate_rest_site_draw(tier).get("prize_data", {})


func simulate_dojo_training(token_cost: int) -> Dictionary:
	return EncounterTransactionEngine.simulate_dojo_training(self, token_cost)


func claim_rest_site_prize(slot_index: int) -> Dictionary:
	return EncounterTransactionEngine.claim_rest_site_prize(self, slot_index)


func auto_claim_all_rest_site_prizes() -> void:
	EncounterTransactionEngine.auto_claim_all_rest_site_prizes(self)
