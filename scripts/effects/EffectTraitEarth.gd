# res://scripts/effects/EffectTraitEarth.gd
@tool
extends EffectDefinition

## Start-of-Combat Earth trait effect granted by Earth Trait Trinket.
## Triggered on_pre_combat when the battle button is pressed.
## Thresholds (Souls):
##   L1 (3 Souls): Frontmost Earth unit gains 1 Armor.
##   L2 (6 Souls): Frontmost Earth unit gains 1 Armor and 1 Spikes.
##   L3 (12 Souls): All Earth units gain 2 Armor and 2 Spikes.
##   L4 (20 Souls): All Earth units gain 3 Armor and 3 Spikes; all non-Earth allies gain 1 Armor and 1 Spikes.

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
	var earth_souls: int = int(active_traits.get("EARTH", 0))
	if earth_souls < 3:
		return EffectResult.empty()

	var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var units = battle_manager.get_instances_in_container(container_tag)
	if units.is_empty():
		return EffectResult.empty()

	var frontmost_earth: GachaBallInstance = battle_manager.get_frontmost_unit_on_team(is_player, "EARTH")

	var armor_target_uuids: Array[String] = []
	var armor_old_vals: Array[int] = []
	var armor_new_vals: Array[int] = []

	var spikes_target_uuids: Array[String] = []
	var spikes_old_vals: Array[int] = []
	var spikes_new_vals: Array[int] = []

	for unit in units:
		if not is_instance_valid(unit) or unit.current_hp <= 0:
			continue
		var is_earth = battle_manager.has_trait(unit, "EARTH")
		var armor_to_apply := 0
		var spikes_to_apply := 0

		if earth_souls >= 20:
			# L4: All Earth get 3A + 3S; non-Earth get 1A + 1S
			if is_earth:
				armor_to_apply = 3
				spikes_to_apply = 3
			else:
				armor_to_apply = 1
				spikes_to_apply = 1
		elif earth_souls >= 12:
			# L3: All Earth get 2A + 2S
			if is_earth:
				armor_to_apply = 2
				spikes_to_apply = 2
		elif earth_souls >= 6:
			# L2: Frontmost Earth gets 1A + 1S
			if unit == frontmost_earth:
				armor_to_apply = 1
				spikes_to_apply = 1
		elif earth_souls >= 3:
			# L1: Frontmost Earth gets 1A
			if unit == frontmost_earth:
				armor_to_apply = 1

		if armor_to_apply > 0:
			var old_armor = unit.get_status_effect_amount(&"armor")
			var new_armor = battle_manager.apply_stat_delta(unit, "armor_stacks", armor_to_apply)
			armor_target_uuids.append(unit.ball_uuid)
			armor_old_vals.append(old_armor)
			armor_new_vals.append(new_armor)

		if spikes_to_apply > 0:
			var old_spikes = unit.get_status_effect_amount(&"spikes")
			var new_spikes = battle_manager.apply_stat_delta(unit, "spikes_stacks", spikes_to_apply)
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
			"visual_payload": CombatPayload.status_change(source_uuid, 0, "armor_stacks", armor_old_vals, armor_new_vals)
		}))

	if not spikes_target_uuids.is_empty():
		result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
			"source_uuid": source_uuid,
			"target_uuids": spikes_target_uuids,
			"ability_id": ability_id,
			"visual_payload": CombatPayload.status_change(source_uuid, 0, "spikes_stacks", spikes_old_vals, spikes_new_vals)
		}))

	result.state_applied = true
	return result
