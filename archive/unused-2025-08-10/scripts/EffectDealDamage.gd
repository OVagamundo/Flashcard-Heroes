# res://scripts/EffectDealDamage.gd
extends EffectDefinition

## An effect that deals damage to targets with optional stat scaling.
## Parameters: {"damage": int or Dictionary} - The damage amount or stat-scaling parameters

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, _context: Dictionary):
	if targets.is_empty() or not parameters.has("damage"):
		return

	var source_instance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_instance):
		return

	var damage = _calculate_damage(source_instance)
	
	# Apply damage to all targets
	for target_uuid in targets:
		var target_instance = battle_manager.get_instance_by_uuid(target_uuid)
		if is_instance_valid(target_instance):
			# Store original HP for kill detection
			var original_hp = target_instance.current_hp
			
			target_instance.set_current_hp(max(0, target_instance.current_hp - damage))
			
			# Trigger on_hurt event for the target
			battle_manager.trigger_on_hurt(target_instance.ball_uuid, damage, source_instance.ball_uuid)
			
			# Check if the target was killed
			if original_hp > 0 and target_instance.current_hp <= 0:
				battle_manager.trigger_on_kill(source_instance.ball_uuid, target_instance.ball_uuid)
			
			# Inform UI and log systems
			var src_name = tr(source_instance.get_definition().display_name_key)
			var tgt_name = tr(target_instance.get_definition().display_name_key)
			var msg = "%s deals %d dmg to %s" % [src_name, damage, tgt_name]
			SignalBus.battle_log_event.emit(msg)
			SignalBus.unit_stats_changed.emit(target_instance.ball_uuid)

	SignalBus.battle_inventory_changed.emit()

## Calculate damage using stat-scaling parameters
func _calculate_damage(source_instance: GachaBallInstance) -> int:
	var damage_param = parameters["damage"]
	
	# If it's a simple integer, use it directly
	if damage_param is int:
		return damage_param
	
	# If it's a dictionary with stat-scaling, calculate it
	if damage_param is Dictionary:
		return _calculate_stat_scaled_value(damage_param, source_instance)
	
	# Fallback to 0 damage
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