# res://scripts/effects/EffectBuffTwoRandomAllies.gd
@tool
extends EffectDefinition

## Buffs two random allies with a specified stat amount each.
## Each ally is selected independently, so the same ally can receive both buffs.
## The animation source is the item holder (equipped_on_uuid), not the item itself.
## Used by Power Amulet (T3 Item B) on_attack trigger.

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	
	# Get the buff amount and stat from parameters
	var buff_amount: int = int(parameters.get("base_value", 2))
	var num_buffs: int = int(parameters.get("buff_count", 2))
	var buff_stat: String = parameters.get("stat", "pwr")
	
	# Zero-Instance-Query Compliant: Get holder UUID from context
	# For items, BattleManager pre-populates source_holder_uuid
	var holder_uuid: String = context.get("source_holder_uuid", "")
	if holder_uuid.is_empty():
		push_warning("[EffectBuffTwoRandomAllies] source_holder_uuid missing from context")
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
	
	# Select random targets independently for each buff
	var buff_targets: Array[String] = []
	for i in range(num_buffs):
		var random_ally = allies[randi() % allies.size()]
		buff_targets.append(random_ally.ball_uuid)
	
	if is_simulation:
		# Return structured data for each buff
		# We return an array of buffs so BattleManager can create multiple BUFF events
		var result = {
			"multi_buff": true,
			"buffs": buff_targets.map(func(t): return {"target": t, "amount": buff_amount}),
			"animation_source_uuid": holder_uuid,
			"stat": buff_stat
		}
		return result
	else:
		# Apply buffs immediately (execution mode)
		for target_uuid in buff_targets:
			var tgt = battle_manager.get_instance_by_uuid(target_uuid)
			if is_instance_valid(tgt):
				if buff_stat == "pwr":
					var new_pwr = max(0, tgt.current_pwr + buff_amount)
					tgt.set_current_pwr(new_pwr)
				elif buff_stat == "hp":
					var new_hp = max(0, tgt.current_hp + buff_amount)
					tgt.set_current_hp(new_hp)
		return buff_amount
