# res://scripts/AbilityResolver.gd
extends Node

## A stateless service that acts as the central coordinator for the ability system.
## Its primary responsibility is to translate game events into EffectRequests.

const C = preload("res://scripts/Constants.gd")

# =============================================================================
# UNIFIED FILTER SYSTEM
# These helpers centralize trigger-based filtering. BattleManager broadcasts
# ONE event per occurrence; these filters determine which instances respond.
# =============================================================================

## Determine team from instance's container location.
## @param instance: The GachaBallInstance to check
## @param battle_manager: Reference to BattleManager for container tags
## @return "PLAYER", "ENEMY", or "" if unknown
func _get_instance_team(instance: GachaBallInstance, battle_manager: Node) -> String:
	assert(is_instance_valid(instance), "AbilityResolver: instance must be valid")
	var container = instance.location_container_tag
	if container == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP:
		return "PLAYER"
	elif container == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
		return "ENEMY"
	elif container == C.BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS:
		return "PLAYER"
	elif container == C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS:
		return "ENEMY"
	return ""

## Unified filter: Should this unit respond to this trigger?
## Called once per unit per trigger broadcast.
## @param trigger: The trigger type being processed
## @param unit_uuid: UUID of the unit being checked
## @param unit: The GachaBallInstance
## @param context: Trigger context with semantic keys
## @param battle_manager: Reference to BattleManager
## @return true if this unit should process abilities for this trigger
func _should_unit_respond(trigger: StringName, unit_uuid: String, unit: GachaBallInstance,
						  context: Dictionary, battle_manager: Node) -> bool:
	match trigger:
		&"on_ally_death":
			# Unit must be: same team as fainting, alive, not the fainting unit
			var fainting_uuid = context.get("fainting_ally_uuid", "")
			var fainting_team = context.get("fainting_ally_team", "")
			var unit_team = _get_instance_team(unit, battle_manager)
			return unit_team == fainting_team and unit_uuid != fainting_uuid and unit.current_hp > 0
		
		&"on_hurt":
			# Only the unit that received damage responds
			return unit_uuid == context.get("victim_uuid", "")
		
		&"on_death":
			# Only the dying unit responds
			return unit_uuid == context.get("dying_uuid", "")
		
		&"on_attack", &"on_kill", &"on_damage_dealt":
			# Only the attacker responds
			return unit_uuid == context.get("attacker_uuid", "")
		
		&"on_before_damage":
			# Only the unit about to receive attack damage responds
			return unit_uuid == context.get("defender_uuid", "")
		
		&"on_turn_start", &"on_turn_end", &"on_battle_start":
			# All living units respond
			return unit.current_hp > 0
		
		&"on_enemy_summon":
			# Only units on the OPPOSING team of the summoned unit respond
			var summoned_team = context.get("summoned_team", "")
			var unit_team = _get_instance_team(unit, battle_manager)
			# Unit must be alive and on the opposite team
			return unit.current_hp > 0 and unit_team != "" and unit_team != summoned_team
		
		&"on_ally_summon":
			# Only units on the SAME team as the summoned unit respond
			var summoned_team = context.get("summoned_team", "")
			var unit_team = _get_instance_team(unit, battle_manager)
			# Unit must be alive, on the same team, and NOT the summoned unit itself
			var summoned_uuid = context.get("summoned_uuid", "")
			return unit.current_hp > 0 and unit_team != "" and unit_team == summoned_team and unit_uuid != summoned_uuid
		
		&"on_draw":
			# Enemy units respond to player draws (draws benefit enemies)
			# AND the drawn unit itself responds (for initialization effects like Merchant)
			var unit_team = _get_instance_team(unit, battle_manager)
			var drawn_uuid = context.get("drawn_uuid", "")
			
			if unit_uuid == drawn_uuid:
				return true # Self-trigger
				
			return unit.current_hp > 0 and unit_team == "ENEMY"
		
		&"on_token_spent":
			# Only enemy units respond to player token spending
			var unit_team = _get_instance_team(unit, battle_manager)
			return unit.current_hp > 0 and unit_team == "ENEMY"
		
		&"on_ally_hurt":
			# Teammates of the hurt unit respond (not the hurt unit itself)
			var victim_uuid = context.get("victim_uuid", "")
			var victim_team = context.get("victim_team", "")
			var unit_team = _get_instance_team(unit, battle_manager)
			# Must be alive, same team as victim, not the victim itself
			return unit.current_hp > 0 and unit_team == victim_team and unit_uuid != victim_uuid
		
		&"on_healed":
			# Only the healed unit itself responds to its own healing
			var healed_uuid = context.get("healed_uuid", "")
			return unit.current_hp > 0 and unit_uuid == healed_uuid
		
		&"on_gacha_tokens_changed":
			# All living units respond to token changes
			return unit.current_hp > 0
	
	# Default: respond (for any new triggers)
	return true

## Unified filter: Should this equipped item respond to this trigger?
## @param trigger: The trigger type being processed
## @param item: The equipped item instance
## @param context: Trigger context with semantic keys
## @return true if this item should process abilities for this trigger
func _should_item_respond(trigger: StringName, item: GachaBallInstance, context: Dictionary) -> bool:
	var holder_uuid = item.equipped_on_uuid
	assert(not holder_uuid.is_empty(), "AbilityResolver: item must be equipped")
	
	match trigger:
		&"on_hurt":
			return holder_uuid == context.get("victim_uuid", "")
		
		&"on_death":
			return holder_uuid == context.get("dying_uuid", "")
		
		&"on_attack", &"on_kill", &"on_damage_dealt":
			return holder_uuid == context.get("attacker_uuid", "")
		
		&"on_before_damage":
			return holder_uuid == context.get("defender_uuid", "")
		
		&"on_ally_death":
			# Items on living allies respond (not on the dying unit)
			var fainting_uuid = context.get("fainting_ally_uuid", "")
			return holder_uuid != fainting_uuid
		
		&"on_turn_start", &"on_turn_end", &"on_battle_start":
			# All equipped items on living holders respond
			return true
		
		&"on_damage_dealt":
			# Only items equipped on the attacker respond (for lifesteal effects)
			var attacker_uuid = context.get("attacker_uuid", "")
			return holder_uuid == attacker_uuid
		
		&"on_draw":
			# Items don't respond to on_draw - only trinkets do
			return false
	
	return true

## Unified filter: Should this trinket respond to this trigger?
## @param trigger: The trigger type being processed
## @param trinket: The trinket instance
## @param context: Trigger context with semantic keys
## @param battle_manager: Reference to BattleManager
## @return true if this trinket should process abilities for this trigger
func _should_trinket_respond(trigger: StringName, trinket: GachaBallInstance,
							 context: Dictionary, battle_manager: Node) -> bool:
	var trinket_team = _get_instance_team(trinket, battle_manager)
	var trinket_def = trinket.get_definition()
	var trinket_name = trinket_def.name_key if is_instance_valid(trinket_def) else "Unknown"
	
	match trigger:
		&"on_ally_death":
			# Trinkets only respond to deaths on their own team
			var fainting_team = context.get("fainting_ally_team", "")
			return trinket_team == fainting_team
		
		&"on_turn_start", &"on_turn_end", &"on_battle_start":
			# All trinkets respond
			return true
		
		&"on_draw":
			# Only player trinkets respond to player draws
			# (enemies don't draw, so this is always player team for now)
			return trinket_team == "PLAYER"
	
	# For other triggers, trinkets respond based on team context if available
	return true

# =============================================================================
# MAIN TRIGGER PROCESSING
# =============================================================================

## Process a trigger event and generate EffectRequests for all matching abilities.
##
## UNIFIED BROADCAST PATTERN: BattleManager calls this ONCE per event.
## AbilityResolver self-filters to determine which instances respond.
##
## Ordering contract (docs/AbilitySystem.md):
## 1) Units first
## 2) Equipped Items second (sorted by slot index)
## 3) Trinkets last
##
## @param trigger: StringName - The trigger type (e.g., "on_attack", "on_death")
## @param context: Dictionary - The context with semantic keys (e.g., victim_uuid, attacker_uuid)
func process_trigger(trigger: StringName, context: Dictionary) -> void:
	# Add trigger_type to context so it flows through to CombatEvents
	context["trigger_type"] = trigger
	
	# Get the current BattleManager
	var battle_manager = get_tree().get_first_node_in_group("battle_manager")
	assert(is_instance_valid(battle_manager), "AbilityResolver: BattleManager not found")

	# Optimization: Single pass to bucket all instances by category
	var all_instances = battle_manager.get_all_instances()
	
	var unit_instances: Array[Dictionary] = []
	var equipped_item_instances: Array[Dictionary] = []
	var trinket_instances: Array[Dictionary] = []

	for instance_uuid in all_instances:
		var instance = all_instances.get(instance_uuid)
		if not is_instance_valid(instance):
			continue
		var definition = instance.get_definition()
		if not is_instance_valid(definition) or not ("ability_definitions" in definition):
			continue
		if definition.ability_definitions.is_empty():
			continue

		if definition.category == &"UNIT":
			unit_instances.append({"uuid": instance_uuid, "inst": instance, "def": definition})
		elif definition.category == &"ITEM" and not instance.equipped_on_uuid.is_empty():
			# Use unified filter to check if item should respond
			if not _should_item_respond(trigger, instance, context):
				continue
			# Check if item has matching ability for this trigger
			var has_matching = false
			for ability in definition.ability_definitions:
				if ability.trigger == trigger:
					has_matching = true
					break
			if has_matching:
				equipped_item_instances.append({
					"instance_uuid": instance_uuid,
					"instance": instance,
					"definition": definition,
					"slot_index": instance.equipped_slot_index
				})
		elif definition.category == &"TRINKET":
			trinket_instances.append({"uuid": instance_uuid, "inst": instance, "def": definition})

	# Phase 1: Process unit abilities
	for data in unit_instances:
		var instance_uuid: String = data.uuid
		var instance: GachaBallInstance = data.inst
		var definition = data.def
		
		# Use unified filter
		if not _should_unit_respond(trigger, instance_uuid, instance, context, battle_manager):
			continue

		for ability in definition.ability_definitions:
			if ability.trigger == trigger:
				_process_ability(ability, instance_uuid, battle_manager, context)


	# Phase 2: Process equipped item abilities (sorted by slot for deterministic order)
	equipped_item_instances.sort_custom(func(a, b): return a.slot_index < b.slot_index)
	
	for item_data in equipped_item_instances:
		var instance_uuid: String = item_data.instance_uuid
		var definition = item_data.definition
		
		for ability in definition.ability_definitions:
			if ability.trigger == trigger:
				_process_ability(ability, instance_uuid, battle_manager, context)

	# Phase 3: Process trinket abilities
	for data in trinket_instances:
		var instance_uuid: String = data.uuid
		var instance: GachaBallInstance = data.inst
		var definition = data.def
		
		# Use unified filter
		if not _should_trinket_respond(trigger, instance, context, battle_manager):
			continue
		
		# Add trinket's team to context for effects that need it
		var trinket_team = _get_instance_team(instance, battle_manager)
		var trinket_context = context.duplicate()
		trinket_context["team"] = trinket_team
		
		for ability in definition.ability_definitions:
			if ability.trigger == trigger:
				# Trinkets are team-based, not unit-based. The trinket itself is the source.
				# This avoids dead-unit edge cases and is semantically correct.
				_process_ability(ability, instance_uuid, battle_manager, trinket_context)


## Process a single ability and create EffectRequests for its effects.
## @param source_uuid: String - The UUID of the source instance
## @param battle_manager: Node - The current battle manager
func _process_ability(ability: AbilityDefinition, source_uuid: String, battle_manager: Node, context: Dictionary) -> void:
	# Check if source is dead and ability doesn't allow lethal execution
	# ONLY for UNITS - items and trinkets don't have HP
	if not source_uuid.is_empty():
		var source = battle_manager.get_instance_by_uuid(source_uuid)
		if is_instance_valid(source):
			var source_def = source.get_definition()
			# Only check HP for UNIT category - items/trinkets don't have meaningful HP
			if is_instance_valid(source_def) and source_def.category == &"UNIT":
				if source.current_hp <= 0:
					# Source unit is dead - only allow if execute_on_lethal is true
					if not ability.execute_on_lethal:
						return
	
	# Check condition if present
	if is_instance_valid(ability.condition):
		var condition_result = battle_manager.check_condition(ability.condition, source_uuid, context)
		if not condition_result:
			return # Condition failed, skip this ability
	
	var ability_activated := false
	
	# Process each effect in the ability
	for effect in ability.effects:
		if not is_instance_valid(effect):
			continue
		
		# Resolve targets for this effect
		var resolved_targets: Array[String] = battle_manager.resolve_target(source_uuid, effect.target_type, context)
		
		# If we found valid targets, mark ability as activated
		if not resolved_targets.is_empty():
			ability_activated = true
		
		# Create EffectRequest
		# For counter-attack abilities, mark the context to identify counter-attack effects
		var effect_context = context.duplicate()
		if ability.id.contains("counter"):
			effect_context["is_counter"] = true
		
		var effect_request = EffectRequest.new(
			source_uuid,
			ability.id,
			effect,
			resolved_targets,
			effect_context,
			ability.priority # Pass priority from ability definition
		)
		
		# Enqueue the request
		battle_manager.enqueue_effect_request(effect_request)

	# If ability successfully activated (found targets) AND it replaces basic attack, set flag
	# This ensures we fallback to basic attack if the special ability fails to find a target (e.g. empty mirror slot)
	if ability_activated and ability.get("replaces_basic_attack") and context.get("trigger_type") == &"on_attack":
		context["attack_replaced"] = true
