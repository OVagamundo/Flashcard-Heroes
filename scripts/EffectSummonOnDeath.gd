@tool
extends EffectDefinition
const C = preload("res://scripts/Constants.gd")

## Summon a random T1 unit when the holder dies
## Uses context data instead of querying instances (Effect Decoupling Rule)

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	# The source is an item triggering on_death
	# Context contains data about the dying unit (the holder)
	# Semantic keys: dying_uuid, dying_location
	# 1. Get holder location from context (this is where we summon)
	var holder_location = context.get("dying_location")
	if not is_instance_valid(holder_location):
		return EffectResult.empty()
	
	# Get holder info from context (using new semantic key)
	var holder_uuid = context.get("dying_uuid", "")
	
	# 2. Find this item in the equipped_items snapshot to validate it's the right item
	var equipped_items: Array = context.get("equipped_items", [])
	var item_found := false
	for item_data in equipped_items:
		if item_data.get("uuid") == source_uuid:
			item_found = true
			break
	
	# If this item wasn't equipped on the dying unit, something is wrong
	if not item_found:
		return EffectResult.empty()

	# 3. Request summon at holder's location
	# We pass the original holder location and UUID.
	# EffectHandlers will handle collision resolution (checking if slot occupied by non-holder)
	# and find an alternative slot if needed using the Unified Summon Slot Finder.

	# 4. Pick a random Tier 1 Unit
	var tier_1_units = []
	for unit_def in Database.units.values():
		if unit_def.tier == 1 and unit_def.category == &"UNIT" and not unit_def.is_hero:
			tier_1_units.append(unit_def)
	
	if tier_1_units.is_empty():
		return EffectResult.empty()
	
	var random_def = tier_1_units.pick_random()
	
	# 5. Return EffectResult with summon instructions
	# CombatSimulator will process summon_request via EffectHandlers
	var result := EffectResult.new()
	result.summon_request = {
		"summon_unit_id": random_def.id,
		"holder_uuid": holder_uuid,
		"holder_location": holder_location
	}
	return result
