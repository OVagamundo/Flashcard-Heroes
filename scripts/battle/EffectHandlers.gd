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

## UNIFIED SLOT FINDER
## Finds the "First Available Slot" according to game rules.
## Rule: "First Available" = "Backmost Available".
##
## GEOMETRY DEFINITION:
## Player (Left Side): Slot 0 (Left/Back) ... Slot 4 (Right/Front). Acts 4 -> 0.
## Enemy (Right Side): Slot 0 (Left/Front) ... Slot 4 (Right/Back). Acts 0 -> 4.
##
## DIRECTION:
## Player: Search 0 -> 4 (Back -> Front).
## Enemy: Search 4 -> 0 (Back -> Front).
static func find_best_summon_slot(container: DataContainer, is_player_team: bool, exclude_slots: Array[int] = []) -> int:
	if not is_instance_valid(container):
		return -1
		
	var size = container.get_size()
	
	if is_player_team:
		# Player: 0 (Back) -> N (Front)
		for i in range(size):
			if i in exclude_slots:
				continue
			if container.get_uuid(i) == "":
				return i
	else:
		# Enemy: N (Back) -> 0 (Front)
		for i in range(size - 1, -1, -1):
			if i in exclude_slots:
				continue
			if container.get_uuid(i) == "":
				return i
	
	return -1

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
	# Log message moved inside loop to report actual damage (varying per target)
	# var dealt: int = abs(amount)
	# ...
	
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
		
	# 2. Fire Trait Logic
	var active_traits = battle_manager.get_active_traits("PLAYER" if is_player_source else "ENEMY")
	var fire_level = active_traits.get("FIRE", 0)
	
		# Fire 3: Apply Burn
	if fire_level >= 3:
		# Check if source is a Fire unit
		if is_instance_valid(source) and battle_manager._has_trait_soul(source, "FIRE"):
			burn_amount += 1
			# Fire 5: Extra Burn Stack (Total 2)
			if fire_level >= 5:
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
	
	# Collect Spikes data for all targets (applied during damage animation at impact moment)
	var spikes_data_list: Array[Dictionary] = []
	
	for tgt_uuid in resolved_targets:
		var tgt: GachaBallInstance = battle_manager.get_instance_by_uuid(tgt_uuid)
		# Skip already-dead or removed targets
		if not is_instance_valid(tgt) or tgt.current_hp <= 0:
			continue
			
		# Fire 9: Bonus Damage = Target's Burn Stacks
		var damage_to_apply = amount
		if fire_level >= 9 and damage_to_apply < 0: # Check damage < 0 to be sure it's damage
			if is_instance_valid(source) and battle_manager._has_trait_soul(source, "FIRE"):
				var burn_count = tgt.get_status_effect_amount(&"burn")
				if OS.is_debug_build():
					print("[EffectHandlers] Fire 9 Check: Lvl=%d Src=%s Burn=%d Dmg=%d" % [fire_level, source.ball_uuid, burn_count, damage_to_apply])
				
				if burn_count > 0:
					var bonus_damage = burn_count
					if OS.is_debug_build():
						print("[EffectHandlers] Fire 9 Bonus: +%d" % bonus_damage)
					damage_to_apply -= bonus_damage # Make it more negative (increase damage)
		
		# Log message (Per Target)
		var target_display_name = ""
		# Try to find name in target_names corresponding to this index
		# resolved_targets is aligned with target_names?
		var tgt_idx = resolved_targets.find(tgt_uuid)
		if tgt_idx != -1 and tgt_idx < target_names.size():
			target_display_name = target_names[tgt_idx]
		
		if source_name != "" and target_display_name != "":
			result.events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
				"text": "%s deals %d dmg to %s" % [source_name, abs(damage_to_apply), target_display_name]
			}))
		
		var loc_tag: StringName = tgt.location_container_tag
		var is_in_battle: bool = (loc_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or loc_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP or
								  loc_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH or loc_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_BENCH)
		if not is_in_battle:
			continue
		
		# GUARDIAN SENTINEL INTERCEPT CHECK
		var original_tgt_uuid = tgt_uuid
		var actual_damage = abs(damage_to_apply)
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
		
		# Determine attacker UUID for Spikes reflection
		var attacker_uuid_for_spikes: String = ""
		if is_instance_valid(source):
			var source_def := source.get_definition()
			if is_instance_valid(source_def) and source_def.category == &"ITEM":
				# For items, the attacker is the holder
				attacker_uuid_for_spikes = source.equipped_on_uuid
			else:
				attacker_uuid_for_spikes = source.ball_uuid
		
		# CENTRALIZED ARMOR: apply_stat_delta now handles armor mitigation automatically
		# It returns a dictionary with armor data for animations
		# Also handles Spikes reflection if attacker_uuid is provided
		var damage_result = battle_manager.apply_stat_delta(tgt, "hp", damage_to_apply, false, attacker_uuid_for_spikes)
		
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
		
		# Collect Spikes data for animation (will be applied at damage impact moment)
		if damage_result.has("spikes_data"):
			var spikes = damage_result["spikes_data"]
			var attacker_inst = battle_manager.get_instance_by_uuid(spikes["attacker_uuid"])
			var attacker_max_hp := 0
			if is_instance_valid(attacker_inst):
				var attacker_def = attacker_inst.get_definition()
				if is_instance_valid(attacker_def):
					attacker_max_hp = attacker_def.base_hp
			
			# Log message for Spikes (still a separate event since it's UI only)
			var defender_name = BattleHelpers.get_instance_display_name(tgt)
			var attacker_name = BattleHelpers.get_instance_display_name(attacker_inst) if is_instance_valid(attacker_inst) else ""
			if defender_name != "" and attacker_name != "":
				result.events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
					"text": "%s's Spikes deals %d to %s" % [defender_name, spikes["spikes_damage"], attacker_name]
				}))
			
			# Add to collected spikes data for animation (NOT a separate event)
			spikes_data_list.append({
				"attacker_uuid": spikes["attacker_uuid"],
				"defender_uuid": spikes["defender_uuid"],
				"spikes_damage": spikes["spikes_damage"],
				"attacker_old_hp": spikes["attacker_old_hp"],
				"attacker_new_hp": spikes["attacker_new_hp"],
				"attacker_max_hp": attacker_max_hp,
				"old_spikes": spikes["old_spikes"],
				"new_spikes": spikes["new_spikes"]
			})
		
		# Add to damaged_uuids if HP or armor was affected OR if Burn is applied
		# This ensures that attacks that do 0 damage (due to armor) but apply burn still trigger visual feedback
		# Always include target for visual feedback, even if 0 HP damage was dealt
		# This ensures animations (like bumps/impacts) fire for 0-PWR units
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
			"spikes_data_list": spikes_data_list, # Spikes damage applied at impact moment
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
	var fire_level = active_traits.get("FIRE", 0)
	if fire_level >= 3:
		if is_instance_valid(source) and battle_manager._has_trait_soul(source, "FIRE"):
			burn_amount += 1
			# Fire 5: Extra Burn Stack (Total 2)
			if fire_level >= 5:
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
		
		# Fire 9: Bonus Damage = Target's Burn Stacks
		# Note: Cascade amount is usually positive in request, but negative in application.
		if fire_level >= 9:
			if is_instance_valid(source) and battle_manager._has_trait_soul(source, "FIRE"):
				var burn_count = cascade_tgt.get_status_effect_amount(&"burn")
				if OS.is_debug_build():
					print("[EffectHandlers] Cascade Fire 9 Check: Lvl=%d Src=%s Burn=%d Dmg=%d" % [fire_level, source.ball_uuid, burn_count, cascade_amount])
					
				if burn_count > 0:
					var bonus_damage = burn_count
					if OS.is_debug_build():
						print("[EffectHandlers] Cascade Fire 9 Bonus: +%d" % bonus_damage)
					cascade_amount += bonus_damage # Increase the positive damage amount (which becomes more negative)
		
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
		
		# Determine attacker UUID for Spikes reflection
		var attacker_uuid_for_spikes: String = ""
		if is_instance_valid(source):
			var source_def := source.get_definition()
			if is_instance_valid(source_def) and source_def.category == &"ITEM":
				attacker_uuid_for_spikes = source.equipped_on_uuid
			else:
				attacker_uuid_for_spikes = source.ball_uuid
		
		# apply_stat_delta now returns a dictionary with armor mitigation data
		# Also handles Spikes reflection if attacker_uuid is provided
		var damage_result = battle_manager.apply_stat_delta(cascade_tgt, "hp", -cascade_amount, false, attacker_uuid_for_spikes)
		
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
		
		# Collect Spikes data for animation (will be applied at damage impact moment)
		var spikes_data_list: Array[Dictionary] = []
		if damage_result.has("spikes_data"):
			var spikes = damage_result["spikes_data"]
			var attacker_inst = battle_manager.get_instance_by_uuid(spikes["attacker_uuid"])
			var attacker_max_hp := 0
			if is_instance_valid(attacker_inst):
				var attacker_def = attacker_inst.get_definition()
				if is_instance_valid(attacker_def):
					attacker_max_hp = attacker_def.base_hp
			
			# Log message for Spikes (still a separate event since it's UI only)
			var defender_name = BattleHelpers.get_instance_display_name(cascade_tgt)
			var attacker_name = BattleHelpers.get_instance_display_name(attacker_inst) if is_instance_valid(attacker_inst) else ""
			if defender_name != "" and attacker_name != "":
				result.events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
					"text": "%s's Spikes deals %d to %s" % [defender_name, spikes["spikes_damage"], attacker_name]
				}))
			
			# Add to collected spikes data for animation (NOT a separate event)
			spikes_data_list.append({
				"attacker_uuid": spikes["attacker_uuid"],
				"defender_uuid": spikes["defender_uuid"],
				"spikes_damage": spikes["spikes_damage"],
				"attacker_old_hp": spikes["attacker_old_hp"],
				"attacker_new_hp": spikes["attacker_new_hp"],
				"attacker_max_hp": attacker_max_hp,
				"old_spikes": spikes["old_spikes"],
				"new_spikes": spikes["new_spikes"]
			})
		
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
				"spikes_data_list": spikes_data_list, # Spikes damage applied at impact moment
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
	# If occupied by a DIFFERENT unit, we must find an alternative slot.
	var final_location = holder_location
	var container = battle_manager.get_container(holder_location.container)
	var collision_detected := false
	
	if is_instance_valid(container):
		var slot_uuid = container.get_uuid(holder_location.index)
		# Checks: Slot occupied?
		if not slot_uuid.is_empty():
			# If occupied by a DIFFERENT unit, it's a collision.
			if slot_uuid != holder_uuid:
				collision_detected = true
			else:
				# If occupied by SAME unit (holder), check if they are ALIVE.
				# If alive (e.g. just resurrected), we cannot overwrite them.
				var slot_unit = battle_manager.get_instance_by_uuid(slot_uuid)
				if is_instance_valid(slot_unit) and slot_unit.current_hp > 0:
					collision_detected = true
	
	if collision_detected:
		# Collision detected! Attempt to find an empty slot.
		# Priority 1: First empty slot in same container (Using Unified Finder)
		var is_player_container = (holder_location.container == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or holder_location.container == C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH)
		var empty_slot = find_best_summon_slot(container, is_player_container)
			
		if empty_slot != -1:
			final_location = LocationIdentifier.new(holder_location.container, empty_slot)
		else:
			# Priority 2: Discard Pile (Player only)
			if is_player_container:
				var discard = battle_manager.get_container(C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
				var discard_slot = find_empty_slot_in_container(discard)
				if discard_slot != -1:
					final_location = LocationIdentifier.new(C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE, discard_slot)
				else:
					# Discard full. Cancel summon.
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
	
	# Queue behavior:
	# - If we replace the holder's slot, we should replace that holder's queue entry (at most one action).
	# - If we summon into a different slot, we should use normal mid-turn insertion rules.
	var is_replacing_holder_slot: bool = (
		final_location.container == holder_location.container and
		final_location.index == holder_location.index
	)
	if is_replacing_holder_slot and not holder_uuid.is_empty():
		result.queue_updates.append({
			"old_uuid": holder_uuid,
			"new_instance": new_inst
		})

	# Container update
	result.container_updates.append({
		"container_tag": final_location.container,
		"slot": final_location.index,
		"uuid": new_inst.ball_uuid,
		"insert_into_queue": not is_replacing_holder_slot
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
			"new_unit_snapshot": snapshot,
			"spawn_source_uuid": effect_data.get("spawn_source_uuid", ""),
			"unit_tier": effect_data.get("unit_tier", 1)
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
		
		# Find empty slot using Unified Finder
		var empty_slot: int = find_best_summon_slot(lineup_container, team == "PLAYER", filled_slots)
		
		if empty_slot == -1:
			break # No more slots
		
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

# ============================================================================
# TRANSFORM HANDLER
# ============================================================================

## Handle Mirror Transform (Mimic)
## Discards equipped items, removes self, and prepares summon of target unit.
static func handle_mirror_transform(
	_request: EffectRequest,
	transform_data: Dictionary,
	battle_manager: Node
) -> SummonResult:
	var self_uuid: String = transform_data.get("self_uuid", "")
	var target_unit_id: StringName = transform_data.get("target_unit_id", &"")
	var target_name: String = transform_data.get("target_name", "")
	
	var source: GachaBallInstance = battle_manager.get_instance_by_uuid(self_uuid)
	if not is_instance_valid(source):
		return SummonResult.new() # Failed
	
	var result := SummonResult.new()
	
	# 1. Log Event
	var source_display_name = BattleHelpers.get_instance_display_name(source)
	if source_display_name == "": source_display_name = "Mimic"
	
	result.events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "%s transforms into %s!" % [source_display_name, target_name]
	}))
	
	# 2. Visual Event (Vanish)
	# 2. Visual Event (Transform: Hop & Vanish)
	# 2. Visual Event (Transform: Hop & Vanish)
	result.events.append(CombatEvent.new(CombatEvent.Type.TRANSFORM, {
		"target_uuids": [self_uuid],
		"visual_payload": {
			"style": "yellow_flash"
		}
	}))
	
	# 3. State Mutation: Discard Items
	var items_to_discard = source.equipped_item_uuids.duplicate()
	for item_uuid in items_to_discard:
		if not item_uuid.is_empty():
			var item_inst = battle_manager.get_instance_by_uuid(item_uuid)
			if is_instance_valid(item_inst):
				InventoryOperations.move_instance_to_discard(battle_manager._state, item_inst)
	# Clear on source
	source.equipped_item_uuids.fill("")
	
	# 4. State Mutation: Remove Self (Vanish)
	var my_loc = source.get_location()
	
	# CRITICAL FIX: Use bm_remove_instance (atomic) to fully unregister the unit from state and containers.
	# InventoryOperations.remove_instance_from_container only clears the container slot but leaves
	# the instance in _battle_instances with an empty location, causing Golden Rule violations.
	battle_manager._state.bm_remove_instance(self_uuid)
	
	# 5. Determine Summon Location
	# We want to summon EXACTLY where we were.
	
	# Create the new instance
	var new_def = Database.get_definition(target_unit_id)
	if is_instance_valid(new_def):
		var new_unit = GachaBallInstance.new()
		new_unit.initialize(new_def)
		new_unit.reset_battle_stats_silent()
		
		# Place it in the container
		# Use atomic API to register and place
		battle_manager._state.bm_add_instance(new_unit, my_loc.container, my_loc.index)
		
		# Populate result
		result.new_instances.append(new_unit)
		# NOTE: We do not use container_updates here because we already used atomic bm_add_instance
		# which handles the placement immediately.
		
		# Events
		# Events
		var is_player = battle_manager._is_player_unit(new_unit)
		
		# Construct robust SUMMON event with visual style
		var summon_payload = {
			"visual_style": "yellow_flash",
			"new_unit_uuid": new_unit.ball_uuid,
			"old_unit_location": my_loc, # Used by Animator to find the slot
			"new_unit_snapshot": VisualDataAdapter.create_visual_data(new_unit, battle_manager.get_all_instances())
		}
		
		result.events.append(CombatEvent.new(CombatEvent.Type.SUMMON, {
			"target_uuids": [new_unit.ball_uuid],
			"visual_payload": summon_payload
		}))
		result.events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "%s appeared!" % [BattleHelpers.get_definition_display_name(new_def)]
		}))
			
	return result
