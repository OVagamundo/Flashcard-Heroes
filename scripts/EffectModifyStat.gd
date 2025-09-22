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
				print("[DEBUG] EffectModifyStat healing ", inst.get_definition().display_name_key, " from ", old_hp, " to ", new_hp)
				if is_simulation and inst.has_method("set_current_hp_silent"):
					inst.set_current_hp_silent(new_hp)
				else:
					inst.set_current_hp(new_hp)
			_:
				pass
	# Optionally notify UI; BattleView generally listens to unit_stats_changed which set_current_hp emits.
	SignalBus.emit_signal("battle_inventory_changed")
	return base_value
