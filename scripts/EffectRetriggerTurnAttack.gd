# res://scripts/EffectRetriggerTurnAttack.gd
@tool
extends EffectDefinition

## Effect that performs a COMPLETE FRESH TURN ACTION.
## Used by Tiger's Spirit to make the unit attack again as if it was a new turn.
## This means: find fresh targets, use current stats (including new buffs), execute all abilities.
## NON-STACKING: Only executes once per turn even with multiple items.

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, _context: Dictionary) -> Variant:
	var is_simulation: bool = _context.get("is_simulation", false)
	
	# --- NON-STACKING CHECK ---
	# If Double Strike already executed this turn, skip
	if _context.get("double_strike_executed", false):
		# Skipping - already executed this turn (non-stacking)
		return EffectResult.empty() if is_simulation else null
	_context["double_strike_executed"] = true
	
	# Determine attacker (for items, use the holder)
	var attacker_uuid: String = source_uuid
	var source_category = _context.get("source_category", &"")
	if source_category == &"ITEM":
		var holder_uuid = _context.get("source_holder_uuid", "")
		if not holder_uuid.is_empty():
			attacker_uuid = holder_uuid
	
	var attacker = battle_manager.get_instance_by_uuid(attacker_uuid)
	if not is_instance_valid(attacker):
		return EffectResult.empty() if is_simulation else null
	
	# --- FIND FRESH TARGET ---
	var is_player = battle_manager._is_player_unit(attacker)
	var target = battle_manager._get_frontmost_target(is_player)
	if not is_instance_valid(target):
		# No front enemy found, skipping
		return EffectResult.empty() if is_simulation else null
	
	# Performing FRESH turn action
	
	# --- BUILD CONTEXT FOR FRESH TURN ACTION ---
	# Use CAUSE_ABILITY_RETRIGGER to prevent Tiger's Spirit from self-triggering
	# (Tiger's Spirit requires CAUSE_TURN)
	var double_strike_context: Dictionary = {
		"attacker_uuid": attacker.ball_uuid,
		"target_uuid": target.ball_uuid,
		"target_initial_hp": target.current_hp,
		"trigger_cause": &"CAUSE_ABILITY_RETRIGGER", # Prevents Tiger's Spirit self-trigger
		"cause_id": &"double_strike",
		"double_strike_executed": true # Prevent nested double strikes
	}
	
	# --- FIRE on_attack FOR OTHER ABILITIES ---
	# This will trigger Shockwave, Mirror Strike, Power Amulet, etc.
	# Tiger's Spirit won't self-trigger because its condition requires CAUSE_TURN
	AbilityResolver.process_trigger(&"on_attack", double_strike_context)
	
	# Check if an ability replaced the basic attack
	if double_strike_context.get("attack_replaced", false):
		return EffectResult.empty() if is_simulation else null
	
	# Mark that on_attack was already triggered
	double_strike_context["on_attack_already_triggered"] = true
	
	# --- QUEUE FRESH BASIC ATTACK ---
	var basic_attack_def = Database.get_ability_definition(&"basic_attack")
	if is_instance_valid(basic_attack_def) and not basic_attack_def.effects.is_empty():
		var basic_attack_request = EffectRequest.new(
			attacker.ball_uuid, &"double_strike_attack", basic_attack_def.effects[0],
			[target.ball_uuid], double_strike_context, -50 # Execute after main attack chain
		)
		battle_manager.enqueue_effect_request(basic_attack_request)
	
	# NEW: Return EffectResult.empty() in simulation mode
	# This effect works by queueing attacks, no direct events needed
	return EffectResult.empty() if is_simulation else null
