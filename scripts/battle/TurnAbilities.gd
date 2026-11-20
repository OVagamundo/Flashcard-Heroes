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
		var battle_start_context := TriggerContext.new()
		battle_start_context.source_uuid = unit.ball_uuid
		AbilityResolver.process_trigger(C.TRIGGER_AT_BATTLE_START, battle_start_context)

# ============================================================================
# TURN START ABILITIES
# ============================================================================

## Trigger on_turn_start for all instances. Returns true if there are pending reactions.
static func trigger_turn_start_abilities(current_turn: int) -> bool:
	var turn_start_context := TriggerContext.new()
	turn_start_context.turn = current_turn
	AbilityResolver.process_trigger(C.TRIGGER_AT_TURN_START, turn_start_context)
	# Caller should check _pending_reactions to know if there are reactions to process
	return true

# ============================================================================
# TURN END ABILITIES
# ============================================================================

## Trigger on_turn_end for all units
static func trigger_turn_end_abilities(current_turn: int) -> void:
	var turn_end_context := TriggerContext.new()
	turn_end_context.turn = current_turn
	AbilityResolver.process_trigger(C.TRIGGER_AT_TURN_END, turn_end_context)

# ============================================================================
# COMBAT TRIGGER CALLBACKS
# ============================================================================

## Trigger on_damage_dealt for the attacker (for lifesteal effects)
## @param actual_attacker_uuid: String - The UUID of the unit that dealt damage
## @param damaged_unit_uuid: String - The UUID of the damaged unit
## @param damage_amount: int - The amount of damage dealt
## @param victim_new_hp: int - The damaged unit's HP after damage
static func trigger_on_damage_dealt(actual_attacker_uuid: String, damaged_unit_uuid: String, damage_amount: int, victim_new_hp: int, cause: StringName) -> void:
	var damage_dealt_context := TriggerContext.new()
	damage_dealt_context.attacker_uuid = actual_attacker_uuid
	damage_dealt_context.damaged_uuid = damaged_unit_uuid
	damage_dealt_context.damage_dealt = damage_amount
	damage_dealt_context.damaged_current_hp = victim_new_hp
	damage_dealt_context.trigger_cause = cause
	AbilityResolver.process_trigger(C.TRIGGER_ON_DAMAGE_DEALT, damage_dealt_context)

## Trigger on_hurt for a unit that took damage
## @param damaged_unit_uuid: String - The UUID of the damaged unit
## @param damage_amount: int - The amount of damage taken
## @param attacker_uuid: String - The UUID of the attacker
## @param victim_team: String - "PLAYER" or "ENEMY"
## @param victim_current_hp: int - The damaged unit's current HP after damage
## @param cause: StringName - The cause of damage (C.CAUSE_ATTACK, etc.)
## @param victim_category: The damaged unit definition category captured at trigger time
static func trigger_on_hurt(damaged_unit_uuid: String, damage_amount: int, attacker_uuid: String, victim_team: String, victim_current_hp: int, cause: StringName, status_id: StringName = &"", victim_category: StringName = &"") -> void:
	var hurt_context := TriggerContext.new()
	hurt_context.damaged_uuid = damaged_unit_uuid
	hurt_context.damage_taken = damage_amount
	hurt_context.attacker_uuid = attacker_uuid
	hurt_context.damaged_team = victim_team
	hurt_context.damaged_current_hp = victim_current_hp
	hurt_context.damaged_category = victim_category
	hurt_context.trigger_cause = cause
	hurt_context.status_id = status_id
	AbilityResolver.process_trigger(C.TRIGGER_WHEN_TAKING_DAMAGE, hurt_context)

## Trigger on_kill for a unit that killed another unit
## @param killer_uuid: String - The UUID of the killer
## @param killed_uuid: String - The UUID of the killed unit
static func trigger_on_kill(killer_uuid: String, killed_uuid: String) -> void:
	var kill_context := TriggerContext.new()
	kill_context.attacker_uuid = killer_uuid
	kill_context.killer_uuid = killer_uuid
	kill_context.knocked_out_uuid = killed_uuid
	AbilityResolver.process_trigger(C.TRIGGER_ON_KNOCKOUT_BLOW, kill_context)

## Trigger on_enemy_summon when a unit is summoned
## This allows units like Assassin to react and attack the newly summoned unit
## @param summoned_uuid: String - The UUID of the summoned unit
## @param summoned_team: String - "PLAYER" or "ENEMY" team of the summoned unit
## @param summoned_location: LocationIdentifier - Where the unit was summoned
static func trigger_on_enemy_summon(summoned_uuid: String, summoned_team: String, summoned_location: LocationIdentifier) -> void:
	# AMBUSH FILTER: Only trigger if the unit is in a lineup (battlefield)
	# This prevents Assassin from attacking units summoned to the shelf
	if is_instance_valid(summoned_location):
		var container := summoned_location.container
		if container != C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP and container != C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
			return
	
	var summon_context := TriggerContext.new()
	summon_context.summoned_uuid = summoned_uuid
	summon_context.summoned_team = summoned_team
	AbilityResolver.process_trigger(C.TRIGGER_WHEN_ENEMY_SUMMONED, summon_context)

## Trigger on_ally_summon when a unit is summoned
## This allows units to react and buff the newly summoned ally unit
## @param summoned_uuid: String - The UUID of the summoned unit
## @param summoned_team: String - "PLAYER" or "ENEMY" team of the summoned unit
## @param summoned_location: LocationIdentifier - Where the unit was summoned
static func trigger_on_ally_summon(summoned_uuid: String, summoned_team: String, summoned_location: LocationIdentifier) -> void:
	# FIELD ONLY FILTER: Only trigger if the unit is in a lineup (battlefield)
	# This prevents Warden from blessing units summoned to the shelf
	if is_instance_valid(summoned_location):
		var container := summoned_location.container
		if container != C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP and container != C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
			return
	
	var summon_context := TriggerContext.new()
	summon_context.summoned_uuid = summoned_uuid
	summon_context.summoned_team = summoned_team
	AbilityResolver.process_trigger(C.TRIGGER_WHEN_ALLY_SUMMONED, summon_context)

## Trigger on_ally_hurt for all allies on the same team as the victim
## This enables reactive abilities that watch for teammates getting hurt
## @param damaged_unit_uuid: String - The UUID of the unit that got hurt
## @param damage_amount: int - The amount of damage taken
## @param attacker_uuid: String - The UUID of the attacker
## @param victim_team: String - "PLAYER" or "ENEMY"
## @param victim_slot_index: int - The slot index of the victim (for position-based abilities)
static func trigger_on_ally_hurt(damaged_unit_uuid: String, damage_amount: int, attacker_uuid: String, victim_team: String, victim_slot_index: int) -> void:
	var ally_hurt_context := TriggerContext.new()
	ally_hurt_context.damaged_uuid = damaged_unit_uuid
	ally_hurt_context.damage_taken = damage_amount
	ally_hurt_context.attacker_uuid = attacker_uuid
	ally_hurt_context.damaged_team = victim_team
	ally_hurt_context.damaged_slot_index = victim_slot_index
	AbilityResolver.process_trigger(C.TRIGGER_WHEN_ALLY_TAKES_DAMAGE, ally_hurt_context)

## Trigger on_healed when a unit's HP increases (healed by any means)
## This enables abilities that react when the unit itself is healed
## @param healed_uuid: String - The UUID of the unit that was healed
## @param heal_amount: int - The amount of HP restored
## @param healer_uuid: String - The UUID of the healer (may be empty for passive healing)
static func trigger_on_healed(healed_uuid: String, heal_amount: int, healer_uuid: String) -> void:
	var healed_context := TriggerContext.new()
	healed_context.healed_uuid = healed_uuid
	healed_context.heal_amount = heal_amount
	healed_context.healer_uuid = healer_uuid
	AbilityResolver.process_trigger(C.TRIGGER_WHEN_HEALED, healed_context)
