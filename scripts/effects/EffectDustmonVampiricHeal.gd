# res://scripts/effects/EffectDustmonVampiricHeal.gd
@tool
extends EffectDefinition

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var source: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source) or source.current_hp <= 0:
		return EffectResult.empty()

	var ko_uuid: String = context.knocked_out_uuid
	if ko_uuid.is_empty():
		ko_uuid = context.triggering_uuid

	var ko_inst: GachaBallInstance = battle_manager.get_instance_by_uuid(ko_uuid)
	var ko_def = ko_inst.get_definition() if is_instance_valid(ko_inst) else null
	var heal_amount: int = int(ko_def.tier) if is_instance_valid(ko_def) else 1
	heal_amount = maxi(1, heal_amount)

	var old_hp: int = source.current_hp
	var new_hp: int = battle_manager.apply_stat_delta(source, "hp", heal_amount, source_uuid, C.ACTION_HEAL)
	var s_def = source.get_definition()
	var max_hp: int = s_def.base_hp if is_instance_valid(s_def) else 0

	var result := EffectResult.new()
	result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
		"source_uuid": source_uuid,
		"target_uuids": [source_uuid],
		"action_type": C.ACTION_HEAL,
		"visual_payload": CombatPayload.heal(source_uuid, heal_amount, [old_hp], [new_hp], [max_hp])
	}))
	return result
