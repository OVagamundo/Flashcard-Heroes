@tool
extends EffectDefinition

## Mirror Transform: Transforms into the enemy in the mirror slot.
## - Triggers on_turn_start.
## - Discards all equipped items.
## - Removes self.
## - Summons base copy of target enemy in self slot.

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, _context: Dictionary) -> EffectResult:
	var source: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source):
		return EffectResult.empty()
		
	# 1. Identify Mirror Slot Target
	
	var my_loc = source.get_location()
	if not is_instance_valid(my_loc) or not (my_loc.container in [C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP]):
		return EffectResult.empty()
		
	var is_player = battle_manager._is_player_unit(source)
	var mirror_index = 4 - my_loc.index
	var target_container_tag = C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if is_player else C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	
	var target_container = battle_manager.get_container(target_container_tag)
	if not is_instance_valid(target_container):
		return EffectResult.empty()
		
	var target_uuid = target_container.get_uuid(mirror_index)
	if target_uuid.is_empty():
		return EffectResult.empty() # No target in mirror slot
		
	var target_unit = battle_manager.get_instance_by_uuid(target_uuid)
	if not is_instance_valid(target_unit):
		return EffectResult.empty()
		
	var target_def = target_unit.get_definition()
	if not is_instance_valid(target_def):
		return EffectResult.empty()
		
	# VALIDATION: Only transform into regular units (Tier 1-3).
	if target_def.is_hero:
		return EffectResult.empty()
		
	# Safety check for Bosses
	if target_def.id.begins_with("boss_") or target_def.id == "enemy_hero":
		return EffectResult.empty()

	if target_def.category != &"UNIT":
		return EffectResult.empty()
	
	# 2. RETURN TRANSFORM REQUEST (Simulation Only)
	# We do NOT mutate state here. We request the transformation.
	
	# Calculate Level
	var level_delta = parameters.get("level_delta", 0)
	var max_level = parameters.get("max_level", false)
	var target_level = target_unit.level
	if max_level:
		target_level = 3
	else:
		target_level += level_delta
	
	target_level = clamp(target_level, 1, 3)

	var result := EffectResult.new()
	
	result.transform_request = {
		"self_uuid": source_uuid,
		"target_unit_id": target_def.id,
		"target_level": target_level,
		"target_name": BattleHelpers.get_instance_display_name(target_unit)
	}
	
	# Logs and Visuals are handled by the Handler or added here?
	# We can add the "Transforming..." log here, but the actual "Summoned X" log comes from the summon handler.
	# Let's let the handler generate the specific transform events to keep it sync.
	
	return result
