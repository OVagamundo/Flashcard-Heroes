# res://scripts/EffectOverflowDamageAdjacent.gd
@tool
class_name EffectOverflowDamageAdjacent
extends EffectDefinition

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var primary_target_uuid: String = ""
	if not targets.is_empty():
		primary_target_uuid = targets[0]
	else:
		primary_target_uuid = String(context.get("target_uuid", ""))
	if primary_target_uuid.is_empty():
		return null

	var overflow_damage: int = _calculate_overflow_damage(source_uuid, battle_manager, context)
	if overflow_damage <= 0:
		return null

	var overflow_target: GachaBallInstance = _find_adjacent_target(primary_target_uuid, battle_manager)
	if not is_instance_valid(overflow_target):
		return null

	var new_hp: int = max(0, overflow_target.current_hp - overflow_damage)
	var is_simulation: bool = bool(context.get("is_simulation", false))
	if not is_simulation:
		overflow_target.set_current_hp(new_hp)

	battle_manager.trigger_on_hurt(overflow_target.ball_uuid, overflow_damage, String(context.get("source_uuid", "")))
	return {
		"stat": "hp",
		"amount": - overflow_damage,
		"targets": [overflow_target.ball_uuid],
		"skip_bump": true
	}

func _calculate_overflow_damage(source_uuid: String, battle_manager: Node, context: Dictionary) -> int:
	var source_instance: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_instance):
		return 0

	var target_initial_hp: int = int(context.get("target_initial_hp", 0))
	var target_uuid: String = context.get("target_uuid", "")
	if target_initial_hp <= 0 or target_uuid.is_empty():
		return 0

	var damage_dealt: int = source_instance.current_pwr
	if damage_dealt <= target_initial_hp:
		return 0
	return damage_dealt - target_initial_hp

func _find_adjacent_target(target_uuid: String, battle_manager: Node) -> GachaBallInstance:
	if target_uuid.is_empty():
		return null
	var primary_target: GachaBallInstance = battle_manager.get_instance_by_uuid(target_uuid)
	if not is_instance_valid(primary_target):
		return null

	var loc: LocationIdentifier = primary_target.get_location()
	if not is_instance_valid(loc):
		return null

	var adjacent_index: int = _get_adjacent_index(loc, battle_manager)
	if adjacent_index == -1:
		return null

	var adjacent_loc: LocationIdentifier = LocationIdentifier.new(loc.container, adjacent_index)
	var adjacent_instance: GachaBallInstance = battle_manager.get_instance_by_location(adjacent_loc)
	if is_instance_valid(adjacent_instance) and adjacent_instance.current_hp > 0:
		return adjacent_instance

	return null

func _get_adjacent_index(loc: LocationIdentifier, battle_manager: Node) -> int:
	if loc.container == battle_manager.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP:
		return loc.index - 1 if loc.index > 0 else -1
	elif loc.container == battle_manager.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
		var container: DataContainer = battle_manager.get_container(loc.container)
		if not is_instance_valid(container):
			return -1
		var max_index: int = container.get_size() - 1
		return loc.index + 1 if loc.index < max_index else -1
	return -1
