# res://scripts/effects/EffectTraitTankPreCombat.gd
@tool
extends EffectDefinition

## Start-of-Combat Tank trait effect granted by Tank Trait Trinket.
## Triggered on_pre_combat.
## Thresholds (Units):
##   L1 (2 Units): Frontmost Tank gains 1 Armor.
##   L2 (3 Units): All Tanks gain 1 Armor.

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
	if tank_units < 2:
		return EffectResult.empty()

	var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var units = battle_manager.get_instances_in_container(container_tag)
	if units.is_empty():
		return EffectResult.empty()

	var frontmost_tank = battle_manager.get_frontmost_unit_on_team(is_player, "TANK")

	var target_uuids: Array[String] = []
	var old_vals: Array[int] = []
	var new_vals: Array[int] = []

	for unit in units:
		if not is_instance_valid(unit) or unit.current_hp <= 0:
			continue
		if not battle_manager.has_trait(unit, "TANK"):
			continue

		var should_buff := false
		if tank_units >= 3:
			# L2: All Tanks gain 1 Armor
			should_buff = true
		elif tank_units >= 2:
			# L1: Frontmost Tank gains 1 Armor
			should_buff = (unit == frontmost_tank)

		if should_buff:
			var old_armor = unit.get_status_effect_amount(&"armor")
			var new_armor = battle_manager.apply_stat_delta(unit, "armor_stacks", 1)
			target_uuids.append(unit.ball_uuid)
			old_vals.append(old_armor)
			new_vals.append(new_armor)

	if target_uuids.is_empty():
		return EffectResult.empty()

	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"ability_trait_tank")

	result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
		"source_uuid": source_uuid,
		"target_uuids": target_uuids,
		"ability_id": ability_id,
		"visual_payload": CombatPayload.status_change(source_uuid, 1, "armor_stacks", old_vals, new_vals)
	}))

	result.state_applied = true
	return result
