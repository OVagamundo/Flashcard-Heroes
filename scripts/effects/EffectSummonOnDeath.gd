@tool
extends EffectDefinition

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, _context: Dictionary) -> Dictionary:
	# 1. Validate source (the item triggering on_death)
	var source_inst = battle_manager.get_instance(source_uuid)
	if not is_instance_valid(source_inst):
		return {}

	# 2. Get the holder unit (the item is equipped on someone)
	if source_inst.get_definition().category != &"ITEM":
		return {}
	
	if source_inst.equipped_on_uuid.is_empty():
		return {}
	
	var holder_uuid = source_inst.equipped_on_uuid
	var holder_inst = battle_manager.get_instance(holder_uuid)
	if not is_instance_valid(holder_inst):
		return {}
	
	# 3. Get the holder's location (this is where we'll summon)
	var holder_location = battle_manager.get_location_for_uuid(holder_uuid)
	if not is_instance_valid(holder_location):
		return {}

	# 4. Pick a random Tier 1 Unit
	var tier_1_units = []
	for unit_def in Database.units.values():
		if unit_def.tier == 1 and unit_def.category == &"UNIT" and not unit_def.is_hero:
			tier_1_units.append(unit_def)
	
	if tier_1_units.is_empty():
		return {}
	
	var random_def = tier_1_units.pick_random()
	
	# 5. Return summon instructions (NOT the instance!)
	# BattleManager will create the instance during simulation
	return {
		"summon_unit_id": random_def.id,
		"holder_uuid": holder_uuid,
		"holder_location": holder_location
	}
