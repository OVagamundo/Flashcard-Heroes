class_name BattleManager
extends Node

const C = preload("res://scripts/Constants.gd")
const RS = preload("res://scripts/RunState.gd")
const BattleStateClass = preload("res://scripts/battle/BattleState.gd")
const CombatSimulatorClass = preload("res://scripts/battle/CombatSimulator.gd")
const _TestModeHelpers = preload("res://scripts/battle/TestModeHelpers.gd")
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
	get: return _combat._is_processing_effect
	set(value): _combat._is_processing_effect = value

var _battle_over_deferred: bool = false
var _battle_over_emitted: bool = false
var is_test_mode: bool = false
var _is_applying_static_damage: bool = false

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
# Note: _dead_this_turn access is via DeathProcessor.is_dead_this_turn()
var _gacha_tokens: int:
	get: return _state._gacha_tokens
	set(value): _state._gacha_tokens = value

const _FixedArrayContainer = preload("res://scripts/FixedArrayContainer.gd")
const _GrowableGridContainer = preload("res://scripts/GrowableGridContainer.gd")
const _EncounterDefinition = preload("res://scripts/EncounterDefinition.gd")
var _last_minigame_results: Dictionary = {}
var _current_turn: int = 0
var _turn_start_abilities_triggered: bool = false
var _bargain_charm_uses: Dictionary = {}
var _pending_inventory_refresh: bool = false
const DEATH_SLOT_START_TURN: int = 10
const LINEUP_SLOT_COUNT: int = 5
const DEATH_SLOT_EFFECT: StringName = &"death"


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
	
	# Sync test mode flag
	is_test_mode = GameManager.is_test_mode
	
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

func is_processing_effect() -> bool:
	return _is_processing_effect

func set_processing_effect(active: bool) -> void:
	_is_processing_effect = active

func _exit_tree() -> void:
	GameManager.unregister_battle_manager() # ADD THIS LINE
	GameManager.is_in_battle = false
	SignalBus.emit_signal("battle_state_changed", false)
	if SignalBus.is_connected("end_turn_requested", _on_end_turn_requested):
		SignalBus.end_turn_requested.disconnect(_on_end_turn_requested)
	if SignalBus.is_connected("draw_gacha_requested", _on_draw_gacha_requested):
		SignalBus.draw_gacha_requested.disconnect(_on_draw_gacha_requested)
	if SignalBus.is_connected("unit_inventory_changed", _on_unit_inventory_changed):
		SignalBus.unit_inventory_changed.disconnect(_on_unit_inventory_changed)
	if FlashcardManager.minigame_finished.is_connected(_on_flashcard_completed):
		FlashcardManager.minigame_finished.disconnect(_on_flashcard_completed)
	if SignalBus.is_connected("results_acknowledged", _on_results_acknowledged):
		SignalBus.results_acknowledged.disconnect(_on_results_acknowledged)
	if is_instance_valid(_animator) and _animator.turn_animation_finished.is_connected(_on_turn_animation_finished):
		_animator.turn_animation_finished.disconnect(_on_turn_animation_finished)

func _connect_signals() -> void:
	SignalBus.end_turn_requested.connect(_on_end_turn_requested)
	SignalBus.draw_gacha_requested.connect(_on_draw_gacha_requested)
	SignalBus.unit_inventory_changed.connect(_on_unit_inventory_changed)
	if SignalBus.has_signal("inventory_instance_removed_penalty"):
		if not SignalBus.inventory_instance_removed_penalty.is_connected(_on_battle_inventory_penalty):
			SignalBus.inventory_instance_removed_penalty.connect(_on_battle_inventory_penalty)
	# Apply deaths after animator finishes death fades
	if SignalBus.has_signal("apply_deaths_requested") and not SignalBus.is_connected("apply_deaths_requested", _on_apply_deaths_requested):
		SignalBus.apply_deaths_requested.connect(_on_apply_deaths_requested)
	# Removed legacy reshuffle trigger; draw now reshuffles atomically when needed.

func _emit_battle_inventory_changed() -> void:
	# Trigger real-time passive updates whenever the inventory changes
	AbilityResolver.process_trigger(&"on_board_changed", {})
	
	if _current_battle_phase == Phases.MANAGEMENT and not _is_processing_effect:
		# Instantly resolve these updates silently so that stats are computed in real time.
		# This ensures active units and equipped items update their stats instantly.
		_combat.process_reaction_queue(self, {})
		
		# Ensure any enemy deaths that occurred during these updates are properly cleaned up
		_flush_deferred_enemy_erasures()
		
		SignalBus.emit_signal("battle_inventory_changed")
		_pending_inventory_refresh = false
	else:
		_pending_inventory_refresh = true


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
	var instance = get_instance(uuid)
	if not is_instance_valid(instance): return
	
	# Directly update the instance's properties, making it the source of truth.
	instance.location_container_tag = container_name
	instance.location_slot_index = index
	# Only clear equip linkage when moving to a physical container or clearing location.
	# Equipped items do not live in physical slots.
	if container_name != C.CONTAINER_EQUIPPED_ITEM:
		instance.equipped_on_uuid = ""
		instance.equipped_slot_index = -1

func get_instance_by_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc): return null
	
	# This function now ONLY handles direct container lookups.
	# The logic for resolving an equipped item's location is now handled by
	# the caller by checking the LocationIdentifier first. This change is
	# mandated by the new architecture to avoid ambiguity.
	var container = get_container(loc.container)
	if not is_instance_valid(container): return null
	
	var uuid = container.get_uuid(loc.index)
	return get_instance(uuid) if not uuid.is_empty() else null

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

	var result := _state.bm_remove_instance(uuid)
	if result.success:
		if not result.unit_changed_uuid.is_empty():
			SignalBus.emit_signal("unit_inventory_changed", result.unit_changed_uuid)
		if OS.is_debug_build():
			_bm_validate_state_consistency()
		_emit_battle_inventory_changed()
		SignalBus.emit_signal("inventory_ui_refresh_requested")
	return result.success

func _cleanup_removed_trinket_passives(instance: GachaBallInstance) -> void:
	if not is_instance_valid(instance):
		return

	var definition = instance.get_definition()
	if not is_instance_valid(definition):
		return
	if definition.category != &"TRINKET":
		return
	if definition.id != &"trinket_twin_charm":
		return

	var status_key := StringName("twin_charm_scaling_" + instance.ball_uuid)
	for uuid in _battle_instances:
		var target: GachaBallInstance = _battle_instances[uuid]
		if not is_instance_valid(target):
			continue
		var target_def = target.get_definition()
		if not is_instance_valid(target_def) or target_def.category != &"UNIT":
			continue

		var last_bonus := target.get_status_effect_amount(status_key)
		if last_bonus <= 0:
			continue

		target.clear_status_effect(status_key)
		target.apply_pwr_delta(-last_bonus)


func bm_move_instance(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> bool:
	assert(is_instance_valid(source_loc), "bm_move_instance: source_loc is null")
	assert(is_instance_valid(target_loc), "bm_move_instance: target_loc is null")
	
	var result := InventoryOperations.move_instance(_state, source_loc, target_loc)
	
	# Handle needs_equip delegation
	if result.needs_equip:
		# Emit unit changes from the pre-equip phase
		for uuid in result.changed_unit_uuids:
			SignalBus.emit_signal("unit_inventory_changed", uuid)
		# Delegate to bm_equip_item which handles its own signals
		return bm_equip_item(result.equip_item_uuid, result.equip_unit_uuid, result.equip_slot_index)
	
	if result.success:
		if OS.is_debug_build():
			_bm_validate_state_consistency()
		for uuid in result.changed_unit_uuids:
			SignalBus.emit_signal("unit_inventory_changed", uuid)
		if result.inventory_changed:
			_emit_battle_inventory_changed()
			SignalBus.emit_signal("inventory_ui_refresh_requested")
	
	return result.success

func bm_swap_instances(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> bool:
	assert(is_instance_valid(source_loc), "bm_swap_instances: source_loc is null")
	assert(is_instance_valid(target_loc), "bm_swap_instances: target_loc is null")
	
	var result := InventoryOperations.swap_instances(_state, source_loc, target_loc)
	
	if result.success:
		if OS.is_debug_build():
			_bm_validate_state_consistency()
		for uuid in result.changed_unit_uuids:
			SignalBus.emit_signal("unit_inventory_changed", uuid)
		if result.inventory_changed:
			_emit_battle_inventory_changed()
			SignalBus.emit_signal("inventory_ui_refresh_requested")
	
	return result.success

func bm_equip_item(item_uuid: String, unit_uuid: String, slot_index: int = -1, silent: bool = false) -> bool:
	assert(not item_uuid.is_empty(), "bm_equip_item: item_uuid is empty")
	assert(not unit_uuid.is_empty(), "bm_equip_item: unit_uuid is empty")
	
	var result := InventoryOperations.equip_item(_state, item_uuid, unit_uuid, slot_index)
	
	if result.success:
		if OS.is_debug_build():
			_bm_validate_state_consistency()
		if not silent:
			for uuid in result.changed_unit_uuids:
				SignalBus.emit_signal("unit_inventory_changed", uuid)
			if result.inventory_changed:
				_emit_battle_inventory_changed()
				SignalBus.emit_signal("inventory_ui_refresh_requested")
		else:
			# Even when silent (e.g. during combat simulation), we must trigger the passive scaling
			# updates to guarantee holder stats are dynamically updated instantly.
			AbilityResolver.process_trigger(&"on_board_changed", {"is_simulation": true})
			_pending_inventory_refresh = true
	
	return result.success

# ------------------------------------------------------------------
# Composite atomic mutation API (Battle)
# ------------------------------------------------------------------

func bm_move_instance_to_discard(uuid: String) -> bool:
	assert(not uuid.is_empty(), "bm_move_instance_to_discard: uuid is empty")
	var instance := get_instance(uuid)
	assert(is_instance_valid(instance), "bm_move_instance_to_discard: instance not found")
	
	# Ownership gate
	assert(_is_player_owned(instance), "bm_move_instance_to_discard: instance is not player owned")
	
	var result := InventoryOperations.move_instance_to_discard(_state, instance)
	
	if result.success:
		for changed_uuid in result.changed_unit_uuids:
			SignalBus.emit_signal("unit_inventory_changed", changed_uuid)
		if OS.is_debug_build():
			_bm_validate_state_consistency()
		_emit_battle_inventory_changed()
		SignalBus.emit_signal("inventory_ui_refresh_requested")
	
	return result.success

func bm_reshuffle_discard_pile(_tier_to_reshuffle: int) -> bool:
	# Automatic reshuffle feature has been removed.
	return false

func bm_draw_gacha_instance(tier: int) -> bool:
	var base_cost := tier
	var cost := base_cost
	
	# Apply Bargain Charm cost reduction
	var has_bargain = _has_team_trinket(true, &"trinket_bargain_charm")
	var bargain_used = _bargain_charm_uses.get(tier, false)
	if has_bargain and not bargain_used:
		cost = maxi(1, cost - 1)
		
	if _gacha_tokens < cost:
		return false
	
	var container_tag: StringName = "BattleInventoryT%d" % tier
	var tier_pool := get_instances_in_container(container_tag)
	
	# If pool is empty, try reshuffling first
	# If pool is empty, the draw fails (No automatic reshuffle)
	if tier_pool.is_empty():
		return false
	
	# Attempt to draw
	var draw_result := InventoryOperations.draw_from_tier(_state, tier, 5)
	
	if not draw_result.success:
		return false
	
	# Spend tokens
	_gacha_tokens -= cost
	if has_bargain and not bargain_used:
		_bargain_charm_uses[tier] = true
		if cost < base_cost:
			var event := CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
				"text": "",
				"visual_payload": {
					"trinket_activations": [{"definition_id": &"trinket_bargain_charm", "is_enemy": false}]
				}
			})
			_animate_bargain_charm_async(event)
	SignalBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
	
	# Validate and emit
	if OS.is_debug_build():
		_bm_validate_state_consistency()
	
	# Emit animation signal FIRST so BattleView can suppress the redraw
	SignalBus.emit_signal("gacha_draw_animated", draw_result)
	
	# Then emit inventory changed (BattleView will skip redraw due to suppression flag)
	_emit_battle_inventory_changed()
	
	# If pool emptied, trigger reshuffle for next draw
	# If pool emptied, next draw will fail until/if a retrieval mechanic is added.
	if draw_result.pool_emptied:
		pass
	
	return true

# ------------------------------------------------------------------
# Golden Rule Validation (Battle)
# ------------------------------------------------------------------

func _bm_validate_state_consistency() -> bool:
	var deferred_erasures: Array = get_meta("_deferred_enemy_erasures", [])
	return _state.validate_state_consistency(deferred_erasures)

func get_gacha_tokens() -> int:
	return _gacha_tokens

func add_gacha_token(amount: int = 1) -> void:
	"""Add gacha tokens and emit signal for UI update. Used for live token updates."""
	_gacha_tokens += amount
	SignalBus.emit_signal("gacha_tokens_changed", _gacha_tokens)

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
	match _current_battle_phase:
		Phases.START_OF_TURN:
			# Increment turn counter and reset turn start flag
			_current_turn += 1
			_turn_start_abilities_triggered = false
			_bargain_charm_uses.clear()
			
			# Timekeeper hero bonus: +5 tokens for easy testing
			if _is_timekeeper_hero():
				_gacha_tokens += 5
			
			SignalBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
			
			# The flashcard mini-game is the first event of the turn.
			# TDD Section 9.4: Battle Flow
			# Turn start abilities will be triggered AFTER the mini-game in _on_results_acknowledged()
			if is_test_mode:
				# In test mode, skip minigame
				# Grant massive tokens for testing
				_gacha_tokens += 999
				SignalBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
				# Transition to results acknowledged (which triggers turn start abilities)
				call_deferred("_on_results_acknowledged")
			elif is_instance_valid(GameManager.run_state):
				# Delay flashcard start to allow entry animation to complete
				await get_tree().create_timer(1.0).timeout
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
## Preserves asymmetric attack order: players left-to-right, then enemies right-to-left.
## NOTE: Old system used LIFO (pop_back), new system uses FIFO (pop_front) for priority queue.
## To preserve visual order with FIFO:
##   - Players go left-to-right (index 0→5) → add in order
##   - Enemies go right-to-left (index 5→0) → add reversed
func _populate_actor_queue() -> void:
	_combat.populate_actor_queue(_state)

## Grant a unit an extra action by inserting them at the front of the actor queue.
## Called by EffectGrantExtraAction when a unit equipped with Bloodlust Edge gets a kill.
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
	for update in result.container_updates:
		var container_tag: StringName = update.container_tag
		var slot: int = update.slot
		var uuid: String = update.uuid
		
		# Update physical container
		var container = get_container(container_tag)
		if is_instance_valid(container):
			container.set_uuid(slot, uuid)
		
		# Update instance location
		_update_instance_location(uuid, container_tag, slot)
	
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
			
	# Trigger on_board_changed to dynamically update passive effects (like Doppleganger/Echoing Orb)
	AbilityResolver.process_trigger(&"on_board_changed", {})

## Enqueue an attack (on_attack trigger + basic attack fallback) for a single actor.
func _enqueue_attack_for(attacker: GachaBallInstance) -> void:
	var is_player = _is_player_unit(attacker)
	# Build context for on_attack trigger (semantic keys per unified broadcast pattern)
	var context: Dictionary = {
		"attacker_uuid": attacker.ball_uuid,
		"trigger_cause": C.CAUSE_TURN,
		"cause_id": C.CAUSE_TURN, # Redundant but explicit for cause_id field
		"trigger_type": &"on_attack"
	}
	
	var target_uuids = TargetResolver.resolve_target(attacker.ball_uuid, C.TARGET_FRONTMOST_ENEMY, context, self)
	if target_uuids.is_empty(): return
	var target = get_instance_by_uuid(target_uuids[0])
	if not is_instance_valid(target): return
	
	context["target_uuid"] = target.ball_uuid
	context["target_initial_hp"] = target.current_hp
	
	# Trigger on_attack abilities (e.g., Double Strike, Power Amulet)
	# Trigger on_attack abilities (e.g., Double Strike, Power Amulet)
	# Generic trigger (Power Amulet & Extra Attack both listen to this now, filtered by condition)
	AbilityResolver.process_trigger(&"on_attack", context)
	
	# Check if an ability replaced the basic attack
	if context.get("attack_replaced", false):
		return
	
	# Mark that on_attack was already triggered - BasicAttackEffect should not re-trigger it
	context["on_attack_already_triggered"] = true
	
	# Always add basic attack
	var basic_attack_def = Database.get_ability_definition(&"basic_attack")
	if is_instance_valid(basic_attack_def) and not basic_attack_def.effects.is_empty():
		var basic_attack_request = EffectRequest.new(
			attacker.ball_uuid, &"basic_attack", basic_attack_def.effects[0],
			[target.ball_uuid], context, 0 # Priority 0 for basic attack
		)
		enqueue_effect_request(basic_attack_request)


func _resolve_single_effect_request(request: EffectRequest, out_events: Array[CombatEvent], death_tracking: Dictionary = {}) -> void:
	# SYSTEM TRAP: Handle delayed trait effects
	if request.ability_id == "trait_start_effects":
		out_events.append_array(_apply_trait_start_of_turn_effects())
		return

	# THIN WRAPPER: Delegates to CombatSimulator
	_combat.resolve_effect_request(request, out_events, death_tracking, self )

## New priority-driven combat phase resolution.
## Uses actor queue with nested reaction loops for cascading effects.
func get_board_snapshot() -> Dictionary:
	return BattleHelpers.get_combat_board_snapshot(_battle_instances)

func _resolve_combat_phase() -> void:
	if _is_processing_effect: return
	_resolve_animator()
	_populate_actor_queue()
	
	# CRITICAL: Enforce global "Puppet Mode" block before capturing snapshot and running simulation.
	# This ensures all mid-combat state mutations (e.g. equips, buffs, damage) do not leak/redraw prematurely.
	_is_processing_effect = true
	
	# 1. Capture State BEFORE Simulation
	_lock_traits() # Snapshot traits for consistent combat behavior (ignoring mid-battle deaths)
	_turn_metadata.clear() # Reset per-turn metadata (e.g. first killed unit, resurrection flags)
	var start_snapshot = get_board_snapshot()
	var death_tracking: Dictionary = {}
	
	# 2. Execute combat turn via CombatSimulator
	var turn_log: Array[CombatEvent] = _combat.execute_combat_turn(self , death_tracking)
	
	# 3. Clean up deferred enemy instances AFTER all reactions have resolved
	_flush_deferred_enemy_erasures()
	
	# 4. Send Log to Animator (The VCR Playback)
	if not turn_log.is_empty():
		_animator.play_turn_sequence(start_snapshot, turn_log)
	else:
		_is_processing_effect = false
		_on_turn_animation_finished()

func _trigger_pre_combat_abilities() -> void:
	# Trigger "on_pre_combat" abilities (e.g. Tier 2 Unit H)
	# This happens after End Turn is pressed but before the Combat snapshot is taken.
	var context: Dictionary = {"turn": _current_turn}
	AbilityResolver.process_trigger(C.TRIGGER_ON_PRE_COMBAT, context)
	
	# Events will be sent to the animator, which triggers _on_turn_animation_finished when done
	call_deferred("_resolve_pending_reactions_only")

func _on_turn_animation_finished() -> void:
	# This signal is the single source of truth for when animations are complete.
	# It is safe to proceed to the next phase.
	_is_processing_effect = false
	
	# Finalize any remaining deaths (removes zombies)
	_finalize_deaths()
	
	if _pending_inventory_refresh:
		_emit_battle_inventory_changed()
	
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


func _check_for_deaths(is_simulation: bool = false, out_events = null) -> void:
	# THIN WRAPPER: Delegates to DeathProcessor
	DeathProcessor.check_for_deaths(is_simulation, out_events, self )
		
## Centralized logic for cleaning up a dead unit.
## Moves player units to discard, removes enemy units entirely.

## Snapshot equipped items for context enrichment (effects should use context, not query instances)
func _snapshot_equipped_items(unit: GachaBallInstance) -> Array[Dictionary]:
	# THIN WRAPPER: Delegates to DeathProcessor
	return DeathProcessor.snapshot_equipped_items(unit, _battle_instances)

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
	return DeathProcessor.register_death(_state, unit, phase)

func is_dead_this_turn(unit_uuid: String) -> bool:
	return DeathProcessor.is_dead_this_turn(_state, unit_uuid)

func get_death_info(unit_uuid: String) -> Dictionary:
	return DeathProcessor.get_death_info(_state, unit_uuid)

func _perform_unit_death_cleanup(unit: GachaBallInstance) -> void:
	# Get or create deferred erasures array (stored on BattleManager for meta access)
	if not has_meta("_deferred_enemy_erasures"):
		set_meta("_deferred_enemy_erasures", [])
	var deferred_erasures: Array = get_meta("_deferred_enemy_erasures")
	
	# Delegate to DeathProcessor
	DeathProcessor.perform_unit_death_cleanup(_state, unit, deferred_erasures)
	
	# Store back (array is shared reference but explicit for clarity)
	set_meta("_deferred_enemy_erasures", deferred_erasures)
	
	# Trigger on_board_changed to dynamically update passive effects mid-combat
	AbilityResolver.process_trigger(&"on_board_changed", {})

## Check if a unit has any abilities that can execute after receiving lethal damage.
## This is determined by the `execute_on_lethal` flag on AbilityDefinition.
func _has_lethal_counter_abilities(unit: GachaBallInstance) -> bool:
	return DeathProcessor.has_lethal_counter_abilities(unit, _battle_instances)


## Enhanced death checking that defers death events for units with counter-attacks
func _check_for_deaths_with_counter_delay(is_simulation: bool = false, out_events = null, death_tracking = null) -> void:
	# THIN WRAPPER: Delegates to DeathProcessor
	DeathProcessor.check_for_deaths_with_counter_delay(is_simulation, out_events, death_tracking, self )


## Helper function to create DEATH events only once per unit
func _create_death_event_if_needed(unit_uuid: String, out_events: Array, death_tracking: Dictionary) -> void:
	if death_tracking.has(unit_uuid):
		return # Already created death event for this unit
	
	death_tracking[unit_uuid] = true
	out_events.append(CombatEvent.new(CombatEvent.Type.DEATH, {
		"target_uuids": [unit_uuid],
		"visual_payload": {}
	}))

## Check if any deferred counter-attack units have completed their abilities and should now die
func _process_completed_counter_deaths(out_events = null, death_tracking = null) -> void:
	# THIN WRAPPER: Delegates to DeathProcessor
	DeathProcessor.process_completed_counter_deaths(out_events, death_tracking, self )

## Helper function to process deferred on_ally_death triggers after counter-attacks resolve
func _process_deferred_ally_death(dying_uuid: String, team: String) -> void:
	# THIN WRAPPER: Delegates to DeathProcessor
	DeathProcessor.process_deferred_ally_death(dying_uuid, team, self )

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
	
	# Check if any enemy units are alive
	var enemy_has_alive = false
	for unit in enemy_lineup:
		if unit.current_hp > 0:
			enemy_has_alive = true
			break
	
	# Determine outcome
	if not player_has_alive:
		return {"is_over": true, "player_won": false, "reason": &"team_wipe"}
	elif not enemy_has_alive:
		return {"is_over": true, "player_won": true, "reason": &"enemy_wipe"}
	else:
		return {"is_over": false, "player_won": false, "reason": &""}

func _emit_battle_over() -> void:
	# Transition to BATTLE_OVER and emit results once animations are finished.
	_current_battle_phase = Phases.BATTLE_OVER
	if not _battle_over_emitted:
		_battle_over_emitted = true
		SignalBus.emit_signal("battle_phase_changed", get_current_phase_name())
		
		var result := _determine_battle_result()
		var results: Dictionary = {"victory": result.player_won, "reason": result.reason}
		SignalBus.emit_signal("battle_ended", results)
		if result.player_won:
			_on_battle_victory()

func _restore_hero_location_to_run_state() -> void:
	"""Restore hero's location to original run state location after battle ends."""
	if not is_instance_valid(GameManager.run_state):
		return
	
	var hero_instance = GameManager.run_state.hero_instance
	if is_instance_valid(hero_instance):
		# Restore hero to its original run state location (PlayerLineup:0)
		hero_instance.location_container_tag = GameManager.run_state.RUN_CONTAINER_TAGS.PLAYER_LINEUP
		hero_instance.location_slot_index = 0

func _on_gacha_tokens_changed(_new_amount: int) -> void:
	# Trigger "on_gacha_tokens_changed" abilities
	# This allows units like Templar to update their stats immediately when tokens change.
	# We don't need to pass the amount in context because the effect will query the current amount.
	if _current_battle_phase == Phases.COMBAT: # Only relevant in combat? Or always?
		# Let's allow it in all phases for now, as stats should reflect reality.
		pass
		
	# Optimization: Only broadcast if we have units that care? 
	# For now, just broadcast. AbilityResolver filters efficiently.
	AbilityResolver.process_trigger(&"on_gacha_tokens_changed", {})

func _on_battle_victory() -> void:
	# Only restore the hero's location in the run state.
	# The hero's stats (HP, power, etc.) remain as they were before the battle.
	# All other battle state (including unit HP changes) is discarded.
	_restore_hero_location_to_run_state()
	# Note: All battle instances (including the hero's battle copy) will be garbage collected
	# when the battle scene is freed, leaving the original hero instance unchanged.

## Resolve targets for an effect based on target type and context.
## @param source_uuid: String - The UUID of the source instance
## @param target_type: StringName - The type of target to resolve (e.g., "SELF", "FRONTMOST_ENEMY")
## @param context: Dictionary - The context of the event
## @return Array[String] - Array of target UUIDs

func resolve_target(source_uuid: String, target_type: StringName, context: Dictionary) -> Array[String]:
	return TargetResolver.resolve_target(source_uuid, target_type, context, self )

## Check if a condition is met for an ability.
## @param condition_def: ConditionDefinition - The condition to check
## @param source_uuid: String - The UUID of the source instance
## @param context: Dictionary - The context of the event
## @return bool - True if condition is met
func check_condition(condition_def: ConditionDefinition, source_uuid: String, context: Dictionary) -> bool:
	return TargetResolver.check_condition(condition_def, source_uuid, context, self )


## Enqueue an effect request for processing.
## @param effect_request: EffectRequest - The effect request to enqueue
func enqueue_effect_request(request: EffectRequest) -> void:
	## New priority-driven system: requests are added to _pending_reactions
	## and sorted by priority before execution. Higher priority = executes first.
	_pending_reactions.push_back(request)

## Get the current size of the pending reactions queue.
## Used by BasicAttackEffect to capture the queue state before triggering on_before_attack.
func get_pending_reactions_size() -> int:
	return _pending_reactions.size()

func drain_pending_reactions_inline(start_index: int) -> void:
	# THIN WRAPPER: Delegates to CombatSimulator
	_combat.drain_reactions_inline(start_index, self )

func collect_inline_events() -> Array[CombatEvent]:
	# THIN WRAPPER: Delegates to CombatSimulator
	return _combat.collect_and_clear_inline_events()

func drain_lethal_reactions_only(start_index: int) -> void:
	# THIN WRAPPER: Delegates to CombatSimulator
	_combat.drain_lethal_reactions(start_index, self )


## Get an instance by UUID.
## @param uuid: String - The UUID of the instance
## @return GachaBallInstance - The instance, or null if not found
func get_instance_by_uuid(uuid: String) -> GachaBallInstance:
	return _battle_instances.get(uuid, null)

## Get the Hero's UUID (player's unit at slot 0, or first available player unit).
func get_hero_uuid() -> String:
	var player_lineup = get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	if is_instance_valid(player_lineup):
		var hero_uuid = player_lineup.get_uuid(0)
		if not hero_uuid.is_empty():
			return hero_uuid
		
		# Fallback: find first non-empty slot in player lineup
		for i in range(player_lineup.get_size()):
			var uuid = player_lineup.get_uuid(i)
			if not uuid.is_empty():
				return uuid
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

func _get_ally_behind(source_instance: GachaBallInstance) -> GachaBallInstance:
	return BattleHelpers.get_ally_behind(_state, source_instance)

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
func apply_stat_delta(instance: GachaBallInstance, stat_type: String, delta: int, bypass_armor: bool = false, attacker_uuid: String = "") -> Variant:
	assert(is_instance_valid(instance), "apply_stat_delta: instance is null")
	
	# CRITICAL: Reject damage to already-dead units
	# This is the "Validate Before Apply" pattern - ensures ghost attacks are impossible
	# Heals and buffs still apply normally (they won't resurrect without explicit resurrection logic)
	if stat_type == "hp" and delta < 0 and instance.current_hp <= 0:
		return null # Signal to caller: operation skipped - target already dead
	
	# CRITICAL: Use SILENT methods during simulation to prevent UI coupling
	# The BattleAnimator handles all visual updates during COMBAT phase
	match stat_type:
		"hp":
			var actual_delta = delta
			var armor_consumed = 0
			var old_armor = 0
			var new_armor = 0
			
			# CENTRALIZED ARMOR MITIGATION: All HP damage goes through armor first
			# Unless bypass_armor is true (for future armor-piercing abilities)
			if delta < 0 and not bypass_armor:
				old_armor = instance.get_status_effect_amount(&"armor")
				if old_armor > 0:
					var incoming_damage = abs(delta)
					armor_consumed = mini(old_armor, incoming_damage)
					var hp_damage = incoming_damage - armor_consumed
					actual_delta = - hp_damage if hp_damage > 0 else 0
					# Consume armor stacks
					instance.add_status_effect_silent(&"armor", -armor_consumed)
					new_armor = instance.get_status_effect_amount(&"armor")
			
			# Apply remaining damage (or full heal) to HP
			var new_hp = instance.current_hp + actual_delta
			instance.set_current_hp_silent(new_hp)
			
			# SPIKES REFLECTION: Handle Spikes status effect for HP damage
			# Spikes deals current stacks as damage to attacker, then decays by 1
			var spikes_data: Dictionary = {}
			if delta < 0 and not attacker_uuid.is_empty():
				var old_spikes = instance.get_status_effect_amount(&"spikes")
				if old_spikes > 0:
					var attacker = get_instance_by_uuid(attacker_uuid)
					if is_instance_valid(attacker) and attacker.current_hp > 0:
						# Deal spikes damage to attacker (bypasses armor, direct HP damage)
						var spikes_damage = old_spikes
						var attacker_old_hp = attacker.current_hp
						var attacker_new_hp = max(0, attacker_old_hp - spikes_damage)
						attacker.set_current_hp_silent(attacker_new_hp)
						
						# Decay spikes by 1 stack
						instance.add_status_effect_silent(&"spikes", -1)
						var new_spikes = instance.get_status_effect_amount(&"spikes")
						
						# Collect spikes data for presentation layer (does NOT emit events here!)
						spikes_data = {
							"spikes_triggered": true,
							"spikes_damage": spikes_damage,
							"attacker_uuid": attacker_uuid,
							"attacker_old_hp": attacker_old_hp,
							"attacker_new_hp": attacker_new_hp,
							"defender_uuid": instance.ball_uuid,
							"old_spikes": old_spikes,
							"new_spikes": new_spikes
						}
			
			# For damage, return full mitigation data for animations
			# For heals, just return new_hp for backwards compatibility
			if delta < 0:
				var result = {
					"new_hp": new_hp,
					"armor_consumed": armor_consumed,
					"old_armor": old_armor,
					"new_armor": new_armor,
					"hp_damage": abs(actual_delta)
				}
				if not spikes_data.is_empty():
					result["spikes_data"] = spikes_data
				if actual_delta != 0 and not _is_applying_static_damage:
					_trigger_static_consumption(instance)
				return result
			else:
				if delta > 0:
					# Trigger on_stat_increased for healing
					AbilityResolver.process_trigger(&"on_stat_increased", {
						"unit_uuid": instance.ball_uuid,
						"triggering_uuid": instance.ball_uuid, # Required for TARGET_TRIGGERING_ENTITY
						"stat": "hp",
						"amount": delta,
						"source_uuid": attacker_uuid
					})
					
					# Trigger on_healed event
					TurnAbilities.trigger_on_healed(instance.ball_uuid, delta, attacker_uuid)
					if not _is_applying_static_damage:
						_trigger_static_consumption(instance)
				return new_hp
		"pwr":
			var new_pwr = instance.apply_pwr_delta(delta, {"silent": true})
			
			if delta != 0:
				if delta > 0:
					# Trigger on_stat_increased for PWR buff
					AbilityResolver.process_trigger(&"on_stat_increased", {
						"unit_uuid": instance.ball_uuid,
						"triggering_uuid": instance.ball_uuid, # Required for TARGET_TRIGGERING_ENTITY
						"stat": "pwr",
						"amount": delta,
						"source_uuid": attacker_uuid
					})
				if not _is_applying_static_damage:
					_trigger_static_consumption(instance)
			
			return new_pwr
		"burn_stacks":
			# Status effects use add_status_effect_silent internally
			instance.add_status_effect_silent(&"burn", delta) # Silent during simulation
			return instance.status_effects.get(&"burn", 0)
		_:
			# Generic status effect pattern: "effect_name_stacks"
			if stat_type.ends_with("_stacks"):
				var effect_name = stat_type.trim_suffix("_stacks")
				instance.add_status_effect_silent(StringName(effect_name), delta) # Silent
				return instance.status_effects.get(StringName(effect_name), 0)
			else:
				push_error("Unknown stat type: %s" % stat_type)
				return 0

func _trigger_static_consumption(instance: GachaBallInstance) -> void:
	var static_stacks = instance.get_status_effect_amount(&"static")
	if static_stacks > 0:
		instance.add_status_effect_silent(&"static", -1)
		var new_static = static_stacks - 1
		
		var static_event = CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
			"source_uuid": "SYSTEM",
			"target_uuids": [instance.ball_uuid],
			"visual_payload": {
				"stat": "static_stacks",
				"amount": -1,
				"new_val": new_static,
				"targets_new_val": [new_static],
				"new_value": new_static,
				"old_value": static_stacks
			}
		})
		_combat.add_inline_event(static_event)
		
		var static_effect_script = preload("res://scripts/effects/EffectStaticDischarge.gd").new()
		var request = EffectRequest.new(
			"",
			&"static_discharge",
			static_effect_script,
			[instance.ball_uuid],
			{"is_simulation": true, "ability_id": &"static_discharge"},
			C.PRIORITY_STANDARD
		)
		_pending_reactions.append(request)

func trigger_on_hurt(target_uuid: String, damage_amount: int, attacker_uuid: String, cause: StringName = C.CAUSE_ATTACK) -> void:
	# Get target instance data for context (effects should not query instances directly)
	var target_instance = get_instance_by_uuid(target_uuid)
	var victim_team := ""
	var victim_current_hp := 0
	if is_instance_valid(target_instance):
		victim_current_hp = target_instance.current_hp
		if target_instance.location_container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP:
			victim_team = "PLAYER"
		elif target_instance.location_container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
			victim_team = "ENEMY"
	
	# LIFESTEAL TIMING FIX: Process on_damage_dealt BEFORE on_hurt
	if not attacker_uuid.is_empty():
		# Resolve the actual attacking UNIT - if attacker is an item, get the holder
		var actual_attacker_uuid := attacker_uuid
		var attacker_instance = get_instance_by_uuid(attacker_uuid)
		if is_instance_valid(attacker_instance):
			var attacker_def = attacker_instance.get_definition()
			if is_instance_valid(attacker_def) and attacker_def.category == &"ITEM":
				if not attacker_instance.equipped_on_uuid.is_empty():
					actual_attacker_uuid = attacker_instance.equipped_on_uuid
		
		TurnAbilities.trigger_on_damage_dealt(actual_attacker_uuid, target_uuid, damage_amount, victim_current_hp)
	
	# Trigger on_hurt for the victim (counter-attacks, etc.) AFTER lifesteal
	TurnAbilities.trigger_on_hurt(target_uuid, damage_amount, attacker_uuid, victim_team, victim_current_hp, cause)
	
	# NEW: Also fire on_ally_hurt for reactive abilities that watch teammates
	var victim_loc = get_location_for_uuid(target_uuid)
	var victim_slot_index: int = victim_loc.index if is_instance_valid(victim_loc) else -1
	TurnAbilities.trigger_on_ally_hurt(target_uuid, damage_amount, attacker_uuid, victim_team, victim_slot_index)


## Trigger on_kill event for a unit that killed another unit.
## @param killer_uuid: String - The UUID of the unit that got the kill
## @param killed_uuid: String - The UUID of the unit that was killed
func trigger_on_kill(killer_uuid: String, killed_uuid: String) -> void:
	TurnAbilities.trigger_on_kill(killer_uuid, killed_uuid)

## Trigger on_battle_start abilities for all units.
func _trigger_battle_start_abilities() -> void:
	TurnAbilities.trigger_battle_start_abilities(_state)
	# Trigger passive scaling right after battle start abilities
	AbilityResolver.process_trigger(&"on_board_changed", {})
	# Instantly resolve starting passive stats/buffs before the first turn begins.
	_combat.process_reaction_queue(self, {})
	
	_flush_deferred_enemy_erasures()

## Trigger on_turn_start abilities for all units and trinkets.
func _trigger_turn_start_abilities() -> void:
	if _turn_start_abilities_triggered:
		return
		
	_turn_start_abilities_triggered = true # Set flag here to prevent multiple calls
	
	# Skip firing turn start triggers on the very first turn so they only count
	# after the player presses 'Battle!' (End Turn) for the first time.
	if _current_turn <= 1:
		_on_turn_animation_finished()
		return

	var slot_transition_events := _advance_death_slot_progression()
	
	# Trigger turn start abilities for all instances using unified processing
	# This queues ability requests into _pending_reactions
	var turn_start_context: Dictionary = {"turn": _current_turn}
	AbilityResolver.process_trigger(&"on_turn_start", turn_start_context)
	
	# QUEUE Trait Start-of-Turn Effects (e.g., Earth Armor)
	# We queue this as a reaction with specific priority so it interleaves correctly
	# with other turn start abilities (e.g. Mimic Transform should happen BEFORE traits).
	var trait_request = EffectRequest.new(
		"SYSTEM",
		"trait_start_effects",
		null,
		[],
		{},
		C.PRIORITY_TRAIT_BURN # 100
	)
	_pending_reactions.append(trait_request)
	
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
	
	# Sort reactions by priority descending (Higher priority executes first)
	_pending_reactions.sort_custom(func(a, b): return b.priority < a.priority)
	
	# Process turn start effects (heals, etc.) without starting combat
	# Don't populate actor queue - we're just processing turn start abilities
	if not _pending_reactions.is_empty() or not slot_transition_events.is_empty():
		_resolve_pending_reactions_only(slot_transition_events)
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
		
	return EffectRequest.new(
		"", # Empty source_uuid so it bypasses validation checks
		ability_id,
		effect_def,
		[target_uuid],
		{"is_simulation": true, "ability_id": ability_id},
		C.PRIORITY_STANDARD # 0
	)

func _advance_death_slot_progression() -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	if _current_turn < DEATH_SLOT_START_TURN:
		return events
	
	var active_death_slots := mini(LINEUP_SLOT_COUNT, _current_turn - DEATH_SLOT_START_TURN + 1)
	events.append_array(_advance_team_death_slots(_state.player_slot_effects, active_death_slots, true))
	events.append_array(_advance_team_death_slots(_state.enemy_slot_effects, active_death_slots, false))
	return events

func _advance_team_death_slots(slot_effects: Array[StringName], active_death_slots: int, is_player_team: bool) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	for offset in range(active_death_slots):
		# Frontmost follows existing board semantics:
		# Player lineup front = highest index, Enemy lineup front = lowest index.
		var slot_index := (LINEUP_SLOT_COUNT - 1 - offset) if is_player_team else offset
		if slot_index < 0 or slot_index >= slot_effects.size():
			continue
		
		var previous_effect: StringName = slot_effects[slot_index]
		if previous_effect == DEATH_SLOT_EFFECT:
			continue
		
		slot_effects[slot_index] = DEATH_SLOT_EFFECT
		var container_tag: StringName = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player_team else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
		events.append(CombatEvent.new(CombatEvent.Type.SLOT_EFFECT_CHANGE, {
			"visual_payload": {
				"container_tag": container_tag,
				"slot_index": slot_index,
				"from_effect": previous_effect,
				"to_effect": DEATH_SLOT_EFFECT
			}
		}))
	return events



## Process pending reactions without populating the actor queue
## Used for turn start abilities that shouldn't trigger combat
## Process pending reactions without populating the actor queue
## Used for turn start abilities that shouldn't trigger combat
func _resolve_pending_reactions_only(extra_events: Array[CombatEvent] = []) -> void:
	if _is_processing_effect: return
	_is_processing_effect = true
	_resolve_animator()
	
	# Process only pending reactions (turn start abilities), don't populate actor queue
	var all_events_for_animator: Array[CombatEvent] = []
	var death_tracking: Dictionary = {}
	
	# Capture board snapshot BEFORE simulation
	var start_snapshot = get_board_snapshot()
	all_events_for_animator.append_array(extra_events)
	
	# Process all pending reactions (turn start abilities)
	# UNIFIED LOGIC: Use CombatSimulator's processor to handle priority, inline events, and deaths
	all_events_for_animator.append_array(_combat.process_reaction_queue(self , death_tracking))
	
	# FINAL DEATH CHECK + FLUSH: Ensure any skipped deaths (e.g. from inline Thorns) are caught
	# and any deferred deaths (waiting for empty queue) are released immediately.
	_check_for_deaths_with_counter_delay(true, all_events_for_animator, death_tracking)
	_process_completed_counter_deaths(all_events_for_animator, death_tracking)
	
	# Clean up deferred enemy instances AFTER all reactions have resolved
	_flush_deferred_enemy_erasures()
	
	if not all_events_for_animator.is_empty():
		_is_processing_effect = false # Wait, let animator emit finished
		_animator.play_turn_sequence(start_snapshot, all_events_for_animator)
	else:
		_is_processing_effect = false
		_on_turn_animation_finished()

## Resolve pending reactions for management phase triggers (on_draw, on_merge, etc.)
## Uses the VCR pattern: process pending effects, then animate via BattleAnimator.
## Block UI updates (for manual effect orchestration)
func block_ui_updates() -> void:
	_is_processing_effect = true

## Unblock UI updates and flush pending refreshes
func unblock_ui_updates() -> void:
	_is_processing_effect = false
	if _pending_inventory_refresh:
		_emit_battle_inventory_changed()
		SignalBus.emit_signal("inventory_ui_refresh_requested")

## Called from BattleView after gacha draw animation completes.
## @param snapshot: Dictionary - Board snapshot captured BEFORE effects were triggered


func resolve_management_effects_and_animate(snapshot: Dictionary) -> void:
	if _pending_reactions.is_empty():
		return
	
	_resolve_animator()
	
	var events: Array[CombatEvent] = []
	var death_tracking: Dictionary = {}
	
	# Resolve all pending reactions (e.g., Royal Insignia buffs)
	# UNIFIED LOGIC: Use CombatSimulator's processor to handle priority, inline events, and deaths
	events.append_array(_combat.process_reaction_queue(self , death_tracking))
	
	# FINAL DEATH CHECK + FLUSH: Ensure any skipped deaths (e.g. from inline Thorns) are caught
	# and any deferred deaths (waiting for empty queue) are released immediately.
	_check_for_deaths_with_counter_delay(true, events, death_tracking)
	_process_completed_counter_deaths(events, death_tracking)
	
	# Play via animator (uses existing VCR pattern)
	if not events.is_empty():
		_is_processing_effect = true # Block UI redraws while animating management effects
		await _animator.play_turn_sequence(snapshot, events)
	
	# Clean up any deaths that occurred during effect resolution
	# Since is_simulation=true for VCR, cleanup is deferred until now
	_finalize_deaths()
	_is_processing_effect = false

## Flush deferred enemy instance erasures. Called after all reactions have resolved.
## This ensures enemy units and items are still available in _battle_instances while
## their on_death abilities are being processed.
func _flush_deferred_enemy_erasures() -> void:
	if not has_meta("_deferred_enemy_erasures"):
		return
	var erasure_list: Array = get_meta("_deferred_enemy_erasures")
	for uuid in erasure_list:
		if _battle_instances.has(uuid):
			_state.bm_remove_instance(uuid)
	remove_meta("_deferred_enemy_erasures")

func _process_death_slots_end_of_turn(all_events: Array[CombatEvent], death_tracking: Dictionary) -> void:
	var keep_checking := true
	var safety_iterations := 0
	while keep_checking and safety_iterations < 12:
		safety_iterations += 1
		keep_checking = false
		keep_checking = _process_team_death_slots_end_of_turn(
			C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP,
			_state.player_slot_effects,
			"PLAYER",
			all_events,
			death_tracking
		) or keep_checking
		keep_checking = _process_team_death_slots_end_of_turn(
			C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP,
			_state.enemy_slot_effects,
			"ENEMY",
			all_events,
			death_tracking
		) or keep_checking

func _process_team_death_slots_end_of_turn(container_tag: StringName, slot_effects: Array[StringName], death_team: String, all_events: Array[CombatEvent], death_tracking: Dictionary) -> bool:
	var lineup_container = get_container(container_tag)
	if not is_instance_valid(lineup_container):
		return false
	
	var killed_any := false
	
	for slot_index in range(mini(LINEUP_SLOT_COUNT, slot_effects.size())):
		if slot_effects[slot_index] != DEATH_SLOT_EFFECT:
			continue
		
		var unit_uuid := lineup_container.get_uuid(slot_index)
		if unit_uuid.is_empty():
			continue
		
		var unit := get_instance(unit_uuid)
		if not is_instance_valid(unit) or unit.current_hp <= 0:
			continue
		
		unit.current_hp = 0
		_process_registered_death(unit, &"END_OF_TURN", death_team, all_events, death_tracking)
		killed_any = true
	
	return killed_any

func _process_registered_death(unit: GachaBallInstance, phase: StringName, death_team: String, all_events: Array[CombatEvent], death_tracking: Dictionary) -> void:
	if not _register_death(unit, phase):
		return
	
	_create_death_event_if_needed(unit.ball_uuid, all_events, death_tracking)
	_track_first_killed_non_hero(unit, death_team)
	
	var death_location = get_location_for_uuid(unit.ball_uuid)
	AbilityResolver.process_trigger(&"on_death", {
		"dying_uuid": unit.ball_uuid,
		"dying_team": death_team,
		"dying_location": death_location,
		"equipped_items": _snapshot_equipped_items(unit)
	})
	AbilityResolver.process_trigger(&"on_ally_death", {
		"fainting_ally_uuid": unit.ball_uuid,
		"fainting_ally_location": death_location,
		"fainting_ally_team": death_team
	})
	AbilityResolver.process_trigger(&"on_unit_death", {
		"dying_uuid": unit.ball_uuid,
		"dying_team": death_team,
		"dying_location": death_location
	})
	
	while not _pending_reactions.is_empty():
		_pending_reactions.sort_custom(func(a, b): return a.priority > b.priority)
		var death_reaction = _pending_reactions.pop_front()
		var death_reaction_events: Array[CombatEvent] = []
		_resolve_single_effect_request(death_reaction, death_reaction_events, death_tracking)
		all_events.append_array(death_reaction_events)

func _track_first_killed_non_hero(unit: GachaBallInstance, death_team: String) -> void:
	var first_killed_key := "first_killed_player_unit" if death_team == "PLAYER" else "first_killed_enemy_unit"
	if _turn_metadata.has(first_killed_key):
		return
	var unit_def = unit.get_definition()
	if is_instance_valid(unit_def) and not unit_def.is_hero:
		var loc_snapshot = get_location_for_uuid(unit.ball_uuid)
		if is_instance_valid(loc_snapshot):
			_turn_metadata[first_killed_key] = {
				"def_id": unit.definition_id,
				"team": death_team,
				"location_snapshot": loc_snapshot
			}

## Trigger on_turn_end abilities for all units.
func _trigger_turn_end_abilities() -> void:
	# print("DEBUG: _trigger_turn_end_abilities called")
	var all_units = get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP) + get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	var all_events: Array[CombatEvent] = []
	var death_tracking: Dictionary = {}
	
	# Capture board snapshot for animation
	var start_snapshot = get_board_snapshot()

	# 0. Death slots execute before other end-of-turn effects.
	_process_death_slots_end_of_turn(all_events, death_tracking)
	
	# 1. Process Status Effects via StatusEffectRegistry
	# Generic loop replaces hardcoded burn logic
	for status_def in StatusEffectRegistry.get_turn_effects("END_OF_TURN"):
		_process_status_turn_effect(status_def, all_units, all_events, death_tracking)

	# 2. Process on_turn_end triggers
	# print("DEBUG: Processing on_turn_end triggers")
	# 2. Process on_turn_end triggers
	# print("DEBUG: Processing on_turn_end triggers")
	# Call once globally; AbilityResolver iterates all units
	AbilityResolver.process_trigger(&"on_turn_end", {})
	
	# 3. Resolve pending reactions from on_turn_end
	# print("DEBUG: Resolving ", _pending_reactions.size(), " pending reactions")
	# 3. Resolve pending reactions from on_turn_end
	# UNIFIED LOGIC: Use CombatSimulator's processor to handle priority, inline events, and deaths
	all_events.append_array(_combat.process_reaction_queue(self , death_tracking))
	
	# FINAL DEATH CHECK + FLUSH: Ensure any skipped deaths (e.g. from inline Thorns) are caught
	# and any deferred deaths (waiting for empty queue) are released immediately.
	_check_for_deaths_with_counter_delay(true, all_events, death_tracking)
	_process_completed_counter_deaths(all_events, death_tracking)
	
	# 4. Play animations or finish immediately
	if not all_events.is_empty():
		_is_processing_effect = true
		_resolve_animator()
		await _animator.play_turn_sequence(start_snapshot, all_events)
	else:
		# No events to animate, proceed immediately
		_on_turn_animation_finished()


# Deprecated: Logic moved into _trigger_turn_end_abilities
func _process_turn_end_status_effects() -> void:
	pass

## Generic status effect turn processor. Handles any status effect at turn start/end.
## @param status_def: StatusEffectDefinition resource from registry
## @param all_units: Array of units to process
## @param all_events: Array to append CombatEvents to
## @param death_tracking: Dictionary for death deduplication
func _process_status_turn_effect(status_def: Resource, all_units: Array, all_events: Array[CombatEvent], death_tracking: Dictionary) -> void:
	for unit in all_units:
		if unit.current_hp <= 0:
			continue
		
		var stacks: int = unit.get_status_effect_amount(status_def.id)
		if stacks <= 0:
			continue
		
		var unit_name: String = _get_instance_display_name(unit)
		var status_name: String = tr(status_def.display_name_key) if not status_def.display_name_key.is_empty() else String(status_def.id)
		
		# Apply turn effect (DAMAGE or HEAL)
		if status_def.turn_effect == "DAMAGE":
			var damage: int = int(stacks * status_def.turn_effect_multiplier)
			var old_hp: int = unit.current_hp
			var old_armor: int = unit.get_status_effect_amount(&"armor")
			
			# apply_stat_delta now returns dictionary for damage with armor mitigation data
			var damage_result = apply_stat_delta(unit, "hp", -damage, status_def.id == &"burn")
			
			# Extract data from dictionary return
			var new_hp: int = damage_result.get("new_hp", unit.current_hp) if damage_result is Dictionary else unit.current_hp
			var armor_consumed: int = damage_result.get("armor_consumed", 0) if damage_result is Dictionary else 0
			var new_armor: int = damage_result.get("new_armor", 0) if damage_result is Dictionary else 0
			
			var max_hp: int = 0
			var unit_def = unit.get_definition()
			if is_instance_valid(unit_def):
				max_hp = unit_def.base_hp
			
			all_events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
				"text": "%s takes %d %s dmg" % [unit_name, damage, status_name]
			}))
			all_events.append(CombatEvent.new(CombatEvent.Type.DAMAGE, {
				"source_uuid": "",
				"target_uuids": [unit.ball_uuid],
				"visual_payload": {
					"amount": - damage,
					"stat": "hp",
					"skip_bump": true,
					"is_status_damage": true,
					"status_color": status_def.color,
					"targets_old_hp": [old_hp],
					"targets_new_hp": [new_hp],
					"targets_max_hp": [max_hp],
					"targets_old_armor": [old_armor],
					"targets_new_armor": [new_armor],
					"armor_consumed": [armor_consumed]
				}
			}))

		elif status_def.turn_effect == "HEAL":
			var heal: int = int(stacks * status_def.turn_effect_multiplier)
			var old_hp: int = unit.current_hp
			var new_hp = apply_stat_delta(unit, "hp", heal)
			var max_hp: int = 0
			var unit_def = unit.get_definition()
			if is_instance_valid(unit_def):
				max_hp = unit_def.base_hp
			
			all_events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
				"text": "%s heals %d from %s" % [unit_name, heal, status_name]
			}))
			all_events.append(CombatEvent.new(CombatEvent.Type.HEAL, {
				"source_uuid": "",
				"target_uuids": [unit.ball_uuid],
				"visual_payload": {
					"amount": heal,
					"stat": "hp",
					"targets_old_hp": [old_hp],
					"targets_new_hp": [new_hp],
					"targets_max_hp": [max_hp]
				}
			}))
		
		# Apply decay
		var old_stacks: int = stacks
		var new_stacks: int = stacks
		
		var is_burn_decay_immune := false
		if status_def.id == &"burn":
			var loc = get_location_for_uuid(unit.ball_uuid)
			if is_instance_valid(loc):
				if loc.container == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP:
					if loc.index >= 0 and loc.index < _state.player_slot_effects.size() and _state.player_slot_effects[loc.index] == &"burn":
						is_burn_decay_immune = true
				elif loc.container == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
					if loc.index >= 0 and loc.index < _state.enemy_slot_effects.size() and _state.enemy_slot_effects[loc.index] == &"burn":
						is_burn_decay_immune = true
		
		if is_burn_decay_immune:
			new_stacks = stacks
		else: # Apply normal decay
			var armor_decay_prevented_by_polished := false
			match status_def.decay_mode:
				"HALVE":
					new_stacks = int(floor(stacks / 2.0))
				"DECREMENT":
					new_stacks = stacks - status_def.decay_amount
				"CLEAR":
					# Armor Decay Exception: Polished Plate Trinket or Hero Bastion
					if status_def.id == &"armor":
						var is_player_unit = _is_player_unit(unit)
						if _has_team_trinket(is_player_unit, &"trinket_polished_plate"):
							new_stacks = stacks
							armor_decay_prevented_by_polished = true
						elif unit.definition_id == &"hero_bastion":
							new_stacks = stacks
						else:
							new_stacks = 0
					else:
						new_stacks = 0
			
			if armor_decay_prevented_by_polished:
				all_events.append(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
					"source_uuid": "",
					"target_uuids": [unit.ball_uuid],
					"visual_payload": {
						"amount": 0,
						"stat": "armor_stacks",
						"new_val": new_stacks,
						"status_color": status_def.color,
						"trinket_activations": [{
							"definition_id": &"trinket_polished_plate",
							"is_enemy": not _is_player_unit(unit)
						}]
					}
				}))
		
		if new_stacks != old_stacks:
			if new_stacks <= 0:
				unit.clear_status_effect(status_def.id)
				new_stacks = 0
			else:
				var decay_delta: int = new_stacks - old_stacks
				apply_stat_delta(unit, String(status_def.id) + "_stacks", decay_delta)
			
			# Emit STATUS_EFFECT event for status decay so animator updates the visual
			all_events.append(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
				"source_uuid": "",
				"target_uuids": [unit.ball_uuid],
				"visual_payload": {
					"amount": new_stacks - old_stacks,
					"stat": String(status_def.id) + "_stacks",
					"new_val": new_stacks,
					"status_color": status_def.color
				}
			}))
		
		# Handle death from status damage
		if unit.current_hp <= 0:
			var death_team: String = "PLAYER" if _is_player_unit(unit) else "ENEMY"
			_process_registered_death(unit, &"END_OF_TURN", death_team, all_events, death_tracking)

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
		"trigger_type": request.trigger_context.get("trigger_type", ""),
		"ability_holder_uuid": request.source_uuid,
		"visual_payload": {
			"source_uuid": request.source_uuid,
			"amount": amount,
			"stat": "armor_stacks",
			"targets_old_val": targets_old_val,
			"targets_new_val": targets_new_val
		}
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
	# CRITICAL: Do not recalculate stats during COMBAT phase
	# This would emit unit_stat_changed which triggers SlotView updates, destroying registered views
	if _current_battle_phase == Phases.COMBAT:
		return
	
	# Only recalculate stats for the specific unit that changed
	var unit_instance = get_instance(unit_uuid)
	if is_instance_valid(unit_instance):
		unit_instance.recalculate_stats(_battle_instances)

func _on_draw_gacha_requested(tier: int) -> void:
	# Delegate to atomic composite; preserves legacy signal order
	# Ignore draw intents during COMBAT to enforce strict input blocking.
	if _current_battle_phase != Phases.MANAGEMENT:
		return
	bm_draw_gacha_instance(tier)


# Helper function to equip an item on a unit
func _perform_equip(item_instance: GachaBallInstance, unit_instance: GachaBallInstance) -> void:
	var empty_slot_idx: int = unit_instance.equipped_item_uuids.find("")
	if empty_slot_idx != -1:
		unit_instance.equipped_item_uuids[empty_slot_idx] = item_instance.ball_uuid
		item_instance.equipped_on_uuid = unit_instance.ball_uuid
		item_instance.equipped_slot_index = empty_slot_idx
		
		# Apply the item's stat bonuses to the unit
		unit_instance.equip_item_bonus(item_instance)


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

func _on_flashcard_completed(results: Dictionary) -> void:
	# TDD Section 9.4: Battle Flow
	# This handler is only for the battle context.
	# BattleManager only exists during battle, so we don't need to check is_in_battle.
	# NOTE: Window closing is now handled by FlashcardManager
	_last_minigame_results = results

	# Automatically emit results acknowledged to trigger dependencies and phase transition
	# skipping the ResultsPopup to go directly to game flow
	SignalBus.results_acknowledged.emit()

func _on_results_acknowledged() -> void:
	"""Called when player acknowledges the results popup"""
	# NOTE: Tokens are now awarded LIVE during animation via add_gacha_token()
	# The FlashcardMinigame calls add_gacha_token(1) each time a token lands
	# So we no longer need to bulk-award tokens here
	
	_last_minigame_results.clear()
	
	SignalBus.emit_signal("close_modal_requested")
	
	# Trigger turn start abilities AFTER mini-game completion
	if not _turn_start_abilities_triggered:
		_trigger_turn_start_abilities()
		# Don't transition to MANAGEMENT yet - let abilities execute and animate first
		# _on_turn_animation_finished() will transition to MANAGEMENT after animations complete
	else:
		# No abilities to execute, go directly to MANAGEMENT
		_change_phase(Phases.MANAGEMENT)


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

func equip_item(item_uuid: String, unit_uuid: String, slot_index: int = -1) -> bool:
	return bm_equip_item(item_uuid, unit_uuid, slot_index)
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
## This enables any unit with the tag to protect allies, not just Guardian Sentinel.
func _find_guardian_on_team(is_player_team: bool, exclude_uuid: String) -> GachaBallInstance:
	return BattleHelpers.find_interceptor_on_team(_state, is_player_team, exclude_uuid)

func _finalize_deaths() -> void:
	# THIN WRAPPER: Delegates to DeathProcessor
	var something_changed = DeathProcessor.finalize_deaths(self )
	
	_flush_deferred_enemy_erasures()
	
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
	var counts: Dictionary = {"FIRE": 0, "EARTH": 0, "WATER": 0, "AIR": 0}
	var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if team == "PLAYER" else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	
	var units = get_instances_in_container(container_tag)
	# Removed debug print during calc to reduce noise
	for unit in units:
		if not is_instance_valid(unit) or unit.current_hp <= 0:
			continue
		
		var soul_counts = unit.get_trait_soul_counts(get_all_instances())
		for soul_type in ["FIRE", "EARTH", "WATER", "AIR"]:
			counts[soul_type] += soul_counts[soul_type]

	for trait_name in C.TRAIT_SORT_ORDER:
		if not _team_has_trait_trinket(team, trait_name):
			counts[trait_name] = 0

	return counts

## Lock current active traits into snapshot.
func _lock_traits() -> void:
	_locked_ready_traits["PLAYER"] = _calculate_active_traits("PLAYER")
	_locked_ready_traits["ENEMY"] = _calculate_active_traits("ENEMY")

## Check if a unit contributes to a specific Soul trait.
func _has_trait_soul(unit: GachaBallInstance, trait_name: String) -> bool:
	if not is_instance_valid(unit):
		return false
	var target_tag = StringName("SOUL_" + trait_name)
	return unit.get_active_tags(get_all_instances()).has(target_tag)

func _accumulate_trait_tag(counts: Dictionary, tag: StringName) -> void:
	if tag == &"SOUL_FIRE":
		counts["FIRE"] += 1
	elif tag == &"SOUL_EARTH":
		counts["EARTH"] += 1
	elif tag == &"SOUL_WATER":
		counts["WATER"] += 1
	elif tag == &"SOUL_AIR":
		counts["AIR"] += 1

## Apply start-of-turn effects for active traits (e.g., Earth Armor)
## Apply start-of-turn effects for active traits (e.g., Earth Armor)
## Returns Array[CombatEvent] to be animated
func _apply_trait_start_of_turn_effects() -> Array[CombatEvent]:
	var total_events: Array[CombatEvent] = []
	
	# Process for both teams
	for team in ["PLAYER", "ENEMY"]:
		var traits = get_active_traits(team)
		
		# EARTH TRAIT: 3/5/7/9 Souls
		# - All Team Units gain 1/2/3/4 Armor
		# - Earth Units gain DOUBLE Armor (2/4/6/8)
		# - All Team Units gain 1/2/3/4 Spikes (not doubled)
		var earth_souls = traits.get("EARTH", 0)
		if earth_souls >= 3:
			var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if team == "PLAYER" else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
			var units = get_instances_in_container(container_tag)
			
			var armor_value = 0
			var spikes_value = 0
			
			if earth_souls >= 9:
				armor_value = 2
				spikes_value = 2
			elif earth_souls >= 7:
				armor_value = 2
				spikes_value = 1
			elif earth_souls >= 5:
				armor_value = 2
				spikes_value = 0
			elif earth_souls >= 3:
				armor_value = 1
				spikes_value = 0
				
			for unit in units:
				if is_instance_valid(unit) and unit.current_hp > 0:
					var is_earth = _has_trait_soul(unit, "EARTH")
					var armor_to_apply = armor_value
					
					if is_earth:
						armor_to_apply *= 2
						
					if armor_to_apply > 0:
						# Create a request-like structure for the event creation
						var mock_request = EffectRequest.new(unit.ball_uuid, &"trait_earth_armor", null, [unit.ball_uuid], {}, 0)
						
						# Reuse handle_armor_stacks logic or apply manually
						var event = handle_armor_stacks(mock_request, [unit.ball_uuid], armor_to_apply)
						total_events.append(event)
					
					# Apply Spikes to ALL team units (not doubled for Earth units)
					if spikes_value > 0:
						var old_spikes = unit.get_status_effect_amount(&"spikes")
						var new_spikes = apply_stat_delta(unit, "spikes_stacks", spikes_value)
						
						var spikes_event = CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
							"source_uuid": "",
							"target_uuids": [unit.ball_uuid],
							"ability_id": &"trait_earth_spikes",
							"visual_payload": {
								"amount": spikes_value,
								"stat": "spikes_stacks",
								"targets_old_val": [old_spikes],
								"targets_new_val": [new_spikes]
							}
						})
						total_events.append(spikes_event)
		
		# FIRE TRAIT: 7+ Souls -> Opposing team gets 2 Burn stacks
		var fire_souls = traits.get("FIRE", 0)
		if fire_souls >= 7:
			var opposing_container_tag = C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if team == "PLAYER" else C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
			var opposing_units = get_instances_in_container(opposing_container_tag)
			
			# Reuse EffectHandlers logic if possible, or implement burn application directly
			for unit in opposing_units:
				if is_instance_valid(unit) and unit.current_hp > 0:
					# Apply 2 burn stacks
					var amount = 2
					var old_val = unit.get_status_effect_amount(&"burn")
					# Silent update for simulation state
					var new_val = apply_stat_delta(unit, "burn_stacks", amount)
					
					var event = CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
						"source_uuid": "", # Trait effect has no single unit source
						"target_uuids": [unit.ball_uuid],
						"ability_id": &"trait_fire_burn",
						"visual_payload": {
							"amount": amount,
							"stat": "burn_stacks",
							"targets_old_val": [old_val],
							"targets_new_val": [new_val]
						}
					})
					total_events.append(event)
		
		# WATER TRAIT: 2+ Souls -> Water units heal adjacent allies 1 HP at start of turn
		var water_souls = traits.get("WATER", 0)
		if water_souls >= 2:
			var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if team == "PLAYER" else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
			var units = get_instances_in_container(container_tag)
			
			for unit in units:
				if not is_instance_valid(unit) or unit.current_hp <= 0:
					continue
				# Only Water units trigger this
				if not _has_trait_soul(unit, "WATER"):
					continue
				
				# Get adjacent allies (using existing helper)
				var adjacent_allies = _get_adjacent_allies(unit)
				for ally in adjacent_allies:
					if not is_instance_valid(ally) or ally.current_hp <= 0:
						continue
					
					var old_hp = ally.current_hp
					var new_hp = apply_stat_delta(ally, "hp", 1)
					
					if new_hp > old_hp:
						var ally_def = ally.get_definition()
						var max_hp = ally_def.base_hp if is_instance_valid(ally_def) else 0
						
						var event = CombatEvent.new(CombatEvent.Type.HEAL, {
							"source_uuid": unit.ball_uuid,
							"target_uuids": [ally.ball_uuid],
							"ability_id": &"trait_water_heal",
							"visual_payload": {
								"source_uuid": unit.ball_uuid,
								"amount": 1,
								"stat": "hp",
								"skip_bump": false,
								"targets_old_hp": [old_hp],
								"targets_new_hp": [new_hp],
								"targets_max_hp": [max_hp]
							}
						})
						total_events.append(event)
						
						# Trigger on_healed for reactions (e.g. Tier 1 Air units)
						TurnAbilities.trigger_on_healed(ally.ball_uuid, 1, unit.ball_uuid)
		
		# AIR TRAIT: 2+ Souls -> Air units steal 1 PWR from the opposite enemy
		var air_souls = traits.get("AIR", 0)
		if air_souls >= 2:
			var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if team == "PLAYER" else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
			var enemy_container_tag = C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if team == "PLAYER" else C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
			var is_player_team = (team == "PLAYER")
			var units = get_instances_in_container(container_tag)
			var enemy_container = get_container(enemy_container_tag)
			var source_container = get_container(container_tag)
			
			for unit in units:
				if not is_instance_valid(unit) or unit.current_hp <= 0:
					continue
				# Only Air units trigger this
				if not _has_trait_soul(unit, "AIR"):
					continue
				
				# Get unit's slot index
				var source_slot = source_container.get_index_of_uuid(unit.ball_uuid)
				if source_slot == -1:
					continue
				
				# Calculate mirror slot (opposite position)
				var source_uuids = source_container.get_all_uuids()
				var source_lineup_size = source_uuids.size()
				var mirror_slot = (source_lineup_size - 1) - source_slot
				
				# Find enemy at mirror slot
				var enemy_uuids = enemy_container.get_all_uuids()
				var enemy: GachaBallInstance = null
				
				# Try mirror slot first
				if mirror_slot >= 0 and mirror_slot < enemy_uuids.size():
					var enemy_uuid = enemy_uuids[mirror_slot]
					if not enemy_uuid.is_empty():
						var potential = get_instance_by_uuid(enemy_uuid)
						if is_instance_valid(potential) and potential.current_hp > 0:
							enemy = potential
				
				# Fallback: target the backmost enemy if mirror slot is empty
				if enemy == null:
					if is_player_team:
						# Backmost enemy for player = HIGHEST slot index
						for slot_index in range(enemy_uuids.size() - 1, -1, -1):
							var uuid = enemy_uuids[slot_index]
							if uuid.is_empty():
								continue
							var potential = get_instance_by_uuid(uuid)
							if is_instance_valid(potential) and potential.current_hp > 0:
								enemy = potential
								break
					else:
						# Backmost enemy for enemy team = LOWEST slot index
						for slot_index in range(enemy_uuids.size()):
							var uuid = enemy_uuids[slot_index]
							if uuid.is_empty():
								continue
							var potential = get_instance_by_uuid(uuid)
							if is_instance_valid(potential) and potential.current_hp > 0:
								enemy = potential
								break
				
				if enemy == null:
					continue
				
				# Steal 1 PWR from enemy (will be clamped to 1 systemically)
				var enemy_old_pwr = enemy.current_pwr
				
				# Always gain 1 PWR
				var unit_old_pwr = unit.current_pwr
				var unit_new_pwr = apply_stat_delta(unit, "pwr", 1)
				
				# Reduce enemy PWR
				var enemy_new_pwr = apply_stat_delta(enemy, "pwr", -1)
				
				# Create debuff event for enemy
				var debuff_event = CombatEvent.new(CombatEvent.Type.BUFF, {
					"source_uuid": enemy.ball_uuid, # Source is enemy (where PWR is being taken from)
					"target_uuids": [enemy.ball_uuid],
					"ability_id": &"trait_air_steal",
					"visual_payload": {
						"source_uuid": enemy.ball_uuid,
						"stat": "pwr",
						"amount": - 1,
						"targets_old_pwr": [enemy_old_pwr],
						"targets_new_pwr": [enemy_new_pwr]
					}
				})
				total_events.append(debuff_event)
				
				# Create buff event for unit - projectile FROM enemy TO Air unit
				var buff_event = CombatEvent.new(CombatEvent.Type.BUFF, {
					"source_uuid": enemy.ball_uuid, # Projectile originates FROM enemy
					"target_uuids": [unit.ball_uuid], # Travels TO Air unit
					"ability_id": &"trait_air_steal",
					"visual_payload": {
						"source_uuid": enemy.ball_uuid, # From enemy
						"stat": "pwr",
						"amount": 1,
						"targets_old_pwr": [unit_old_pwr],
						"targets_new_pwr": [unit_new_pwr]
					}
				})
				total_events.append(buff_event)

	return total_events

# =============================================================================

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

func _on_battle_inventory_penalty(uuid: String) -> void:
	if _battle_instances.has(uuid):
		var instance = _battle_instances.get(uuid)
		var name_str = "Item"
		
		if is_instance_valid(instance):
			var def = instance.get_definition()
			if def and "display_name_key" in def:
				name_str = tr(def.display_name_key)
			
			# SELECTIVE RESHUFFLE: If ball is already in Discard, send it back to Trays
			if instance.location_container_tag == C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE:
				var tier = def.tier if (def is GachaBallDefinition) else 1
				var target_container = "BattleInventoryT%d" % tier
				
				# Restore stats before returning to tray pool
				instance.reset_battle_stats()
				
				# Remove from discard first to prevent duplicate entries (Golden Rule safe)
				_state.remove_instance_from_container(instance)
				
				# Atomic move: add to target tray
				if bm_add_instance(instance, target_container):
					if Engine.has_singleton("BattleLogger"):
						BattleLogger.log_message("[color=cyan]SELECTIVE RESHUFFLE:[/color] %s returned to Tier %d tray." % [name_str, tier])
				return

		# Standard Penalty: move to discard
		bm_move_instance_to_discard(uuid)
		
		if Engine.has_singleton("BattleLogger"):
			BattleLogger.log_message("[color=red]OVERFLOW PENALTY:[/color] %s was moved to discard pile." % name_str)

func _animate_bargain_charm_async(event: CombatEvent) -> void:
	_resolve_animator()
	_is_processing_effect = true
	var snapshot = get_board_snapshot()
	var events: Array[CombatEvent] = [event]
	await _animator.play_turn_sequence(snapshot, events)
	_is_processing_effect = false
	if _pending_inventory_refresh:
		_emit_battle_inventory_changed()
