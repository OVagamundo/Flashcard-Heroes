# res://scripts/effects/EffectDuplicateToGacha.gd
@tool
extends EffectDefinition

## Generic effect that duplicates a unit or item to the Gacha Machine inventory of the specified tier upon death.
## Integrates directly with the BattleAnimator's arc spawning systems.
func execute(source_uuid: String, _targets: Array[String], _battle_manager: Node, context: Dictionary) -> EffectResult:
	var dup_def_id = parameters.get("duplicate_def_id", &"")
	var dup_type = parameters.get("duplicate_type", "UNIT")
	var dup_tier = int(parameters.get("duplicate_tier", 1))
	var dying_uuid = context.get("dying_uuid", source_uuid)
	
	# Item-specific safety check: Ensure the item is actually equipped on the dying unit
	if dup_type == "ITEM":
		var equipped = context.get("equipped_items", [])
		var found = false
		for item in equipped:
			if item.get("uuid") == source_uuid: 
				found = true
				break
		if not found: 
			return EffectResult.empty()

	var target_tag = StringName("BattleInventoryT%d" % dup_tier)
	var container = _battle_manager.get_container(target_tag)
	var target_index = -1
	
	if is_instance_valid(container) and container.has_method("find_first_empty_slot"):
		target_index = container.find_first_empty_slot()
		
	if target_index == -1:
		return EffectResult.empty()

	var result = EffectResult.new()
	result.summon_request = {
		"summon_unit_id": dup_def_id,
		"holder_location": LocationIdentifier.new(target_tag, target_index),
		"spawn_source_uuid": dying_uuid, # Feeds into the Bezier Arc spawn animation towards the Gacha Machine UI
		"unit_tier": dup_tier
	}
	return result
