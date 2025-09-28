# res://scripts/BasicAttackEffect.gd
extends EffectDefinition

## An effect that deals damage equal to the source's power to the first target.
## This is the default attack effect used when no special abilities are triggered.

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, _context: Dictionary) -> Variant:
	if targets.is_empty():
		return null

	var source_instance = battle_manager.get_instance_by_uuid(source_uuid)
	var target_instance = battle_manager.get_instance_by_uuid(targets[0])
	
	if not is_instance_valid(source_instance) or not is_instance_valid(target_instance):
		return null

	# Calculate damage (can be overridden by parameters for stat scaling)
	var damage = _calculate_damage(source_instance)
	
	# Store original HP for kill detection
	var original_hp = target_instance.current_hp
	
	# Apply damage
	var is_simulation: bool = _context.get("is_simulation", false)
	var old_hp = target_instance.current_hp
	var new_hp = max(0, old_hp - damage)
	var target_name = "unknown"
	var target_def = target_instance.get_definition()
	if is_instance_valid(target_def):
		if "display_name_key" in target_def:
			target_name = tr(target_def.display_name_key)
		elif "name" in target_def:
			target_name = tr(target_def.name)
		elif "id" in target_def:
			target_name = String(target_def.id)
	print("[DEBUG] %s takes %d damage. HP: %d -> %d" % [target_name, damage, old_hp, new_hp])
	if is_simulation and target_instance.has_method("set_current_hp_silent"):
		target_instance.set_current_hp_silent(new_hp)
	else:
		target_instance.set_current_hp(new_hp)

	# Trigger on_hurt event for the target
	battle_manager.trigger_on_hurt(target_instance.ball_uuid, damage, source_instance.ball_uuid)
	
	# Check if the target was killed
	if original_hp > 0 and target_instance.current_hp <= 0:
		battle_manager.trigger_on_kill(source_instance.ball_uuid, target_instance.ball_uuid)

	# Inform UI and log systems (suppressed when simulating)
	var src_name = "unknown"
	var src_def = source_instance.get_definition()
	if is_instance_valid(src_def):
		if "display_name_key" in src_def:
			src_name = tr(src_def.display_name_key)
		elif "name" in src_def:
			src_name = tr(src_def.name)
		elif "id" in src_def:
			src_name = String(src_def.id)
	
	var tgt_name = "unknown"
	var tgt_def = target_instance.get_definition()
	if is_instance_valid(tgt_def):
		if "display_name_key" in tgt_def:
			tgt_name = tr(tgt_def.display_name_key)
		elif "name" in tgt_def:
			tgt_name = tr(tgt_def.name)
		elif "id" in tgt_def:
			tgt_name = String(tgt_def.id)
	var msg = "%s deals %d dmg to %s" % [src_name, damage, tgt_name]
	if not is_simulation:
		SignalBus.battle_log_event.emit(msg)
		SignalBus.battle_inventory_changed.emit()
		# Emit unit_stats_changed so UI updates HP in real time
		SignalBus.unit_stats_changed.emit(target_instance.ball_uuid)

	return damage

## Calculate damage using stat-scaling parameters if provided
func _calculate_damage(source_instance: GachaBallInstance) -> int:
	if not parameters.has("damage"):
		# Default: use source's power
		return source_instance.current_pwr
	
	var damage_param = parameters["damage"]
	
	# If it's a simple integer, use it directly
	if damage_param is int:
		return damage_param
	
	# If it's a dictionary with stat-scaling, calculate it
	if damage_param is Dictionary:
		return _calculate_stat_scaled_value(damage_param, source_instance)
	
	# Fallback to source's power
	return source_instance.current_pwr

## Calculate a stat-scaled value using the TDD V7.0 formula
func _calculate_stat_scaled_value(param_dict: Dictionary, source_instance: GachaBallInstance) -> int:
	var base_value: int = param_dict.get("base_value", 0)
	var pwr_multiplier: float = param_dict.get("pwr_multiplier", 0.0)
	var hp_multiplier: float = param_dict.get("hp_multiplier", 0.0)
	var base_hp_multiplier: float = param_dict.get("base_hp_multiplier", 0.0)
	
	var final_value = base_value
	final_value += source_instance.current_pwr * pwr_multiplier
	final_value += source_instance.current_hp * hp_multiplier
	
	# Access base_hp through the definition, not the instance
	var source_definition = source_instance.get_definition()
	if is_instance_valid(source_definition):
		final_value += source_definition.base_hp * base_hp_multiplier
	
	return floor(final_value)
