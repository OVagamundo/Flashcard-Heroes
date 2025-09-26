# res://scripts/AbilityResolver.gd
extends Node

## A stateless service that acts as the central coordinator for the ability system.
## Its primary responsibility is to translate game events into EffectRequests.

## Process a trigger event and generate EffectRequests for all matching abilities.
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

	# Loop 1: GachaBallInstances (Units & Equipped Items)
	var all_instances = battle_manager.get_all_instances()
	for instance_uuid in all_instances:
		var instance = all_instances.get(instance_uuid)
		if not is_instance_valid(instance):
			continue
		var definition = instance.get_definition()
		if not is_instance_valid(definition) or not ("ability_definitions" in definition):
			continue
		if definition.ability_definitions.is_empty():
			continue
		
		# For equipped items with on_hurt triggers, only process if the item is equipped to the unit that took damage
		if definition.category == &"ITEM" and trigger == &"on_hurt":
			var damaged_unit_uuid = context.get("source_uuid", "")
			if not instance.equipped_on_uuid.is_empty() and instance.equipped_on_uuid == damaged_unit_uuid:
				if trigger == &"on_hurt":
					print("[DEBUG] Found on_hurt ability on equipped item: ", instance_uuid, " definition: ", definition.id, " equipped to: ", damaged_unit_uuid)
				for ability in definition.ability_definitions:
					if ability.trigger == trigger:
						print("[DEBUG] Processing equipped item ability: ", ability.id, " for item: ", instance_uuid)
						print("[DEBUG] Item equipped_on_uuid: ", instance.equipped_on_uuid, " equipped_slot_index: ", instance.equipped_slot_index)
						_process_ability(ability, instance_uuid, battle_manager, context)
		else:
			# Process abilities normally for units, trinkets, and other triggers
			for ability in definition.ability_definitions:
				if ability.trigger == trigger:
					if trigger == &"on_hurt":
						print("[DEBUG] Found on_hurt ability on instance: ", instance_uuid, " definition: ", definition.id)
					
					# Apply trinket source rules per AbilitySystem.md
					var source_uuid_for_ability = instance_uuid
					if definition.category == &"TRINKET":
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
		var effect_request = EffectRequest.new(
			source_uuid,
			ability.id,
			effect,
			resolved_targets,
			context
		)
		
		# Enqueue the request
		battle_manager.enqueue_effect_request(effect_request)
