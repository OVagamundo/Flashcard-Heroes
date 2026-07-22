# res://scripts/battle/commands/DamageCommand.gd
class_name DamageCommand
extends CombatCommand

## Handles EffectResult.damage_request — delegated damage through the proper pipeline.
## Preserves: on_before_damage triggers, queue draining, armor/burn/guardian handling,
## on_hurt/on_kill triggers, and death checks.

const C = preload("res://scripts/Constants.gd")

var damage_request: EffectResult.DamageRequest

func _init(p_request: EffectRequest, p_combat_sim: CombatSimulator, p_bm: Node, p_damage_request: EffectResult.DamageRequest) -> void:
	super._init(p_request, p_combat_sim, p_bm)
	damage_request = p_damage_request

func execute(out_events: Array[CombatEvent], death_tracking: Dictionary) -> void:
	var amount: int = damage_request.amount
	var targets: Array = damage_request.targets
	
	if amount <= 0 or targets.is_empty():
		return
	
	var dmg_source: GachaBallInstance = battle_manager.get_instance_by_uuid(request.source_uuid)
	var resolved_targets: Array[String] = []
	var target_display_names: Array[String] = []
	for t in targets:
		var tgt = battle_manager.get_instance_by_uuid(String(t))
		resolved_targets.append(String(t))
		target_display_names.append(BattleHelpers.get_instance_display_name(tgt))
	
	var source_name := ""
	if is_instance_valid(dmg_source):
		source_name = BattleHelpers.get_instance_display_name(dmg_source)
	if source_name == "":
		source_name = String(request.ability_id)
	
	# CRITICAL: Trigger on_before_damage for each target BEFORE damage
	# This allows defensive abilities like Guardian's Defensive Stance to proc
	var on_before_damage_start_index = combat_sim._pending_reactions.size()
	
	for tgt_uuid in resolved_targets:
		var tgt = battle_manager.get_instance_by_uuid(tgt_uuid)
		if is_instance_valid(tgt) and tgt.current_hp > 0:
			var before_ctx := {
				"source_uuid": tgt_uuid,
				"defender_uuid": tgt_uuid,
				"attacker_uuid": request.source_uuid,
				"target_initial_hp": tgt.current_hp,
				"is_simulation": true
			}
			AbilityResolver.process_trigger(&"on_before_damage", before_ctx)
	
	# Drain on_before_damage reactions before damage is applied
	combat_sim.drain_reactions_inline(on_before_damage_start_index, battle_manager)
	var before_damage_evts = combat_sim.collect_and_clear_inline_events()
	out_events.append_array(before_damage_evts)
	
	var damage_result := EffectHandlers.handle_damage_effect(
		request, damage_request, dmg_source, source_name, target_display_names, battle_manager
	)
	out_events.append_array(damage_result.events)
	
	if damage_result.should_return:
		return
	
	# Trigger on_hurt for damaged units
	var on_hurt_start_index = combat_sim._pending_reactions.size()
	for tgt_uuid in damage_result.damaged_uuids:
		battle_manager.trigger_on_hurt(tgt_uuid, abs(amount), request.source_uuid, damage_request.cause)
	
	# Drain on_hurt reactions
	combat_sim.drain_reactions_inline(on_hurt_start_index, battle_manager)
	var hurt_inline_evts = combat_sim.collect_and_clear_inline_events()
	out_events.append_array(hurt_inline_evts)
	
	# Trigger on_kill for killed units
	for tgt_uuid in damage_result.damaged_uuids:
		var tgt = battle_manager.get_instance_by_uuid(tgt_uuid)
		if is_instance_valid(tgt) and tgt.current_hp <= 0:
			battle_manager.trigger_on_kill(request.source_uuid, tgt_uuid)
	
	# Death check
	battle_manager._check_for_deaths_with_counter_delay(true, out_events, death_tracking)
