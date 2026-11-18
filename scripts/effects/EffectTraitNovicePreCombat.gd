@tool
extends EffectDefinition

## Cumulative Novice Crest rewards, using the unspent wallet at Pre-Battle.
const C = preload("res://scripts/Constants.gd")
const ApplyStatus = preload("res://scripts/EffectApplyStatus.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	if not context.is_simulation:
		return EffectResult.empty()

	var crest: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	assert(crest != null, "Novice Crest Pre-Battle requires a registered source")
	assert(crest.location_container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS, "Novice Crest is player-only")
	var active_traits: Dictionary = battle_manager.get_active_traits("PLAYER")
	var novice_count: int = int(active_traits.get("NOVICE", 0))
	var token_pairs: int = int(battle_manager.get_gacha_tokens() / 2)
	if novice_count < 3 or token_pairs == 0:
		return EffectResult.empty()

	# The shared Gold API emits wallet events and triggers On Gold Earned reactions.
	battle_manager.earn_gold(token_pairs, source_uuid)
	var result := EffectResult.new()
	if novice_count >= 4:
		var target_uuids: Array[String] = []
		var units: Array[GachaBallInstance] = battle_manager.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
		for unit: GachaBallInstance in units:
			if unit.current_hp > 0 and battle_manager.has_trait(unit, "NOVICE"):
				target_uuids.append(unit.ball_uuid)

		var status_ids: Array[StringName] = [&"armor"]
		if novice_count >= 5:
			status_ids.append(&"spikes")
		for status_id: StringName in status_ids:
			var effect: EffectDefinition = ApplyStatus.new()
			effect.parameters = {"status_id": String(status_id), "amount": token_pairs}
			var status_result: EffectResult = effect.execute(source_uuid, target_uuids, battle_manager, context)
			result.events.append_array(status_result.events)

	result.state_applied = true
	return result
