# res://scripts/battle/commands/TransformCommand.gd
class_name TransformCommand
extends CombatCommand

## Handles unit transformation (transform_request).
## Used by Mimic and similar transforming units.

const C = preload("res://scripts/Constants.gd")
const EffectHandlers = preload("res://scripts/battle/EffectHandlers.gd")

var transform_request: Dictionary

func _init(p_request: EffectRequest, p_combat_sim: CombatSimulator, p_bm: Node, p_transform_request: Dictionary) -> void:
	super._init(p_request, p_combat_sim, p_bm)
	transform_request = p_transform_request

func execute(out_events: Array[CombatEvent], death_tracking: Dictionary) -> void:
	var transform_result := EffectHandlers.handle_mirror_transform(request, transform_request, battle_manager)
	battle_manager._apply_summon_result(transform_result)
	out_events.append_array(transform_result.events)
	
	# If this transformation happened during a unit's active turn (i.e. replacing the basic attack)
	# We want the newly spawned unit to immediately take a turn
	if transform_result.new_instances.size() > 0:
		var new_inst = transform_result.new_instances[0]
		if is_instance_valid(new_inst) and is_instance_valid(combat_sim._current_acting_unit):
			if combat_sim._current_acting_unit.ball_uuid == request.source_uuid:
				combat_sim._actor_queue.push_front(new_inst)
	
	# A transformation counts as a summon for reaction purposes
	combat_sim._trigger_summon_reactions_for_result(transform_result, out_events, battle_manager)
	
	battle_manager._check_for_deaths_with_counter_delay(true, out_events, death_tracking)
