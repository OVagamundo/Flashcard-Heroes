# res://scripts/effects/EffectRepeatAdjacentBuff.gd
@tool
extends EffectDefinition
class_name EffectRepeatAdjacentBuff

## Absorbs/copies stat buffs (HP or PWR) given to adjacent units, targeting itself.
## The source of THIS new buff is the unit owning this effect (Nuton).

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var is_simulation: bool = context.is_simulation
	
	# Only discrete (event-driven, stackable) battle buffs are echoed.
	# Conditional/state-bound modifiers (while equipped, trinket conditions) and permanent upgrades are strictly excluded.
	if context.buff_subgroup != C.BUFF_SUBGROUP_DISCRETE or not context.is_stackable:
		return EffectResult.empty()
		
	# An echo must never echo another echo (prevents mutual and cascading echo recursion loops)
	if context.is_echo:
		return EffectResult.empty()
	
	# Extract the original buff details from context
	var stat: String = context.stat
	var amount: int = context.amount
	
	if stat == null or amount <= 0:
		return EffectResult.empty()
		
	var multiplier = parameters.get("effectiveness", 1.0)
	amount = int(floor(amount * multiplier))
	if amount <= 0:
		return EffectResult.empty()
		
	# Validate targets
	if targets.is_empty():
		return EffectResult.empty()

	var src_inst = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(src_inst) or src_inst.current_hp <= 0:
		return EffectResult.empty()

	# Filter targets to adjacent allies of the absorber
	var adjacent_allies = battle_manager._get_adjacent_allies(src_inst)
	var adjacent_uuids: Array[String] = []
	for ally in adjacent_allies:
		adjacent_uuids.append(ally.ball_uuid)

	var has_valid_adjacent_target: bool = false
	for target_uuid in targets:
		if target_uuid in adjacent_uuids:
			has_valid_adjacent_target = true
			break

	if not has_valid_adjacent_target:
		return EffectResult.empty()

	if is_simulation:
		var result := EffectResult.new()
		var source_name = BattleHelpers.get_instance_display_name(src_inst)
		
		var old_val: int = src_inst.current_hp if stat == "hp" else src_inst.current_pwr
		var max_hp = 0
		var def = src_inst.get_definition()
		if is_instance_valid(def):
			max_hp = def.base_hp
			
		var new_val = battle_manager.apply_stat_delta(src_inst, stat, amount, source_uuid, C.ACTION_BUFF, true, &"", &"", {"is_echo": true}, C.BUFF_SUBGROUP_DISCRETE)
		if new_val == null:
			new_val = old_val

		# Visuals
		var stat_str = "HP" if stat == "hp" else "PWR"
		var log_text = "%s absorbs buff! Gains +%d %s." % [source_name, amount, stat_str]
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))

		var visual_source_uuid = source_uuid

		if stat == "hp":
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": visual_source_uuid,
				"target_uuids": [source_uuid],
				"ability_id": &"unit_t3_shadow_buff_echo",
				"trigger_type": C.TRIGGER_ON_STAT_INCREASED,
				"action_type": C.ACTION_BUFF,
				"buff_subgroup": C.BUFF_SUBGROUP_DISCRETE,
				"ability_holder_uuid": source_uuid,
				"visual_payload": CombatPayload.hp_buff(visual_source_uuid, amount, [old_val], [new_val], [max_hp])
			}))
		elif stat == "pwr":
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": visual_source_uuid,
				"target_uuids": [source_uuid],
				"ability_id": &"unit_t3_shadow_buff_echo",
				"trigger_type": C.TRIGGER_ON_STAT_INCREASED,
				"action_type": C.ACTION_BUFF,
				"buff_subgroup": C.BUFF_SUBGROUP_DISCRETE,
				"ability_holder_uuid": source_uuid,
				"visual_payload": CombatPayload.pwr_buff(visual_source_uuid, amount, [old_val], [new_val])
			}))
			
		result.state_applied = true
		return result
	else:
		# Non-simulation
		battle_manager.apply_stat_delta(src_inst, stat, amount, source_uuid, C.ACTION_BUFF, true, &"", &"", {"is_echo": true}, C.BUFF_SUBGROUP_DISCRETE)
		return EffectResult.empty()