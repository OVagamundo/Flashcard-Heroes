# res://scripts/EffectHealTwoRandomAllies.gd
@tool
extends EffectDefinition
const C = preload("res://scripts/Constants.gd")

## Heals two random allies for a specified amount each.
## Each ally is selected independently, so the same ally can receive both heals.
## The animation source is the item holder (equipped_on_uuid), not the item itself.

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	
	# Get the heal amount from parameters
	var heal_amount: int = int(parameters.get("base_value", 2))
	var num_heals: int = int(parameters.get("heal_count", 2))
	
	# Zero-Instance-Query Compliant: Get holder UUID from context
	# For items, BattleManager pre-populates source_holder_uuid
	var holder_uuid: String = context.get("source_holder_uuid", "")
	if holder_uuid.is_empty():
		push_warning("[EffectHealTwoRandomAllies] source_holder_uuid missing from context")
		return EffectResult.empty() if is_simulation else null
	
	# We still need holder instance for team detection
	var holder = battle_manager.get_instance_by_uuid(holder_uuid)
	if not is_instance_valid(holder):
		return EffectResult.empty() if is_simulation else null
	
	# Determine which team the holder is on
	var holder_is_player: bool = battle_manager._is_player_unit(holder)
	
	# Get all living allies (including the holder)
	var lineup_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if holder_is_player else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var allies = battle_manager.get_instances_in_container(lineup_tag).filter(func(u): return u.current_hp > 0)
	
	if allies.is_empty():
		return EffectResult.empty() if is_simulation else null
	
	# Select random targets independently for each heal
	var heal_targets: Array[String] = []
	for i in range(num_heals):
		var random_ally = allies[randi() % allies.size()]
		heal_targets.append(random_ally.ball_uuid)
	
	if is_simulation:
		# NEW: Return EffectResult with HEAL events
		var result := EffectResult.new()
		
		for target_uuid in heal_targets:
			var tgt = battle_manager.get_instance_by_uuid(target_uuid)
			if not is_instance_valid(tgt):
				continue
			
			# Capture old HP for animation
			var old_hp: int = tgt.current_hp
			var tgt_def = tgt.get_definition()
			var max_hp: int = tgt_def.base_hp if is_instance_valid(tgt_def) else 0
			
			# Apply heal to model
			var new_hp = battle_manager.apply_stat_delta(tgt, "hp", heal_amount)
			
			# Get display names
			var holder_name: String = BattleHelpers.get_instance_display_name(holder)
			var target_name: String = BattleHelpers.get_instance_display_name(tgt)
			
			# Log message
			result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
				"text": "%s heals %s for %d HP" % [holder_name, target_name, heal_amount]
			}))
			
			# HEAL event
			result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
				"source_uuid": _source_uuid,
				"target_uuids": [target_uuid],
				"ability_id": context.get("ability_id", &"heal_two_random"),
				"trigger_type": context.get("trigger_type", ""),
				"ability_holder_uuid": holder_uuid,
				"visual_payload": {
					"source_uuid": holder_uuid,
					"amount": heal_amount,
					"stat": "hp",
					"skip_bump": false,
					"targets_old_hp": [old_hp],
					"targets_new_hp": [new_hp],
					"targets_max_hp": [max_hp]
				}
			}))
			
			result.mark_healed(target_uuid)
		
		result.state_applied = true
		return result
	else:
		# Apply heals immediately (execution mode)
		for target_uuid in heal_targets:
			var tgt = battle_manager.get_instance_by_uuid(target_uuid)
			if is_instance_valid(tgt):
				var new_hp = max(0, tgt.current_hp + heal_amount)
				tgt.set_current_hp(new_hp)
		return heal_amount
