# res://scripts/effects/EffectTraitAir.gd
@tool
extends EffectDefinition

## Start-of-Combat Air trait effect granted by Air Trait Trinket.
## Triggered on_pre_combat when the battle button is pressed.
## Thresholds (Souls):
##   L4 (20 Souls): Inflicts 1 Static stack to all enemy units.

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
	if air_souls < 20:
		return EffectResult.empty()

	# Target enemy lineup
	var enemy_container_tag = C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if team == "PLAYER" else C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	var enemy_units = battle_manager.get_instances_in_container(enemy_container_tag)
	if enemy_units.is_empty():
		return EffectResult.empty()

	var target_uuids: Array[String] = []
	var old_static_vals: Array[int] = []
	var new_static_vals: Array[int] = []

	for enemy in enemy_units:
		if not is_instance_valid(enemy) or enemy.current_hp <= 0:
			continue
		var old_static = enemy.get_status_effect_amount(&"static")
		var new_static = battle_manager.apply_stat_delta(enemy, "static_stacks", 1)
		target_uuids.append(enemy.ball_uuid)
		old_static_vals.append(old_static)
		new_static_vals.append(new_static)

	if target_uuids.is_empty():
		return EffectResult.empty()

	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"ability_trait_air")

	result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
		"source_uuid": source_uuid,
		"target_uuids": target_uuids,
		"ability_id": ability_id,
		"visual_payload": CombatPayload.status_change(source_uuid, 1, "static_stacks", old_static_vals, new_static_vals)
	}))

	result.state_applied = true
	return result
