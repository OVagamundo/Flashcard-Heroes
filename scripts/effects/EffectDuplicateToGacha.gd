# res://scripts/effects/EffectDuplicateToGacha.gd
@tool
extends EffectDefinition

## Generic effect that duplicates a unit or item to the Gacha Machine inventory of the specified tier upon death.
## Integrates directly with the BattleAnimator's arc spawning systems.
func execute(source_uuid: String, _targets: Array[String], _battle_manager: Node, context: TriggerContext) -> EffectResult:
	var dup_def_id = parameters.get("duplicate_def_id", &"")
	var dup_type = parameters.get("duplicate_type", "UNIT")
	var dup_tier = int(parameters.get("duplicate_tier", 1))
	var ko_uuid: String = context.knocked_out_uuid if not context.knocked_out_uuid.is_empty() else source_uuid
	
	# Team-awareness check: Ensure only player-owned units/items duplicate to the gacha machine
	var dying_team: String = context.knocked_out_team
	if dying_team != "PLAYER":
		return EffectResult.empty()
	
	# Item-specific safety check: Ensure the item is actually equipped on the dying unit
	if dup_type == "ITEM":
		var equipped: Array = context.equipped_items
		var found = false
		for item in equipped:
			if item.get("uuid") == source_uuid: 
				found = true
				break
		if not found: 
			return EffectResult.empty()

	var target_tag = StringName("BattleInventoryT%d" % dup_tier)

	var result = EffectResult.new()
	result.summon_request = {
		"summon_unit_id": dup_def_id,
		"holder_location": LocationIdentifier.new(target_tag, -1),
		"spawn_source_uuid": ko_uuid, # Feeds into the Bezier Arc spawn animation towards the Gacha Machine UI
		"unit_tier": dup_tier
	}
	return result
