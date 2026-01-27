# res://scripts/battle/EffectHandlers.gd
class_name EffectHandlers
extends RefCounted

## EffectHandlers contains specialized handlers for different effect types.
## This breaks down the monolithic _resolve_single_effect_request into focused methods.

const BM = preload("res://scripts/BattleManager.gd")
const C = preload("res://scripts/Constants.gd")

# ============================================================================
# CONTEXT TYPES
# ============================================================================

## EffectContext holds all data needed to process an effect
class EffectContext:
	var request: EffectRequest
	var source: GachaBallInstance
	var effect_data: Dictionary
	var out_events: Array[CombatEvent]
	var death_tracking: Dictionary
	var state: BattleState
	var is_player_source: bool
	
	func _init(
		p_request: EffectRequest,
		p_source: GachaBallInstance,
		p_effect_data: Dictionary,
		p_out_events: Array[CombatEvent],
		p_death_tracking: Dictionary,
		p_state: BattleState,
		p_is_player_source: bool
	):
		request = p_request
		source = p_source
		effect_data = p_effect_data
		out_events = p_out_events
		death_tracking = p_death_tracking
		state = p_state
		is_player_source = p_is_player_source

# ============================================================================
# HANDLER DISPATCH
# ============================================================================

## Determine which handler should process this effect
static func get_handler_type(effect_data: Dictionary) -> StringName:
	if effect_data.has("cascade_damage"):
		return &"cascade_damage"
	if effect_data.has("extra_action"):
		return &"extra_action"
	if effect_data.has("summon_unit_id"):
		return &"summon_unit"
	if effect_data.has("summon_units"):
		return &"summon_units"
	if effect_data.has("multi_heal") and effect_data.get("multi_heal", false):
		return &"multi_heal"
	if effect_data.has("multi_buff") and effect_data.get("multi_buff", false):
		return &"multi_buff"
	if effect_data.has("stat"):
		return &"stat_change"
	return &"unknown"

# ============================================================================
# EXTRA ACTION HANDLER
# ============================================================================

## Handle granting an extra action to a unit
static func handle_extra_action(ctx: EffectContext, battle_manager: Node) -> void:
	var unit_uuid := String(ctx.effect_data.get("unit_uuid", ""))
	var unit := ctx.state.get_instance(unit_uuid)
	if not is_instance_valid(unit):
		return
	if unit.current_hp <= 0:
		return
	
	# Grant extra action via BattleManager
	battle_manager.grant_extra_action(unit_uuid)
	
	# Get display names for log
	var unit_name := BattleHelpers.get_instance_display_name(unit)
	var source_name := ""
	if not String(ctx.request.source_uuid).is_empty():
		var src_inst := ctx.state.get_instance(ctx.request.source_uuid)
		source_name = BattleHelpers.get_instance_display_name(src_inst)
	if source_name == "":
		source_name = String(ctx.request.ability_id)
	
	ctx.out_events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "%s grants extra action to %s" % [source_name, unit_name]
	}))

# ============================================================================
# SUMMON HELPERS
# ============================================================================

## Find the first empty slot in a container
static func find_empty_slot_in_container(container: DataContainer) -> int:
	if not is_instance_valid(container):
		return -1
	return container.find_first_empty_slot()

## Create a summon event
static func create_summon_event(unit_uuid: String, slot_index: int, is_player: bool) -> CombatEvent:
	return CombatEvent.new(CombatEvent.Type.SUMMON, {
		"target_uuids": [unit_uuid],
		"visual_payload": {
			"slot_index": slot_index,
			"is_player": is_player
		}
	})

# ============================================================================
# STAT CHANGE HELPERS
# ============================================================================

## Determine bump direction for damage animations
static func get_bump_direction(source_tag: StringName) -> Vector2:
	if source_tag == &"PlayerLineup" or source_tag == &"PlayerBench":
		return Vector2(1, 0) # Player bumps right
	elif source_tag == &"EnemyLineup" or source_tag == &"EnemyBench":
		return Vector2(-1, 0) # Enemy bumps left
	return Vector2.ZERO

## Get animation source UUID (item uses holder for animation)
static func get_animation_source_uuid(source: GachaBallInstance, _state: BattleState) -> String:
	if not is_instance_valid(source):
		return ""
	
	var source_def := source.get_definition()
	if is_instance_valid(source_def) and source_def.category == &"ITEM":
		if not source.equipped_on_uuid.is_empty():
			return source.equipped_on_uuid
	
	return source.ball_uuid

# ============================================================================
# BURN STACKS HANDLER
# ============================================================================

## Handle burn_stacks stat changes
## Returns a CombatEvent for the burn buff
static func handle_burn_stacks(
	request: EffectRequest,
	resolved_targets: Array[String],
	amount: int,
	battle_manager: Node
) -> CombatEvent:
	var targets_old_val: Array[int] = []
	var targets_new_val: Array[int] = []
	
	for target_uuid in resolved_targets:
		var tgt: GachaBallInstance = battle_manager.get_instance_by_uuid(target_uuid)
		if is_instance_valid(tgt):
			targets_old_val.append(tgt.get_status_effect_amount(&"burn"))
			var new_v = battle_manager.apply_stat_delta(tgt, "burn_stacks", amount)
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
			"stat": "burn_stacks",
			"targets_old_val": targets_old_val,
			"targets_new_val": targets_new_val
		}
	})

# ============================================================================
# DAMAGE RESULT CLASS
# ============================================================================

## Result returned from handle_damage_effect containing events and trigger data
class DamageResult:
	var events: Array[CombatEvent] = []
	var damaged_uuids: Array[String] = [] # For trigger_on_hurt/on_kill callbacks
	var should_return: bool = false # If true, BattleManager should return early
	
	func _init():
		pass

# ============================================================================
# DAMAGE EFFECT HANDLER
# ============================================================================

## Container tags for battle validation - use C.BATTLE_CONTAINER_TAGS

## Handle damage effects (amount < 0)
## Returns DamageResult with events and damaged_uuids for trigger callbacks
static func handle_damage_effect(
	request: EffectRequest,
	resolved_targets: Array[String],
	source: GachaBallInstance,
	source_name: String,
	target_names: Array[String],
	amount: int,
	skip_bump: bool,
	battle_manager: Node
) -> DamageResult:
	var result := DamageResult.new()
	
	# Log message
	var dealt: int = abs(amount)
	var damage_target_name := ""
	if not target_names.is_empty():
		damage_target_name = target_names[0]
	if source_name != "" and damage_target_name != "":
		result.events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": "%s deals %d dmg to %s" % [source_name, dealt, damage_target_name]}))
	
	# Check if burn should be applied
	# Check if burn should be applied (Trinket + Fire Trait)
	var is_player_source := false
	var burn_amount := 0
	
	if is_instance_valid(source):
		is_player_source = battle_manager._is_player_unit(source)
	elif request.trigger_context.has("team"):
		is_player_source = (String(request.trigger_context.get("team")) == "PLAYER")
	
	# 1. Trinket: Burn Vial (Team-wide)
	if battle_manager._has_team_trinket(is_player_source, &"trinket_burn_vial"):
		burn_amount += 1
		
	# 2. Fire Trait: 3+ Souls -> Fire units apply Burn
	var active_traits = battle_manager.get_active_traits("PLAYER" if is_player_source else "ENEMY")
	if active_traits.get("FIRE", 0) >= 3:
		# Check if source is a Fire unit
		if is_instance_valid(source) and battle_manager._has_trait_soul(source, "FIRE"):
			burn_amount += 1
			
	var should_apply_burn = burn_amount > 0
	
	# Apply HP delta and capture old/new values
	var targets_old_hp: Array[int] = []
	var targets_new_hp: Array[int] = []
	var targets_max_hp: Array[int] = []
	var targets_old_burn: Array[int] = []
	var targets_new_burn: Array[int] = []
	var original_target_uuids: Array[String] = []
	
	# Track armor consumption for visualization (grey popup + countdown)
	var targets_old_armor: Array[int] = []
	var targets_new_armor: Array[int] = []
	var armor_consumed_list: Array[int] = []
	
	for tgt_uuid in resolved_targets:
		var tgt: GachaBallInstance = battle_manager.get_instance_by_uuid(tgt_uuid)
		# Skip already-dead or removed targets
		if not is_instance_valid(tgt) or tgt.current_hp <= 0:
			continue
		var loc_tag: StringName = tgt.location_container_tag
		var is_in_battle: bool = (loc_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or loc_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP or
								  loc_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH or loc_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_BENCH)
		if not is_in_battle:
			continue
		
		# GUARDIAN SENTINEL INTERCEPT CHECK
		var original_tgt_uuid = tgt_uuid
		var actual_damage = abs(amount)
		var would_be_lethal = tgt.current_hp - actual_damage <= 0
		var tgt_is_player_unit = battle_manager._is_player_unit(tgt)
		var is_ally_damage = (tgt_is_player_unit != is_player_source)
		
		if would_be_lethal and is_ally_damage:
			var guardian: GachaBallInstance = battle_manager._find_guardian_on_team(tgt_is_player_unit, tgt_uuid)
			if is_instance_valid(guardian):
				result.events.append(CombatEvent.new(CombatEvent.Type.GUARDIAN_INTERCEPT, {
					"source_uuid": guardian.ball_uuid,
					"target_uuids": [tgt_uuid],
					"visual_payload": {
						"guardian_uuid": guardian.ball_uuid,
						"original_target_uuid": tgt_uuid,
						"damage": actual_damage
					}
				}))
				tgt_uuid = guardian.ball_uuid
				tgt = guardian
		
		original_target_uuids.append(original_tgt_uuid)
		targets_old_hp.append(tgt.current_hp)
		targets_old_burn.append(tgt.get_status_effect_amount(&"burn"))
		
		# Capture old armor BEFORE apply_stat_delta modifies it
		var old_armor = tgt.get_status_effect_amount(&"armor")
		targets_old_armor.append(old_armor)
		
		# CENTRALIZED ARMOR: apply_stat_delta now handles armor mitigation automatically
		# It returns a dictionary with armor data for animations
		var damage_result = battle_manager.apply_stat_delta(tgt, "hp", amount) # amount is negative
		
		# Skip if target was already dead
		if damage_result == null:
			continue
		
		# Extract data from the damage result dictionary
		var new_hp: int = damage_result.get("new_hp", tgt.current_hp)
		var armor_consumed: int = damage_result.get("armor_consumed", 0)
		var new_armor: int = damage_result.get("new_armor", 0)
		var hp_damage: int = damage_result.get("hp_damage", 0)
		
		armor_consumed_list.append(armor_consumed)
		targets_new_armor.append(new_armor)
		targets_new_hp.append(new_hp)
		
		# Add to damaged_uuids if HP or armor was affected
		if hp_damage > 0 or armor_consumed > 0:
			result.damaged_uuids.append(tgt_uuid)
		
		var tgt_def := tgt.get_definition()
		if is_instance_valid(tgt_def):
			targets_max_hp.append(tgt_def.base_hp)
		else:
			targets_max_hp.append(0)
		
		var burn_val := 0
		if should_apply_burn:
			burn_val = battle_manager.apply_stat_delta(tgt, "burn_stacks", burn_amount)
		targets_new_burn.append(burn_val)

	
	# Skip if all targets were dead/invalid
	if result.damaged_uuids.is_empty():
		result.should_return = true
		return result
	
	# Compute animation source
	var animation_source_uuid: String = request.source_uuid
	if is_instance_valid(source):
		var source_def := source.get_definition()
		if is_instance_valid(source_def) and source_def.category == &"ITEM":
			if not source.equipped_on_uuid.is_empty():
				animation_source_uuid = source.equipped_on_uuid
	
	# Compute bump direction
	var bump_dir := Vector2.ZERO
	var anim_source: GachaBallInstance = battle_manager.get_instance_by_uuid(animation_source_uuid)
	if is_instance_valid(anim_source):
		var src_tag: StringName = anim_source.location_container_tag
		if src_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or src_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH:
			bump_dir = Vector2(1, 0)
		elif src_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP or src_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_BENCH:
			bump_dir = Vector2(-1, 0)
	
	# Add DAMAGE event with ARMOR data included for unified animation
	result.events.append(CombatEvent.new(CombatEvent.Type.DAMAGE, {
		"source_uuid": request.source_uuid,
		"target_uuids": result.damaged_uuids,
		"ability_id": request.ability_id,
		"trigger_type": request.trigger_context.get("trigger_type", ""),
		"ability_holder_uuid": request.source_uuid,
		"visual_payload": {
			"source_uuid": animation_source_uuid,
			"amount": amount,
			"stat": "hp",
			"skip_bump": skip_bump,
			"bump_direction": bump_dir,
			"apply_burn": should_apply_burn,
			"targets_old_hp": targets_old_hp,
			"targets_new_hp": targets_new_hp,
			"targets_max_hp": targets_max_hp,
			"targets_old_burn": targets_old_burn,
			"targets_new_burn": targets_new_burn,
			"targets_old_armor": targets_old_armor,
			"targets_new_armor": targets_new_armor,
			"armor_consumed": armor_consumed_list,
			"attack_type": "melee",
			"original_target_uuids": original_target_uuids,
			"projectile_data": {
				"stat": "hp",
				"amount": amount,
				"color": "red"
			}
		}
	}))
	
	return result

# ============================================================================
# CASCADE RESULT CLASS
# ============================================================================

## Result returned from handle_cascade_damage containing events and hit targets for Phase 2
class CascadeResult:
	var events: Array[CombatEvent] = []
	var hit_targets: Array[Dictionary] = [] # {uuid, amount, was_killed} for Phase 2 reactions
	
	func _init():
		pass

# ============================================================================
# CASCADE DAMAGE HANDLER
# ============================================================================

## Handle cascade damage effects (AOE shockwave)
## Phase 1: Apply damage and create events for visual "wave" effect
## Returns CascadeResult with events and hit_targets for Phase 2 callbacks
static func handle_cascade_damage(
	request: EffectRequest,
	cascade_list: Array,
	source: GachaBallInstance,
	battle_manager: Node
) -> CascadeResult:
	var result := CascadeResult.new()
	
	# Check if burn should be applied
	# Check if burn should be applied (Trinket + Fire Trait)
	var is_player_source := false
	var burn_amount := 0
	
	if is_instance_valid(source):
		is_player_source = battle_manager._is_player_unit(source)
	
	# 1. Trinket: Burn Vial (Team-wide)
	if battle_manager._has_team_trinket(is_player_source, &"trinket_burn_vial"):
		burn_amount += 1
		
	# 2. Fire Trait: 3+ Souls -> Fire units apply Burn
	var active_traits = battle_manager.get_active_traits("PLAYER" if is_player_source else "ENEMY")
	if active_traits.get("FIRE", 0) >= 3:
		if is_instance_valid(source) and battle_manager._has_trait_soul(source, "FIRE"):
			burn_amount += 1
			
	var should_apply_burn = burn_amount > 0
	
	# Process each cascade target
	for cascade_item in cascade_list:
		var cascade_target_uuid := String(cascade_item.get("target", ""))
		var cascade_amount := int(cascade_item.get("amount", 0))
		var cascade_skip_bump := bool(cascade_item.get("skip_bump", false))
		
		# Store original target for animation (in case Guardian redirects)
		var original_target_uuid := cascade_target_uuid
		
		var cascade_tgt: GachaBallInstance = battle_manager.get_instance_by_uuid(cascade_target_uuid)
		if not is_instance_valid(cascade_tgt):
			continue
		
		# GUARDIAN SENTINEL INTERCEPT CHECK
		var would_be_lethal: bool = cascade_tgt.current_hp - cascade_amount <= 0
		var tgt_is_player_unit: bool = battle_manager._is_player_unit(cascade_tgt)
		var is_ally_damage: bool = (tgt_is_player_unit != is_player_source)
		
		if would_be_lethal and is_ally_damage:
			var guardian: GachaBallInstance = battle_manager._find_guardian_on_team(tgt_is_player_unit, cascade_target_uuid)
			if is_instance_valid(guardian):
				result.events.append(CombatEvent.new(CombatEvent.Type.GUARDIAN_INTERCEPT, {
					"source_uuid": guardian.ball_uuid,
					"target_uuids": [cascade_target_uuid],
					"visual_payload": {
						"guardian_uuid": guardian.ball_uuid,
						"original_target_uuid": cascade_target_uuid,
						"damage": cascade_amount
					}
				}))
				cascade_target_uuid = guardian.ball_uuid
				cascade_tgt = guardian
		
		var old_hp := cascade_tgt.current_hp
		var old_burn := cascade_tgt.get_status_effect_amount(&"burn")
		
		# apply_stat_delta now returns a dictionary with armor mitigation data
		var damage_result = battle_manager.apply_stat_delta(cascade_tgt, "hp", -cascade_amount)
		
		# Skip if target was already dead (apply_stat_delta returns null)
		if damage_result == null:
			continue
		
		# Extract data from the damage result dictionary
		var new_hp: int = damage_result.get("new_hp", cascade_tgt.current_hp)
		var armor_consumed: int = damage_result.get("armor_consumed", 0)
		var old_armor: int = damage_result.get("old_armor", 0)
		var new_armor: int = damage_result.get("new_armor", 0)
		
		var max_hp := 0
		var tgt_def := cascade_tgt.get_definition()
		if is_instance_valid(tgt_def):
			max_hp = tgt_def.base_hp
		
		# Apply burn if needed
		var burn_val := old_burn
		if should_apply_burn:
			burn_val = battle_manager.apply_stat_delta(cascade_tgt, "burn_stacks", burn_amount)
		
		# Compute animation source
		var animation_source_uuid: String = request.source_uuid
		if is_instance_valid(source):
			var source_def := source.get_definition()
			if is_instance_valid(source_def) and source_def.category == &"ITEM":
				if not source.equipped_on_uuid.is_empty():
					animation_source_uuid = source.equipped_on_uuid
		
		# Compute bump direction
		var bump_dir := Vector2.ZERO
		var anim_source: GachaBallInstance = battle_manager.get_instance_by_uuid(animation_source_uuid)
		if is_instance_valid(anim_source):
			var src_tag: StringName = anim_source.location_container_tag
			if src_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or src_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH:
				bump_dir = Vector2(1, 0)
			elif src_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP or src_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_BENCH:
				bump_dir = Vector2(-1, 0)
		
		result.events.append(CombatEvent.new(CombatEvent.Type.DAMAGE, {
			"source_uuid": request.source_uuid,
			"target_uuids": [cascade_target_uuid],
			"visual_payload": {
				"source_uuid": animation_source_uuid,
				"amount": - cascade_amount,
				"stat": "hp",
				"skip_bump": cascade_skip_bump,
				"bump_direction": bump_dir,
				"apply_burn": should_apply_burn,
				"targets_old_hp": [old_hp],
				"targets_new_hp": [new_hp],
				"targets_max_hp": [max_hp],
				"targets_old_burn": [old_burn],
				"targets_new_burn": [burn_val],
				"targets_old_armor": [old_armor],
				"targets_new_armor": [new_armor],
				"armor_consumed": [armor_consumed],
				"attack_type": "melee",
				"original_target_uuid": original_target_uuid,
				"projectile_data": {
					"stat": "hp",
					"amount": - cascade_amount,
					"color": "red"
				}
			}
		}))
		
		# Track for Phase 2 reactions
		result.hit_targets.append({
			"uuid": cascade_target_uuid,
			"amount": cascade_amount,
			"was_killed": cascade_tgt.current_hp <= 0
		})
	
	return result

# ============================================================================
# SUMMON RESULT CLASS
# ============================================================================

## Result returned from summon handlers
class SummonResult:
	var events: Array[CombatEvent] = []
	var new_instances: Array[GachaBallInstance] = [] # BattleManager registers these
	var cleanup_uuids: Array[String] = [] # Units to cleanup via _perform_unit_death_cleanup
	var queue_updates: Array[Dictionary] = [] # {old_uuid, new_instance} for actor queue
	var container_updates: Array[Dictionary] = [] # {container_tag, slot, uuid} for physical containers
	
	func _init():
		pass

# ============================================================================
# SUMMON HELPER - Create snapshot for SUMMON event
# ============================================================================

## Create snapshot dictionary for a new unit (used in SUMMON event visual_payload)
static func create_unit_snapshot(inst: GachaBallInstance, unit_def: Resource) -> Dictionary:
	var icon = unit_def.icon if "icon" in unit_def else null
	var tier = unit_def.tier if "tier" in unit_def else 0
	var category = unit_def.category if "category" in unit_def else &"UNIT"
	var name_key = unit_def.display_name_key if "display_name_key" in unit_def else ""
	
	return {
		"uuid": inst.ball_uuid,
		"hp": inst.current_hp,
		"pwr": inst.current_pwr,
		"burn_stacks": inst.get_status_effect_amount(&"burn"),
		"def_id": unit_def.id,
		"icon": icon,
		"tier": tier,
		"category": category,
		"display_name_key": name_key
	}

# ============================================================================
# SUMMON UNIT HANDLER (Single unit summon/resurrection)
# ============================================================================

## Handle single unit summon effects (e.g., item on-death summon, resurrection)
## Creates new instance and returns data for BattleManager to register
static func handle_summon_unit(
	request: EffectRequest,
	effect_data: Dictionary,
	battle_manager: Node
) -> SummonResult:
	var result := SummonResult.new()
	
	var unit_id = effect_data.get("summon_unit_id")
	var holder_uuid: String = effect_data.get("holder_uuid", "")
	var holder_location = effect_data.get("holder_location")
	var is_resurrection: bool = effect_data.get("is_resurrection", false)
	
	if not unit_id or not is_instance_valid(holder_location):
		return result
	
	# Get unit definition
	var unit_def = Database.units.get(unit_id)
	if not is_instance_valid(unit_def):
		unit_def = Database.get_definition(unit_id)
	if not is_instance_valid(unit_def):
		return result
	
	# Create new instance
	var new_inst := GachaBallInstance.new()
	new_inst.initialize(unit_def)
	new_inst.reset_battle_stats_silent()
	
	# 2. Add to result for BattleManager to register
	result.new_instances.append(new_inst)
	
	# COLLISION RESOLUTION:
	# Verify the target slot is actually available (either empty or occupied by the holder we're replacing).
	# If occupied by a DIFFERENT unit, we must find an alternative slot or discard.
	var final_location = holder_location
	var container = battle_manager.get_container(holder_location.container)
	if is_instance_valid(container):
		var slot_uuid = container.get_uuid(holder_location.index)
		# Checks: Slot not empty AND Slot not occupied by the unit we are replacing/resurrecting
		if not slot_uuid.is_empty() and slot_uuid != holder_uuid:
			# Collision detected! Attempt to find an empty slot.
			var empty_slot = find_empty_slot_in_container(container)
			# Note: find_empty_slot_in_container searches 0->N (front-to-back? depends on impl)
			# We might prefer back-to-front for players, checking BattleManager helper if needed.
			# But for safety, ANY empty slot is better than overwriting.
			
			if empty_slot != -1:
				# Found a new slot in the lineup
				var new_loc = LocationIdentifier.new(holder_location.container, empty_slot)
				final_location = new_loc
			else:
				# Lineup full. Try Discard Pile.
				if holder_location.container == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or holder_location.container == C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH:
					var discard = battle_manager.get_container(C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
					var discard_slot = find_empty_slot_in_container(discard)
					if discard_slot != -1:
						var discard_loc = LocationIdentifier.new(C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE, discard_slot)
						final_location = discard_loc
					else:
						# Discard also full? Critical failure.
						# We must proceed but maybe log error? 
						# Or just overwrite (worst case) or fail summon?
						# Let's fail the summon to prevent overwriting a live unit.
						result.new_instances.clear()
						return result
				else:
					# Enemy has no discard pile. Cancel summon.
					result.new_instances.clear()
					return result

	# Handle cleanup of old unit (only if we are still targeting the holder's slot)
	if not is_resurrection and final_location.container == holder_location.container and final_location.index == holder_location.index:
		if not holder_uuid.is_empty():
			result.cleanup_uuids.append(holder_uuid)
	elif is_resurrection:
		# For resurrection: mark slot for cleanup if dead unit present
		var rez_container = battle_manager.get_container(final_location.container)
		if is_instance_valid(rez_container):
			var old_uuid: String = rez_container.get_uuid(final_location.index)
			if not old_uuid.is_empty():
				var old_inst: GachaBallInstance = battle_manager.get_instance(old_uuid)
				if is_instance_valid(old_inst) and old_inst.current_hp <= 0:
					result.cleanup_uuids.append(old_uuid)
	
	# Queue update: replace holder in actor queue
	# Only do this if we are taking the holder's slot
	if final_location.container == holder_location.container and final_location.index == holder_location.index:
		result.queue_updates.append({
			"old_uuid": holder_uuid,
			"new_instance": new_inst
		})
	else:
		# If we moved to a new slot (or discard), we need to insert into queue naturally?
		# BattleManager handles insertion of new units via container_updates "insert_into_queue" flag?
		# No, standard summons aren't always inserted.
		# If it's a summon, it should probably be added to queue if it's a new unit.
		# But wait, original logic was "Queue update: replace holder".
		# If we don't replace holder, we should probably append to queue?
		# Let's trust BattleManager's _insert_summoned_unit_into_queue logic if we flag it?
		# result.container_updates has "insert_into_queue".
		pass

	# Container update
	result.container_updates.append({
		"container_tag": final_location.container,
		"slot": final_location.index,
		"uuid": new_inst.ball_uuid,
		"insert_into_queue": true # Ensure it gets added to queue since we might not be replacing holder
	})
	
	# Create SUMMON event
	var snapshot := create_unit_snapshot(new_inst, unit_def)
	var final_old_uuid = holder_uuid
	# If we are NOT replacing the holder, then the "old unit" at the target slot is effectively empty (or we wouldn't be summoning there)
	if final_location.container != holder_location.container or final_location.index != holder_location.index:
		final_old_uuid = ""
		
	result.events.append(CombatEvent.new(CombatEvent.Type.SUMMON, {
		"source_uuid": request.source_uuid,
		"target_uuids": [new_inst.ball_uuid],
		"ability_id": request.ability_id,
		"trigger_type": request.trigger_context.get("trigger_type", ""),
		"ability_holder_uuid": request.source_uuid,
		"visual_payload": {
			"old_unit_uuid": final_old_uuid,
			"new_unit_uuid": new_inst.ball_uuid,
			"old_unit_location": final_location,
			"new_unit_snapshot": snapshot
		}
	}))
	
	return result

# ============================================================================
# SUMMON UNITS HANDLER (Boss summon - multiple units)
# ============================================================================

## Handle boss summon effects (array of units to summon into empty slots)
## Creates new instances and returns data for BattleManager to register
static func handle_summon_units(
	request: EffectRequest,
	effect_data: Dictionary,
	battle_manager: Node
) -> SummonResult:
	var result := SummonResult.new()
	
	var summon_list: Array = effect_data.get("summon_units", [])
	var team: String = effect_data.get("team", "ENEMY")
	var target_container_tag: StringName = C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if team == "ENEMY" else C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	
	# Get container for slot finding
	var lineup_container = battle_manager.get_container(target_container_tag)
	if not is_instance_valid(lineup_container):
		return result
	
	# Track slots we've filled in this batch
	var filled_slots: Array[int] = []
	
	for summon_data in summon_list:
		var unit_id = summon_data.get("unit_id")
		var unit_def = Database.get_definition(unit_id)
		if not is_instance_valid(unit_def):
			continue
		
		# Find empty slot (accounting for slots we've already claimed)
		var empty_slot: int = -1
		for i in range(5):
			if lineup_container.get_uuid(i).is_empty() and not filled_slots.has(i):
				empty_slot = i
				break
		
		if empty_slot == -1:
			break # No more slots
		
		filled_slots.append(empty_slot)
		
		# Create new unit
		var new_unit := GachaBallInstance.new()
		new_unit.initialize(unit_def)
		new_unit.reset_battle_stats_silent()
		
		# Equip items if provided in summon data
		var item_ids: Array = summon_data.get("items", [])
		for i in range(mini(item_ids.size(), new_unit.equipped_item_uuids.size())):
			var item_id = item_ids[i]
			var item_def = Database.get_definition(item_id)
			if is_instance_valid(item_def):
				var item_inst := GachaBallInstance.new()
				item_inst.initialize(item_def)
				item_inst.reset_battle_stats_silent()
				# Link item to unit (equip)
				new_unit.equipped_item_uuids[i] = item_inst.ball_uuid
				item_inst.equipped_on_uuid = new_unit.ball_uuid
				item_inst.equipped_slot_index = i
				item_inst.location_container_tag = C.CONTAINER_EQUIPPED_ITEM
				item_inst.location_slot_index = i
				# Apply item bonuses
				new_unit.current_hp += item_def.bonus_hp
				new_unit.current_pwr += item_def.bonus_pwr
				result.new_instances.append(item_inst)
		
		result.new_instances.append(new_unit)
		
		# Container update
		result.container_updates.append({
			"container_tag": target_container_tag,
			"slot": empty_slot,
			"uuid": new_unit.ball_uuid,
			"insert_into_queue": true # Boss summons insert into queue
		})
		
		# Create location for visual payload
		var summon_loc := LocationIdentifier.new()
		summon_loc.container = target_container_tag
		summon_loc.index = empty_slot
		
		# Create SUMMON event
		var snapshot := create_unit_snapshot(new_unit, unit_def)
		result.events.append(CombatEvent.new(CombatEvent.Type.SUMMON, {
			"source_uuid": request.source_uuid,
			"target_uuids": [new_unit.ball_uuid],
			"ability_id": request.ability_id,
			"trigger_type": request.trigger_context.get("trigger_type", ""),
			"ability_holder_uuid": request.source_uuid,
			"visual_payload": {
				"old_unit_uuid": "", # No old unit for boss summons
				"new_unit_uuid": new_unit.ball_uuid,
				"old_unit_location": summon_loc,
				"new_unit_snapshot": snapshot
			}
		}))
	
	return result
