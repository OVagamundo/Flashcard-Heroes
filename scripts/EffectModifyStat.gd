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
				var new_hp = max(0, inst.current_hp + base_value)
				# Update HP silently during simulation, loudly during non-simulation
				if is_simulation and inst.has_method("set_current_hp_silent"):
					inst.set_current_hp_silent(new_hp)
				else:
					inst.set_current_hp(new_hp)
			"pwr":
				# Do NOT mutate current_pwr during simulation; animator will apply per-event deltas
				if not is_simulation:
					inst.current_pwr = max(0, inst.current_pwr + base_value)
					SignalBus.emit_signal("unit_stats_changed", inst.ball_uuid)
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
