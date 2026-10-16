# res://scripts/effects/EffectTraitSupportTurnStart.gd
@tool
extends EffectDefinition

## Turn-Start Support trait effect granted by Support Trait Trinket.
## Triggered on_turn_start.
## Thresholds (Units):
##   L3 (4 Units): Each living Support unit deployed in the lineup grants +1 HP
##                 to lowest-HP ally and +1 PWR to lowest-PWR ally (tie-breaker: frontmost).

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
	var support_units: int = int(active_traits.get("SUPPORT", 0))
	if support_units < 4:
		return EffectResult.empty()

	var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var units = battle_manager.get_instances_in_container(container_tag)
	var living_allies: Array[GachaBallInstance] = []
	var living_supports: Array[GachaBallInstance] = []

	for u in units:
		if is_instance_valid(u) and u.current_hp > 0:
			living_allies.append(u)
			if battle_manager.has_trait(u, "SUPPORT"):
				living_supports.append(u)

	if living_supports.is_empty() or living_allies.is_empty():
		return EffectResult.empty()

	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"ability_trait_support_turn_start")

	# For each living Support unit, grant +1 HP to lowest-HP ally and +1 PWR to lowest-PWR ally
	for support_unit in living_supports:
		# Lowest HP ally
		living_allies.sort_custom(func(a, b):
			if a.current_hp != b.current_hp:
				return a.current_hp < b.current_hp
			if is_player:
				return a.location_slot_index > b.location_slot_index
			else:
				return a.location_slot_index < b.location_slot_index
		)
		var lowest_hp_target = living_allies[0]
		var old_hp = lowest_hp_target.current_hp
		var new_hp = battle_manager.apply_stat_delta(lowest_hp_target, "hp", 1, support_unit.ball_uuid, C.ACTION_BUFF)
		var t_def = lowest_hp_target.get_definition()
		var max_hp = t_def.base_hp if is_instance_valid(t_def) else 0

		result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
			"source_uuid": support_unit.ball_uuid,
			"target_uuids": [lowest_hp_target.ball_uuid],
			"ability_id": ability_id,
			"action_type": C.ACTION_BUFF,
			"visual_payload": CombatPayload.hp_change(support_unit.ball_uuid, 1, [old_hp], [new_hp], [max_hp])
		}))

		# Lowest PWR ally
		living_allies.sort_custom(func(a, b):
			if a.current_pwr != b.current_pwr:
				return a.current_pwr < b.current_pwr
			if is_player:
				return a.location_slot_index > b.location_slot_index
			else:
				return a.location_slot_index < b.location_slot_index
		)
		var lowest_pwr_target = living_allies[0]
		var old_pwr = lowest_pwr_target.current_pwr
		var new_pwr = battle_manager.apply_stat_delta(lowest_pwr_target, "pwr", 1, support_unit.ball_uuid, C.ACTION_BUFF)

		result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
			"source_uuid": support_unit.ball_uuid,
			"target_uuids": [lowest_pwr_target.ball_uuid],
			"ability_id": ability_id,
			"action_type": C.ACTION_BUFF,
			"visual_payload": CombatPayload.pwr_change(support_unit.ball_uuid, 1, [old_pwr], [new_pwr])
		}))

	result.state_applied = true
	return result
