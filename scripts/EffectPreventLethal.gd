# res://scripts/EffectPreventLethal.gd
@tool
extends EffectDefinition

const C = preload("res://scripts/Constants.gd")

## Prevent lethal damage once per turn by setting HP directly to 1.
## This is a state save, not a heal, and does not trigger heal abilities.
func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var is_simulation: bool = context.is_simulation
	var damaged_unit_uuid: String = context.damaged_uuid
	var victim_team: String = context.damaged_team
	var victim_current_hp: int = context.damaged_current_hp if context.damaged_current_hp != -1 else 1
	var victim_category: StringName = context.damaged_category
	var trinket_team: String = context.team

	if damaged_unit_uuid.is_empty() or victim_team.is_empty() or trinket_team.is_empty():
		return EffectResult.empty()
	if victim_team != trinket_team or victim_category != &"UNIT" or victim_current_hp > 0:
		return EffectResult.empty()

	var aegis_flag_key: String = "aegis_prevented_" + trinket_team
	if battle_manager._turn_metadata.get(aegis_flag_key, false):
		return EffectResult.empty()

	var victim: GachaBallInstance = battle_manager.get_instance_by_uuid(damaged_unit_uuid)
	assert(victim != null, "EffectPreventLethal: damaged unit %s must exist while resolving its lethal save" % damaged_unit_uuid)
	var heal_amount: int = 1 - victim_current_hp
	battle_manager._turn_metadata[aegis_flag_key] = true
	victim.set_current_hp_silent(1)
	battle_manager._state.clear_lethal_transition(victim.ball_uuid)

	if not is_simulation:
		var non_sim_result := EffectResult.new()
		non_sim_result.state_applied = true
		return non_sim_result

	var result := EffectResult.new()
	var victim_name: String = BattleHelpers.get_instance_display_name(victim)
	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "Aegis Charm saves %s from lethal damage!" % victim_name
	}))

	var save_payload := CombatPayload.new()
	save_payload.saved_uuid = damaged_unit_uuid
	save_payload.heal_amount = heal_amount
	result.add_event(CombatEvent.new(CombatEvent.Type.PREVENT_KNOCKOUT, {
		"source_uuid": _source_uuid,
		"target_uuids": [damaged_unit_uuid],
		"ability_id": context.ability_id if context.ability_id != &"" else &"aegis_charm",
		"action_type": C.TRIGGER_PREVENT_KNOCKOUT,
		"visual_payload": save_payload
	}))

	result.state_applied = true
	return result
