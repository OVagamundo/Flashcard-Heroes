# res://scripts/battle/commands/CascadeCommand.gd
class_name CascadeCommand
extends CombatCommand

## Handles EffectResult.cascade_request — AOE shockwave damage.
## TWO-PHASE PROCESSING for visual "wave" effect:
##   Phase 1: Apply all damage + DAMAGE events in sequence
##   Phase 2: Process all reactions (counter-attacks, on_kill) one target at a time

const C = preload("res://scripts/Constants.gd")

var cascade_request: EffectResult.CascadeRequest

func _init(p_request: EffectRequest, p_combat_sim: CombatSimulator, p_bm: Node, p_cascade_request: EffectResult.CascadeRequest) -> void:
	super._init(p_request, p_combat_sim, p_bm)
	cascade_request = p_cascade_request

func execute(out_events: Array[CombatEvent], death_tracking: Dictionary) -> void:
	var source: GachaBallInstance = battle_manager.get_instance_by_uuid(request.source_uuid)
	
	# Phase 1: Apply all damage via EffectHandlers
	var cascade_result := EffectHandlers.handle_cascade_damage(request, cascade_request, source, battle_manager)
	out_events.append_array(cascade_result.events)
	
	# Phase 2: Process reactions one target at a time (after all damage shown).
	# Spikes is applied during Phase 1 too, so it must raise its own on_hurt
	# reaction before lethal deaths are finalized.
	var reflected_hurt_start = combat_sim._pending_reactions.size()
	for reflected_hit in cascade_result.reflected_hits:
		battle_manager.trigger_on_hurt(
			reflected_hit.target_uuid,
			reflected_hit.damage_amount,
			reflected_hit.source_uuid,
			C.CAUSE_ABILITY,
			&"",
			false
		)
	combat_sim.drain_reactions_inline(reflected_hurt_start, battle_manager)
	out_events.append_array(combat_sim.collect_and_clear_inline_events())

	for reflected_hit in cascade_result.reflected_hits:
		var reflected_target = battle_manager.get_instance_by_uuid(reflected_hit.target_uuid)
		if is_instance_valid(reflected_target) and reflected_target.current_hp <= 0:
			battle_manager.trigger_on_kill(reflected_hit.source_uuid, reflected_hit.target_uuid)

	for hit_data in cascade_result.hit_targets:
		var target_uuid: String = hit_data.uuid
		var damage_amount: int = hit_data.amount
		var was_killed: bool = hit_data.was_killed
		
		# Trigger on_hurt for counter-attacks
		var cascade_hurt_start = combat_sim._pending_reactions.size()
		battle_manager.trigger_on_hurt(target_uuid, damage_amount, request.source_uuid, C.CAUSE_ABILITY)
		
		# Drain on_hurt reactions for THIS target
		combat_sim.drain_reactions_inline(cascade_hurt_start, battle_manager)
		var cascade_hurt_inline_evts = combat_sim.collect_and_clear_inline_events()
		out_events.append_array(cascade_hurt_inline_evts)
		
		# Trigger on_kill if killed
		if was_killed:
			battle_manager.trigger_on_kill(request.source_uuid, target_uuid)
	
	# Check for deaths after cascade
	battle_manager._check_for_deaths_with_counter_delay(true, out_events, death_tracking)
