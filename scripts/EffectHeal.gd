# res://scripts/EffectHeal.gd
extends EffectDefinition

## An effect that heals targets with optional stat scaling.
## Parameters: {"heal": int or Dictionary} - The heal amount or stat-scaling parameters

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, _context: Dictionary):
	if targets.is_empty() or not parameters.has("heal"):
		return

	var source_instance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_instance):
		return

	var heal_amount = _calculate_heal(source_instance)
	
	# Apply healing to all targets
	for target_uuid in targets:
		var target_instance = battle_manager.get_instance_by_uuid(target_uuid)
		if is_instance_valid(target_instance):
			var max_hp = target_instance.get_definition().base_hp
			var new_hp = min(max_hp, target_instance.current_hp + heal_amount)
			target_instance.set_current_hp(new_hp)
			
			# Inform UI and log systems
			var src_name = tr(source_instance.get_definition().display_name_key)
			var tgt_name = tr(target_instance.get_definition().display_name_key)
			var msg = "%s heals %s for %d HP" % [src_name, tgt_name, heal_amount]
			SignalBus.battle_log_event.emit(msg)
			SignalBus.unit_stats_changed.emit(target_instance.ball_uuid)

	SignalBus.battle_inventory_changed.emit()

## Calculate heal amount using stat-scaling parameters
func _calculate_heal(source_instance: GachaBallInstance) -> int:
	var heal_param = parameters["heal"]
	
	# If it's a simple integer, use it directly
	if heal_param is int:
		return heal_param
	
	# If it's a dictionary with stat-scaling, calculate it
	if heal_param is Dictionary:
		return _calculate_stat_scaled_value(heal_param, source_instance)
	
	# Fallback to 0 healing
	return 0

## Calculate a stat-scaled value using the TDD V7.0 formula
func _calculate_stat_scaled_value(param_dict: Dictionary, source_instance: GachaBallInstance) -> int:
	var base_value = param_dict.get("base_value", 0)
	var pwr_multiplier = param_dict.get("pwr_multiplier", 0.0)
	var hp_multiplier = param_dict.get("hp_multiplier", 0.0)
	var base_hp_multiplier = param_dict.get("base_hp_multiplier", 0.0)
	
	var final_value = base_value
	final_value += source_instance.current_pwr * pwr_multiplier
	final_value += source_instance.current_hp * hp_multiplier
	final_value += source_instance.base_hp * base_hp_multiplier
	
	return floor(final_value) 