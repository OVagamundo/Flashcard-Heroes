# res://scripts/BasicAttackEffect.gd
@tool
extends EffectDefinition

## An effect that deals damage equal to the source's power to the first target.
## This is the default attack effect used when no special abilities are triggered.

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, _context: Dictionary) -> Variant:
	if targets.is_empty():
		return null

	# Target must still be queried since targets are dynamically resolved
	var target_instance = battle_manager.get_instance_by_uuid(targets[0])
	if not is_instance_valid(target_instance):
		return null

	# Zero-Instance-Query Compliant: Use context data for source stats
	# Context is pre-populated by BattleManager with: source_pwr, source_hp, source_category, source_holder_uuid
	var damage = _calculate_damage_from_context(_context, battle_manager)
	
	# Apply damage
	var is_simulation: bool = _context.get("is_simulation", false)
	
	# Determine the actual attacker (for items, this is the holder)
	# Use context data instead of querying the source instance
	var attacker_uuid: String = source_uuid
	var source_category = _context.get("source_category", &"")
	if source_category == &"ITEM":
		var holder_uuid = _context.get("source_holder_uuid", "")
		if not holder_uuid.is_empty():
			attacker_uuid = holder_uuid
	
	# Capture the pending reactions queue size BEFORE triggering on_attack
	# This ensures we only process the NEW reactions added by these triggers, not unrelated ones
	var reactions_before_trigger: int = battle_manager.get_pending_reactions_size()
	
	# Determine trigger cause:
	# 1. Inherit from context (e.g. CAUSE_TURN from BattleManager)
	# 2. If this is an ABILITY (like Extra Attack), it overrides the cause to CAUSE_ABILITY
	#    This prevents "Extra Attack" (Cause: ABILITY) from triggering another "Extra Attack" (Requires: CAUSE_TURN)
	var trigger_cause = _context.get("trigger_cause", &"")
	var ability_id = _context.get("ability_id", &"")
	
	if ability_id != &"basic_attack":
		trigger_cause = &"CAUSE_ABILITY"
	
	# Trigger on_attack for the attacker using the unified broadcast system
	# This structure allows abilities to listen to:
	# 1. "on_attack" (Generic - fires for everything, filtered by CAUSE)
	if not _context.get("on_attack_already_triggered", false):
		var attack_context: Dictionary = {
			"attacker_uuid": attacker_uuid,
			"target_uuid": target_instance.ball_uuid,
			"target_initial_hp": target_instance.current_hp,
			"is_simulation": is_simulation,
			"trigger_cause": trigger_cause,
			"cause_id": ability_id # Track which ability caused this attack
		}
		
		# Always fire generic trigger
		AbilityResolver.process_trigger(&"on_attack", attack_context)


	# Trigger on_before_attack on the target (for defensive abilities like Defensive Stance)
	# This fires for all attacks including counter-attacks
	var before_attack_context: Dictionary = {
		"source_uuid": target_instance.ball_uuid, # The target is the source of its own defensive ability
		"defender_uuid": target_instance.ball_uuid, # CRITICAL: Used by AbilityResolver to filter responding units
		"attacker_uuid": attacker_uuid,
		"target_initial_hp": target_instance.current_hp,
		"is_simulation": is_simulation
	}
	AbilityResolver.process_trigger(&"on_before_attack", before_attack_context)
	
	# CRITICAL: Drain ONLY the on_attack and on_before_attack effects that were just added
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

## Calculate damage using context data (Zero-Instance-Query Compliant)
func _calculate_damage_from_context(context: Dictionary, battle_manager: Node) -> int:
	# Get base PWR from context - this is the holder's PWR for items
	var source_pwr: int = context.get("source_pwr", 0)
	
	if source_pwr == 0:
		push_warning("[BasicAttackEffect] source_pwr missing from context, damage will be 0")
	
	if not parameters.has("damage"):
		# Default: use source's power from context
		return source_pwr
	
	var damage_param = parameters["damage"]
	
	# If it's a simple integer, use it directly
	if damage_param is int:
		return damage_param
	
	# If it's a dictionary with stat-scaling, calculate it using context
	if damage_param is Dictionary:
		return _calculate_stat_scaled_value_from_context(damage_param, context, battle_manager)
	
	# Fallback to source's power
	return source_pwr

## Calculate a stat-scaled value using context data (Zero-Instance-Query Compliant)
func _calculate_stat_scaled_value_from_context(param_dict: Dictionary, context: Dictionary, _battle_manager: Node) -> int:
	var base_value: int = param_dict.get("base_value", 0)
	var pwr_multiplier: float = param_dict.get("pwr_multiplier", 0.0)
	var hp_multiplier: float = param_dict.get("hp_multiplier", 0.0)
	var base_hp_multiplier: float = param_dict.get("base_hp_multiplier", 0.0)
	
	# Use context data instead of querying instances
	var source_pwr: int = context.get("source_pwr", 0)
	var source_hp: int = context.get("source_hp", 0)
	
	var final_value = base_value
	final_value += source_pwr * pwr_multiplier
	final_value += source_hp * hp_multiplier
	
	# NOTE: base_hp_multiplier would require the definition's base_hp
	# This is a rare use case - if needed, add "source_base_hp" to context enrichment
	# For now, we skip it since no current abilities use it
	if base_hp_multiplier != 0.0:
		push_warning("[BasicAttackEffect] base_hp_multiplier requires source_base_hp in context (not yet implemented)")
	
	return floor(final_value)
