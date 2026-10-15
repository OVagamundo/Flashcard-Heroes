# res://scripts/effects/EffectTraitPowerBuff.gd
@tool
extends EffectDefinition

## Start-of-Combat PWR buff granted by trait trinkets.
## Triggered on_pre_combat when the battle button is pressed.
## Grants +1 PWR for 2 units, +2 for 3 units, +3 for 4 units, +4 for 5+ units of the matching trait.

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation: bool = context.get("is_simulation", false)
	if not is_simulation:
		return EffectResult.empty()

	var trinket = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(trinket):
		return EffectResult.empty()

	var trinket_def = trinket.get_definition()
	var trait_name: String = ""
	if is_instance_valid(trinket_def) and "linked_trait_id" in trinket_def and trinket_def.linked_trait_id != &"":
		trait_name = String(trinket_def.linked_trait_id).to_upper()
	if trait_name.is_empty():
		trait_name = String(self.parameters.get("trait_name", "")).to_upper()
	if trait_name.is_empty():
		return EffectResult.empty()

	# Determine team
	var team: String = context.get("team", "")
	if team.is_empty():
		var container_tag = trinket.location_container_tag
		if container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS:
			team = "ENEMY"
		else:
			team = "PLAYER"

	var active_traits: Dictionary = battle_manager.get_active_traits(team)
	var trait_count: int = int(active_traits.get(trait_name, 0))
	if trait_count < 2:
		return EffectResult.empty()

	var buff_amount: int = clampi(trait_count - 1, 1, 4)

	var lineup_container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if team == "PLAYER" else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var lineup_units = battle_manager.get_instances_in_container(lineup_container_tag)
	var all_instances: Dictionary = battle_manager.get_all_instances()

	var target_uuids: Array[String] = []
	var old_pwrs: Array[int] = []
	var new_pwrs: Array[int] = []

	for unit in lineup_units:
		if not is_instance_valid(unit) or unit.current_hp <= 0:
			continue
		if not _unit_matches_trait(unit, trait_name, all_instances):
			continue

		var old_p: int = unit.current_pwr
		var new_p: int = battle_manager.apply_stat_delta(unit, "pwr", buff_amount, source_uuid, C.ACTION_BUFF, true)
		target_uuids.append(unit.ball_uuid)
		old_pwrs.append(old_p)
		new_pwrs.append(new_p)

	if target_uuids.is_empty():
		return EffectResult.empty()

	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"ability_trait_buff")
	var trait_def: Dictionary = C.TRAIT_DEFINITIONS.get(trait_name, {})
	var trait_display = tr(trait_def.get("display_name_key", trait_name))

	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "[%s] +%d PWR granted to %d units (%s)" % [trait_display, buff_amount, target_uuids.size(), team]
	}))

	result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
		"source_uuid": source_uuid,
		"target_uuids": target_uuids,
		"ability_id": ability_id,
		"action_type": C.ACTION_BUFF,
		"trigger_type": context.get("trigger_type", &"on_pre_combat"),
		"ability_holder_uuid": source_uuid,
		"visual_payload": CombatPayload.pwr_buff(source_uuid, buff_amount, old_pwrs, new_pwrs)
	}))

	result.state_applied = true
	return result

func _unit_matches_trait(unit: GachaBallInstance, trait_name: String, all_instances: Dictionary) -> bool:
	var upper := trait_name.to_upper()
	for tag in unit.get_active_tags(all_instances):
		var s := String(tag).to_upper()
		if s == upper or s == "SOUL_" + upper:
			return true
	return false
