# res://scripts/effects/EffectDustEliteSpawn.gd
@tool
extends EffectDefinition

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, _context: Dictionary) -> EffectResult:
	var result := EffectResult.new()
	
	var is_space_available := false
	var target_location: Dictionary
	
	# 1. Try PlayerBench
	var bench = battle_manager.get_container(&"PlayerBench")
	if is_instance_valid(bench):
		var empty_index = bench.find_first_empty_slot()
		if empty_index != -1:
			is_space_available = true
			target_location = {"container": &"PlayerBench", "index": empty_index}
	
	# 2. Try BattleInventoryT1 as fallback
	if not is_space_available:
		var inventory = battle_manager.get_container(&"BattleInventoryT1")
		if is_instance_valid(inventory):
			var empty_index = inventory.find_first_empty_slot()
			if empty_index != -1:
				is_space_available = true
				target_location = {"container": &"BattleInventoryT1", "index": empty_index}
	
	if not is_space_available:
		return EffectResult.empty()
		
	# Tier 3 Elite spawns random of T1 or T2 Dust units
	var dust_pool = [&"unit_dust_t1", &"unit_dust_t2"]
	var selected_dust = dust_pool[randi() % dust_pool.size()]
	
	# Summon unit using standard summon request
	result.summon_request = {
		"summon_unit_id": selected_dust,
		"holder_uuid": "", # Player inventory doesn't replace a holder
		"holder_location": LocationIdentifier.new(target_location.container, target_location.index),
		"is_resurrection": false
	}
	
	# We also need a LOG event to show the spawn
	result.events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "Dust Elite spawned a Dust unit in the player inventory."
	}))
	
	return result
