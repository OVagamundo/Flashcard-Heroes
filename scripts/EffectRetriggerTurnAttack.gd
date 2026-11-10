# res://scripts/EffectRetriggerTurnAttack.gd
@tool
extends EffectDefinition

## Effect that performs a COMPLETE FRESH TURN ACTION.
## Used by Tiger's Spirit to make the unit attack again as if it was a new turn.
## This means: find fresh targets, use current stats (including new buffs), execute all abilities.
## NON-STACKING: Only executes once per turn even with multiple items.

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, _context: TriggerContext) -> EffectResult:
	var is_simulation: bool = _context.is_simulation
	
	# --- NON-STACKING CHECK ---
	# If Double Strike already executed this turn, skip
	if _context.double_strike_executed:
		# Skipping - already executed this turn (non-stacking)
		return EffectResult.empty()
	_context.double_strike_executed = true
	
	# Determine attacker (for items, use the holder)
	var attacker_uuid: String = source_uuid
	var source_category = _context.source_category
	if source_category == &"ITEM":
		var holder_uuid = _context.source_holder_uuid
		if not holder_uuid.is_empty():
			attacker_uuid = holder_uuid
	
	var attacker = battle_manager.get_instance_by_uuid(attacker_uuid)
	if not is_instance_valid(attacker):
		return EffectResult.empty()
	
	# --- FIND FRESH TARGET ---
	var basic_attack_def = battle_manager.get_basic_attack_for(attacker)
	var default_target_type = C.TARGET_FRONTMOST_ENEMY
	if is_instance_valid(basic_attack_def) and not basic_attack_def.effects.is_empty():
		var effect = basic_attack_def.effects[0]
		if is_instance_valid(effect) and effect.target_type != &"":
			default_target_type = effect.target_type
	var target_ctx := TriggerContext.new()
	target_ctx.trigger_type = C.TRIGGER_WHEN_ATTACKING
	var target_uuids = TargetResolver.resolve_target(attacker.ball_uuid, default_target_type, target_ctx, battle_manager)
	if target_uuids.is_empty():
		return EffectResult.empty()
	var target = battle_manager.get_instance_by_uuid(target_uuids[0])
	if not is_instance_valid(target):
		return EffectResult.empty()

	# LOGIC CHECK: Only trigger if target has more HP or PWR (Tiger Spirit's defining trait)
	var target_has_more_hp = target.current_hp > attacker.current_hp
	var target_has_more_pwr = target.current_pwr > attacker.current_pwr
	
	if not (target_has_more_hp or target_has_more_pwr):
		return EffectResult.empty()

	# --- BUILD CONTEXT FOR FRESH TURN ACTION ---
	# Use CAUSE_ABILITY_RETRIGGER to prevent Tiger's Spirit from self-triggering
	# (Tiger's Spirit requires CAUSE_TURN)
	var double_strike_context := TriggerContext.new()
	double_strike_context.attacker_uuid = attacker.ball_uuid
	double_strike_context.target_uuid = target.ball_uuid
	double_strike_context.target_initial_hp = target.current_hp
	double_strike_context.trigger_cause = &"CAUSE_ABILITY_RETRIGGER" # Prevents Tiger's Spirit self-trigger
	double_strike_context.cause_id = &"double_strike"
	double_strike_context.double_strike_executed = true # Prevent nested double strikes
	
	# --- FIRE on_attack FOR OTHER ABILITIES ---
	# This will trigger Shockwave, Mirror Strike, Power Amulet, etc.
	# Tiger's Spirit won't self-trigger because its condition requires CAUSE_TURN
	AbilityResolver.process_trigger(C.TRIGGER_WHEN_ATTACKING, double_strike_context)
	
	# Check if an ability replaced the basic attack
	if double_strike_context.attack_replaced:
		return EffectResult.empty()
	
	# Mark that on_attack was already triggered
	double_strike_context.on_attack_already_triggered = true
	
	# --- QUEUE FRESH BASIC ATTACK ---
	if is_instance_valid(basic_attack_def) and not basic_attack_def.effects.is_empty():
		var basic_attack_request = EffectRequest.new(
			attacker.ball_uuid, &"double_strike_attack", basic_attack_def.effects[0],
			[target.ball_uuid], double_strike_context, C.SubPhase.DOUBLE_STRIKE_FOLLOWUP
		)
		battle_manager.enqueue_effect_request(basic_attack_request)
	
	# NEW: Return EffectResult.empty() in simulation mode
	# This effect works by queueing attacks, no direct events needed
	return EffectResult.empty()
