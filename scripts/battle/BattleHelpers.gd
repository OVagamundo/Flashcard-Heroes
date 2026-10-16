# res://scripts/battle/BattleHelpers.gd
class_name BattleHelpers
extends RefCounted

## BattleHelpers contains static utility functions used across the battle system.
## These are pure helper functions with no state dependencies.

# ============================================================================
# DISPLAY NAME HELPERS
# ============================================================================

## Get display name from a definition resource
static func get_definition_display_name(definition: Resource) -> String:
	if not is_instance_valid(definition):
		return ""
	if "display_name_key" in definition:
		return TranslationServer.translate(definition.display_name_key)
	if "name_key" in definition:
		return TranslationServer.translate(definition.name_key)
	if "name" in definition:
		return TranslationServer.translate(definition.name)
	if "id" in definition:
		return String(definition.id)
	return ""

## Get display name from an instance
static func get_instance_display_name(inst: GachaBallInstance) -> String:
	if not is_instance_valid(inst):
		return ""
	var definition := inst.get_definition()
	return get_definition_display_name(definition)

# ============================================================================
# ALLY/ENEMY HELPERS
# ============================================================================

## Get the ally behind a source unit (for pass-through abilities)
static func get_ally_behind(state: BattleState, source_instance: GachaBallInstance) -> GachaBallInstance:
	if not is_instance_valid(source_instance):
		return null
	var container_name := source_instance.location_container_tag
	var container := state.get_container(container_name)
	if not is_instance_valid(container):
		return null
	
	var source_index := container.get_index_of_uuid(source_instance.ball_uuid)
	if source_index == -1:
		return null
	
	var is_player := state.is_player_unit(source_instance)
	
	# For players (right-to-left), "behind" means lower index
	# For enemies (left-to-right), "behind" means higher index
	var behind_index: int
	if is_player:
		behind_index = source_index - 1
	else:
		behind_index = source_index + 1
	
	if behind_index < 0 or behind_index >= container.get_size():
		return null
	
	var behind_uuid := container.get_uuid(behind_index)
	if behind_uuid.is_empty():
		return null
	
	var inst := state.get_instance(behind_uuid)
	if is_instance_valid(inst) and inst.current_hp > 0:
		return inst
	return null

## Find a unit with the intercept_lethal tag on the specified team that can intercept damage.
## Returns the unit with highest HP, or null if none available.
static func find_interceptor_on_team(state: BattleState, is_player_team: bool, exclude_uuid: String = "") -> GachaBallInstance:
	var container_tag := &"PlayerLineup" if is_player_team else &"EnemyLineup"
	var units := state.get_instances_in_container(container_tag)
	
	var best_interceptor: GachaBallInstance = null
	for unit in units:
		if unit.ball_uuid == exclude_uuid:
			continue
		if unit.current_hp <= 0:
			continue
		
		var def := unit.get_definition()
		if not is_instance_valid(def):
			continue
		
		# Check for intercept_lethal tag (generic system, not hardcoded to one unit)
		if def is GachaBallDefinition:
			var gbd := def as GachaBallDefinition
			if gbd.tags and gbd.tags.has(&"intercept_lethal"):
				if best_interceptor == null or unit.current_hp > best_interceptor.current_hp:
					best_interceptor = unit
	
	return best_interceptor

# ============================================================================
# SNAPSHOT HELPERS
# ============================================================================

## Capture a snapshot of the current board state for animation comparison
static func get_board_snapshot(state: BattleState) -> Dictionary:
	var snapshot := {}
	for uuid in state.get_all_instances():
		var inst := state.get_instance(uuid)
		if is_instance_valid(inst):
			snapshot[uuid] = {
				"hp": inst.current_hp,
				"pwr": inst.current_pwr,
				"location": inst.location_container_tag,
				"slot": inst.location_slot_index
			}
	return snapshot

## Get the slot ahead of a source unit (for frontline targeting)
static func get_slot_ahead(state: BattleState, source_instance: GachaBallInstance) -> GachaBallInstance:
	if not is_instance_valid(source_instance):
		return null
	var container_name := source_instance.location_container_tag
	var container := state.get_container(container_name)
	if not is_instance_valid(container):
		return null
	
	var source_index := container.get_index_of_uuid(source_instance.ball_uuid)
	if source_index == -1:
		return null
	
	var is_player := state.is_player_unit(source_instance)
	
	# For players (right-to-left), "ahead" (toward enemy) means higher index
	# For enemies (left-to-right), "ahead" (toward player) means lower index
	var ahead_index: int
	if is_player:
		ahead_index = source_index + 1
	else:
		ahead_index = source_index - 1
	
	if ahead_index < 0 or ahead_index >= container.get_size():
		return null
	
	var ahead_uuid := container.get_uuid(ahead_index)
	if ahead_uuid.is_empty():
		return null
	
	var inst := state.get_instance(ahead_uuid)
	if is_instance_valid(inst) and inst.current_hp > 0:
		return inst
	return null

## Get adjacent allies (front and back)
static func get_adjacent_allies(state: BattleState, source_instance: GachaBallInstance) -> Array[GachaBallInstance]:
	var adjacent: Array[GachaBallInstance] = []
	
	var ally_behind := get_ally_behind(state, source_instance)
	if is_instance_valid(ally_behind):
		adjacent.append(ally_behind)
	
	var ally_ahead := get_slot_ahead(state, source_instance)
	if is_instance_valid(ally_ahead):
		adjacent.append(ally_ahead)
	
	return adjacent

## Find a Guardian by ability ID (more specific than tag-based lookup)
## Returns the Guardian with highest HP, or null if none available.
static func find_guardian_by_ability(state: BattleState, is_player_team: bool, exclude_uuid: String, ability_id: StringName) -> GachaBallInstance:
	var container_tag := &"PlayerLineup" if is_player_team else &"EnemyLineup"
	var units := state.get_instances_in_container(container_tag)
	
	var best_guardian: GachaBallInstance = null
	for unit in units:
		if unit.ball_uuid == exclude_uuid:
			continue
		if unit.current_hp <= 0:
			continue
		
		var def := unit.get_definition()
		if not is_instance_valid(def):
			continue
		
		# Check for specific ability
		var has_ability := false
		for ability in def.ability_definitions:
			if ability.id == ability_id:
				has_ability = true
				break
		
		if has_ability:
			if best_guardian == null or unit.current_hp > best_guardian.current_hp:
				best_guardian = unit
	
	return best_guardian

class InterceptResolution extends RefCounted:
	var intercepted: bool = false
	var interceptor: GachaBallInstance = null
	var events: Array[CombatEvent] = []

## Centralized Guardian intercept resolution.
## Evaluates if incoming damage is lethal to target ally, finds a guardian on the same team,
## triggers passive_intercept so Guardian gains level-based armor (e.g. +1 / +2)
## on top of any existing armor BEFORE leaping, and records events in proper sequence.
static func resolve_guardian_intercept(
	target_inst: GachaBallInstance,
	damage_amount: int,
	damage_type: int,
	is_player_source: bool,
	battle_manager: Node
) -> InterceptResolution:
	var res := InterceptResolution.new()
	if not is_instance_valid(target_inst) or target_inst.current_hp <= 0:
		return res
	if not is_instance_valid(battle_manager):
		return res
		
	# Status effect damage (BURN, STATIC) bypasses armor and intercept
	const C = preload("res://scripts/Constants.gd")
	if damage_type == C.DamageType.BURN or damage_type == C.DamageType.STATIC:
		return res
		
	var tgt_is_player_unit: bool = battle_manager._is_player_unit(target_inst)
	var is_ally_damage: bool = (tgt_is_player_unit != is_player_source)
	if not is_ally_damage:
		return res

	# Tank L3: Intercept ANY physical attack aimed at the ally directly behind it
	var team_traits: Dictionary = battle_manager.get_active_traits("PLAYER" if tgt_is_player_unit else "ENEMY")
	if team_traits.get("TANK", 0) >= 4:
		var ahead_unit = battle_manager._get_slot_ahead(target_inst)
		if is_instance_valid(ahead_unit) and ahead_unit.current_hp > 0 and battle_manager.has_trait(ahead_unit, "TANK"):
			res.intercepted = true
			res.interceptor = ahead_unit
			return res

	var target_armor: int = target_inst.get_status_effect_amount(&"armor")
	var predicted_hp_damage: int = max(0, damage_amount - target_armor)
	var would_be_lethal: bool = target_inst.current_hp - predicted_hp_damage <= 0
	if not would_be_lethal:
		return res
		
	var guardian: GachaBallInstance = battle_manager._find_guardian_on_team(tgt_is_player_unit, target_inst.ball_uuid)
	if not is_instance_valid(guardian):
		return res
		
	res.intercepted = true
	res.interceptor = guardian
	
	# Trigger Guardian passive effects (e.g., gain Armor at Level 2/3 on top of existing armor)
	var combat_sim = battle_manager._combat
	var intercept_scope = combat_sim.begin_reaction_scope()
	AbilityResolver.process_trigger(&"passive_intercept", {
		"source_uuid": guardian.ball_uuid,
		"is_simulation": true
	})
	var guardian_results = combat_sim.drain_reaction_scope(intercept_scope, battle_manager)
	
	# Event order: Armor gain resolves first (on top of existing armor), then the leap event
	res.events.append_array(guardian_results)
	res.events.append(CombatEvent.new(CombatEvent.Type.GUARDIAN_INTERCEPT, {
		"source_uuid": guardian.ball_uuid,
		"target_uuids": [target_inst.ball_uuid],
		"visual_payload": CombatPayload.guardian_intercept(guardian.ball_uuid, target_inst.ball_uuid)
	}))
	
	return res

## Get a comprehensive board snapshot for animation playback (includes visual data)
static func get_combat_board_snapshot(battle_instances: Dictionary) -> Dictionary:
	var snapshot: Dictionary = {}
	for uuid in battle_instances:
		var inst: GachaBallInstance = battle_instances[uuid]
		if not is_instance_valid(inst):
			continue
		
		var location = inst.get_location()
		# Only include instances that have visual representations
		if not is_instance_valid(location) or not location is LocationIdentifier:
			continue
		
		var container: StringName = location.container
		# Only include units in lineups and bench - these have GachaBallView instances
		if container != &"PlayerLineup" and container != &"EnemyLineup" and container != &"PlayerBench":
			continue
		
		var def = inst.get_definition()
		snapshot[uuid] = {
			# Core stats
			"hp": inst.current_hp,
			"pwr": inst.current_pwr,
			"burn_stacks": inst.get_status_effect_amount(&"burn"), # Backward compat
			"armor_stacks": inst.get_status_effect_amount(&"armor"), # Added for armor - same pattern as burn
			"spikes_stacks": inst.get_status_effect_amount(&"spikes"), # Spikes status effect
			"status_effects": inst.status_effects.duplicate(), # Generic
			# Definition data for view creation
			"def_id": def.id if is_instance_valid(def) else "",
			"icon": def.icon if (is_instance_valid(def) and "icon" in def) else null,
			"tier": def.tier if (is_instance_valid(def) and "tier" in def) else 0,
			"category": def.category if (is_instance_valid(def) and "category" in def) else &"UNIT",
			"display_name_key": def.display_name_key if (is_instance_valid(def) and "display_name_key" in def) else "",
			# Location as VALUES not reference
			"container_tag": container,
			"slot_index": location.index
		}
	
	return snapshot
