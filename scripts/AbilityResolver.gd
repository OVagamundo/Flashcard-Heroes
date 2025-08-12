# res://scripts/AbilityResolver.gd
extends Node

## A stateless service that acts as the central coordinator for the ability system.
## Its primary responsibility is to translate game events into EffectRequests.

## Process a trigger event and generate EffectRequests for all matching abilities.
## @param trigger: StringName - The trigger type (e.g., "on_attack", "on_death")
## @param context: Dictionary - The context of the event (e.g., {"source_uuid": "...", "target_uuid": "..."})
func process_trigger(trigger: StringName, context: Dictionary):
	# Get the current BattleManager
	var battle_manager = get_tree().get_first_node_in_group("battle_manager")
	if not is_instance_valid(battle_manager):
		return
	
	# Get all live instances that have abilities matching the trigger
	var all_instances = battle_manager.get_all_instances()
	
	for instance_uuid in all_instances:
		var instance = all_instances[instance_uuid]
		if not is_instance_valid(instance):
			continue
		
		# Check if this instance has abilities
		var definition = instance.get_definition()
		if not is_instance_valid(definition) or not definition.ability_definitions:
			continue
		
		# Check each ability for matching trigger
		for ability in definition.ability_definitions:
			if ability.trigger == trigger:
				_process_ability(ability, instance_uuid, battle_manager, context)

## Process a single ability and create EffectRequests for its effects.
## @param ability: AbilityDefinition - The ability to process
## @param source_uuid: String - The UUID of the source instance
## @param battle_manager: Node - The current battle manager
## @param context: Dictionary - The event context
func _process_ability(ability: AbilityDefinition, source_uuid: String, battle_manager: Node, context: Dictionary):
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
