@tool
extends EffectDefinition

## Effect: Resurrect the first non-hero unit that died this turn.
## Returns summon instructions for BattleManager to process.
## Only triggers once per team per turn.
## Uses context data instead of querying instances (Effect Decoupling Rule)

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	# 1. Determine team from context - the fainting ally's team is our team
	# (Soul Echo triggers on_ally_death when a teammate dies)
	var fainting_ally_team: String = context.get("fainting_ally_team", "")
	if fainting_ally_team.is_empty():
		print("[SoulEcho] Failed: fainting_ally_team is empty")
		return EffectResult.empty()
	
	var is_player_team := (fainting_ally_team == "PLAYER")

	# 2. Check if resurrection already happened this turn
	var resurrection_flag_key := "resurrection_done_player" if is_player_team else "resurrection_done_enemy"
	if battle_manager._turn_metadata.get(resurrection_flag_key, false):
		print("[SoulEcho] Failed: resurrection already done for ", fainting_ally_team)
		return EffectResult.empty() # Already resurrected this turn

	# 3. Get first-killed unit metadata
	var first_killed_key := "first_killed_player_unit" if is_player_team else "first_killed_enemy_unit"
	var first_killed_data: Dictionary = battle_manager._turn_metadata.get(first_killed_key, {})
	if first_killed_data.is_empty():
		print("[SoulEcho] Failed: no first_killed_data for ", fainting_ally_team)
		return EffectResult.empty() # No unit died yet

	# 4. Get the definition of the unit to resurrect
	var def_id: StringName = first_killed_data.get("def_id", &"")
	var unit_def = Database.get_definition(def_id)
	if not is_instance_valid(unit_def):
		print("[SoulEcho] Failed: invalid unit def ", def_id)
		return EffectResult.empty()

	# 4b. Hero check - don't resurrect the hero (game over condition)
	var is_hero: bool = false
	if "is_hero" in unit_def:
		is_hero = unit_def.is_hero
	elif String(def_id).to_lower() == "hero":
		is_hero = true
		
	if is_hero:
		print("[SoulEcho] Failed: cannot resurrect the hero")
		return EffectResult.empty()

	# 5. Determine where to resurrect
	# We prefer the slot where the triggering ally died (fainting_ally_location)
	# This matches Soul Caller and other summoning items.
	# Fallback to the original death location if necessary.
	var fainting_ally_location: LocationIdentifier = context.get("fainting_ally_location")
	var death_location: LocationIdentifier = first_killed_data.get("location_snapshot")
	
	var summon_location: LocationIdentifier = fainting_ally_location
	if not is_instance_valid(summon_location):
		summon_location = death_location
		
	if not is_instance_valid(summon_location) or summon_location.index < 0:
		var loc_str = str(summon_location.index) if is_instance_valid(summon_location) else "null"
		print("[SoulEcho] Failed: invalid summon location index ", loc_str)
		return EffectResult.empty()

	# 6. Mark resurrection as done for this team
	print("[SoulEcho] SUCCESS: Resurrecting ", def_id, " at ", summon_location.index)
	battle_manager._turn_metadata[resurrection_flag_key] = true

	# 7. Return EffectResult with resurrection instructions
	var result := EffectResult.new()
	result.summon_request = {
		"summon_unit_id": def_id,
		"holder_uuid": first_killed_data.get("uuid", ""), # Pass original UUID to allow overwriting the corpse
		"holder_location": summon_location,
		"is_resurrection": true # Flag for special handling
	}
	return result
