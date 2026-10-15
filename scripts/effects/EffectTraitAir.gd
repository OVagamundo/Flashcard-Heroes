# res://scripts/effects/EffectTraitAir.gd
@tool
extends EffectDefinition

## Start-of-Combat Air trait effect granted by Air Trait Trinket.
## Triggered on_pre_combat when the battle button is pressed.
## At 2+ Air souls: Air units steal 1 PWR from the opposite enemy.

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
	var air_souls: int = int(active_traits.get("AIR", 0))
	if air_souls < 2:
		return EffectResult.empty()

	var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if team == "PLAYER" else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var enemy_container_tag = C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if team == "PLAYER" else C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	var is_player_team = (team == "PLAYER")
	var units = battle_manager.get_instances_in_container(container_tag)
	var enemy_container = battle_manager.get_container(enemy_container_tag)
	var source_container = battle_manager.get_container(container_tag)

	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"ability_trait_air")

	for unit in units:
		if not is_instance_valid(unit) or unit.current_hp <= 0:
			continue
		if not battle_manager._has_trait_soul(unit, "AIR"):
			continue

		var source_slot = source_container.get_index_of_uuid(unit.ball_uuid)
		if source_slot == -1:
			continue

		var source_uuids = source_container.get_all_uuids()
		var source_lineup_size = source_uuids.size()
		var mirror_slot = (source_lineup_size - 1) - source_slot

		var enemy_uuids = enemy_container.get_all_uuids()
		var enemy: GachaBallInstance = null

		if mirror_slot >= 0 and mirror_slot < enemy_uuids.size():
			var enemy_uuid = enemy_uuids[mirror_slot]
			if not enemy_uuid.is_empty():
				var potential = battle_manager.get_instance_by_uuid(enemy_uuid)
				if is_instance_valid(potential) and potential.current_hp > 0:
					enemy = potential

		if enemy == null:
			if is_player_team:
				for slot_index in range(enemy_uuids.size() - 1, -1, -1):
					var uuid = enemy_uuids[slot_index]
					if uuid.is_empty(): continue
					var potential = battle_manager.get_instance_by_uuid(uuid)
					if is_instance_valid(potential) and potential.current_hp > 0:
						enemy = potential
						break
			else:
				for slot_index in range(enemy_uuids.size()):
					var uuid = enemy_uuids[slot_index]
					if uuid.is_empty(): continue
					var potential = battle_manager.get_instance_by_uuid(uuid)
					if is_instance_valid(potential) and potential.current_hp > 0:
						enemy = potential
						break

		if enemy == null:
			continue

		var enemy_old_pwr = enemy.current_pwr
		var unit_old_pwr = unit.current_pwr
		var unit_new_pwr = battle_manager.apply_stat_delta(unit, "pwr", 1, enemy.ball_uuid, C.ACTION_BUFF)
		var enemy_new_pwr = battle_manager.apply_stat_delta(enemy, "pwr", -1, enemy.ball_uuid, C.ACTION_DEBUFF)

		result.add_event(CombatEvent.new(CombatEvent.Type.DEBUFF, {
			"source_uuid": enemy.ball_uuid,
			"target_uuids": [enemy.ball_uuid],
			"ability_id": ability_id,
			"action_type": C.ACTION_DEBUFF,
			"visual_payload": CombatPayload.pwr_debuff(enemy.ball_uuid, -1, [enemy_old_pwr], [enemy_new_pwr])
		}))

		result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
			"source_uuid": enemy.ball_uuid,
			"target_uuids": [unit.ball_uuid],
			"ability_id": ability_id,
			"action_type": C.ACTION_BUFF,
			"visual_payload": CombatPayload.pwr_buff(enemy.ball_uuid, 1, [unit_old_pwr], [unit_new_pwr])
		}))
		result.state_applied = true

	return result
