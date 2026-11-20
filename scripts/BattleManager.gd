class_name BattleManager
extends Node

const C = preload("res://scripts/Constants.gd")
const RS = preload("res://scripts/RunState.gd")
const BattleStateClass = preload("res://scripts/battle/BattleState.gd")
const CombatSimulatorClass = preload("res://scripts/battle/CombatSimulator.gd")
const _TestModeHelpers = preload("res://scripts/battle/TestModeHelpers.gd")
const REPLAY_MIN_PLAYER_SHELF_SLOTS: int = 6
enum Phases {START_OF_TURN, MANAGEMENT, PRE_COMBAT, COMBAT, END_OF_TURN, BATTLE_OVER}
var _current_battle_phase: Phases

# Internal delegates - encapsulate battle data and combat simulation
var _state = BattleStateClass.new()
var _combat = CombatSimulatorClass.new()

# Combat variables - forward to _combat for backwards compatibility
var _actor_queue: Array[GachaBallInstance]:
	get: return _combat._actor_queue
	set(value): _combat._actor_queue = value
var _pending_reactions: Array[EffectRequest]:
	get: return _combat._pending_reactions
	set(value): _combat._pending_reactions = value
var _is_processing_effect: bool:
	get: return _combat._processing_effect_count > 0
	set(value):
		if value:
			_combat._processing_effect_count += 1
		else:
			_combat._processing_effect_count = maxi(0, _combat._processing_effect_count - 1)

var _management_animation_queue: Array[Dictionary] = []
var _is_animating_management_queue: bool = false
var _is_entrance_sequence_running: bool = false
var _is_drawing: bool = false
signal management_animation_queue_completed


var _battle_over_deferred: bool = false
var _battle_over_emitted: bool = false

# Locked traits snapshot for COMBAT phase stability
var _locked_ready_traits: Dictionary = {}


# Legacy accessors - forward to _state for backwards compatibility
var _battle_instances: Dictionary:
	get: return _state._battle_instances
	set(value): _state._battle_instances = value
var _containers: Dictionary:
	get: return _state._containers
	set(value): _state._containers = value
var enemy_trinkets: Array[GachaBallInstance]:
	get: return _state.enemy_trinkets
	set(value): _state.enemy_trinkets = value
var _turn_metadata: Dictionary:
	get: return _state._turn_metadata
	set(value): _state._turn_metadata = value
# Note: _dead_this_turn access is via KnockoutProcessor.is_knocked_out_this_turn()
var _gacha_tokens: int:
	get:
		if is_instance_valid(GameManager.run_state):
			return GameManager.run_state.current_room_tokens
		return _state._gacha_tokens
	set(value):
		if is_instance_valid(GameManager.run_state):
			GameManager.run_state.current_room_tokens = value
		_state._gacha_tokens = value

const _FixedArrayContainer = preload("res://scripts/FixedArrayContainer.gd")
const _GrowableGridContainer = preload("res://scripts/GrowableGridContainer.gd")
const _EncounterDefinition = preload("res://scripts/EncounterDefinition.gd")
var _last_minigame_results: Dictionary = {}
var _next_minigame_bonus_time: float = 0.0

func get_next_minigame_bonus_time() -> float:
	if is_instance_valid(GameManager.run_state):
		return GameManager.run_state.next_battle_minigame_bonus_time
	return _next_minigame_bonus_time

func get_total_next_minigame_bonus_time() -> float:
	var total: float = get_next_minigame_bonus_time()
	if GameManager.has_trinket(&"trinket_time_sprint_charm") or _has_team_trinket(true, &"trinket_time_sprint_charm"):
		total += 2.0
	if TraitRulesEngine.has_tier(get_active_traits("PLAYER"), "NOVICE", 1):
		total += 1.0
	return total

func add_next_minigame_bonus_time(seconds: float, silent: bool = false) -> void:
	if is_instance_valid(GameManager.run_state):
		GameManager.run_state.next_battle_minigame_bonus_time += seconds
	else:
		_next_minigame_bonus_time += seconds
	if not silent:
		SignalBus.minigame_bonus_time_changed.emit(get_total_next_minigame_bonus_time())

func consume_next_minigame_bonus_time() -> float:
	var bonus: float = 0.0
	if is_instance_valid(GameManager.run_state):
		bonus = GameManager.run_state.next_battle_minigame_bonus_time
		GameManager.run_state.next_battle_minigame_bonus_time = 0.0
	else:
		bonus = _next_minigame_bonus_time
		_next_minigame_bonus_time = 0.0
	SignalBus.minigame_bonus_time_changed.emit(get_total_next_minigame_bonus_time())
	return bonus

func clear_next_minigame_bonus_time() -> void:
	if is_instance_valid(GameManager.run_state):
		GameManager.run_state.next_battle_minigame_bonus_time = 0.0
	_next_minigame_bonus_time = 0.0
	SignalBus.minigame_bonus_time_changed.emit(0.0)

func get_last_minigame_results() -> Dictionary:
	return _last_minigame_results
var _current_turn: int = 0
var _turn_start_abilities_triggered: bool = false
var _bargain_charm_uses: Dictionary = {}
var _specialist_gold_awarded_battle: int = 0
var _pending_inventory_refresh: bool = false


# -----------------------------------------------------------------------------
# INITIALIZATION & SETUP
# -----------------------------------------------------------------------------
var _animator: Node = null

func _resolve_animator() -> void:
	if is_instance_valid(_animator):
		return
	var candidate: Node = get_node_or_null("/root/BattleAnimator")
	if not is_instance_valid(candidate):
		candidate = get_tree().get_first_node_in_group("battle_animator")
	if is_instance_valid(candidate):
		_animator = candidate
		if not _animator.turn_animation_finished.is_connected(_on_turn_animation_finished):
			_animator.turn_animation_finished.connect(_on_turn_animation_finished)

func _ready() -> void:
	var existing := get_tree().get_nodes_in_group("battle_manager")
	if existing.size() > 0:
		var is_first = true
		for node in existing:
			if node != self: is_first = false; break
		if not is_first: queue_free(); return

	add_to_group("battle_manager")
	GameManager.register_battle_manager(self ) # ADD THIS LINE
	
	_change_phase(Phases.MANAGEMENT)

	_connect_signals()
	# Connect to flashcard completion signal
	FlashcardManager.minigame_finished.connect(_on_flashcard_completed)
	SignalBus.results_acknowledged.connect(_on_results_acknowledged)
	_resolve_animator()
	if is_instance_valid(_animator) and not _animator.turn_animation_finished.is_connected(_on_turn_animation_finished):
		_animator.turn_animation_finished.connect(_on_turn_animation_finished)

func get_current_phase() -> Phases:
	return _current_battle_phase

func get_battle_phase() -> Phases:
	return _current_battle_phase

## Provides the settled battle simulation state for replay verification.
## Runtime nodes, animation tracks, and screen-space state are intentionally absent.
func get_replay_state_snapshot() -> Dictionary:
	var instances: Dictionary = {}
	var instance_ids: Array = _battle_instances.keys()
	instance_ids.sort()
	for uuid in instance_ids:
		var instance: Variant = _battle_instances[uuid]
		if not is_instance_valid(instance):
			continue
		var instance_data: Dictionary = instance.to_save_dict()
		var battle_components: Array[Dictionary] = []
		for component: GachaBallComponent in instance.battle_components:
			if is_instance_valid(component):
				battle_components.append(component.to_save_dict())
		instance_data["battle_components"] = battle_components
		instances[String(uuid)] = instance_data

	var containers: Dictionary = {}
	var container_names: Array = _containers.keys()
	container_names.sort()
	for container_name in container_names:
		var container: DataContainer = _containers[container_name]
		if is_instance_valid(container):
			var slots: Array[String] = container.get_all_uuids()
			if container_name == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF:
				# Preserve existing replay hashes while extra slots are locked and empty.
				var retained_slots: int = maxi(REPLAY_MIN_PLAYER_SHELF_SLOTS, _state.player_shelf_slots_unlocked)
				while slots.size() > retained_slots and slots[-1].is_empty():
					slots.pop_back()
			containers[String(container_name)] = slots

	var actor_queue: Array[String] = []
	for actor in _actor_queue:
		if is_instance_valid(actor):
			actor_queue.append(actor.ball_uuid)
	var enemy_trinket_ids: Array[String] = []
	for trinket in enemy_trinkets:
		if is_instance_valid(trinket):
			enemy_trinket_ids.append(trinket.ball_uuid)

	return {
		"phase": int(_current_battle_phase),
		"turn": _current_turn,
		"turn_metadata": _turn_metadata.duplicate(true),
		"specialist_gacha_discount_used": _state.specialist_gacha_discount_used,
		"dead_this_turn": _state._dead_this_turn.duplicate(true),
		"gacha_tokens": _gacha_tokens,
		"player_shelf_slots_unlocked": _state.player_shelf_slots_unlocked,
		"player_slot_effects": _state.player_slot_effects.duplicate(),
		"enemy_slot_effects": _state.enemy_slot_effects.duplicate(),
		"staged_enemy_placements": _state.staged_enemy_placements.duplicate(true),
		"staged_hero_placement": _state.staged_hero_placement.duplicate(true),
		"instances": instances,
		"containers": containers,
		"actor_queue": actor_queue,
		"enemy_trinkets": enemy_trinket_ids,
		"pending_reaction_count": _pending_reactions.size(),
		"battle_over_emitted": _battle_over_emitted
	}

func is_processing_effect() -> bool:
	return _is_processing_effect

func set_processing_effect(active: bool) -> void:
	_is_processing_effect = active

func _exit_tree() -> void:
	clear_next_minigame_bonus_time()
	GameManager.unregister_battle_manager() # ADD THIS LINE
	GameManager.is_in_battle = false
	SignalBus.emit_signal("battle_state_changed", false)
	if SignalBus.battle_entry_animation_finished.is_connected(_on_battle_entry_animation_finished):
		SignalBus.battle_entry_animation_finished.disconnect(_on_battle_entry_animation_finished)
	if SignalBus.end_turn_requested.is_connected(_on_end_turn_requested):
		SignalBus.end_turn_requested.disconnect(_on_end_turn_requested)
	if SignalBus.unit_inventory_changed.is_connected(_on_unit_inventory_changed):
		SignalBus.unit_inventory_changed.disconnect(_on_unit_inventory_changed)
	if FlashcardManager.minigame_finished.is_connected(_on_flashcard_completed):
		FlashcardManager.minigame_finished.disconnect(_on_flashcard_completed)
	if SignalBus.results_acknowledged.is_connected(_on_results_acknowledged):
		SignalBus.results_acknowledged.disconnect(_on_results_acknowledged)
	if is_instance_valid(_animator) and _animator.turn_animation_finished.is_connected(_on_turn_animation_finished):
		_animator.turn_animation_finished.disconnect(_on_turn_animation_finished)
	if SignalBus.management_animation_requested.is_connected(_on_management_animation_requested):
		SignalBus.management_animation_requested.disconnect(_on_management_animation_requested)

func _connect_signals() -> void:
	SignalBus.battle_entry_animation_finished.connect(_on_battle_entry_animation_finished)
	SignalBus.end_turn_requested.connect(_on_end_turn_requested)
	SignalBus.unit_inventory_changed.connect(_on_unit_inventory_changed)
	if not SignalBus.management_animation_requested.is_connected(_on_management_animation_requested):
		SignalBus.management_animation_requested.connect(_on_management_animation_requested)

func _is_unit_instance(inst: GachaBallInstance) -> bool:
	if not is_instance_valid(inst):
		return false
	var def = inst.get_definition()
	return is_instance_valid(def) and def.category == &"UNIT"

func _capture_all_unit_stats() -> Dictionary:
	return BoardStatDiffBuilder.capture_all_unit_stats(_battle_instances)

static func _apply_unit_stat_override(snapshot_unit: Dictionary, unit_override: Dictionary) -> void:
	BoardStatDiffBuilder.apply_unit_stat_override(snapshot_unit, unit_override)

func _generate_inventory_stat_events(pre_stats: Dictionary) -> Dictionary:
	return BoardStatDiffBuilder.generate_inventory_stat_events(pre_stats, self)

func _emit_battle_inventory_changed(extra_events: Array[CombatEvent] = [], pre_stats_override: Dictionary = {}, pre_equipped_override: Dictionary = {}, pre_board_snapshot: Dictionary = {}) -> void:
	# Trigger real-time passive updates whenever the inventory changes
	var board_ctx := TriggerContext.new()
	board_ctx.is_simulation = true
	AbilityResolver.process_trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED, board_ctx)
	
	if _current_battle_phase == Phases.MANAGEMENT:
		if not _is_processing_effect:
			# Preserve the starting values so playback can show each reaction's stat change.
			var snapshot: Dictionary = pre_board_snapshot if not pre_board_snapshot.is_empty() else VisualDataAdapter.create_board_snapshot(get_all_instances())
			# Process passive updates (e.g. Twin Charm, Echoing Orb scaling) via CRR so UI reflects changes
			var events: Array[CombatEvent] = []
			if not extra_events.is_empty():
				events.append_array(extra_events)
			
			var death_tracking: Dictionary = {}
			var passive_events: Array[CombatEvent] = []
			passive_events.append_array(_combat.process_reaction_queue(self, death_tracking))
			var safety := 20
			while safety > 0 and not _combat.get_crr().is_empty():
				_check_for_deaths_with_counter_delay(true, passive_events, death_tracking)
				_process_completed_counter_deaths(passive_events, death_tracking)
				if _combat.get_crr().is_empty():
					break
				passive_events.append_array(_combat.process_reaction_queue(self, death_tracking))
				safety -= 1
			
			var root_cause_id: int = -1
			for ev in extra_events:
				if is_instance_valid(ev) and ev.type in [CombatEvent.Type.ITEM_EQUIP, CombatEvent.Type.ITEM_DISCARD, CombatEvent.Type.MOVE, CombatEvent.Type.MERGE]:
					root_cause_id = ev.event_id
					break
			if root_cause_id >= 0:
				CausalReactionResolver.stamp_cause_id(passive_events, root_cause_id)
				CausalReactionResolver.stamp_cause_id(extra_events, root_cause_id)
			
			if not passive_events.is_empty():
				events.append_array(passive_events)
			
			# Ensure any enemy deaths that occurred during these updates are properly cleaned up
			_flush_deferred_enemy_removals()
			
			if not events.is_empty():
				for unit_uuid in pre_stats_override:
					if snapshot.has(unit_uuid):
						var unit_override: Dictionary = pre_stats_override[unit_uuid]
						_apply_unit_stat_override(snapshot[unit_uuid], unit_override)
				for unit_uuid in pre_equipped_override:
					if snapshot.has(unit_uuid):
						var eq_override: Dictionary = pre_equipped_override[unit_uuid]
						if eq_override.has("equipped_items"):
							snapshot[unit_uuid]["equipped_items"] = eq_override["equipped_items"]
						if eq_override.has("equipped_item_icon"):
							snapshot[unit_uuid]["equipped_item_icon"] = eq_override["equipped_item_icon"]
				enqueue_management_animation(snapshot, events)
				_pending_inventory_refresh = true
			else:
				SignalBus.emit_signal("battle_inventory_changed")
				_pending_inventory_refresh = false
		else:
			if not extra_events.is_empty():
				var snapshot: Dictionary = pre_board_snapshot if not pre_board_snapshot.is_empty() else VisualDataAdapter.create_board_snapshot(get_all_instances())
				for unit_uuid in pre_stats_override:
					if snapshot.has(unit_uuid):
						var unit_override: Dictionary = pre_stats_override[unit_uuid]
						_apply_unit_stat_override(snapshot[unit_uuid], unit_override)
				for unit_uuid in pre_equipped_override:
					if snapshot.has(unit_uuid):
						var eq_override: Dictionary = pre_equipped_override[unit_uuid]
						if eq_override.has("equipped_items"):
							snapshot[unit_uuid]["equipped_items"] = eq_override["equipped_items"]
						if eq_override.has("equipped_item_icon"):
							snapshot[unit_uuid]["equipped_item_icon"] = eq_override["equipped_item_icon"]
				enqueue_management_animation(snapshot, extra_events)
			_pending_inventory_refresh = true
	else:
		_pending_inventory_refresh = true


func _on_management_animation_requested(snapshot: Dictionary) -> void:
	await resolve_management_effects_and_animate(snapshot)
	unblock_ui_updates()


func start_battle(encounter_def: EncounterDefinition) -> void:
	# Clear any existing selection when entering battle
	SignalBus.emit_signal("selection_clear_requested")
	# Create a fresh battle state with copies of units from run state.
	# IMPORTANT: The battle operates on these copies, leaving the original run state untouched.
	# Any changes to units during battle (HP, stats, etc.) will be discarded when the battle ends.
	_setup_battle(encounter_def)
	GameManager.is_in_battle = true
	SignalBus.emit_signal("battle_state_changed", true)
	_emit_battle_inventory_changed()
	
	# AUDIO HOOK: Battle BGM
	Audio.play_music(SoundRegistry.BGM_BATTLE)
	
	SignalBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
	
	# Emit unit_stat_changed for all units that have equipped items after UI is populated
	call_deferred("_emit_stats_changed_for_equipped_units")
	
	# Start the first turn with the Challenge
	_change_phase(Phases.START_OF_TURN)

	if ActionQueue.get_active_action() is SelectPathAction:
		ActionQueue.finish_action(ActionQueue.get_active_action())

func _setup_battle(encounter_def: EncounterDefinition = null) -> void:
	# Clear all state
	clear_next_minigame_bonus_time()
	_state.clear()
	_combat.clear()
	_is_entrance_sequence_running = false
	_battle_over_emitted = false
	_battle_over_deferred = false
	_current_turn = 0
	
	if is_instance_valid(encounter_def):
		if "player_slot_effects" in encounter_def and encounter_def.player_slot_effects.size() == 5:
			_state.player_slot_effects = encounter_def.player_slot_effects.duplicate()
		if "enemy_slot_effects" in encounter_def and encounter_def.enemy_slot_effects.size() == 5:
			_state.enemy_slot_effects = encounter_def.enemy_slot_effects.duplicate()

	
	# Atomically copy and place instances from run state using BattleSetup
	BattleSetup.setup_from_run_state(_state)
	
	# Setup board using BattleSetup
	if is_instance_valid(encounter_def):
		BattleSetup.stage_enemy_lineup(_state, encounter_def)
		BattleSetup.setup_enemy_trinkets(_state, encounter_def)
	
	# Copy player trinkets
	BattleSetup.setup_player_trinkets(_state)
	
	# Trigger on_battle_start for all units
	# 5. Connect to token changes for dynamic abilities (e.g., Templar)
	if not SignalBus.gacha_tokens_changed.is_connected(_on_gacha_tokens_changed):
		SignalBus.gacha_tokens_changed.connect(_on_gacha_tokens_changed)

	_trigger_battle_start_abilities()
	if OS.is_debug_build():
		_bm_validate_state_consistency()


func get_container(container_name: StringName) -> DataContainer:
	return _state.get_container(container_name)

func get_instances_in_container(container_tag: StringName) -> Array[GachaBallInstance]:
	return _state.get_instances_in_container(container_tag)

func get_inventory_tier_instances(tier: int) -> Array[GachaBallInstance]:
	return _state.get_inventory_tier_instances(tier)

func get_instance(uuid: String) -> GachaBallInstance:
	return _battle_instances.get(uuid)

func get_location_for_uuid(uuid: String) -> LocationIdentifier:
	var instance = get_instance(uuid)
	if is_instance_valid(instance):
		return instance.get_location()
	return null

func _update_instance_location(uuid: String, container_name: StringName, index: int) -> void:
	_state.update_instance_location(uuid, container_name, index)

func get_instance_by_location(loc: LocationIdentifier) -> GachaBallInstance:
	return _state.get_instance_by_location(loc)

func get_all_instances() -> Dictionary:
	return _battle_instances

# ------------------------------------------------------------------
# Atomic mutation API (Battle)
# ------------------------------------------------------------------

func bm_add_instance(instance: GachaBallInstance, container_name: StringName, index: int = -1) -> bool:
	var result := _state.bm_add_instance(instance, container_name, index)
	if result:
		if OS.is_debug_build():
			_bm_validate_state_consistency()
		_emit_battle_inventory_changed()
		SignalBus.emit_signal("inventory_ui_refresh_requested")
	return result

func _reshuffle_tier_from_discard(tier_to_reshuffle: int) -> bool:
	return _state.reshuffle_tier_from_discard(tier_to_reshuffle)

func bm_remove_instance(uuid: String) -> bool:
	var instance := get_instance(uuid)
	if is_instance_valid(instance):
		_cleanup_removed_trinket_passives(instance)

	var pre_stats := _capture_all_unit_stats()
	var result := _state.bm_remove_instance(uuid)
	if result.success:
		if not result.unit_changed_uuid.is_empty():
			SignalBus.emit_signal("unit_inventory_changed", result.unit_changed_uuid)
		if OS.is_debug_build():
			_bm_validate_state_consistency()
		var stat_data := _generate_inventory_stat_events(pre_stats)
		_emit_battle_inventory_changed(stat_data.events, stat_data.pre_stats)
		SignalBus.emit_signal("inventory_ui_refresh_requested")
	return result.success

func _cleanup_removed_trinket_passives(instance: GachaBallInstance) -> void:
	if not is_instance_valid(instance):
		return
	AuraEvaluator.clear_auras_for_source(instance.ball_uuid, _battle_instances, false)


func bm_move_instance(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> bool:
	assert(is_instance_valid(source_loc), "bm_move_instance: source_loc is null")
	assert(is_instance_valid(target_loc), "bm_move_instance: target_loc is null")
	
	var pre_stats := _capture_all_unit_stats()
	var source: GachaBallInstance = get_instance_by_location(source_loc)
	var incubator: GachaBallInstance = null
	if source != null and source_loc.container == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF and _is_lineup_container(target_loc.container):
		incubator = _state.get_equipped_incubator(source)
	var pre_board: Dictionary = VisualDataAdapter.create_board_snapshot(get_all_instances()) if incubator != null else {}
	var result := InventoryOperations.move_instance(_state, source_loc, target_loc)
	
	# Handle needs_equip delegation
	if result.needs_equip:
		# Emit unit changes from the pre-equip phase
		for uuid in result.changed_unit_uuids:
			SignalBus.emit_signal("unit_inventory_changed", uuid)
		# Delegate to bm_equip_item which handles its own signals
		return bm_equip_item(result.equip_item_uuid, result.equip_unit_uuid, result.equip_slot_index)
	
	if result.success:
		var events: Array[CombatEvent] = []
		if incubator != null:
			var discard: InventoryOperations.OperationResult = InventoryOperations.move_instance_to_discard(_state, incubator)
			assert(discard.success, "Redeploying an incubated unit must send its Incubator to Discard")
			result.add_unit_change(source.ball_uuid)
			events.append(_incubator_move_event(source, source_loc, incubator.ball_uuid))
			events.append(_item_discard_event(discard))
		else:
			SignalBus.emit_signal("battle_inventory_changed")
		if not _is_lineup_container(source_loc.container) and _is_lineup_container(target_loc.container):
			var entered_unit: GachaBallInstance = get_instance_by_location(target_loc)
			assert(is_instance_valid(entered_unit), "bm_move_instance: successful lineup move must place a registered instance")
			var entered_definition: GachaBallDefinition = entered_unit.get_definition()
			assert(is_instance_valid(entered_definition), "bm_move_instance: lineup entrant must have a definition")
			if entered_definition.category == C.CATEGORY_UNIT:
				_process_lineup_entry(entered_unit)
		elif not _is_battle_board_container(source_loc.container) and (target_loc.container == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF or target_loc.container == C.BATTLE_CONTAINER_TAGS.ENEMY_SHELF):
			var entered_shelf_unit: GachaBallInstance = get_instance_by_location(target_loc)
			if is_instance_valid(entered_shelf_unit):
				var entered_shelf_def: GachaBallDefinition = entered_shelf_unit.get_definition()
				if is_instance_valid(entered_shelf_def) and entered_shelf_def.category == C.CATEGORY_UNIT:
					_process_shelf_entry(entered_shelf_unit)
		if OS.is_debug_build():
			_bm_validate_state_consistency()
		for uuid in result.changed_unit_uuids:
			SignalBus.emit_signal("unit_inventory_changed", uuid)
		if result.inventory_changed:
			var stat_data := _generate_inventory_stat_events(pre_stats)
			events.append_array(stat_data.events)
			_emit_battle_inventory_changed(events, stat_data.pre_stats, {}, pre_board)
			SignalBus.emit_signal("inventory_ui_refresh_requested")
	
	return result.success

func bm_swap_instances(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> bool:
	assert(is_instance_valid(source_loc), "bm_swap_instances: source_loc is null")
	assert(is_instance_valid(target_loc), "bm_swap_instances: target_loc is null")
	
	var pre_stats := _capture_all_unit_stats()
	var result := InventoryOperations.swap_instances(_state, source_loc, target_loc)
	
	if result.success:
		SignalBus.emit_signal("battle_inventory_changed")
		if not _is_lineup_container(source_loc.container) and _is_lineup_container(target_loc.container):
			var entered_from_source: GachaBallInstance = get_instance_by_location(target_loc)
			assert(is_instance_valid(entered_from_source), "bm_swap_instances: successful lineup swap must place a registered instance")
			var source_definition: GachaBallDefinition = entered_from_source.get_definition()
			assert(is_instance_valid(source_definition), "bm_swap_instances: lineup entrant must have a definition")
			if source_definition.category == C.CATEGORY_UNIT:
				_process_lineup_entry(entered_from_source)
		elif not _is_battle_board_container(source_loc.container) and (target_loc.container == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF or target_loc.container == C.BATTLE_CONTAINER_TAGS.ENEMY_SHELF):
			var entered_shelf_from_source: GachaBallInstance = get_instance_by_location(target_loc)
			if is_instance_valid(entered_shelf_from_source):
				var s_shelf_def: GachaBallDefinition = entered_shelf_from_source.get_definition()
				if is_instance_valid(s_shelf_def) and s_shelf_def.category == C.CATEGORY_UNIT:
					_process_shelf_entry(entered_shelf_from_source)

		if not _is_lineup_container(target_loc.container) and _is_lineup_container(source_loc.container):
			var entered_from_target: GachaBallInstance = get_instance_by_location(source_loc)
			assert(is_instance_valid(entered_from_target), "bm_swap_instances: successful lineup swap must place a registered instance")
			var target_definition: GachaBallDefinition = entered_from_target.get_definition()
			assert(is_instance_valid(target_definition), "bm_swap_instances: lineup entrant must have a definition")
			if target_definition.category == C.CATEGORY_UNIT:
				_process_lineup_entry(entered_from_target)
		elif not _is_battle_board_container(target_loc.container) and (source_loc.container == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF or source_loc.container == C.BATTLE_CONTAINER_TAGS.ENEMY_SHELF):
			var entered_shelf_from_target: GachaBallInstance = get_instance_by_location(source_loc)
			if is_instance_valid(entered_shelf_from_target):
				var t_shelf_def: GachaBallDefinition = entered_shelf_from_target.get_definition()
				if is_instance_valid(t_shelf_def) and t_shelf_def.category == C.CATEGORY_UNIT:
					_process_shelf_entry(entered_shelf_from_target)
		if OS.is_debug_build():
			_bm_validate_state_consistency()
		for uuid in result.changed_unit_uuids:
			SignalBus.emit_signal("unit_inventory_changed", uuid)
		if result.inventory_changed:
			var stat_data := _generate_inventory_stat_events(pre_stats)
			_emit_battle_inventory_changed(stat_data.events, stat_data.pre_stats)
			SignalBus.emit_signal("inventory_ui_refresh_requested")
	
	return result.success

func _capture_unit_equipped_items_data(unit_uuid: String) -> Array:
	var old_equipped_items_data: Array = []
	var old_unit: GachaBallInstance = get_instance(unit_uuid)
	if is_instance_valid(old_unit):
		for u_item_uuid in old_unit.equipped_item_uuids:
			if not u_item_uuid.is_empty():
				var u_item = get_instance(u_item_uuid)
				if is_instance_valid(u_item):
					var u_def = u_item.get_definition()
					if is_instance_valid(u_def):
						old_equipped_items_data.append({
							"uuid": u_item_uuid,
							"icon": u_def.icon,
							"definition_id": u_item.definition_id
						})
	return old_equipped_items_data

func _item_discard_event(result: InventoryOperations.OperationResult) -> CombatEvent:
	return CombatEvent.new(CombatEvent.Type.ITEM_DISCARD, {
		"source_uuid": result.replaced_from_unit_uuid,
		"target_uuids": [result.replaced_item_uuid],
		"visual_payload": CombatPayload.item_discard(
			result.replaced_from_unit_uuid, result.replaced_item_uuid,
			result.replaced_item_icon, result.replaced_item_icon_path, result.replaced_item_name
		)
	})

func _incubator_move_event(unit: GachaBallInstance, from: LocationIdentifier, item_uuid: String) -> CombatEvent:
	var payload := CombatPayload.new()
	payload.old_unit_location = from
	payload.container_tag = unit.location_container_tag
	payload.slot_index = unit.location_slot_index
	payload.item_uuid = item_uuid
	payload.new_unit_snapshot = VisualDataAdapter.create_visual_data(unit, get_all_instances())
	return CombatEvent.new(CombatEvent.Type.MOVE, {
		"source_uuid": unit.ball_uuid,
		"target_uuids": [unit.ball_uuid],
		"visual_payload": payload
	})

func _finalize_bm_equip_result(
	result: InventoryOperations.OperationResult,
	item_uuid: String,
	unit_uuid: String,
	pre_stats: Dictionary,
	old_equipped_items_data: Array,
	silent: bool,
	out_events: Array[CombatEvent]
) -> bool:
	if not result.success:
		return false

	if OS.is_debug_build():
		_bm_validate_state_consistency()

	# If an item was replaced, create an ITEM_DISCARD event (sequential beat!)
	var discard_event: CombatEvent = null
	if not result.replaced_item_uuid.is_empty():
		discard_event = _item_discard_event(result)
		if out_events != null:
			out_events.append(discard_event)

	var new_item := get_instance(item_uuid)
	var new_item_def = new_item.get_definition() if is_instance_valid(new_item) else null
	var equip_payload := CombatPayload.item_equip(
		unit_uuid,
		item_uuid,
		new_item_def.icon if (is_instance_valid(new_item_def) and "icon" in new_item_def) else null,
		new_item_def.icon_path if (is_instance_valid(new_item_def) and "icon_path" in new_item_def) else "",
		new_item_def.name if (is_instance_valid(new_item_def) and "name" in new_item_def) else "Item"
	)
	var equip_event := CombatEvent.new(CombatEvent.Type.ITEM_EQUIP, {
		"source_uuid": unit_uuid,
		"target_uuids": [unit_uuid],
		"visual_payload": equip_payload
	})
	if out_events != null:
		out_events.append(equip_event)

	if not silent:
		for uuid in result.changed_unit_uuids:
			SignalBus.emit_signal("unit_inventory_changed", uuid)
		if result.inventory_changed:
			var stat_data := _generate_inventory_stat_events(pre_stats)
			var extra_events: Array[CombatEvent] = []
			var pre_equipped_override: Dictionary = {}

			if discard_event != null:
				extra_events.append(discard_event)
				if not old_equipped_items_data.is_empty():
					pre_equipped_override[unit_uuid] = {
						"equipped_items": old_equipped_items_data,
						"equipped_item_icon": old_equipped_items_data[0]["icon"]
					}
			else:
				pre_equipped_override[unit_uuid] = {
					"equipped_items": [],
					"equipped_item_icon": null
				}

			CausalReactionResolver.stamp_cause_id(stat_data.events, equip_event.event_id)
			extra_events.append(equip_event)
			extra_events.append_array(stat_data.events)
			_emit_battle_inventory_changed(extra_events, stat_data.pre_stats, pre_equipped_override)
			SignalBus.emit_signal("inventory_ui_refresh_requested")
	else:
		# Even when silent (e.g. during combat simulation), we must trigger the passive scaling
		# updates to guarantee holder stats are dynamically updated instantly.
		var board_ctx := TriggerContext.new()
		board_ctx.is_simulation = true
		AbilityResolver.process_trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED, board_ctx)
		var death_tracking: Dictionary = {}
		var passive_events: Array[CombatEvent] = []
		passive_events.append_array(_combat.process_reaction_queue(self, death_tracking))
		CausalReactionResolver.stamp_cause_id(passive_events, equip_event.event_id)
		if out_events != null:
			out_events.append_array(passive_events)
		_pending_inventory_refresh = true

	return true

func bm_register_and_equip_item(item: GachaBallInstance, unit_uuid: String, slot_index: int = -1, silent: bool = false, out_events: Array[CombatEvent] = []) -> bool:
	assert(is_instance_valid(item), "bm_register_and_equip_item: item is null")
	assert(not unit_uuid.is_empty(), "bm_register_and_equip_item: unit_uuid is empty")
	var pre_stats := _capture_all_unit_stats() if not silent else {}
	var old_equipped_items_data := _capture_unit_equipped_items_data(unit_uuid) if not silent else []
	var result := InventoryOperations.register_and_equip_item(_state, item, unit_uuid, slot_index)
	return _finalize_bm_equip_result(result, item.ball_uuid, unit_uuid, pre_stats, old_equipped_items_data, silent, out_events)

func bm_equip_item(item_uuid: String, unit_uuid: String, slot_index: int = -1, silent: bool = false, out_events: Array[CombatEvent] = []) -> bool:
	assert(not item_uuid.is_empty(), "bm_equip_item: item_uuid is empty")
	assert(not unit_uuid.is_empty(), "bm_equip_item: unit_uuid is empty")
	var item: GachaBallInstance = get_instance(item_uuid)
	if item != null and item.definition_id == C.ITEM_INCUBATOR:
		return _equip_incubator(item, get_instance(unit_uuid), slot_index)
	var pre_stats := _capture_all_unit_stats() if not silent else {}
	var old_equipped_items_data := _capture_unit_equipped_items_data(unit_uuid) if not silent else []
	var result := InventoryOperations.equip_item(_state, item_uuid, unit_uuid, slot_index)
	return _finalize_bm_equip_result(result, item_uuid, unit_uuid, pre_stats, old_equipped_items_data, silent, out_events)

func _equip_incubator(item: GachaBallInstance, unit: GachaBallInstance, slot_index: int) -> bool:
	if _current_battle_phase != Phases.MANAGEMENT or unit == null or not InventoryOperations.can_incubate(_state, item, unit):
		return false
	var from: LocationIdentifier = unit.get_location()
	var pre_board: Dictionary = VisualDataAdapter.create_board_snapshot(get_all_instances())
	var result: InventoryOperations.OperationResult = InventoryOperations.equip_item(_state, item.ball_uuid, unit.ball_uuid, slot_index)
	if not result.success:
		return false

	_process_shelf_entry(unit)
	var events: Array[CombatEvent] = []
	if not result.replaced_item_uuid.is_empty():
		events.append(_item_discard_event(result))
	events.append(_incubator_move_event(unit, from, item.ball_uuid))
	_bm_validate_state_consistency()
	_emit_battle_inventory_changed(events, {}, {}, pre_board)
	SignalBus.unit_inventory_changed.emit(unit.ball_uuid)
	SignalBus.inventory_ui_refresh_requested.emit()
	return true

# ------------------------------------------------------------------
# Composite atomic mutation API (Battle)
# ------------------------------------------------------------------

func _is_battle_board_container(container_tag: StringName) -> bool:
	return (
		container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
		or container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF
		or container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
		or container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_SHELF
	)

func _is_lineup_container(container_tag: StringName) -> bool:
	return container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP

func _process_lineup_entry(unit: GachaBallInstance) -> void:
	assert(is_instance_valid(unit), "_process_lineup_entry: lineup entrant is required")
	assert(_is_lineup_container(unit.location_container_tag), "_process_lineup_entry: unit must be in an active lineup")
	var entry_context := TriggerContext.new()
	entry_context.is_simulation = true
	entry_context.entered_uuid = unit.ball_uuid
	entry_context.triggering_uuid = unit.ball_uuid
	AbilityResolver.process_trigger(C.TRIGGER_ON_ENTER_BOARD, entry_context)
	AbilityResolver.process_trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED, entry_context)
	# The enclosing inventory/summon operation drains reactions into its VCR log.
	# Draining here would consume unrelated pending reactions and discard their events.

func _process_shelf_entry(unit: GachaBallInstance) -> void:
	assert(is_instance_valid(unit), "_process_shelf_entry: shelf entrant is required")
	assert(unit.location_container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF or unit.location_container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_SHELF, "_process_shelf_entry: unit must be on an active shelf")
	var entry_context := TriggerContext.new()
	entry_context.is_simulation = true
	entry_context.entered_uuid = unit.ball_uuid
	entry_context.triggering_uuid = unit.ball_uuid
	AbilityResolver.process_trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED, entry_context)
	# Preserve the enclosing operation's reaction scope and event collector.

func _get_team_for_board_container(container_tag: StringName) -> String:
	if container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF:
		return "PLAYER"
	if container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP or container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_SHELF:
		return "ENEMY"
	return ""

## Atomically simulates a merge in battle, applying state mutations,
## triggering merge passives, routing reactions through CRR,
func _resolve_instance_at_loc(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc):
		return null
	if loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var parent_unit = _battle_instances.get(loc.unit_uuid)
		if is_instance_valid(parent_unit) and loc.index >= 0 and loc.index < parent_unit.equipped_item_uuids.size():
			var item_uuid = parent_unit.equipped_item_uuids[loc.index]
			return _battle_instances.get(item_uuid)
		return null
	return get_instance_by_location(loc)

## and returning a structured result with causal event logs.
func bm_merge_instances(source_loc: LocationIdentifier, target_loc: LocationIdentifier, recipe_id: StringName = &"") -> Dictionary:
	if not _state.is_lineup_location(target_loc):
		return {}
	if source_loc.container == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF and not _state.is_player_shelf_slot_unlocked(source_loc.index):
		return {}
	var source_instance: GachaBallInstance = _resolve_instance_at_loc(source_loc)
	if not is_instance_valid(source_instance):
		source_instance = GameManager.get_instance_from_location(source_loc)
	var target_instance: GachaBallInstance = _resolve_instance_at_loc(target_loc)
	if not is_instance_valid(target_instance):
		target_instance = GameManager.get_instance_from_location(target_loc)
	if not is_instance_valid(source_instance) or not is_instance_valid(target_instance):
		return {}

	var merge_result = MergeManager.calculate_merge_result(source_instance, target_instance, source_loc, target_loc, _battle_instances, recipe_id)
	if merge_result.is_empty():
		return {}

	var new_instance: GachaBallInstance = merge_result["merged_instance"]
	var result_def = new_instance.get_definition()
	if not is_instance_valid(result_def):
		return {}

	var all_parent_items: Array = merge_result.get("items_to_equip", [])
	var parent_items_to_discard: Array = merge_result.get("items_to_discard", [])
	# An Incubator belongs to the sealed capsule, never to the deployed merge result.
	for item: GachaBallInstance in all_parent_items.duplicate():
		if item.definition_id == C.ITEM_INCUBATOR:
			all_parent_items.erase(item)
			parent_items_to_discard.append(item)

	var source_is_equipped = source_loc.container == C.CONTAINER_EQUIPPED_ITEM
	var target_is_equipped = target_loc.container == C.CONTAINER_EQUIPPED_ITEM
	var is_board_merge = target_loc.container == C.CONTAINER_PLAYER_LINEUP or target_loc.container == C.CONTAINER_PLAYER_SHELF
	var is_same_unit_item_merge := source_is_equipped and target_is_equipped and source_loc.unit_uuid == target_loc.unit_uuid

	for discarded_item in parent_items_to_discard:
		if is_instance_valid(discarded_item):
			bm_move_instance_to_discard(discarded_item.ball_uuid)

	if not is_same_unit_item_merge:
		remove_instance(source_instance.ball_uuid)
		remove_instance(target_instance.ball_uuid)


	if target_is_equipped:
		if is_same_unit_item_merge:
			remove_instance(source_instance.ball_uuid)
			remove_instance(target_instance.ball_uuid)
		bm_register_and_equip_item(new_instance, target_loc.unit_uuid, target_loc.index)
	elif is_board_merge:
		add_instance(new_instance, target_loc.container, target_loc.index)
	elif ("tier" in result_def) and ("tier" in source_instance.get_definition()) and result_def.tier > source_instance.get_definition().tier:
		var new_container_tag = &"BattleInventoryT%d" % result_def.tier
		add_instance(new_instance, new_container_tag, -1)
	else:
		add_instance(new_instance, target_loc.container, target_loc.index)

	if result_def.category == &"UNIT":
		var max_slots = new_instance.equipped_item_uuids.size()
		for i in range(min(all_parent_items.size(), max_slots)):
			var it: GachaBallInstance = all_parent_items[i]
			if is_instance_valid(it):
				equip_item(it.ball_uuid, new_instance.ball_uuid, i, true)

	var is_dust_merge: bool = [&"unit_dust_t1", &"unit_dust_t2", &"unit_dust_t3"].has(new_instance.definition_id)
	var should_trigger_on_merge: bool = false
	var merge_container_tag: StringName = &""
	if is_same_unit_item_merge:
		var parent_unit: GachaBallInstance = get_instance(target_loc.unit_uuid)
		if is_instance_valid(parent_unit) and _is_battle_board_container(parent_unit.location_container_tag):
			should_trigger_on_merge = true
			merge_container_tag = parent_unit.location_container_tag
	elif _is_battle_board_container(target_loc.container) or is_dust_merge:
		should_trigger_on_merge = true
		merge_container_tag = target_loc.container

	var merge_team: String = _get_team_for_board_container(merge_container_tag)
	if merge_team.is_empty():
		merge_team = "PLAYER"
	var merge_context: Dictionary = {
		"merged_uuid": new_instance.ball_uuid,
		"merged_team": merge_team,
		"merge_container": merge_container_tag,
		"merge_category": result_def.category
	}

	var merge_payload := CombatPayload.merge_payload(
		source_instance.ball_uuid,
		target_instance.ball_uuid,
		new_instance.ball_uuid,
		VisualDataAdapter.create_visual_data(new_instance, get_all_instances()),
		recipe_id
	)
	var merge_event := CombatEvent.new(CombatEvent.Type.MERGE, {
		"source_uuid": source_instance.ball_uuid,
		"target_uuids": [new_instance.ball_uuid],
		"visual_payload": merge_payload
	})

	var reaction_events: Array[CombatEvent] = []
	var post_merge_snapshot := VisualDataAdapter.create_board_snapshot(get_all_instances())
	if should_trigger_on_merge:
		var scope_id = _combat.get_crr().begin_scope()

		# Resolve pending expired continuous auras from evolutionary level-up
		# before new level-entry aura abilities run.
		AuraEvaluator.drain_expired_auras(new_instance, reaction_events, true)

		if result_def.category == C.CATEGORY_UNIT and _is_lineup_container(merge_container_tag):
			_process_lineup_entry(new_instance)

		var trig_merge_ctx := TriggerContext.new()
		trig_merge_ctx.merged_uuid = merge_context.get("merged_uuid", "")
		trig_merge_ctx.merged_team = merge_context.get("merged_team", "")
		trig_merge_ctx.merge_container = merge_context.get("merge_container", &"")
		trig_merge_ctx.merge_category = merge_context.get("merge_category", &"")
		trig_merge_ctx.merged_definition_id = new_instance.definition_id
		AbilityResolver.process_trigger(C.TRIGGER_ON_MERGE, trig_merge_ctx)
		if is_dust_merge:
			AbilityResolver.process_trigger(C.TRIGGER_WHEN_DUST_MINIONS_MERGE, trig_merge_ctx)

		var board_ctx := TriggerContext.new()
		board_ctx.is_simulation = true
		AbilityResolver.process_trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED, board_ctx)

		TraitRulesEngine.apply_on_merge_traits(self, reaction_events)

		var death_tracking: Dictionary = {}
		reaction_events.append_array(_combat.process_reaction_queue(self, death_tracking))
		var safety := 20
		while safety > 0 and not _combat.get_crr().is_empty():
			_check_for_deaths_with_counter_delay(true, reaction_events, death_tracking)
			_process_completed_counter_deaths(reaction_events, death_tracking)
			if _combat.get_crr().is_empty():
				break
			reaction_events.append_array(_combat.process_reaction_queue(self, death_tracking))
			safety -= 1

		CausalReactionResolver.stamp_cause_id(reaction_events, merge_event.event_id)
	else:
		AuraEvaluator.drain_expired_auras(new_instance, reaction_events, false)

	reaction_events.append_array(take_inventory_events())
	var all_events: Array[CombatEvent] = [merge_event]
	all_events.append_array(reaction_events)

	var final_loc = LocationIdentifier.new(new_instance.location_container_tag, new_instance.location_slot_index)
	if new_instance.location_container_tag == C.CONTAINER_EQUIPPED_ITEM:
		final_loc.unit_uuid = new_instance.equipped_on_uuid

	return {
		"success": true,
		"merged_instance": new_instance,
		"source_loc": source_loc,
		"target_loc": target_loc,
		"final_loc": final_loc,
		"snapshot": post_merge_snapshot,
		"events": all_events,
		"reaction_events": reaction_events,
		"merge_event": merge_event,
		"should_trigger_on_merge": should_trigger_on_merge,
		"merge_context": merge_context
	}


func bm_move_instance_to_discard(uuid: String, out_events: Array[CombatEvent] = []) -> bool:
	assert(not uuid.is_empty(), "bm_move_instance_to_discard: uuid is empty")
	var instance := get_instance(uuid)
	assert(is_instance_valid(instance), "bm_move_instance_to_discard: instance not found")
	
	var pre_stats := _capture_all_unit_stats()
	var old_parent_uuid: String = ""
	var old_equipped_items_data: Array = []
	var loc := instance.get_location()
	if is_instance_valid(loc) and loc.container == C.CONTAINER_EQUIPPED_ITEM:
		old_parent_uuid = loc.unit_uuid
		var parent := get_instance(old_parent_uuid)
		if is_instance_valid(parent):
			for u_item_uuid in parent.equipped_item_uuids:
				if not u_item_uuid.is_empty():
					var u_item = get_instance(u_item_uuid)
					if is_instance_valid(u_item):
						var u_def = u_item.get_definition()
						if is_instance_valid(u_def):
							old_equipped_items_data.append({
								"uuid": u_item_uuid,
								"icon": u_def.icon,
								"definition_id": u_item.definition_id
							})

	var result := InventoryOperations.move_instance_to_discard(_state, instance)
	
	if result.success:
		for changed_uuid in result.changed_unit_uuids:
			SignalBus.emit_signal("unit_inventory_changed", changed_uuid)
		if OS.is_debug_build():
			_bm_validate_state_consistency()
		var stat_data := _generate_inventory_stat_events(pre_stats)
		var extra_events: Array[CombatEvent] = []
		var pre_equipped_override: Dictionary = {}
		if not result.replaced_item_uuid.is_empty():
			var discard_payload := CombatPayload.item_discard(
				result.replaced_from_unit_uuid,
				result.replaced_item_uuid,
				result.replaced_item_icon,
				result.replaced_item_icon_path,
				result.replaced_item_name
			)
			var discard_event := CombatEvent.new(CombatEvent.Type.ITEM_DISCARD, {
				"source_uuid": result.replaced_from_unit_uuid,
				"target_uuids": [result.replaced_item_uuid],
				"visual_payload": discard_payload
			})
			extra_events.append(discard_event)
			if out_events != null:
				out_events.append(discard_event)
			if not old_equipped_items_data.is_empty() and not old_parent_uuid.is_empty():
				pre_equipped_override[old_parent_uuid] = {
					"equipped_items": old_equipped_items_data,
					"equipped_item_icon": old_equipped_items_data[0]["icon"]
				}
		extra_events.append_array(stat_data.events)
		_emit_battle_inventory_changed(extra_events, stat_data.pre_stats, pre_equipped_override)
		SignalBus.emit_signal("inventory_ui_refresh_requested")
	
	return result.success

func bm_reshuffle_discard_pile(_tier_to_reshuffle: int) -> bool:
	# Automatic reshuffle feature has been removed.
	return false

func get_gacha_draw_cost(tier: int) -> int:
	var cost := tier
	var has_bargain = _has_team_trinket(true, &"trinket_bargain_charm")
	var bargain_used = _bargain_charm_uses.get(tier, false)
	if has_bargain and not bargain_used:
		cost = maxi(1, cost - 1)
	elif TraitRulesEngine.has_tier(get_active_traits("PLAYER"), "SPECIALIST", 2) and not _state.specialist_gacha_discount_used:
		cost = maxi(1, cost - 1)
	return cost

func is_animations_playing() -> bool:
	if _is_entrance_sequence_running or _is_processing_effect or _is_animating_management_queue:
		return true
	if is_instance_valid(_animator) and _animator.is_playing_sequence():
		return true
	return false

func is_animating_management_queue() -> bool:
	return _is_animating_management_queue

func can_draw_gacha_instance(tier: int, pending_cost: int = 0) -> bool:
	if _current_battle_phase != Phases.MANAGEMENT:
		return false
		
	var cost := get_gacha_draw_cost(tier)
	if _gacha_tokens - pending_cost < cost:
		return false
		
	var container_tag: StringName = "BattleInventoryT%d" % tier
	var tier_pool := get_instances_in_container(container_tag)
	if tier_pool.is_empty():
		return false
		
	return true

func can_draw_from_discard(pending_cost: int = 0) -> bool:
	if _current_battle_phase != Phases.MANAGEMENT:
		return false
	const cost := 1
	if _gacha_tokens - pending_cost < cost:
		return false
	var discard_pool := get_instances_in_container(C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	if discard_pool.is_empty():
		return false
	return _state.has_tier_space(1) or _state.has_tier_space(2) or _state.has_tier_space(3)

func bm_draw_from_discard() -> Array[CombatEvent]:
	var chain_events: Array[CombatEvent] = []
	const cost := 1
	if not can_draw_from_discard():
		return chain_events

	var draw_result := InventoryOperations.draw_from_discard(_state)
	if not draw_result.success:
		return chain_events

	_is_drawing = true
	_gacha_tokens -= cost
	SignalBus.emit_signal("gacha_tokens_changed", _gacha_tokens)

	if OS.is_debug_build():
		_bm_validate_state_consistency()

	var drawn_instance = get_instance(draw_result.drawn_uuid)
	var new_unit_snapshot = {}
	if is_instance_valid(drawn_instance):
		var VisualDataAdapter = preload("res://scripts/VisualDataAdapter.gd")
		new_unit_snapshot = VisualDataAdapter.create_visual_data(drawn_instance, get_all_instances())

	var draw_event = CombatEvent.new(CombatEvent.Type.DRAW)
	var draw_payload := CombatPayload.new()
	draw_payload.draw_result = draw_result
	draw_payload.new_unit_snapshot = new_unit_snapshot
	draw_payload.target_token_amount = _gacha_tokens
	draw_event.visual_payload = draw_payload
	draw_event.source_uuid = "PLAYER"
	var draw_targets: Array[String] = [draw_result.drawn_uuid]
	draw_event.target_uuids = draw_targets
	chain_events.append_array(take_inventory_events())
	chain_events.append(draw_event)

	var trig_ctx := TriggerContext.new()
	trig_ctx.drawn_uuid = draw_result.drawn_uuid
	trig_ctx.dest_container = draw_result.dest_container
	trig_ctx.dest_slot = draw_result.dest_slot
	trig_ctx.tier = drawn_instance.get_definition().tier if (is_instance_valid(drawn_instance) and is_instance_valid(drawn_instance.get_definition())) else 1
	trig_ctx.tokens_spent = cost
	var scope_id = _combat.get_crr().begin_scope()
	AbilityResolver.process_trigger(C.TRIGGER_ON_TOKEN_SPENT, trig_ctx)

	var death_tracking: Dictionary = {}
	var reaction_events: Array[CombatEvent] = []
	reaction_events.append_array(_combat.process_reaction_queue(self, death_tracking))

	var safety := 20
	while safety > 0 and not _combat.get_crr().is_empty():
		_check_for_deaths_with_counter_delay(true, reaction_events, death_tracking)
		_process_completed_counter_deaths(reaction_events, death_tracking)
		if _combat.get_crr().is_empty():
			break
		reaction_events.append_array(_combat.process_reaction_queue(self, death_tracking))
		safety -= 1

	CausalReactionResolver.stamp_cause_id(reaction_events, draw_event.event_id)
	chain_events.append_array(reaction_events)

	_is_drawing = false
	return chain_events

func bm_draw_gacha_instance(tier: int) -> Array[CombatEvent]:
	var chain_events: Array[CombatEvent] = []
	var base_cost := tier
	var cost := get_gacha_draw_cost(tier)
	var has_bargain = _has_team_trinket(true, &"trinket_bargain_charm")
	var bargain_used = _bargain_charm_uses.get(tier, false)
		
	if _gacha_tokens < cost:
		return chain_events
	
	var container_tag: StringName = "BattleInventoryT%d" % tier
	var tier_pool := get_instances_in_container(container_tag)
	
	# If pool is empty, try reshuffling first
	# If pool is empty, the draw fails (No automatic reshuffle)
	if tier_pool.is_empty():
		return chain_events
	
	# Attempt to draw
	var draw_result := InventoryOperations.draw_from_tier(_state, tier, _state.player_shelf_slots_unlocked)
	
	if not draw_result.success:
		return chain_events
	
	_is_drawing = true
	# Spend tokens
	_gacha_tokens -= cost
	if has_bargain and not bargain_used:
		_bargain_charm_uses[tier] = true
		if cost < base_cost:
			var event := CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": ""})
			event.trinket_activations.append(CombatTrinketActivation.new(&"trinket_bargain_charm", false))
			chain_events.append(event)
	elif TraitRulesEngine.has_tier(get_active_traits("PLAYER"), "SPECIALIST", 2) and not _state.specialist_gacha_discount_used:
		_state.specialist_gacha_discount_used = true
		if cost < base_cost:
			var event := CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": "Specialist discount applied!"})
			event.trinket_activations.append(CombatTrinketActivation.new(&"trinket_trait_specialist", false))
			chain_events.append(event)
	SignalBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
	
	# Validate and emit
	if OS.is_debug_build():
		_bm_validate_state_consistency()
	
	# Trigger passive updates (like Trinkets) so they enter the reaction queue FIRST
	# This ensures the drawn unit's stats are updated before the snapshot is taken
	var trig_ctx := TriggerContext.new()
	trig_ctx.drawn_uuid = draw_result.drawn_uuid
	trig_ctx.dest_container = draw_result.dest_container
	trig_ctx.dest_slot = draw_result.dest_slot
	trig_ctx.tier = tier
	trig_ctx.tokens_spent = tier # Tier equals tokens spent
	var drawn_instance = get_instance(draw_result.drawn_uuid)
	var new_unit_snapshot = {}
	if is_instance_valid(drawn_instance):
		var VisualDataAdapter = preload("res://scripts/VisualDataAdapter.gd")
		new_unit_snapshot = VisualDataAdapter.create_visual_data(drawn_instance, get_all_instances())

	# Create the draw event with the base stats snapshot
	var draw_event = CombatEvent.new(CombatEvent.Type.DRAW)
	var draw_payload := CombatPayload.new()
	draw_payload.draw_result = draw_result
	draw_payload.new_unit_snapshot = new_unit_snapshot
	draw_payload.target_token_amount = _gacha_tokens
	draw_event.visual_payload = draw_payload
	draw_event.source_uuid = "PLAYER"
	var draw_targets: Array[String] = [draw_result.drawn_uuid]
	draw_event.target_uuids = draw_targets
	chain_events.append_array(take_inventory_events())
	chain_events.append(draw_event)

	# Trigger passive updates (like Trinkets) so they enter the CRR reaction queue
	var scope_id = _combat.get_crr().begin_scope()
	var board_ctx := TriggerContext.new()
	board_ctx.is_simulation = true
	AbilityResolver.process_trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED, board_ctx)
	AbilityResolver.process_trigger(C.TRIGGER_ON_GACHA_DRAW, trig_ctx)
	AbilityResolver.process_trigger(C.TRIGGER_ON_TOKEN_SPENT, trig_ctx)
	
	# Process resulting reactions (e.g. passive scaling, on-draw buffs) via CRR
	var death_tracking: Dictionary = {}
	var reaction_events: Array[CombatEvent] = []
	reaction_events.append_array(_combat.process_reaction_queue(self, death_tracking))
	
	var safety := 20
	while safety > 0 and not _combat.get_crr().is_empty():
		_check_for_deaths_with_counter_delay(true, reaction_events, death_tracking)
		_process_completed_counter_deaths(reaction_events, death_tracking)
		if _combat.get_crr().is_empty():
			break
		reaction_events.append_array(_combat.process_reaction_queue(self, death_tracking))
		safety -= 1

	# Stamp causal lineage: reactions were caused by the draw
	CausalReactionResolver.stamp_cause_id(reaction_events, draw_event.event_id)
	chain_events.append_array(reaction_events)
	
	_is_drawing = false
	return chain_events

# ------------------------------------------------------------------
# Golden Rule Validation (Battle)
# ------------------------------------------------------------------

func _bm_validate_state_consistency() -> bool:
	var valid := _state.validate_state_consistency()
	assert(valid, "BattleState consistency invariant violated")
	return valid

func get_gacha_tokens() -> int:
	return _gacha_tokens

func get_player_shelf_slots_unlocked() -> int:
	return _state.player_shelf_slots_unlocked

func can_purchase_shelf_slot() -> bool:
	return _current_battle_phase == Phases.MANAGEMENT \
		and _state.player_shelf_slots_unlocked < C.PLAYER_SHELF_CAP \
		and get_gacha_tokens() >= C.SHELF_SLOT_TOKEN_COST

func purchase_shelf_slot() -> bool:
	if not can_purchase_shelf_slot():
		return false
	var spent: bool = _state.spend_gacha_tokens(C.SHELF_SLOT_TOKEN_COST)
	assert(spent, "purchase_shelf_slot: validated token spend failed")
	_state.player_shelf_slots_unlocked += 1
	var spend_context: TriggerContext = TriggerContext.new()
	spend_context.is_simulation = true
	spend_context.tokens_spent = C.SHELF_SLOT_TOKEN_COST
	AbilityResolver.process_trigger(C.TRIGGER_ON_TOKEN_SPENT, spend_context)
	SignalBus.emit_signal("gacha_tokens_changed", get_gacha_tokens())
	SignalBus.emit_signal("battle_inventory_changed")
	return true

func add_gacha_token(amount: int = 1, silent: bool = false) -> void:
	add_gacha_tokens(amount, silent)

func add_gacha_tokens(amount: int, silent: bool = false) -> void:
	"""Add gacha tokens to authoritative state. If not silent, emits gacha_tokens_changed."""
	if is_instance_valid(GameManager.run_state):
		GameManager.run_state.add_tokens(amount, silent)
		_state._gacha_tokens = GameManager.run_state.current_room_tokens
	else:
		_state._gacha_tokens += amount
		if not silent:
			SignalBus.emit_signal("gacha_tokens_changed", _state._gacha_tokens)

func spend_gacha_tokens(amount: int, origin_uuid: String = "") -> bool:
	assert(amount > 0, "spend_gacha_tokens: amount must be > 0")
	var success: bool = _state.spend_gacha_tokens(amount)
	if not success:
		return false
	
	if is_instance_valid(_combat):
		var target_token_amount := get_gacha_tokens()
		var token_payload := CombatPayload.new()
		token_payload.amount = amount
		token_payload.origin_uuid = origin_uuid
		token_payload.target_token_amount = target_token_amount
		
		_combat.add_inline_event(CombatEvent.new(CombatEvent.Type.TOKEN_SPEND, {
			"source_uuid": origin_uuid,
			"target_uuids": [origin_uuid] if not origin_uuid.is_empty() else [],
			"amount": amount,
			"visual_payload": token_payload
		}))
	
	var spend_ctx := TriggerContext.new()
	spend_ctx.is_simulation = true
	spend_ctx.source_uuid = origin_uuid
	spend_ctx.tokens_spent = amount
	AbilityResolver.process_trigger(C.TRIGGER_ON_TOKEN_SPENT, spend_ctx)
	return true

func get_current_phase_name() -> StringName:
	var phase_name: StringName
	match _current_battle_phase:
		Phases.START_OF_TURN: phase_name = &"START_OF_TURN"
		Phases.MANAGEMENT: phase_name = &"MANAGEMENT"
		Phases.PRE_COMBAT: phase_name = &"PRE_COMBAT"
		Phases.COMBAT: phase_name = &"COMBAT"
		Phases.END_OF_TURN: phase_name = &"END_OF_TURN"
		Phases.BATTLE_OVER: phase_name = &"BATTLE_OVER"
	return phase_name

func get_battle_inventory() -> Dictionary:
	return _containers

func get_discard_pile_inventory() -> Array[GachaBallInstance]:
	var result: Array[GachaBallInstance] = []
	var container = get_container(C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	if not is_instance_valid(container): return result
	var all_uuids = container.get_all_uuids()
	for uuid in all_uuids:
		if uuid.is_empty(): result.append(null)
		else: result.append(get_instance(uuid))
	if result.size() < 16: result.resize(16)
	return result

func _change_phase(new_phase: Phases) -> void:
	_current_battle_phase = new_phase
	SignalBus.emit_signal("battle_phase_changed", get_current_phase_name())
	
	# Re-assert canonical tokens on UI when entering key resting phases
	if new_phase == Phases.START_OF_TURN or new_phase == Phases.MANAGEMENT or new_phase == Phases.PRE_COMBAT or new_phase == Phases.BATTLE_OVER:
		SignalBus.emit_signal("gacha_tokens_changed", _gacha_tokens)

	if (new_phase == Phases.START_OF_TURN or new_phase == Phases.MANAGEMENT or new_phase == Phases.BATTLE_OVER) and ActionQueue.get_active_action() is EndTurnAction:
		ActionQueue.finish_action(ActionQueue.get_active_action())
		
	match _current_battle_phase:
		Phases.START_OF_TURN:
			# Increment turn counter and reset turn start flag
			_current_turn += 1
			_turn_start_abilities_triggered = false
			_bargain_charm_uses.clear()
			_state.specialist_gacha_discount_used = false
			_locked_ready_traits.clear()
			
			# Timekeeper hero bonus: +5 tokens for easy testing
			if _is_timekeeper_hero():
				_gacha_tokens += 5
			
			SignalBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
			
			# The flashcard Challenge is the first event of the turn.
			# TDD Section 9.4: Battle Flow
			# Turn start abilities will be triggered AFTER the Challenge in _on_results_acknowledged()
			if is_instance_valid(GameManager.run_state):
				if _current_turn == 1:
					SignalBus.emit_signal("battle_entry_animation_requested")
				else:
					FlashcardManager.start_minigame(GameManager.run_state, GameManager.run_state.active_deck_ids)
			# Note: The management phase will be triggered by _on_results_acknowledged
		Phases.MANAGEMENT:
			# Re-enable draw buttons when entering management phase
			_emit_battle_inventory_changed()
		Phases.PRE_COMBAT:
			pass
		Phases.COMBAT:
			pass
		Phases.END_OF_TURN:
			# Fire on_turn_end for all units
			# Note: _trigger_turn_end_abilities will start animations
			# The phase transition to START_OF_TURN will happen in _on_turn_animation_finished
			# when the burn animations complete
			_trigger_turn_end_abilities()

## Populate the actor queue at the start of combat.
## Turn order alternates rank by rank starting with the frontmost enemy slot:
##   Rank 0: Enemy Slot 0 -> Player Slot 4
##   Rank 1: Enemy Slot 1 -> Player Slot 3
##   Rank 2: Enemy Slot 2 -> Player Slot 2
##   Rank 3: Enemy Slot 3 -> Player Slot 1
##   Rank 4: Enemy Slot 4 -> Player Slot 0
## Empty slots are skipped, allowing frontloaded formations to act before backloaded units.
func _populate_actor_queue() -> void:
	_combat.populate_actor_queue(_state)

## Grant a unit an extra action by inserting them at the front of the actor queue.
## Called by EffectGrantExtraAction when a unit equipped with Scythe gets a kill.
## @param unit_uuid: String - The UUID of the unit to grant an extra action
func grant_extra_action(unit_uuid: String) -> void:
	var unit := get_instance_by_uuid(unit_uuid)
	_combat.grant_extra_action_to(unit)

## Insert a newly summoned unit into the actor queue.
## Mid-turn summons should always participate in combat if they're still alive when their turn comes.
func _insert_summoned_unit_into_queue(new_unit: GachaBallInstance) -> void:
	var is_player := _is_player_unit(new_unit)
	_combat.insert_summoned_unit(new_unit, is_player, _is_player_unit)

func _actor_queue_contains_uuid(uuid: String) -> bool:
	if uuid.is_empty():
		return false
	for queued_unit in _actor_queue:
		if is_instance_valid(queued_unit) and queued_unit.ball_uuid == uuid:
			return true
	return false

## Apply results from EffectHandlers summon handlers
## Registers new instances, updates containers, handles queue and cleanup
func take_inventory_events() -> Array[CombatEvent]:
	return _state.take_inventory_events()

func _apply_summon_result(result: EffectHandlers.SummonResult) -> void:
	# 1. Cleanup old units first
	for uuid in result.cleanup_uuids:
		var old_inst = get_instance(uuid)
		if is_instance_valid(old_inst):
			_perform_unit_death_cleanup(old_inst)
	
	# 2. Register new instances
	for new_inst in result.new_instances:
		_battle_instances[new_inst.ball_uuid] = new_inst

	# 3. Update containers and locations
	var pending_board_entries: Array[Dictionary] = []
	for update in result.container_updates:
		var container_tag: StringName = update.container_tag
		var slot: int = update.slot
		var uuid: String = update.uuid
		if String(container_tag).begins_with("BattleInventoryT") or container_tag == C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE:
			var capsule: GachaBallInstance = get_instance(uuid)
			var added: bool = _state.bm_add_instance(capsule, container_tag, slot)
			assert(added, "Storage summon must enter its tier or Discard")
			update.container_tag = capsule.location_container_tag
			update.slot = capsule.location_slot_index
			update.insert_into_queue = false
			for event: CombatEvent in result.events:
				if event.visual_payload.new_unit_uuid == uuid:
					event.visual_payload.old_unit_location = capsule.get_location()
					event.visual_payload.new_unit_snapshot["capsule_sealed"] = true
			continue

		var container = get_container(container_tag)
		assert(is_instance_valid(container), "_apply_summon_result: invalid container '%s'" % String(container_tag))
		var existing_at_slot := container.get_uuid(slot)
		assert(existing_at_slot.is_empty() or existing_at_slot == uuid, "_apply_summon_result: slot %s:%d occupied by %s when placing %s" % [String(container_tag), slot, existing_at_slot, uuid])
		container.set_uuid(slot, uuid)

		_update_instance_location(uuid, container_tag, slot)
		pending_board_entries.append({"container_tag": container_tag, "uuid": uuid})

	if OS.is_debug_build():
		_bm_validate_state_consistency()

	for entry in pending_board_entries:
		var container_tag: StringName = entry.container_tag
		var uuid: String = entry.uuid

		# Unlock the recipe if a player summoned this unit
		if _is_in_player_container_tag(container_tag) and is_instance_valid(GameManager.run_state):
			var inst = get_instance_by_uuid(uuid)
			if is_instance_valid(inst):
				GameManager.run_state.unlock_recipe_for_result(inst.definition_id)

		if _is_lineup_container(container_tag):
			var entered_unit: GachaBallInstance = get_instance_by_uuid(uuid)
			assert(is_instance_valid(entered_unit), "_apply_summon_result: lineup entrant must be registered")
			_process_lineup_entry(entered_unit)
	
	# 4. Handle queue replacements (single unit summons replace holder in queue)
	var replaced_new_uuids: Dictionary = {}
	for update in result.queue_updates:
		var old_uuid: String = update.old_uuid
		var new_inst: GachaBallInstance = update.new_instance
		
		for i in range(_actor_queue.size()):
			if _actor_queue[i].ball_uuid == old_uuid:
				_actor_queue[i] = new_inst
				replaced_new_uuids[new_inst.ball_uuid] = true
				break
	
	# 5. Insert summons into queue when requested (and not already represented via replacement)
	for update in result.container_updates:
		if not update.get("insert_into_queue", false):
			continue
		
		var uuid: String = update.uuid
		if replaced_new_uuids.has(uuid):
			continue
		if _actor_queue_contains_uuid(uuid):
			continue
		
		var inst = get_instance_by_uuid(uuid)
		if is_instance_valid(inst):
			_insert_summoned_unit_into_queue(inst)
			
	# Trigger on_board_state_changed to dynamically update passive effects (like Doppleganger/Echoing Orb)
	var board_ctx := TriggerContext.new()
	board_ctx.is_simulation = true
	AbilityResolver.process_trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED, board_ctx)
	_emit_battle_inventory_changed()

## Retrieves the basic attack ability definition for the specified unit.
func get_basic_attack_for(attacker: GachaBallInstance) -> AbilityDefinition:
	if is_instance_valid(attacker):
		var def = attacker.get_definition()
		if is_instance_valid(def) and "ability_definitions" in def and def.ability_definitions != null:
			for ability in def.ability_definitions:
				if is_instance_valid(ability):
					if ability.id == &"basic_attack" or String(ability.id).begins_with("basic_attack"):
						return ability

	return Database.get_ability_definition(&"basic_attack")

## Enqueue an attack (on_attack trigger + basic attack fallback) for a single actor.
func _enqueue_attack_for(attacker: GachaBallInstance) -> void:
	var is_player = _is_player_unit(attacker)
	# Build context for on_attack trigger (semantic keys per unified broadcast pattern)
	var context := TriggerContext.new()
	context.attacker_uuid = attacker.ball_uuid
	context.trigger_cause = C.CAUSE_TURN
	context.cause_id = C.CAUSE_TURN
	context.trigger_type = C.TRIGGER_WHEN_ATTACKING
	
	var basic_attack_def = get_basic_attack_for(attacker)
	var default_target_type = C.TARGET_FRONTMOST_ENEMY
	if is_instance_valid(basic_attack_def) and not basic_attack_def.effects.is_empty():
		var effect = basic_attack_def.effects[0]
		if is_instance_valid(effect) and effect.target_type != &"":
			default_target_type = effect.target_type
	
	var target_uuids = TargetResolver.resolve_target(attacker.ball_uuid, default_target_type, context, self)
	if target_uuids.is_empty(): return
	var target = get_instance_by_uuid(target_uuids[0])
	if not is_instance_valid(target): return
	
	context.target_uuid = target.ball_uuid
	context.target_initial_hp = target.current_hp
	
	# Trigger on_attack abilities (e.g., Double Strike, Power Amulet)
	# Generic trigger (Power Amulet & Extra Attack both listen to this now, filtered by condition)
	AbilityResolver.process_trigger(C.TRIGGER_WHEN_ATTACKING, context)
	
	# Check if an ability replaced the basic attack
	if context.attack_replaced:
		return
	
	# Mark that on_attack was already triggered - BasicAttackEffect should not re-trigger it
	context.on_attack_already_triggered = true
	
	# Always add basic attack
	if is_instance_valid(basic_attack_def) and not basic_attack_def.effects.is_empty():
		var basic_attack_request = EffectRequest.new(
			attacker.ball_uuid, basic_attack_def.id, basic_attack_def.effects[0],
			[target.ball_uuid], context, C.SubPhase.STANDARD
		)
		enqueue_effect_request(basic_attack_request)


func _resolve_single_effect_request(request: EffectRequest, out_events: Array[CombatEvent], death_tracking: Dictionary = {}) -> void:


	# THIN WRAPPER: Delegates to CombatSimulator
	_combat.resolve_effect_request(request, out_events, death_tracking, self )

## New priority-driven combat phase resolution.
## Uses actor queue with nested reaction loops for cascading effects.
func get_board_snapshot(pre_stats_override: Dictionary = {}) -> Dictionary:
	var snapshot = BattleHelpers.get_combat_board_snapshot(_battle_instances)
	for unit_uuid in pre_stats_override:
		if snapshot.has(unit_uuid):
			var unit_override: Dictionary = pre_stats_override[unit_uuid]
			_apply_unit_stat_override(snapshot[unit_uuid], unit_override)
	var discard_c = get_container(&"DiscardPile")
	if is_instance_valid(discard_c):
		snapshot["__discard_count__"] = discard_c.get_all_non_empty_uuids().size()
	return snapshot

func _resolve_combat_phase() -> void:
	_resolve_animator()
	
	# Wait for any in-flight management-phase async animation chains to finish.
	# Without this, a management Twin Charm buff projectile could still be in flight
	# when play_turn_sequence clears the visual registry, causing apply_pwr_delta
	# to find a null view for the management chain's targets.
	if _is_animating_management_queue:
		await management_animation_queue_completed
	if is_instance_valid(_animator) and _animator.is_playing_sequence():
		await _animator.turn_animation_finished
	
	var start_snapshot: Dictionary = get_board_snapshot()
	var turn_log: Array[CombatEvent] = _simulate_combat_turn()

	# 4. Send Log to Animator (The VCR Playback)
	if not turn_log.is_empty():
		_animator.play_turn_sequence(start_snapshot, turn_log)
	else:
		_is_processing_effect = false
		_on_turn_animation_finished()

func _simulate_combat_turn() -> Array[CombatEvent]:
	_populate_actor_queue()
	_is_processing_effect = true
	_lock_traits()
	_turn_metadata.clear()
	return _combat.execute_combat_turn(self, {})

func _enqueue_ready_effects() -> void:
	var context := TriggerContext.new()
	context.turn = _current_turn
	AbilityResolver.process_trigger(C.TRIGGER_PRE_COMBAT, context)

func get_starting_actor_order() -> Array[String]:
	return CombatSimulatorClass.actor_order(CombatSimulatorClass.starting_actors(_state))

func can_hold_turn_preview() -> bool:
	return _current_battle_phase == Phases.MANAGEMENT and not is_animations_playing() and not ActionQueue.is_busy()

func get_held_turn_preview() -> Dictionary:
	assert(can_hold_turn_preview(), "Preview requires settled preparation")
	assert(_combat.get_crr().is_empty(), "Preview requires a settled reaction queue")
	var live_run: RunState = GameManager.run_state
	assert(live_run != null, "Turn Preview requires an active run")
	var simulation := BattleManager.new()
	simulation._state = _state.copy_for_simulation()
	simulation._current_turn = _current_turn
	simulation._bargain_charm_uses = _bargain_charm_uses.duplicate()
	simulation._specialist_gold_awarded_battle = _specialist_gold_awarded_battle

	# Effect handlers use the active battle, run and RNG streams. Swap the
	# simulation context synchronously while suppressing live signal delivery.
	var live_battle: Node = GameManager.get_battle_manager()
	var uuid_before: Dictionary = UUIDUtils.serialize_state()
	var rng_before: Dictionary = RNGManager.serialize()
	var event_id_before: int = CombatEvent._next_event_id
	var signals_were_blocked: bool = SignalBus.is_blocking_signals()
	var run_data: Dictionary = live_run.to_save_dict(false)
	run_data.erase("rng_state")
	var preview_run := RunState.new()
	SignalBus.set_block_signals(true)
	preview_run.from_save_dict(run_data)
	GameManager.run_state = preview_run
	GameManager.register_battle_manager(simulation)
	RNGManager.deserialize(rng_before)

	var result: Dictionary = simulation._resolve_preview_turn()

	GameManager.run_state = live_run
	GameManager.register_battle_manager(live_battle)
	RNGManager.deserialize(rng_before)
	UUIDUtils.restore_state(uuid_before, live_run.run_id)
	CombatEvent._next_event_id = event_id_before
	SignalBus.set_block_signals(signals_were_blocked)
	simulation.free()
	return result

func _resolve_preview_turn() -> Dictionary:
	_current_battle_phase = Phases.PRE_COMBAT
	_enqueue_ready_effects()
	_is_processing_effect = true
	_resolve_effect_phase([])
	_settle_resolved_board()
	if not _is_battle_over():
		_current_battle_phase = Phases.COMBAT
		_simulate_combat_turn()
		_settle_resolved_board()
	if not _is_battle_over():
		_current_battle_phase = Phases.END_OF_TURN
		_simulate_turn_end_effects()
		_settle_resolved_board()
	var units: Dictionary = {}
	for tag: StringName in [C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP]:
		for unit: GachaBallInstance in get_instances_in_container(tag):
			units[unit.ball_uuid] = VisualDataAdapter.create_visual_data(unit, _battle_instances)
			units[unit.ball_uuid]["container_tag"] = tag
			units[unit.ball_uuid]["slot_index"] = unit.location_slot_index
	return {
		"units": units,
		"player_slot_effects": _state.player_slot_effects.duplicate(),
		"enemy_slot_effects": _state.enemy_slot_effects.duplicate(),
	}

func _trigger_pre_combat_abilities() -> void:
	_enqueue_ready_effects()
	call_deferred("_resolve_pending_reactions_only")

func _on_turn_animation_finished() -> void:
	if _is_entrance_sequence_running:
		return

	if _is_animating_management_queue:
		# Management queue animations are orchestrated exclusively by _process_management_animation_queue
		# A single VCR sequence finishing does not mean the full management queue
		# has drained. The queue owner checks for battle completion after its loop.
		return

	_settle_resolved_board()

	# ALWAYS check for battle over FIRST after animations finish in ANY phase
	# This prevents getting stuck in Management phase if a turn start/end ability wiped the board
	if _is_battle_over():
		if not _battle_over_emitted:
			_battle_over_deferred = false
			_emit_battle_over()
		return
	
	if _current_battle_phase == Phases.PRE_COMBAT:
		# Transition from Pre-Combat (Start of Combat effects) to Combat
		_change_phase(Phases.COMBAT)
		# Start the main combat simulation
		call_deferred("_resolve_combat_phase")
		return
		
	if _current_battle_phase == Phases.START_OF_TURN:
		# Turn start abilities finished animating, transition to MANAGEMENT
		_change_phase(Phases.MANAGEMENT)
		# Force a UI refresh to reflect any silent updates (e.g., traits) that occurred during the animation
		_emit_battle_inventory_changed()
		SignalBus.emit_signal("inventory_ui_refresh_requested")
	elif _current_battle_phase == Phases.END_OF_TURN:
		# Poison/turn-end animations finished, now start the next turn
		_change_phase(Phases.START_OF_TURN)
	elif _current_battle_phase == Phases.COMBAT:
		# After combat finishes, trigger end of turn abilities, then start next turn
		_change_phase(Phases.END_OF_TURN)


func _settle_resolved_board() -> void:
	_is_processing_effect = false

	# Finalize any remaining deaths (removes zombies)
	_finalize_deaths()

	if _pending_inventory_refresh:
		_pending_inventory_refresh = false
		_emit_battle_inventory_changed()

func _check_for_deaths(is_simulation: bool = false, out_events = null) -> void:
	# THIN WRAPPER: Delegates to KnockoutProcessor
	KnockoutProcessor.check_for_knockouts(is_simulation, out_events, self )
		
## Centralized logic for cleaning up a dead unit.
## Moves player units to discard, removes enemy units entirely.

## Snapshot equipped items for context enrichment (effects should use context, not query instances)
func _snapshot_equipped_items(unit: GachaBallInstance) -> Array[Dictionary]:
	# THIN WRAPPER: Delegates to KnockoutProcessor
	return KnockoutProcessor.snapshot_equipped_items(unit, _battle_instances)

# -----------------------------------------------------------------------------
# UNIFIED DEATH TRACKING
# -----------------------------------------------------------------------------
# These functions provide the SINGLE source of truth for death tracking within a turn.
# All code paths that detect deaths must use _register_death() to ensure:
#   1. Each unit dies exactly ONCE per turn
#   2. DEATH events are generated exactly ONCE per death
#   3. Death triggers (on_death, on_ally_death) fire exactly ONCE per death

## Register a unit as dead. Returns true if this is a NEW death, false if already registered.
## This is the ONLY function that should mark a unit as dead. All death detection code paths
## must call this before creating DEATH events or firing triggers.
func _register_death(unit: GachaBallInstance, phase: StringName) -> bool:
	return KnockoutProcessor.register_knockout(_state, unit, phase)

func is_dead_this_turn(unit_uuid: String) -> bool:
	return KnockoutProcessor.is_knocked_out_this_turn(_state, unit_uuid)

func get_death_info(unit_uuid: String) -> Dictionary:
	return KnockoutProcessor.get_knockout_info(_state, unit_uuid)

func _perform_unit_death_cleanup(unit: GachaBallInstance) -> void:
	# Delegate to KnockoutProcessor with strongly typed deferred erasures array
	KnockoutProcessor.perform_unit_knockout_cleanup(_state, unit, _state.deferred_enemy_erasures)
	
	# Trigger on_board_state_changed to dynamically update passive effects mid-combat
	var board_ctx := TriggerContext.new()
	board_ctx.is_simulation = true
	AbilityResolver.process_trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED, board_ctx)

## Check if a unit has any abilities that can execute after receiving lethal damage.
## This is determined by the `execute_before_knockout` flag on AbilityDefinition.
func _has_lethal_counter_abilities(unit: GachaBallInstance) -> bool:
	return KnockoutProcessor.has_before_knockout_counter_abilities(unit, _battle_instances)


## Enhanced death checking that defers death events for units with counter-attacks
func _check_for_deaths_with_counter_delay(is_simulation: bool = false, out_events = null, death_tracking = null) -> void:
	# THIN WRAPPER: Delegates to KnockoutProcessor
	KnockoutProcessor.check_for_knockouts_with_counter_delay(is_simulation, out_events, death_tracking, self )


## Helper function to create DEATH events only once per unit
func _create_death_event_if_needed(unit_uuid: String, out_events: Array, death_tracking: Dictionary) -> void:
	if death_tracking.has(unit_uuid):
		return # Already created death event for this unit
	
	death_tracking[unit_uuid] = true
	out_events.append(CombatEvent.new(CombatEvent.Type.KNOCKOUT, {
		"target_uuids": [unit_uuid],
		"visual_payload": CombatPayload.new()
	}))

## Check if any deferred counter-attack units have completed their abilities and should now die
func _process_completed_counter_deaths(out_events = null, death_tracking = null) -> void:
	# THIN WRAPPER: Delegates to KnockoutProcessor
	KnockoutProcessor.process_completed_counter_knockouts(out_events, death_tracking, self )

## Helper function to process deferred on_ally_death triggers after counter-attacks resolve
func _process_deferred_ally_death(ko_uuid: String, team: String) -> void:
	# THIN WRAPPER: Delegates to KnockoutProcessor
	KnockoutProcessor.process_deferred_ally_knockout(ko_uuid, team, self )

func _on_apply_deaths_requested(dead_unit_uuids: Array) -> void:
	if dead_unit_uuids == null:
		return
	for uuid in dead_unit_uuids:
		var unit := get_instance_by_uuid(String(uuid))
		if not is_instance_valid(unit):
			continue
		# Apply the same non-simulation removal rules as in _check_for_deaths
		var def = unit.get_definition()
		if is_instance_valid(def) and def.category == &"UNIT":
			_perform_unit_death_cleanup(unit)
	# NOTE: Do NOT emit battle_inventory_changed here!
	# BattleAnimator handles visual cleanup (queue_free) during death animation.
	# Emitting this signal mid-animation would cause BattleView to redraw
	# from the current Model state, spoiling future damage/heal values.
	# If battle is now over, defer victory to end of animations
	var _player_lineup = get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var _enemy_lineup = get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	if _current_battle_phase == Phases.COMBAT and _is_battle_over():
		_battle_over_deferred = true

func _is_battle_over() -> bool:
	return _determine_battle_result().is_over

## Determine the current battle result. Single source of truth for victory/defeat logic.
## @return Dictionary with keys:
##   - is_over: bool - Whether battle has ended
##   - player_won: bool - If over, did player win?
##   - reason: StringName - "hero_death", "team_wipe", or "enemy_wipe"
func _determine_battle_result() -> Dictionary:
	if _is_entrance_sequence_running:
		return {"is_over": false, "player_won": false, "reason": &""}

	var player_lineup = get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var enemy_lineup = get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	
	# Check if any hero died THIS TURN (via death registry - catches heroes already moved to discard)
	var dead_this_turn: Dictionary = _state.get_dead_this_turn()
	for uuid in dead_this_turn.keys():
		var death_info: Dictionary = dead_this_turn[uuid]
		if death_info.get("team") == "PLAYER":
			var def_id: StringName = death_info.get("def_id", &"")
			if not def_id.is_empty():
				var unit_def = Database.get_definition(def_id)
				if is_instance_valid(unit_def) and unit_def.is_hero:
					return {"is_over": true, "player_won": false, "reason": &"hero_death"}
	
	# Also check living units in lineup (in case death hasn't been registered yet)
	for unit in player_lineup:
		var def = unit.get_definition()
		if is_instance_valid(def) and def.is_hero and unit.current_hp <= 0:
			return {"is_over": true, "player_won": false, "reason": &"hero_death"}
	
	# Check if any player units are alive
	var player_has_alive = false
	for unit in player_lineup:
		if unit.current_hp > 0:
			player_has_alive = true
			break
	if not _state.staged_hero_placement.is_empty():
		player_has_alive = true
	if not player_has_alive and _current_battle_phase == Phases.MANAGEMENT:
		for unit: GachaBallInstance in get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF):
			if unit.current_hp > 0 and _state.get_equipped_incubator(unit) != null:
				player_has_alive = true
				break
	
	# Check if any enemy units are alive
	var enemy_has_alive = false
	for unit in enemy_lineup:
		if unit.current_hp > 0:
			enemy_has_alive = true
			break
	if not _state.staged_enemy_placements.is_empty():
		enemy_has_alive = true
	
	# Determine outcome
	if not player_has_alive:
		return {"is_over": true, "player_won": false, "reason": &"team_wipe"}
	elif not enemy_has_alive:
		return {"is_over": true, "player_won": true, "reason": &"enemy_wipe"}
	else:
		return {"is_over": false, "player_won": false, "reason": &""}

func _emit_battle_over() -> void:
	# Transition to BATTLE_OVER and emit results once animations are finished.
	_change_phase(Phases.BATTLE_OVER)
	if not _battle_over_emitted:
		_battle_over_emitted = true
		
		var result := _determine_battle_result()
		var results: Dictionary = {"victory": result.player_won, "reason": result.reason}
		SignalBus.emit_signal("battle_ended", results)
		if result.player_won:
			_on_battle_victory()

func _on_gacha_tokens_changed(_new_amount: int) -> void:
	# Trigger "on_gacha_tokens_changed" abilities
	# This allows units like Templar to update their stats immediately when tokens change.
	# We don't need to pass the amount in context because the effect will query the current amount.
	var pre_stats := _capture_all_unit_stats()
	AbilityResolver.process_trigger(C.TRIGGER_ON_GACHA_TOKENS_CHANGED, TriggerContext.new())
	
	if not _is_drawing and _current_battle_phase == Phases.MANAGEMENT and not _is_processing_effect:
		var passive_events = _combat.process_reaction_queue(self, {})
		if not passive_events.is_empty():
			var snapshot = VisualDataAdapter.create_board_snapshot(self.get_all_instances())
			for unit_uuid in pre_stats:
				if snapshot.has(unit_uuid):
					var unit_override: Dictionary = pre_stats[unit_uuid]
					_apply_unit_stat_override(snapshot[unit_uuid], unit_override)
			enqueue_management_animation(snapshot, passive_events)
			_pending_inventory_refresh = true

func _on_battle_victory() -> void:
	# Note: All battle instances (including the hero's battle copy) will be garbage collected
	# when the battle scene is freed, leaving RunState's hero instance and slot untouched.
	pass

## Resolve targets for an effect based on target type and context.
## @param source_uuid: String - The UUID of the source instance
## @param target_type: StringName - The type of target to resolve (e.g., "SELF", "FRONTMOST_ENEMY")
## @param context: TriggerContext - The context of the event
## @return Array[String] - Array of target UUIDs

func resolve_target(source_uuid: String, target_type: StringName, context: TriggerContext = null) -> Array[String]:
	if context == null:
		context = TriggerContext.new()
	return TargetResolver.resolve_target(source_uuid, target_type, context, self)

## Check if a condition is met for an ability.
## @param condition_def: ConditionDefinition - The condition to check
## @param source_uuid: String - The UUID of the source instance
## @param context: TriggerContext - The context of the event
## @return bool - True if condition is met
func check_condition(condition_def: ConditionDefinition, source_uuid: String, context: TriggerContext = null) -> bool:
	if context == null:
		context = TriggerContext.new()
	return TargetResolver.check_condition(condition_def, source_uuid, context, self)


## Enqueue an effect request for processing.
## @param effect_request: EffectRequest - The effect request to enqueue
func enqueue_effect_request(request: EffectRequest) -> void:
	## Route request through CRR to ensure proper priority and scope tracking
	_combat.enqueue_reaction(request)

## Get the current size of the pending reactions queue.
## Used by BasicAttackEffect to capture the queue state before triggering on_before_attack.
func get_pending_reactions_size() -> int:
	return _pending_reactions.size()

func begin_reaction_scope() -> int:
	return _combat.begin_reaction_scope()

func drain_reaction_scope(scope_id: int) -> Array[CombatEvent]:
	return _combat.drain_reaction_scope(scope_id, self)

func drain_reaction_scope_matching(scope_id: int, predicate: Callable) -> Array[CombatEvent]:
	return _combat.drain_reaction_scope_matching(scope_id, predicate, self)

func adopt_into_reaction_scope(scope_id: int, predicate: Callable) -> void:
	_combat.adopt_into_reaction_scope(scope_id, predicate)

func drain_interceptions() -> Array[CombatEvent]:
	return _combat.drain_interceptions(self)

func drain_lethal_counters() -> Array[CombatEvent]:
	return _combat.drain_lethal_counters(self)

func drain_cascade() -> Array[CombatEvent]:
	return _combat.drain_cascade(self)

func collect_inline_events() -> Array[CombatEvent]:
	# THIN WRAPPER: Delegates to CombatSimulator
	return _combat.collect_and_clear_inline_events()


## Get an instance by UUID.
## @param uuid: String - The UUID of the instance
## @return GachaBallInstance - The instance, or null if not found
func get_instance_by_uuid(uuid: String) -> GachaBallInstance:
	return _battle_instances.get(uuid, null)

## Get the Hero's UUID (player's hero unit in PlayerLineup, staged hero, or first available player unit).
func get_hero_uuid() -> String:
	var player_lineup = get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	if is_instance_valid(player_lineup):
		var first_non_empty := ""
		for i in range(player_lineup.get_size()):
			var uuid = player_lineup.get_uuid(i)
			if uuid.is_empty():
				continue
			if first_non_empty.is_empty():
				first_non_empty = uuid
			var inst := get_instance(uuid)
			if is_instance_valid(inst):
				var def = inst.get_definition()
				if is_instance_valid(def) and def.is_hero:
					return uuid
		if not first_non_empty.is_empty():
			return first_non_empty
	if not _state.staged_hero_placement.is_empty():
		return _state.staged_hero_placement.get("uuid", "")
	return ""

## Check if a unit is on the player's side.
## @param instance: GachaBallInstance - The instance to check
## @return bool - True if the unit is on the player's side
func _is_player_unit(instance: GachaBallInstance) -> bool:
	return _state.is_player_unit(instance)

func _is_in_player_container_tag(tag: StringName) -> bool:
	return _state.is_in_player_container_tag(tag)

func _is_player_owned(instance: GachaBallInstance) -> bool:
	return _state.is_player_owned(instance)

## Check if the current hero is the Timekeeper (for bonus token passive)
func _is_timekeeper_hero() -> bool:
	if not is_instance_valid(GameManager.run_state):
		return false
	var hero: GachaBallInstance = GameManager.run_state.hero_instance
	if not is_instance_valid(hero):
		return false
	var def: GachaBallDefinition = hero.get_definition()
	if not is_instance_valid(def):
		return false
	return def.id == &"hero_timekeeper"

## Get the ally unit behind the source unit.
## @param source_instance: GachaBallInstance - The source unit
## @return GachaBallInstance - The ally behind, or null if none
func _get_definition_display_name(definition: Resource) -> String:
	return BattleHelpers.get_definition_display_name(definition)

func _get_instance_display_name(inst: GachaBallInstance) -> String:
	return BattleHelpers.get_instance_display_name(inst)

func _get_ally_behind(source_instance: GachaBallInstance, allow_dying: bool = false) -> GachaBallInstance:
	return BattleHelpers.get_ally_behind(_state, source_instance, allow_dying)

## Get the slot ahead of the source unit.
## @param source_instance: GachaBallInstance - The source unit
## @return GachaBallInstance - The unit ahead, or null if empty
func _get_slot_ahead(source_instance: GachaBallInstance) -> GachaBallInstance:
	return BattleHelpers.get_slot_ahead(_state, source_instance)

## Get adjacent allies (front and back).
## @param source_instance: GachaBallInstance - The source unit
## @return Array[GachaBallInstance] - Array of adjacent allies
func _get_adjacent_allies(source_instance: GachaBallInstance) -> Array[GachaBallInstance]:
	return BattleHelpers.get_adjacent_allies(_state, source_instance)

## Look up an ability definition by ID from a source unit or its equipped items.
## @param ability_id: StringName - The ability ID to look up
## @param source: GachaBallInstance - The unit to search (and its equipped items)
## @return AbilityDefinition if found, null otherwise
func _get_ability_definition(ability_id: StringName, source: GachaBallInstance) -> AbilityDefinition:
	if not is_instance_valid(source):
		return null

	for entry in source.get_active_ability_entries(get_all_instances()):
		var ability_def: AbilityDefinition = entry.get("ability_def")
		if is_instance_valid(ability_def) and ability_def.id == ability_id:
			return ability_def

	return null

## Trigger on_hurt event for a unit that took damage.
## @param target_uuid: String - The UUID of the unit that took damage
## @param damage_amount: int - The amount of damage taken
## @param attacker_uuid: String - The UUID of the unit that caused the damage
## Apply a stat change to an instance and return the new value.
## This is the SINGLE modification point for all stat changes (HP, PWR, status effects).
## Ensures snapshots are always captured post-change for VCR pattern.
## @param instance: GachaBallInstance to modify
## @param stat_type: String - "hp", "pwr", "burn_stacks", etc.
## @param delta: int - Amount to change (positive or negative)
## @return Variant - New value after change, or null if operation was skipped (e.g., damage to dead unit)
## Apply a stat delta to an instance. Returns the new stat value or damage result.
## For HP damage, returns a Dictionary with armor mitigation data for animations.
## @param instance: The target instance
## @param stat_type: The stat to modify ("hp", "pwr", "burn_stacks", etc.)
## @param delta: The amount to add (negative for damage)
## @param bypass_armor: If true, damage bypasses armor (for future armor-piercing abilities)

# ============================================================================
# DAMAGE & STAT DELTAS
# ============================================================================

func get_bonus_burn_stacks_for_attack(source: GachaBallInstance, target: GachaBallInstance = null) -> int:
	return TraitRulesEngine.get_bonus_burn_stacks_for_attack(source, target, self)

func _emit_inline_trait_status_event(source_uuid: String, target: GachaBallInstance, stat_name: String, delta: int, old_val: int, new_val: int, ability_id: StringName) -> void:
	if new_val == old_val:
		return
	_combat.add_inline_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
		"source_uuid": source_uuid,
		"target_uuids": [target.ball_uuid],
		"ability_id": ability_id,
		"visual_payload": CombatPayload.status_change(source_uuid, delta, stat_name, [old_val], [new_val])
	}))

func _emit_inline_trait_buff_event(source_uuid: String, target: GachaBallInstance, stat_name: String, delta: int, old_val: int, new_val: int, ability_id: StringName) -> void:
	if new_val == old_val:
		return
	var payload: CombatPayload
	if stat_name == "hp":
		var target_def := target.get_definition()
		var max_hp: int = target_def.base_hp if is_instance_valid(target_def) and "base_hp" in target_def else new_val
		payload = CombatPayload.hp_buff(source_uuid, delta, [old_val], [new_val], [max_hp])
	else:
		payload = CombatPayload.pwr_buff(source_uuid, delta, [old_val], [new_val])
	_combat.add_inline_event(CombatEvent.new(CombatEvent.Type.BUFF, {
		"source_uuid": source_uuid,
		"target_uuids": [target.ball_uuid],
		"ability_id": ability_id,
		"action_type": C.ACTION_BUFF,
		"visual_payload": payload
	}))

func apply_damage(instance: GachaBallInstance, amount: int, damage_type: int, attacker_uuid: String = "") -> Dictionary:
	assert(is_instance_valid(instance), "apply_damage: instance is null")
	
	if instance.current_hp <= 0 or amount <= 0:
		return {}
		
	var actual_damage = amount
	var armor_consumed = 0
	var old_armor: int = instance.get_status_effect_amount(&"armor")
	var new_armor: int = old_armor
	var is_in_lineup: bool = _is_lineup_container(instance.location_container_tag)
	
	# CENTRALIZED ARMOR MITIGATION: All HP damage goes through armor first (unless non-attack: BURN)
	if is_in_lineup and damage_type != C.DamageType.BURN:
		if old_armor > 0:
			armor_consumed = mini(old_armor, actual_damage)
			var hp_damage = actual_damage - armor_consumed
			actual_damage = hp_damage if hp_damage > 0 else 0
			# Consume armor stacks
			instance.add_status_effect_silent(&"armor", -armor_consumed)
			new_armor = instance.get_status_effect_amount(&"armor")
			TraitRulesEngine.apply_on_armor_absorbed_traits(instance, attacker_uuid, self)
			
	var new_hp = instance.current_hp - actual_damage
	
	if actual_damage > 0:
		var comp = StatComponent.new()
		comp.id = &"battle_damage"
		comp.category = &"COMBAT_STATE"
		comp.modifiers = {"hp": -actual_damage}
		instance.battle_components.append(comp)
		
	instance.set_current_hp_silent(new_hp)
	if new_hp <= 0:
		_state.record_lethal_transition(instance.ball_uuid)
	
	# SPIKES REFLECTION
	var spikes_data: Dictionary = {}
	if is_in_lineup and damage_type == C.DamageType.MELEE and not attacker_uuid.is_empty():
		var old_spikes = instance.get_status_effect_amount(&"spikes")
		if old_spikes > 0:
			var attacker = get_instance_by_uuid(attacker_uuid)
			if is_instance_valid(attacker) and attacker.current_hp > 0:
				var spikes_damage = old_spikes
				var attacker_old_hp = attacker.current_hp
				
				var damage_result = apply_damage(attacker, spikes_damage, C.DamageType.SPIKES, "")
				
				var attacker_new_hp = attacker.current_hp
				var spikes_armor_consumed = 0
				var spikes_new_armor = attacker.get_status_effect_amount(&"armor")
				
				if not damage_result.is_empty():
					attacker_new_hp = damage_result.get("new_hp", attacker_new_hp)
					spikes_armor_consumed = damage_result.get("armor_consumed", 0)
					spikes_new_armor = damage_result.get("new_armor", spikes_new_armor)
				
				# Decay spikes by 1 stack
				instance.add_status_effect_silent(&"spikes", -1)
				var new_spikes = instance.get_status_effect_amount(&"spikes")
				
				spikes_data = {
					"spikes_triggered": true,
					"spikes_damage": spikes_damage,
					"armor_consumed": spikes_armor_consumed,
					"new_armor": spikes_new_armor,
					"attacker_uuid": attacker_uuid,
					"attacker_old_hp": attacker_old_hp,
					"attacker_new_hp": attacker_new_hp,
					"defender_uuid": instance.ball_uuid,
					"old_spikes": old_spikes,
					"new_spikes": new_spikes
				}
				
	var result = {
		"new_hp": new_hp,
		"armor_consumed": armor_consumed,
		"old_armor": old_armor,
		"new_armor": new_armor,
		"hp_damage": actual_damage
	}
	if not spikes_data.is_empty():
		result["spikes_data"] = spikes_data
		
	return result

func apply_permanent_stat_delta(instance: GachaBallInstance, stat_type: String, delta: int, source_id: String) -> Variant:
	assert(is_instance_valid(instance), "apply_permanent_stat_delta: instance is null")
	
	if delta == 0:
		return instance.current_hp if stat_type == "hp" else instance.current_pwr
		
	var hp_delta = delta if stat_type == "hp" else 0
	var pwr_delta = delta if stat_type == "pwr" else 0
	
	instance.add_or_update_stat_component(
		StringName(source_id + "_permanent"),
		&"PERMANENT_BUFF",
		source_id,
		hp_delta,
		pwr_delta,
		false,
		"Permanent Buff",
		"Permanent stat increase"
	)
	
	return apply_stat_delta(instance, stat_type, delta, source_id, C.ACTION_BUFF, false, &"", &"", {}, C.BUFF_SUBGROUP_PERMANENT)

func apply_stat_delta(instance: GachaBallInstance, stat_type: String, delta: int, source_uuid: String = "", action_type: StringName = &"", is_stackable: bool = true, source_category: StringName = &"", source_def_id: StringName = &"", extra_context: Dictionary = {}, buff_subgroup: StringName = &"") -> Variant:
	assert(is_instance_valid(instance), "apply_stat_delta: instance is null")
	var is_in_lineup: bool = _is_lineup_container(instance.location_container_tag)
	
	if buff_subgroup.is_empty() and action_type == C.ACTION_BUFF:
		buff_subgroup = C.BUFF_SUBGROUP_DISCRETE if is_stackable else C.BUFF_SUBGROUP_CONDITIONAL
	
	if source_category.is_empty() and not source_uuid.is_empty():
		var src_inst = get_instance_by_uuid(source_uuid)
		if is_instance_valid(src_inst) and is_instance_valid(src_inst.get_definition()):
			source_category = src_inst.get_definition().category
			if source_def_id.is_empty():
				source_def_id = src_inst.definition_id

	match stat_type:
		"hp":
			if delta == 0:
				return instance.current_hp
				
			if delta > 0:
				assert(action_type in [C.ACTION_HEAL, C.ACTION_BUFF], "apply_stat_delta: positive HP delta requires ACTION_HEAL or ACTION_BUFF, got '%s'" % action_type)
				var new_hp = instance.current_hp + delta
				
				if is_stackable or action_type == C.ACTION_HEAL:
					var comp = StatComponent.new()
					if source_category == C.CATEGORY_CONSUMABLE:
						comp.id = StringName("consumable_buff_hp_" + str(instance.battle_components.size()))
						comp.category = &"CONSUMABLE"
						comp.source_type = &"CONSUMABLE"
						comp.source_id = String(source_def_id) if not source_def_id.is_empty() else source_uuid
						comp.allow_stacking = true
					else:
						comp.id = &"battle_heal" if action_type == C.ACTION_HEAL else &"battle_buff_hp"
						comp.category = &"COMBAT_STATE"
						comp.source_type = &"BATTLE_BUFF" if action_type == C.ACTION_BUFF else &"COMBAT_STATE"
						comp.source_id = source_uuid
					comp.modifiers = {"hp": delta}
					instance.battle_components.append(comp)
				
				instance.set_current_hp_silent(new_hp)
				if new_hp > 0:
					_state.clear_lethal_transition(instance.ball_uuid)
				
				if action_type == C.ACTION_HEAL:
					TraitRulesEngine.apply_on_heal_traits(instance, source_uuid, is_in_lineup, self)

					var heal_ctx := TriggerContext.new()
					heal_ctx.healed_uuid = instance.ball_uuid
					heal_ctx.unit_uuid = instance.ball_uuid
					heal_ctx.triggering_uuid = instance.ball_uuid
					heal_ctx.source_uuid = source_uuid
					heal_ctx.healer_uuid = source_uuid
					heal_ctx.heal_amount = delta
					heal_ctx.amount = delta
					heal_ctx.is_stackable = is_stackable
					AbilityResolver.process_trigger(C.TRIGGER_WHEN_HEALED, heal_ctx)
				elif action_type == C.ACTION_BUFF:
					var trigger_ctx := TriggerContext.new()
					trigger_ctx.unit_uuid = instance.ball_uuid
					trigger_ctx.triggering_uuid = instance.ball_uuid
					trigger_ctx.source_uuid = source_uuid
					trigger_ctx.stat = "hp"
					trigger_ctx.amount = delta
					trigger_ctx.is_stackable = is_stackable
					trigger_ctx.buff_subgroup = buff_subgroup
					if extra_context.has("is_echo"):
						trigger_ctx.is_echo = bool(extra_context["is_echo"])
					AbilityResolver.process_trigger(C.TRIGGER_ON_STAT_INCREASED, trigger_ctx)
				
				return new_hp
			else:
				# delta < 0: HP debuff (GCD §7: Debuffs cannot drop HP below 1)
				assert(action_type == C.ACTION_DEBUFF, "apply_stat_delta: negative HP delta requires ACTION_DEBUFF, got '%s'. Direct damage must use apply_damage()!" % action_type)
				var current_val: int = instance.current_hp
				var clamped_new_hp: int = maxi(1, current_val + delta)
				var actual_delta: int = clamped_new_hp - current_val
				
				if actual_delta != 0:
					var comp := StatComponent.new()
					comp.id = &"battle_debuff_hp"
					comp.category = &"COMBAT_STATE"
					comp.modifiers = {"hp": actual_delta}
					instance.battle_components.append(comp)
					instance.set_current_hp_silent(clamped_new_hp)
					
					var hp_dec_ctx := TriggerContext.new()
					hp_dec_ctx.unit_uuid = instance.ball_uuid
					hp_dec_ctx.triggering_uuid = instance.ball_uuid
					hp_dec_ctx.source_uuid = source_uuid
					hp_dec_ctx.stat = "hp"
					hp_dec_ctx.amount = abs(actual_delta)
					hp_dec_ctx.is_stackable = is_stackable
					AbilityResolver.process_trigger(C.TRIGGER_ON_STAT_DECREASED, hp_dec_ctx)
				
				return clamped_new_hp
				
		"pwr":
			if delta == 0:
				return instance.current_pwr
				
			if delta > 0:
				assert(action_type == C.ACTION_BUFF, "apply_stat_delta: positive PWR delta requires ACTION_BUFF, got '%s'" % action_type)
				var battle_component_count := instance.battle_components.size()
				var new_pwr = instance.apply_pwr_delta(delta, {"silent": true})
				
				if instance.battle_components.size() > battle_component_count:
					var gain_component = instance.battle_components[-1]
					if gain_component is StatComponent and gain_component.id == &"battle_pwr_gain":
						if source_category == C.CATEGORY_CONSUMABLE:
							gain_component.id = StringName("consumable_buff_pwr_" + str(instance.battle_components.size()))
							gain_component.category = &"CONSUMABLE"
							gain_component.source_type = &"CONSUMABLE"
							gain_component.source_id = String(source_def_id) if not source_def_id.is_empty() else source_uuid
							gain_component.allow_stacking = true
						elif is_stackable:
							gain_component.id = &"battle_buff_pwr"
							gain_component.source_type = &"BATTLE_BUFF"
							gain_component.source_id = source_uuid
						else:
							# Non-stackable deltas are continuous auras or represented by a separate
							# persistent component. Tag as AURA so merges never inherit this runtime delta.
							gain_component.source_type = &"AURA"
							gain_component.source_id = source_uuid
				
				var trigger_ctx := TriggerContext.new()
				trigger_ctx.unit_uuid = instance.ball_uuid
				trigger_ctx.triggering_uuid = instance.ball_uuid
				trigger_ctx.source_uuid = source_uuid
				trigger_ctx.stat = "pwr"
				trigger_ctx.amount = delta
				trigger_ctx.is_stackable = is_stackable
				trigger_ctx.buff_subgroup = buff_subgroup
				if extra_context.has("is_echo"):
					trigger_ctx.is_echo = bool(extra_context["is_echo"])
				AbilityResolver.process_trigger(C.TRIGGER_ON_STAT_INCREASED, trigger_ctx)
				
				return new_pwr
			else:
				assert(action_type == C.ACTION_DEBUFF, "apply_stat_delta: negative PWR delta requires ACTION_DEBUFF, got '%s'" % action_type)
				var new_pwr = instance.apply_pwr_delta(delta, {"silent": true})
				
				var pwr_dec_ctx := TriggerContext.new()
				pwr_dec_ctx.unit_uuid = instance.ball_uuid
				pwr_dec_ctx.triggering_uuid = instance.ball_uuid
				pwr_dec_ctx.source_uuid = source_uuid
				pwr_dec_ctx.stat = "pwr"
				pwr_dec_ctx.amount = abs(delta)
				pwr_dec_ctx.is_stackable = is_stackable
				AbilityResolver.process_trigger(C.TRIGGER_ON_STAT_DECREASED, pwr_dec_ctx)
				
				return new_pwr
				
		"burn_stacks":
			if TraitRulesEngine.try_intercept_appliance_status(instance, "burn", delta, source_uuid, is_in_lineup, self):
				return instance.status_effects.get(&"burn", 0)
			instance.add_status_effect_silent(&"burn", delta)
			return instance.status_effects.get(&"burn", 0)
		_:
			if stat_type.ends_with("_stacks"):
				var effect_name = stat_type.trim_suffix("_stacks")
				if TraitRulesEngine.try_intercept_appliance_status(instance, effect_name, delta, source_uuid, is_in_lineup, self):
					return instance.status_effects.get(StringName(effect_name), 0)

				instance.add_status_effect_silent(StringName(effect_name), delta)
				TraitRulesEngine.apply_on_status_gained_traits(instance, effect_name, delta, source_uuid, is_in_lineup, self)

				return instance.status_effects.get(StringName(effect_name), 0)
			else:
				push_error("Unknown stat type: %s" % stat_type)
				return 0

## Central combat gold disbursement API.
## Incrementally adds gold, emits visual events, and triggers on_gold_earned for each 1 gold.
func earn_gold(amount: int, origin_uuid: String = "") -> void:
	assert(amount > 0, "earn_gold: amount must be > 0")
	for i in range(amount):
		var target_gold_amount := 0
		if is_instance_valid(GameManager.run_state):
			GameManager.run_state.add_gold(1, true)
			target_gold_amount = GameManager.run_state.gold
		
		var gold_payload := CombatPayload.new()
		gold_payload.amount = 1
		gold_payload.origin_uuid = origin_uuid
		gold_payload.target_gold_amount = target_gold_amount
		
		_combat.add_inline_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "Earned 1 Gold!"
		}))
		_combat.add_inline_event(CombatEvent.new(CombatEvent.Type.GOLD_GAIN, {
			"source_uuid": origin_uuid,
			"target_uuids": [origin_uuid] if not origin_uuid.is_empty() else [],
			"amount": 1,
			"visual_payload": gold_payload
		}))
		
		var gold_ctx := TriggerContext.new()
		gold_ctx.is_simulation = true
		gold_ctx.source_uuid = origin_uuid
		AbilityResolver.process_trigger(C.TRIGGER_ON_GOLD_EARNED, gold_ctx)

## Central combat gold spending API.
## Spends gold silently without triggering on_gold_earned, emitting visual spend events.
func spend_gold(amount: int, origin_uuid: String = "") -> bool:
	assert(amount > 0, "spend_gold: amount must be > 0")
	if not is_instance_valid(GameManager.run_state):
		return false
	if not GameManager.run_state.spend_gold(amount, true):
		return false
	
	if is_instance_valid(_combat):
		var target_gold_amount := GameManager.run_state.gold
		var gold_payload := CombatPayload.new()
		gold_payload.amount = amount
		gold_payload.origin_uuid = origin_uuid
		gold_payload.target_gold_amount = target_gold_amount
		
		_combat.add_inline_event(CombatEvent.new(CombatEvent.Type.GOLD_SPEND, {
			"source_uuid": origin_uuid,
			"target_uuids": [origin_uuid] if not origin_uuid.is_empty() else [],
			"amount": amount,
			"visual_payload": gold_payload
		}))

	var spend_ctx := TriggerContext.new()
	spend_ctx.is_simulation = true
	spend_ctx.source_uuid = origin_uuid
	spend_ctx.amount = amount
	AbilityResolver.process_trigger(C.TRIGGER_ON_GOLD_SPENT, spend_ctx)

	return true

func trigger_on_hurt(target_uuid: String, damage_amount: int, attacker_uuid: String, cause: StringName = C.CAUSE_ATTACK, status_id: StringName = &"", trigger_damage_dealt: bool = true) -> void:
	# Get target instance data for context (effects should not query instances directly)
	var target_instance = get_instance_by_uuid(target_uuid)
	var victim_team := ""
	var victim_current_hp := 0
	var victim_category: StringName = &""
	if is_instance_valid(target_instance):
		victim_current_hp = target_instance.current_hp
		var target_definition = target_instance.get_definition()
		if is_instance_valid(target_definition):
			victim_category = target_definition.category
		if target_instance.location_container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP:
			victim_team = "PLAYER"
		elif target_instance.location_container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
			victim_team = "ENEMY"
	
	# LIFESTEAL TIMING FIX: Process on_damage_dealt BEFORE on_hurt
	if trigger_damage_dealt and not attacker_uuid.is_empty():
		# Resolve the actual attacking UNIT - if attacker is an item, get the holder
		var actual_attacker_uuid := attacker_uuid
		var attacker_instance = get_instance_by_uuid(attacker_uuid)
		if is_instance_valid(attacker_instance):
			var attacker_def = attacker_instance.get_definition()
			if is_instance_valid(attacker_def) and attacker_def.category == &"ITEM":
				if not attacker_instance.equipped_on_uuid.is_empty():
					actual_attacker_uuid = attacker_instance.equipped_on_uuid
		
		TurnAbilities.trigger_on_damage_dealt(actual_attacker_uuid, target_uuid, damage_amount, victim_current_hp, cause)
	
	# Trigger on_hurt for the victim (counter-attacks, etc.) AFTER lifesteal
	TurnAbilities.trigger_on_hurt(target_uuid, damage_amount, attacker_uuid, victim_team, victim_current_hp, cause, status_id, victim_category)
	TraitRulesEngine.apply_on_hurt_traits(target_instance, victim_team, attacker_uuid, cause, self)

	# NEW: Also fire on_ally_hurt for reactive abilities that watch teammates
	var victim_loc = get_location_for_uuid(target_uuid)
	var victim_slot_index: int = victim_loc.index if is_instance_valid(victim_loc) else -1
	TurnAbilities.trigger_on_ally_hurt(target_uuid, damage_amount, attacker_uuid, victim_team, victim_slot_index)


## Trigger on_kill event for a unit that killed another unit.
## @param killer_uuid: String - The UUID of the unit that got the kill
## @param killed_uuid: String - The UUID of the unit that was killed
func trigger_on_kill(killer_uuid: String, killed_uuid: String) -> void:
	TurnAbilities.trigger_on_kill(killer_uuid, killed_uuid)
	TraitRulesEngine.apply_on_kill_traits(get_instance_by_uuid(killer_uuid), get_instance_by_uuid(killed_uuid), self)

## Trigger on_battle_start abilities for all units.
func _trigger_battle_start_abilities() -> void:
	# First, fire on_board_enter for all units currently on the board
	var all_units = (
		get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
		+ get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	)
	for unit in all_units:
		if is_instance_valid(unit) and unit.current_hp > 0:
			var enter_ctx := TriggerContext.new()
			enter_ctx.entered_uuid = unit.ball_uuid
			AbilityResolver.process_trigger(C.TRIGGER_ON_ENTER_BOARD, enter_ctx)
			
	TurnAbilities.trigger_battle_start_abilities(_state)
	# Trigger passive scaling right after battle start abilities
	var board_ctx := TriggerContext.new()
	board_ctx.is_simulation = true
	AbilityResolver.process_trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED, board_ctx)
	
	# BUGFIX: Delay erasing enemy instances from memory until _on_turn_animation_finished
	# so that players can inspect them while they are animating their death or combat actions.
	# _flush_deferred_enemy_removals()

## Trigger on_turn_start abilities for all units and trinkets.
func _trigger_turn_start_abilities() -> void:
	if _turn_start_abilities_triggered:
		return
		
	_turn_start_abilities_triggered = true # Set flag here to prevent multiple calls
	
	# Skip firing turn start triggers on the very first turn so they only count
	# after the player presses 'Ready!' for the first time.
	if _current_turn <= 1:
		_on_turn_animation_finished()
		return

	# Process START_OF_TURN combat effects (e.g., Bounty decay)
	var all_units = get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP) + get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	var start_of_turn_death_tracking: Dictionary = {}
	var start_of_turn_events: Array[CombatEvent] = []
	for effect_def in CombatEffectRegistry.get_turn_effects("START_OF_TURN"):
		_process_status_turn_effect(effect_def, all_units, start_of_turn_events, start_of_turn_death_tracking)
	
	# Trigger turn start abilities for all instances using unified processing
	# This queues ability requests into _pending_reactions
	var turn_start_context := TriggerContext.new()
	turn_start_context.turn = _current_turn
	AbilityResolver.process_trigger(C.TRIGGER_AT_TURN_START, turn_start_context)
	

	
	# QUEUE Slot Turn-Start Effects
	var player_lineup_container = get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	if is_instance_valid(player_lineup_container):
		for i in range(min(5, _state.player_slot_effects.size())):
			var slot_effect = _state.player_slot_effects[i]
			if slot_effect == &"":
				continue
			var unit_uuid = player_lineup_container.get_uuid(i)
			if unit_uuid.is_empty():
				continue
			var unit = get_instance(unit_uuid)
			if not is_instance_valid(unit) or unit.current_hp <= 0:
				continue
			
			var request = _create_slot_effect_request(slot_effect, unit_uuid)
			if request:
				_pending_reactions.append(request)

	var enemy_lineup_container = get_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	if is_instance_valid(enemy_lineup_container):
		for i in range(min(5, _state.enemy_slot_effects.size())):
			var slot_effect = _state.enemy_slot_effects[i]
			if slot_effect == &"":
				continue
			var unit_uuid = enemy_lineup_container.get_uuid(i)
			if unit_uuid.is_empty():
				continue
			var unit = get_instance(unit_uuid)
			if not is_instance_valid(unit) or unit.current_hp <= 0:
				continue
			
			var request = _create_slot_effect_request(slot_effect, unit_uuid)
			if request:
				_pending_reactions.append(request)
	
	# Sort reactions using unified 3-layer hierarchy
	_combat.sort_reactions_by_sub_phase()
	
	# Process turn start effects (heals, etc.) without starting combat
	# Don't populate actor queue - we're just processing turn start abilities
	if not _pending_reactions.is_empty() or not start_of_turn_events.is_empty():
		_resolve_pending_reactions_only(start_of_turn_events)
	else:
		# No turn start abilities to process - transition to MANAGEMENT directly
		_on_turn_animation_finished()


func _create_slot_effect_request(slot_effect: StringName, target_uuid: String) -> EffectRequest:
	var effect_def: EffectDefinition
	var ability_id: StringName
	
	if slot_effect == &"burn":
		var effect_apply = preload("res://scripts/EffectApplyStatus.gd").new()
		effect_apply.parameters = {
			"status_id": "burn",
			"amount": 1
		}
		effect_def = effect_apply
		ability_id = &"slot_burn"
	elif slot_effect == &"lightning":
		var effect_apply = preload("res://scripts/EffectApplyStatus.gd").new()
		effect_apply.parameters = {
			"status_id": "static",
			"amount": 1
		}
		effect_def = effect_apply
		ability_id = &"slot_lightning"
	else:
		return null
		
	var slot_ctx := TriggerContext.new()
	slot_ctx.is_simulation = true
	slot_ctx.ability_id = ability_id
	return EffectRequest.new(
		"", # Empty source_uuid so it bypasses validation checks
		ability_id,
		effect_def,
		[target_uuid],
		slot_ctx,
		C.SubPhase.STANDARD
	)

## Process pending reactions without populating the actor queue
## Used for turn start abilities that shouldn't trigger combat
## Process pending reactions without populating the actor queue
## Used for turn start abilities that shouldn't trigger combat
func _resolve_pending_reactions_only(extra_events: Array[CombatEvent] = []) -> void:
	_resolve_animator()
	if _is_animating_management_queue:
		await management_animation_queue_completed
	if is_instance_valid(_animator) and _animator.is_playing_sequence():
		await _animator.turn_animation_finished
	_is_processing_effect = true
	
	var start_snapshot: Dictionary = get_board_snapshot()
	var events: Array[CombatEvent] = _resolve_effect_phase(extra_events)
	if not events.is_empty():
		_animator.play_turn_sequence(start_snapshot, events)
	else:
		_on_turn_animation_finished()

func _resolve_effect_phase(extra_events: Array[CombatEvent]) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = extra_events.duplicate()
	var death_tracking: Dictionary = {}
	events.append_array(_combat.process_reaction_queue(self, death_tracking))
	_check_for_deaths_with_counter_delay(true, events, death_tracking)
	_process_completed_counter_deaths(events, death_tracking)
	if not _combat.get_crr().is_empty():
		events.append_array(_combat.process_reaction_queue(self, death_tracking))
	events.append_array(_combat.collect_and_clear_inline_events())
	events.append_array(take_inventory_events())
	return events

## Resolve pending reactions for management phase triggers (on_draw, on_merge, etc.)
## Uses the VCR pattern: process pending effects, then animate via BattleAnimator.
## Block UI updates (for manual effect orchestration)
func block_ui_updates() -> void:
	_is_processing_effect = true

## Unblock UI updates and flush pending refreshes
func unblock_ui_updates() -> void:
	_is_processing_effect = false
	if _pending_inventory_refresh:
		_pending_inventory_refresh = false
		_emit_battle_inventory_changed()
		SignalBus.emit_signal("inventory_ui_refresh_requested")

## Called from BattleView after gacha draw animation completes.
## @param snapshot: Dictionary - Board snapshot captured BEFORE effects were triggered


func enqueue_management_animation(snapshot: Dictionary, events: Array[CombatEvent]) -> void:
	if events.is_empty():
		return
	_resolve_animator()
	_management_animation_queue.append({
		"snapshot": snapshot,
		"events": events
	})
	if not _is_animating_management_queue:
		_process_management_animation_queue()

func resolve_management_effects_and_animate(snapshot: Dictionary) -> void:
	if _pending_reactions.is_empty():
		return
	
	_resolve_animator()
	
	var events: Array[CombatEvent] = []
	var death_tracking: Dictionary = {}
	
	# Resolve all pending reactions (e.g., Apprentice Insignia buffs)
	# UNIFIED LOGIC: Use CombatSimulator's processor to handle priority, inline events, and deaths
	events.append_array(_combat.process_reaction_queue(self , death_tracking))
	
	# Loop until all cascading reactions + death triggers are fully drained.
	# Death checks can fire on_death triggers (e.g. Empathic Link) which enqueue new reactions.
	# Those MUST be captured in the same event batch with the original snapshot.
	var safety := 20
	while safety > 0:
		_check_for_deaths_with_counter_delay(true, events, death_tracking)
		_process_completed_counter_deaths(events, death_tracking)
		if _pending_reactions.is_empty():
			break
		events.append_array(_combat.process_reaction_queue(self , death_tracking))
		safety -= 1
	
	if events.is_empty():
		return

	_pending_inventory_refresh = true
	enqueue_management_animation(snapshot, events)
	if _is_animating_management_queue:
		await management_animation_queue_completed

func _process_management_animation_queue() -> void:
	if _is_animating_management_queue:
		return
	_is_animating_management_queue = true
	_is_processing_effect = true
	
	while true:
		while not _management_animation_queue.is_empty():
			var payload = _management_animation_queue.pop_front()
			if is_instance_valid(_animator):
				await _animator.play_turn_sequence(payload["snapshot"], payload["events"])
		
		# Finalize any deaths that occurred during the management sequence (e.g. from Fusion Spark)
		# NOW that the death animations have finished playing.
		_finalize_deaths()
		
		if _pending_inventory_refresh:
			_pending_inventory_refresh = false
			_is_processing_effect = false
			_emit_battle_inventory_changed()
			SignalBus.emit_signal("inventory_ui_refresh_requested")
			if not _management_animation_queue.is_empty():
				_is_processing_effect = true
				continue
		else:
			_is_processing_effect = false
		
		break
			
	_is_animating_management_queue = false
	if _is_battle_over() and not _battle_over_emitted:
		_battle_over_deferred = false
		_emit_battle_over()

	management_animation_queue_completed.emit()


## Flush deferred enemy instance erasures. Called after all reactions have resolved.
## This ensures enemy units and items are still available in _battle_instances while
## their on_death abilities are being processed.
func _flush_deferred_enemy_removals() -> void:
	if _state.deferred_enemy_erasures.is_empty():
		return
	for uuid in _state.deferred_enemy_erasures:
		if _battle_instances.has(uuid):
			_state.bm_remove_instance(uuid)
	_state.deferred_enemy_erasures.clear()

func _process_registered_death(unit: GachaBallInstance, phase: StringName, death_team: String, all_events: Array[CombatEvent], death_tracking: Dictionary) -> void:
	KnockoutProcessor.process_registered_knockout(unit, phase, death_team, all_events, death_tracking, self)

func _track_first_killed_non_hero(unit: GachaBallInstance, death_team: String) -> void:
	# THIN WRAPPER: Delegates to KnockoutProcessor
	KnockoutProcessor.track_first_knocked_out(self, unit, death_team)

## Trigger on_turn_end abilities for all units.
func _trigger_turn_end_abilities() -> void:
	var start_snapshot: Dictionary = get_board_snapshot()
	_is_processing_effect = true
	var events: Array[CombatEvent] = _simulate_turn_end_effects()
	if not events.is_empty():
		_resolve_animator()
		await _animator.play_turn_sequence(start_snapshot, events)
	else:
		_on_turn_animation_finished()

func _simulate_turn_end_effects() -> Array[CombatEvent]:
	var all_units: Array[GachaBallInstance] = get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP) + get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	var all_events: Array[CombatEvent] = []
	var death_tracking: Dictionary = {}

	# 1. Process Combat Effects via CombatEffectRegistry
	# Generic loop replaces hardcoded burn logic
	for effect_def in CombatEffectRegistry.get_turn_effects("END_OF_TURN"):
		_process_status_turn_effect(effect_def, all_units, all_events, death_tracking)

	# 2. Process on_turn_end triggers
	# Call once globally; AbilityResolver iterates all units
	AbilityResolver.process_trigger(C.TRIGGER_AT_TURN_END, TriggerContext.new())
	
	# 3. Resolve pending reactions from on_turn_end
	# UNIFIED LOGIC: Use CombatSimulator's processor to handle priority, inline events, and deaths
	all_events.append_array(_combat.process_reaction_queue(self , death_tracking))
	
	# FINAL DEATH CHECK + FLUSH: Ensure any skipped deaths (e.g. from inline Thorns) are caught
	# and any deferred deaths (waiting for empty queue) are released immediately.
	_check_for_deaths_with_counter_delay(true, all_events, death_tracking)
	_process_completed_counter_deaths(all_events, death_tracking)
	
	all_events.append_array(take_inventory_events())

	return all_events


## Generic combat effect turn processor. Handles any combat effect at turn start/end.
func _process_status_turn_effect(status_def: Resource, all_units: Array, all_events: Array[CombatEvent], death_tracking: Dictionary) -> void:
	StatusTickProcessor.process_status_turn_effect(status_def, all_units, all_events, death_tracking, self)

func _reshuffle_discard_pile(tier_to_reshuffle: int) -> void:
	# Delegate to BattleState's authoritative reshuffle logic
	_state.reshuffle_tier_from_discard(tier_to_reshuffle)


## Handle armor_stacks stat changes for trinket abilities
## Applies armor stacks to targets and returns a STATUS_EFFECT event for visual feedback
func handle_armor_stacks(request: EffectRequest, resolved_targets: Array[String], amount: int) -> CombatEvent:
	var targets_old_val: Array[int] = []
	var targets_new_val: Array[int] = []
	
	for target_uuid in resolved_targets:
		var tgt: GachaBallInstance = get_instance_by_uuid(target_uuid)
		if is_instance_valid(tgt):
			targets_old_val.append(tgt.get_status_effect_amount(&"armor"))
			var new_v = apply_stat_delta(tgt, "armor_stacks", amount)
			targets_new_val.append(new_v)
		else:
			targets_old_val.append(0)
			targets_new_val.append(0)
	
	return CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
		"source_uuid": request.source_uuid,
		"target_uuids": resolved_targets,
		"ability_id": request.ability_id,
		"trigger_type": request.trigger_context.trigger_type,
		"ability_holder_uuid": request.source_uuid,
		"visual_payload": CombatPayload.status_change(request.source_uuid, amount, "armor_stacks", targets_old_val, targets_new_val)
	})


func _get_frontmost_target(attacker_is_player: bool) -> GachaBallInstance:
	var target_lineup_tag = C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if attacker_is_player else C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	var living_targets = get_instances_in_container(target_lineup_tag).filter(func(unit): return unit.current_hp > 0)
	if living_targets.is_empty(): return null
	
	# Sort by location index to ensure consistent targeting
	living_targets.sort_custom(func(a, b):
		var loc_a = get_location_for_uuid(a.ball_uuid)
		var loc_b = get_location_for_uuid(b.ball_uuid)
		if not loc_a or not loc_b: return false
		return loc_a.index < loc_b.index
	)
	
	# Player attacks from left to right (0 to n), enemies from right to left (n to 0)
	return living_targets[0] if attacker_is_player else living_targets[-1]

func _on_end_turn_requested() -> void:
	if _current_battle_phase == Phases.MANAGEMENT:
		_change_phase(Phases.PRE_COMBAT)
		# Trigger pre-combat abilities (Start of Combat)
		# These will run, animate, and then transition to COMBAT in _on_turn_animation_finished
		_trigger_pre_combat_abilities()
	else:
		pass

func _on_unit_inventory_changed(unit_uuid: String) -> void:
	# CRITICAL: Do not recalculate stats during COMBAT phase or when animations are actively playing.
	# Ambient unit_stat_changed emissions would bypass the animation queue and desync visual stats.
	if _current_battle_phase == Phases.COMBAT or is_animations_playing():
		return
	
	# Only recalculate stats for the specific unit that changed
	var unit_instance = get_instance(unit_uuid)
	if is_instance_valid(unit_instance):
		unit_instance.recalculate_stats(_battle_instances)

func execute_machine_draw(tier: int, action: GameAction) -> void:
	var snapshot: Dictionary = get_board_snapshot()
	var cost: int = 1 if tier == 4 else get_gacha_draw_cost(tier)
	var events: Array[CombatEvent] = bm_draw_from_discard() if tier == 4 else bm_draw_gacha_instance(tier)
	assert(not events.is_empty(), "Validated machine draw must commit before playback")
	_pending_inventory_refresh = true
	var main: Node = GameManager.get_main_node()
	if main != null and not ActionQueue.is_headless_mode():
		main.begin_token_animation()
		await main.play_machine_draw(tier, cost)
		enqueue_management_animation(snapshot, events)
		if is_animating_management_queue():
			await management_animation_queue_completed
		main.end_token_animation()
		ActionQueue.finish_action(action)
	else:
		enqueue_management_animation(snapshot, events)

func get_discard_count() -> int:
	return _state.get_container(C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE).get_all_non_empty_uuids().size()

func _emit_stats_changed_for_equipped_units() -> void:
	# Emit granular unit_stat_changed signals for all units that have equipped items
	for instance in _battle_instances.values():
		if is_instance_valid(instance) and instance.get_definition().category == &"UNIT":
			var has_equipped_items = false
			for item_uuid in instance.equipped_item_uuids:
				if not item_uuid.is_empty():
					has_equipped_items = true
					break
			if has_equipped_items:
				# Emit both HP and PWR as "changed" with current values (after equipment bonuses applied)
				# Using 0 for old_value since this is initialization
				SignalBus.emit_signal("unit_stat_changed", instance.ball_uuid, &"hp", 0, instance.current_hp)
				SignalBus.emit_signal("unit_stat_changed", instance.ball_uuid, &"pwr", 0, instance.current_pwr)

func _on_battle_entry_animation_finished() -> void:
	if _current_battle_phase == Phases.START_OF_TURN and is_instance_valid(GameManager.run_state):
		FlashcardManager.start_minigame(GameManager.run_state, GameManager.run_state.active_deck_ids)

func _on_flashcard_completed(results: Dictionary) -> void:
	# TDD Section 9.4: Battle Flow
	# This handler is only for the battle context.
	# BattleManager only exists during battle, so we don't need to check is_in_battle.
	# NOTE: Window closing is now handled by FlashcardManager
	_last_minigame_results = results.duplicate()

	var context := TriggerContext.new()
	context.trigger_type = C.TRIGGER_AT_MINIGAME_END
	context.team = "PLAYER"
	AbilityResolver.process_trigger(C.TRIGGER_AT_MINIGAME_END, context)

	# Automatically emit results acknowledged to trigger dependencies and phase transition
	# skipping the ResultsPopup to go directly to game flow
	SignalBus.results_acknowledged.emit()

func _on_results_acknowledged() -> void:
	"""Called when player acknowledges the results popup"""
	# NOTE: Tokens are now awarded LIVE during animation via add_gacha_token()
	# The FlashcardMinigame calls add_gacha_token(1) each time a token lands
	# So we no longer need to bulk-award tokens here
	
	SignalBus.emit_signal("close_modal_requested")
	
	if _current_turn <= 1 and (not _state.staged_hero_placement.is_empty() or not _state.staged_enemy_placements.is_empty()):
		_is_entrance_sequence_running = true
		if not _state.staged_hero_placement.is_empty():
			await execute_hero_entrance_sequence()
		if not _state.staged_enemy_placements.is_empty():
			await execute_enemy_entrance_sequence()
		_is_entrance_sequence_running = false
	
	# Trigger turn start abilities AFTER Challenge completion
	if not _turn_start_abilities_triggered:
		_trigger_turn_start_abilities()
		# Don't transition to MANAGEMENT yet - let abilities execute and animate first
		# _on_turn_animation_finished() will transition to MANAGEMENT after animations complete
	else:
		# No abilities to execute, go directly to MANAGEMENT
		_change_phase(Phases.MANAGEMENT)

## Executes entrance animation of staged hero unit at its PlayerLineup slot.
func execute_hero_entrance_sequence() -> void:
	await BattleEntranceSequencer.execute_hero_entrance_sequence(self)

## Executes sequential entrance of staged enemy units from Slot 4 (Backline) down to Slot 0 (Frontline).
func execute_enemy_entrance_sequence() -> void:
	await BattleEntranceSequencer.execute_enemy_entrance_sequence(self)


# ------------------------------------------------------------------
# Polymorphic Adapter API (Matches RunState interface)
# ------------------------------------------------------------------

func add_instance(instance: GachaBallInstance, container_name: StringName, index: int = -1) -> bool:
	return bm_add_instance(instance, container_name, index)

func remove_instance(uuid: String) -> bool:
	return bm_remove_instance(uuid)

func move_instance(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> bool:
	return bm_move_instance(source_loc, target_loc)

func swap_instances(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> bool:
	return bm_swap_instances(source_loc, target_loc)

func equip_item(item_uuid: String, unit_uuid: String, slot_index: int = -1, silent: bool = false) -> bool:
	return bm_equip_item(item_uuid, unit_uuid, slot_index, silent)

func register_and_equip_item(item: GachaBallInstance, unit_uuid: String, slot_index: int = -1, silent: bool = false) -> bool:
	return bm_register_and_equip_item(item, unit_uuid, slot_index, silent)
func _has_team_trinket(is_player_team: bool, trinket_id: StringName) -> bool:
	var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS if is_player_team else C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS
	var trinkets = get_instances_in_container(container_tag)
	for trinket in trinkets:
		if trinket.definition_id == trinket_id:
			return true
	return false

func _team_has_trait_trinket(team: String, trait_name: String) -> bool:
	var trait_definition: Dictionary = C.TRAIT_DEFINITIONS.get(trait_name, {})
	var trinket_id: StringName = trait_definition.get("trinket_id", &"")
	if trinket_id == &"":
		return false
	return _has_team_trinket(team == "PLAYER", trinket_id)

## Find a unit with the intercept_lethal tag on the specified team.
## Returns the unit with highest HP, or null if none available.
## This enables any unit with the tag to protect allies, not just Guardian.
func _find_guardian_on_team(is_player_team: bool, exclude_uuid: String) -> GachaBallInstance:
	return BattleHelpers.find_interceptor_on_team(_state, is_player_team, exclude_uuid)

func _finalize_deaths() -> void:
	# THIN WRAPPER: Delegates to KnockoutProcessor
	var something_changed = KnockoutProcessor.finalize_knockouts(self )
	
	_flush_deferred_enemy_removals()
	
	if something_changed:
		_emit_battle_inventory_changed()

# =============================================================================
# TRAIT SYSTEM
# =============================================================================

## Calculate active trait counts for a specific team.
## @param team: "PLAYER" or "ENEMY"
## @return Dictionary: { "FIRE": count, "EARTH": count }
func get_active_traits(team: String) -> Dictionary:
	# During COMBAT, use the locked snapshot to prevent traits from fluctuating due to deaths
	if _current_battle_phase == Phases.COMBAT and _locked_ready_traits.has(team):
		return _locked_ready_traits[team]
	
	# Otherwise (Management, Start of Turn), calculate live based on current board state
	return _calculate_active_traits(team)

## Internal calculation of active traits based on current board state.
func _calculate_active_traits(team: String) -> Dictionary:
	return TraitRulesEngine.calculate_active_traits(team, self)

## Lock current active traits into snapshot.
func _lock_traits() -> void:
	_locked_ready_traits["PLAYER"] = _calculate_active_traits("PLAYER")
	_locked_ready_traits["ENEMY"] = _calculate_active_traits("ENEMY")
	_emit_battle_inventory_changed()

## Check if a unit contributes to a specific Soul trait.
func _has_trait_soul(unit: GachaBallInstance, trait_name: String) -> bool:
	return TraitRulesEngine.has_trait_soul(unit, trait_name, get_all_instances())

func has_trait(unit: GachaBallInstance, trait_name: String) -> bool:
	return TraitRulesEngine.has_trait(unit, trait_name, get_all_instances())

func get_frontmost_unit_on_team(is_player: bool, trait_name: String = "") -> GachaBallInstance:
	var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var units = get_instances_in_container(container_tag).filter(func(u):
		if not is_instance_valid(u) or u.current_hp <= 0:
			return false
		if not trait_name.is_empty():
			return has_trait(u, trait_name)
		return true
	)
	if units.is_empty():
		return null
	units.sort_custom(func(a, b): return a.location_slot_index < b.location_slot_index)
	return units[-1] if is_player else units[0]

func get_hero_on_team(is_player: bool) -> GachaBallInstance:
	var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var units = get_instances_in_container(container_tag)
	for u in units:
		if is_instance_valid(u) and u.current_hp > 0:
			var def = u.get_definition()
			if is_instance_valid(def) and def.is_hero:
				return u
	return get_frontmost_unit_on_team(is_player, "")

# =============================================================================
# TEST MODE HELPERS
# Thin wrappers delegating to TestModeHelpers for cleaner separation.
# =============================================================================

func register_test_unit(unit_def_id: StringName, is_enemy: bool, position: int = -1) -> GachaBallInstance:
	return TestModeHelpers.register_test_unit(self , unit_def_id, is_enemy, position)

func register_test_item(item_def_id: StringName, is_enemy: bool) -> GachaBallInstance:
	return TestModeHelpers.register_test_item(self , item_def_id, is_enemy)

func register_test_item_on_unit(item_def_id: StringName, unit_uuid: String) -> GachaBallInstance:
	return TestModeHelpers.register_test_item_on_unit(self , item_def_id, unit_uuid)

func register_test_trinket(trinket_def_id: StringName, is_enemy: bool) -> GachaBallInstance:
	return TestModeHelpers.register_test_trinket(self , trinket_def_id, is_enemy)

func trigger_test_battle_start() -> void:
	TestModeHelpers.trigger_test_battle_start(self )

func clear_test_team(is_enemy: bool) -> void:
	TestModeHelpers.clear_test_team(self , is_enemy)
