# res://scripts/battle/TraitRulesEngine.gd
class_name TraitRulesEngine
extends RefCounted

## Centralized, data-threshold-driven trait rules engine.
## Reads all tier thresholds strictly from Constants.TRAIT_DEFINITIONS["levels"]
## (eliminating scattered magic integers across BattleManager, EffectHandlers,
## and BasicAttackEffect). Pure simulation module (zero SceneTree/UI deps).

const C = preload("res://scripts/Constants.gd")


## Returns the 1-based active tier (0 if below tier 1) for `trait_name` at `count`,
## derived strictly from `Constants.TRAIT_DEFINITIONS[trait_name]["levels"]`.
static func get_tier(trait_name: String, count: int) -> int:
	var def: Dictionary = C.TRAIT_DEFINITIONS.get(trait_name, {})
	if def.is_empty():
		return 0
	var levels: Array = def.get("levels", [])
	var active_tier: int = 0
	for i: int in range(levels.size()):
		if count >= int((levels[i] as Dictionary).get("min", 999999)):
			active_tier = i + 1
	return active_tier


## Returns the 1-based active tier for `trait_name` from an `active_traits` dictionary (0 if inactive).
static func get_active_tier(active_traits: Dictionary, trait_name: String) -> int:
	return get_tier(trait_name, int(active_traits.get(trait_name, 0)))


## Returns true if `active_traits[trait_name]` has reached at least 1-based `required_tier`.
static func has_tier(active_traits: Dictionary, trait_name: String, required_tier: int) -> bool:
	return get_active_tier(active_traits, trait_name) >= required_tier


## Returns the minimum count required to unlock 1-based `tier` for `trait_name`.
static func get_tier_min(trait_name: String, tier: int) -> int:
	var def: Dictionary = C.TRAIT_DEFINITIONS.get(trait_name, {})
	var levels: Array = def.get("levels", [])
	assert(tier >= 1 and tier <= levels.size(), "TraitRulesEngine.get_tier_min: invalid tier %d for %s" % [tier, trait_name])
	return int((levels[tier - 1] as Dictionary).get("min", 0))


static func has_trait_soul(unit: GachaBallInstance, trait_name: String, all_instances: Dictionary) -> bool:
	if not is_instance_valid(unit):
		return false
	var target_tag := StringName("SOUL_" + trait_name.to_upper())
	return unit.get_active_tags(all_instances).has(target_tag)


static func has_trait(unit: GachaBallInstance, trait_name: String, all_instances: Dictionary) -> bool:
	if not is_instance_valid(unit):
		return false
	var upper_trait: String = trait_name.to_upper()
	if upper_trait in ["FIRE", "EARTH", "WATER", "AIR"]:
		return has_trait_soul(unit, upper_trait, all_instances)
	for tag: StringName in unit.get_active_tags(all_instances):
		if String(tag).to_upper() == upper_trait:
			return true
	return false


static func calculate_active_traits(team: String, bm: Node) -> Dictionary:
	var counts: Dictionary = {}
	for trait_name: String in C.TRAIT_SORT_ORDER:
		counts[trait_name] = 0

	var container_tag: StringName = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if team == "PLAYER" else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var units: Array = bm.get_instances_in_container(container_tag)
	var all_inst: Dictionary = bm.get_all_instances()

	for unit: GachaBallInstance in units:
		if not is_instance_valid(unit) or unit.current_hp <= 0:
			continue
		var soul_counts: Dictionary = unit.get_trait_soul_counts(all_inst)
		for soul_type: String in ["FIRE", "EARTH", "WATER", "AIR"]:
			if counts.has(soul_type):
				counts[soul_type] = int(counts[soul_type]) + int(soul_counts.get(soul_type, 0))
		for tag: StringName in unit.get_active_tags(all_inst):
			var upper: String = String(tag).to_upper()
			if counts.has(upper):
				counts[upper] = int(counts[upper]) + 1

	for trait_name: String in C.TRAIT_SORT_ORDER:
		if not bm._team_has_trait_trinket(team, trait_name):
			counts[trait_name] = 0

	return counts


## Bonus Burn stacks applied on attacks (Burn Vial + Fire L1/L2 + Appliance L2).
static func get_bonus_burn_stacks_for_attack(source: GachaBallInstance, target: GachaBallInstance, bm: Node) -> int:
	if not is_instance_valid(source):
		return 0
	var is_player: bool = bm._is_player_unit(source)
	var all_inst: Dictionary = bm.get_all_instances()
	var burn: int = 0

	if bm._has_team_trinket(is_player, &"trinket_burn_vial"):
		burn += 1

	var active_traits: Dictionary = bm.get_active_traits("PLAYER" if is_player else "ENEMY")
	if has_tier(active_traits, "FIRE", 1) and has_trait_soul(source, "FIRE", all_inst):
		burn += 1
		# Fire L2: +1 additional Burn only if target already holds Burn
		if has_tier(active_traits, "FIRE", 2) and is_instance_valid(target) and target.get_status_effect_amount(&"burn") > 0:
			burn += 1

	if has_tier(active_traits, "APPLIANCE", 2) and has_trait(source, "APPLIANCE", all_inst):
		burn += 1

	return burn


## Bonus Static stacks applied on basic attacks (Air L1/L2/L5 + Mecha L2 + Appliance L1).
static func get_bonus_static_stacks_for_attack(source: GachaBallInstance, bm: Node) -> int:
	if not is_instance_valid(source):
		return 0
	var is_player: bool = bm._is_player_unit(source)
	var all_inst: Dictionary = bm.get_all_instances()
	var active_traits: Dictionary = bm.get_active_traits("PLAYER" if is_player else "ENEMY")
	var static_amount: int = 0

	if has_trait(source, "AIR", all_inst):
		var air_tier: int = get_tier("AIR", int(active_traits.get("AIR", 0)))
		if air_tier >= 5:
			static_amount = maxi(1, source.current_pwr)
		elif air_tier >= 2:
			static_amount = 2
		elif air_tier >= 1:
			static_amount = 1

	if has_tier(active_traits, "MECHA", 2) and has_trait(source, "MECHA", all_inst):
		static_amount += 1

	if has_tier(active_traits, "APPLIANCE", 1) and has_trait(source, "APPLIANCE", all_inst):
		static_amount += 1

	return static_amount


## Fire L4 (and Burnie Combustion Strike) bonus damage equal to target's current Burn stacks.
static func get_fire_burn_bonus_damage(source: GachaBallInstance, target: GachaBallInstance, bm: Node, include_burnie: bool = false) -> int:
	if not is_instance_valid(source) or not is_instance_valid(target):
		return 0
	var burn_count: int = target.get_status_effect_amount(&"burn")
	if burn_count <= 0:
		return 0
	if include_burnie and source.definition_id == &"elite_burnie":
		return burn_count
	var is_player: bool = bm._is_player_unit(source)
	var active_traits: Dictionary = bm.get_active_traits("PLAYER" if is_player else "ENEMY")
	if has_tier(active_traits, "FIRE", 4) and has_trait_soul(source, "FIRE", bm.get_all_instances()):
		return burn_count
	return 0


## Mecha L3: on merge, each living allied Mecha fires 1 ranged damage + 1 Static at a random enemy.
static func apply_on_merge_traits(bm: Node, out_events: Array[CombatEvent]) -> void:
	var p_traits: Dictionary = bm.get_active_traits("PLAYER")
	if not has_tier(p_traits, "MECHA", 3):
		return
	var p_lineup: Array = bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var mechas: Array = p_lineup.filter(func(u: GachaBallInstance) -> bool:
		return is_instance_valid(u) and u.current_hp > 0 and bm.has_trait(u, "MECHA")
	)
	var opp_lineup: Array = bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).filter(func(e: GachaBallInstance) -> bool:
		return is_instance_valid(e) and e.current_hp > 0
	)
	if mechas.is_empty() or opp_lineup.is_empty():
		return

	for mecha: GachaBallInstance in mechas:
		var living_enemies: Array = opp_lineup.filter(func(e: GachaBallInstance) -> bool:
			return is_instance_valid(e) and e.current_hp > 0
		)
		if living_enemies.is_empty():
			break
		var target_enemy: GachaBallInstance = RNGManager.combat_rng.pick_random(living_enemies)
		var old_h: int = target_enemy.current_hp
		var old_a: int = target_enemy.get_status_effect_amount(&"armor")
		var dmg_res: Dictionary = bm.apply_damage(target_enemy, 1, C.DamageType.RANGED, mecha.ball_uuid)
		var new_h: int = int(dmg_res.get("new_hp", target_enemy.current_hp))
		var a_cons: int = int(dmg_res.get("armor_consumed", 0))
		var new_a: int = int(dmg_res.get("new_armor", old_a))
		var t_def: Resource = target_enemy.get_definition()
		var max_h: int = int(t_def.base_hp) if is_instance_valid(t_def) and "base_hp" in t_def else 0

		var p := CombatPayload.damage(mecha.ball_uuid, 1, [old_h], [new_h], [old_a], [new_a], [a_cons])
		p.attack_type = "ranged"
		p.skip_bump = true
		p.projectile = CombatProjectile.new("hp", 1, "yellow")
		p.targets_max_hp = [max_h] as Array[int]
		out_events.append(CombatEvent.new(CombatEvent.Type.DAMAGE, {
			"source_uuid": mecha.ball_uuid,
			"target_uuids": [target_enemy.ball_uuid],
			"visual_payload": p,
		}))

		var old_st: int = target_enemy.get_status_effect_amount(&"static")
		var new_st: int = int(bm.apply_stat_delta(target_enemy, "static_stacks", 1))
		var st_p := CombatPayload.status_change(mecha.ball_uuid, 1, "static_stacks", [old_st], [new_st])
		out_events.append(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
			"source_uuid": mecha.ball_uuid,
			"target_uuids": [target_enemy.ball_uuid],
			"visual_payload": st_p,
		}))

		if new_h <= 0:
			bm.trigger_on_kill(mecha.ball_uuid, target_enemy.ball_uuid)


## Tank L2 (Armor pass behind) & Mecha L2 (Static on attacker) when Armor absorbs damage.
static func apply_on_armor_absorbed_traits(defender: GachaBallInstance, attacker_uuid: String, bm: Node) -> void:
	var is_player: bool = bm._is_player_unit(defender)
	var team_traits: Dictionary = bm.get_active_traits("PLAYER" if is_player else "ENEMY")

	# Tank L2: When a Tank absorbs damage with Armor, ally directly behind gains 1 Armor
	if has_tier(team_traits, "TANK", 2) and bm.has_trait(defender, "TANK"):
		var ally_behind: GachaBallInstance = bm._get_ally_behind(defender)
		if is_instance_valid(ally_behind) and ally_behind.current_hp > 0:
			var old_ally_armor: int = ally_behind.get_status_effect_amount(&"armor")
			var new_ally_armor: int = int(bm.apply_stat_delta(ally_behind, "armor_stacks", 1, defender.ball_uuid, C.ACTION_BUFF))
			bm._emit_inline_trait_status_event(defender.ball_uuid, ally_behind, "armor_stacks", 1, old_ally_armor, new_ally_armor, &"ability_trait_tank")

	# Mecha L2: When Mecha Armor absorbs damage, inflicts 1 Static on attacker
	if has_tier(team_traits, "MECHA", 2) and bm.has_trait(defender, "MECHA") and not attacker_uuid.is_empty():
		var attacker_inst: GachaBallInstance = bm.get_instance_by_uuid(attacker_uuid)
		if is_instance_valid(attacker_inst) and attacker_inst.current_hp > 0:
			var old_att_static: int = attacker_inst.get_status_effect_amount(&"static")
			var new_att_static: int = int(bm.apply_stat_delta(attacker_inst, "static_stacks", 1, defender.ball_uuid))
			bm._emit_inline_trait_status_event(defender.ball_uuid, attacker_inst, "static_stacks", 1, old_att_static, new_att_static, &"ability_trait_mecha")


## Plant L4: whenever a living Lineup Plant receives ACTION_HEAL, it gains 1 Spikes.
static func apply_on_heal_traits(unit: GachaBallInstance, source_uuid: String, is_in_lineup: bool, bm: Node) -> void:
	if not is_in_lineup or not is_instance_valid(unit):
		return
	var u_is_player: bool = bm._is_player_unit(unit)
	var u_traits: Dictionary = bm.get_active_traits("PLAYER" if u_is_player else "ENEMY")
	if has_tier(u_traits, "PLANT", 4) and bm.has_trait(unit, "PLANT"):
		var old_plant_spikes: int = unit.get_status_effect_amount(&"spikes")
		var new_plant_spikes: int = int(bm.apply_stat_delta(unit, "spikes_stacks", 1, source_uuid, C.ACTION_BUFF))
		bm._emit_inline_trait_status_event(unit.ball_uuid, unit, "spikes_stacks", 1, old_plant_spikes, new_plant_spikes, &"ability_trait_plant")


## Appliance L1/L2/L3/L4 Burn/Static immunity, reflection, and conversion.
## Returns true if the incoming status stack gain was intercepted/absorbed by Appliance.
static func try_intercept_appliance_status(unit: GachaBallInstance, effect_name: String, delta: int, source_uuid: String, is_in_lineup: bool, bm: Node) -> bool:
	if not is_in_lineup or delta <= 0 or not is_instance_valid(unit) or not bm.has_trait(unit, "APPLIANCE"):
		return false
	if effect_name != "burn" and effect_name != "static":
		return false
	var is_app_player: bool = bm._is_player_unit(unit)
	var app_traits: Dictionary = bm.get_active_traits("PLAYER" if is_app_player else "ENEMY")
	var required_tier: int = 2 if effect_name == "burn" else 1
	if not has_tier(app_traits, "APPLIANCE", required_tier):
		return false

	# Appliance L4: convert absorbed Burn -> HP, Static -> PWR
	if has_tier(app_traits, "APPLIANCE", 4):
		var stat_name: String = "hp" if effect_name == "burn" else "pwr"
		var old_stat: int = unit.current_hp if stat_name == "hp" else unit.current_pwr
		var new_stat: int = int(bm.apply_stat_delta(unit, stat_name, delta, source_uuid, C.ACTION_BUFF))
		bm._emit_inline_trait_buff_event(unit.ball_uuid, unit, stat_name, delta, old_stat, new_stat, &"ability_trait_appliance")

	# Appliance L3: reflect absorbed Burn/Static back to sender
	if has_tier(app_traits, "APPLIANCE", 3):
		_handle_appliance_reflection(source_uuid, effect_name + "_stacks", delta, unit.ball_uuid, bm)

	return true


## Tank L4: when a Lineup Tank gains Armor, it gains equal Spikes.
static func apply_on_status_gained_traits(unit: GachaBallInstance, effect_name: String, delta: int, source_uuid: String, is_in_lineup: bool, bm: Node) -> void:
	if not is_in_lineup or delta <= 0 or effect_name != "armor" or not is_instance_valid(unit):
		return
	var is_tnk_player: bool = bm._is_player_unit(unit)
	var tnk_traits: Dictionary = bm.get_active_traits("PLAYER" if is_tnk_player else "ENEMY")
	if has_tier(tnk_traits, "TANK", 4) and bm.has_trait(unit, "TANK"):
		var old_tnk_spikes: int = unit.get_status_effect_amount(&"spikes")
		var new_tnk_spikes: int = int(bm.apply_stat_delta(unit, "spikes_stacks", delta, source_uuid, C.ACTION_BUFF))
		bm._emit_inline_trait_status_event(unit.ball_uuid, unit, "spikes_stacks", delta, old_tnk_spikes, new_tnk_spikes, &"ability_trait_tank")


## Fighter L2 retaliation + Food L1-L4 heal/buff ally behind on hurt.
static func apply_on_hurt_traits(victim: GachaBallInstance, victim_team: String, attacker_uuid: String, cause: StringName, bm: Node) -> void:
	if not is_instance_valid(victim) or not bm._is_lineup_container(victim.location_container_tag):
		return
	var target_uuid: String = victim.ball_uuid
	var target_is_player: bool = (victim_team == "PLAYER")
	var target_traits: Dictionary = bm.get_active_traits("PLAYER" if target_is_player else "ENEMY")

	# Fighter L2: Retaliation on attack damage (1 ranged damage to attacker, 1/turn per Fighter)
	if cause == C.CAUSE_ATTACK and not attacker_uuid.is_empty():
		if has_tier(target_traits, "FIGHTER", 2) and bm.has_trait(victim, "FIGHTER"):
			var retal_key: String = "fighter_retaliated_turn_" + str(bm._current_turn) + "_" + target_uuid
			if not bm._turn_metadata.get(retal_key, false):
				bm._turn_metadata[retal_key] = true
				var atk_inst: GachaBallInstance = bm.get_instance_by_uuid(attacker_uuid)
				if is_instance_valid(atk_inst) and atk_inst.current_hp > 0:
					var old_h: int = atk_inst.current_hp
					var old_a: int = atk_inst.get_status_effect_amount(&"armor")
					var retal_res: Dictionary = bm.apply_damage(atk_inst, 1, C.DamageType.RANGED, target_uuid)
					var new_h: int = int(retal_res.get("new_hp", atk_inst.current_hp))
					var a_cons: int = int(retal_res.get("armor_consumed", 0))
					var new_a: int = int(retal_res.get("new_armor", old_a))
					var atk_def: Resource = atk_inst.get_definition()
					var max_h: int = int(atk_def.base_hp) if is_instance_valid(atk_def) and "base_hp" in atk_def else 0
					var payload := CombatPayload.damage(target_uuid, 1, [old_h], [new_h], [old_a], [new_a], [a_cons])
					payload.attack_type = "ranged"
					payload.skip_bump = true
					payload.projectile = CombatProjectile.new("hp", 1, "red")
					payload.targets_max_hp = [max_h] as Array[int]
					bm._combat.add_inline_event(CombatEvent.new(CombatEvent.Type.DAMAGE, {
						"source_uuid": target_uuid,
						"target_uuids": [attacker_uuid],
						"visual_payload": payload,
					}))
					if new_h <= 0:
						bm.trigger_on_kill(target_uuid, attacker_uuid)

	# Food L1-L4: on_hurt heal/buff ally directly behind
	var food_tier: int = get_tier("FOOD", int(target_traits.get("FOOD", 0)))
	if food_tier >= 1 and bm.has_trait(victim, "FOOD"):
		var ally_behind: GachaBallInstance = bm._get_ally_behind(victim)
		if is_instance_valid(ally_behind) and ally_behind.current_hp > 0:
			var heal_amount: int = food_tier
			var pwr_amount: int = 2 if food_tier >= 4 else (1 if food_tier == 3 else 0)
			var old_h: int = ally_behind.current_hp
			var new_h: int = int(bm.apply_stat_delta(ally_behind, "hp", heal_amount, target_uuid, C.ACTION_HEAL))
			var ab_def: Resource = ally_behind.get_definition()
			var max_h: int = int(ab_def.base_hp) if is_instance_valid(ab_def) and "base_hp" in ab_def else 0

			bm._combat.add_inline_event(CombatEvent.new(CombatEvent.Type.HEAL, {
				"source_uuid": target_uuid,
				"target_uuids": [ally_behind.ball_uuid],
				"action_type": C.ACTION_HEAL,
				"visual_payload": CombatPayload.heal(target_uuid, heal_amount, [old_h], [new_h], [max_h]),
			}))

			if pwr_amount > 0:
				var old_p: int = ally_behind.current_pwr
				var new_p: int = int(bm.apply_stat_delta(ally_behind, "pwr", pwr_amount, target_uuid, C.ACTION_BUFF))
				bm._combat.add_inline_event(CombatEvent.new(CombatEvent.Type.BUFF, {
					"source_uuid": target_uuid,
					"target_uuids": [ally_behind.ball_uuid],
					"action_type": C.ACTION_BUFF,
					"visual_payload": CombatPayload.pwr_change(target_uuid, pwr_amount, [old_p], [new_p]),
				}))


## Fire L5 Burn dispersion + Fighter L4 extra action + Specialist L3 kill gold.
static func apply_on_kill_traits(killer: GachaBallInstance, killed: GachaBallInstance, bm: Node) -> void:
	if not is_instance_valid(killer) or not is_instance_valid(killed) or not bm._is_lineup_container(killer.location_container_tag):
		return
	var killer_uuid: String = killer.ball_uuid
	var killed_uuid: String = killed.ball_uuid
	var killer_is_player: bool = bm._is_player_unit(killer)
	var killer_traits: Dictionary = bm.get_active_traits("PLAYER" if killer_is_player else "ENEMY")

	# Fire L5: Burn dispersion on kill
	if has_tier(killer_traits, "FIRE", 5) and bm.has_trait(killer, "FIRE"):
		var burn_stacks: int = killed.get_status_effect_amount(&"burn")
		if burn_stacks > 0:
			killed.clear_status_effect_silent(&"burn")
			var killed_loc: LocationIdentifier = bm.get_location_for_uuid(killed_uuid)
			if is_instance_valid(killed_loc):
				var lineup: Array = bm.get_instances_in_container(killed_loc.container)
				var adj_living: Array[GachaBallInstance] = []
				for unit: GachaBallInstance in lineup:
					if not is_instance_valid(unit) or unit.current_hp <= 0 or unit.ball_uuid == killed_uuid:
						continue
					if unit.location_slot_index == killed_loc.index - 1 or unit.location_slot_index == killed_loc.index + 1:
						adj_living.append(unit)
				adj_living.sort_custom(func(a: GachaBallInstance, b: GachaBallInstance) -> bool:
					return a.location_slot_index < b.location_slot_index
				)
				if adj_living.size() == 2:
					var half: int = int(floor(burn_stacks / 2.0))
					var front_burn: int = half + (burn_stacks % 2)
					var rear_burn: int = half
					var old_f: int = adj_living[0].get_status_effect_amount(&"burn")
					var new_f: int = int(bm.apply_stat_delta(adj_living[0], "burn_stacks", front_burn, killer_uuid))
					bm._combat.add_inline_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
						"source_uuid": killer_uuid,
						"target_uuids": [adj_living[0].ball_uuid],
						"visual_payload": CombatPayload.status_change(killer_uuid, front_burn, "burn_stacks", [old_f], [new_f]),
					}))
					var old_r: int = adj_living[1].get_status_effect_amount(&"burn")
					var new_r: int = int(bm.apply_stat_delta(adj_living[1], "burn_stacks", rear_burn, killer_uuid))
					bm._combat.add_inline_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
						"source_uuid": killer_uuid,
						"target_uuids": [adj_living[1].ball_uuid],
						"visual_payload": CombatPayload.status_change(killer_uuid, rear_burn, "burn_stacks", [old_r], [new_r]),
					}))
				elif adj_living.size() == 1:
					var old_b: int = adj_living[0].get_status_effect_amount(&"burn")
					var new_b: int = int(bm.apply_stat_delta(adj_living[0], "burn_stacks", burn_stacks, killer_uuid))
					bm._combat.add_inline_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
						"source_uuid": killer_uuid,
						"target_uuids": [adj_living[0].ball_uuid],
						"visual_payload": CombatPayload.status_change(killer_uuid, burn_stacks, "burn_stacks", [old_b], [new_b]),
					}))

	# Fighter L4: +1 PWR and extra action on kill (1/turn per Fighter)
	if has_tier(killer_traits, "FIGHTER", 4) and bm.has_trait(killer, "FIGHTER"):
		var key: String = "fighter_kill_action_" + killer_uuid
		if not bm._turn_metadata.get(key, false):
			bm._turn_metadata[key] = true
			var old_fighter_pwr: int = killer.current_pwr
			var new_fighter_pwr: int = int(bm.apply_stat_delta(killer, "pwr", 1, killer_uuid, C.ACTION_BUFF))
			bm._emit_inline_trait_buff_event(killer_uuid, killer, "pwr", 1, old_fighter_pwr, new_fighter_pwr, &"ability_trait_fighter")
			bm.grant_extra_action(killer_uuid)

	# Specialist L3: Defeating an enemy awards +1 Gold (max 1/turn, 5/battle)
	if killer_is_player and has_tier(killer_traits, "SPECIALIST", 3) and bm.has_trait(killer, "SPECIALIST"):
		var turn_key: String = "specialist_gold_awarded_turn_" + str(bm._current_turn)
		if not bm._turn_metadata.get(turn_key, false) and bm._specialist_gold_awarded_battle < 5:
			bm._turn_metadata[turn_key] = true
			bm._specialist_gold_awarded_battle += 1
			bm.earn_gold(1, killed_uuid)


## Fire L3: Spread 1 Burn to each living adjacent ally when Burn ticks.
static func apply_fire_burn_tick_spread(burning_unit: GachaBallInstance, bm: Node, out_events: Array[CombatEvent]) -> void:
	if not is_instance_valid(burning_unit):
		return
	var is_player_unit: bool = bm._is_player_unit(burning_unit)
	var opp_team: String = "ENEMY" if is_player_unit else "PLAYER"
	if not has_tier(bm.get_active_traits(opp_team), "FIRE", 3):
		return
	var loc: LocationIdentifier = bm.get_location_for_uuid(burning_unit.ball_uuid)
	if not is_instance_valid(loc):
		return
	for adj: GachaBallInstance in bm.get_instances_in_container(loc.container):
		if not is_instance_valid(adj) or adj.current_hp <= 0 or adj.ball_uuid == burning_unit.ball_uuid:
			continue
		if adj.location_slot_index == loc.index - 1 or adj.location_slot_index == loc.index + 1:
			var old_b: int = adj.get_status_effect_amount(&"burn")
			var new_b: int = int(bm.apply_stat_delta(adj, "burn_stacks", 1, burning_unit.ball_uuid))
			var spread_payload := CombatPayload.status_change(burning_unit.ball_uuid, 1, "burn_stacks", [old_b], [new_b])
			out_events.append(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
				"source_uuid": burning_unit.ball_uuid,
				"target_uuids": [adj.ball_uuid],
				"visual_payload": spread_payload,
			}))


## Toy L1-L3 melee Static reflection resolved at contact.
static func apply_melee_defender_toy_reflection(attacker: GachaBallInstance, defender: GachaBallInstance, bm: Node) -> CombatStaticReflectionData:
	if not is_instance_valid(defender) or not is_instance_valid(attacker) or attacker.current_hp <= 0:
		return null
	var def_is_player: bool = bm._is_player_unit(defender)
	var def_traits: Dictionary = bm.get_active_traits("PLAYER" if def_is_player else "ENEMY")
	var toy_tier: int = get_tier("TOY", int(def_traits.get("TOY", 0)))
	if toy_tier < 1 or not bm.has_trait(defender, "TOY"):
		return null
	var toy_static: int = 4 if toy_tier >= 3 else (3 if toy_tier == 2 else 2)
	var atk_old_st: int = attacker.get_status_effect_amount(&"static")
	var atk_new_st: int = int(bm.apply_stat_delta(attacker, "static_stacks", toy_static, defender.ball_uuid))
	var static_refl := CombatStaticReflectionData.new()
	static_refl.attacker_uuid = attacker.ball_uuid
	static_refl.defender_uuid = defender.ball_uuid
	static_refl.static_amount = toy_static
	static_refl.attacker_old_static = atk_old_st
	static_refl.attacker_new_static = atk_new_st
	return static_refl


## Animal L1-L4 heal on basic attack.
static func apply_animal_attack_heal(attacker: GachaBallInstance, bm: Node, impact_events: Array[CombatEvent]) -> void:
	if not is_instance_valid(attacker) or attacker.current_hp <= 0 or not bm.has_trait(attacker, "ANIMAL"):
		return
	var is_player: bool = bm._is_player_unit(attacker)
	var active_traits: Dictionary = bm.get_active_traits("PLAYER" if is_player else "ENEMY")
	var animal_tier: int = get_tier("ANIMAL", int(active_traits.get("ANIMAL", 0)))
	if animal_tier < 1:
		return
	var heal_amount: int = 1
	if animal_tier >= 4:
		heal_amount = 3 + maxi(1, int(floor(attacker.current_pwr * 0.25)))
	elif animal_tier == 3:
		heal_amount = 3
	elif animal_tier == 2:
		heal_amount = 2

	var a_old_hp: int = attacker.current_hp
	var a_new_hp: int = int(bm.apply_stat_delta(attacker, "hp", heal_amount, attacker.ball_uuid, C.ACTION_HEAL))
	var a_def: Resource = attacker.get_definition()
	var a_max_hp: int = int(a_def.base_hp) if is_instance_valid(a_def) and "base_hp" in a_def else 0
	impact_events.append(CombatEvent.new(CombatEvent.Type.HEAL, {
		"source_uuid": attacker.ball_uuid,
		"target_uuids": [attacker.ball_uuid],
		"action_type": C.ACTION_HEAL,
		"visual_payload": CombatPayload.heal(attacker.ball_uuid, heal_amount, [a_old_hp], [a_new_hp], [a_max_hp]),
	}))


static func _handle_appliance_reflection(source_uuid: String, stat_name: String, delta: int, reflector_uuid: String, bm: Node) -> void:
	if source_uuid.is_empty():
		return
	var sender: GachaBallInstance = bm.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(sender):
		return
	var sender_def: Resource = sender.get_definition()
	if not is_instance_valid(sender_def):
		return
	var status_key: StringName = StringName(stat_name.trim_suffix("_stacks"))
	var origin_uuid: String = reflector_uuid if not reflector_uuid.is_empty() else source_uuid
	if sender_def.category == &"ITEM":
		if not sender.equipped_on_uuid.is_empty():
			var holder: GachaBallInstance = bm.get_instance_by_uuid(sender.equipped_on_uuid)
			if is_instance_valid(holder) and holder.current_hp > 0 and not bm.has_trait(holder, "APPLIANCE"):
				var old_val: int = holder.get_status_effect_amount(status_key)
				var new_val: int = int(bm.apply_stat_delta(holder, stat_name, delta, origin_uuid))
				bm._emit_inline_trait_status_event(origin_uuid, holder, stat_name, delta, old_val, new_val, &"ability_trait_appliance")
	elif sender_def.category == &"UNIT":
		if sender.current_hp > 0 and not bm.has_trait(sender, "APPLIANCE"):
			var old_val: int = sender.get_status_effect_amount(status_key)
			var new_val: int = int(bm.apply_stat_delta(sender, stat_name, delta, origin_uuid))
			bm._emit_inline_trait_status_event(origin_uuid, sender, stat_name, delta, old_val, new_val, &"ability_trait_appliance")
