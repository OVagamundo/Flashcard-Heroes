# res://scripts/EffectModifyStat.gd
@tool
extends EffectDefinition

## A generic stat modification effect. 
## For Healing Amulet we use { stat: "hp", base_value: 2 }.
## For PWR-based healing we use { stat: "hp", use_source_pwr: true }.
func execute(_source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	if targets.is_empty():
		return null
	if not parameters is Dictionary:
		return null
	var stat: String = String(parameters.get("stat", ""))
	if stat == "":
		return null
	
	# Determine the value to modify by
	var base_value: int = int(parameters.get("base_value", 0))
	var use_source_pwr: bool = parameters.get("use_source_pwr", false)
	
	# If using source's PWR, get it from pre-snapshotted context data
	# Zero-Instance-Query Compliant: BattleManager populates source_pwr before execute()
	if use_source_pwr:
		base_value = context.get("source_pwr", 0)
		if base_value == 0:
			push_warning("[EffectModifyStat] source_pwr missing from context for use_source_pwr=true")
	
	if base_value == 0:
		return null
	
	var is_simulation: bool = context.get("is_simulation", false)
	# During simulation, validate targets and return structured data without mutating state
	if is_simulation:
		# Filter out invalid targets
		var valid_targets: Array[String] = []
		for t in targets:
			var inst: GachaBallInstance = battle_manager.get_instance_by_uuid(t)
			if is_instance_valid(inst):
				valid_targets.append(t)
		if valid_targets.is_empty():
			return null
		return {
			"stat": stat,
			"amount": base_value,
			"targets": valid_targets
		}
	# Non-simulation: apply stat changes immediately
	else:
		for t in targets:
			var inst: GachaBallInstance = battle_manager.get_instance_by_uuid(t)
			if not is_instance_valid(inst):
				continue
			match stat:
				"hp":
					var new_hp = max(0, inst.current_hp + base_value)
					inst.set_current_hp(new_hp)
				"pwr":
					inst.current_pwr = max(0, inst.current_pwr + base_value)
					SignalBus.emit_signal("unit_stats_changed", inst.ball_uuid)
				_:
					pass
	# Non-simulation return (legacy compatibility)
	return base_value
