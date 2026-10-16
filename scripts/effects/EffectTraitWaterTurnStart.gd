# res://scripts/effects/EffectTraitWaterTurnStart.gd
@tool
extends EffectDefinition

## Turn-Start Water trait effect granted by Water Trait Trinket.
## Triggered on_turn_start.
## Thresholds (Souls):
##   L3 (12 Souls): Heals ally with lowest current HP by 1 HP (tie-breaker: frontmost).
##   L5 (32 Souls): All allies consume all Burn and Static stacks, healing 1 HP per stack consumed.

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
	var water_souls: int = int(active_traits.get("WATER", 0))
	if water_souls < 12:
		return EffectResult.empty()

	var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var units = battle_manager.get_instances_in_container(container_tag)
	var living_allies: Array[GachaBallInstance] = []
	for u in units:
		if is_instance_valid(u) and u.current_hp > 0:
			living_allies.append(u)

	if living_allies.is_empty():
		return EffectResult.empty()

	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"ability_trait_water_turn_start")

	# L3 (12 Souls): Heal lowest-HP ally by 1 HP (tie-breaker: frontmost)
	living_allies.sort_custom(func(a, b):
		if a.current_hp != b.current_hp:
			return a.current_hp < b.current_hp
		# Tie-breaker: frontmost (higher slot for player, lower slot for enemy)
		if is_player:
			return a.location_slot_index > b.location_slot_index
		else:
			return a.location_slot_index < b.location_slot_index
	)
	var lowest_ally = living_allies[0]
	var old_hp = lowest_ally.current_hp
	var new_hp = battle_manager.apply_stat_delta(lowest_ally, "hp", 1, source_uuid, C.ACTION_HEAL)
	var lowest_def = lowest_ally.get_definition()
	var max_hp = lowest_def.base_hp if is_instance_valid(lowest_def) else 0

	result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
		"source_uuid": source_uuid,
		"target_uuids": [lowest_ally.ball_uuid],
		"ability_id": ability_id,
		"action_type": C.ACTION_HEAL,
		"visual_payload": CombatPayload.heal(source_uuid, 1, [old_hp], [new_hp], [max_hp])
	}))

	# L5 (32 Souls): All allies consume all Burn and Static stacks, healing 1 HP per stack consumed
	if water_souls >= 32:
		for ally in living_allies:
			var burn_st = ally.get_status_effect_amount(&"burn")
			var static_st = ally.get_status_effect_amount(&"static")
			var total_stacks = burn_st + static_st
			if total_stacks > 0:
				ally.clear_status_effect(&"burn")
				ally.clear_status_effect(&"static")
				var ally_old_hp = ally.current_hp
				var ally_new_hp = battle_manager.apply_stat_delta(ally, "hp", total_stacks, source_uuid, C.ACTION_HEAL)
				var a_def = ally.get_definition()
				var a_max_hp = a_def.base_hp if is_instance_valid(a_def) else 0

				result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
					"source_uuid": source_uuid,
					"target_uuids": [ally.ball_uuid],
					"ability_id": ability_id,
					"visual_payload": CombatPayload.status_change(source_uuid, -burn_st, "burn_stacks", [burn_st], [0])
				}))
				result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
					"source_uuid": source_uuid,
					"target_uuids": [ally.ball_uuid],
					"ability_id": ability_id,
					"visual_payload": CombatPayload.status_change(source_uuid, -static_st, "static_stacks", [static_st], [0])
				}))
				result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
					"source_uuid": source_uuid,
					"target_uuids": [ally.ball_uuid],
					"ability_id": ability_id,
					"action_type": C.ACTION_HEAL,
					"visual_payload": CombatPayload.heal(source_uuid, total_stacks, [ally_old_hp], [ally_new_hp], [a_max_hp])
				}))

	result.state_applied = true
	return result
