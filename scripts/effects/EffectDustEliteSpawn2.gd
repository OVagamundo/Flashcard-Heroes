# res://scripts/effects/EffectDustEliteSpawn2.gd
@tool
extends EffectDefinition

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, _context: Dictionary) -> EffectResult:
	var result := EffectResult.new()
	
	# 1. Select the dust unit (Tier 2 for this elite)
	var selected_dust = &"unit_dust_t2"
	var inventory_tag = &"BattleInventoryT2"
	
	var is_space_available := false
	var target_location: Dictionary
	
	# 2. Try PlayerBench first
	var bench = battle_manager.get_container(&"PlayerBench")
	if is_instance_valid(bench):
		var empty_index = bench.find_first_empty_slot()
		if empty_index != -1:
			is_space_available = true
			target_location = {"container": &"PlayerBench", "index": empty_index}
	
	# 3. Try the CORRECT Tier Inventory as fallback
	if not is_space_available:
		var inventory = battle_manager.get_container(inventory_tag)
		if is_instance_valid(inventory):
			var empty_index = inventory.find_first_empty_slot()
			if empty_index != -1:
				is_space_available = true
				target_location = {"container": inventory_tag, "index": empty_index}
	
	if not is_space_available:
		return EffectResult.empty()
		
	# Summon unit using standard summon request
	result.summon_request = {
		"summon_unit_id": &"unit_dust_t2",
		"holder_uuid": "", # Player inventory doesn't replace a holder
		"holder_location": LocationIdentifier.new(target_location.container, target_location.index),
		"is_resurrection": false
	}
	
	# We also need a LOG event to show the spawn
	result.events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "Dust Elite 2 spawned a Dust unit in the player inventory."
	}))
	
	return result
