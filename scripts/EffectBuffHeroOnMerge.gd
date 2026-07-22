# res://scripts/EffectBuffHeroOnMerge.gd
@tool
extends EffectDefinition

## Effect that buffs the hero unit when a merge occurs.
## Expected parameters:
##   - hp_amount: int (default 1) - HP buff amount
##   - pwr_amount: int (default 1) - PWR buff amount  

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation: bool = context.get("is_simulation", false)
	
	# Determine the merged unit
	var merged_uuid: String = context.get("merged_uuid", "")
	if merged_uuid.is_empty():
		return EffectResult.empty()
		
	var merged_instance = battle_manager.get_instance(merged_uuid)
	if not is_instance_valid(merged_instance):
		return EffectResult.empty()
		
	# Check if the merged unit is on the player's team (since this is a player exclusive trinket)
	var source_team = _get_team_from_container(merged_instance.location_container_tag)
	if source_team != "PLAYER":
		return EffectResult.empty()
		
	var hero_uuid = ""
	for c_name in [&"PlayerLineup"]:
		var container = battle_manager.get_container(c_name)
		if is_instance_valid(container):
			for i in range(container.get_size()):
				var uuid = container.get_uuid(i)
				if not uuid.is_empty():
					var inst = battle_manager.get_instance(uuid)
					if is_instance_valid(inst):
						var def = inst.get_definition()
						if is_instance_valid(def):
							var is_hero = false
							if def.category == &"HERO":
								is_hero = true
							else:
								var def_id = String(def.id).to_lower()
								if def_id == "hero" or def_id.begins_with("hero_"):
									is_hero = true
								elif "tags" in def:
									for tag in def.tags:
										if String(tag).to_lower() == "hero":
											is_hero = true
											break
							
							if is_hero:
								hero_uuid = uuid
								break
		if not hero_uuid.is_empty():
			break
			
	if hero_uuid.is_empty():
		return EffectResult.empty()
		
	var hero_instance = battle_manager.get_instance(hero_uuid)
	if not is_instance_valid(hero_instance):
		return EffectResult.empty()
		
	var result := EffectResult.new()
	var state_applied_any := false
	
	var raw_hp = parameters.get("hp_amount", 1)
	var hp_amount: int = int(raw_hp) if raw_hp != null else 1
	
	var raw_pwr = parameters.get("pwr_amount", 1)
	var pwr_amount: int = int(raw_pwr) if raw_pwr != null else 1
	
	if is_simulation:
		# Capture old stats
		var old_hp: int = hero_instance.current_hp
		var old_pwr: int = hero_instance.current_pwr
		var max_hp: int = hero_instance.get_definition().base_hp if is_instance_valid(hero_instance.get_definition()) else hero_instance.current_hp
		
		# Apply HP buff
		var hp_result = battle_manager.apply_stat_delta(hero_instance, "hp", hp_amount)
		var new_hp: int = hero_instance.current_hp
		if hp_result is Dictionary:
			new_hp = hp_result.get("new_hp", hero_instance.current_hp)
		elif hp_result != null:
			new_hp = int(hp_result)
		
		# Apply PWR buff  
		var pwr_result = battle_manager.apply_stat_delta(hero_instance, "pwr", pwr_amount)
		var new_pwr: int = hero_instance.current_pwr
		if pwr_result is Dictionary:
			new_pwr = pwr_result.get("new_pwr", hero_instance.current_pwr)
		elif pwr_result != null:
			new_pwr = int(pwr_result)
		
		var trinket_instance = battle_manager.get_instance(_source_uuid)
		var trinket_name: String = ""
		if is_instance_valid(trinket_instance):
			var trinket_def = trinket_instance.get_definition()
			if is_instance_valid(trinket_def):
				trinket_name = tr(trinket_def.name_key)
		if trinket_name.is_empty():
			trinket_name = "Hero's Catalyst"
		
		var unit_name := BattleHelpers.get_instance_display_name(hero_instance)
		
		# Log message
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "%s grants %s +%d HP, +%d PWR" % [trinket_name, unit_name, hp_amount, pwr_amount]
		}))
		
		# HP BUFF event
		result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
			"source_uuid": _source_uuid,
			"target_uuids": [hero_uuid],
			"ability_id": context.get("ability_id", &"ability_trinket_hero_catalyst"),
			"trigger_type": context.get("trigger_type", ""),
			"ability_holder_uuid": _source_uuid,
			"visual_payload": CombatPayload.hp_change(_source_uuid, hp_amount, [old_hp], [new_hp], [max_hp])
		}))
		
		# PWR BUFF event
		result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
			"source_uuid": _source_uuid,
			"target_uuids": [hero_uuid],
			"ability_id": context.get("ability_id", &"ability_trinket_hero_catalyst"),
			"trigger_type": context.get("trigger_type", ""),
			"ability_holder_uuid": _source_uuid,
			"visual_payload": CombatPayload.pwr_change(_source_uuid, pwr_amount, [old_pwr], [new_pwr])
		}))
		state_applied_any = true
	else:
		# Non-simulation: apply immediately
		battle_manager.apply_stat_delta(hero_instance, "hp", hp_amount)
		battle_manager.apply_stat_delta(hero_instance, "pwr", pwr_amount)
		state_applied_any = true

	result.state_applied = true
	return result

func _get_team_from_container(container: StringName) -> String:
	if container == &"PlayerLineup" or container == &"PlayerTrinkets" or container == &"PlayerBench":
		return "PLAYER"
	elif container == &"EnemyLineup" or container == &"EnemyTrinkets":
		return "ENEMY"
	return ""
