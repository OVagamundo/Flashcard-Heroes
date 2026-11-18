# res://scripts/effects/EffectRecruitingCharm.gd
@tool
class_name EffectRecruitingCharm
extends EffectDefinition

## Recruiting Charm: At turn start, if Gold >= 1 and a shelf slot is open,
## spends 1 Gold to hire a Level 1 Tier 1 Mercenary (Coinling / ?MerSpe) onto the player's shelf.

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var is_simulation: bool = context.is_simulation
	if not is_simulation:
		return EffectResult.empty()

	if not is_instance_valid(GameManager.run_state) or GameManager.run_state.gold < 1:
		return EffectResult.empty()

	var shelf = battle_manager.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF)
	if not is_instance_valid(shelf):
		return EffectResult.empty()

	if battle_manager._state.find_first_empty_player_shelf_slot() == -1:
		return EffectResult.empty()

	var spent = battle_manager.spend_gold(1, source_uuid)
	if not spent:
		return EffectResult.empty()

	var result := EffectResult.new()
	result.summon_units_request = [{"unit_id": &"?MerSpe", "level": 1}]
	result.summon_team = "PLAYER"
	result.summon_container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF
	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "Recruiting Charm hires 1 Coinling (?MerSpe) to the shelf for 1 Gold!"
	}))
	result.state_applied = true
	return result
