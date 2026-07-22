# res://scripts/battle/commands/SummonUnitsCommand.gd
class_name SummonUnitsCommand
extends CombatCommand

## Handles multiple unit summons (summon_units_request).
## Used primarily by Boss encounters.

const C = preload("res://scripts/Constants.gd")
const EffectHandlers = preload("res://scripts/battle/EffectHandlers.gd")

var summon_units_request: Dictionary

func _init(p_request: EffectRequest, p_combat_sim: CombatSimulator, p_bm: Node, p_effect_result: EffectResult) -> void:
	super._init(p_request, p_combat_sim, p_bm)
	# EffectHandlers expects the raw dictionary containing "summon_units"
	summon_units_request = {"summon_units": p_effect_result.summon_units_request}

func execute(out_events: Array[CombatEvent], death_tracking: Dictionary) -> void:
	var summon_result := EffectHandlers.handle_summon_units(request, summon_units_request, battle_manager)
	battle_manager._apply_summon_result(summon_result)
	out_events.append_array(summon_result.events)
	
	# Trigger on_enemy_summon or on_ally_summon for each new unit
	combat_sim._trigger_summon_reactions_for_result(summon_result, out_events, battle_manager)
	
	battle_manager._check_for_deaths_with_counter_delay(true, out_events, death_tracking)
