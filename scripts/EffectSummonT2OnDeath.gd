@tool
extends EffectDefinition
const C = preload("res://scripts/Constants.gd")

## Summon a random T2 unit when the holder dies
## Uses context data instead of querying instances (Effect Decoupling Rule)

## Find empty slot searching from back to front based on team
## Player team: back is index 4, front is index 0 (search 4→0)
## Enemy team: back is index 0, front is index 4 (search 0→4)
func _find_empty_slot_back_to_front(container: DataContainer, is_enemy_team: bool) -> int:
	if is_enemy_team:
		# Enemy back-to-front: 0→4
		for i in range(5):
			if container.get_uuid(i).is_empty():
				return i
	else:
		# Player back-to-front: 4→0
		for i in range(4, -1, -1):
			if container.get_uuid(i).is_empty():
				return i
	return -1

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
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
	

	# 2. Check if the slot is already occupied by a resurrection
	# If another effect (like Soul Echo) already claimed this slot, find an alternative
	var container = battle_manager.get_container(holder_location.container)
	if is_instance_valid(container):
		var slot_uuid = container.get_uuid(holder_location.index)
		print("[EST2OD] Checking slot %d. Holder: %s, Slot Content: %s" % [holder_location.index, holder_uuid, slot_uuid])
		
		if not slot_uuid.is_empty() and slot_uuid != holder_uuid:
			print("[EST2OD] Slot occupied by %s. Finding alternative..." % slot_uuid)
			# Slot is occupied by another unit - find an empty slot using back-to-front search
			# Player team: back is index 4, front is index 0 (search 4→0)
			# Enemy team: back is index 0, front is index 4 (search 0→4)
			var is_enemy_team = holder_location.container == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
			var empty_slot = _find_empty_slot_back_to_front(container, is_enemy_team)
			print("[EST2OD] Found empty slot: %d" % empty_slot)
			if empty_slot == -1:
				# No lineup slots available
				if is_enemy_team:
					# Enemy team: cancel summon entirely (enemies have no discard pile)
					return EffectResult.empty()
				else:
					# Player team: send to discard pile
					var discard_container = battle_manager.get_container(C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
					if is_instance_valid(discard_container):
						var discard_slot = discard_container.find_first_empty_slot()
						if discard_slot != -1:
							var discard_location = LocationIdentifier.new()
							discard_location.container = C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE
							discard_location.index = discard_slot
							holder_location = discard_location
						else:
							return EffectResult.empty() # Discard pile is also full, cancel summon
					else:
						return EffectResult.empty() # No discard container, cancel summon
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
