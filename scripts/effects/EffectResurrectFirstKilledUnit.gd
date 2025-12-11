@tool
extends EffectDefinition

## Effect: Resurrect the first non-hero unit that died this turn.
## Returns summon instructions for BattleManager to process.
## Only triggers once per team per turn.
## Uses context data instead of querying instances (Effect Decoupling Rule)

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Dictionary:
	print("[DEBUG ResurrectEffect] execute called - fainting_ally_team=%s" % context.get("fainting_ally_team", "MISSING"))
	
	# 1. Determine team from context - the fainting ally's team is our team
	# (Soul Echo triggers on_ally_death when a teammate dies)
	var fainting_ally_team: String = context.get("fainting_ally_team", "")
	if fainting_ally_team.is_empty():
		print("[DEBUG ResurrectEffect] EXIT: fainting_ally_team is empty")
		return {}
	
	var is_player_team := (fainting_ally_team == "PLAYER")

	# 2. Check if resurrection already happened this turn
	var resurrection_flag_key := "resurrection_done_player" if is_player_team else "resurrection_done_enemy"
	if battle_manager._turn_metadata.get(resurrection_flag_key, false):
		print("[DEBUG ResurrectEffect] EXIT: resurrection already done for %s" % fainting_ally_team)
		return {} # Already resurrected this turn

	# 3. Get first-killed unit metadata
	var first_killed_key := "first_killed_player_unit" if is_player_team else "first_killed_enemy_unit"
	var first_killed_data: Dictionary = battle_manager._turn_metadata.get(first_killed_key, {})
	print("[DEBUG ResurrectEffect] Checking %s: %s" % [first_killed_key, first_killed_data])
	if first_killed_data.is_empty():
		print("[DEBUG ResurrectEffect] EXIT: no first_killed_data for key %s" % first_killed_key)
		return {} # No unit died yet

	# 4. Get the definition of the unit to resurrect
	var def_id: StringName = first_killed_data.get("def_id", &"")
	var unit_def = Database.get_definition(def_id)
	if not is_instance_valid(unit_def):
		return {}

	# 5. Get the exact slot where they died
	var death_location: LocationIdentifier = first_killed_data.get("location_snapshot")
	if not is_instance_valid(death_location):
		return {}

	# 6. Mark resurrection as done for this team
	battle_manager._turn_metadata[resurrection_flag_key] = true

	# 7. Return resurrection instructions (like summon but uses death slot)
	return {
		"summon_unit_id": def_id,
		"holder_uuid": "", # No holder - this is a resurrection
		"holder_location": death_location,
		"is_resurrection": true # Flag for special handling
	}
