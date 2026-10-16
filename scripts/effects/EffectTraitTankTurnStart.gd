# res://scripts/effects/EffectTraitTankTurnStart.gd
@tool
extends EffectDefinition

## Turn-Start Tank trait effect granted by Tank Trait Trinket.
## Triggered on_turn_start.
## Thresholds (Units):
##   L3 (4 Units): Frontmost Tank gains 1 additional Armor.

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
	var tank_units: int = int(active_traits.get("TANK", 0))
	if tank_units < 4:
		return EffectResult.empty()

	var frontmost_tank = battle_manager.get_frontmost_unit_on_team(is_player, "TANK")
	if not is_instance_valid(frontmost_tank) or frontmost_tank.current_hp <= 0:
		return EffectResult.empty()

	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"ability_trait_tank_turn_start")

	var old_armor = frontmost_tank.get_status_effect_amount(&"armor")
	var new_armor = battle_manager.apply_stat_delta(frontmost_tank, "armor_stacks", 1)

	result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
		"source_uuid": source_uuid,
		"target_uuids": [frontmost_tank.ball_uuid],
		"ability_id": ability_id,
		"visual_payload": CombatPayload.status_change(source_uuid, 1, "armor_stacks", [old_armor], [new_armor])
	}))

	result.state_applied = true
	return result
