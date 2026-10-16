# res://scripts/effects/EffectTraitWater.gd
@tool
extends EffectDefinition

## Start-of-Combat Water trait effect granted by Water Trait Trinket.
## Triggered on_pre_combat when the battle button is pressed.
## Thresholds (Souls):
##   L1 (3 Souls): Each Water unit heals the ally directly ahead by 1 HP.
##   L2 (6 Souls): The pre-combat heal also cleanses 1 stack of negative status (Burn/Static) from that ally.
##   L4 (20 Souls): All allies cleanse 1 stack of negative status effects.

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
	if water_souls < 3:
		return EffectResult.empty()

	var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if team == "PLAYER" else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var units = battle_manager.get_instances_in_container(container_tag)
	if units.is_empty():
		return EffectResult.empty()

	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"ability_trait_water")

	# L1 & L2: Each Water unit heals ally ahead (+ cleanse at L2)
	for unit in units:
		if not is_instance_valid(unit) or unit.current_hp <= 0:
			continue
		if not battle_manager.has_trait(unit, "WATER"):
			continue

		var ally_ahead = battle_manager._get_slot_ahead(unit)
		if not is_instance_valid(ally_ahead) or ally_ahead.current_hp <= 0:
			continue

		# L1 Heal
		var old_hp = ally_ahead.current_hp
		var new_hp = battle_manager.apply_stat_delta(ally_ahead, "hp", 1, unit.ball_uuid, C.ACTION_HEAL)
		var ally_def = ally_ahead.get_definition()
		var max_hp = ally_def.base_hp if is_instance_valid(ally_def) else 0

		result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
			"source_uuid": unit.ball_uuid,
			"target_uuids": [ally_ahead.ball_uuid],
			"ability_id": ability_id,
			"action_type": C.ACTION_HEAL,
			"visual_payload": CombatPayload.heal(unit.ball_uuid, 1, [old_hp], [new_hp], [max_hp])
		}))

		# L2 Cleanse (Burn or Static)
		if water_souls >= 6:
			var old_burn = ally_ahead.get_status_effect_amount(&"burn")
			var old_static = ally_ahead.get_status_effect_amount(&"static")
			if old_burn > 0:
				var new_burn = battle_manager.apply_stat_delta(ally_ahead, "burn_stacks", -1)
				result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
					"source_uuid": unit.ball_uuid,
					"target_uuids": [ally_ahead.ball_uuid],
					"ability_id": ability_id,
					"visual_payload": CombatPayload.status_change(unit.ball_uuid, -1, "burn_stacks", [old_burn], [new_burn])
				}))
			elif old_static > 0:
				var new_static = battle_manager.apply_stat_delta(ally_ahead, "static_stacks", -1)
				result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
					"source_uuid": unit.ball_uuid,
					"target_uuids": [ally_ahead.ball_uuid],
					"ability_id": ability_id,
					"visual_payload": CombatPayload.status_change(unit.ball_uuid, -1, "static_stacks", [old_static], [new_static])
				}))

	# L4 Cleanse All Allies
	if water_souls >= 20:
		for ally in units:
			if not is_instance_valid(ally) or ally.current_hp <= 0:
				continue
			var old_burn = ally.get_status_effect_amount(&"burn")
			var old_static = ally.get_status_effect_amount(&"static")
			if old_burn > 0:
				var new_burn = battle_manager.apply_stat_delta(ally, "burn_stacks", -1)
				result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
					"source_uuid": source_uuid,
					"target_uuids": [ally.ball_uuid],
					"ability_id": ability_id,
					"visual_payload": CombatPayload.status_change(source_uuid, -1, "burn_stacks", [old_burn], [new_burn])
				}))
			elif old_static > 0:
				var new_static = battle_manager.apply_stat_delta(ally, "static_stacks", -1)
				result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
					"source_uuid": source_uuid,
					"target_uuids": [ally.ball_uuid],
					"ability_id": ability_id,
					"visual_payload": CombatPayload.status_change(source_uuid, -1, "static_stacks", [old_static], [new_static])
				}))

	result.state_applied = true
	return result
