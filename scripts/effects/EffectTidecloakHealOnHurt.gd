# res://scripts/effects/EffectTidecloakHealOnHurt.gd
@tool
class_name EffectTidecloakHealOnHurt
extends EffectDefinition

## When hurt by an attack, heal self for 1 / 2 / 3 HP for every 2 Current Tokens held.

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var result := EffectResult.new()
	var unit: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(unit) or unit.current_hp <= 0:
		return EffectResult.empty()
	
	var tokens: int = battle_manager.get_gacha_tokens()
	var heal_scale: int = unit.level
	var total_heal: int = int(tokens / 2) * heal_scale
	
	if total_heal > 0:
		var old_hp: int = unit.current_hp
		var new_hp: int = battle_manager.apply_stat_delta(unit, "hp", total_heal, source_uuid, C.ACTION_HEAL)
		var u_def: GachaBallDefinition = unit.get_definition()
		var u_max_hp: int = u_def.base_hp if is_instance_valid(u_def) else unit.current_hp
		var payload := CombatPayload.hp_change(source_uuid, total_heal, [old_hp], [new_hp], [u_max_hp])
		payload.new_val = new_hp
		payload.action_type = C.ACTION_HEAL
		result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
			"source_uuid": source_uuid,
			"target_uuids": [source_uuid],
			"ability_id": context.ability_id if context.ability_id != &"" else &"tidecloak_heal_on_hurt",
			"trigger_type": context.trigger_type,
			"action_type": C.ACTION_HEAL,
			"visual_payload": payload
		}))
	
	result.state_applied = true
	return result
