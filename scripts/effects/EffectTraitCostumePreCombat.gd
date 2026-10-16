# res://scripts/effects/EffectTraitCostumePreCombat.gd
@tool
extends EffectDefinition

## Start-of-Combat Costume trait effect granted by Costume Trait Trinket.
## Triggered on_pre_combat.
## Thresholds (Units):
##   L1 (2 Units): Each Costume steals 1 stack of mirror enemy's highest status (armor/spikes),
##                 or 1 point of highest stat (hp/pwr).
##   L2 (3 Units): Each Costume steals entire highest status (armor/spikes) from mirror enemy,
##                 or 1 HP and 1 PWR.
##   L3 (4 Units): Each Costume steals all Armor and all Spikes from mirror enemy,
##                 or 2 HP and 2 PWR.
##   L4 (5 Units): Executed ONCE per team: Steals all Armor, all Spikes, +3 HP and +3 PWR
##                 from the enemy with highest total armor+spikes to the Hero unit.

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
	var costume_units: int = int(active_traits.get("COSTUME", 0))
	if costume_units < 2:
		return EffectResult.empty()

	var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var units = battle_manager.get_instances_in_container(container_tag)
	if units.is_empty():
		return EffectResult.empty()

	var opp_tag = C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if is_player else C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	var opp_container = battle_manager._state.get_container(opp_tag)
	if not is_instance_valid(opp_container):
		return EffectResult.empty()

	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"ability_trait_costume")

	# L1-L3: Per Costume unit mirror theft
	if costume_units >= 2 and costume_units <= 4:
		for unit in units:
			if not is_instance_valid(unit) or unit.current_hp <= 0:
				continue
			if not battle_manager.has_trait(unit, "COSTUME"):
				continue

			var mirror_index = 4 - unit.location_slot_index
			if mirror_index < 0 or mirror_index >= opp_container.get_size():
				continue

			var mirror_uuid = opp_container.get_uuid(mirror_index)
			if mirror_uuid.is_empty():
				continue

			var mirror_enemy = battle_manager.get_instance_by_uuid(mirror_uuid)
			if not is_instance_valid(mirror_enemy) or mirror_enemy.current_hp <= 0:
				continue

			var m_armor = mirror_enemy.get_status_effect_amount(&"armor")
			var m_spikes = mirror_enemy.get_status_effect_amount(&"spikes")

			if costume_units == 2:
				# L1 (2 Units): Steal 1 stack of highest status or 1 point of highest stat
				if m_armor > 0 or m_spikes > 0:
					if m_armor >= m_spikes:
						_steal_status(battle_manager, result, mirror_enemy, unit, "armor_stacks", 1, ability_id)
					else:
						_steal_status(battle_manager, result, mirror_enemy, unit, "spikes_stacks", 1, ability_id)
				else:
					var steal_hp := false
					if mirror_enemy.current_hp > mirror_enemy.current_pwr:
						steal_hp = true
					elif mirror_enemy.current_hp < mirror_enemy.current_pwr:
						steal_hp = false
					else:
						steal_hp = (RNGManager.combat_rng.randi_range(0, 1) == 0)

					if steal_hp:
						_steal_hp(battle_manager, result, mirror_enemy, unit, 1, ability_id)
					else:
						_steal_pwr(battle_manager, result, mirror_enemy, unit, 1, ability_id)

			elif costume_units == 3:
				# L2 (3 Units): Steal entire highest status or 1 HP + 1 PWR
				if m_armor > 0 or m_spikes > 0:
					if m_armor >= m_spikes:
						_steal_status(battle_manager, result, mirror_enemy, unit, "armor_stacks", m_armor, ability_id)
					else:
						_steal_status(battle_manager, result, mirror_enemy, unit, "spikes_stacks", m_spikes, ability_id)
				else:
					_steal_hp(battle_manager, result, mirror_enemy, unit, 1, ability_id)
					_steal_pwr(battle_manager, result, mirror_enemy, unit, 1, ability_id)

			elif costume_units == 4:
				# L3 (4 Units): Steal all Armor and all Spikes or 2 HP + 2 PWR
				if m_armor > 0 or m_spikes > 0:
					if m_armor > 0:
						_steal_status(battle_manager, result, mirror_enemy, unit, "armor_stacks", m_armor, ability_id)
					if m_spikes > 0:
						_steal_status(battle_manager, result, mirror_enemy, unit, "spikes_stacks", m_spikes, ability_id)
				else:
					_steal_hp(battle_manager, result, mirror_enemy, unit, 2, ability_id)
					_steal_pwr(battle_manager, result, mirror_enemy, unit, 2, ability_id)

	# L4 (5 Units): Executed ONCE per team. Steals from enemy with highest total armor+spikes to Hero
	elif costume_units >= 5:
		var hero = battle_manager.get_hero_on_team(is_player)
		if is_instance_valid(hero) and hero.current_hp > 0:
			var opp_units = battle_manager.get_instances_in_container(opp_tag).filter(func(e):
				return is_instance_valid(e) and e.current_hp > 0
			)
			if not opp_units.is_empty():
				opp_units.sort_custom(func(a, b):
					var tot_a = a.get_status_effect_amount(&"armor") + a.get_status_effect_amount(&"spikes")
					var tot_b = b.get_status_effect_amount(&"armor") + b.get_status_effect_amount(&"spikes")
					if tot_a != tot_b:
						return tot_a > tot_b
					if is_player:
						return a.location_slot_index < b.location_slot_index
					else:
						return a.location_slot_index > b.location_slot_index
				)
				var best_target = opp_units[0]
				var t_armor = best_target.get_status_effect_amount(&"armor")
				var t_spikes = best_target.get_status_effect_amount(&"spikes")

				if t_armor > 0:
					_steal_status(battle_manager, result, best_target, hero, "armor_stacks", t_armor, ability_id)
				if t_spikes > 0:
					_steal_status(battle_manager, result, best_target, hero, "spikes_stacks", t_spikes, ability_id)

				_steal_hp(battle_manager, result, best_target, hero, 3, ability_id)
				_steal_pwr(battle_manager, result, best_target, hero, 3, ability_id)

	result.state_applied = true
	return result

func _steal_status(bm: Node, res: EffectResult, victim: GachaBallInstance, thief: GachaBallInstance, stat_name: String, amount: int, ability_id: StringName) -> void:
	if amount <= 0:
		return
	var v_old = victim.get_status_effect_amount(StringName(stat_name.trim_suffix("_stacks")))
	var v_new = bm.apply_stat_delta(victim, stat_name, -amount, thief.ball_uuid)
	var stolen = v_old - v_new
	if stolen <= 0:
		return
	res.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
		"source_uuid": thief.ball_uuid,
		"target_uuids": [victim.ball_uuid],
		"ability_id": ability_id,
		"visual_payload": CombatPayload.status_change(thief.ball_uuid, -stolen, stat_name, [v_old], [v_new])
	}))

	var t_old = thief.get_status_effect_amount(StringName(stat_name.trim_suffix("_stacks")))
	var t_new = bm.apply_stat_delta(thief, stat_name, stolen, victim.ball_uuid)
	res.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
		"source_uuid": victim.ball_uuid,
		"target_uuids": [thief.ball_uuid],
		"ability_id": ability_id,
		"visual_payload": CombatPayload.status_change(victim.ball_uuid, stolen, stat_name, [t_old], [t_new])
	}))

func _steal_hp(bm: Node, res: EffectResult, victim: GachaBallInstance, thief: GachaBallInstance, amount: int, ability_id: StringName) -> void:
	if amount <= 0:
		return
	var v_old_h = victim.current_hp
	var v_new_h = bm.apply_stat_delta(victim, "hp", -amount, thief.ball_uuid, C.ACTION_DEBUFF)
	var stolen = v_old_h - v_new_h
	if stolen <= 0:
		return
	var v_def = victim.get_definition()
	var v_max_h = v_def.base_hp if is_instance_valid(v_def) else 0
	res.add_event(CombatEvent.new(CombatEvent.Type.DEBUFF, {
		"source_uuid": thief.ball_uuid,
		"target_uuids": [victim.ball_uuid],
		"ability_id": ability_id,
		"action_type": C.ACTION_DEBUFF,
		"visual_payload": CombatPayload.hp_change(thief.ball_uuid, -stolen, [v_old_h], [v_new_h], [v_max_h])
	}))

	var t_old_h = thief.current_hp
	var t_new_h = bm.apply_stat_delta(thief, "hp", stolen, victim.ball_uuid, C.ACTION_BUFF)
	var t_def = thief.get_definition()
	var t_max_h = t_def.base_hp if is_instance_valid(t_def) else 0
	res.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
		"source_uuid": victim.ball_uuid,
		"target_uuids": [thief.ball_uuid],
		"ability_id": ability_id,
		"action_type": C.ACTION_BUFF,
		"visual_payload": CombatPayload.hp_change(victim.ball_uuid, stolen, [t_old_h], [t_new_h], [t_max_h])
	}))

func _steal_pwr(bm: Node, res: EffectResult, victim: GachaBallInstance, thief: GachaBallInstance, amount: int, ability_id: StringName) -> void:
	if amount <= 0:
		return
	var v_old_p = victim.current_pwr
	var v_new_p = bm.apply_stat_delta(victim, "pwr", -amount, thief.ball_uuid, C.ACTION_DEBUFF)
	var stolen = v_old_p - v_new_p
	if stolen <= 0:
		return
	res.add_event(CombatEvent.new(CombatEvent.Type.DEBUFF, {
		"source_uuid": thief.ball_uuid,
		"target_uuids": [victim.ball_uuid],
		"ability_id": ability_id,
		"action_type": C.ACTION_DEBUFF,
		"visual_payload": CombatPayload.pwr_change(thief.ball_uuid, -stolen, [v_old_p], [v_new_p])
	}))

	var t_old_p = thief.current_pwr
	var t_new_p = bm.apply_stat_delta(thief, "pwr", stolen, victim.ball_uuid, C.ACTION_BUFF)
	res.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
		"source_uuid": victim.ball_uuid,
		"target_uuids": [thief.ball_uuid],
		"ability_id": ability_id,
		"action_type": C.ACTION_BUFF,
		"visual_payload": CombatPayload.pwr_change(victim.ball_uuid, stolen, [t_old_p], [t_new_p])
	}))
