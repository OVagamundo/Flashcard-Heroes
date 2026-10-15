# res://scripts/effects/EffectTraitEarth.gd
@tool
extends EffectDefinition

## Start-of-Combat Earth trait effect granted by Earth Trait Trinket.
## Triggered on_pre_combat when the battle button is pressed.
## Thresholds (Souls):
##   3+ Souls: 1 Armor
##   5+ Souls: 2 Armor
##   7+ Souls: 2 Armor, 1 Spikes
##   9+ Souls: 2 Armor, 2 Spikes
## Earth units gain double armor bonus.

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
	var earth_souls: int = int(active_traits.get("EARTH", 0))
	if earth_souls < 3:
		return EffectResult.empty()

	var armor_value := 0
	var spikes_value := 0

	if earth_souls >= 9:
		armor_value = 2
		spikes_value = 2
	elif earth_souls >= 7:
		armor_value = 2
		spikes_value = 1
	elif earth_souls >= 5:
		armor_value = 2
		spikes_value = 0
	elif earth_souls >= 3:
		armor_value = 1
		spikes_value = 0

	var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if team == "PLAYER" else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var units = battle_manager.get_instances_in_container(container_tag)

	var armor_target_uuids: Array[String] = []
	var armor_old_vals: Array[int] = []
	var armor_new_vals: Array[int] = []

	var spikes_target_uuids: Array[String] = []
	var spikes_old_vals: Array[int] = []
	var spikes_new_vals: Array[int] = []

	for unit in units:
		if not is_instance_valid(unit) or unit.current_hp <= 0:
			continue
		var is_earth = battle_manager._has_trait_soul(unit, "EARTH")
		var armor_to_apply = armor_value * 2 if is_earth else armor_value

		if armor_to_apply > 0:
			var old_armor = unit.get_status_effect_amount(&"armor")
			var new_armor = battle_manager.apply_stat_delta(unit, "armor_stacks", armor_to_apply)
			armor_target_uuids.append(unit.ball_uuid)
			armor_old_vals.append(old_armor)
			armor_new_vals.append(new_armor)

		if spikes_value > 0:
			var old_spikes = unit.get_status_effect_amount(&"spikes")
			var new_spikes = battle_manager.apply_stat_delta(unit, "spikes_stacks", spikes_value)
			spikes_target_uuids.append(unit.ball_uuid)
			spikes_old_vals.append(old_spikes)
			spikes_new_vals.append(new_spikes)

	if armor_target_uuids.is_empty() and spikes_target_uuids.is_empty():
		return EffectResult.empty()

	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"ability_trait_earth")

	if not armor_target_uuids.is_empty():
		result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
			"source_uuid": source_uuid,
			"target_uuids": armor_target_uuids,
			"ability_id": ability_id,
			"visual_payload": CombatPayload.status_change("", armor_value, "armor_stacks", armor_old_vals, armor_new_vals)
		}))

	if not spikes_target_uuids.is_empty():
		result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
			"source_uuid": source_uuid,
			"target_uuids": spikes_target_uuids,
			"ability_id": ability_id,
			"visual_payload": CombatPayload.status_change("", spikes_value, "spikes_stacks", spikes_old_vals, spikes_new_vals)
		}))

	result.state_applied = true
	return result
