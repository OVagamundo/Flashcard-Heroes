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
		for ability in definition.ability_definitions:
			if ability.trigger == trigger:
				_process_ability(ability, instance_uuid, battle_manager, context)

	# Loop 2: Player Trinkets (only process in global calls, not unit-specific calls)
	if not context.has("source_uuid"):
		var player_trinkets = battle_manager.get_instances_in_container(battle_manager.BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS)
		for trinket_instance in player_trinkets:
			if not is_instance_valid(trinket_instance):
				continue
			var trinket_def = trinket_instance.get_definition()
			if is_instance_valid(trinket_def) and not trinket_def.ability_definitions.is_empty():
				for ability in trinket_def.ability_definitions:
					if ability.trigger == trigger:
						var new_context = context.duplicate(true)
						new_context["team"] = "PLAYER"
						print("[DEBUG] Processing player trinket ability: ", trinket_def.id, " trigger: ", trigger)
						_process_ability(ability, "", battle_manager, new_context)

		# Loop 3: Enemy Trinkets (only process in global calls, not unit-specific calls)
		if not battle_manager.enemy_trinkets.is_empty():
			for trinket_instance in battle_manager.enemy_trinkets:
				if not is_instance_valid(trinket_instance):
					continue
				var trinket_def = trinket_instance.get_definition()
				if is_instance_valid(trinket_def) and not trinket_def.ability_definitions.is_empty():
					for ability in trinket_def.ability_definitions:
						if ability.trigger == trigger:
							var new_context = context.duplicate(true)
							new_context["team"] = "ENEMY"
							print("[DEBUG] Processing enemy trinket ability: ", trinket_def.id, " trigger: ", trigger)
							_process_ability(ability, "", battle_manager, new_context)

## Process a single ability and create EffectRequests for its effects.
## @param ability: AbilityDefinition - The ability to process
## @param source_uuid: String - The UUID of the source instance
## @param battle_manager: Node - The current battle manager
func _process_ability(ability: AbilityDefinition, source_uuid: String, battle_manager: Node, context: Dictionary) -> void:
	# Check condition if present
	if is_instance_valid(ability.condition):
		if not battle_manager.check_condition(ability.condition, source_uuid, context):
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
