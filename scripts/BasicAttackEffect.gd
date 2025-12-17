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
	var damage = StatScaling.calculate(parameters.get("damage"), _context, "BasicAttackEffect")
	
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
	# Determine trigger cause:
	# 1. Inherit from context (e.g. CAUSE_TURN from BattleManager)
	# 2. If this is an ABILITY (like Extra Attack), it overrides the cause to CAUSE_ABILITY
	#    This prevents "Extra Attack" (Cause: ABILITY) from triggering another "Extra Attack" (Requires: CAUSE_TURN)
	var trigger_cause = _context.get("trigger_cause", &"")
	var ability_id = _context.get("ability_id", &"")
	
	if ability_id != &"basic_attack":
		trigger_cause = &"CAUSE_ABILITY"
	
	# CRITICAL: Capture queue size BEFORE triggering any reactions
	# This ensures we drain ALL reactions (on_attack + on_before_damage) added during this attack
	var reactions_before_attack: int = battle_manager.get_pending_reactions_size()
	
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

	# Trigger on_before_damage on the target (for defensive abilities like Defensive Stance)
	# This fires for all attacks including counter-attacks
	var before_attack_context: Dictionary = {
		"source_uuid": target_instance.ball_uuid, # The target is the source of its own defensive ability
		"defender_uuid": target_instance.ball_uuid, # CRITICAL: Used by AbilityResolver to filter responding units
		"attacker_uuid": attacker_uuid,
		"target_initial_hp": target_instance.current_hp,
		"is_simulation": is_simulation
	}
	AbilityResolver.process_trigger(&"on_before_damage", before_attack_context)
	
	# CRITICAL FIX: Drain ALL pre-attack reactions (on_attack + on_before_damage) inline
	# This includes Power Amulet buffs, Defensive Stance heals, etc.
	# They must execute BEFORE damage is calculated so stats are correct
	# Priority sorting ensures high-priority effects (Power Amulet=100) execute first
	if is_simulation:
		battle_manager.drain_pending_reactions_inline(reactions_before_attack)

	
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
