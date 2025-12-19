class_name BattleManager
extends Node

const RS = preload("res://scripts/RunState.gd")
const BattleStateClass = preload("res://scripts/battle/BattleState.gd")
const CombatSimulatorClass = preload("res://scripts/battle/CombatSimulator.gd")
enum Phases {START_OF_TURN, MANAGEMENT, COMBAT, END_OF_TURN, BATTLE_OVER}
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
var _inline_events: Array[CombatEvent]:
	get: return _combat._inline_events
	set(value): _combat._inline_events = value
var _is_processing_effect: bool:
	get: return _combat._is_processing_effect
	set(value): _combat._is_processing_effect = value

var _battle_over_deferred: bool = false
var _battle_over_emitted: bool = false
var is_test_mode: bool = false


const BATTLE_CONTAINER_TAGS = {
	PLAYER_LINEUP = &"PlayerLineup",
	PLAYER_BENCH = &"PlayerBench",
	PLAYER_ITEM_INVENTORY = &"ItemInventory",
	ENEMY_LINEUP = &"EnemyLineup",
	ENEMY_BENCH = &"EnemyBench",
	BATTLE_DISCARD_PILE = &"DiscardPile",
	ENEMY_TRINKETS = &"EnemyTrinkets",
	PLAYER_TRINKETS = &"PlayerTrinkets",
}

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

const FixedArrayContainer = preload("res://scripts/FixedArrayContainer.gd")
const GrowableGridContainer = preload("res://scripts/GrowableGridContainer.gd")
const EncounterDefinition = preload("res://scripts/EncounterDefinition.gd")
var _last_minigame_results: Dictionary = {}
var _current_turn: int = 0
var _turn_start_abilities_triggered: bool = false

# -----------------------------------------------------------------------------
# INITIALIZATION & SETUP
# -----------------------------------------------------------------------------
@onready var _animator: Node = $"../BattleAnimator"

func _resolve_animator() -> void:
	if is_instance_valid(_animator):
		return
	var candidate = get_tree().get_first_node_in_group("battle_animator")
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
	GameManager.register_battle_manager(self) # ADD THIS LINE
	
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
	# Apply deaths after animator finishes death fades
	if SignalBus.has_signal("apply_deaths_requested") and not SignalBus.is_connected("apply_deaths_requested", _on_apply_deaths_requested):
		SignalBus.apply_deaths_requested.connect(_on_apply_deaths_requested)
	# Removed legacy reshuffle trigger; draw now reshuffles atomically when needed.

func _emit_battle_inventory_changed() -> void:
	SignalBus.emit_signal("battle_inventory_changed")


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
			_state.validate_state_consistency()
		_emit_battle_inventory_changed()
		SignalBus.emit_signal("inventory_ui_refresh_requested")
	return result

func _reshuffle_tier_from_discard(tier_to_reshuffle: int) -> bool:
	return _state.reshuffle_tier_from_discard(tier_to_reshuffle)

func bm_remove_instance(uuid: String) -> bool:
	var result := _state.bm_remove_instance(uuid)
	if result.success:
		if not result.unit_changed_uuid.is_empty():
			SignalBus.emit_signal("unit_inventory_changed", result.unit_changed_uuid)
		if OS.is_debug_build():
			_state.validate_state_consistency()
		_emit_battle_inventory_changed()
		SignalBus.emit_signal("inventory_ui_refresh_requested")
	return result.success


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

func bm_equip_item(item_uuid: String, unit_uuid: String, slot_index: int = -1) -> bool:
	assert(not item_uuid.is_empty(), "bm_equip_item: item_uuid is empty")
	assert(not unit_uuid.is_empty(), "bm_equip_item: unit_uuid is empty")
	
	var result := InventoryOperations.equip_item(_state, item_uuid, unit_uuid, slot_index)
	
	if result.success:
		if OS.is_debug_build():
			_bm_validate_state_consistency()
		for uuid in result.changed_unit_uuids:
			SignalBus.emit_signal("unit_inventory_changed", uuid)
		if result.inventory_changed:
			_emit_battle_inventory_changed()
			SignalBus.emit_signal("inventory_ui_refresh_requested")
	
	return result.success

# ------------------------------------------------------------------
# Composite atomic mutation API (Battle)
# ------------------------------------------------------------------

func bm_move_instance_to_discard(uuid: String) -> bool:
	assert(not uuid.is_empty(), "bm_move_instance_to_discard: uuid is empty")
	var instance := get_instance(uuid)
	assert(is_instance_valid(instance), "bm_move_instance_to_discard: instance not found")
	var loc := instance.get_location()
	assert(is_instance_valid(loc), "bm_move_instance_to_discard: instance has no location")
	# Ownership gate: only player-owned instances can enter the player's discard pile
	assert(_is_player_owned(instance), "bm_move_instance_to_discard: instance is not player owned")
	# If equipped, clear equip mapping; otherwise remove from its container
	if loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var parent := get_instance(loc.unit_uuid)
		if not is_instance_valid(parent):
			return false
		if loc.index < 0 or loc.index >= parent.equipped_item_uuids.size():
			return false
		parent.equipped_item_uuids[loc.index] = ""
		instance.equipped_on_uuid = ""
		instance.equipped_slot_index = -1
	else:
		_remove_instance_from_container(instance)
	# Place into discard
	var discard_container = get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	if not is_instance_valid(discard_container):
		return false
	var index := discard_container.find_first_empty_slot()
	if index == -1:
		push_error("Discard pile full; cannot move %s" % instance.ball_uuid)
		return false
	discard_container.set_uuid(index, instance.ball_uuid)
	_update_instance_location(instance.ball_uuid, BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE, index)
	if OS.is_debug_build():
		_bm_validate_state_consistency()
	_emit_battle_inventory_changed()
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

func bm_reshuffle_discard_pile(tier_to_reshuffle: int) -> bool:
	var moved := _reshuffle_tier_from_discard(tier_to_reshuffle)
	if not moved:
		return false
	if OS.is_debug_build():
		_bm_validate_state_consistency()
	_emit_battle_inventory_changed()
	# Ensure InventoryWindow grids reflect reshuffled draw pools immediately
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

func bm_draw_gacha_instance(tier: int) -> bool:
	var cost := tier
	if _gacha_tokens < cost:
		return false
	
	var container_tag: StringName = "BattleInventoryT%d" % tier
	var tier_pool := get_instances_in_container(container_tag)
	
	# If pool is empty, try reshuffling first
	if tier_pool.is_empty():
		if not _reshuffle_tier_from_discard(tier):
			return false
	
	# Attempt to draw
	var draw_result := InventoryOperations.draw_from_tier(_state, tier, 3, 2)
	
	if not draw_result.success:
		return false
	
	# Spend tokens
	_gacha_tokens -= cost
	SignalBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
	
	# Validate and emit
	if OS.is_debug_build():
		_bm_validate_state_consistency()
	_emit_battle_inventory_changed()
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	
	# If pool emptied, trigger reshuffle for next draw
	if draw_result.pool_emptied:
		_reshuffle_tier_from_discard(tier)
	
	return true

# ------------------------------------------------------------------
# Golden Rule Validation (Battle)
# ------------------------------------------------------------------

func _bm_validate_state_consistency() -> bool:
	return _state.validate_state_consistency()

func get_gacha_tokens() -> int:
	return _gacha_tokens

func get_current_phase_name() -> StringName:
	var phase_name: StringName
	match _current_battle_phase:
		Phases.START_OF_TURN: phase_name = &"START_OF_TURN"
		Phases.MANAGEMENT: phase_name = &"MANAGEMENT"
		Phases.COMBAT: phase_name = &"COMBAT"
		Phases.END_OF_TURN: phase_name = &"END_OF_TURN"
		Phases.BATTLE_OVER: phase_name = &"BATTLE_OVER"
	return phase_name

func get_battle_inventory() -> Dictionary:
	return _containers

func get_discard_pile_inventory() -> Array[GachaBallInstance]:
	var result: Array[GachaBallInstance] = []
	var container = get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
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
			
			# Grant base 5 tokens for the turn
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
				FlashcardManager.start_minigame(GameManager.run_state, GameManager.run_state.active_deck_ids)
			# Note: The management phase will be triggered by _on_results_acknowledged
		Phases.MANAGEMENT:
			# Re-enable draw buttons when entering management phase
			_emit_battle_inventory_changed()
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
		
		# Insert into queue if flagged (boss summons)
		if update.get("insert_into_queue", false):
			var inst = get_instance_by_uuid(uuid)
			if is_instance_valid(inst):
				_insert_summoned_unit_into_queue(inst)
	
	# 4. Handle queue replacements (single unit summons replace holder in queue)
	for update in result.queue_updates:
		var old_uuid: String = update.old_uuid
		var new_inst: GachaBallInstance = update.new_instance
		
		for i in range(_actor_queue.size()):
			if _actor_queue[i].ball_uuid == old_uuid:
				_actor_queue[i] = new_inst
				break

## Enqueue an attack (on_attack trigger + basic attack fallback) for a single actor.
func _enqueue_attack_for(attacker: GachaBallInstance) -> void:
	var is_player = _is_player_unit(attacker)
	var target = _get_frontmost_target(is_player)
	if not is_instance_valid(target): return
	# Build context for on_attack trigger (semantic keys per unified broadcast pattern)
	var context: Dictionary = {
		"attacker_uuid": attacker.ball_uuid,
		"target_uuid": target.ball_uuid,
		"target_initial_hp": target.current_hp,
		"trigger_cause": C.CAUSE_TURN,
		"cause_id": C.CAUSE_TURN # Redundant but explicit for cause_id field
	}
	
	# Trigger on_attack abilities (e.g., Double Strike, Power Amulet)
	print("[BM] _enqueue_attack_for:", attacker.ball_uuid, "-> target:", target.ball_uuid)
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
	# Validate source is still alive (allow empty source UUID for trinket effects)
	var source = null
	if not request.source_uuid.is_empty():
		source = get_instance_by_uuid(request.source_uuid)
		if not is_instance_valid(source):
			return
		# Only gate dead UNIT sources; allow ITEM/TRINKET sources to execute
		# Exceptions:
		# 1. Reactive abilities (counter-attacks, retaliation) allowed post-mortem
		# 2. on_death abilities - the dying unit IS expected to be dead when these execute
		var src_def = source.get_definition()
		if is_instance_valid(src_def) and src_def.category == &"UNIT" and source.current_hp <= 0:
			# Allow if this is the dying unit's own on_death trigger
			var dying_uuid: String = request.trigger_context.get("dying_uuid", "")
			var is_own_death_trigger: bool = (dying_uuid == request.source_uuid)
			
			# Check if ability has execute_on_lethal flag via AbilitiesRegistry or source instance
			var is_reactive_ability: bool = false
			var ability_def = _get_ability_definition(request.ability_id, source)
			if is_instance_valid(ability_def) and ability_def.execute_on_lethal:
				is_reactive_ability = true
			
			if not is_own_death_trigger and not is_reactive_ability:
				return

	# Prepare execution targets from resolved targets. Only basic attacks may dynamically retarget.
	var exec_targets: Array[String] = []
	exec_targets.append_array(request.resolved_targets)
	var is_basic_attack := (request.ability_id == &"basic_attack")
	
	# For ALL abilities (basic or triggered), validate targets are still alive AND in battle
	# Filter out dead targets to prevent ghost attacks
	# NOTE: Must check location_container_tag because reset_battle_stats_silent() restores HP before discard
	var valid_targets: Array[String] = []
	for target_uuid in exec_targets:
		var target_inst = get_instance_by_uuid(target_uuid)
		if is_instance_valid(target_inst) and target_inst.current_hp > 0:
			# Also verify the target is still in an active battle container (not discard/removed)
			var loc_tag: StringName = target_inst.location_container_tag
			var is_in_battle: bool = (loc_tag == BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or
								 loc_tag == BATTLE_CONTAINER_TAGS.ENEMY_LINEUP or
								 loc_tag == BATTLE_CONTAINER_TAGS.PLAYER_BENCH or
								 loc_tag == BATTLE_CONTAINER_TAGS.ENEMY_BENCH)
			if is_in_battle:
				valid_targets.append(target_uuid)
	
	# Allow targetless effects (e.g., summons) to proceed
	# They will provide their own targets in the return data
	# Only abort if we EXPECTED targets but they're all invalid
	if valid_targets.is_empty() and not exec_targets.is_empty():
		return
	
	exec_targets = valid_targets
	
	# For basic attacks only, apply retargeting to frontmost if needed
	if is_basic_attack and exec_targets.size() > 0:
		var first_target = get_instance_by_uuid(exec_targets[0])
		if not is_instance_valid(first_target) or first_target.current_hp <= 0:
			var attacker_is_player: bool = false
			if is_instance_valid(source):
				attacker_is_player = _is_player_unit(source)
			var new_target_inst = _get_frontmost_target(attacker_is_player)
			if is_instance_valid(new_target_inst):
				exec_targets[0] = new_target_inst.ball_uuid
			else:
				return
	# Execute without emitting UI; capture results for events
	var damage := 0
	if is_instance_valid(request.effect_definition):
		var sim_ctx = request.trigger_context.duplicate(true)
		sim_ctx["is_simulation"] = true
		sim_ctx["ability_id"] = request.ability_id
		
		# Zero-Instance-Query Compliance: Pre-populate source data
		# This allows effects to use context data instead of querying instances
		# Data is snapshotted at the EXACT moment before execute(), reflecting current simulation state
		if is_instance_valid(source):
			var source_def = source.get_definition()
			var stat_provider = source # Default: use source's own stats
			
			if is_instance_valid(source_def):
				sim_ctx["source_category"] = source_def.category
				
				# For items, use the HOLDER's stats (not the item's stats which are 0)
				# Also include holder UUID so effects can identify the attacker
				if source_def.category == &"ITEM" and not source.equipped_on_uuid.is_empty():
					sim_ctx["source_holder_uuid"] = source.equipped_on_uuid
					var holder = get_instance_by_uuid(source.equipped_on_uuid)
					if is_instance_valid(holder):
						stat_provider = holder
			
			# Snapshot stats from the appropriate provider (source for units, holder for items)
			sim_ctx["source_pwr"] = stat_provider.current_pwr
			sim_ctx["source_hp"] = stat_provider.current_hp
		
		var effect_script_path = request.effect_definition.get_script().resource_path if request.effect_definition.get_script() else "no_script"
		var res = request.effect_definition.execute(request.source_uuid, exec_targets, self, sim_ctx)
		
		# CRITICAL: Collect on_before_attack inline events IMMEDIATELY after effect execution
		# These events (like Defensive Stance heal) must appear BEFORE any damage events
		# to maintain correct causal order: HEAL → DAMAGE (not DAMAGE → HEAL)
		var before_attack_inline_evts = collect_inline_events()
		out_events.append_array(before_attack_inline_evts)
		
		# IMPORTANT: Normalize legacy integer returns to dictionary format FIRST
		# This must happen before the TYPE_DICTIONARY check so the normalized value gets processed
		if typeof(res) == TYPE_INT:
			var damage_amount = int(res)
			res = {
				"stat": "hp",
				"amount": - damage_amount,
				"targets": exec_targets
			}
		
		# Preferred: structured stat change results
		if typeof(res) == TYPE_DICTIONARY:
			var effect_data: Dictionary = res
			
				# Handle cascading damage (special case for AOE shockwave)
			# TWO-PHASE PROCESSING for visual "wave" effect:
			# Phase 1: Apply all damage + DAMAGE events in sequence
			# Phase 2: Process all reactions (counter-attacks, on_kill) one target at a time
			if effect_data.has("cascade_damage"):
				print("[BM] Processing cascade_damage from ability:", request.ability_id, "source:", request.source_uuid)
				var cascade_list = effect_data.get("cascade_damage", [])
				
				# Phase 1: Apply all damage via EffectHandlers
				var cascade_result := EffectHandlers.handle_cascade_damage(request, cascade_list, source, self)
				out_events.append_array(cascade_result.events)
				
				# Phase 2: Process reactions one target at a time (after all damage shown)
				for hit_data in cascade_result.hit_targets:
					var target_uuid: String = hit_data.uuid
					var damage_amount: int = hit_data.amount
					var was_killed: bool = hit_data.was_killed
					
					# Trigger on_hurt for counter-attacks
					trigger_on_hurt(target_uuid, damage_amount, request.source_uuid)
					
					# Drain on_hurt reactions for THIS target
					drain_pending_reactions_inline(0)
					var cascade_hurt_inline_evts = collect_inline_events()
					out_events.append_array(cascade_hurt_inline_evts)
					
					# Trigger on_kill if killed
					if was_killed:
						trigger_on_kill(request.source_uuid, target_uuid)
				
				# Check for deaths after cascade
				_check_for_deaths_with_counter_delay(true, out_events, death_tracking)
				return

			# Handle extra action effects (e.g., Bloodlust Edge on kill)
			if effect_data.has("extra_action"):
				var unit_uuid = String(effect_data.get("unit_uuid", ""))
				var unit = get_instance_by_uuid(unit_uuid)
				if is_instance_valid(unit):
					var unit_name = _get_instance_display_name(unit)
					out_events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": "%s triggers Bloodlust!" % unit_name}))
				# grant_extra_action was already called in the effect, no further action needed
				return

			# Standard single-stat change processing
			var stat: String = String(effect_data.get("stat", ""))
			var amount: int = int(effect_data.get("amount", 0))
			var targets: Array = effect_data.get("targets", [])
			var skip_bump: bool = bool(effect_data.get("skip_bump", false))
			var resolved_targets: Array[String] = []
			var target_names: Array[String] = []
			for raw_target in targets:
				var target_uuid := String(raw_target)
				resolved_targets.append(target_uuid)
				var target_inst = get_instance_by_uuid(target_uuid)
				var target_label := _get_instance_display_name(target_inst)
				if target_label == "":
					target_label = target_uuid
				target_names.append(target_label)
			var source_name := ""
			if not String(request.source_uuid).is_empty():
				var src_inst = get_instance_by_uuid(request.source_uuid)
				source_name = _get_instance_display_name(src_inst)
			if source_name == "":
				source_name = String(request.ability_id)
		
			if stat == "hp" and not resolved_targets.is_empty():
				# Special case: Aegis Charm prevented lethal damage
				# Emit LETHAL_SAVE event for dramatic visual, then apply heal normally
				if effect_data.get("prevented_lethal", false):
					for tgt_uuid in resolved_targets:
						out_events.append(CombatEvent.new(CombatEvent.Type.LETHAL_SAVE, {
							"source_uuid": request.source_uuid,
							"target_uuids": [tgt_uuid],
							"ability_id": request.ability_id,
							"visual_payload": {
								"saved_uuid": tgt_uuid,
								"heal_amount": amount
							}
						}))
						var tgt = get_instance_by_uuid(tgt_uuid)
						if is_instance_valid(tgt):
							apply_stat_delta(tgt, "hp", amount)
					return # Don't process as normal heal
				
				if amount >= 0:
					out_events.append_array(EffectHandlers.handle_heal_effect(request, resolved_targets, source_name, target_names, amount, skip_bump, self))
				else:
					var damage_result := EffectHandlers.handle_damage_effect(request, resolved_targets, source, source_name, target_names, amount, skip_bump, self)
					out_events.append_array(damage_result.events)
					
					if damage_result.should_return:
						return
					
					# CRITICAL: Trigger on_hurt AFTER apply_stat_delta so condition checks see post-damage HP
					for tgt_uuid in damage_result.damaged_uuids:
						trigger_on_hurt(tgt_uuid, abs(amount), request.source_uuid)
					
					# AEGIS FIX: Drain on_hurt effects BEFORE death check
					drain_pending_reactions_inline(0)
					
					# CRITICAL: Collect inline events (like LETHAL_SAVE) immediately
					var hurt_inline_evts = collect_inline_events()
					out_events.append_array(hurt_inline_evts)
					
					# DETERMINISTIC ON_KILL: If this damage killed the target, trigger on_kill immediately
					for tgt_uuid in damage_result.damaged_uuids:
						var tgt = get_instance_by_uuid(tgt_uuid)
						if is_instance_valid(tgt) and tgt.current_hp <= 0:
							trigger_on_kill(request.source_uuid, tgt_uuid)
			elif stat == "pwr" and amount > 0 and not resolved_targets.is_empty():
				out_events.append_array(EffectHandlers.handle_pwr_buff(request, resolved_targets, target_names, amount, self))
				
			elif stat == "burn_stacks" and not resolved_targets.is_empty():
				out_events.append(EffectHandlers.handle_burn_stacks(request, resolved_targets, amount, self))
			elif stat == "armor_stacks" and not resolved_targets.is_empty():
				out_events.append(handle_armor_stacks(request, resolved_targets, amount))
			# Handle summon effects (e.g., item_t2_c02)
			elif effect_data.has("summon_unit_id"):
				var summon_result := EffectHandlers.handle_summon_unit(request, effect_data, self)
				_apply_summon_result(summon_result)
				out_events.append_array(summon_result.events)
			# Handle boss summon effects (array of units to summon)
			elif effect_data.has("summon_units"):
				var summon_result := EffectHandlers.handle_summon_units(request, effect_data, self)
				_apply_summon_result(summon_result)
				out_events.append_array(summon_result.events)
			# Handle multi_heal effects (e.g., Heart Stone - two random allies healed independently)
			elif effect_data.has("multi_heal") and effect_data.get("multi_heal", false):
				out_events.append_array(EffectHandlers.handle_multi_heal(request, effect_data, self))
			# Handle multi_buff effects (e.g., Power Amulet - two random allies buffed independently)
			elif effect_data.has("multi_buff") and effect_data.get("multi_buff", false):
				out_events.append_array(EffectHandlers.handle_multi_buff(request, effect_data, self))
	# CRITICAL FIX: Death check MUST run unconditionally after any effect execution
	# This was previously inside the TYPE_DICTIONARY block, causing deaths from the
	# last attack of a turn to miss on_ally_death triggers when effect returned null
	_check_for_deaths_with_counter_delay(true, out_events, death_tracking)

## New priority-driven combat phase resolution.
## Uses actor queue with nested reaction loops for cascading effects.
func get_board_snapshot() -> Dictionary:
	return BattleHelpers.get_combat_board_snapshot(_battle_instances)

func _resolve_combat_phase() -> void:
	if _is_processing_effect: return
	_resolve_animator()
	_populate_actor_queue()
	
	# 1. Capture State BEFORE Simulation
	var start_snapshot = get_board_snapshot()
	var death_tracking: Dictionary = {}
	
	# 2. Execute combat turn via CombatSimulator
	var turn_log: Array[CombatEvent] = _combat.execute_combat_turn(self, death_tracking)
	
	# 3. Clean up deferred enemy instances AFTER all reactions have resolved
	_flush_deferred_enemy_erasures()
	
	_is_processing_effect = false
	
	# 4. Send Log to Animator (The VCR Playback)
	if not turn_log.is_empty():
		_animator.play_turn_sequence(start_snapshot, turn_log)
	else:
		_on_turn_animation_finished()

func _on_turn_animation_finished() -> void:
	# This signal is the single source of truth for when animations are complete.
	# It is safe to proceed to the next phase.
	_is_processing_effect = false
	
	# Finalize any remaining deaths (removes zombies)
	_finalize_deaths()
	
	if _current_battle_phase == Phases.START_OF_TURN:
		# Turn start abilities finished animating, transition to MANAGEMENT
		_change_phase(Phases.MANAGEMENT)
	elif _current_battle_phase == Phases.END_OF_TURN:
		# Check if battle is over after poison/turn-end effects
		if _battle_over_deferred or _is_battle_over():
			_battle_over_deferred = false
			_emit_battle_over()
			return
		# Poison/turn-end animations finished, now start the next turn
		_change_phase(Phases.START_OF_TURN)
	elif _current_battle_phase == Phases.COMBAT:
		# If a battle over condition was detected during simulation, emit it now
		if _battle_over_deferred:
			_battle_over_deferred = false
			# Emit and transition to BATTLE_OVER now that visuals are done
			_emit_battle_over()
			return
		# After combat finishes, trigger end of turn abilities, then start next turn
		_change_phase(Phases.END_OF_TURN)

func _move_instance_to_discard(instance: GachaBallInstance) -> void:
	assert(is_instance_valid(instance), "_move_instance_to_discard: instance is null")
	# Ownership gate: only player-owned instances can enter the player's discard pile
	assert(_is_player_owned(instance), "_move_instance_to_discard: instance is not player owned")
	# Atomically remove from current location (equipped or container) and place into discard
	var loc := get_location_for_uuid(instance.ball_uuid)
	if is_instance_valid(loc):
		if loc.container == C.CONTAINER_EQUIPPED_ITEM:
			var parent := get_instance(loc.unit_uuid)
			if is_instance_valid(parent):
				if loc.index >= 0 and loc.index < parent.equipped_item_uuids.size():
					# Clear the parent's slot mapping if it points to this instance
					if parent.equipped_item_uuids[loc.index] == instance.ball_uuid:
						parent.equipped_item_uuids[loc.index] = ""
			# Clear equipped linkage on the item itself
			instance.equipped_on_uuid = ""
			instance.equipped_slot_index = -1
		else:
			var src := get_container(loc.container)
			if is_instance_valid(src):
				var uuids := src.get_all_uuids()
				var si := uuids.find(instance.ball_uuid)
				if si != -1:
					src.set_uuid(si, "")
	var discard_container = get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	if not is_instance_valid(discard_container): return
	var index := discard_container.find_first_empty_slot()
	if index == -1:
		# Discard full: do not attempt out-of-bounds write; leave instance removed and log via validator
		return
	discard_container.set_uuid(index, instance.ball_uuid)
	_update_instance_location(instance.ball_uuid, BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE, index)

func _remove_instance_from_container(instance: GachaBallInstance) -> void:
	assert(is_instance_valid(instance), "_remove_instance_from_container: instance is null")
	var loc = get_location_for_uuid(instance.ball_uuid)
	assert(is_instance_valid(loc), "_remove_instance_from_container: instance has no location")
	var container = get_container(loc.container)
	if is_instance_valid(container):
		var uuids = container.get_all_uuids()
		var idx: int = uuids.find(instance.ball_uuid)
		if idx != -1:
			container.set_uuid(idx, "")
			_update_instance_location(instance.ball_uuid, &"", -1)
		else:
			push_error("Remove failed: %s not found in stated container %s" % [instance.ball_uuid, String(loc.container)])

func _check_for_deaths(is_simulation: bool = false, out_events = null) -> void:
	var something_changed = false
	var player_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP).duplicate()
	for unit in player_units:
		if unit.current_hp <= 0:
			# Use unified death registry to prevent duplicate processing
			if not _register_death(unit, &"COMBAT"):
				continue # Already died earlier this turn
			something_changed = true
			if is_simulation and out_events != null:
				# During simulation, ONLY add DEATH event - do not process actual death yet
				# This keeps the unit visible for counter-attacks
				out_events.append(CombatEvent.new(CombatEvent.Type.DEATH, {
					"target_uuids": [unit.ball_uuid],
					"visual_payload": {}
				}))
			elif not is_simulation:
				# Trigger on_death for the dying unit (semantic key: dying_uuid)
				var death_location = get_location_for_uuid(unit.ball_uuid)
				var death_context: Dictionary = {
					"dying_uuid": unit.ball_uuid,
					"dying_team": "PLAYER",
					"dying_location": death_location,
					"equipped_items": _snapshot_equipped_items(unit)
				}
				AbilityResolver.process_trigger(&"on_death", death_context)
				
				# UNIFIED BROADCAST: Single call, AbilityResolver self-filters
				var ally_death_context: Dictionary = {
					"fainting_ally_uuid": unit.ball_uuid,
					"fainting_ally_location": death_location,
					"fainting_ally_team": "PLAYER"
				}
				AbilityResolver.process_trigger(&"on_ally_death", ally_death_context)
				
				# DEFER cleanup - unit must stay in original container
				# _perform_unit_death_cleanup(unit)
		
	var enemy_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).duplicate()
	for unit in enemy_units:
		if unit.current_hp <= 0:
			# Use unified death registry to prevent duplicate processing
			if not _register_death(unit, &"COMBAT"):
				continue # Already died earlier this turn
			something_changed = true
			if is_simulation and out_events != null:
				# During simulation, ONLY add DEATH event - do not process actual death yet
				# This keeps the unit visible for counter-attacks
				out_events.append(CombatEvent.new(CombatEvent.Type.DEATH, {
					"target_uuids": [unit.ball_uuid],
					"visual_payload": {}
				}))
			elif not is_simulation:
				# Trigger on_death for the dying unit (semantic key: dying_uuid)
				var death_location = get_location_for_uuid(unit.ball_uuid)
				var death_context: Dictionary = {
					"dying_uuid": unit.ball_uuid,
					"dying_team": "ENEMY",
					"dying_location": death_location,
					"equipped_items": _snapshot_equipped_items(unit)
				}
				AbilityResolver.process_trigger(&"on_death", death_context)
				
				# UNIFIED BROADCAST: Single call, AbilityResolver self-filters
				var ally_death_context: Dictionary = {
					"fainting_ally_uuid": unit.ball_uuid,
					"fainting_ally_location": death_location,
					"fainting_ally_team": "ENEMY"
				}
				AbilityResolver.process_trigger(&"on_ally_death", ally_death_context)
				
				# DEFER cleanup - unit must stay in original container
				# _perform_unit_death_cleanup(unit)
		
## Centralized logic for cleaning up a dead unit.
## Moves player units to discard, removes enemy units entirely.

## Snapshot equipped items for context enrichment (effects should use context, not query instances)
func _snapshot_equipped_items(unit: GachaBallInstance) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for item_uuid in unit.equipped_item_uuids:
		if not item_uuid.is_empty():
			var item = get_instance(item_uuid)
			if is_instance_valid(item):
				var item_def = item.get_definition()
				items.append({
					"uuid": item.ball_uuid,
					"def_id": item.definition_id,
					"equipped_on_uuid": item.equipped_on_uuid,
					"slot_index": item.equipped_slot_index,
					"category": item_def.category if is_instance_valid(item_def) else &"ITEM"
				})
	return items

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

## Check if a unit has any abilities that can execute after receiving lethal damage.
## This is determined by the `execute_on_lethal` flag on AbilityDefinition.
func _has_lethal_counter_abilities(unit: GachaBallInstance) -> bool:
	return DeathProcessor.has_lethal_counter_abilities(unit, _battle_instances)


## Enhanced death checking that defers death events for units with counter-attacks
func _check_for_deaths_with_counter_delay(is_simulation: bool = false, out_events = null, death_tracking = null) -> void:
	var something_changed = false
	var deferred_deaths: Array[String] = [] # Units whose deaths should be deferred
	
	# SKIP death trigger processing if called from drain_pending_reactions_inline
	# This prevents duplicate on_ally_death triggers for already-dead units
	if death_tracking != null and death_tracking.get("__skip_death_triggers__", false):
		return
	
	# CAUSALITY FIX: Drain ONLY execute_on_lethal reactions BEFORE processing death
	# This ensures the event order is: DAMAGE → execute_on_lethal counter → DEATH → cascade reactions
	# 
	# DEATH PRIORITY: After lethal reactions complete, death is processed BEFORE cascading
	# reactions (like on_hurt heals/buffs from the counter-attack hitting another unit)
	if is_simulation and out_events != null and not _pending_reactions.is_empty():
		# Process ONLY lethal reactions (no recursive cascade)
		drain_lethal_reactions_only(0)
		# Append the lethal reaction events (counter-attack damage)
		var lethal_evts: Array[CombatEvent] = collect_inline_events()
		for evt in lethal_evts:
			out_events.append(evt)

	
	# Check player units (LINEUP and BENCH - summoned units can be on bench and die there)
	var player_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP).duplicate()
	player_units.append_array(get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_BENCH).duplicate())
	for unit in player_units:
		if unit.current_hp <= 0:
			something_changed = true
			if is_simulation and out_events != null:
				# Emit death-related triggers once during simulation so reactions can resolve
				if death_tracking != null:
					# Use unified death registry to prevent cross-phase duplicate processing
					if _register_death(unit, &"COMBAT"):
						# Track first-killed for resurrection (before triggers fire)
						var first_killed_key := "first_killed_player_unit"
						if not _turn_metadata.has(first_killed_key):
							var unit_def_fk = unit.get_definition()
							if is_instance_valid(unit_def_fk) and not unit_def_fk.is_hero:
								var loc_snapshot = get_location_for_uuid(unit.ball_uuid)
								if is_instance_valid(loc_snapshot):
									_turn_metadata[first_killed_key] = {
										"def_id": unit.definition_id,
										"team": "PLAYER",
										"location_snapshot": loc_snapshot
									}
						# on_death for the dying unit (semantic key: dying_uuid)
						# Enrich context so effects use context data, not get_instance()
						var death_location = get_location_for_uuid(unit.ball_uuid)
						var death_ctx := {
							"dying_uuid": unit.ball_uuid,
							"dying_team": "PLAYER",
							"dying_location": death_location,
							"equipped_items": _snapshot_equipped_items(unit)
						}
						AbilityResolver.process_trigger(&"on_death", death_ctx)
						
						# Check if this unit has on_hurt reactions that should complete before death
						# (counter-attacks, resilient aura buffs, etc.)
						# If so, defer DEATH event AND on_ally_death until after reactions complete
						if _has_lethal_counter_abilities(unit):
							# DEATH event and on_ally_death will be generated by _process_completed_counter_deaths()
							# after all counter-attacks and buffs have resolved
							# Store the dying unit's info for deferred on_ally_death trigger
							if not has_meta("deferred_ally_deaths_player"):
								set_meta("deferred_ally_deaths_player", [])
							var deferred_list: Array = get_meta("deferred_ally_deaths_player")
							deferred_list.append({
								"uuid": unit.ball_uuid,
								"location": death_location,
								"slot": unit.location_slot_index,
								"def_id": unit.definition_id
							})
							set_meta("deferred_ally_deaths_player", deferred_list)
						else:
							# No on_hurt reactions - generate DEATH event immediately
							# Use _create_death_event_if_needed to ensure consistent tracking
							_create_death_event_if_needed(unit.ball_uuid, out_events, death_tracking)
							
							# UNIFIED BROADCAST: Single call, AbilityResolver self-filters
							var ally_death_ctx := {
								"fainting_ally_uuid": unit.ball_uuid,
								"fainting_ally_location": death_location,
								"fainting_ally_team": "PLAYER"
							}
							AbilityResolver.process_trigger(&"on_ally_death", ally_death_ctx)
				
				# Game state cleanup is deferred - unit stays in containers for reaction targeting
				# But DEATH event may be immediate or deferred depending on on_hurt abilities
				deferred_deaths.append(unit.ball_uuid)
				
				# Legacy immediate path removed to enforce ordering
			elif not is_simulation:
				# Triggers already handled during simulation; perform cleanup only.
				_perform_unit_death_cleanup(unit)
	
	# Check enemy units (same logic - LINEUP and BENCH)
	var enemy_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).duplicate()
	enemy_units.append_array(get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_BENCH).duplicate())
	for unit in enemy_units:
		if unit.current_hp <= 0:
			var _unit_def2 = unit.get_definition()
			var _unit_name2 = tr(_unit_def2.display_name_key) if "display_name_key" in _unit_def2 else String(_unit_def2.id)
			something_changed = true
			if is_simulation and out_events != null:
				# Emit death-related triggers once during simulation so reactions can resolve
				if death_tracking != null:
					# Use unified death registry to prevent cross-phase duplicate processing
					if _register_death(unit, &"COMBAT"):
						# Track first-killed for resurrection (before triggers fire)
						var first_killed_key2 := "first_killed_enemy_unit"
						if not _turn_metadata.has(first_killed_key2):
							var unit_def_fk2 = unit.get_definition()
							if is_instance_valid(unit_def_fk2) and not unit_def_fk2.is_hero:
								var loc_snapshot2 = get_location_for_uuid(unit.ball_uuid)
								if is_instance_valid(loc_snapshot2):
									_turn_metadata[first_killed_key2] = {
										"def_id": unit.definition_id,
										"team": "ENEMY",
										"location_snapshot": loc_snapshot2
									}
						# on_death for the dying unit (semantic key: dying_uuid)
						# Enrich context so effects use context data, not get_instance()
						var death_location2 = get_location_for_uuid(unit.ball_uuid)
						var death_ctx2 := {
							"dying_uuid": unit.ball_uuid,
							"dying_team": "ENEMY",
							"dying_location": death_location2,
							"equipped_items": _snapshot_equipped_items(unit)
						}
						AbilityResolver.process_trigger(&"on_death", death_ctx2)
						
						# Check if this unit has on_hurt reactions that should complete before death
						# (counter-attacks, resilient aura buffs, etc.)
						# If so, defer DEATH event AND on_ally_death until after reactions complete
						if _has_lethal_counter_abilities(unit):
							# DEATH event and on_ally_death will be generated by _process_completed_counter_deaths()
							# after all counter-attacks and buffs have resolved
							# Store the dying unit's info for deferred on_ally_death trigger
							if not has_meta("deferred_ally_deaths_enemy"):
								set_meta("deferred_ally_deaths_enemy", [])
							var deferred_list2: Array = get_meta("deferred_ally_deaths_enemy")
							deferred_list2.append({
								"uuid": unit.ball_uuid,
								"location": death_location2,
								"slot": unit.location_slot_index,
								"def_id": unit.definition_id
							})
							set_meta("deferred_ally_deaths_enemy", deferred_list2)
						else:
							# No on_hurt reactions - generate DEATH event immediately
							# Use _create_death_event_if_needed to ensure consistent tracking
							_create_death_event_if_needed(unit.ball_uuid, out_events, death_tracking)
							
							# UNIFIED BROADCAST: Single call, AbilityResolver self-filters
							var ally_death_ctx2 := {
								"fainting_ally_uuid": unit.ball_uuid,
								"fainting_ally_location": death_location2,
								"fainting_ally_team": "ENEMY"
							}
							AbilityResolver.process_trigger(&"on_ally_death", ally_death_ctx2)
				
				# Game state cleanup is deferred - unit stays in containers for reaction targeting
				# But DEATH event may be immediate or deferred depending on on_hurt abilities
				deferred_deaths.append(unit.ball_uuid)
				
				# Legacy immediate path removed to enforce ordering
			elif not is_simulation:
				# Triggers already handled during simulation; perform cleanup only.
				_perform_unit_death_cleanup(unit)
	
	# Store deferred deaths for processing after their counter-attacks complete
	if not deferred_deaths.is_empty():
		# Store current deferred deaths, merging with any existing ones
		var existing_deferred: Array = get_meta("deferred_deaths", [])
		existing_deferred.append_array(deferred_deaths)
		set_meta("deferred_deaths", existing_deferred)
	
	# DEATH PRIORITY: Now drain any remaining cascading reactions from lethal abilities
	# These are reactions like on_hurt heals/buffs from counter-attacks hitting other units
	# They were left in _pending_reactions by drain_lethal_reactions_only()
	if is_simulation and out_events != null and not _pending_reactions.is_empty():
		drain_pending_reactions_inline(0)
		var cascade_evts: Array[CombatEvent] = collect_inline_events()
		for evt in cascade_evts:
			out_events.append(evt)
	
	if something_changed and not is_simulation:
		_emit_battle_inventory_changed()


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
	if not has_meta("deferred_deaths"):
		return
	
	var deferred_deaths: Array = get_meta("deferred_deaths")
	var remaining_deferred: Array = []
	
	
	for uuid in deferred_deaths:
		var unit = get_instance_by_uuid(uuid)
		if not is_instance_valid(unit):
			continue
		
		var _unit_def = unit.get_definition()
		var _unit_name = tr(_unit_def.display_name_key) if "display_name_key" in _unit_def else String(_unit_def.id)
			
		# Check if this unit still has ANY pending reactions (counters, on_death, etc.)
		var has_pending_counters = false
		for request in _pending_reactions:
			if request.source_uuid == uuid:
				has_pending_counters = true
				break
		
		# If no pending counter-attacks, this unit can die now
		if not has_pending_counters:
			if out_events != null and death_tracking != null:
				_create_death_event_if_needed(uuid, out_events, death_tracking)
			
			# Process deferred on_ally_death triggers for this unit
			# These were stored when the death was detected but counter-attacks were pending
			_process_deferred_ally_death(uuid, "PLAYER")
			_process_deferred_ally_death(uuid, "ENEMY")
			
			# CRITICAL FIX: Actually clean up the unit from the game state
			# Without this, units stay in lineup with HP<=0 and die again on next turn
			_perform_unit_death_cleanup(unit)
		else:
			# Still has pending counter-attacks, keep deferred
			remaining_deferred.append(uuid)
	
	# Update the deferred deaths list
	if remaining_deferred.is_empty():
		remove_meta("deferred_deaths")
	else:
		set_meta("deferred_deaths", remaining_deferred)

## Helper function to process deferred on_ally_death triggers after counter-attacks resolve
func _process_deferred_ally_death(dying_uuid: String, team: String) -> void:
	var meta_key = "deferred_ally_deaths_player" if team == "PLAYER" else "deferred_ally_deaths_enemy"
	if not has_meta(meta_key):
		return
	
	var deferred_list: Array = get_meta(meta_key)
	var remaining_list: Array = []
	
	for entry in deferred_list:
		if entry.uuid != dying_uuid:
			remaining_list.append(entry)
			continue
		
		# This dying unit's on_ally_death triggers can now fire
		var death_location = entry.location
		
		# UNIFIED BROADCAST: Single call, AbilityResolver self-filters
		var ally_death_ctx := {
			"fainting_ally_uuid": dying_uuid,
			"fainting_ally_location": death_location,
			"fainting_ally_team": team
		}
		AbilityResolver.process_trigger(&"on_ally_death", ally_death_ctx)
	
	# Update the deferred list
	if remaining_list.is_empty():
		remove_meta(meta_key)
	else:
		set_meta(meta_key, remaining_list)

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
	var _player_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var _enemy_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	if _current_battle_phase == Phases.COMBAT and _is_battle_over():
		_battle_over_deferred = true

func _is_battle_over() -> bool:
	var player_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var enemy_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	
	# Check if any hero died - immediate defeat
	for unit in player_lineup:
		var def = unit.get_definition()
		if is_instance_valid(def) and def.is_hero and unit.current_hp <= 0:
			return true # Hero died = defeat
	
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
	
	# Battle is over if either side has no living units
	return not player_has_alive or not enemy_has_alive

func _emit_battle_over() -> void:
	# Transition to BATTLE_OVER and emit results once animations are finished.
	_current_battle_phase = Phases.BATTLE_OVER
	if not _battle_over_emitted:
		_battle_over_emitted = true
		SignalBus.emit_signal("battle_phase_changed", get_current_phase_name())
		
		# Determine victory/defeat - hero death = defeat even if other player units alive
		var player_won := true
		var player_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
		
		# Check if any hero died - immediate defeat
		for unit in player_lineup:
			var def = unit.get_definition()
			if is_instance_valid(def) and def.is_hero and unit.current_hp <= 0:
				player_won = false
				break
		
		# If no hero died, check if any player units are alive
		if player_won:
			var any_player_alive := false
			for unit in player_lineup:
				if unit.current_hp > 0:
					any_player_alive = true
					break
			player_won = any_player_alive
		
		var results: Dictionary = {"victory": player_won}
		SignalBus.emit_signal("battle_ended", results)
		if player_won:
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
	return TargetResolver.resolve_target(source_uuid, target_type, context, self)

## Check if a condition is met for an ability.
## @param condition_def: ConditionDefinition - The condition to check
## @param source_uuid: String - The UUID of the source instance
## @param context: Dictionary - The context of the event
## @return bool - True if condition is met
func check_condition(condition_def: ConditionDefinition, source_uuid: String, context: Dictionary) -> bool:
	return TargetResolver.check_condition(condition_def, source_uuid, context, self)


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

## Drain pending reactions inline during effect execution.
## Used by BasicAttackEffect to process on_before_attack defensive abilities
## BEFORE damage is calculated. This ensures Defensive Stance HP boost happens first.
## Events are stored in _inline_events for the outer loop to collect.
## @param start_index: int - Only process reactions at index >= start_index (reactions added after this point)
func drain_pending_reactions_inline(start_index: int) -> void:
	# Only process reactions that were added AFTER start_index
	# This prevents processing unrelated reactions (like on_ally_death) that were already queued
	if start_index >= _pending_reactions.size():
		return # No new reactions to process
	
	# Extract only the new reactions (from start_index to end)
	var reactions_to_process: Array[EffectRequest] = []
	for i in range(start_index, _pending_reactions.size()):
		reactions_to_process.append(_pending_reactions[i])
	
	# Remove them from the main queue to process them locally
	_pending_reactions.resize(start_index)
	
	# Sort by priority before processing
	reactions_to_process.sort_custom(func(a, b): return a.priority > b.priority)
	
	for request in reactions_to_process:
		# Capture events to _inline_events so they can be collected by the outer loop
		# IMPORTANT: Pass a special death_tracking that disables death checking
		# The outer loop will handle death checking properly - we're only processing pre-attack heals here
		# which don't cause deaths, and any existing dead units were already processed
		_resolve_single_effect_request(request, _inline_events, {"__skip_death_triggers__": true})
		
		# RECURSIVE PROCESSING: If this effect triggered new reactions (e.g., retaliation damage
		# triggering on_damage_dealt for lifesteal), process them immediately so heals appear
		# right after the damage that caused them, not batched at the end
		if not _pending_reactions.is_empty():
			drain_pending_reactions_inline(0)

## Collect any events generated during inline reaction processing (e.g., on_before_attack)
## Called by the outer resolution loop to insert these before damage events.
func collect_inline_events() -> Array[CombatEvent]:
	var events = _inline_events.duplicate()
	_inline_events.clear()
	return events

## Drain ONLY execute_on_lethal reactions WITHOUT recursive cascade processing.
## This ensures death is processed BEFORE cascading reactions from the lethal ability.
## 
## Event ordering after this fix:
## 1. Lethal damage dealt → unit HP <= 0
## 2. execute_on_lethal ability (counter-attack) triggers → DAMAGE event
## 3. DEATH event is created (by caller after this returns)
## 4. Remaining cascading reactions (on_hurt from counter) process later
##
## @param start_index: int - Only process reactions at index >= start_index
func drain_lethal_reactions_only(start_index: int) -> void:
	if start_index >= _pending_reactions.size():
		return # No reactions to process
	
	# Extract reactions from start_index to end
	var reactions_to_process: Array[EffectRequest] = []
	for i in range(start_index, _pending_reactions.size()):
		reactions_to_process.append(_pending_reactions[i])
	
	# Clear the processed range
	_pending_reactions.resize(start_index)
	
	# Sort by priority
	reactions_to_process.sort_custom(func(a, b): return a.priority > b.priority)
	
	# Process ONLY these reactions - do NOT recursively drain new ones
	# Any new reactions (cascading from these) will remain in _pending_reactions
	# and be processed AFTER death by the caller
	for request in reactions_to_process:
		_resolve_single_effect_request(request, _inline_events, {"__skip_death_triggers__": true})
		# NOTE: We intentionally do NOT call drain_pending_reactions_inline(0) here
		# This leaves cascading reactions in the queue for post-death processing


## Get an instance by UUID.
## @param uuid: String - The UUID of the instance
## @return GachaBallInstance - The instance, or null if not found
func get_instance_by_uuid(uuid: String) -> GachaBallInstance:
	return _battle_instances.get(uuid, null)

## Get the Hero's UUID (player's unit at slot 0, or first available player unit).
func get_hero_uuid() -> String:
	var player_lineup = get_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
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
	
	# Check unit's own abilities
	for ability in source.abilities:
		if ability.id == ability_id:
			return ability
	
	# Check equipped items' abilities
	for item_uuid in source.equipped_item_uuids:
		if item_uuid.is_empty():
			continue
		var item_inst = get_instance_by_uuid(item_uuid)
		if not is_instance_valid(item_inst):
			continue
		for ability in item_inst.abilities:
			if ability.id == ability_id:
				return ability
	
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
func apply_stat_delta(instance: GachaBallInstance, stat_type: String, delta: int) -> Variant:
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
			var new_hp = instance.current_hp + delta
			instance.set_current_hp_silent(new_hp) # Silent during simulation
			return new_hp
		"pwr":
			var new_pwr = instance.current_pwr + delta
			instance.set_current_pwr_silent(new_pwr) # Silent during simulation
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

func trigger_on_hurt(target_uuid: String, damage_amount: int, attacker_uuid: String, cause: StringName = C.CAUSE_ATTACK) -> void:
	# Get target instance data for context (effects should not query instances directly)
	var target_instance = get_instance_by_uuid(target_uuid)
	var victim_team := ""
	var victim_current_hp := 0
	if is_instance_valid(target_instance):
		victim_current_hp = target_instance.current_hp
		if target_instance.location_container_tag == BATTLE_CONTAINER_TAGS.PLAYER_LINEUP:
			victim_team = "PLAYER"
		elif target_instance.location_container_tag == BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
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


## Trigger on_kill event for a unit that killed another unit.
## @param killer_uuid: String - The UUID of the unit that got the kill
## @param killed_uuid: String - The UUID of the unit that was killed
func trigger_on_kill(killer_uuid: String, killed_uuid: String) -> void:
	TurnAbilities.trigger_on_kill(killer_uuid, killed_uuid)

## Trigger on_battle_start abilities for all units.
func _trigger_battle_start_abilities() -> void:
	TurnAbilities.trigger_battle_start_abilities(_state)

## Trigger on_turn_start abilities for all units and trinkets.
func _trigger_turn_start_abilities() -> void:
	if _turn_start_abilities_triggered:
		return
		
	_turn_start_abilities_triggered = true # Set flag here to prevent multiple calls
	
	# Trigger turn start abilities for all instances using unified processing
	var turn_start_context: Dictionary = {"turn": _current_turn}
	AbilityResolver.process_trigger(&"on_turn_start", turn_start_context)
	
	# Process turn start effects (heals, etc.) without starting combat
	# Don't populate actor queue - we're just processing turn start abilities
	if not _pending_reactions.is_empty():
		_resolve_pending_reactions_only()
	else:
		# No turn start abilities to process - transition to MANAGEMENT directly
		_on_turn_animation_finished()


## Process pending reactions without populating the actor queue
## Used for turn start abilities that shouldn't trigger combat
func _resolve_pending_reactions_only() -> void:
	if _is_processing_effect: return
	_is_processing_effect = true
	_resolve_animator()
	
	# Process only pending reactions (turn start abilities), don't populate actor queue
	var all_events_for_animator: Array[CombatEvent] = []
	var death_tracking: Dictionary = {}
	
	# Capture board snapshot BEFORE simulation
	var start_snapshot = get_board_snapshot()
	
	# Process all pending reactions (turn start abilities)
	while not _pending_reactions.is_empty():
		var request: EffectRequest = _pending_reactions.pop_front()
		var reaction_events: Array[CombatEvent] = []
		_resolve_single_effect_request(request, reaction_events, death_tracking)
		all_events_for_animator.append_array(reaction_events)
	
	# Clean up deferred enemy instances AFTER all reactions have resolved
	_flush_deferred_enemy_erasures()
	
	_is_processing_effect = false
	if not all_events_for_animator.is_empty():
		_animator.play_turn_sequence(start_snapshot, all_events_for_animator)
	else:
		_on_turn_animation_finished()

## Flush deferred enemy instance erasures. Called after all reactions have resolved.
## This ensures enemy units and items are still available in _battle_instances while
## their on_death abilities are being processed.
func _flush_deferred_enemy_erasures() -> void:
	if not has_meta("_deferred_enemy_erasures"):
		return
	var erasure_list: Array = get_meta("_deferred_enemy_erasures")
	for uuid in erasure_list:
		if _battle_instances.has(uuid):
			_battle_instances.erase(uuid)
	remove_meta("_deferred_enemy_erasures")

## Trigger on_turn_end abilities for all units.
func _trigger_turn_end_abilities() -> void:
	# print("DEBUG: _trigger_turn_end_abilities called")
	var all_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP) + get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	var all_events: Array[CombatEvent] = []
	var death_tracking: Dictionary = {}
	
	# Capture board snapshot for animation
	var start_snapshot = get_board_snapshot()
	
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
	while not _pending_reactions.is_empty():
		var request: EffectRequest = _pending_reactions.pop_front()
		var reaction_events: Array[CombatEvent] = []
		_resolve_single_effect_request(request, reaction_events, death_tracking)
		all_events.append_array(reaction_events)
	
	# 4. Play animations or finish immediately
	if not all_events.is_empty():
		_is_processing_effect = true
		_resolve_animator()
		_animator.play_turn_sequence(start_snapshot, all_events)
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
			var new_hp = apply_stat_delta(unit, "hp", -damage)
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
					"targets_max_hp": [max_hp]
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
		match status_def.decay_mode:
			"HALVE":
				new_stacks = int(floor(stacks / 2.0))
			"DECREMENT":
				new_stacks = stacks - status_def.decay_amount
			"CLEAR":
				new_stacks = 0
		
		if new_stacks != old_stacks:
			if new_stacks <= 0:
				unit.clear_status_effect(status_def.id)
				new_stacks = 0
			else:
				var decay_delta: int = new_stacks - old_stacks
				apply_stat_delta(unit, String(status_def.id) + "_stacks", decay_delta)
			
			# Emit BUFF event for status decay so animator updates the visual
			all_events.append(CombatEvent.new(CombatEvent.Type.BUFF, {
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
			if not _register_death(unit, &"END_OF_TURN"):
				continue
			
			_create_death_event_if_needed(unit.ball_uuid, all_events, death_tracking)
			
			var is_player: bool = _is_player_unit(unit)
			var first_killed_key := "first_killed_player_unit" if is_player else "first_killed_enemy_unit"
			if not _turn_metadata.has(first_killed_key):
				var unit_def_fk = unit.get_definition()
				if is_instance_valid(unit_def_fk) and not unit_def_fk.is_hero:
					var loc_snapshot = get_location_for_uuid(unit.ball_uuid)
					if is_instance_valid(loc_snapshot):
						_turn_metadata[first_killed_key] = {
							"def_id": unit.definition_id,
							"team": "PLAYER" if is_player else "ENEMY",
							"location_snapshot": loc_snapshot
						}
			
			var death_location = get_location_for_uuid(unit.ball_uuid)
			var death_team: String = "PLAYER" if is_player else "ENEMY"
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
			
			while not _pending_reactions.is_empty():
				_pending_reactions.sort_custom(func(a, b): return a.priority > b.priority)
				var death_reaction = _pending_reactions.pop_front()
				var death_reaction_events: Array[CombatEvent] = []
				_resolve_single_effect_request(death_reaction, death_reaction_events, death_tracking)
				all_events.append_array(death_reaction_events)

func _reshuffle_discard_pile(tier_to_reshuffle: int) -> void:
	# Delegate to BattleState's authoritative reshuffle logic
	_state.reshuffle_tier_from_discard(tier_to_reshuffle)


## Handle armor_stacks stat changes for trinket abilities
## Applies armor stacks to targets and returns a BUFF event for visual feedback
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
	
	return CombatEvent.new(CombatEvent.Type.BUFF, {
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
	var target_lineup_tag = BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if attacker_is_player else BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
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
		_change_phase(Phases.COMBAT)
		call_deferred("_resolve_combat_phase")
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
	# Force close any lingering FlashcardMinigame window to prevent freeze.
	# This acts as a failsafe if WindowManager.open_modal_window() fails to close it.
	var minigame = get_tree().get_root().find_child("FlashcardMinigame", true, false)
	if is_instance_valid(minigame):
		minigame.queue_free()

	_last_minigame_results = results

	var correct_answers: int = results.get("correct_answers", 0)
	var gacha_gain = 5 + correct_answers # TDD: gacha_gain = 5 (base) + results.correct_answers
	
	# Display ResultsPopup
	WindowManager.open_modal_window(&"ResultsPopup", {
		"populate_args": ["Turn Start!", "You earned %d Gacha Tokens." % correct_answers, "Okay"]
	})

func _on_results_acknowledged() -> void:
	"""Called when player acknowledges the results popup"""
	
	var correct_answers: int = _last_minigame_results.get("correct_answers", 0)
	var gacha_gain = correct_answers
	
	_gacha_tokens += gacha_gain
	SignalBus.emit_signal("gacha_tokens_changed", _gacha_tokens)

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
	var container_tag = BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS if is_player_team else BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS
	var trinkets = get_instances_in_container(container_tag)
	for trinket in trinkets:
		if trinket.definition_id == trinket_id:
			return true
	return false

## Find a unit with the intercept_lethal tag on the specified team.
## Returns the unit with highest HP, or null if none available.
## This enables any unit with the tag to protect allies, not just Guardian Sentinel.
func _find_guardian_on_team(is_player_team: bool, exclude_uuid: String) -> GachaBallInstance:
	return BattleHelpers.find_interceptor_on_team(_state, is_player_team, exclude_uuid)

func _finalize_deaths() -> void:
	# Removes units with <= 0 HP from containers and discard, WITHOUT triggering abilities.
	# This is called after VCR playback to synchronize logical state with visual state.
	var all_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP) + get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	var something_changed = false
	
	for unit in all_units:
		if unit.current_hp <= 0 and is_dead_this_turn(unit.ball_uuid):
			something_changed = true
			# Use unified cleanup logic which handles:
			# 1. Item cleanup (move to discard or destroy)
			# 2. Stat reset (for player units) - CRITICAL FIX
			# 3. Unit removal/move to discard
			_perform_unit_death_cleanup(unit)
	
	if something_changed:
		_emit_battle_inventory_changed()

# =============================================================================
# TEST MODE HELPERS
# These functions ensure test mode uses the same initialization paths as real battles.
# =============================================================================

## Register a unit for test mode using the same logic as _setup_enemy_lineup().
## Guarantees 100% parity with real battle initialization.
## @param unit_def_id: StringName - The ID of the unit definition
## @param is_enemy: bool - True for enemy team, false for player team
## @param position: int - Slot position (0-4), or -1 for auto-placement
## @return GachaBallInstance - The created instance, or null on failure
func register_test_unit(unit_def_id: StringName, is_enemy: bool, position: int = -1) -> GachaBallInstance:
	var unit_def = Database.get_definition(unit_def_id)
	if not is_instance_valid(unit_def):
		push_warning("[TestMode] Unit definition not found: %s" % unit_def_id)
		return null
	
	var container_tag = BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if is_enemy else BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	var lineup_container: DataContainer = get_container(container_tag)
	
	# Find position if not specified
	var slot := position
	if slot < 0:
		slot = lineup_container.find_first_empty_slot()
		if slot == -1:
			push_warning("[TestMode] No empty slots in lineup")
			return null
	
	# Create instance EXACTLY like _setup_enemy_lineup does
	var unit_inst = GachaBallInstance.new()
	unit_inst.initialize(unit_def)
	_battle_instances[unit_inst.ball_uuid] = unit_inst
	
	# Place in container EXACTLY like _setup_enemy_lineup does
	lineup_container.set_uuid(slot, unit_inst.ball_uuid)
	_update_instance_location(unit_inst.ball_uuid, container_tag, slot)
	
	print("[TestMode] Registered unit: %s at %s slot %d" % [unit_def_id, container_tag, slot])
	return unit_inst

## Equip an item on a unit using the same logic as real battles.
## Uses _perform_equip() to guarantee parity.
## @param item_def_id: StringName - The ID of the item definition
## @param unit_uuid: String - UUID of the unit to equip on
## @return GachaBallInstance - The created item instance, or null on failure
func register_test_item_on_unit(item_def_id: StringName, unit_uuid: String) -> GachaBallInstance:
	var item_def = Database.get_definition(item_def_id)
	if not is_instance_valid(item_def):
		push_warning("[TestMode] Item definition not found: %s" % item_def_id)
		return null
	
	var unit = get_instance(unit_uuid)
	if not is_instance_valid(unit):
		push_warning("[TestMode] Unit not found: %s" % unit_uuid)
		return null
	
	# Check for empty equipment slot
	if not unit.equipped_item_uuids.has(""):
		push_warning("[TestMode] Unit %s has no empty equipment slots" % unit_uuid)
		return null
	
	# Create and equip item EXACTLY like _setup_enemy_lineup does
	var item_inst = GachaBallInstance.new()
	item_inst.initialize(item_def)
	_battle_instances[item_inst.ball_uuid] = item_inst
	
	# Use existing _perform_equip for proper stat application
	_perform_equip(item_inst, unit)
	
	print("[TestMode] Equipped item: %s on unit: %s" % [item_def_id, unit_uuid])
	return item_inst

## Register a trinket for test mode using the same logic as _setup_enemy_trinkets_from_encounter().
## @param trinket_def_id: StringName - The ID of the trinket definition
## @param is_enemy: bool - True for enemy team, false for player team
## @return GachaBallInstance - The created instance, or null on failure
func register_test_trinket(trinket_def_id: StringName, is_enemy: bool) -> GachaBallInstance:
	var trinket_def = Database.get_definition(trinket_def_id)
	if not is_instance_valid(trinket_def):
		push_warning("[TestMode] Trinket definition not found: %s" % trinket_def_id)
		return null
	
	var container_tag = BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS if is_enemy else BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS
	var trinket_container: DataContainer = get_container(container_tag)
	
	# Find empty slot
	var slot := trinket_container.find_first_empty_slot()
	if slot == -1:
		push_warning("[TestMode] No empty trinket slots for team: %s" % ("enemy" if is_enemy else "player"))
		return null
	
	# Create instance EXACTLY like _setup_enemy_trinkets_from_encounter does
	var trinket_inst = GachaBallInstance.new()
	trinket_inst.initialize_from_trinket(trinket_def)
	_battle_instances[trinket_inst.ball_uuid] = trinket_inst
	
	# Place in container
	trinket_container.set_uuid(slot, trinket_inst.ball_uuid)
	_update_instance_location(trinket_inst.ball_uuid, container_tag, slot)
	
	# For enemy trinkets, also add to legacy array
	if is_enemy:
		enemy_trinkets.append(trinket_inst)
	
	print("[TestMode] Registered trinket: %s for %s at slot %d" % [trinket_def_id, "enemy" if is_enemy else "player", slot])
	return trinket_inst

## Trigger on_battle_start abilities for all units currently on the board.
## Call this after setting up your test entities.
func trigger_test_battle_start() -> void:
	print("[TestMode] Triggering on_battle_start for all units...")
	_trigger_battle_start_abilities()
	call_deferred("_emit_stats_changed_for_equipped_units")
	_emit_battle_inventory_changed()
	print("[TestMode] Battle start trigger complete")

## Clear all entities for a specific team. Used to reset before re-applying test setup.
## @param is_enemy: bool - True to clear enemy team, false to clear player team
func clear_test_team(is_enemy: bool) -> void:
	if is_enemy:
		# Clear enemy lineup
		var enemy_container = get_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
		for i in range(5):
			var uuid = enemy_container.get_uuid(i)
			if not uuid.is_empty():
				var inst = get_instance(uuid)
				if is_instance_valid(inst):
					# Remove equipped items from registry
					for item_uuid in inst.equipped_item_uuids:
						if not item_uuid.is_empty():
							_battle_instances.erase(item_uuid)
					_battle_instances.erase(uuid)
				enemy_container.set_uuid(i, "")
		
		# Clear enemy trinkets
		enemy_trinkets.clear()
		var trinket_container = get_container(BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS)
		for i in range(5):
			var uuid = trinket_container.get_uuid(i)
			if not uuid.is_empty():
				_battle_instances.erase(uuid)
				trinket_container.set_uuid(i, "")
		
		print("[TestMode] Cleared enemy team")
	else:
		# Clear player lineup (excluding hero at position 0)
		var player_container = get_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
		for i in range(1, 5): # Skip hero at position 0
			var uuid = player_container.get_uuid(i)
			if not uuid.is_empty():
				var inst = get_instance(uuid)
				if is_instance_valid(inst):
					for item_uuid in inst.equipped_item_uuids:
						if not item_uuid.is_empty():
							_battle_instances.erase(item_uuid)
					_battle_instances.erase(uuid)
				player_container.set_uuid(i, "")
		
		# Clear player trinkets
		var trinket_container = get_container(BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS)
		for i in range(5):
			var uuid = trinket_container.get_uuid(i)
			if not uuid.is_empty():
				_battle_instances.erase(uuid)
				trinket_container.set_uuid(i, "")
		
		print("[TestMode] Cleared player team (kept hero)")
	
	_emit_battle_inventory_changed()
