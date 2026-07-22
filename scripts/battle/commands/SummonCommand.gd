# res://scripts/battle/commands/SummonCommand.gd
class_name SummonCommand
extends CombatCommand

## Handles single unit summons (summon_request).
## Triggers on_enemy_summon / on_ally_summon for reactions.

const C = preload("res://scripts/Constants.gd")
const EffectHandlers = preload("res://scripts/battle/EffectHandlers.gd")

var summon_request: Dictionary

func _init(p_request: EffectRequest, p_combat_sim: CombatSimulator, p_bm: Node, p_summon_request: Dictionary) -> void:
	super._init(p_request, p_combat_sim, p_bm)
	summon_request = p_summon_request

func execute(out_events: Array[CombatEvent], death_tracking: Dictionary) -> void:
	var summon_result := EffectHandlers.handle_summon_unit(request, summon_request, battle_manager)
	battle_manager._apply_summon_result(summon_result)
	out_events.append_array(summon_result.events)
	
	# Trigger on_enemy_summon or on_ally_summon for each new unit
	combat_sim._trigger_summon_reactions_for_result(summon_result, out_events, battle_manager)
	
	battle_manager._check_for_deaths_with_counter_delay(true, out_events, death_tracking)
