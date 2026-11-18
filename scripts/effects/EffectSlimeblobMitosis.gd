# res://scripts/effects/EffectSlimeblobMitosis.gd
@tool
extends EffectDefinition

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, _context: TriggerContext) -> EffectResult:
	var source: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source) or source.current_hp <= 0:
		return EffectResult.empty()

	var enemy_container = battle_manager.get_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	if not is_instance_valid(enemy_container):
		return EffectResult.empty()

	# Priority: Frontmost vacant slot (0 -> 4), replacing corpses if present
	var empty_slot: int = -1
	for i in range(5):
		var u_uuid: String = enemy_container.get_uuid(i)
		if u_uuid.is_empty():
			empty_slot = i
			break
		var u_inst: GachaBallInstance = battle_manager.get_instance_by_uuid(u_uuid)
		if not is_instance_valid(u_inst) or u_inst.current_hp <= 0 or battle_manager.is_dead_this_turn(u_uuid):
			empty_slot = i
			break

	if empty_slot == -1:
		return EffectResult.empty()

	var result := EffectResult.new()
	result.summon_units_request = [{
		"unit_id": &"unit_spikeslime",
		"slot": empty_slot,
		"level": 1
	}]
	result.summon_team = "ENEMY"
	return result
