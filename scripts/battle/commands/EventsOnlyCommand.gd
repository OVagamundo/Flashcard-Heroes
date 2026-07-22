# res://scripts/battle/commands/EventsOnlyCommand.gd
class_name EventsOnlyCommand
extends CombatCommand

## Handles EffectResults that only contain events (no delegated damage/summon requests).
## Used by pre-built effects like BasicAttackEffect, EffectModifyStat, etc.
## Preserves the precise sequence of appending events, triggering on_hurt for recorded
## damaged units, triggering on_kill, and final death checks.

const C = preload("res://scripts/Constants.gd")

var effect_result: EffectResult

func _init(p_request: EffectRequest, p_combat_sim: CombatSimulator, p_bm: Node, p_effect_result: EffectResult) -> void:
	super._init(p_request, p_combat_sim, p_bm)
	effect_result = p_effect_result

func execute(out_events: Array[CombatEvent], death_tracking: Dictionary) -> void:
	out_events.append_array(effect_result.events)
	
	# Determine if any trigger fields are populated
	var has_damaged = not effect_result.damaged_uuids.is_empty()
	var has_killed = not effect_result.killed_uuids.is_empty()
	var has_healed = not effect_result.healed_events.is_empty()
	
	if has_damaged:
		var events_hurt_start = combat_sim._pending_reactions.size()
		for damaged_uuid in effect_result.damaged_uuids:
			var amount: int = effect_result.events[0].visual_payload.amount if not effect_result.events.is_empty() and effect_result.events[0].visual_payload != null else 0
			battle_manager.trigger_on_hurt(damaged_uuid, abs(amount), request.source_uuid, C.CAUSE_ABILITY)
		
		combat_sim.drain_reactions_inline(events_hurt_start, battle_manager)
		var events_hurt_inline_evts = combat_sim.collect_and_clear_inline_events()
		out_events.append_array(events_hurt_inline_evts)
		
	if has_killed:
		for target_uuid in effect_result.killed_uuids:
			var tgt = battle_manager.get_instance_by_uuid(target_uuid)
			if is_instance_valid(tgt) and tgt.current_hp <= 0:
				battle_manager.trigger_on_kill(request.source_uuid, target_uuid)
	
	if has_healed:
		for heal_data in effect_result.healed_events:
			var healed_uuid: String = heal_data.get("uuid", "")
			var amount: int = heal_data.get("amount", 0)
			# EffectResult stores these when mark_healed is called
			AbilityResolver.process_trigger(&"on_healed", {
				"healed_uuid": healed_uuid,
				"heal_amount": amount,
				"healer_uuid": request.source_uuid
			})
	
	# Death check (unless explicitly skipped, e.g. BasicAttackEffect handles its own death check routing sometimes,
	# though generally we want this to run unless an effect explicitly defers it)
	if not effect_result.skip_death_check:
		battle_manager._check_for_deaths_with_counter_delay(true, out_events, death_tracking)
