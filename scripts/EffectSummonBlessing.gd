# res://scripts/EffectSummonBlessing.gd
@tool
class_name EffectSummonBlessing
extends EffectDefinition

## Effect that buffs a newly summoned ally unit with HP.
## Used by the Tier 3 F unit's "Summon Blessing" ability.
##
## Parameters:
##   - hp_amount: int - Amount of HP to grant to the summoned unit (default 3)
##
## Context expected:
##   - summoned_uuid: String - UUID of the newly summoned unit

func execute(source_uuid: String, _resolved_targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var result := EffectResult.new()
	
	# Get the summoned unit from context
	var summoned_uuid: String = context.get("summoned_uuid", "")
	if summoned_uuid.is_empty():
		return result
	
	# Get target instance
	var target_inst: GachaBallInstance = battle_manager.get_instance_by_uuid(summoned_uuid)
	if not is_instance_valid(target_inst) or target_inst.current_hp <= 0:
		return result
	
	# Get HP amount from parameters (default 3)
	var hp_amount: int = int(parameters.get("hp_amount", 3))
	if hp_amount <= 0:
		return result
	
	# Capture old HP
	var old_hp: int = target_inst.current_hp
	var max_hp: int = 0
	var target_def = target_inst.get_definition()
	if is_instance_valid(target_def):
		max_hp = target_def.base_hp
	
	# Apply HP buff
	var new_hp = battle_manager.apply_stat_delta(target_inst, "hp", hp_amount)
	
	# Get source name for log
	var source_name: String = ""
	if not source_uuid.is_empty():
		var src = battle_manager.get_instance_by_uuid(source_uuid)
		source_name = BattleHelpers.get_instance_display_name(src)
	if source_name == "":
		source_name = "Summon Blessing"
	
	var target_name: String = BattleHelpers.get_instance_display_name(target_inst)
	
	# Add log event
	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "%s blesses %s with +%d HP" % [source_name, target_name, hp_amount]
	}))
	
	# Add BUFF event for animation (BuffAnimation now handles both HP and PWR)
	result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
		"source_uuid": source_uuid,
		"target_uuids": [summoned_uuid],
		"ability_id": context.get("ability_id", &"summon_blessing"),
		"trigger_type": context.get("trigger_type", ""),
		"ability_holder_uuid": source_uuid,
		"visual_payload": {
			"source_uuid": source_uuid,
			"amount": hp_amount,
			"stat": "hp",
			"targets_old_hp": [old_hp],
			"targets_new_hp": [new_hp],
			"targets_max_hp": [max_hp]
		}
	}))
	
	result.mark_healed(summoned_uuid)
	result.state_applied = true
	return result
