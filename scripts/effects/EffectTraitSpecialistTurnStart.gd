# res://scripts/effects/EffectTraitSpecialistTurnStart.gd
@tool
extends EffectDefinition

## Turn-Start Specialist trait effect granted by Specialist Trait Trinket.
## Triggered on_turn_start.
## Thresholds (Units):
##   L4 (5 Units): Frontmost Specialist gains +1 PWR per 5 Gold currently held.

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation: bool = context.get("is_simulation", false)
	if not is_simulation:
		return EffectResult.empty()

	var trinket = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(trinket):
		return EffectResult.empty()

	var team: String = context.get("team", "")
	if team.is_empty():
		var container_tag = trinket.location_container_tag
		if container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS:
			team = "ENEMY"
		else:
			team = "PLAYER"

	var is_player = (team == "PLAYER")
	var active_traits: Dictionary = battle_manager.get_active_traits(team)
	var specialist_units: int = int(active_traits.get("SPECIALIST", 0))
	if specialist_units < 5:
		return EffectResult.empty()

	var frontmost_specialist = battle_manager.get_frontmost_unit_on_team(is_player, "SPECIALIST")
	if not is_instance_valid(frontmost_specialist) or frontmost_specialist.current_hp <= 0:
		return EffectResult.empty()

	var gold: int = 0
	if is_player and is_instance_valid(GameManager.run_state):
		gold = GameManager.run_state.gold

	var pwr_bonus: int = int(floor(gold / 5.0))
	if pwr_bonus <= 0:
		return EffectResult.empty()

	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"ability_trait_specialist_turn_start")

	var old_pwr = frontmost_specialist.current_pwr
	var new_pwr = battle_manager.apply_stat_delta(frontmost_specialist, "pwr", pwr_bonus, source_uuid, C.ACTION_BUFF)

	result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
		"source_uuid": source_uuid,
		"target_uuids": [frontmost_specialist.ball_uuid],
		"ability_id": ability_id,
		"action_type": C.ACTION_BUFF,
		"visual_payload": CombatPayload.pwr_change(source_uuid, pwr_bonus, [old_pwr], [new_pwr])
	}))

	result.state_applied = true
	return result
