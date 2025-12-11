# res://scripts/BasicAttackEffect.gd
@tool
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
	var damage = _calculate_damage(source_instance, battle_manager)
	
	# Apply damage
	var is_simulation: bool = _context.get("is_simulation", false)
	
	# Capture the pending reactions queue size BEFORE triggering on_before_attack
	# This ensures we only process the NEW reactions added by on_before_attack, not unrelated ones
	var reactions_before_trigger: int = battle_manager.get_pending_reactions_size()
	
	# Trigger on_before_attack on the target (for defensive abilities like Defensive Stance)
	# This fires for all attacks including counter-attacks
	var before_attack_context: Dictionary = {
		"source_uuid": target_instance.ball_uuid, # The target is the source of its own defensive ability
		"attacker_uuid": source_instance.ball_uuid,
		"target_initial_hp": target_instance.current_hp,
		"is_simulation": is_simulation
	}
	AbilityResolver.process_trigger(&"on_before_attack", before_attack_context)
	
	# CRITICAL: Drain ONLY the on_before_attack effects that were just added
	# Pass the queue size from before triggering - only process reactions added after that point
	if is_simulation:
		battle_manager.drain_pending_reactions_inline(reactions_before_trigger)
	
	# CRITICAL: During simulation, DO NOT modify state here.
	# BattleManager handles the application via apply_stat_delta().
	# Modifying it here would cause double damage (once here, once in BattleManager).
	if not is_simulation:
		var new_hp = max(0, target_instance.current_hp - damage)
		target_instance.set_current_hp(new_hp)

	# NOTE: on_hurt is triggered by BattleManager AFTER apply_stat_delta, not here.
	# This ensures condition checks like DAMAGE_WAS_NON_LETHAL see post-damage HP.
	
	# NOTE: on_kill is NOT triggered here - BattleManager handles kill tracking
	# at the per-actor level after all reactions complete. This ensures kills from
	# all sources (shockwave, counter, double strike, etc.) are properly attributed.

	# Inform UI and log systems (suppressed when simulating)
	if not is_simulation:
		SignalBus.battle_inventory_changed.emit()
		# Emit unit_stats_changed so UI updates HP in real time
		SignalBus.unit_stats_changed.emit(target_instance.ball_uuid)

	return damage

## Calculate damage using stat-scaling parameters if provided
func _calculate_damage(source_instance: GachaBallInstance, battle_manager: Node) -> int:
	# If source is an item/trinket, use the holder's PWR instead
	var stat_provider = _get_stat_provider(source_instance, battle_manager)
	
	if not parameters.has("damage"):
		# Default: use source's power
		return stat_provider.current_pwr
	
	var damage_param = parameters["damage"]
	
	# If it's a simple integer, use it directly
	if damage_param is int:
		return damage_param
	
	# If it's a dictionary with stat-scaling, calculate it
	if damage_param is Dictionary:
		return _calculate_stat_scaled_value(damage_param, stat_provider)
	
	# Fallback to source's power
	return stat_provider.current_pwr

## Get the instance to use for stat calculations (holder for items/trinkets)
func _get_stat_provider(source_instance: GachaBallInstance, battle_manager: Node) -> GachaBallInstance:
	var source_def = source_instance.get_definition()
	if not is_instance_valid(source_def):
		return source_instance
	
	# If source is an item, use the holder's stats
	if source_def.category == &"ITEM" and not source_instance.equipped_on_uuid.is_empty():
		var holder = battle_manager.get_instance_by_uuid(source_instance.equipped_on_uuid)
		if is_instance_valid(holder):
			return holder
	
	# For units and trinkets, use their own stats
	return source_instance

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
