# res://scripts/effects/EffectRecruitingCharm.gd
@tool
class_name EffectRecruitingCharm
extends EffectDefinition

## Recruiting Charm: At turn start, if Gold >= 1 and a bench slot is open,
## spends 1 Gold to hire a Level 1 Tier 1 Mercenary (?MerSpe) onto the player's bench.

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation: bool = context.get("is_simulation", false)
	if not is_simulation:
		return EffectResult.empty()

	if not is_instance_valid(GameManager.run_state) or GameManager.run_state.gold < 1:
		return EffectResult.empty()

	var bench = battle_manager.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH)
	if not is_instance_valid(bench):
		return EffectResult.empty()

	var has_empty_slot := false
	for i in range(bench.get_size()):
		if bench.get_uuid(i) == "":
			has_empty_slot = true
			break

	if not has_empty_slot:
		return EffectResult.empty()

	var spent = battle_manager.spend_gold(1, source_uuid)
	if not spent:
		return EffectResult.empty()

	var result := EffectResult.new()
	result.summon_units_request = [{"unit_id": &"?MerSpe", "level": 1}]
	result.summon_team = "PLAYER"
	result.summon_container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH
	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "Recruiting Charm hires 1 ?MerSpe to the bench for 1 Gold!"
	}))
	result.state_applied = true
	return result
