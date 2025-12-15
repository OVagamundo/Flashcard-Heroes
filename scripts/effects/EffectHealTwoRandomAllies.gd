# res://scripts/effects/EffectHealTwoRandomAllies.gd
@tool
extends EffectDefinition

## Heals two random allies for a specified amount each.
## Each ally is selected independently, so the same ally can receive both heals.
## The animation source is the item holder (equipped_on_uuid), not the item itself.

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	print("[EffectHealTwoRandomAllies] *** EXECUTE FUNCTION ENTERED ***")
	var is_simulation: bool = context.get("is_simulation", false)
	
	print("[EffectHealTwoRandomAllies] execute called - source_uuid=%s, is_simulation=%s" % [source_uuid, is_simulation])
	
	# Get the heal amount from parameters
	var heal_amount: int = int(parameters.get("base_value", 2))
	var num_heals: int = int(parameters.get("heal_count", 2))
	
	print("[EffectHealTwoRandomAllies] heal_amount=%d, num_heals=%d" % [heal_amount, num_heals])
	
	# Get the source item instance
	var source_item = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_item):
		print("[EffectHealTwoRandomAllies] EXIT: source_item is invalid")
		return null
	
	# Get the item holder (the unit wearing the item)
	var holder_uuid: String = source_item.equipped_on_uuid
	print("[EffectHealTwoRandomAllies] holder_uuid=%s" % holder_uuid)
	if holder_uuid.is_empty():
		print("[EffectHealTwoRandomAllies] EXIT: holder_uuid is empty")
		return null
	
	var holder = battle_manager.get_instance_by_uuid(holder_uuid)
	if not is_instance_valid(holder):
		print("[EffectHealTwoRandomAllies] EXIT: holder instance is invalid")
		return null
	
	# Determine which team the holder is on
	var holder_is_player: bool = battle_manager._is_player_unit(holder)
	print("[EffectHealTwoRandomAllies] holder_is_player=%s" % holder_is_player)
	
	# Get all living allies (including the holder)
	var lineup_tag = battle_manager.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if holder_is_player else battle_manager.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var allies = battle_manager.get_instances_in_container(lineup_tag).filter(func(u): return u.current_hp > 0)
	
	print("[EffectHealTwoRandomAllies] Found %d living allies" % allies.size())
	if allies.is_empty():
		print("[EffectHealTwoRandomAllies] EXIT: no living allies")
		return null
	
	# Select random targets independently for each heal
	var heal_targets: Array[String] = []
	for i in range(num_heals):
		var random_ally = allies[randi() % allies.size()]
		heal_targets.append(random_ally.ball_uuid)
	print("[EffectHealTwoRandomAllies] Selected targets: %s" % str(heal_targets))
	
	if is_simulation:
		# Return structured data for each heal
		# We return an array of heals so BattleManager can create multiple BUFF events
		var result = {
			"multi_heal": true,
			"heals": heal_targets.map(func(t): return {"target": t, "amount": heal_amount}),
			"animation_source_uuid": holder_uuid,
			"stat": "hp"
		}
		print("[EffectHealTwoRandomAllies] Returning simulation result: %s" % str(result))
		return result
	else:
		# Apply heals immediately (execution mode)
		for target_uuid in heal_targets:
			var tgt = battle_manager.get_instance_by_uuid(target_uuid)
			if is_instance_valid(tgt):
				var new_hp = max(0, tgt.current_hp + heal_amount)
				tgt.set_current_hp(new_hp)
		print("[EffectHealTwoRandomAllies] Applied heals in execution mode, returning %d" % heal_amount)
		return heal_amount
