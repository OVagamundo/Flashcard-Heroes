# res://scripts/effects/EffectTraitWater.gd
@tool
extends EffectDefinition

## Start-of-Combat Water trait effect granted by Water Trait Trinket.
## Triggered on_pre_combat when the battle button is pressed.
## At 2+ Water souls: Water units heal adjacent allies 1 HP.

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

	var active_traits: Dictionary = battle_manager.get_active_traits(team)
	var water_souls: int = int(active_traits.get("WATER", 0))
	if water_souls < 2:
		return EffectResult.empty()

	var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if team == "PLAYER" else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var units = battle_manager.get_instances_in_container(container_tag)

	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"ability_trait_water")

	for unit in units:
		if not is_instance_valid(unit) or unit.current_hp <= 0:
			continue
		if not battle_manager._has_trait_soul(unit, "WATER"):
			continue

		var adjacent_allies = battle_manager._get_adjacent_allies(unit)
		var water_target_uuids: Array[String] = []
		var water_old_hp: Array[int] = []
		var water_new_hp: Array[int] = []
		var water_max_hp: Array[int] = []

		for ally in adjacent_allies:
			if not is_instance_valid(ally) or ally.current_hp <= 0:
				continue

			var old_hp = ally.current_hp
			var new_hp = battle_manager.apply_stat_delta(ally, "hp", 1, unit.ball_uuid, C.ACTION_HEAL)

			if new_hp > old_hp:
				var ally_def = ally.get_definition()
				var max_hp = ally_def.base_hp if is_instance_valid(ally_def) else 0
				water_target_uuids.append(ally.ball_uuid)
				water_old_hp.append(old_hp)
				water_new_hp.append(new_hp)
				water_max_hp.append(max_hp)

		if not water_target_uuids.is_empty():
			result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
				"source_uuid": unit.ball_uuid,
				"target_uuids": water_target_uuids,
				"ability_id": ability_id,
				"action_type": C.ACTION_HEAL,
				"visual_payload": CombatPayload.heal(unit.ball_uuid, 1, water_old_hp, water_new_hp, water_max_hp)
			}))
			result.state_applied = true

	return result
