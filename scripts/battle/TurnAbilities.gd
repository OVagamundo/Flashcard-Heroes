# res://scripts/battle/TurnAbilities.gd
class_name TurnAbilities
extends RefCounted

## TurnAbilities handles turn-phase ability triggers.
## Responsible for:
##   - Triggering on_battle_start abilities
##   - Triggering on_turn_start abilities  
##   - Triggering on_turn_end abilities
##   - Processing status effects (burn damage)

const C = preload("res://scripts/Constants.gd")

# ============================================================================
# BATTLE START ABILITIES
# ============================================================================

## Trigger on_battle_start for all units in lineup
static func trigger_battle_start_abilities(state: BattleState) -> void:
	var all_units := state.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	all_units.append_array(state.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP))

	
	for unit in all_units:
		var battle_start_context: Dictionary = {"source_uuid": unit.ball_uuid}
		AbilityResolver.process_trigger(&"on_battle_start", battle_start_context)

# ============================================================================
# TURN START ABILITIES
# ============================================================================

## Trigger on_turn_start for all instances. Returns true if there are pending reactions.
static func trigger_turn_start_abilities(current_turn: int) -> bool:
	var turn_start_context: Dictionary = {"turn": current_turn}
	AbilityResolver.process_trigger(&"on_turn_start", turn_start_context)
	# Caller should check _pending_reactions to know if there are reactions to process
	return true

# ============================================================================
# TURN END - STATUS EFFECTS
# ============================================================================

## Process burn damage for all units. Returns array of CombatEvents.
static func process_burn_damage(state: BattleState, get_display_name_callback: Callable, apply_stat_delta_callback: Callable) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	
	var all_units := state.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	all_units.append_array(state.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP))
	
	for unit in all_units:
		if unit.current_hp <= 0:
			continue # Skip dead units
		
		var burn_stacks: int = unit.get_status_effect_amount(&"burn")
		if burn_stacks > 0:
			var damage := burn_stacks
			var old_hp := unit.current_hp
			var old_armor := unit.get_status_effect_amount(&"armor")
			
			# Apply damage via callback (apply_stat_delta now returns dictionary for damage)
			var damage_result = apply_stat_delta_callback.call(unit, "hp", -damage)
			
			# Extract data from dictionary return
			var new_hp: int = damage_result.get("new_hp", unit.current_hp) if damage_result is Dictionary else unit.current_hp
			var armor_consumed: int = damage_result.get("armor_consumed", 0) if damage_result is Dictionary else 0
			var new_armor: int = damage_result.get("new_armor", 0) if damage_result is Dictionary else 0
			
			var max_hp := 0
			var unit_def := unit.get_definition()
			if is_instance_valid(unit_def):
				max_hp = unit_def.base_hp
			
			var unit_name: String = get_display_name_callback.call(unit)
			events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": "%s takes %d burn dmg" % [unit_name, damage]}))
			events.append(CombatEvent.new(CombatEvent.Type.DAMAGE, {
				"source_uuid": "",
				"target_uuids": [unit.ball_uuid],
				"visual_payload": {
					"amount": - damage,
					"stat": "hp",
					"skip_bump": true,
					"is_burn_damage": true,
					"targets_old_hp": [old_hp],
					"targets_new_hp": [new_hp],
					"targets_max_hp": [max_hp],
					"targets_old_armor": [old_armor],
					"targets_new_armor": [new_armor],
					"armor_consumed": [armor_consumed]
				}
			}))

	
	return events

# ============================================================================
# TURN END ABILITIES
# ============================================================================

## Trigger on_turn_end for all units
static func trigger_turn_end_abilities(current_turn: int) -> void:
	var turn_end_context: Dictionary = {"turn": current_turn}
	AbilityResolver.process_trigger(&"on_turn_end", turn_end_context)

# ============================================================================
# COMBAT TRIGGER CALLBACKS
# ============================================================================

## Trigger on_damage_dealt for the attacker (for lifesteal effects)
## @param actual_attacker_uuid: String - The UUID of the unit that dealt damage
## @param victim_uuid: String - The UUID of the damaged unit
## @param damage_amount: int - The amount of damage dealt
## @param victim_new_hp: int - The victim's HP after damage
static func trigger_on_damage_dealt(actual_attacker_uuid: String, victim_uuid: String, damage_amount: int, victim_new_hp: int) -> void:
	var damage_dealt_context: Dictionary = {
		"attacker_uuid": actual_attacker_uuid,
		"victim_uuid": victim_uuid,
		"damage_dealt": damage_amount,
		"victim_new_hp": victim_new_hp
	}
	AbilityResolver.process_trigger(&"on_damage_dealt", damage_dealt_context)

## Trigger on_hurt for a unit that took damage
## @param victim_uuid: String - The UUID of the damaged unit
## @param damage_amount: int - The amount of damage taken
## @param attacker_uuid: String - The UUID of the attacker
## @param victim_team: String - "PLAYER" or "ENEMY"
## @param victim_current_hp: int - The victim's current HP after damage
## @param cause: StringName - The cause of damage (C.CAUSE_ATTACK, etc.)
static func trigger_on_hurt(victim_uuid: String, damage_amount: int, attacker_uuid: String, victim_team: String, victim_current_hp: int, cause: StringName) -> void:
	var hurt_context: Dictionary = {
		"victim_uuid": victim_uuid,
		"damage_taken": damage_amount,
		"attacker_uuid": attacker_uuid,
		"victim_team": victim_team,
		"victim_current_hp": victim_current_hp,
		"trigger_cause": cause
	}
	AbilityResolver.process_trigger(&"on_hurt", hurt_context)

## Trigger on_kill for a unit that killed another unit
## @param killer_uuid: String - The UUID of the killer
## @param killed_uuid: String - The UUID of the killed unit
static func trigger_on_kill(killer_uuid: String, killed_uuid: String) -> void:
	var kill_context: Dictionary = {
		"attacker_uuid": killer_uuid,
		"killed_uuid": killed_uuid
	}
	AbilityResolver.process_trigger(&"on_kill", kill_context)

## Trigger on_enemy_summon when a unit is summoned
## This allows units like Dreadnought to react and attack the newly summoned unit
## @param summoned_uuid: String - The UUID of the summoned unit
## @param summoned_team: String - "PLAYER" or "ENEMY" team of the summoned unit
## @param summoned_location: LocationIdentifier - Where the unit was summoned
static func trigger_on_enemy_summon(summoned_uuid: String, summoned_team: String, summoned_location: LocationIdentifier) -> void:
	var summon_context: Dictionary = {
		"summoned_uuid": summoned_uuid,
		"summoned_team": summoned_team,
		"summoned_location": summoned_location
	}
	AbilityResolver.process_trigger(&"on_enemy_summon", summon_context)

## Trigger on_ally_summon when a unit is summoned
## This allows units to react and buff the newly summoned ally unit
## @param summoned_uuid: String - The UUID of the summoned unit
## @param summoned_team: String - "PLAYER" or "ENEMY" team of the summoned unit
## @param summoned_location: LocationIdentifier - Where the unit was summoned
static func trigger_on_ally_summon(summoned_uuid: String, summoned_team: String, summoned_location: LocationIdentifier) -> void:
	var summon_context: Dictionary = {
		"summoned_uuid": summoned_uuid,
		"summoned_team": summoned_team,
		"summoned_location": summoned_location
	}
	AbilityResolver.process_trigger(&"on_ally_summon", summon_context)
