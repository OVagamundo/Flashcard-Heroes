@tool
extends EffectDefinition
const C = preload("res://scripts/Constants.gd")

## Summon a random T2 unit when the holder dies
## Uses context data instead of querying instances (Effect Decoupling Rule)

func execute(source_uuid: String, _targets: Array[String], _battle_manager: Node, context: Dictionary) -> EffectResult:
	# The source is a unit triggering on_death
	# Context contains data about the dying unit
	# Semantic keys: dying_uuid, dying_location
	# 1. Get holder location from context (this is where we summon)
	var holder_location = context.get("dying_location")
	if not is_instance_valid(holder_location):
		return EffectResult.empty()
	
	# Get holder info from context (using new semantic key)
	var holder_uuid = context.get("dying_uuid", "")
	
	# Validate this is the correct source (the dying unit must have this ability)
	if source_uuid != holder_uuid:
		return EffectResult.empty()

	# 2. Request summon at holder's location
	# We pass the original holder location and UUID.
	# EffectHandlers will handle collision resolution (checking if slot occupied by non-holder)
	# and find an alternative slot if needed using the Unified Summon Slot Finder.

	# 3. Pick a random Tier 2 Unit
	var tier_2_units = []
	for unit_def in Database.units.values():
		if unit_def.tier == 2 and unit_def.category == &"UNIT" and not unit_def.is_hero:
			tier_2_units.append(unit_def)
	
	if tier_2_units.is_empty():
		return EffectResult.empty()
	
	var random_def = tier_2_units.pick_random()
	
	# 4. Return EffectResult with summon instructions
	# CombatSimulator will process summon_request via EffectHandlers
	var result := EffectResult.new()
	result.summon_request = {
		"summon_unit_id": random_def.id,
		"holder_uuid": holder_uuid,
		"holder_location": holder_location
	}
	return result
