# res://scripts/effects/EffectTraitSupportPreCombat.gd
@tool
extends EffectDefinition

## Start-of-Combat Support trait effect granted by Support Trait Trinket.
## Triggered on_pre_combat.
## Thresholds (Units):
##   L1 (2 Units): Support units grant +1 HP to the ally directly in front.
##   L2 (3 Units): Support units also grant +1 PWR to the ally directly behind.
##   L4 (5 Units): Grants +1 HP and +1 PWR to the Hero unit (stacks with positional buffs).

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
	if support_units < 2:
		return EffectResult.empty()

	var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var units = battle_manager.get_instances_in_container(container_tag)
	if units.is_empty():
		return EffectResult.empty()

	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"ability_trait_support")

	# Iterate backwards (or by slot) for consistent deterministic ordering
	for unit in units:
		if not is_instance_valid(unit) or unit.current_hp <= 0:
			continue
		if not battle_manager.has_trait(unit, "SUPPORT"):
			continue

		# L1 (2 Units): +1 HP to ally directly in front
		var ally_ahead = battle_manager._get_slot_ahead(unit)
		if is_instance_valid(ally_ahead) and ally_ahead.current_hp > 0:
			var old_hp = ally_ahead.current_hp
			var new_hp = battle_manager.apply_stat_delta(ally_ahead, "hp", 1, unit.ball_uuid, C.ACTION_BUFF)
			var a_def = ally_ahead.get_definition()
			var a_max_hp = a_def.base_hp if is_instance_valid(a_def) else 0
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": unit.ball_uuid,
				"target_uuids": [ally_ahead.ball_uuid],
				"ability_id": ability_id,
				"action_type": C.ACTION_BUFF,
				"visual_payload": CombatPayload.hp_change(unit.ball_uuid, 1, [old_hp], [new_hp], [a_max_hp])
			}))

		# L2 (3 Units): +1 PWR to ally directly behind
		if support_units >= 3:
			var ally_behind = battle_manager._get_ally_behind(unit)
			if is_instance_valid(ally_behind) and ally_behind.current_hp > 0:
				var old_pwr = ally_behind.current_pwr
				var new_pwr = battle_manager.apply_stat_delta(ally_behind, "pwr", 1, unit.ball_uuid, C.ACTION_BUFF)
				result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
					"source_uuid": unit.ball_uuid,
					"target_uuids": [ally_behind.ball_uuid],
					"ability_id": ability_id,
					"action_type": C.ACTION_BUFF,
					"visual_payload": CombatPayload.pwr_change(unit.ball_uuid, 1, [old_pwr], [new_pwr])
				}))

	# L4 (5 Units): +1 HP and +1 PWR to Hero unit (stacks cumulatively with positional buffs)
	if support_units >= 5:
		var hero = battle_manager.get_hero_on_team(is_player)
		if is_instance_valid(hero) and hero.current_hp > 0:
			var hero_old_hp = hero.current_hp
			var hero_new_hp = battle_manager.apply_stat_delta(hero, "hp", 1, source_uuid, C.ACTION_BUFF)
			var hero_old_pwr = hero.current_pwr
			var hero_new_pwr = battle_manager.apply_stat_delta(hero, "pwr", 1, source_uuid, C.ACTION_BUFF)
			var h_def = hero.get_definition()
			var h_max_hp = h_def.base_hp if is_instance_valid(h_def) else 0
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": source_uuid,
				"target_uuids": [hero.ball_uuid],
				"ability_id": ability_id,
				"action_type": C.ACTION_BUFF,
				"visual_payload": CombatPayload.both_stats_change(source_uuid, 1, 1, [hero_old_hp], [hero_new_hp], [hero_old_pwr], [hero_new_pwr], [h_max_hp])
			}))

	result.state_applied = true
	return result
