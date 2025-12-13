@tool
extends EffectDefinition

## Summon a random T2 unit when the holder dies
## Uses context data instead of querying instances (Effect Decoupling Rule)

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Dictionary:
	# The source is a unit triggering on_death
	# Context contains data about the dying unit
	# Semantic keys: dying_uuid, dying_location
	# 1. Get holder location from context (this is where we summon)
	var holder_location = context.get("dying_location")
	if not is_instance_valid(holder_location):
		return {}
	
	# Get holder info from context (using new semantic key)
	var holder_uuid = context.get("dying_uuid", "")
	
	# Validate this is the correct source (the dying unit must have this ability)
	if source_uuid != holder_uuid:
		return {}
	

	# 2. Check if the slot is already occupied by a resurrection
	# If another effect (like Soul Echo) already claimed this slot, find an alternative
	var container = battle_manager.get_container(holder_location.container)
	if is_instance_valid(container):
		var slot_uuid = container.get_uuid(holder_location.index)
		if not slot_uuid.is_empty() and slot_uuid != holder_uuid:
			# Slot is occupied by another unit - find an empty slot
			var empty_slot = container.find_first_empty_slot()
			if empty_slot == -1:
				# No lineup slots available - send to discard pile instead
				var discard_container = battle_manager.get_container(battle_manager.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
				if is_instance_valid(discard_container):
					var discard_slot = discard_container.find_first_empty_slot()
					if discard_slot != -1:
						var discard_location = LocationIdentifier.new()
						discard_location.container = battle_manager.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE
						discard_location.index = discard_slot
						holder_location = discard_location
					else:
						return {} # Discard pile is also full, cancel summon
				else:
					return {} # No discard container, cancel summon
			else:
				# Create a new LocationIdentifier for the alternative slot
				var alt_location = LocationIdentifier.new()
				alt_location.container = holder_location.container
				alt_location.index = empty_slot
				holder_location = alt_location

	# 3. Pick a random Tier 2 Unit
	var tier_2_units = []
	for unit_def in Database.units.values():
		if unit_def.tier == 2 and unit_def.category == &"UNIT" and not unit_def.is_hero:
			tier_2_units.append(unit_def)
	
	if tier_2_units.is_empty():
		return {}
	
	var random_def = tier_2_units.pick_random()
	
	# 4. Return summon instructions (NOT the instance!)
	# BattleManager will create the instance during simulation
	return {
		"summon_unit_id": random_def.id,
		"holder_uuid": holder_uuid,
		"holder_location": holder_location
	}
