# res://scripts/effects/EffectDustEliteSpawn.gd
@tool
extends EffectDefinition

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, _context: Dictionary) -> EffectResult:
	var result := EffectResult.new()
	
	# 1. Select the dust unit FIRST to know its tier
	# Tier 3 Elite spawns random of T1 or T2 Dust units
	var dust_pool = [&"unit_dust_t1", &"unit_dust_t2", &"unit_dust_t3"]
	var selected_dust = RNGManager.combat_rng.pick_random(dust_pool)
	
	# Determine target container based on tier
	var tier := 1
	if selected_dust == &"unit_dust_t2":
		tier = 2
	elif selected_dust == &"unit_dust_t3":
		tier = 3
	
	var inventory_tag: StringName = "BattleInventoryT%d" % tier
	var is_space_available := false
	var target_location: Dictionary
	
	# 2. Try the CORRECT Tier Inventory directly
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
		"summon_unit_id": selected_dust,
		"holder_uuid": "", # Player inventory doesn't replace a holder
		"holder_location": LocationIdentifier.new(target_location.container, target_location.index),
		"is_resurrection": false,
		"spawn_source_uuid": _source_uuid,
		"unit_tier": tier
	}
	
	# We also need a LOG event to show the spawn
	result.events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "Dust Elite spawned a Dust unit in the player inventory."
	}))
	
	return result
