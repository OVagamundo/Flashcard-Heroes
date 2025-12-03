# res://scripts/AbilityResolver.gd
extends Node

## A stateless service that acts as the central coordinator for the ability system.
## Its primary responsibility is to translate game events into EffectRequests.

## Process a trigger event and generate EffectRequests for all matching abilities.
##
## Ordering & Filtering contract (kept in sync with docs/AbilitySystem.md & docs/CombatSystem.md):
## 1) Units first
##    - For on_hurt specifically, only the damaged unit (context.source_uuid) may process unit-level abilities.
## 2) Equipped Items second
##    - Only items actually equipped are eligible.
##    - For on_hurt, only items equipped on the damaged unit are eligible.
##    - Items are processed in ascending equipped_slot_index to make stacked effects deterministic.
## 3) Trinkets last
##    - Player trinkets source the Hero for targeting; enemy trinkets derive source from trigger context when available.
##
## Each matching ability produces a separate EffectRequest to preserve per-source visual events.
## @param trigger: StringName - The trigger type (e.g., "on_attack", "on_death")
## @param context: Dictionary - The context of the event (e.g., {"source_uuid": "...", "target_uuid": "..."})
func process_trigger(trigger: StringName, context: Dictionary) -> void:
	# Get the current BattleManager
	var battle_manager = get_tree().get_first_node_in_group("battle_manager")
	if not is_instance_valid(battle_manager):
		return

	# Process abilities in stacking order: Units first, then equipped items, then trinkets
	# Optimization: Iterate once and bucket instances to avoid O(3N) lookups.
	var all_instances = battle_manager.get_all_instances()
	# print("DEBUG: AbilityResolver processing trigger '", trigger, "' with ", all_instances.size(), " total instances")
	
	var unit_instances: Array[Dictionary] = []
	var equipped_item_instances: Array[Dictionary] = []
	var trinket_instances: Array[Dictionary] = []

	# Single pass to categorize all instances
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
			# Pre-filter items that don't match the trigger context to save processing
			if trigger == &"on_hurt":
				var damaged_unit_uuid = context.get("source_uuid", "")
				if instance.equipped_on_uuid != damaged_unit_uuid:
					continue
			elif trigger == &"on_attack":
				var attacking_unit_uuid = context.get("source_uuid", "")
				if instance.equipped_on_uuid != attacking_unit_uuid:
					continue
			elif trigger == &"on_death":
				# Only process items equipped on the dying unit
				var dying_unit_uuid = context.get("source_uuid", "")
				if instance.equipped_on_uuid != dying_unit_uuid:
					continue
			
			# Check if item has matching ability before adding
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
			# print("DEBUG: Found trinket: ", definition.id, " in container: ", instance.location_container_tag)
			trinket_instances.append({"uuid": instance_uuid, "inst": instance, "def": definition})

	# Phase 1: Process unit abilities
	for data in unit_instances:
		var instance_uuid = data.uuid
		var definition = data.def
		var instance = data.inst
		
		# For on_hurt triggers, only process if this is the unit that took damage
		if trigger == &"on_hurt":
			var damaged_unit_uuid = context.get("source_uuid", "")
			if instance_uuid != damaged_unit_uuid:
				continue
		# For on_ally_death, only process the specific ally this trigger was emitted for
		elif trigger == &"on_ally_death":
			var ally_uuid = context.get("source_uuid", "")
			if instance_uuid != ally_uuid:
				continue
		
		# General Rule: Dead units cannot trigger abilities (except on_death, on_ally_death, and on_hurt for counters)
		if instance.current_hp <= 0 and trigger != &"on_death" and trigger != &"on_ally_death" and trigger != &"on_hurt":
			continue
				
		for ability in definition.ability_definitions:
			if ability.trigger == trigger:
				_process_ability(ability, instance_uuid, battle_manager, context)

	# Phase 2: Process equipped item abilities (sorted by slot)
	equipped_item_instances.sort_custom(func(a, b): return a.slot_index < b.slot_index)
	
	for item_data in equipped_item_instances:
		var instance_uuid = item_data.instance_uuid
		var instance = item_data.instance
		var definition = item_data.definition
		
		for ability in definition.ability_definitions:
			if ability.trigger == trigger:
				var ability_source_uuid = instance.equipped_on_uuid if trigger == &"on_attack" else instance_uuid
				_process_ability(ability, ability_source_uuid, battle_manager, context)

	# Phase 3: Process trinket abilities
	# print("DEBUG: Processing ", trinket_instances.size(), " trinket abilities for trigger: ", trigger)
	for data in trinket_instances:
		var instance_uuid = data.uuid
		var instance = data.inst
		var definition = data.def
		# print("DEBUG: Checking trinket: ", definition.id, " UUID: ", instance_uuid)
		
		for ability in definition.ability_definitions:
			if ability.trigger == trigger:
				# print("DEBUG: Trinket ability match: ", ability.id)
				# Apply trinket source rules per AbilitySystem.md
				var source_uuid_for_ability = instance_uuid
				
				if instance.location_container_tag == battle_manager.BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS:
					var hero_uuid = battle_manager.get_hero_uuid()
					if not hero_uuid.is_empty():
						source_uuid_for_ability = hero_uuid
				else:
					if context.has("source_uuid"):
						source_uuid_for_ability = context.get("source_uuid")
					else:
						var enemy_units = battle_manager.get_instances_in_container(battle_manager.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
						if not enemy_units.is_empty():
							source_uuid_for_ability = enemy_units[0].ball_uuid
				
				_process_ability(ability, source_uuid_for_ability, battle_manager, context)

	# Debug logging for on_death trigger
	# if trigger == &"on_death":
	# 	print("[AbilityResolver] Finished processing on_death. Context: ", context)


## Process a single ability and create EffectRequests for its effects.
## @param source_uuid: String - The UUID of the source instance
## @param battle_manager: Node - The current battle manager
func _process_ability(ability: AbilityDefinition, source_uuid: String, battle_manager: Node, context: Dictionary) -> void:
	# Check condition if present
	if is_instance_valid(ability.condition):
		var condition_result = battle_manager.check_condition(ability.condition, source_uuid, context)
		if not condition_result:
			return # Condition failed, skip this ability
	
	# Process each effect in the ability
	for effect in ability.effects:
		if not is_instance_valid(effect):
			continue
		
		# Resolve targets for this effect
		var resolved_targets: Array[String] = battle_manager.resolve_target(source_uuid, effect.target_type, context)
		
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
