# res://scripts/effects/EffectStudyHallBell.gd
@tool
class_name EffectStudyHallBell
extends EffectDefinition

## Study Hall Bell: At turn start, if available, spend 1 Token to summon a Level 1 ?NovPla
## into the first open lineup slot (or shelf if full). Battle-only summon.

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var is_simulation: bool = context.is_simulation
	if not is_simulation:
		return EffectResult.empty()

	if battle_manager.get_gacha_tokens() < 1:
		return EffectResult.empty()

	var lineup = battle_manager.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var shelf = battle_manager.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF)
	if not is_instance_valid(lineup) or not is_instance_valid(shelf):
		return EffectResult.empty()

	var target_container_tag: StringName = &""
	for i in range(lineup.get_size()):
		if lineup.get_uuid(i) == "":
			target_container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
			break

	if target_container_tag == &"":
		if battle_manager._state.find_first_empty_player_shelf_slot() != -1:
			target_container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF

	if target_container_tag == &"":
		return EffectResult.empty()

	var spent: bool = battle_manager.spend_gacha_tokens(1, source_uuid)
	if not spent:
		return EffectResult.empty()

	var result := EffectResult.new()
	result.summon_units_request = [{"unit_id": &"?NovPla", "level": 1}]
	result.summon_team = "PLAYER"
	result.summon_container_tag = target_container_tag
	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "Study Hall Bell rings! Spent 1 Token to summon a Level 1 Novisprout (?NovPla)!"
	}))
	result.state_applied = true
	return result
