# res://scripts/effects/EffectSpikeslimeEnter.gd
@tool
extends EffectDefinition

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, _context: TriggerContext) -> EffectResult:
	var source: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source) or source.current_hp <= 0:
		return EffectResult.empty()

	if source.has_tag(&"spikeslime_initialized"):
		return EffectResult.empty()

	source.add_tag(&"spikeslime_initialized")
	var spikes_amount: int = maxi(1, source.level)

	var old_s = source.get_status_effect_amount(&"spikes")
	var new_s = battle_manager.apply_stat_delta(source, "spikes_stacks", spikes_amount, source_uuid)

	var result := EffectResult.new()
	var payload := CombatPayload.status_change(source_uuid, spikes_amount, "spikes_stacks", [old_s], [new_s])
	result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
		"source_uuid": source_uuid,
		"target_uuids": [source_uuid],
		"visual_payload": payload
	}))
	return result
