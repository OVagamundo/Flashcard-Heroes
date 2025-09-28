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

	if trigger == &"on_hurt":
		print("[DEBUG] AbilityResolver processing on_hurt trigger with context: ", context)
		# Debug: List all equipped items
		var damaged_unit_uuid = context.get("source_uuid", "")
		var damaged_unit = battle_manager.get_instance_by_uuid(damaged_unit_uuid)
		if is_instance_valid(damaged_unit):
			print("[DEBUG] Damaged unit equipped items: ", damaged_unit.equipped_item_uuids)
			for item_uuid in damaged_unit.equipped_item_uuids:
				if not item_uuid.is_empty():
					var item = battle_manager.get_instance_by_uuid(item_uuid)
					if is_instance_valid(item):
						print("[DEBUG] Equipped item: ", item_uuid, " definition: ", item.get_definition().id)

	# Process abilities in stacking order: Units first, then equipped items, then trinkets
	var all_instances = battle_manager.get_all_instances()
	
	# Phase 1: Process unit abilities first (for proper stacking order)
	# Note: for on_hurt we strictly filter to the damaged unit to avoid cross-unit triggers.
	for instance_uuid in all_instances:
		var instance = all_instances.get(instance_uuid)
		if not is_instance_valid(instance):
			continue
		var definition = instance.get_definition()
		if not is_instance_valid(definition) or not ("ability_definitions" in definition):
			continue
		if definition.ability_definitions.is_empty():
			continue
		
		# Only process units in this phase
		if definition.category == &"UNIT":
			# For on_hurt triggers, only process if this is the unit that took damage
			if trigger == &"on_hurt":
				var damaged_unit_uuid = context.get("source_uuid", "")
				if instance_uuid != damaged_unit_uuid:
					continue
			
			for ability in definition.ability_definitions:
				if ability.trigger == trigger:
					if trigger == &"on_hurt":
						print("[DEBUG] Found on_hurt ability on damaged unit: ", instance_uuid, " definition: ", definition.id)
					_process_ability(ability, instance_uuid, battle_manager, context)
	
	# Phase 2: Process equipped item abilities (in slot order for deterministic stacking)
	# We collect and sort by equipped_slot_index to ensure a stable, predictable order of activation.
	# Collect all equipped items that match the trigger
	var equipped_items_to_process = []
	for instance_uuid in all_instances:
		var instance = all_instances.get(instance_uuid)
		if not is_instance_valid(instance):
			continue
		var definition = instance.get_definition()
		if not is_instance_valid(definition) or not ("ability_definitions" in definition):
			continue
		if definition.ability_definitions.is_empty():
			continue
		
		# Only collect equipped items in this phase
		if definition.category == &"ITEM" and not instance.equipped_on_uuid.is_empty():
			# For on_hurt triggers, only process if the item is equipped to the unit that took damage
			if trigger == &"on_hurt":
				var damaged_unit_uuid = context.get("source_uuid", "")
				if instance.equipped_on_uuid != damaged_unit_uuid:
					continue
			
			# Check if this item has abilities for this trigger
			var has_matching_ability = false
			for ability in definition.ability_definitions:
				if ability.trigger == trigger:
					has_matching_ability = true
					break
			
			if has_matching_ability:
				equipped_items_to_process.append({
					"instance_uuid": instance_uuid,
					"instance": instance,
					"definition": definition,
					"slot_index": instance.equipped_slot_index
				})
	
	# Sort by slot index to ensure deterministic order
	equipped_items_to_process.sort_custom(func(a, b): return a.slot_index < b.slot_index)
	
	# Process equipped items in slot order
	for item_data in equipped_items_to_process:
		var instance_uuid = item_data.instance_uuid
		var instance = item_data.instance
		var definition = item_data.definition
		
		print("[DEBUG] Processing equipped item: ", instance_uuid, " definition: ", definition.id, " equipped to: ", instance.equipped_on_uuid, " slot: ", instance.equipped_slot_index)
		for ability in definition.ability_definitions:
			if ability.trigger == trigger:
				print("[DEBUG] Processing equipped item ability: ", ability.id, " for item: ", instance_uuid)
				_process_ability(ability, instance_uuid, battle_manager, context)
	
	# Phase 3: Process trinket abilities
	# Player trinkets: source is the Hero; Enemy trinkets: source depends on trigger context.
	for instance_uuid in all_instances:
		var instance = all_instances.get(instance_uuid)
		if not is_instance_valid(instance):
			continue
		var definition = instance.get_definition()
		if not is_instance_valid(definition) or not ("ability_definitions" in definition):
			continue
		if definition.ability_definitions.is_empty():
			continue
		
		# Only process trinkets in this phase
		if definition.category == &"TRINKET":
			for ability in definition.ability_definitions:
				if ability.trigger == trigger:
					if trigger == &"on_hurt":
						print("[DEBUG] Found on_hurt ability on trinket: ", instance_uuid, " definition: ", definition.id)
					
					# Apply trinket source rules per AbilitySystem.md
					var source_uuid_for_ability = instance_uuid
					var source_instance = battle_manager.get_instance_by_uuid(instance_uuid)
					print("[DEBUG] Trinket source resolution for: ", instance_uuid)
					if is_instance_valid(source_instance):
						print("[DEBUG] Trinket container: ", source_instance.location_container_tag)
						if source_instance.location_container_tag == battle_manager.BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS:
							# Player trinkets: Hero is always the source
							var hero_uuid = battle_manager.get_hero_uuid()
							print("[DEBUG] Player trinket - Hero UUID: '", hero_uuid, "'")
							if not hero_uuid.is_empty():
								source_uuid_for_ability = hero_uuid
							else:
								print("[DEBUG] WARNING: Hero UUID is empty for player trinket!")
						else:
							# Enemy trinkets: source depends on trigger context
							if context.has("source_uuid"):
								source_uuid_for_ability = context.get("source_uuid")
								print("[DEBUG] Enemy trinket - using context source: ", source_uuid_for_ability)
							else:
								# For global triggers, use first enemy unit as source for targeting
								var enemy_units = battle_manager.get_instances_in_container(battle_manager.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
								if not enemy_units.is_empty():
									source_uuid_for_ability = enemy_units[0].ball_uuid
									print("[DEBUG] Enemy trinket - using first enemy as source: ", source_uuid_for_ability)
								else:
									source_uuid_for_ability = ""
									print("[DEBUG] Enemy trinket - no enemy units found, using empty source")
					else:
						print("[DEBUG] WARNING: Invalid trinket source instance for: ", instance_uuid)
					
					_process_ability(ability, source_uuid_for_ability, battle_manager, context)


## Process a single ability and create EffectRequests for its effects.
## @param ability: AbilityDefinition - The ability to process
## @param source_uuid: String - The UUID of the source instance
## @param battle_manager: Node - The current battle manager
func _process_ability(ability: AbilityDefinition, source_uuid: String, battle_manager: Node, context: Dictionary) -> void:
	print("[DEBUG] _process_ability called for ability: ", ability.id, " source: ", source_uuid)
	
	# Loop prevention for counter-attacks: prevent infinite ping-pong counters
	# Track counter-attacks per attacker to allow countering different attackers
	if ability.id.contains("counter"):
		var attacker_uuid = context.get("attacker_uuid", "")
		if not attacker_uuid.is_empty():
			# Check if this unit has already counter-attacked this specific attacker
			if battle_manager.has_counter_attacked(source_uuid, attacker_uuid):
				print("[DEBUG] Skipping counter-attack - already countered this attacker: ", ability.id, " attacker: ", attacker_uuid)
				return
			
			# Mark this attacker as countered by this unit
			battle_manager.mark_counter_attack(source_uuid, attacker_uuid)
	
	# Check condition if present
	if is_instance_valid(ability.condition):
		var condition_result = battle_manager.check_condition(ability.condition, source_uuid, context)
		print("[DEBUG] Condition check for ", ability.condition.condition_type, " result: ", condition_result)
		if not condition_result:
			print("[DEBUG] Condition failed, skipping ability: ", ability.id)
			return  # Condition failed, skip this ability
	
	# Process each effect in the ability
	for effect in ability.effects:
		if not is_instance_valid(effect):
			continue
		
		# Resolve targets for this effect
		var resolved_targets: Array[String] = battle_manager.resolve_target(source_uuid, effect.target_type, context)
		print("[DEBUG] AbilityResolver effect: ", effect, " target_type: ", effect.target_type, " resolved_targets: ", resolved_targets)
		
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
			effect_context
		)
		
		# Enqueue the request
		battle_manager.enqueue_effect_request(effect_request)
