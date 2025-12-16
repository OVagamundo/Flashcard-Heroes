# res://scripts/effects/EffectHealTwoRandomAllies.gd
@tool
extends EffectDefinition

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
		return null
	
	# We still need holder instance for team detection
	var holder = battle_manager.get_instance_by_uuid(holder_uuid)
	if not is_instance_valid(holder):
		return null
	
	# Determine which team the holder is on
	var holder_is_player: bool = battle_manager._is_player_unit(holder)
	
	# Get all living allies (including the holder)
	var lineup_tag = battle_manager.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if holder_is_player else battle_manager.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var allies = battle_manager.get_instances_in_container(lineup_tag).filter(func(u): return u.current_hp > 0)
	
	if allies.is_empty():
		return null
	
	# Select random targets independently for each heal
	var heal_targets: Array[String] = []
	for i in range(num_heals):
		var random_ally = allies[randi() % allies.size()]
		heal_targets.append(random_ally.ball_uuid)
	
	if is_simulation:
		# Return structured data for each heal
		# We return an array of heals so BattleManager can create multiple BUFF events
		var result = {
			"multi_heal": true,
			"heals": heal_targets.map(func(t): return {"target": t, "amount": heal_amount}),
			"animation_source_uuid": holder_uuid,
			"stat": "hp"
		}
		return result
	else:
		# Apply heals immediately (execution mode)
		for target_uuid in heal_targets:
			var tgt = battle_manager.get_instance_by_uuid(target_uuid)
			if is_instance_valid(tgt):
				var new_hp = max(0, tgt.current_hp + heal_amount)
				tgt.set_current_hp(new_hp)
		return heal_amount
