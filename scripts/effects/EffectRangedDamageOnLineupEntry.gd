@tool
class_name EffectRangedDamageOnLineupEntry
extends EffectDefinition

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, _context: TriggerContext) -> EffectResult:
	assert(targets.size() <= 1, "EffectRangedDamageOnLineupEntry: lineup entry resolves to at most one unit")
	if targets.is_empty():
		return EffectResult.empty()

	var source: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	assert(is_instance_valid(source), "EffectRangedDamageOnLineupEntry: source unit must be registered")
	var source_container: StringName = source.location_container_tag
	if source_container != C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP and source_container != C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
		return EffectResult.empty()

	var damage_amount: int = int(parameters["damage"])
	assert(damage_amount > 0, "EffectRangedDamageOnLineupEntry: damage must be positive")
	var result := EffectResult.new()
	result.damage_request = EffectResult.DamageRequest.new(damage_amount, C.DamageType.RANGED, targets)
	return result
