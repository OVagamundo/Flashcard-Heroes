# res://scripts/EffectApplyStatus.gd
extends EffectDefinition

## An effect that applies status effects to targets.
## Parameters: {"status_id": StringName, "stacks": int} - The status effect ID and number of stacks

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, _context: Dictionary):
	if targets.is_empty() or not parameters.has("status_id"):
		return

	var source_instance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_instance):
		return

	var status_id = parameters["status_id"]
	var stacks = parameters.get("stacks", 1)
	
	# Apply status effect to all targets
	for target_uuid in targets:
		var target_instance = battle_manager.get_instance_by_uuid(target_uuid)
		if is_instance_valid(target_instance):
			# Add or update status effect
			if target_instance.status_effects.has(status_id):
				target_instance.status_effects[status_id] += stacks
			else:
				target_instance.status_effects[status_id] = stacks
			
			# Inform UI and log systems
			var src_name = tr(source_instance.get_definition().display_name_key)
			var tgt_name = tr(target_instance.get_definition().display_name_key)
			var status_name = tr("status." + status_id + ".name")
			var msg = "%s applies %s (%d) to %s" % [src_name, status_name, stacks, tgt_name]
			EventBus.battle_log_event.emit(msg)
			EventBus.unit_stats_changed.emit(target_instance.ball_uuid)

	EventBus.battle_inventory_changed.emit() 