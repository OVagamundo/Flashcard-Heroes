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
	
	# Use centralized stat-scaling utility
	# Supports: base_value, pwr_multiplier, hp_multiplier, use_source_pwr
	var amount: int = StatScaling.calculate(parameters, context, "EffectModifyStat")
	if amount == 0:
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
			"amount": amount,
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
					var new_hp = max(0, inst.current_hp + amount)
					inst.set_current_hp(new_hp)
					# NOTE: set_current_hp() emits granular unit_stat_changed signal
				"pwr":
					var old_pwr = inst.current_pwr
					inst.current_pwr = max(0, inst.current_pwr + amount)
					SignalBus.emit_signal("unit_stat_changed", inst.ball_uuid, &"pwr", old_pwr, inst.current_pwr)
				_:
					pass
	# Non-simulation return (legacy compatibility)
	return amount
