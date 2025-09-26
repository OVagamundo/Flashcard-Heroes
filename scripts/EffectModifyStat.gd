# res://scripts/EffectModifyStat.gd
@tool
extends EffectDefinition

## A generic stat modification effect. For Healing Amulet we use { stat: "hp", base_value: 2 }.
func execute(_source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	if targets.is_empty():
		return null
	if not parameters is Dictionary:
		return null
	var stat: String = String(parameters.get("stat", ""))
	var base_value: int = int(parameters.get("base_value", 0))
	if stat == "":
		return null
	if base_value == 0:
		return null
	var is_simulation: bool = context.get("is_simulation", false)
	for t in targets:
		var inst: GachaBallInstance = battle_manager.get_instance_by_uuid(t)
		if not is_instance_valid(inst):
			continue
		match stat:
			"hp":
				var old_hp = inst.current_hp
				var new_hp = max(0, inst.current_hp + base_value)
				var ability_id = context.get("ability_id", "unknown_ability")
				var target_name = "unknown"
				var target_def = inst.get_definition()
				if is_instance_valid(target_def):
					if "display_name_key" in target_def:
						target_name = target_def.display_name_key
					elif "name" in target_def:
						target_name = target_def.name
					elif "id" in target_def:
						target_name = target_def.id
				var log_msg = "EffectModifyStat: %s changed for %s from %d to %d (Source: %s)" % [stat, target_name, old_hp, new_hp, ability_id]
				print("[DEBUG] ", log_msg)
				if not is_simulation:
					inst.set_current_hp(new_hp)
				# Other stats can be added here when implemented
			_:
				pass
	# During simulation, return structured result for BattleManager to create events.
	if is_simulation:
		return {
			"stat": stat,
			"amount": base_value,
			"targets": targets
		}
	# Non-simulation return (legacy compatibility)
	return base_value
