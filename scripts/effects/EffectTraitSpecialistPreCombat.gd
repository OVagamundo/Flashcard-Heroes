# res://scripts/effects/EffectTraitSpecialistPreCombat.gd
@tool
extends EffectDefinition

## Start-of-Combat Specialist trait effect granted by Specialist Trait Trinket.
## Triggered on_pre_combat.
## Thresholds (Units):
##   L1 (2 Units): If player tokens == 0, grants 1 Token (projectile from Specialist trinket to HUD).
##   L4 (5 Units): Summons temporary combat copy of lowest tier/level unit to bench
##                 (tie-breaker: lowest tier first, lowest level second, RNGManager.combat_rng).
##                 Overflows to discard pile if bench is full.

const C = preload("res://scripts/Constants.gd")
const EffectHandlers = preload("res://scripts/battle/EffectHandlers.gd")

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
	var specialist_units: int = int(active_traits.get("SPECIALIST", 0))
	if specialist_units < 2:
		return EffectResult.empty()

	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"ability_trait_specialist")

	# L1 (2 Units): If player tokens == 0, grants 1 Token
	if is_player and specialist_units >= 2:
		var current_tokens = battle_manager.get_gacha_tokens()
		if current_tokens == 0:
			battle_manager.add_gacha_tokens(1)
			var target_tokens = battle_manager.get_gacha_tokens()
			var token_payload := CombatPayload.new()
			token_payload.amount = 1
			token_payload.origin_uuid = source_uuid
			token_payload.target_token_amount = target_tokens

			result.add_event(CombatEvent.new(CombatEvent.Type.TOKEN_GAIN, {
				"source_uuid": source_uuid,
				"target_uuids": [source_uuid],
				"ability_id": ability_id,
				"amount": 1,
				"visual_payload": token_payload
			}))

	# L4 (5 Units): Summon combat copy of lowest tier/level unit
	if specialist_units >= 5:
		var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
		var units = battle_manager.get_instances_in_container(container_tag)
		var eligible: Array[GachaBallInstance] = []
		for u in units:
			if is_instance_valid(u) and u.current_hp > 0:
				var def = u.get_definition()
				if is_instance_valid(def) and def.category == &"UNIT":
					eligible.append(u)

		if not eligible.is_empty():
			var non_heroes = eligible.filter(func(u):
				var def = u.get_definition()
				return is_instance_valid(def) and not def.is_hero
			)
			var pool = non_heroes if not non_heroes.is_empty() else eligible

			# Sort tie-breaker: lowest tier first, lowest level second
			var min_tier = 999
			for u in pool:
				var t = u.get_definition().tier
				if t < min_tier:
					min_tier = t

			var tier_pool = pool.filter(func(u): return u.get_definition().tier == min_tier)

			var min_level = 999
			for u in tier_pool:
				if u.level < min_level:
					min_level = u.level

			var candidate_pool = tier_pool.filter(func(u): return u.level == min_level)
			var chosen_unit: GachaBallInstance = RNGManager.combat_rng.pick_random(candidate_pool)

			if is_instance_valid(chosen_unit):
				# Find destination slot: Bench first, discard pile if bench full
				var bench_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH if is_player else C.BATTLE_CONTAINER_TAGS.ENEMY_BENCH
				var bench = battle_manager._state.get_container(bench_tag)
				var empty_slot = bench.find_first_empty_slot() if is_instance_valid(bench) else -1
				var dest_container: StringName
				var dest_slot: int

				if empty_slot != -1 and empty_slot < 5:
					dest_container = bench_tag
					dest_slot = empty_slot
				else:
					dest_container = C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE
					var discard = battle_manager._state.get_container(dest_container)
					dest_slot = discard.find_first_empty_slot() if is_instance_valid(discard) else 0
					if dest_slot == -1:
						dest_slot = discard.get_all_uuids().size()

				var copy = chosen_unit.duplicate_instance(battle_manager.get_all_instances())
				if is_instance_valid(copy):
					copy.is_temporary = true
					battle_manager._state.bm_add_instance(copy, dest_container, dest_slot)

					var VisualDataAdapter = preload("res://scripts/VisualDataAdapter.gd")
					var snap = VisualDataAdapter.create_visual_data(copy, battle_manager.get_all_instances())
					var loc = LocationIdentifier.new(dest_container, dest_slot)
					var summon_payload = EffectHandlers._make_summon_payload("", copy.ball_uuid, loc, snap, source_uuid, copy.get_definition().tier)

					result.add_event(CombatEvent.new(CombatEvent.Type.SUMMON, {
						"source_uuid": source_uuid,
						"target_uuids": [copy.ball_uuid],
						"ability_id": ability_id,
						"visual_payload": summon_payload
					}))

	result.state_applied = true
	return result
