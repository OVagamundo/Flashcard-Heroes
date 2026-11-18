# res://scripts/effects/EffectDustEnterBoard.gd
@tool
extends EffectDefinition

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, _context: TriggerContext) -> EffectResult:
	var source: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source) or source.current_hp <= 0:
		return EffectResult.empty()

	var loc_tag: StringName = source.location_container_tag
	if loc_tag != C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP and loc_tag != C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
		return EffectResult.empty()

	if source.has_tag(&"dust_status_applied"):
		return EffectResult.empty()

	source.add_tag(&"dust_status_applied")
	var s_def = source.get_definition()
	var tier_amount: int = int(s_def.tier) if is_instance_valid(s_def) else 1
	tier_amount = maxi(1, tier_amount)

	var old_burn: int = source.get_status_effect_amount(&"burn")
	var new_burn: int = battle_manager.apply_stat_delta(source, "burn_stacks", tier_amount, source_uuid)

	var old_static: int = source.get_status_effect_amount(&"static")
	var new_static: int = battle_manager.apply_stat_delta(source, "static_stacks", tier_amount, source_uuid)

	var result := EffectResult.new()
	var burn_payload := CombatPayload.status_change(source_uuid, tier_amount, "burn_stacks", [old_burn], [new_burn])
	result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
		"source_uuid": source_uuid,
		"target_uuids": [source_uuid],
		"visual_payload": burn_payload
	}))

	var static_payload := CombatPayload.status_change(source_uuid, tier_amount, "static_stacks", [old_static], [new_static])
	result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
		"source_uuid": source_uuid,
		"target_uuids": [source_uuid],
		"visual_payload": static_payload
	}))

	return result
