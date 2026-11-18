extends Node

const C = preload("res://scripts/Constants.gd")
const BattleManagerScript = preload("res://scripts/BattleManager.gd")
const EffectTransferItemBehindScript = preload("res://scripts/EffectTransferItemBehind.gd")
const EffectGainDeadAllyPwrAsHPScript = preload("res://scripts/effects/EffectGainDeadAllyPwrAsHP.gd")
const EffectGalebloomPreBattleScript = preload("res://scripts/effects/EffectGalebloomPreBattle.gd")
const EffectStormshroudHealOnHurtScript = preload("res://scripts/effects/EffectStormshroudHealOnHurt.gd")
const EffectSummonOnDeathScript = preload("res://scripts/EffectSummonOnDeath.gd")
const EffectSummonT2OnDeathScript = preload("res://scripts/EffectSummonT2OnDeath.gd")
const ReplayStateDigest = preload("res://scripts/engine/replay/ReplayStateDigest.gd")

var suite_has_failed: bool = false

func _assert_ok(cond: bool, msg: String) -> void:
	if not cond:
		suite_has_failed = true
		push_error("ASSERTION FAILED: " + msg)
		printerr("ASSERTION FAILED: " + msg)

func _make_equipped_loc(unit_uuid: String, slot_idx: int = 0) -> LocationIdentifier:
	var loc := LocationIdentifier.new(C.CONTAINER_EQUIPPED_ITEM, slot_idx)
	loc.unit_uuid = unit_uuid
	return loc

func _ready() -> void:
	print("==================================================")
	print("=== RUNNING FAST VERIFICATION SUITE (< 4s)    ===")
	print("==================================================")

	# Prevent SceneManager from hijacking the test runner with Main.tscn
	if is_instance_valid(SceneManager) and SignalBus.main_scene_requested.is_connected(SceneManager._on_main_scene_requested):
		SignalBus.main_scene_requested.disconnect(SceneManager._on_main_scene_requested)

	# Global speedup so any pausable timers complete instantaneously
	AnimationConstants.is_in_battle = true
	AnimationConstants.speed_factor = 1000.0

	# ----------------------------------------------------
	# SUITE 1: Database & Localization Referential Integrity
	# ----------------------------------------------------
	print("[SUITE 1/8] Database & Localization Referential Integrity...")
	_run_suite_1_database()
	print("  -> [PASS] Suite 1 Passed!")

	# ----------------------------------------------------
	# SUITE 2: Atomic Container & Hybrid Truth+Index Consistency
	# ----------------------------------------------------
	print("[SUITE 2/8] Atomic Container & Hybrid Truth+Index Consistency...")
	await _run_suite_2_atomic_state()
	print("  -> [PASS] Suite 2 Passed!")

	# ----------------------------------------------------
	# SUITE 3: Deterministic Seed Parity (Seed X == Seed X)
	# ----------------------------------------------------
	print("[SUITE 3/8] Deterministic Seed Parity (Seed A == Seed A)...")
	await _run_suite_3_seed_determinism()
	print("  -> [PASS] Suite 3 Passed!")

	# ----------------------------------------------------
	# SUITE 4: RunState Save/Load Roundtrip Consistency
	# ----------------------------------------------------
	print("[SUITE 4/8] RunState Save/Load Roundtrip Consistency...")
	_run_suite_4_save_load()
	print("  -> [PASS] Suite 4 Passed!")

	# ----------------------------------------------------
	# SUITE 5: Constitutional SubPhase & Knockout Invariants
	# ----------------------------------------------------
	print("[SUITE 5/8] Constitutional SubPhase & Knockout Invariants...")
	await _run_suite_5_constitutional_invariants()
	print("  -> [PASS] Suite 5 Passed!")

	print("[SUITE 6/8] Phase 2 Content Reconciliation...")
	_run_suite_6_phase2_content()
	print("  -> [PASS] Suite 6 Passed!")

	# ----------------------------------------------------
	# SUITE 7: Novice Set Integration & Mechanics
	# ----------------------------------------------------
	print("[SUITE 7/8] Novice Set Integration & Mechanics...")
	await _run_suite_7_novice_set()
	print("  -> [PASS] Suite 7 Passed!")

	# ----------------------------------------------------
	# SUITE 8: Alternating Action Order & Highest-Rank Summon Placement
	# ----------------------------------------------------
	print("[SUITE 8/8] Alternating Action Order & Highest-Rank Summon Placement...")
	_run_suite_8_alternating_initiative()
	print("  -> [PASS] Suite 8 Passed!")

	if suite_has_failed:
		printerr("==================================================")
		printerr("=== FAST SUITE FAILED WITH ASSERTION ERRORS!   ===")
		printerr("==================================================")
		get_tree().quit(1)
		return

	print("==================================================")
	print("=== ALL FAST SUITE TESTS PASSED (0 ERRORS)    ===")
	print("==================================================")

	get_tree().quit(0)

# ==============================================================================
# SUITE 1 IMPLEMENTATION
# ==============================================================================
func _run_suite_1_database() -> void:
	_assert_ok(not Database.units.is_empty(), "Database.units must not be empty")
	_assert_ok(not Database.items.is_empty(), "Database.items must not be empty")
	_assert_ok(not Database.trinkets.is_empty(), "Database.trinkets must not be empty")
	_assert_ok(not Database.recipes.is_empty(), "Database.recipes must not be empty")

	var enemy_resource_pools: Dictionary = EncounterGenerator._create_resource_pools(true)
	for unit_value in enemy_resource_pools["units"]:
		var unit_definition: GachaBallDefinition = unit_value
		_assert_ok(not unit_definition.is_player_exclusive, "Player-exclusive unit %s entered enemy encounter pools" % unit_definition.id)
		_assert_ok(Database.get_entity_set(unit_definition) == Database.SET_BASE, "Non-base unit %s entered enemy encounter pools" % unit_definition.id)
	for item_value in enemy_resource_pools["items"]:
		var item_definition: GachaBallDefinition = item_value
		_assert_ok(not item_definition.is_player_exclusive, "Player-exclusive item %s entered enemy encounter pools" % item_definition.id)
		_assert_ok(Database.get_entity_set(item_definition) == Database.SET_BASE, "Non-base item %s entered enemy encounter pools" % item_definition.id)
	for trinket_value in enemy_resource_pools["trinkets"]:
		var trinket_definition: TrinketDefinition = trinket_value
		_assert_ok(not trinket_definition.is_player_exclusive, "Player-exclusive trinket %s entered enemy encounter pools" % trinket_definition.id)
		_assert_ok(Database.get_entity_set(trinket_definition) == Database.SET_BASE, "Non-base trinket %s entered enemy encounter pools" % trinket_definition.id)

	# Verify set pool scoping
	var novice_pool = Database.get_all_pool_definitions(Database.SET_NOVICE)
	var mercenary_pool = Database.get_all_pool_definitions(Database.SET_MERCENARY)
	var base_pool = Database.get_all_pool_definitions(Database.SET_BASE)
	var novice_in_novice_count: int = 0
	var merc_in_merc_count: int = 0
	for d in novice_pool:
		_assert_ok(Database.get_entity_set(d) != Database.SET_MERCENARY, "Mercenary entity %s leaked into Novice pool" % d.id)
		if Database.get_entity_set(d) == Database.SET_NOVICE:
			novice_in_novice_count += 1
	for d in mercenary_pool:
		_assert_ok(Database.get_entity_set(d) != Database.SET_NOVICE, "Novice entity %s leaked into Mercenary pool" % d.id)
		if Database.get_entity_set(d) == Database.SET_MERCENARY:
			merc_in_merc_count += 1
	for d in base_pool:
		_assert_ok(Database.get_entity_set(d) == Database.SET_BASE, "Non-base entity %s leaked into Base pool" % d.id)
	_assert_ok(novice_in_novice_count == 16, "All 16 Novice definitions (11 units + 5 items) are available in Novice pool")
	_assert_ok(merc_in_merc_count == 16, "All 16 Mercenary definitions (11 units + 5 items) are available in Mercenary pool")

	var novice_trinkets = Database.get_eligible_trinkets_for_reward(Database.SET_NOVICE)
	var mercenary_trinkets = Database.get_eligible_trinkets_for_reward(Database.SET_MERCENARY)
	var base_trinkets = Database.get_eligible_trinkets_for_reward(Database.SET_BASE)
	var novice_trinkets_count: int = 0
	var merc_trinkets_count: int = 0
	for t in novice_trinkets:
		_assert_ok(Database.get_entity_set(t) != Database.SET_MERCENARY, "Mercenary trinket %s leaked into Novice trinkets" % t.id)
		if Database.get_entity_set(t) == Database.SET_NOVICE:
			novice_trinkets_count += 1
	for t in mercenary_trinkets:
		_assert_ok(Database.get_entity_set(t) != Database.SET_NOVICE, "Novice trinket %s leaked into Mercenary trinkets" % t.id)
		if Database.get_entity_set(t) == Database.SET_MERCENARY:
			merc_trinkets_count += 1
	for t in base_trinkets:
		_assert_ok(Database.get_entity_set(t) == Database.SET_BASE, "Non-base trinket %s leaked into Base trinkets" % t.id)
	_assert_ok(novice_trinkets_count == 4, "All 4 Novice trinkets are available in Novice reward pool")
	_assert_ok(merc_trinkets_count == 4, "All 4 Mercenary trinkets are available in Mercenary reward pool")

	# In-Combat Random Summon Scoping Tests
	for t in [1, 2, 3]:
		var enemy_summons: Array[GachaBallDefinition] = Database.get_eligible_summon_units(t, false)
		_assert_ok(not enemy_summons.is_empty(), "Enemy Tier %d summon pool is not empty" % t)
		for u in enemy_summons:
			_assert_ok(not u.is_player_exclusive, "Enemy Tier %d summon unit %s is player-exclusive" % [t, u.id])
			_assert_ok(Database.get_entity_set(u) == Database.SET_BASE, "Enemy Tier %d summon unit %s belongs to non-base set %s" % [t, u.id, Database.get_entity_set(u)])

		var player_novice_summons: Array[GachaBallDefinition] = Database.get_eligible_summon_units(t, true, Database.SET_NOVICE)
		_assert_ok(not player_novice_summons.is_empty(), "Player Novice Tier %d summon pool is not empty" % t)
		for u in player_novice_summons:
			var u_set := Database.get_entity_set(u)
			_assert_ok(u_set == Database.SET_BASE or u_set == Database.SET_NOVICE, "Player Novice Tier %d summon unit %s belongs to illegal set %s" % [t, u.id, u_set])
			_assert_ok(u_set != Database.SET_MERCENARY, "Mercenary unit %s leaked into Player Novice summons" % u.id)

		var player_merc_summons: Array[GachaBallDefinition] = Database.get_eligible_summon_units(t, true, Database.SET_MERCENARY)
		_assert_ok(not player_merc_summons.is_empty(), "Player Mercenary Tier %d summon pool is not empty" % t)
		for u in player_merc_summons:
			var u_set := Database.get_entity_set(u)
			_assert_ok(u_set == Database.SET_BASE or u_set == Database.SET_MERCENARY, "Player Mercenary Tier %d summon unit %s belongs to illegal set %s" % [t, u.id, u_set])
			_assert_ok(u_set != Database.SET_NOVICE, "Novice unit %s leaked into Player Mercenary summons" % u.id)

		var player_base_summons: Array[GachaBallDefinition] = Database.get_eligible_summon_units(t, true, Database.SET_BASE)
		_assert_ok(not player_base_summons.is_empty(), "Player Base Tier %d summon pool is not empty" % t)
		for u in player_base_summons:
			var u_set := Database.get_entity_set(u)
			_assert_ok(u_set == Database.SET_BASE, "Non-base unit %s leaked into Player Base summons" % u.id)

	# EffectSummonUnitOnDeath in enemy context
	var enemy_summon_effect := EffectSummonUnitOnDeath.new()
	enemy_summon_effect.parameters = {"level": 1, "tier": 1}
	var enemy_ctx := TriggerContext.new()
	enemy_ctx.knocked_out_uuid = "enemy_unit_uuid"
	enemy_ctx.knocked_out_team = "ENEMY"
	enemy_ctx.knocked_out_location = LocationIdentifier.new(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, 0)
	var enemy_res: EffectResult = enemy_summon_effect.execute("enemy_unit_uuid", [], null, enemy_ctx)
	_assert_ok(not enemy_res.summon_request.is_empty(), "EffectSummonUnitOnDeath generates summon request for enemy")
	var enemy_summoned_def: GachaBallDefinition = Database.units[enemy_res.summon_request["summon_unit_id"]]
	_assert_ok(not enemy_summoned_def.is_player_exclusive, "Enemy on-death summon unit %s must not be player-exclusive" % enemy_summoned_def.id)
	_assert_ok(Database.get_entity_set(enemy_summoned_def) == Database.SET_BASE, "Enemy on-death summon unit %s must be SET_BASE" % enemy_summoned_def.id)

	# EffectSummonOnDeath in enemy context
	var enemy_item_summon = EffectSummonOnDeathScript.new()
	var enemy_item_ctx := TriggerContext.new()
	enemy_item_ctx.knocked_out_uuid = "enemy_holder_uuid"
	enemy_item_ctx.knocked_out_team = "ENEMY"
	enemy_item_ctx.knocked_out_location = LocationIdentifier.new(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, 1)
	enemy_item_ctx.equipped_items = [{"uuid": "item_uuid"}]
	var item_res: EffectResult = enemy_item_summon.execute("item_uuid", [], null, enemy_item_ctx)
	_assert_ok(not item_res.summon_request.is_empty(), "EffectSummonOnDeath generates summon request for enemy")
	var item_summoned_def: GachaBallDefinition = Database.units[item_res.summon_request["summon_unit_id"]]
	_assert_ok(not item_summoned_def.is_player_exclusive, "Enemy item on-death summon %s must not be player-exclusive" % item_summoned_def.id)
	_assert_ok(Database.get_entity_set(item_summoned_def) == Database.SET_BASE, "Enemy item on-death summon %s must be SET_BASE" % item_summoned_def.id)

	# EffectSummonT2OnDeath in enemy context
	var enemy_t2_summon = EffectSummonT2OnDeathScript.new()
	var enemy_t2_ctx := TriggerContext.new()
	enemy_t2_ctx.knocked_out_uuid = "enemy_t2_holder_uuid"
	enemy_t2_ctx.knocked_out_team = "ENEMY"
	enemy_t2_ctx.knocked_out_location = LocationIdentifier.new(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, 2)
	var t2_res: EffectResult = enemy_t2_summon.execute("enemy_t2_holder_uuid", [], null, enemy_t2_ctx)
	_assert_ok(not t2_res.summon_request.is_empty(), "EffectSummonT2OnDeath generates summon request for enemy")
	var t2_summoned_def: GachaBallDefinition = Database.units[t2_res.summon_request["summon_unit_id"]]
	_assert_ok(not t2_summoned_def.is_player_exclusive, "Enemy T2 on-death summon %s must not be player-exclusive" % t2_summoned_def.id)
	_assert_ok(Database.get_entity_set(t2_summoned_def) == Database.SET_BASE, "Enemy T2 on-death summon %s must be SET_BASE" % t2_summoned_def.id)

	# Check recipes referential integrity
	for r_id in Database.recipes.keys():
		var r: MergeRecipe = Database.recipes[r_id]
		if r.ingredient_a_id != &"":
			_assert_ok(Database.get_definition(r.ingredient_a_id) != null, "Recipe %s ingredient_a %s must exist in Database" % [r_id, r.ingredient_a_id])
		if r.ingredient_b_id != &"":
			_assert_ok(Database.get_definition(r.ingredient_b_id) != null, "Recipe %s ingredient_b %s must exist in Database" % [r_id, r.ingredient_b_id])
		if r.result_id != &"":
			_assert_ok(Database.get_definition(r.result_id) != null, "Recipe %s result %s must exist in Database" % [r_id, r.result_id])

	# Check translations for player-facing entities in en and pt_BR
	for loc in ["en", "pt_BR"]:
		TranslationServer.set_locale(loc)
		for u_id in Database.units.keys():
			var u: GachaBallDefinition = Database.units[u_id]
			if not u.display_name_key.is_empty() and not String(u_id).begins_with("test_"):
				var tr_val: String = TranslationServer.translate(u.display_name_key)
				_assert_ok(not tr_val.is_empty() and tr_val != u.display_name_key, "[%s] Missing unit translation for key: %s (id: %s)" % [loc, u.display_name_key, u_id])
		for i_id in Database.items.keys():
			var it: GachaBallDefinition = Database.items[i_id]
			if not it.display_name_key.is_empty() and not String(i_id).begins_with("test_"):
				var tr_val: String = TranslationServer.translate(it.display_name_key)
				_assert_ok(not tr_val.is_empty() and tr_val != it.display_name_key, "[%s] Missing item translation for key: %s (id: %s)" % [loc, it.display_name_key, i_id])
		for t_id in Database.trinkets.keys():
			var tr_def: TrinketDefinition = Database.trinkets[t_id]
			if not tr_def.name_key.is_empty() and not String(t_id).begins_with("test_"):
				var tr_val: String = TranslationServer.translate(tr_def.name_key)
				_assert_ok(not tr_val.is_empty() and tr_val != tr_def.name_key, "[%s] Missing trinket translation for key: %s (id: %s)" % [loc, tr_def.name_key, t_id])
			if not tr_def.description_key.is_empty() and not String(t_id).begins_with("test_"):
				var tr_val: String = TranslationServer.translate(tr_def.description_key)
				_assert_ok(not tr_val.is_empty() and tr_val != tr_def.description_key, "[%s] Missing trinket description translation for key: %s (id: %s)" % [loc, tr_def.description_key, t_id])
		for trait_name in C.TRAIT_DEFINITIONS.keys():
			var trait_def: Dictionary = C.TRAIT_DEFINITIONS[trait_name]
			var disp_key: String = trait_def.get("display_name_key", "")
			if not disp_key.is_empty():
				var tr_val: String = TranslationServer.translate(disp_key)
				_assert_ok(not tr_val.is_empty() and tr_val != disp_key, "[%s] Missing trait name translation for key: %s (trait: %s)" % [loc, disp_key, trait_name])
			for lvl in trait_def.get("levels", []):
				var lvl_key: String = lvl.get("desc_key", "")
				if not lvl_key.is_empty():
					var tr_val: String = TranslationServer.translate(lvl_key)
					_assert_ok(not tr_val.is_empty() and tr_val != lvl_key, "[%s] Missing trait level translation for key: %s (trait: %s, min: %d)" % [loc, lvl_key, trait_name, lvl.get("min", 0)])

	# Economic 1/2/4 Invariant Verification:
	# Unit & Item costs are mathematically derived from tier & level; trinkets cost 10.
	for u_id in Database.units.keys():
		var u: GachaBallDefinition = Database.units[u_id]
		if u.tier > 0:
			var expected_cost: int = (1 << (u.tier - 1)) * (1 << (maxi(1, u.level) - 1))
			_assert_ok(u.cost == expected_cost, "Unit %s cost %d does not match 1/2/4 formula %d" % [u_id, u.cost, expected_cost])
			_assert_ok(GameManager.get_item_cost(u) == expected_cost, "GameManager cost for unit %s mismatch" % u_id)

	for i_id in Database.items.keys():
		var it: GachaBallDefinition = Database.items[i_id]
		if it.tier > 0:
			var expected_cost: int = (1 << (it.tier - 1)) * (1 << (maxi(1, it.level) - 1))
			_assert_ok(it.cost == expected_cost, "Item %s cost %d does not match 1/2/4 formula %d" % [i_id, it.cost, expected_cost])
			_assert_ok(GameManager.get_item_cost(it) == expected_cost, "GameManager cost for item %s mismatch" % i_id)

	for t_id in Database.trinkets.keys():
		var tr_def: TrinketDefinition = Database.trinkets[t_id]
		var expected_cost: int = 0 if tr_def.is_banner else TrinketDefinition.DEFAULT_TRINKET_COST
		_assert_ok(tr_def.cost == expected_cost, "Trinket %s cost %d must be %d" % [t_id, tr_def.cost, expected_cost])
		_assert_ok(GameManager.get_item_cost(tr_def) == expected_cost, "GameManager cost for trinket %s must be %d" % [t_id, expected_cost])

	# Invariant: Basic attack definitions are manual turn actions, not event-driven abilities
	var basic_atk: AbilityDefinition = Database.abilities.get(&"basic_attack", null)
	_assert_ok(is_instance_valid(basic_atk), "Database.abilities contains basic_attack")
	if is_instance_valid(basic_atk):
		_assert_ok(basic_atk.trigger == &"", "BasicAttack trigger must be empty (got '%s')" % basic_atk.trigger)

	var basic_ranged: AbilityDefinition = Database.abilities.get(&"basic_attack_ranged_mirror", null)
	_assert_ok(is_instance_valid(basic_ranged), "Database.abilities contains basic_attack_ranged_mirror")
	if is_instance_valid(basic_ranged):
		_assert_ok(basic_ranged.trigger == &"", "BasicAttackRangedMirror trigger must be empty (got '%s')" % basic_ranged.trigger)

# ==============================================================================
# SUITE 2 IMPLEMENTATION (Ported Atomic Invariants)
# ==============================================================================
func _run_suite_2_atomic_state() -> void:
	# Part 1: RunState atomic operations & Hero slot preservation
	GameManager.is_in_battle = false
	GameManager.start_run_with_seed(&"hero_bounty_hunter", &"deck_nihongo_starter")
	var rs: RunState = GameManager.run_state
	rs.unlock_all_recipes_for_testing()
	_assert_ok(rs._validate_state_consistency(), "RunState initial consistency")

	# Move hero from PlayerLineup:0 to PlayerLineup:2
	var hero := rs.hero_instance
	_assert_ok(is_instance_valid(hero), "Hero instance valid")
	var moved_hero := rs.move_instance(
		LocationIdentifier.new(&"PlayerLineup", 0),
		LocationIdentifier.new(&"PlayerLineup", 2)
	)
	_assert_ok(moved_hero and hero.location_slot_index == 2, "Hero moved to PlayerLineup:2")

	# Place two units in PlayerLineup:0 and PlayerLineup:1 from RunInventoryT1
	var inv_t1 := rs.get_inventory_tier_instances(1)
	var u1: GachaBallInstance = null
	var u2: GachaBallInstance = null
	var it1: GachaBallInstance = null
	var it2: GachaBallInstance = null
	for inst in inv_t1:
		var d = inst.get_definition()
		if d.category == &"UNIT" and inst.definition_id == &"ETnkPla":
			if u1 == null:
				u1 = inst
			elif u2 == null:
				u2 = inst
		elif d.category == &"ITEM":
			if it1 == null:
				it1 = inst
			elif it2 == null and inst.definition_id != it1.definition_id:
				it2 = inst
	if it2 == null:
		for inst in inv_t1:
			if inst.get_definition().category == &"ITEM" and inst != it1:
				it2 = inst
				break

	_assert_ok(is_instance_valid(u1) and is_instance_valid(u2), "Found two starter units")
	_assert_ok(is_instance_valid(it1) and is_instance_valid(it2), "Found two starter items")

	_assert_ok(rs.move_instance(u1.get_location(), LocationIdentifier.new(&"PlayerLineup", 0)), "Move u1 to PlayerLineup:0")
	_assert_ok(rs.move_instance(u2.get_location(), LocationIdentifier.new(&"PlayerLineup", 1)), "Move u2 to PlayerLineup:1")

	# Equip items on hero, u1, and test unequip / swap in RunState
	_assert_ok(rs.equip_item(it1.ball_uuid, hero.ball_uuid, 0), "Equip it1 on hero")
	_assert_ok(rs.equip_item(it1.ball_uuid, hero.ball_uuid, 0), "Self-equip no-op on hero")

	# Move it2 to PlayerShelf:0, swap equipped it1 <-> shelf it2 in BOTH directions
	_assert_ok(rs.move_instance(it2.get_location(), LocationIdentifier.new(&"PlayerShelf", 0)), "Move it2 to PlayerShelf:0")
	var hero_eq_loc := _make_equipped_loc(hero.ball_uuid, 0)
	var shelf0_loc := LocationIdentifier.new(&"PlayerShelf", 0)
	_assert_ok(rs.swap_instances(shelf0_loc, hero_eq_loc), "Swap shelf -> equipped in RunState")
	_assert_ok(hero.equipped_item_uuids[0] == it2.ball_uuid and rs.get_container(&"PlayerShelf").get_uuid(0) == it1.ball_uuid, "Swap 1 verified")
	_assert_ok(rs.swap_instances(hero_eq_loc, shelf0_loc), "Swap equipped -> shelf in RunState")
	_assert_ok(hero.equipped_item_uuids[0] == it1.ball_uuid and rs.get_container(&"PlayerShelf").get_uuid(0) == it2.ball_uuid, "Swap 2 verified")

	var shelf1_loc := LocationIdentifier.new(&"PlayerShelf", 1)
	_assert_ok(rs.move_instance(hero_eq_loc, shelf1_loc), "Unequip hero item to PlayerShelf:1 via move_instance")
	_assert_ok(hero.equipped_item_uuids[0].is_empty() and rs.get_container(&"PlayerShelf").get_uuid(1) == it1.ball_uuid, "Hero item unequipped cleanly")
	_assert_ok(rs.equip_item(it1.ball_uuid, hero.ball_uuid, 0), "Re-equip it1 on hero")
	_assert_ok(rs.equip_item(it2.ball_uuid, u1.ball_uuid, 0), "Equip it2 on u1")

	# Fill PlayerShelf slots
	for slot_i in range(C.SHELF_CAP):
		if rs.get_container(&"PlayerShelf").get_uuid(slot_i).is_empty():
			var dummy := GachaBallInstance.new()
			dummy.initialize(Database.get_definition(&"FFigMec"))
			_assert_ok(rs.add_instance(dummy, &"PlayerShelf", slot_i), "Fill RunState shelf slot %d" % slot_i)

	var extra_inv_item := GachaBallInstance.new()
	extra_inv_item.initialize(Database.get_definition(&"item_t1_a"))
	_assert_ok(rs.add_instance(extra_inv_item, &"RunInventoryT1", -1), "Add extra_inv_item to RunInventoryT1")
	var rejected_full_replace := rs.equip_item(extra_inv_item.ball_uuid, u1.ball_uuid, 0)
	_assert_ok(not rejected_full_replace, "RunState.equip_item from non-shelf must cleanly reject when shelf full")
	_assert_ok(rs._validate_state_consistency(), "RunState consistent after rejected full-shelf equip")
	_assert_ok(u1.equipped_item_uuids[0] == it2.ball_uuid, "u1 still holds it2 after rejected replace")

	# Free shelf slot 0 and equip
	var shelf_item := GachaBallInstance.new()
	shelf_item.initialize(Database.get_definition(&"item_claim_ticket"))
	rs.remove_instance(rs.get_container(&"PlayerShelf").get_uuid(0))
	_assert_ok(rs.add_instance(shelf_item, &"PlayerShelf", 0), "Place shelf_item at PlayerShelf:0")
	_assert_ok(rs.equip_item(shelf_item.ball_uuid, u1.ball_uuid, 0), "Equip from full PlayerShelf onto equipped u1 must succeed")
	_assert_ok(u1.equipped_item_uuids[0] == shelf_item.ball_uuid and it2.location_container_tag == &"PlayerShelf", "Swapped old item into freed shelf slot")

	# Part 2: Battle Setup & Entrance
	var bm = BattleManagerScript.new()
	add_child(bm)
	bm.add_to_group("battle_manager")
	GameManager.register_battle_manager(bm)
	GameManager.is_in_battle = true

	var encounter_def = EncounterGenerator.generate_encounter(1)
	if encounter_def.enemy_placements.size() > 0:
		encounter_def.enemy_placements[0]["equipment"] = [&"item_t1_a", &"item_t1_b"]

	bm._setup_battle(encounter_def)
	_assert_ok(bm._bm_validate_state_consistency(), "BattleState consistent immediately after _setup_battle")
	_assert_ok(not bm._state.staged_hero_placement.is_empty(), "Hero staged before entrance")
	_assert_ok(int(bm._state.staged_hero_placement.get("position", -1)) == 2, "Staged hero remembers slot 2")

	await bm.execute_hero_entrance_sequence()
	_assert_ok(bm._bm_validate_state_consistency(), "BattleState consistent after hero entrance")
	var battle_hero := bm.get_instance_by_location(LocationIdentifier.new(&"PlayerLineup", 2))
	_assert_ok(is_instance_valid(battle_hero) and battle_hero.get_definition().is_hero, "Battle hero at PlayerLineup:2")

	await bm.execute_enemy_entrance_sequence()
	_assert_ok(bm._bm_validate_state_consistency(), "BattleState consistent after enemy entrance")

	# Part 3: Gacha draw & Discard
	bm.add_gacha_tokens(30)
	var draw_count := 0
	while true:
		var evts = bm.bm_draw_gacha_instance(1)
		if evts.is_empty():
			break
		draw_count += 1
		_assert_ok(bm._bm_validate_state_consistency(), "Consistent after draw #%d" % draw_count)

	# Clean up battle manager
	bm.queue_free()
	GameManager.unregister_battle_manager()
	GameManager.is_in_battle = false
	await get_tree().process_frame

# ==============================================================================
# SUITE 3 IMPLEMENTATION (Deterministic Seed Parity)
# ==============================================================================
func _run_suite_3_seed_determinism() -> void:
	const TEST_SEEDS: Array[int] = [101, 2026, 7777, 42424, 99991]

	for seed_val in TEST_SEEDS:
		var test_run_id := "test_deterministic_run_%d" % seed_val

		# Run A
		UUIDUtils._counter = 0
		GameManager.is_in_battle = false
		GameManager.start_run_with_seed(&"hero_bounty_hunter", &"deck_nihongo_starter", "REGULAR", "FULL", seed_val, false, test_run_id)
		var initial_run_dict: Dictionary = GameManager.run_state.to_save_dict()
		var initial_uuid_state: Dictionary = UUIDUtils.serialize_state()
		var bm_a = BattleManagerScript.new()
		add_child(bm_a)
		bm_a.add_to_group("battle_manager")
		GameManager.register_battle_manager(bm_a)
		GameManager.is_in_battle = true

		var enc_a = EncounterGenerator.generate_encounter(1)
		bm_a._setup_battle(enc_a)
		await bm_a.execute_hero_entrance_sequence()
		await bm_a.execute_enemy_entrance_sequence()

		var all_events_a: Array[CombatEvent] = []
		for turn_idx in range(2):
			if bm_a._is_battle_over(): break
			bm_a._state.clear_turn_data()
			bm_a._populate_actor_queue()
			var turn_events: Array[CombatEvent] = []
			var death_tracking: Dictionary = {}
			var safety := 0
			while not bm_a._actor_queue.is_empty() and safety < 30:
				safety += 1
				var actor: GachaBallInstance = bm_a._actor_queue.pop_front()
				if not is_instance_valid(actor) or actor.current_hp <= 0: continue
				if actor.location_container_tag != C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP and actor.location_container_tag != C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP: continue
				var basic_ab = bm_a.get_basic_attack_for(actor)
				if is_instance_valid(basic_ab) and not basic_ab.effects.is_empty():
					var targets = bm_a.resolve_target(actor.ball_uuid, basic_ab.effects[0].target_type, TriggerContext.new())
					var req := EffectRequest.new(actor.ball_uuid, basic_ab.id, basic_ab.effects[0], targets, TriggerContext.new(), C.SubPhase.STANDARD)
					bm_a.enqueue_effect_request(req)
					turn_events.append_array(bm_a._combat.process_reaction_queue(bm_a, death_tracking))
					KnockoutProcessor.check_for_knockouts_with_counter_delay(true, turn_events, death_tracking, bm_a)
					KnockoutProcessor.process_completed_counter_knockouts(turn_events, death_tracking, bm_a)
			bm_a._finalize_deaths()
			all_events_a.append_array(turn_events)

		var snap_a: Dictionary = GameManager.get_replay_state_snapshot()
		var digest_a: String = ReplayStateDigest.digest(snap_a)
		_assert_ok(bm_a._state.validate_state_consistency(), "Run A state consistency for seed %d" % seed_val)
		bm_a.queue_free()
		GameManager.unregister_battle_manager()
		GameManager.is_in_battle = false
		await get_tree().process_frame

		# Run B (Identical seed and run ID, restoring setup objects from Run A to eliminate wall-clock second boundary)
		GameManager.is_in_battle = false
		RNGManager.initialize(seed_val)
		UUIDUtils.restore_state(initial_uuid_state, test_run_id)
		GameManager.run_state = RunState.new()
		GameManager.run_state.from_save_dict(initial_run_dict)
		GameManager.reset_gacha_discounts()
		var bm_b = BattleManagerScript.new()
		add_child(bm_b)
		bm_b.add_to_group("battle_manager")
		GameManager.register_battle_manager(bm_b)
		GameManager.is_in_battle = true

		var enc_b = EncounterGenerator.generate_encounter(1)
		bm_b._setup_battle(enc_b)
		await bm_b.execute_hero_entrance_sequence()
		await bm_b.execute_enemy_entrance_sequence()

		var all_events_b: Array[CombatEvent] = []
		for turn_idx in range(2):
			if bm_b._is_battle_over(): break
			bm_b._state.clear_turn_data()
			bm_b._populate_actor_queue()
			var turn_events: Array[CombatEvent] = []
			var death_tracking: Dictionary = {}
			var safety := 0
			while not bm_b._actor_queue.is_empty() and safety < 30:
				safety += 1
				var actor: GachaBallInstance = bm_b._actor_queue.pop_front()
				if not is_instance_valid(actor) or actor.current_hp <= 0: continue
				if actor.location_container_tag != C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP and actor.location_container_tag != C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP: continue
				var basic_ab = bm_b.get_basic_attack_for(actor)
				if is_instance_valid(basic_ab) and not basic_ab.effects.is_empty():
					var targets = bm_b.resolve_target(actor.ball_uuid, basic_ab.effects[0].target_type, TriggerContext.new())
					var req := EffectRequest.new(actor.ball_uuid, basic_ab.id, basic_ab.effects[0], targets, TriggerContext.new(), C.SubPhase.STANDARD)
					bm_b.enqueue_effect_request(req)
					turn_events.append_array(bm_b._combat.process_reaction_queue(bm_b, death_tracking))
					KnockoutProcessor.check_for_knockouts_with_counter_delay(true, turn_events, death_tracking, bm_b)
					KnockoutProcessor.process_completed_counter_knockouts(turn_events, death_tracking, bm_b)
			bm_b._finalize_deaths()
			all_events_b.append_array(turn_events)

		var snap_b: Dictionary = GameManager.get_replay_state_snapshot()
		var digest_b: String = ReplayStateDigest.digest(snap_b)
		_assert_ok(bm_b._state.validate_state_consistency(), "Run B state consistency for seed %d" % seed_val)
		bm_b.queue_free()
		GameManager.unregister_battle_manager()
		GameManager.is_in_battle = false
		await get_tree().process_frame

		if digest_a != digest_b:
			for k in snap_a.keys():
				var dig_ak = ReplayStateDigest.digest(snap_a[k])
				var dig_bk = ReplayStateDigest.digest(snap_b.get(k))
				if dig_ak != dig_bk:
					print("  [DIFF seed %d] Sub-key '%s' mismatch! A: %s vs B: %s" % [seed_val, k, dig_ak, dig_bk])

		_assert_ok(not digest_a.is_empty(), "Digest A must not be empty for seed %d" % seed_val)
		_assert_ok(digest_a == digest_b, "Deterministic digest mismatch for seed %d! A: %s vs B: %s" % [seed_val, digest_a, digest_b])
		_assert_ok(all_events_a.size() == all_events_b.size(), "CombatEvent count mismatch for seed %d: %d vs %d" % [seed_val, all_events_a.size(), all_events_b.size()])
		var check_limit: int = mini(all_events_a.size(), all_events_b.size())
		for ev_idx in range(check_limit):
			_assert_ok(all_events_a[ev_idx].type == all_events_b[ev_idx].type, "CombatEvent type mismatch at %d for seed %d: %s vs %s" % [ev_idx, seed_val, all_events_a[ev_idx].type, all_events_b[ev_idx].type])

# ==============================================================================
# SUITE 4 IMPLEMENTATION (RunState Save/Load Roundtrip Consistency)
# ==============================================================================
func _run_suite_4_save_load() -> void:
	GameManager.is_in_battle = false
	GameManager.start_run_with_seed(&"hero_bounty_hunter", &"deck_nihongo_starter")
	var rs: RunState = GameManager.run_state
	rs.gold = 42
	rs.day = 3

	var saved: Dictionary = rs.to_save_dict()
	var restored_rs: RunState = RunState.new()
	restored_rs.from_save_dict(saved)

	_assert_ok(restored_rs._validate_state_consistency(), "Restored RunState consistency")
	_assert_ok(restored_rs.gold == rs.gold, "Gold parity")
	_assert_ok(restored_rs.day == rs.day, "Day parity")

	_assert_ok(rs.active_hero_set == Database.SET_MERCENARY, "hero_bounty_hunter sets active_hero_set to MERCENARY")
	_assert_ok(restored_rs.active_hero_set == Database.SET_MERCENARY, "active_hero_set saved and restored correctly")

	var novice_rs := RunState.new()
	novice_rs.initialize_run(&"hero_starter", &"deck_nihongo_starter")
	_assert_ok(novice_rs.active_hero_set == Database.SET_NOVICE, "hero_starter sets active_hero_set to NOVICE")

	# Legacy save file healing: when active_hero_set in save is BASE but hero is Dan
	var legacy_save: Dictionary = novice_rs.to_save_dict()
	legacy_save["active_hero_set"] = "BASE"
	var healed_rs := RunState.new()
	healed_rs.from_save_dict(legacy_save)
	_assert_ok(healed_rs.get_active_hero_set() == Database.SET_NOVICE, "Legacy save with Dan is healed to SET_NOVICE")
	_assert_ok(healed_rs.active_hero_set == Database.SET_NOVICE, "active_hero_set field healed to SET_NOVICE")

	# Test EffectHandlers.handle_summon_unit for Novice unit under Dan
	var old_gm_rs = GameManager.run_state
	GameManager.run_state = healed_rs
	var dummy_bm = BattleManagerScript.new()
	var summon_request_data := {
		"summon_unit_id": &"F?NovApp",
		"holder_uuid": "dummy_holder",
		"holder_location": LocationIdentifier.new(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 1),
		"is_resurrection": false
	}
	var dummy_req := EffectRequest.new("dummy_holder", &"test_summon", null, [], TriggerContext.new())
	var s_res := EffectHandlers.handle_summon_unit(dummy_req, summon_request_data, dummy_bm)
	_assert_ok(not s_res.new_instances.is_empty(), "EffectHandlers summons F?NovApp cleanly under Dan")
	_assert_ok(s_res.new_instances[0].definition_id == &"F?NovApp", "Summoned instance is F?NovApp")
	dummy_bm.free()
	GameManager.run_state = old_gm_rs

	var avenger_rs := RunState.new()
	avenger_rs.initialize_run(&"hero_avenger", &"deck_nihongo_starter")
	_assert_ok(avenger_rs.active_hero_set == Database.SET_BASE, "hero_avenger sets active_hero_set to BASE")

	for cname in [&"PlayerLineup", &"PlayerShelf", &"PlayerTrinkets"]:
		var orig_uuids = rs.get_container(cname).get_all_uuids()
		var rest_uuids = restored_rs.get_container(cname).get_all_uuids()
		_assert_ok(orig_uuids == rest_uuids, "Container %s UUID parity mismatch" % String(cname))

# ==============================================================================
# SUITE 5 IMPLEMENTATION (Constitutional SubPhase & Knockout Invariants)
# ==============================================================================
func _run_suite_5_constitutional_invariants() -> void:
	_test_subphase_three_layer_sorting()
	await _test_prevent_knockout_blocks_knockout_chain()
	await _test_knockout_subphase_cascade_order()
	await _test_registered_knockout_consolidation()
	await _test_multi_casualty_shockwave_soul_echo_causality()

func _test_subphase_three_layer_sorting() -> void:
	var crr = CausalReactionResolver.new()
	var dummy_ctx = TriggerContext.new()

	var r_extra = EffectRequest.new("u1", &"extra", null, [], dummy_ctx, C.SubPhase.GRANT_EXTRA_ACTION)
	var r_standard_item = EffectRequest.new("u1", &"std_item", null, [], dummy_ctx, C.SubPhase.STANDARD, &"ITEM", true, 0, 1)
	var r_standard_unit = EffectRequest.new("u1", &"std_unit", null, [], dummy_ctx, C.SubPhase.STANDARD, &"UNIT", true, 0, 0)
	var r_standard_enemy = EffectRequest.new("e1", &"std_enemy", null, [], dummy_ctx, C.SubPhase.STANDARD, &"UNIT", false, 0, 0)
	var r_sum_item = EffectRequest.new("u1", &"sum_item", null, [], dummy_ctx, C.SubPhase.KNOCKOUT_SUMMON_ITEM)
	var r_sum_unit = EffectRequest.new("u1", &"sum_unit", null, [], dummy_ctx, C.SubPhase.KNOCKOUT_SUMMON_UNIT)
	var r_sum_trinket = EffectRequest.new("u1", &"sum_trinket", null, [], dummy_ctx, C.SubPhase.KNOCKOUT_SUMMON_TRINKET)
	var r_pre_ko = EffectRequest.new("u1", &"pre_ko", null, [], dummy_ctx, C.SubPhase.PRE_KNOCKOUT)
	var r_item_xfer = EffectRequest.new("u1", &"item_xfer", null, [], dummy_ctx, C.SubPhase.ITEM_TRANSFER)
	var r_prevent = EffectRequest.new("u1", &"prevent", null, [], dummy_ctx, C.SubPhase.PREVENT_KNOCKOUT_CHECK)
	var r_stat_pass = EffectRequest.new("u1", &"stat_pass", null, [], dummy_ctx, C.SubPhase.KNOCKOUT_STAT_PASS)
	var r_intercept = EffectRequest.new("u1", &"intercept", null, [], dummy_ctx, C.SubPhase.PRE_DAMAGE_INTERCEPT)

	crr.enqueue(r_extra)
	crr.enqueue(r_standard_enemy)
	crr.enqueue(r_standard_item)
	crr.enqueue(r_pre_ko)
	crr.enqueue(r_intercept)
	crr.enqueue(r_sum_item)
	crr.enqueue(r_prevent)
	crr.enqueue(r_stat_pass)
	crr.enqueue(r_standard_unit)
	crr.enqueue(r_item_xfer)
	crr.enqueue(r_sum_trinket)
	crr.enqueue(r_sum_unit)

	crr.sort_pending()

	var sorted = crr.drain_all()
	_assert_ok(sorted.size() == 12, "All 12 requests drained from CRR")
	_assert_ok(sorted[0].sub_phase == C.SubPhase.PRE_DAMAGE_INTERCEPT, "Order 0: PRE_DAMAGE_INTERCEPT")
	_assert_ok(sorted[1].sub_phase == C.SubPhase.KNOCKOUT_STAT_PASS, "Order 1: KNOCKOUT_STAT_PASS")
	_assert_ok(sorted[2].sub_phase == C.SubPhase.PREVENT_KNOCKOUT_CHECK, "Order 2: PREVENT_KNOCKOUT_CHECK")
	_assert_ok(sorted[3].sub_phase == C.SubPhase.ITEM_TRANSFER, "Order 3: ITEM_TRANSFER")
	_assert_ok(sorted[4].sub_phase == C.SubPhase.PRE_KNOCKOUT, "Order 4: PRE_KNOCKOUT")
	_assert_ok(sorted[5].sub_phase == C.SubPhase.KNOCKOUT_SUMMON_TRINKET, "Order 5: KNOCKOUT_SUMMON_TRINKET")
	_assert_ok(sorted[6].sub_phase == C.SubPhase.KNOCKOUT_SUMMON_UNIT, "Order 6: KNOCKOUT_SUMMON_UNIT")
	_assert_ok(sorted[7].sub_phase == C.SubPhase.KNOCKOUT_SUMMON_ITEM, "Order 7: KNOCKOUT_SUMMON_ITEM")
	_assert_ok(sorted[8] == r_standard_unit, "Order 8: Standard Player UNIT")
	_assert_ok(sorted[9] == r_standard_enemy, "Order 9: Standard Enemy UNIT")
	_assert_ok(sorted[10] == r_standard_item, "Order 10: Standard Player ITEM")
	_assert_ok(sorted[11].sub_phase == C.SubPhase.GRANT_EXTRA_ACTION, "Order 11: GRANT_EXTRA_ACTION")

func _test_prevent_knockout_blocks_knockout_chain() -> void:
	var bm = BattleManagerScript.new()
	add_child(bm)
	bm.add_to_group("battle_manager")
	GameManager.register_battle_manager(bm)
	GameManager.is_in_battle = true

	var enc = EncounterGenerator.generate_encounter(1)
	bm._setup_battle(enc)
	await bm.execute_hero_entrance_sequence()
	await bm.execute_enemy_entrance_sequence()

	# Add trinket_aegis to PlayerTrinkets via register_test_trinket
	var aegis = bm.register_test_trinket(&"trinket_aegis", false)
	_assert_ok(is_instance_valid(aegis), "Registered trinket_aegis on player team")

	var player_units = bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	_assert_ok(not player_units.is_empty(), "Found player unit for Aegis test")
	var target_unit: GachaBallInstance = player_units[0]
	target_unit.current_hp = 10

	var enemy_units = bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	_assert_ok(not enemy_units.is_empty(), "Found enemy unit for Aegis test")
	var enemy_unit: GachaBallInstance = enemy_units[0]

	var turn_events: Array[CombatEvent] = []
	var death_tracking: Dictionary = {}

	# Apply fatal damage (20 damage > 10 HP)
	bm.apply_damage(target_unit, 20, C.DamageType.MELEE, enemy_unit.ball_uuid)
	_assert_ok(target_unit.current_hp <= 0, "Target unit current_hp <= 0 before Aegis resolution")

	# Trigger on_hurt reactions
	bm.trigger_on_hurt(target_unit.ball_uuid, 20, enemy_unit.ball_uuid, C.CAUSE_ATTACK)

	# Process reactions
	var reaction_evts = bm._combat.process_reaction_queue(bm, death_tracking)
	turn_events.append_array(reaction_evts)

	# Knockout check
	KnockoutProcessor.check_for_knockouts_with_counter_delay(true, turn_events, death_tracking, bm)
	KnockoutProcessor.process_completed_counter_knockouts(turn_events, death_tracking, bm)

	_assert_ok(target_unit.current_hp == 1, "Aegis Charm saved unit to 1 HP")
	_assert_ok(target_unit.location_container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, "Saved unit stays in PlayerLineup")
	_assert_ok(not KnockoutProcessor.is_knocked_out_this_turn(bm._state, target_unit.ball_uuid), "Unit not registered as knocked out")

	var has_prevent_evt := false
	var has_ko_evt := false
	for ev in turn_events:
		if ev.type == CombatEvent.Type.PREVENT_KNOCKOUT:
			has_prevent_evt = true
		if ev.type == CombatEvent.Type.KNOCKOUT and ev.target_uuids.has(target_unit.ball_uuid):
			has_ko_evt = true
	_assert_ok(has_prevent_evt, "CombatEvent.Type.PREVENT_KNOCKOUT emitted")
	_assert_ok(not has_ko_evt, "CombatEvent.Type.KNOCKOUT NOT emitted for saved unit")

	bm.queue_free()
	GameManager.unregister_battle_manager()
	GameManager.is_in_battle = false
	await get_tree().process_frame

func _test_knockout_subphase_cascade_order() -> void:
	var bm = BattleManagerScript.new()
	add_child(bm)
	bm.add_to_group("battle_manager")
	GameManager.register_battle_manager(bm)
	GameManager.is_in_battle = true

	var enc = EncounterGenerator.generate_encounter(1)
	bm._setup_battle(enc)
	await bm.execute_hero_entrance_sequence()
	await bm.execute_enemy_entrance_sequence()

	# Equip item_t3_e (Death's Bargain) on player unit at lineup 0
	var player_units = bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var dying_unit: GachaBallInstance = player_units[0]
	dying_unit.current_hp = 5

	var death_bargain = bm.register_test_item_on_unit(&"item_t3_e", dying_unit.ball_uuid)
	_assert_ok(is_instance_valid(death_bargain), "Equipped item_t3_e on dying unit")

	var enemy_units = bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	var enemy_unit: GachaBallInstance = enemy_units[0]
	enemy_unit.current_hp = 20

	var turn_events: Array[CombatEvent] = []
	var death_tracking: Dictionary = {}

	# Deal fatal damage
	bm.apply_damage(dying_unit, 10, C.DamageType.MELEE, enemy_unit.ball_uuid)
	_assert_ok(dying_unit.current_hp <= 0, "Dying unit current_hp <= 0")

	# Execute knockout processor cascade
	KnockoutProcessor.check_for_knockouts_with_counter_delay(true, turn_events, death_tracking, bm)
	KnockoutProcessor.process_completed_counter_knockouts(turn_events, death_tracking, bm)

	# Assertions:
	# 1. PreKnockoutAttackCommand emitted PRE_KNOCKOUT_ATTACK event
	var has_pre_ko_attack := false
	var has_redundant_ko_evt := false
	for ev in turn_events:
		if ev.type == CombatEvent.Type.PRE_KNOCKOUT_ATTACK:
			has_pre_ko_attack = true
		if ev.type == CombatEvent.Type.KNOCKOUT and ev.target_uuids.has(dying_unit.ball_uuid):
			has_redundant_ko_evt = true

	_assert_ok(has_pre_ko_attack, "PreKnockoutAttackCommand emitted PRE_KNOCKOUT_ATTACK")
	_assert_ok(not has_redundant_ko_evt, "Suppressed redundant KNOCKOUT event for PRE_KNOCKOUT_ATTACK unit")
	_assert_ok(KnockoutProcessor.is_knocked_out_this_turn(bm._state, dying_unit.ball_uuid), "Dying unit is marked knocked out this turn")

	# Clean up and check consistency
	bm._finalize_deaths()
	_assert_ok(bm._bm_validate_state_consistency(), "BattleState consistent after knockout cleanup")

	bm.queue_free()
	GameManager.unregister_battle_manager()
	GameManager.is_in_battle = false
	await get_tree().process_frame

func _test_registered_knockout_consolidation() -> void:
	var bm = BattleManagerScript.new()
	add_child(bm)
	bm.add_to_group("battle_manager")
	GameManager.register_battle_manager(bm)
	GameManager.is_in_battle = true

	var enc = EncounterGenerator.generate_encounter(1)
	bm._setup_battle(enc)
	await bm.execute_hero_entrance_sequence()
	await bm.execute_enemy_entrance_sequence()

	var player_units = bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var unit: GachaBallInstance = null
	for u in player_units:
		if is_instance_valid(u) and not u.get_definition().is_hero:
			unit = u
			break
	if unit == null:
		unit = bm.register_test_unit(&"ASpeFod", false)

	_assert_ok(is_instance_valid(unit), "Found non-hero player unit for knockout consolidation")
	unit.current_hp = 1
	var expected_uuid = unit.ball_uuid

	var all_events: Array[CombatEvent] = []
	var knockout_tracking: Dictionary = {}

	# Run consolidated knockout processing for status-effect KOs such as Burn.
	KnockoutProcessor.process_registered_knockout(unit, &"END_OF_TURN", "PLAYER", all_events, knockout_tracking, bm)

	_assert_ok(KnockoutProcessor.is_knocked_out_this_turn(bm._state, expected_uuid), "is_knocked_out_this_turn is true")
	_assert_ok(knockout_tracking.has(expected_uuid), "knockout_tracking contains unit UUID")

	var ko_info = KnockoutProcessor.get_knockout_info(bm._state, expected_uuid)
	_assert_ok(ko_info.get("died_in_phase") == &"END_OF_TURN", "Knockout phase recorded correctly")
	_assert_ok(ko_info.get("team") == "PLAYER", "Knockout team recorded correctly")

	var has_ko_evt := false
	for ev in all_events:
		if ev.type == CombatEvent.Type.KNOCKOUT and ev.target_uuids.has(expected_uuid):
			has_ko_evt = true
	_assert_ok(has_ko_evt, "KNOCKOUT event created in consolidated processor")

	_assert_ok(bm._turn_metadata.has("first_killed_player_unit"), "First killed player unit recorded in turn metadata")
	var first_killed: Dictionary = bm._turn_metadata.get("first_killed_player_unit", {})
	_assert_ok(first_killed.get("uuid") == expected_uuid, "First killed player unit UUID matches")

	_assert_ok(bm._bm_validate_state_consistency(), "BattleState consistent after consolidated knockout")

	bm.queue_free()
	GameManager.unregister_battle_manager()
	GameManager.is_in_battle = false
	await get_tree().process_frame

func _test_multi_casualty_shockwave_soul_echo_causality() -> void:
	var bm = BattleManagerScript.new()
	add_child(bm)
	bm.add_to_group("battle_manager")
	GameManager.register_battle_manager(bm)
	GameManager.is_in_battle = true

	var enc = EncounterGenerator.generate_encounter(1)
	bm._setup_battle(enc)
	await bm.execute_hero_entrance_sequence()
	await bm.execute_enemy_entrance_sequence()

	# Clear existing player lineup except Slot 0 (Hero) so we can place exact test units in Slots 4, 3, 2
	var p_lineup = bm.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	for slot_idx in range(1, 5):
		var old_uuid: String = p_lineup.get_uuid(slot_idx)
		if not old_uuid.is_empty():
			bm._state.bm_remove_instance(old_uuid)

	# Register Soul Echo trinket on Player team
	var soul_echo = bm.register_test_trinket(&"trinket_soul_echo", false)
	_assert_ok(is_instance_valid(soul_echo), "Registered trinket_soul_echo on player team")

	# Place frontmost casualty in Player Slot 4: Vulcannon (FFigMec), which has CounterOnHurt (execute_before_knockout == true)
	var front_unit := GachaBallInstance.new()
	var front_def: GachaBallDefinition = Database.units.get(&"FFigMec")
	front_unit.initialize(front_def)
	front_unit.current_hp = 1
	bm._state.bm_add_instance(front_unit, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 4)

	# Place second casualty in Player Slot 3: ?NovPla (grants timer bonus on death at SubPhase 200)
	var second_unit := GachaBallInstance.new()
	var second_def: GachaBallDefinition = Database.units.get(&"?NovPla")
	second_unit.initialize(second_def)
	second_unit.current_hp = 1
	bm._state.bm_add_instance(second_unit, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 3)

	var enemy_units = bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	_assert_ok(not enemy_units.is_empty(), "Found enemy unit for Shockwave causality test")
	var attacker: GachaBallInstance = enemy_units[0]
	attacker.current_hp = 30

	# Build a Shockwave cascade hitting Player lineup front-to-back (Slot 4 first, then Slot 3)
	var cascade_items: Array[EffectResult.CascadeRequestItem] = [
		EffectResult.CascadeRequestItem.new(front_unit.ball_uuid, 5, false),
		EffectResult.CascadeRequestItem.new(second_unit.ball_uuid, 5, true)
	]
	var cascade_req := EffectResult.CascadeRequest.new(C.DamageType.MELEE, cascade_items)
	var req := EffectRequest.new(attacker.ball_uuid, &"ability_shockwave", null, [front_unit.ball_uuid, second_unit.ball_uuid], TriggerContext.new(), C.SubPhase.STANDARD)
	var cmd := CascadeCommand.new(req, bm._combat, bm, cascade_req)

	var turn_events: Array[CombatEvent] = []
	var death_tracking: Dictionary = {}
	cmd.execute(turn_events, death_tracking)
	KnockoutProcessor.process_completed_counter_knockouts(turn_events, death_tracking, bm)

	# 1. Chronological lethal sequence: Slot 4 took lethal damage before Slot 3
	var seq_front: int = bm._state.get_lethal_sequence(front_unit.ball_uuid)
	var seq_second: int = bm._state.get_lethal_sequence(second_unit.ball_uuid)
	_assert_ok(seq_front < seq_second, "Front unit (Slot 4) recorded earlier lethal sequence than second unit (Slot 3): %d < %d" % [seq_front, seq_second])

	# 2. First killed player unit MUST be the front unit (Slot 4), NOT the second unit (Slot 3)
	var first_killed: Dictionary = bm._turn_metadata.get("first_killed_player_unit", {})
	_assert_ok(first_killed.get("uuid", "") == front_unit.ball_uuid, "first_killed_player_unit is front unit (Slot 4)")

	# 3. Soul Echo resurrected a new FFigMec into Slot 4
	var slot4_uuid_after: String = p_lineup.get_uuid(4)
	var slot4_inst_after: GachaBallInstance = bm.get_instance_by_uuid(slot4_uuid_after)
	_assert_ok(is_instance_valid(slot4_inst_after) and slot4_uuid_after != front_unit.ball_uuid, "Soul Echo summoned replacement instance into Slot 4")
	_assert_ok(is_instance_valid(slot4_inst_after) and slot4_inst_after.definition_id == &"FFigMec" and slot4_inst_after.current_hp > 0, "Resurrected unit in Slot 4 is living FFigMec")

	# 4. Event stream causality:
	#    Front unit KNOCKOUT -> Soul Echo SUMMON -> Second unit KNOCKOUT -> Second unit TIMER_BONUS
	var front_ko_idx := -1
	var soul_echo_summon_idx := -1
	var second_ko_idx := -1
	var second_timer_idx := -1
	for i in range(turn_events.size()):
		var ev: CombatEvent = turn_events[i]
		if ev.type == CombatEvent.Type.KNOCKOUT and ev.target_uuids.has(front_unit.ball_uuid):
			front_ko_idx = i
		elif ev.type == CombatEvent.Type.SUMMON and ev.visual_payload != null and ev.visual_payload.new_unit_uuid == slot4_uuid_after:
			soul_echo_summon_idx = i
		elif ev.type == CombatEvent.Type.KNOCKOUT and ev.target_uuids.has(second_unit.ball_uuid):
			second_ko_idx = i
		elif ev.type == CombatEvent.Type.TIMER_BONUS and ev.source_uuid == second_unit.ball_uuid:
			second_timer_idx = i

	_assert_ok(front_ko_idx != -1, "Emitted KNOCKOUT event for front unit (Slot 4)")
	_assert_ok(soul_echo_summon_idx != -1, "Emitted SUMMON event for Soul Echo resurrection")
	_assert_ok(second_ko_idx != -1, "Emitted KNOCKOUT event for second unit (Slot 3)")
	_assert_ok(second_timer_idx != -1, "Emitted TIMER_BONUS event for second unit (Slot 3)")
	_assert_ok(front_ko_idx < soul_echo_summon_idx, "Front unit KNOCKOUT (%d) occurs before Soul Echo SUMMON (%d)" % [front_ko_idx, soul_echo_summon_idx])
	_assert_ok(soul_echo_summon_idx < second_ko_idx, "Soul Echo SUMMON (%d) resolves completely before second unit KNOCKOUT (%d)" % [soul_echo_summon_idx, second_ko_idx])
	_assert_ok(second_ko_idx < second_timer_idx, "Second unit KNOCKOUT (%d) occurs before second unit post-death TIMER_BONUS (%d)" % [second_ko_idx, second_timer_idx])

	bm._finalize_deaths()
	_assert_ok(bm._bm_validate_state_consistency(), "BattleState consistent after multi-casualty Shockwave + Soul Echo")

	bm.queue_free()
	GameManager.unregister_battle_manager()
	GameManager.is_in_battle = false
	await get_tree().process_frame

func _run_suite_6_phase2_content() -> void:
	_test_status_effect_visual_sources()

	var status_phases: Dictionary = {
		&"burn": "END_OF_TURN",
		&"armor": "START_OF_TURN",
		&"spikes": "NONE",
		&"static": "END_OF_TURN",
		&"bounty": "START_OF_TURN",
		&"reinforce": "START_OF_TURN"
	}
	var status_effects: Dictionary = {
		&"burn": "DAMAGE",
		&"armor": "NONE",
		&"spikes": "NONE",
		&"static": "NONE",
		&"bounty": "NONE",
		&"reinforce": "NONE"
	}
	var status_decay_modes: Dictionary = {
		&"burn": "HALVE",
		&"armor": "CLEAR",
		&"spikes": "NONE",
		&"static": "DECREMENT",
		&"bounty": "DECREMENT",
		&"reinforce": "DECREMENT"
	}
	for status_id in status_phases:
		var status_definition: CombatEffectDefinition = CombatEffectRegistry.get_definition(status_id)
		assert(status_definition != null, "Phase 2 status %s must be registered" % status_id)
		_assert_ok(status_definition.id == status_id, "Phase 2 status ID %s is registered" % status_id)
		_assert_ok(status_definition.turn_phase == status_phases[status_id], "Phase 2 status %s turn phase" % status_id)
		_assert_ok(status_definition.turn_effect == status_effects[status_id], "Phase 2 status %s turn effect" % status_id)
		_assert_ok(status_definition.decay_mode == status_decay_modes[status_id], "Phase 2 status %s decay mode" % status_id)
		if status_id in [&"static", &"bounty", &"reinforce"]:
			_assert_ok(status_definition.decay_amount == 1, "Phase 2 status %s decrements one stack" % status_id)

	var elemental_traits: Array[String] = ["fire", "earth", "water", "air"]
	var other_traits: Array[String] = ["tank", "fighter", "support", "specialist", "mercenary", "food", "mecha", "animal", "plant", "toy", "appliance", "costume"]
	TranslationServer.set_locale("en")
	for trait_name in elemental_traits + other_traits:
		var crest_id := StringName("trinket_trait_" + trait_name)
		var crest: TrinketDefinition = Database.trinkets[crest_id]
		var expected_linked_trait := StringName(trait_name.to_upper())
		var crest_description: String = TranslationServer.translate(crest.description_key)
		var thresholds := "3, 6, 12, 20, and 32" if trait_name in elemental_traits else "2, 3, 4, and 5"
		_assert_ok(crest.linked_trait_id == expected_linked_trait, "%s links to its trait" % crest_id)
		_assert_ok(not crest.ability_definitions.is_empty(), "%s has trait abilities" % crest_id)
		_assert_ok(crest_description.contains(thresholds), "%s documents thresholds %s" % [crest_id, thresholds])

	var trait_insignia_traits: Array[String] = ["tank", "fighter", "support", "specialist", "mercenary", "food", "mecha", "animal", "plant", "toy", "appliance", "costume", "fire", "earth", "water", "air"]
	for trait_name in trait_insignia_traits:
		var insignia_id := StringName("trinket_" + trait_name + "_insignia")
		var insignia: TrinketDefinition = Database.trinkets[insignia_id]
		_assert_ok(insignia.ability_definitions.size() == 4, "%s covers draw, summon, merge, and battle start" % insignia_id)
		_assert_ok(insignia.is_player_exclusive == (trait_name == "mercenary"), "%s has the expected encounter eligibility" % insignia_id)
		for insignia_ability: AbilityDefinition in insignia.ability_definitions:
			var insignia_effect: EffectDefinition = insignia_ability.effects[0]
			_assert_ok(int(insignia_effect.parameters.get("hp_amount", 0)) == 1, "%s grants +1 HP" % insignia_id)
			_assert_ok(int(insignia_effect.parameters.get("pwr_amount", 0)) == 1, "%s grants +1 PWR" % insignia_id)
			_assert_ok(insignia_effect.parameters.get("target_trait") == trait_name.to_upper(), "%s targets its matching trait" % insignia_id)
	_assert_ok(Database.trinkets[&"trinket_mercenary_insignia"].icon != null, "Mercenary Insignia has its ribboned badge icon")
	_assert_ok(TranslationServer.translate("trinket.mercenary_insignia.name") == "Mercenary Insignia", "Mercenary Insignia EN name")
	TranslationServer.set_locale("pt_BR")
	_assert_ok(TranslationServer.translate("trinket.mercenary_insignia.name") == "Insígnia do Mercenário", "Mercenary Insignia PT-BR name")

	var enemy_pools: Dictionary = EncounterGenerator._create_resource_pools(true)
	for trinket_value in enemy_pools["trinkets"]:
		var trinket: TrinketDefinition = trinket_value
		_assert_ok(not trinket.is_player_exclusive, "Player-only trinket %s is excluded from enemy pools" % trinket.id)
	_assert_ok(Database.trinkets[&"trinket_trait_specialist"].is_player_exclusive, "Specialist Crest is player-only because enemies have no tokens, Gold, draws, or shelf")
	_assert_ok(Database.trinkets[&"trinket_trait_mercenary"].is_player_exclusive, "Mercenary Crest is player-only")

	var polished_plate: TrinketDefinition = Database.trinkets[&"trinket_polished_plate"]
	var plate_ability: AbilityDefinition = polished_plate.ability_definitions[0]
	var plate_effect: EffectDefinition = plate_ability.effects[0]
	_assert_ok(plate_ability.trigger == C.TRIGGER_PRE_COMBAT, "Polished Plate triggers at Pre-Battle")
	_assert_ok(plate_effect.target_type == C.TARGET_ALL_ALLIES, "Polished Plate targets all allies")
	_assert_ok(plate_effect.parameters.get("status_id") == "reinforce", "Polished Plate grants Reinforce")
	_assert_ok(int(plate_effect.parameters.get("amount", 0)) == 1, "Polished Plate grants one Reinforce stack")

	var rusty_ring: TrinketDefinition = Database.trinkets[&"trinket_rusty_ring"]
	var ring_triggers: Array[StringName] = []
	for ability: AbilityDefinition in rusty_ring.ability_definitions:
		ring_triggers.append(ability.trigger)
	for expected_trigger in [&"on_enter_board", &"when_ally_summoned", &"at_battle_start", &"on_board_state_changed", &"on_merge"]:
		_assert_ok(ring_triggers.has(expected_trigger), "Rusty Ring listens for %s" % expected_trigger)

	var aegis: TrinketDefinition = Database.trinkets[&"trinket_aegis"]
	var aegis_ability: AbilityDefinition = aegis.ability_definitions[0]
	_assert_ok(aegis_ability.trigger == &"when_taking_damage", "Aegis observes lethal damage")
	_assert_ok(aegis_ability.effects[0].get_script() == preload("res://scripts/EffectPreventLethal.gd"), "Aegis uses the non-heal lethal save")

	var recruiting_charm: TrinketDefinition = Database.trinkets[&"trinket_recruiting_charm"]
	var recruiting_ability: AbilityDefinition = recruiting_charm.ability_definitions[0]
	_assert_ok(recruiting_charm.is_player_exclusive, "Recruiting Charm is player-only")
	_assert_ok(recruiting_ability.trigger == C.TRIGGER_AT_TURN_START, "Recruiting Charm triggers at turn start")
	_assert_ok(recruiting_ability.effects[0].get_script() == preload("res://scripts/effects/EffectRecruitingCharm.gd"), "Recruiting Charm uses the recruitment effect")

	var approved_item_names: Dictionary = {
		&"consumable_potion_plunder": ["Plunder", "Saque"],
		&"item_claim_ticket": ["Claim Ticket", "Bilhete de Reivindicação"],
		&"item_potion_heroism": ["Battery", "Bateria"],
		&"item_potion_spikes": ["Cactus Juice", "Suco de Cacto"],
		&"item_potion_t1": ["Apple", "Maçã"],
		&"item_interest_ledger": ["Piggy Bank", "Cofrinho"],
		&"item_loaded_contract": ["Loaded Contract", "Contrato Viciado"],
		&"item_t1_a": ["Candy", "Doce"],
		&"item_t1_b": ["Wakizashi", "Wakizashi"],
		&"item_t2_b": ["Scythe", "Foice"],
		&"item_t2_c": ["Anvil", "Bigorna"],
		&"item_t2_d": ["Slime Cell", "Célula de Slime"],
		&"item_t3_a": ["Ramune", "Ramune"],
		&"item_t3_b": ["HardCandy", "Bala Dura"],
		&"item_t3_c": ["Leech Gumi", "Goma Sanguessuga"],
		&"item_t3_d": ["Rubber Ball", "Bola de Borracha"],
		&"item_t3_e": ["Sour Candy", "Bala Azeda"],
		&"item_t3_f": ["popcorn", "Pipoca"],
		&"item_t3_g": ["Slingshot", "Estilingue"]
	}
	var approved_hero_names: Dictionary = {
		&"hero_avenger": ["Han", "Han"],
		&"hero_bastion": ["Kon", "Kon"],
		&"hero_bounty_hunter": ["Shiken", "Shiken"],
		&"hero_pyro": ["Hiko", "Hiko"],
		&"hero_starter": ["Dan", "Dan"],
		&"hero_timekeeper": ["Deko", "Deko"]
	}
	for hero_id in approved_hero_names:
		var hero_definition: GachaBallDefinition = Database.units[hero_id]
		TranslationServer.set_locale("en")
		_assert_ok(TranslationServer.translate(hero_definition.display_name_key) == approved_hero_names[hero_id][0], "%s EN display name" % hero_id)
		TranslationServer.set_locale("pt_BR")
		_assert_ok(TranslationServer.translate(hero_definition.display_name_key) == approved_hero_names[hero_id][1], "%s PT-BR display name" % hero_id)
	for item_id in approved_item_names:
		var item_definition: GachaBallDefinition = Database.items[item_id]
		TranslationServer.set_locale("en")
		_assert_ok(TranslationServer.translate(item_definition.display_name_key) == approved_item_names[item_id][0], "%s EN display name" % item_id)
		TranslationServer.set_locale("pt_BR")
		_assert_ok(TranslationServer.translate(item_definition.display_name_key) == approved_item_names[item_id][1], "%s PT-BR display name" % item_id)

	var canonical_base_units: Dictionary = {
		&"ETnkPla": "Stumpling",
		&"FFigMec": "Vulcannon",
		&"WSupAni": "Ripplepup",
		&"ASpeFod": "Puffcorn",
		&"EWFigCos": "Bogmantle",
		&"FASpeApp": "Furnair",
		&"EASupToy": "Matryodust",
		&"WATnkAni": "Soliwhale",
		&"EFTnkMec": "Branblee",
		&"FWFigFod": "Pepspray",
		&"EEFASpeCos": "Mimicloak",
		&"EEFWSupPla": "Oakbark",
		&"EEWAFigAni": "Griffoam",
		&"EFAASupToy": "Matryoshkan",
		&"EFFASupMec": "Mechamom",
		&"EFFWSpeApp": "Blendroid",
		&"EFWAFigMec": "Pachinkannon",
		&"EFWASpeFod": "BubbleGunger",
		&"EFWATnkApp": "Reizokun",
		&"EFWWFigCos": "Tsunamantle",
		&"EWAASpeApp": "Sojikun",
		&"EWWATnkToy": "Komatop",
		&"FFWASupMec": "Relaytron",
		&"FWAASpeToy": "Wind-up-kun",
		&"FWWATnkFod": "Nuton",
	}
	TranslationServer.set_locale("en")
	for uid in canonical_base_units:
		_assert_ok(Database.units.has(uid), "Database.units has canonical unit %s" % uid)
		var udef: GachaBallDefinition = Database.units[uid]
		_assert_ok(TranslationServer.translate(udef.display_name_key) == canonical_base_units[uid], "%s resolves to %s" % [uid, canonical_base_units[uid]])

	var canonical_mercenary_units: Dictionary = {
		&"?MerSpe": "Coinling",
		&"?ASpeMerFodToy": "Doughpuff",
		&"E?TnkMerPlaToy": "Vaultbark",
		&"F?FigMerMecApp": "Cashcannon",
		&"W?SupMerAniCos": "Pennypaw",
		&"E??ATnkSpeMerFodPlaToy": "Bullionbark",
		&"FW??FigSupMerAniMecAppCos": "Jackpotron",
		&"W??ASupSpeMerFodAniToyCos": "Bountifur",
		&"F??AFigSpeMerFodMecToyApp": "Coinroaster",
		&"EF??TnkFigMerMecPlaToyApp": "Furnasafe",
		&"EW??TnkSupMerAniPlaToyCos": "Mosstycoon",
	}
	for uid in canonical_mercenary_units:
		_assert_ok(Database.units.has(uid), "Database.units has canonical mercenary unit %s" % uid)
		var udef: GachaBallDefinition = Database.units[uid]
		_assert_ok(TranslationServer.translate(udef.display_name_key) == canonical_mercenary_units[uid], "%s resolves to %s" % [uid, canonical_mercenary_units[uid]])

	_assert_ok(TranslationServer.translate("trinket.polished_plate.desc").begins_with("Before battle,"), "Pre-Battle behavior is described without a heading")
	_assert_ok(TranslationServer.translate("item_t1_b.desc").contains("[color=#ffd166]Extra Attack[/color]"), "Extra Attack trigger uses approved highlight")
	_assert_ok(TranslationServer.translate("item_t1_b.desc").contains("[color=#ffd166]Melee Attack[/color]"), "Melee Attack term uses approved highlight")
	_assert_ok(TranslationServer.translate("item_t2_b.desc").contains("[color=#ffd166]Extra Action[/color]"), "Extra Action trigger uses approved highlight")
	_assert_ok(TranslationServer.translate("item_t3_d.desc").contains("[color=#ffd166]Ranged Attack[/color]"), "Ranged Attack term uses approved highlight")
	_assert_ok(TranslationServer.translate("item.claim_ticket.desc") == "When the holder is knocked out, earn 1 Gold.", "Gold Coin description has no ability heading")
	_assert_ok(TranslationServer.translate("ability.hero_timekeeper_temporal_aura.desc").contains("+1 HP") and TranslationServer.translate("ability.hero_timekeeper_temporal_aura.desc").contains("+1 PWR"), "Deko aura description matches its +1/+1 values")
	TranslationServer.set_locale("pt_BR")
	_assert_ok(TranslationServer.translate("trinket.polished_plate.desc").begins_with("Antes da batalha,"), "PT-BR Pre-Battle behavior is described without a heading")
	_assert_ok(TranslationServer.translate("item_t1_b.desc").contains("[color=#ffd166]Ataque Extra[/color]"), "PT-BR Extra Attack trigger uses approved highlight")
	_assert_ok(TranslationServer.translate("item_t1_b.desc").contains("[color=#ffd166]Ataque Corpo a Corpo[/color]"), "PT-BR Melee Attack term uses approved highlight")
	_assert_ok(TranslationServer.translate("item_t2_b.desc").contains("[color=#ffd166]Ação Extra[/color]"), "PT-BR Extra Action trigger uses approved highlight")
	_assert_ok(TranslationServer.translate("item_t3_d.desc").contains("[color=#ffd166]Ataque à Distância[/color]"), "PT-BR Ranged Attack term uses approved highlight")
	_assert_ok(TranslationServer.translate("item.claim_ticket.desc") == "Quando o portador é nocauteado, ganha 1 de Ouro.", "PT-BR Gold Coin description has no ability heading")

	# Shiken Ability Check
	var shiken_def: GachaBallDefinition = Database.units[&"hero_bounty_hunter"]
	_assert_ok(shiken_def.ability_definitions.size() == 1, "Shiken has exactly 1 ability definition")
	_assert_ok(shiken_def.ability_definitions[0].id == &"hero_shiken_gold_on_kill", "Shiken ability is hero_shiken_gold_on_kill")
	_assert_ok(shiken_def.ability_definitions[0].trigger == &"on_knockout_blow", "Shiken ability triggers on_knockout_blow")
	TranslationServer.set_locale("en")
	_assert_ok(TranslationServer.translate(shiken_def.ability_definitions[0].description_key) == "When this hero defeats an enemy, earn 1 Gold.", "Shiken ability translation matches")

	# Golden Seal Definition & Scaling Check
	var seal_def: GachaBallDefinition = Database.items[&"item_golden_seal"]
	_assert_ok(seal_def.bonus_hp == 2 and seal_def.bonus_pwr == 2, "Golden Seal grants +2/+2 base stats")
	_assert_ok(seal_def.ability_definitions.size() == 4, "Golden Seal has 4 ability definitions")
	var seal_triggers: Array[StringName] = []
	for ab: AbilityDefinition in seal_def.ability_definitions:
		seal_triggers.append(ab.trigger)
		_assert_ok(ab.effects.size() > 0 and ab.effects[0] is EffectGoldenSealScaling, "Golden Seal ability uses EffectGoldenSealScaling")
	for expected_trig in [&"on_gold_earned", &"on_gold_spent", &"on_board_state_changed", &"pre_combat"]:
		_assert_ok(seal_triggers.has(expected_trig), "Golden Seal listens to %s" % expected_trig)

	# Golden Seal Functional Scaling Simulation Test
	var test_bm = BattleManagerScript.new()
	add_child(test_bm)
	test_bm.add_to_group("battle_manager")
	GameManager.register_battle_manager(test_bm)

	var test_unit := GachaBallInstance.new()
	test_unit.initialize(Database.get_definition(&"FFigMec"))
	test_unit.current_hp = 10
	test_unit.current_pwr = 2
	test_unit.location_container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP

	var test_seal := GachaBallInstance.new()
	test_seal.initialize(seal_def)
	test_seal.equipped_on_uuid = test_unit.ball_uuid

	test_bm._battle_instances[test_unit.ball_uuid] = test_unit
	test_bm._battle_instances[test_seal.ball_uuid] = test_seal

	var old_rs = GameManager.run_state
	var test_rs = RunState.new()
	test_rs.gold = 25
	GameManager.run_state = test_rs

	var seal_effect := EffectGoldenSealScaling.new()
	var sim_ctx := TriggerContext.new()
	sim_ctx.is_simulation = true

	# 1. Scaling at 25 gold -> +2 HP / +2 PWR
	var res1 = seal_effect.execute(test_seal.ball_uuid, [], test_bm, sim_ctx)
	_assert_ok(res1.state_applied, "Golden Seal initial 25 gold scaling applied")
	_assert_ok(test_unit.current_hp == 12, "Golden Seal holder HP scaled to 12 at 25 gold (was 10)")
	_assert_ok(test_unit.current_pwr == 4, "Golden Seal holder PWR scaled to 4 at 25 gold (was 2)")
	var status_key := StringName("golden_seal_scaling_" + test_seal.ball_uuid)
	_assert_ok(test_unit.get_status_effect_amount(status_key) == 2, "Golden Seal status tracker is 2")

	# 2. Spend 10 gold -> gold drops to 15 -> bonus drops to +1 -> holder stats drop by 1
	test_rs.gold = 15
	var res2 = seal_effect.execute(test_seal.ball_uuid, [], test_bm, sim_ctx)
	_assert_ok(res2.state_applied, "Golden Seal spend gold scaling applied")
	_assert_ok(test_unit.current_hp == 11, "Golden Seal holder HP decreased to 11 at 15 gold")
	_assert_ok(test_unit.current_pwr == 3, "Golden Seal holder PWR decreased to 3 at 15 gold")
	_assert_ok(test_unit.get_status_effect_amount(status_key) == 1, "Golden Seal status tracker decreased to 1")

	# 3. Unequip Golden Seal -> bonus removed cleanly
	test_seal.equipped_on_uuid = ""
	var res3 = seal_effect.execute(test_seal.ball_uuid, [], test_bm, sim_ctx)
	_assert_ok(res3.state_applied, "Golden Seal unequip scaling applied")
	_assert_ok(test_unit.current_hp == 10, "Golden Seal holder HP restored to base 10 on unequip")
	_assert_ok(test_unit.current_pwr == 2, "Golden Seal holder PWR restored to base 2 on unequip")
	_assert_ok(test_unit.get_status_effect_amount(status_key) == 0, "Golden Seal status tracker cleared to 0")

	GameManager.run_state = old_rs
	test_bm.queue_free()
	GameManager.unregister_battle_manager()

	# Nuton Buff Absorption Test (FWWATnkFod)
	var nuton_bm = BattleManagerScript.new()
	add_child(nuton_bm)
	nuton_bm.add_to_group("battle_manager")
	GameManager.register_battle_manager(nuton_bm)

	var nuton_def: GachaBallDefinition = Database.units.get(&"FWWATnkFod")
	_assert_ok(nuton_def != null, "Nuton definition found in Database")
	var nuton_inst := GachaBallInstance.new()
	nuton_inst.initialize(nuton_def)
	nuton_inst.current_hp = 4
	nuton_inst.current_pwr = 5

	var ally_def: GachaBallDefinition = Database.units.get(&"ETnkPla")
	var ally_inst := GachaBallInstance.new()
	ally_inst.initialize(ally_def)
	ally_inst.current_hp = 6
	ally_inst.current_pwr = 3

	var non_adjacent_def: GachaBallDefinition = Database.units.get(&"FFigMec")
	var non_adjacent_inst := GachaBallInstance.new()
	non_adjacent_inst.initialize(non_adjacent_def)
	non_adjacent_inst.current_hp = 5
	non_adjacent_inst.current_pwr = 2

	# Place units in player lineup: ally at 0, nuton at 1, non-adjacent at 3
	nuton_bm._state.bm_add_instance(ally_inst, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 0)
	nuton_bm._state.bm_add_instance(nuton_inst, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 1)
	nuton_bm._state.bm_add_instance(non_adjacent_inst, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 3)

	var echo_effect := EffectRepeatAdjacentBuff.new()
	echo_effect.parameters = {"effectiveness": 1.0}

	# 1. Buff adjacent ally -> Nuton absorbs buff onto itself
	var buff_ctx := TriggerContext.new()
	buff_ctx.is_simulation = true
	buff_ctx.is_stackable = true
	buff_ctx.stat = "hp"
	buff_ctx.amount = 2
	buff_ctx.unit_uuid = ally_inst.ball_uuid
	buff_ctx.triggering_uuid = ally_inst.ball_uuid

	var echo_res = echo_effect.execute(nuton_inst.ball_uuid, [ally_inst.ball_uuid], nuton_bm, buff_ctx)
	_assert_ok(echo_res.state_applied, "Nuton buff absorption applied")
	_assert_ok(nuton_inst.current_hp == 6, "Nuton absorbed HP buff (HP increased from 4 to 6)")
	_assert_ok(ally_inst.current_hp == 6, "Ally HP unaffected by Nuton's absorption (remained 6)")

	# 2. Buff non-adjacent ally -> Nuton ignores buff
	var non_adj_ctx := TriggerContext.new()
	non_adj_ctx.is_simulation = true
	non_adj_ctx.is_stackable = true
	non_adj_ctx.stat = "pwr"
	non_adj_ctx.amount = 3
	non_adj_ctx.unit_uuid = non_adjacent_inst.ball_uuid
	non_adj_ctx.triggering_uuid = non_adjacent_inst.ball_uuid

	var non_adj_res = echo_effect.execute(nuton_inst.ball_uuid, [non_adjacent_inst.ball_uuid], nuton_bm, non_adj_ctx)
	_assert_ok(not non_adj_res.state_applied, "Nuton does not absorb buff from non-adjacent unit")
	_assert_ok(nuton_inst.current_pwr == 5, "Nuton PWR unchanged when non-adjacent unit is buffed")

	# 3. Echo loop protection -> does not trigger on an echo buff
	var loop_ctx := TriggerContext.new()
	loop_ctx.is_simulation = true
	loop_ctx.is_stackable = true
	loop_ctx.is_echo = true
	loop_ctx.stat = "hp"
	loop_ctx.amount = 5
	loop_ctx.unit_uuid = ally_inst.ball_uuid

	var loop_res = echo_effect.execute(nuton_inst.ball_uuid, [ally_inst.ball_uuid], nuton_bm, loop_ctx)
	_assert_ok(not loop_res.state_applied, "Nuton rejects echo buffs to prevent infinite loop")
	_assert_ok(nuton_inst.current_hp == 6, "Nuton HP unchanged on echo buff")

	# 4. Taxonomy Subgroup Protection -> Rejects CONDITIONAL buffs (e.g. while equipped, conditional trinkets)
	var cond_ctx := TriggerContext.new()
	cond_ctx.is_simulation = true
	cond_ctx.is_stackable = false
	cond_ctx.buff_subgroup = C.BUFF_SUBGROUP_CONDITIONAL
	cond_ctx.stat = "hp"
	cond_ctx.amount = 4
	cond_ctx.unit_uuid = ally_inst.ball_uuid

	var cond_res = echo_effect.execute(nuton_inst.ball_uuid, [ally_inst.ball_uuid], nuton_bm, cond_ctx)
	_assert_ok(not cond_res.state_applied, "Buff Echo strictly rejects CONDITIONAL buffs (while equipped, trinket conditions)")
	_assert_ok(nuton_inst.current_hp == 6, "Nuton HP unchanged after conditional buff rejection")

	# 5. Taxonomy Subgroup Protection -> Rejects PERMANENT buffs (cultivation upgrades)
	var perm_ctx := TriggerContext.new()
	perm_ctx.is_simulation = true
	perm_ctx.is_stackable = false
	perm_ctx.buff_subgroup = C.BUFF_SUBGROUP_PERMANENT
	perm_ctx.stat = "hp"
	perm_ctx.amount = 5
	perm_ctx.unit_uuid = ally_inst.ball_uuid

	var perm_res = echo_effect.execute(nuton_inst.ball_uuid, [ally_inst.ball_uuid], nuton_bm, perm_ctx)
	_assert_ok(not perm_res.state_applied, "Buff Echo strictly rejects PERMANENT cultivation buffs")
	_assert_ok(nuton_inst.current_hp == 6, "Nuton HP unchanged after permanent buff rejection")

	# 6. Dan Hero Self Buff -> Triggers DISCRETE buff on Dan, which adjacent Buff Echo echoes
	var dan_def: GachaBallDefinition = load("res://resources/units/HeroStarter.tres")
	var dan_inst := GachaBallInstance.new()
	dan_inst.initialize(dan_def)
	nuton_bm._state.bm_remove_instance(ally_inst.ball_uuid)
	nuton_bm._state.bm_add_instance(dan_inst, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 0)

	var dan_absorb_script = load("res://scripts/effects/EffectGainDeadAllyPwrAsHP.gd")
	var dan_absorb_effect = dan_absorb_script.new()
	var dan_ctx := TriggerContext.new()
	dan_ctx.is_simulation = true
	dan_ctx.ally_knocked_out_uuid = non_adjacent_inst.ball_uuid
	dan_ctx.ally_knocked_out_pwr = 3

	var dan_targets: Array[String] = [dan_inst.ball_uuid]
	var dan_res = dan_absorb_effect.execute(dan_inst.ball_uuid, dan_targets, nuton_bm, dan_ctx)
	_assert_ok(dan_res.state_applied, "Dan hero self buff executed")
	_assert_ok(dan_inst.current_hp == 13, "Dan HP increased from 10 to 13 (+3 HP from dead ally PWR)")

	# Now Nuton echoes Dan's discrete buff
	var dan_buff_event: CombatEvent = null
	for ev in dan_res.events:
		if ev.type == CombatEvent.Type.BUFF:
			dan_buff_event = ev
			break
	_assert_ok(dan_buff_event != null, "Dan soul harvest emitted CombatEvent.BUFF")
	_assert_ok(dan_buff_event.buff_subgroup == C.BUFF_SUBGROUP_DISCRETE, "Dan buff tagged as BUFF_SUBGROUP_DISCRETE")

	var dan_echo_ctx := TriggerContext.new()
	dan_echo_ctx.is_simulation = true
	dan_echo_ctx.is_stackable = true
	dan_echo_ctx.buff_subgroup = C.BUFF_SUBGROUP_DISCRETE
	dan_echo_ctx.stat = "hp"
	dan_echo_ctx.amount = 3
	dan_echo_ctx.unit_uuid = dan_inst.ball_uuid
	dan_echo_ctx.triggering_uuid = dan_inst.ball_uuid

	var echo_targets: Array[String] = [dan_inst.ball_uuid]
	var dan_echo_res = echo_effect.execute(nuton_inst.ball_uuid, echo_targets, nuton_bm, dan_echo_ctx)
	_assert_ok(dan_echo_res.state_applied, "Nuton echoes Dan's discrete in-combat self buff")
	_assert_ok(nuton_inst.current_hp == 9, "Nuton HP increased from 6 to 9 (+3 HP echoed from Dan)")

	# 7. Inventory Equip Simulation -> _generate_inventory_stat_events tags buffs as CONDITIONAL, which Nuton rejects
	var pre_stats := {
		dan_inst.ball_uuid: {
			"hp": dan_inst.current_hp,
			"pwr": dan_inst.current_pwr
		}
	}
	# Simulate equipping an item on Dan that grants +2 HP and +1 PWR
	dan_inst.current_hp += 2
	dan_inst.current_pwr += 1
	var stat_data = nuton_bm._generate_inventory_stat_events(pre_stats)
	_assert_ok(not stat_data.events.is_empty(), "Inventory equip generated stat events")
	for ev in stat_data.events:
		if ev.type == CombatEvent.Type.BUFF:
			_assert_ok(ev.buff_subgroup == C.BUFF_SUBGROUP_CONDITIONAL, "Inventory buff event tagged as CONDITIONAL")
	_assert_ok(nuton_inst.current_hp == 9, "Nuton HP unaffected by adjacent ally equipping item (remains 9)")

	nuton_bm.queue_free()
	GameManager.unregister_battle_manager()

func _test_status_effect_visual_sources() -> void:
	var status_bm: BattleManager = BattleManagerScript.new()
	var candy_definition: GachaBallDefinition = Database.get_definition(&"item_t3_b")
	var candy_ability: AbilityDefinition = candy_definition.ability_definitions[0]
	for container_tag: StringName in [&"PlayerLineup", &"EnemyLineup"]:
		status_bm._state = BattleState.new()
		status_bm._combat = CombatSimulator.new()
		var holder := GachaBallInstance.new()
		holder.initialize(Database.get_definition(&"FFigMec"))
		assert(status_bm._state.bm_add_instance(holder, container_tag, 0))
		var candy := GachaBallInstance.new()
		candy.initialize(candy_definition)
		assert(InventoryOperations.register_and_equip_item(status_bm._state, candy, holder.ball_uuid).success)
		var snapshot: Dictionary = status_bm.get_board_snapshot()
		_assert_ok(not snapshot.has(candy.ball_uuid), "Equipped HardCandy has no independent battle view")
		var context := TriggerContext.new()
		context.trigger_type = candy_ability.trigger
		context.damage_dealt = 7
		var events: Array[CombatEvent] = []
		for effect: EffectDefinition in candy_ability.effects:
			var request := EffectRequest.new(candy.ball_uuid, candy_ability.id, effect, [holder.ball_uuid], context)
			status_bm._combat.resolve_effect_request(request, events, {}, status_bm)
		_assert_ok(events.size() == 2, "HardCandy emits separate Armor and Spikes events for %s" % container_tag)
		for event: CombatEvent in events:
			_assert_ok(event.type == CombatEvent.Type.STATUS_EFFECT, "HardCandy emits status events")
			_assert_ok(event.source_uuid == candy.ball_uuid, "HardCandy retains its logical item source")
			_assert_ok(event.visual_payload.source_uuid == holder.ball_uuid, "HardCandy projectiles originate from its holder")
			_assert_ok(snapshot.has(event.visual_payload.source_uuid), "HardCandy projectile source is in the presentation snapshot")
			_assert_ok(event.visual_payload.amount == 3 and event.visual_payload.targets_new_val == [3], "HardCandy preserves half-damage stack amounts")
		_assert_ok(holder.get_status_effect_amount(&"armor") == 3 and holder.get_status_effect_amount(&"spikes") == 3, "HardCandy still grants both statuses")

		# Unit, trinket, and unsourced status effects keep their own visual origin.
		var status_effect: EffectDefinition = preload("res://scripts/EffectApplyStatus.gd").new()
		status_effect.parameters = {"status_id": "burn", "amount": 1}
		var trinket := GachaBallInstance.new()
		trinket.initialize_from_trinket(Database.trinkets[&"trinket_polished_plate"])
		assert(status_bm._state.bm_add_instance(trinket, &"PlayerTrinkets", 0))
		for source_uuid: String in [holder.ball_uuid, trinket.ball_uuid, ""]:
			var source_events: Array[CombatEvent] = []
			var request := EffectRequest.new(source_uuid, &"apply_status", status_effect, [holder.ball_uuid], TriggerContext.new())
			status_bm._combat.resolve_effect_request(request, source_events, {}, status_bm)
			_assert_ok(source_events.size() == 1, "Status source case emits one event")
			_assert_ok(source_events[0].visual_payload.source_uuid == source_uuid, "Non-item status source remains unchanged")
	status_bm.free()

# ==============================================================================
# SUITE 7 IMPLEMENTATION: Novice Set Integration & Mechanics
# ==============================================================================
func _run_suite_7_novice_set() -> void:
	# 1. Novice units definitions in Database
	var novice_unit_ids: Array[StringName] = [
		&"?NovPla", &"?ANovFod", &"E?NovPla", &"F?NovApp", &"W?NovCos",
		&"E??ANovPla", &"F??ANovFod", &"W??ANovCos", &"EF??NovApp", &"EW??NovPla", &"FW??NovAni"
	]
	for u_id in novice_unit_ids:
		var u_def: GachaBallDefinition = Database.units.get(u_id)
		_assert_ok(u_def != null, "Novice unit definition %s must exist in Database" % u_id)
		if u_def != null:
			_assert_ok(u_def.tags.has(&"Novice"), "Novice unit %s must have trait Novice" % u_id)
			_assert_ok(not u_def.ability_definitions.is_empty(), "Novice unit %s must have an ability" % u_id)

	# 2. Novice items in Database
	var novice_item_ids: Array[StringName] = [
		&"item_study_pouch", &"item_review_ledger", &"item_answer_key", &"item_novice_archive", &"item_novice_emblem"
	]
	for i_id in novice_item_ids:
		var it_def: GachaBallDefinition = Database.items.get(i_id)
		_assert_ok(it_def != null, "Novice item definition %s must exist in Database" % i_id)
		if it_def != null:
			_assert_ok(not it_def.ability_definitions.is_empty(), "Novice item %s must have an ability" % i_id)
	var emblem_def: GachaBallDefinition = Database.items.get(&"item_novice_emblem")
	if emblem_def != null:
		_assert_ok(emblem_def.tags.has(&"Novice"), "Novice Emblem item must have trait tag Novice")

	# 3. Novice trinkets in Database
	var crest: TrinketDefinition = Database.trinkets.get(&"trinket_trait_novice")
	_assert_ok(crest != null, "trinket_trait_novice must exist in Database")
	if crest != null:
		_assert_ok(crest.linked_trait_id == &"NOVICE", "trinket_trait_novice must have linked_trait_id NOVICE")
		for loc in ["en", "pt_BR"]:
			TranslationServer.set_locale(loc)
			var crest_name: String = TranslationServer.translate(crest.name_key)
			var crest_desc: String = TranslationServer.translate(crest.description_key)
			_assert_ok(not crest_name.is_empty() and crest_name != crest.name_key, "[%s] trinket_trait_novice name must be translated" % loc)
			_assert_ok(not crest_desc.is_empty() and crest_desc != crest.description_key, "[%s] trinket_trait_novice desc must be translated" % loc)
			
			var inst := GachaBallInstance.new()
			inst.initialize_from_trinket(crest)
			var window = preload("res://scenes/ItemInspectionWindow.tscn").instantiate()
			get_tree().root.add_child(window)
			window.populate({"instance": inst, "is_preview": true})
			var window_text: String = window.description_label.text
			_assert_ok(not window_text.contains("trait.novice"), "[%s] ItemInspectionWindow contains raw key trait.novice: %s" % [loc, window_text])
			_assert_ok(window_text.contains(crest_desc), "[%s] ItemInspectionWindow must contain base passive: %s" % [loc, crest_desc])
			window.queue_free()

			var trait_window = preload("res://scenes/TraitInspectionWindow.tscn").instantiate()
			get_tree().root.add_child(trait_window)
			trait_window.populate({"trait_id": "NOVICE", "count": 2})
			var trait_title: String = trait_window.title_label.text
			var trait_desc: String = trait_window.description_label.text
			_assert_ok(not trait_title.contains("trait.novice"), "[%s] TraitInspectionWindow title contains raw key: %s" % [loc, trait_title])
			_assert_ok(not trait_desc.contains("trait.novice"), "[%s] TraitInspectionWindow desc contains raw key: %s" % [loc, trait_desc])
			trait_window.queue_free()

	var bell: TrinketDefinition = Database.trinkets.get(&"trinket_study_hall_bell")
	_assert_ok(bell != null, "trinket_study_hall_bell must exist in Database")

	var apprentice_insignia: TrinketDefinition = Database.trinkets.get(&"trinket_royal_insignia")
	_assert_ok(apprentice_insignia != null, "trinket_royal_insignia must exist in Database")
	if apprentice_insignia != null:
		_assert_ok(apprentice_insignia.name_key == "trinket.apprentice_insignia.name", "trinket_royal_insignia must have name_key trinket.apprentice_insignia.name")
		_assert_ok(apprentice_insignia.description_key == "trinket.apprentice_insignia.desc", "trinket_royal_insignia must have description_key trinket.apprentice_insignia.desc")

	var novice_insignia: TrinketDefinition = Database.trinkets.get(&"trinket_novice_insignia")
	_assert_ok(novice_insignia != null, "trinket_novice_insignia must exist in Database")
	if novice_insignia != null:
		_assert_ok(novice_insignia.name_key == "trinket.novice_insignia.name", "trinket_novice_insignia must have name_key trinket.novice_insignia.name")
		_assert_ok(novice_insignia.description_key == "trinket.novice_insignia.desc", "trinket_novice_insignia must have description_key trinket.novice_insignia.desc")
		_assert_ok(novice_insignia.ability_definitions.size() == 4, "trinket_novice_insignia must have 4 abilities")
		_assert_ok(novice_insignia.is_player_exclusive, "trinket_novice_insignia must be player exclusive")
		_assert_ok(novice_insignia.set_id == Database.SET_NOVICE, "trinket_novice_insignia must have set_id NOVICE")

	# 4. Recipes
	var expected_recipes: Array[StringName] = [
		&"merge_novpla_aspefod_to_anovfod",
		&"merge_novpla_etnkpla_to_enovpla",
		&"merge_novpla_ffigmec_to_fnovapp",
		&"merge_novpla_wsupani_to_wnovcos",
		&"merge_anovfod_enovpla_to_eanovpla",
		&"merge_anovfod_fnovapp_to_fanovfod",
		&"merge_anovfod_wnovcos_to_wanovcos",
		&"merge_enovpla_fnovapp_to_efnovapp",
		&"merge_enovpla_wnovcos_to_ewnovpla",
		&"merge_fnovapp_wnovcos_to_fwnovani",
		&"merge_item_study_pouch_item_t1_a_to_item_review_ledger",
		&"merge_item_study_pouch_item_t1_b_to_item_answer_key",
		&"merge_item_review_ledger_item_answer_key_to_item_novice_archive"
	]
	for r_id in expected_recipes:
		_assert_ok(Database.recipes.has(r_id), "Novice recipe %s must exist in Database" % r_id)

	# 5. Hero Dan dynamic element adaptation
	var hero_dan: GachaBallDefinition = Database.units.get(&"hero_starter")
	_assert_ok(hero_dan != null, "Hero Dan (hero_starter) must exist in Database")
	var dan_run := RunState.new()
	dan_run.initialize_run(&"hero_starter", &"")
	_assert_ok(dan_run.hero_instance != null, "Dan hero instance must be initialized")
	var hero_tags_comp: TagComponent = null
	for comp in dan_run.hero_instance.components:
		if comp is TagComponent and comp.id == &"hero_run_traits":
			hero_tags_comp = comp
			break
	_assert_ok(hero_tags_comp != null, "Hero run traits component must exist")
	if hero_tags_comp != null:
		_assert_ok(hero_tags_comp.tags_to_add.has(&"Novice"), "Dan must have Novice tag")
		var has_element: bool = (
			hero_tags_comp.tags_to_add.has(&"SOUL_FIRE") or
			hero_tags_comp.tags_to_add.has(&"SOUL_EARTH") or
			hero_tags_comp.tags_to_add.has(&"SOUL_WATER") or
			hero_tags_comp.tags_to_add.has(&"SOUL_AIR")
		)
		_assert_ok(has_element, "Dan must have a chosen elemental soul")

	# Verify Dan starter instances in RunState
	var dan_starter_novpla_found: bool = false
	var dan_study_pouch_found: bool = false
	var dan_novice_crest_found: bool = false
	for inst in dan_run.get_all_instances().values():
		if inst.definition_id == &"?NovPla":
			dan_starter_novpla_found = true
		elif inst.definition_id == &"item_study_pouch":
			dan_study_pouch_found = true
		elif inst.definition_id == &"trinket_trait_novice":
			dan_novice_crest_found = true
	_assert_ok(dan_starter_novpla_found, "Dan starter instances must contain ?NovPla")
	_assert_ok(dan_study_pouch_found, "Dan starter instances must contain item_study_pouch")
	_assert_ok(dan_novice_crest_found, "Dan starter instances must contain trinket_trait_novice")

	# 6. Battle mechanics (Tokens, Minigame Bonus Time, Effects)
	var old_rs = GameManager.run_state
	GameManager.run_state = dan_run

	var test_bm = BattleManagerScript.new()
	add_child(test_bm)
	test_bm.add_to_group("battle_manager")
	GameManager.register_battle_manager(test_bm)

	# Tokens
	_assert_ok(test_bm.get_gacha_tokens() == 0, "Initial tokens must be 0")
	test_bm.add_gacha_tokens(5)
	_assert_ok(test_bm.get_gacha_tokens() == 5, "Tokens after add(5) must be 5")
	var spent: bool = test_bm.spend_gacha_tokens(2)
	_assert_ok(spent and test_bm.get_gacha_tokens() == 3, "spend_gacha_tokens(2) must succeed and leave 3")
	var overspent: bool = test_bm.spend_gacha_tokens(4)
	_assert_ok(not overspent and test_bm.get_gacha_tokens() == 3, "spend_gacha_tokens(4) must fail and leave 3")

	# Minigame bonus time & SignalBus emission
	var bonus_signal_val: Array[float] = [-1.0]
	var bonus_signal_cb := func(val: float): bonus_signal_val[0] = val
	SignalBus.minigame_bonus_time_changed.connect(bonus_signal_cb)

	test_bm.add_next_minigame_bonus_time(2.5)
	_assert_ok(is_equal_approx(bonus_signal_val[0], 2.5), "minigame_bonus_time_changed emitted on add")
	var bonus_time: float = test_bm.consume_next_minigame_bonus_time()
	_assert_ok(is_equal_approx(bonus_time, 2.5), "consume_next_minigame_bonus_time must return 2.5")
	_assert_ok(is_equal_approx(bonus_signal_val[0], 0.0), "minigame_bonus_time_changed emitted 0.0 on consume")
	var bonus_time2: float = test_bm.consume_next_minigame_bonus_time()
	_assert_ok(is_equal_approx(bonus_time2, 0.0), "second consume_next_minigame_bonus_time must return 0.0")
	SignalBus.minigame_bonus_time_changed.disconnect(bonus_signal_cb)

	# Effects simulation
	var test_unit := GachaBallInstance.new()
	var test_def: GachaBallDefinition = Database.units.get(&"?NovPla")
	_assert_ok(test_def != null, "Definition for ?NovPla must exist")
	if test_def != null:
		test_unit.initialize(test_def)
		test_bm._state.bm_add_instance(test_unit, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 0)

		# Mirethicket / Novice's Archive: EffectChargeEmpoweredAttack with SPEND_1_BONUS_DAMAGE_PER_TOKEN_HELD
		var archive_effect := EffectChargeEmpoweredAttack.new()
		archive_effect.parameters = {"mode": "SPEND_1_BONUS_DAMAGE_PER_TOKEN_HELD", "scale": 1}
		var ctx := TriggerContext.new()
		ctx.is_simulation = true
		var arc_res = archive_effect.execute(test_unit.ball_uuid, [], test_bm, ctx)
		_assert_ok(arc_res.state_applied, "EffectChargeEmpoweredAttack applied")
		_assert_ok(test_unit.charged_empowered_attack.get("bonus_damage", 0) == 3, "charged_empowered_attack has +3 bonus damage for 3 tokens held")
		_assert_ok(test_bm.get_gacha_tokens() == 2, "Empowered attack spent 1 token immediately on execution (3 -> 2)")
		var inline_spends = test_bm.collect_inline_events()
		_assert_ok(inline_spends.any(func(e): return e.type == CombatEvent.Type.TOKEN_SPEND), "TOKEN_SPEND event emitted on token spend")

		# Reset tokens to 3 for Galebloom
		test_bm.add_gacha_tokens(1)

		# Galebloom: EffectGalebloomPreBattle (spends 1 token, gains armor per token and spikes per 2 tokens held)
		var galebloom_effect = EffectGalebloomPreBattleScript.new()
		var gale_res = galebloom_effect.execute(test_unit.ball_uuid, [], test_bm, ctx)
		_assert_ok(gale_res.state_applied, "EffectGalebloomPreBattle applied")
		_assert_ok(test_unit.get_status_effect_amount(&"armor") == 3, "Unit gained 3 armor for 3 tokens held")
		_assert_ok(test_unit.get_status_effect_amount(&"spikes") == 1, "Unit gained 1 spike for 3 tokens held (floor(3/2)*1)")
		_assert_ok(test_bm.get_gacha_tokens() == 2, "Galebloom spent 1 token (3 -> 2)")

		var status_events = gale_res.events.filter(func(e): return e.type == CombatEvent.Type.STATUS_EFFECT)
		_assert_ok(status_events.size() == 2, "Galebloom produces 2 distinct STATUS_EFFECT events (Armor and Spikes)")
		var armor_ev = status_events[0]
		var spikes_ev = status_events[1]
		_assert_ok(not armor_ev.can_merge_with(spikes_ev), "Armor and Spikes STATUS_EFFECT events cannot merge into a single event")
		_assert_ok(CombatEffectRegistry.get_definition(&"spikes").color == Color(0.2, 0.85, 0.2, 1), "Spikes definition color is standardized green")
		_assert_ok(CombatEffectRegistry.get_definition(&"armor").color == Color(0.65, 0.65, 0.65, 1), "Armor definition color is standardized gray")

		# Rootguard: EffectRootguardPreBattle (T2: 1/2/3 Armor per 2 tokens held, NO spikes)
		var rootguard_effect := EffectRootguardPreBattle.new()
		var root_res = rootguard_effect.execute(test_unit.ball_uuid, [], test_bm, ctx)
		_assert_ok(root_res.state_applied, "EffectRootguardPreBattle applied")
		_assert_ok(test_unit.get_status_effect_amount(&"armor") == 4, "Unit gained 1 armor for 2 tokens (total 4)")
		_assert_ok(test_unit.get_status_effect_amount(&"spikes") == 1, "Rootguard gives no spikes (still 1)")

		# Tidecloak: EffectTidecloakHealOnHurt (T2: heal 1/2/3 HP per 2 tokens held when hurt, 0 token cost)
		test_unit.current_hp = 5
		var tidecloak_effect := EffectTidecloakHealOnHurt.new()
		var tide_res = tidecloak_effect.execute(test_unit.ball_uuid, [], test_bm, ctx)
		_assert_ok(tide_res.state_applied, "EffectTidecloakHealOnHurt applied")
		_assert_ok(test_unit.current_hp == 6, "Unit healed 1 HP for 2 tokens held (5 -> 6)")
		_assert_ok(test_bm.get_gacha_tokens() == 2, "Tidecloak costs 0 tokens (still 2)")

		# Stormshroud: EffectStormshroudHealOnHurt (T3: spend 1 token, heal 1/2/3 HP per 1 token held before spend)
		var stormshroud_effect = EffectStormshroudHealOnHurtScript.new()
		var steam_res = stormshroud_effect.execute(test_unit.ball_uuid, [], test_bm, ctx)
		_assert_ok(steam_res.state_applied, "EffectStormshroudHealOnHurt applied")
		_assert_ok(test_unit.current_hp == 8, "Unit healed 2 HP for 2 tokens held before spend (6 -> 8)")
		_assert_ok(test_bm.get_gacha_tokens() == 1, "Stormshroud spent 1 token (2 -> 1)")

		# Gustpuff: EffectChargeEmpoweredAttack (T2: STATIC_PER_2_TOKENS)
		var gustpuff_effect := EffectChargeEmpoweredAttack.new()
		gustpuff_effect.parameters = {"mode": "STATIC_PER_2_TOKENS"}
		test_bm.add_gacha_tokens(1) # tokens: 1 -> 2
		var gust_res = gustpuff_effect.execute(test_unit.ball_uuid, [], test_bm, ctx)
		_assert_ok(gust_res.state_applied, "Gustpuff applied")
		_assert_ok(test_unit.charged_empowered_attack.get("static_stacks", 0) == 1, "Gustpuff charged 1 static for 2 tokens held")

		# Ignikettle: EffectChargeEmpoweredAttack (T2: BURN_PER_2_TOKENS)
		var igni_effect := EffectChargeEmpoweredAttack.new()
		igni_effect.parameters = {"mode": "BURN_PER_2_TOKENS"}
		var igni_res = igni_effect.execute(test_unit.ball_uuid, [], test_bm, ctx)
		_assert_ok(igni_res.state_applied, "Ignikettle applied")
		_assert_ok(test_unit.charged_empowered_attack.get("burn_stacks", 0) == 1, "Ignikettle charged 1 burn for 2 tokens held")

		# Nail: EffectNailPreBattle (1/2/3 Spikes per token held at pre_combat, equipped on holder)
		var nail_item := GachaBallInstance.new()
		var nail_def: GachaBallDefinition = Database.items.get(&"item_review_ledger")
		nail_item.initialize(nail_def)
		var nail_eq = InventoryOperations.register_and_equip_item(test_bm._state, nail_item, test_unit.ball_uuid, 0)
		_assert_ok(nail_eq.success, "Nail item equipped successfully on test unit")
		var nail_effect := EffectNailPreBattle.new()
		var nail_res = nail_effect.execute(nail_item.ball_uuid, [], test_bm, ctx)
		_assert_ok(nail_res.state_applied, "EffectNailPreBattle applied")
		_assert_ok(test_unit.get_status_effect_amount(&"spikes") == 3, "Unit gained 2 spikes for 2 tokens held (1 + 2 = 3)")

		# Dynamic combat token scaling test across sequential activations:
		# Attack 1 (Zephyrcrisp), Attack 2 (Mirethicket), Attack 3 (Magmarange)
		if test_bm.get_gacha_tokens() != 3:
			test_bm.add_gacha_tokens(3 - test_bm.get_gacha_tokens())
		_assert_ok(test_bm.get_gacha_tokens() == 3, "Setup 3 tokens for sequential combat ability scaling test")

		# Unit attacks with 3 tokens: charges 3 static, spends 1 token -> 2 tokens left
		var zephyr_effect := EffectChargeEmpoweredAttack.new()
		zephyr_effect.parameters = {"mode": "SPEND_1_STATIC_PER_TOKEN_HELD"}
		test_unit.charged_empowered_attack = {}
		var z_res = zephyr_effect.execute(test_unit.ball_uuid, [], test_bm, ctx)
		_assert_ok(z_res.state_applied, "Zephyrcrisp activated")
		_assert_ok(test_unit.charged_empowered_attack.get("static_stacks", 0) == 3, "Scaled with 3 tokens (3 static)")
		_assert_ok(test_bm.get_gacha_tokens() == 2, "Spent 1 token immediately (3 -> 2)")

		# Next attack: sees only 2 tokens left -> charges 2 bonus damage, spends 1 token -> 1 token left
		var mire_effect := EffectChargeEmpoweredAttack.new()
		mire_effect.parameters = {"mode": "SPEND_1_BONUS_DAMAGE_PER_TOKEN_HELD"}
		test_unit.charged_empowered_attack = {}
		var m_res = mire_effect.execute(test_unit.ball_uuid, [], test_bm, ctx)
		_assert_ok(m_res.state_applied, "Mirethicket activated")
		_assert_ok(test_unit.charged_empowered_attack.get("bonus_damage", 0) == 2, "Progressively scaled with remaining 2 tokens (2 bonus damage)")
		_assert_ok(test_bm.get_gacha_tokens() == 1, "Spent 1 token immediately (2 -> 1)")

		# Next attack: sees only 1 token left -> charges 1 burn, spends 1 token -> 0 tokens left
		var magma_effect := EffectChargeEmpoweredAttack.new()
		magma_effect.parameters = {"mode": "SPEND_1_BURN_PER_TOKEN_HELD"}
		test_unit.charged_empowered_attack = {}
		var mg_res = magma_effect.execute(test_unit.ball_uuid, [], test_bm, ctx)
		_assert_ok(mg_res.state_applied, "Magmarange activated")
		_assert_ok(test_unit.charged_empowered_attack.get("burn_stacks", 0) == 1, "Progressively scaled with remaining 1 token (1 burn)")
		_assert_ok(test_bm.get_gacha_tokens() == 0, "Spent 1 token immediately (1 -> 0)")

		# Tries to attack with 0 tokens: cannot pay 1 token cost -> no charge, 0 tokens spent
		test_unit.charged_empowered_attack = {}
		var fail_res = magma_effect.execute(test_unit.ball_uuid, [], test_bm, ctx)
		_assert_ok(test_unit.charged_empowered_attack.is_empty(), "Could not charge without tokens")
		_assert_ok(test_bm.get_gacha_tokens() == 0, "Tokens remain 0")

		# Zephyrcrisp lethal attack & Static collateral damage test:
		test_bm.add_gacha_tokens(3)
		var zephyr_unit := GachaBallInstance.new()
		var zephyr_def: GachaBallDefinition = Database.units.get(&"F??ANovFod")
		zephyr_unit.initialize(zephyr_def)
		test_bm._state.bm_add_instance(zephyr_unit, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 1)

		var target_enemy := GachaBallInstance.new()
		var target_def: GachaBallDefinition = Database.units.get(&"ETnkPla")
		target_enemy.initialize(target_def)
		target_enemy.current_hp = 5 # Lethal damage (Zephyrcrisp has 5 PWR)
		test_bm._state.bm_add_instance(target_enemy, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, 0)

		var adj_enemy := GachaBallInstance.new()
		adj_enemy.initialize(target_def)
		adj_enemy.current_hp = 10
		test_bm._state.bm_add_instance(adj_enemy, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, 1)

		test_bm._enqueue_attack_for(zephyr_unit)
		var ko_track: Dictionary = {}
		var combat_events = test_bm._combat.process_reaction_queue(test_bm, ko_track)

		_assert_ok(target_enemy.current_hp <= 0, "Primary target killed by lethal attack")
		_assert_ok(adj_enemy.current_hp == 7, "Adjacent enemy took 3 static collateral damage on primary target death (10 -> 7)")
		_assert_ok(test_bm.get_gacha_tokens() == 2, "Zephyrcrisp spent 1 token on attack (3 -> 2)")

		var dmg_event: CombatEvent = null
		for ev in combat_events:
			if ev.type == CombatEvent.Type.DAMAGE and ev.target_uuids.has(target_enemy.ball_uuid):
				dmg_event = ev
				break
		_assert_ok(dmg_event != null, "Damage event found for target enemy")
		if dmg_event != null:
			_assert_ok(dmg_event.visual_payload.apply_static, "Static is applied directly on the attack itself")
			_assert_ok(dmg_event.visual_payload.targets_new_static.size() > 0 and dmg_event.visual_payload.targets_new_static[0] > 0, "Static stacks recorded in attack payload")

		test_bm._state.bm_remove_instance(zephyr_unit.ball_uuid)
		test_bm._state.bm_remove_instance(target_enemy.ball_uuid)
		test_bm._state.bm_remove_instance(adj_enemy.ball_uuid)

	# Knockout Processor integration: item_study_pouch and ?NovPla on death
	var pouch_holder := GachaBallInstance.new()
	var pouch_holder_def: GachaBallDefinition = Database.units.get(&"ASpeFod")
	pouch_holder.initialize(pouch_holder_def)
	test_bm._state.bm_add_instance(pouch_holder, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 1)

	var pouch_item := GachaBallInstance.new()
	var pouch_def: GachaBallDefinition = Database.items.get(&"item_study_pouch")
	pouch_item.initialize(pouch_def)
	var eq_res = InventoryOperations.register_and_equip_item(test_bm._state, pouch_item, pouch_holder.ball_uuid, 0)
	_assert_ok(eq_res.success, "item_study_pouch equipped successfully")

	var tokens_before_pouch_ko = test_bm.get_gacha_tokens()
	pouch_holder.current_hp = 0
	var pouch_ko_events: Array[CombatEvent] = []
	var pouch_death_tracking: Dictionary = {}
	KnockoutProcessor.check_for_knockouts_with_counter_delay(true, pouch_ko_events, pouch_death_tracking, test_bm)
	KnockoutProcessor.process_completed_counter_knockouts(pouch_ko_events, pouch_death_tracking, test_bm)
	var pouch_cascade_evts = test_bm.drain_cascade()
	pouch_ko_events.append_array(pouch_cascade_evts)

	_assert_ok(test_bm.get_gacha_tokens() == tokens_before_pouch_ko + pouch_holder_def.tier, "item_study_pouch grants tokens equal to holder tier on knockout")

	# ?NovPla knockout minigame timer bonus
	test_unit.current_hp = 0
	var novpla_ko_events: Array[CombatEvent] = []
	var novpla_death_tracking: Dictionary = {}
	KnockoutProcessor.check_for_knockouts_with_counter_delay(true, novpla_ko_events, novpla_death_tracking, test_bm)
	KnockoutProcessor.process_completed_counter_knockouts(novpla_ko_events, novpla_death_tracking, test_bm)
	var novpla_cascade_evts = test_bm.drain_cascade()
	novpla_ko_events.append_array(novpla_cascade_evts)

	var novpla_bonus = test_bm.consume_next_minigame_bonus_time()
	_assert_ok(is_equal_approx(novpla_bonus, float(test_unit.level)), "?NovPla adds bonus minigame time equal to level on knockout")

	# FW??NovAni (Steampaw) knockout minigame timer bonus + tokens
	var steampaw_inst := GachaBallInstance.new()
	var steampaw_def: GachaBallDefinition = Database.units.get(&"FW??NovAni")
	steampaw_inst.initialize(steampaw_def)
	steampaw_inst.level = 2
	test_bm._state.bm_add_instance(steampaw_inst, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 2)
	var tokens_before_sp = test_bm.get_gacha_tokens()
	steampaw_inst.current_hp = 0
	var sp_ko_events: Array[CombatEvent] = []
	var sp_death_tracking: Dictionary = {}
	KnockoutProcessor.check_for_knockouts_with_counter_delay(true, sp_ko_events, sp_death_tracking, test_bm)
	KnockoutProcessor.process_completed_counter_knockouts(sp_ko_events, sp_death_tracking, test_bm)
	var sp_cascade = test_bm.drain_cascade()
	sp_ko_events.append_array(sp_cascade)

	var sp_bonus = test_bm.consume_next_minigame_bonus_time()
	_assert_ok(is_equal_approx(sp_bonus, 2.0), "FW??NovAni adds bonus minigame time equal to level on knockout")
	_assert_ok(test_bm.get_gacha_tokens() == tokens_before_sp + 2, "FW??NovAni grants tokens equal to level on knockout")

	# W??ANovCos (Stormshroud) heal on hurt (spends 1 token, heals for level * tokens before spend)
	var stormshroud_inst := GachaBallInstance.new()
	var stormshroud_def: GachaBallDefinition = Database.units.get(&"W??ANovCos")
	stormshroud_inst.initialize(stormshroud_def)
	stormshroud_inst.level = 2
	stormshroud_inst.current_hp = 2
	test_bm._state.bm_add_instance(stormshroud_inst, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 3)
	test_bm._state.set_gacha_tokens(3)
	TurnAbilities.trigger_on_hurt(stormshroud_inst.ball_uuid, 1, "mock_enemy", "PLAYER", stormshroud_inst.current_hp, &"melee")
	test_bm.drain_cascade()
	_assert_ok(test_bm.get_gacha_tokens() == 2, "Stormshroud spent 1 token on hurt (3 -> 2)")
	_assert_ok(stormshroud_inst.current_hp == 2 + (3 * 2), "Stormshroud healed 3 tokens * level 2 = 6 HP (2 + 6 = 8 HP)")

	# W?NovCos (Tidecloak) heal on hurt (heals for int(tokens / 2) * level, costs 0 tokens)
	var tidecloak_inst := GachaBallInstance.new()
	var tidecloak_def: GachaBallDefinition = Database.units.get(&"W?NovCos")
	tidecloak_inst.initialize(tidecloak_def)
	tidecloak_inst.level = 1
	tidecloak_inst.current_hp = 1
	test_bm._state.bm_add_instance(tidecloak_inst, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 4)
	# Tokens are currently 2
	TurnAbilities.trigger_on_hurt(tidecloak_inst.ball_uuid, 1, "mock_enemy", "PLAYER", tidecloak_inst.current_hp, &"melee")
	test_bm.drain_cascade()
	_assert_ok(test_bm.get_gacha_tokens() == 2, "Tidecloak does not spend tokens")
	_assert_ok(tidecloak_inst.current_hp == 1 + (int(2 / 2) * 1), "Tidecloak healed int(2 / 2) * 1 = 1 HP (1 + 1 = 2 HP)")

	# Encounter-scoped bonus minigame time reset on battle exit
	test_bm.add_next_minigame_bonus_time(3.5)
	_assert_ok(test_bm.get_next_minigame_bonus_time() == 3.5, "Bonus minigame time added during battle")
	test_bm.queue_free()
	GameManager.unregister_battle_manager()
	await get_tree().process_frame

	var next_bm = BattleManagerScript.new()
	add_child(next_bm)
	next_bm.add_to_group("battle_manager")
	GameManager.register_battle_manager(next_bm)
	var carried_time = next_bm.consume_next_minigame_bonus_time()
	_assert_ok(is_equal_approx(carried_time, 0.0), "Bonus minigame time does NOT carry over across encounters; resets to 0 on exit")
	next_bm.queue_free()
	GameManager.unregister_battle_manager()

	GameManager.run_state = old_rs

	# Novice Crest 3-Token Floor verification (Trinket-bound, works on any hero)
	var fm_test_rs := RunState.new()
	fm_test_rs.initialize_run(&"hero_avenger", &"")
	GameManager.run_state = fm_test_rs
	FlashcardManager._run_state_ref = fm_test_rs
	FlashcardManager.is_session_active = true
	FlashcardManager.tokens_earned = 1
	FlashcardManager._on_minigame_complete(1, 0)
	_assert_ok(FlashcardManager.tokens_earned == 1, "Without Novice Crest, tokens earned remain 1 (no floor)")

	# Equip Novice Crest
	var crest_def: TrinketDefinition = Database.trinkets.get(&"trinket_trait_novice")
	var crest_inst := GachaBallInstance.new()
	crest_inst.initialize_from_trinket(crest_def)
	fm_test_rs.add_instance(crest_inst, RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS, -1)
	FlashcardManager.is_session_active = true
	FlashcardManager.tokens_earned = 1
	FlashcardManager._on_minigame_complete(1, 0)
	_assert_ok(FlashcardManager.tokens_earned == 3, "With Novice Crest, tokens earned are floored to 3 (even on non-Dan hero)")

	# Dan's Soul Harvest: 100% dead ally PWR absorption
	var harvest_effect := EffectGainDeadAllyPwrAsHPScript.new()
	var test_hero_inst := GachaBallInstance.new()
	test_hero_inst.initialize(hero_dan)
	test_hero_inst.current_hp = 10
	var dead_ally_inst := GachaBallInstance.new()
	var test_ally_def: GachaBallDefinition = Database.units.get(&"?NovPla")
	dead_ally_inst.initialize(test_ally_def)
	dead_ally_inst.current_pwr = 4
	var harvest_bm = BattleManagerScript.new()
	add_child(harvest_bm)
	harvest_bm.add_to_group("battle_manager")
	GameManager.register_battle_manager(harvest_bm)
	harvest_bm._state.bm_add_instance(test_hero_inst, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 0)
	harvest_bm._state.bm_add_instance(dead_ally_inst, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 1)
	var harvest_ctx := TriggerContext.new()
	harvest_ctx.ally_knocked_out_uuid = dead_ally_inst.ball_uuid
	harvest_ctx.ally_knocked_out_pwr = 4
	var h_res = harvest_effect.execute(test_hero_inst.ball_uuid, [], harvest_bm, harvest_ctx)
	_assert_ok(h_res.state_applied, "Soul Harvest effect applied")
	_assert_ok(test_hero_inst.current_hp == 14, "Soul Harvest grants 100% PWR (10 + 4 = 14 HP)")
	# Novice Emblem on_knockout_blow minigame timer bonus
	var emblem_holder := GachaBallInstance.new()
	var emblem_holder_def: GachaBallDefinition = Database.units.get(&"ASpeFod")
	emblem_holder.initialize(emblem_holder_def)
	harvest_bm._state.bm_add_instance(emblem_holder, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 2)
	var emblem_item := GachaBallInstance.new()
	var emblem_item_def: GachaBallDefinition = Database.items.get(&"item_novice_emblem")
	emblem_item.initialize(emblem_item_def)
	var emblem_eq = InventoryOperations.register_and_equip_item(harvest_bm._state, emblem_item, emblem_holder.ball_uuid, 0)
	_assert_ok(emblem_eq.success, "item_novice_emblem equipped successfully")
	var killed_enemy := GachaBallInstance.new()
	killed_enemy.initialize(emblem_holder_def)
	harvest_bm._state.bm_add_instance(killed_enemy, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, 0)
	harvest_bm.trigger_on_kill(emblem_holder.ball_uuid, killed_enemy.ball_uuid)
	harvest_bm._combat.drain_cascade(harvest_bm)
	var emblem_bonus = harvest_bm.consume_next_minigame_bonus_time()
	_assert_ok(is_equal_approx(emblem_bonus, 1.0), "Novice Emblem adds 1.0 second on knockout blow")

	# EffectAddNextMinigameTimeOnDeath bonus verification
	var death_effect := EffectAddNextMinigameTimeOnDeath.new()
	var death_ctx := TriggerContext.new()
	death_ctx.source_level = 2
	var d_res = death_effect.execute("mock_uuid", [], harvest_bm, death_ctx)
	_assert_ok(d_res.state_applied, "EffectAddNextMinigameTimeOnDeath applied")
	_assert_ok(is_equal_approx(harvest_bm.consume_next_minigame_bonus_time(), 2.0), "EffectAddNextMinigameTimeOnDeath adds seconds equal to level (2.0s)")

	# Simulation event emission test (Unit knockout)
	var sim_death_ctx := TriggerContext.new()
	sim_death_ctx.source_level = 3
	sim_death_ctx.is_simulation = true
	var sim_res = death_effect.execute("unit_uuid_abc", [], harvest_bm, sim_death_ctx)
	_assert_ok(sim_res.state_applied, "EffectAddNextMinigameTimeOnDeath applied in simulation")
	var timer_events = sim_res.events.filter(func(e): return e.type == CombatEvent.Type.TIMER_BONUS)
	_assert_ok(timer_events.size() == 1, "TIMER_BONUS event emitted in simulation")
	_assert_ok(timer_events[0].visual_payload.amount == 3, "TIMER_BONUS amount is 3 for level 3 unit")
	_assert_ok(timer_events[0].visual_payload.origin_uuid == "unit_uuid_abc", "TIMER_BONUS origin_uuid is source unit")
	_assert_ok(is_equal_approx(timer_events[0].visual_payload.target_bonus_time, 3.0), "TIMER_BONUS target_bonus_time matches total bonus time")
	harvest_bm.consume_next_minigame_bonus_time()

	# Simulation event emission test (Item holder kill)
	var kill_effect := EffectAddNextMinigameTimeOnKill.new()
	var kill_ctx := TriggerContext.new()
	kill_ctx.source_holder_uuid = "holder_uuid_xyz"
	kill_ctx.is_simulation = true
	var k_res = kill_effect.execute("item_uuid_123", [], harvest_bm, kill_ctx)
	_assert_ok(k_res.state_applied, "EffectAddNextMinigameTimeOnKill applied in simulation")
	var kill_timer_events = k_res.events.filter(func(e): return e.type == CombatEvent.Type.TIMER_BONUS)
	_assert_ok(kill_timer_events.size() == 1, "TIMER_BONUS event emitted by Novice Emblem in simulation")
	_assert_ok(kill_timer_events[0].visual_payload.amount == 1, "Novice Emblem adds 1 second")
	_assert_ok(kill_timer_events[0].visual_payload.origin_uuid == "holder_uuid_xyz", "Novice Emblem origin_uuid is item holder")
	harvest_bm.consume_next_minigame_bonus_time()

	# Projectile visual text test
	var proj = preload("res://scenes/vfx/BuffNumberProjectile.tscn").instantiate()
	proj.setup(2, "timer", Vector2.ZERO, Vector2(100, 100), false)
	_assert_ok(proj.label.text == "+2s", "BuffNumberProjectile formats timer value as +2s")
	proj.free()

	# Novice Trait Bronze verification (+1.0s to minigame when 2+ Novices active)
	harvest_bm._state.bm_add_instance(crest_inst, C.BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS, -1)
	var second_novice := GachaBallInstance.new()
	second_novice.initialize(test_ally_def)
	harvest_bm._state.bm_add_instance(second_novice, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 3)
	var novice_traits: Dictionary = harvest_bm.get_active_traits("PLAYER")
	_assert_ok(int(novice_traits.get("NOVICE", 0)) >= 2, "2 Novices active on player lineup")
	_assert_ok(is_equal_approx(harvest_bm.get_total_next_minigame_bonus_time(), 1.0), "Novice Bronze trait contributes 1.0s to total minigame bonus time")

	# Top UI Bonus Timer Widget: Hierarchy, Sequence, and Visibility
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	var token_group: Control = main_scene.get_node("%TokenGroup")
	var bonus_group: Control = main_scene.get_node("%BonusTimerGroup")
	var bonus_lbl: Label = main_scene.get_node("%BonusTimerLabel")
	var sandclock_icon: TextureRect = main_scene.get_node("%SandclockIcon")
	var gold_group: Control = main_scene.get_node("%GoldGroup")
	var token_icon: TextureRect = main_scene.get_node("%TokenIcon")
	var tokens_lbl: Label = main_scene.get_node("%TokensLabel")

	_assert_ok(bonus_group.get_parent() == token_group, "BonusTimerGroup must be a child of TokenGroup to stay to its right")
	_assert_ok(gold_group.get_index() < token_group.get_index(), "GoldGroup must be to the left of TokenGroup in LeftStats")
	_assert_ok(token_icon.get_index() < tokens_lbl.get_index(), "TokenIcon must be to the left of TokensLabel in TokenGroup")
	_assert_ok(tokens_lbl.get_index() < bonus_group.get_index(), "TokensLabel must be to the left of BonusTimerGroup in TokenGroup")
	_assert_ok(sandclock_icon.get_index() < bonus_lbl.get_index(), "SandclockIcon must be to the left of BonusTimerLabel in BonusTimerGroup")
	_assert_ok(not bonus_group.visible, "BonusTimerGroup must be hidden when bonus time is 0")

	# In battle: Update bonus time to 2.0s
	GameManager.is_in_battle = true
	main_scene._on_minigame_bonus_time_changed(2.0)
	_assert_ok(bonus_group.visible, "BonusTimerGroup must be visible when in battle and bonus time > 0")
	_assert_ok(bonus_lbl.text == "+2s", "BonusTimerLabel text must format integer seconds cleanly (+2s)")

	# Bonus timer animation bracket lock test
	main_scene.begin_bonus_timer_animation()
	_assert_ok(main_scene._bonus_timer_animations_in_flight == 1, "Bonus timer animation lock active")
	main_scene._on_minigame_bonus_time_changed(5.0)
	_assert_ok(bonus_lbl.text == "+2s", "BonusTimerLabel does not update prematurely while projectile in flight")
	main_scene.modify_visual_bonus_timer(1.0, false)
	_assert_ok(bonus_lbl.text == "+3s", "BonusTimerLabel updates exactly when visual timer modified on landing")
	main_scene.end_bonus_timer_animation()
	_assert_ok(main_scene._bonus_timer_animations_in_flight == 0, "Bonus timer animation lock released")

	# Exiting battle: Battle ended / state changed to false clears bonus time and hides timer
	harvest_bm.add_next_minigame_bonus_time(3.0)
	_assert_ok(harvest_bm.get_next_minigame_bonus_time() > 0.0, "Bonus time added during battle")
	harvest_bm.clear_next_minigame_bonus_time()
	_assert_ok(harvest_bm.get_next_minigame_bonus_time() == 0.0, "clear_next_minigame_bonus_time resets bonus time to 0")

	GameManager._on_battle_ended({"victory": true})
	_assert_ok(not GameManager.is_in_battle, "GameManager.is_in_battle must be false after battle ends")
	main_scene._on_battle_state_changed(false)
	_assert_ok(not bonus_group.visible, "BonusTimerGroup must be hidden outside of battle")

	main_scene.free()
	harvest_bm.queue_free()
	GameManager.unregister_battle_manager()

	# ----------------------------------------------------
	# Dynamic Hero Pack Tags & Elemental Crest Regression Tests
	# ----------------------------------------------------
	var dynamic_rs := RunState.new()
	dynamic_rs.initialize_run(&"hero_starter", &"hiragana")
	GameManager.run_state = dynamic_rs

	var rolled_elem: StringName = dynamic_rs.hero_element
	_assert_ok(not rolled_elem.is_empty(), "RunState.hero_element must be non-empty upon run initialization")
	var nov_def: GachaBallDefinition = Database.units[&"?NovPla"]
	_assert_ok(nov_def.tags.has(&"?"), "Database.units['?NovPla'].tags must remain unmutated on disk/flyweight ([?])")
	_assert_ok(not nov_def.tags.has(rolled_elem), "Database.units['?NovPla'].tags must NOT be directly mutated")

	var nov_inst := GachaBallInstance.new()
	nov_inst.initialize(nov_def)
	var active_nov_tags := nov_inst.get_active_tags(dynamic_rs.get_all_instances())
	_assert_ok(active_nov_tags.has(rolled_elem), "Novice instance must inherit dynamic hero element (%s) via RunState" % rolled_elem)

	# Save/Load roundtrip verification
	var save_dict := dynamic_rs.to_save_dict()
	var restored_rs := RunState.new()
	restored_rs.from_save_dict(save_dict)
	GameManager.run_state = restored_rs
	_assert_ok(restored_rs.hero_element == rolled_elem, "Restored RunState must preserve hero_element across save/load")
	_assert_ok(restored_rs.dynamic_tag_overrides.has(&"?NovPla"), "Restored RunState must re-adapt dynamic_tag_overrides")

	var restored_nov_inst := GachaBallInstance.new()
	restored_nov_inst.initialize(nov_def)
	var restored_tags := restored_nov_inst.get_active_tags(restored_rs.get_all_instances())
	_assert_ok(restored_tags.has(rolled_elem), "Novice instance under restored RunState must retain hero element (%s)" % rolled_elem)

	# Trait Crest Trinket Count Test (Hero's 3 souls counted outside & inside battle)
	var hero_souls_dict := restored_rs.hero_instance.get_trait_soul_counts(restored_rs.get_all_instances())
	var elem_key := String(rolled_elem).trim_prefix("SOUL_")
	_assert_ok(hero_souls_dict.get(elem_key, 0) == 3, "Hero must have 3 elemental souls of %s" % elem_key)

	var gb_view := preload("res://scenes/GachaBallView.tscn").instantiate()
	add_child(gb_view)
	var run_count: int = gb_view._get_run_trait_count_for_view(elem_key)
	_assert_ok(run_count >= 3, "_get_run_trait_count_for_view must count hero's 3 souls (got %d)" % run_count)
	gb_view.queue_free()

	GameManager.run_state = old_rs

# ==============================================================================
# SUITE 8 IMPLEMENTATION (Alternating Action Order & Highest-Rank Summon Placement)
# ==============================================================================
func _run_suite_8_alternating_initiative() -> void:
	# 1. Action step mapping
	# Enemy: 0, 1, 2, 3, 4 -> 0, 2, 4, 6, 8
	# Player: 4, 3, 2, 1, 0 -> 1, 3, 5, 7, 9
	_assert_ok(CombatSimulator.get_unit_action_step(0, false) == 0, "Enemy Slot 0 is step 0")
	_assert_ok(CombatSimulator.get_unit_action_step(4, true) == 1, "Player Slot 4 is step 1")
	_assert_ok(CombatSimulator.get_unit_action_step(1, false) == 2, "Enemy Slot 1 is step 2")
	_assert_ok(CombatSimulator.get_unit_action_step(3, true) == 3, "Player Slot 3 is step 3")
	_assert_ok(CombatSimulator.get_unit_action_step(2, false) == 4, "Enemy Slot 2 is step 4")
	_assert_ok(CombatSimulator.get_unit_action_step(2, true) == 5, "Player Slot 2 is step 5")
	_assert_ok(CombatSimulator.get_unit_action_step(3, false) == 6, "Enemy Slot 3 is step 6")
	_assert_ok(CombatSimulator.get_unit_action_step(1, true) == 7, "Player Slot 1 is step 7")
	_assert_ok(CombatSimulator.get_unit_action_step(4, false) == 8, "Enemy Slot 4 is step 8")
	_assert_ok(CombatSimulator.get_unit_action_step(0, true) == 9, "Player Slot 0 is step 9")

	# 2. Populate queue with all 10 slots
	var state := BattleState.new()
	var def: GachaBallDefinition = Database.units.get(&"?NovPla")
	var player_units: Array[GachaBallInstance] = []
	var enemy_units: Array[GachaBallInstance] = []

	for i in range(5):
		var p_unit := GachaBallInstance.new()
		p_unit.initialize(def)
		p_unit.current_hp = 5
		state.bm_add_instance(p_unit, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, i)
		player_units.append(p_unit)

		var e_unit := GachaBallInstance.new()
		e_unit.initialize(def)
		e_unit.current_hp = 5
		state.bm_add_instance(e_unit, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, i)
		enemy_units.append(e_unit)

	var sim := CombatSimulator.new()
	sim.populate_actor_queue(state)
	var queue := sim.get_actor_queue()

	_assert_ok(queue.size() == 10, "All 10 units queued")
	var expected_order: Array[GachaBallInstance] = [
		enemy_units[0], player_units[4],
		enemy_units[1], player_units[3],
		enemy_units[2], player_units[2],
		enemy_units[3], player_units[1],
		enemy_units[4], player_units[0]
	]
	_assert_ok(queue == expected_order, "Queue follows strict alternating rank order starting with enemy")

	# 3. User Scenario: 2 front vs 2 back
	# Team A (Player) in front two slots (slots 4, 3)
	# Team B (Enemy) in back two slots (slots 3, 4)
	var state_ab := BattleState.new()
	var p4 := GachaBallInstance.new()
	p4.initialize(def)
	p4.current_hp = 5
	state_ab.bm_add_instance(p4, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 4)

	var p3 := GachaBallInstance.new()
	p3.initialize(def)
	p3.current_hp = 5
	state_ab.bm_add_instance(p3, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 3)

	var e3 := GachaBallInstance.new()
	e3.initialize(def)
	e3.current_hp = 5
	state_ab.bm_add_instance(e3, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, 3)

	var e4 := GachaBallInstance.new()
	e4.initialize(def)
	e4.current_hp = 5
	state_ab.bm_add_instance(e4, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, 4)

	var sim_ab := CombatSimulator.new()
	sim_ab.populate_actor_queue(state_ab)
	var queue_ab := sim_ab.get_actor_queue()
	_assert_ok(queue_ab == [p4, p3, e3, e4], "Frontloaded Player units act before backloaded Enemy units")

	# 4. Highest-rank summon slot search
	var p_lineup := state.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var e_lineup := state.get_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)

	# When all are full, returns -1
	_assert_ok(EffectHandlers.find_best_summon_slot(p_lineup, true) == -1, "Full player lineup returns -1")
	_assert_ok(EffectHandlers.find_best_summon_slot(e_lineup, false) == -1, "Full enemy lineup returns -1")

	# Create a sparse container
	var sparse_state := BattleState.new()
	var sp_p_lineup := sparse_state.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var sp_e_lineup := sparse_state.get_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)

	# Empty lineup: Player finds Slot 4 (Rank 0), Enemy finds Slot 0 (Rank 0)
	_assert_ok(EffectHandlers.find_best_summon_slot(sp_p_lineup, true) == 4, "Empty player lineup finds Slot 4 (frontmost)")
	_assert_ok(EffectHandlers.find_best_summon_slot(sp_e_lineup, false) == 0, "Empty enemy lineup finds Slot 0 (frontmost)")

	# If Slot 4 is taken, Player finds Slot 3
	sparse_state.bm_add_instance(p4, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 4)
	_assert_ok(EffectHandlers.find_best_summon_slot(sp_p_lineup, true) == 3, "Player lineup finds Slot 3 when Slot 4 is taken")

	# If Slot 0 is taken, Enemy finds Slot 1
	var e0 := GachaBallInstance.new()
	e0.initialize(def)
	e0.current_hp = 5
	sparse_state.bm_add_instance(e0, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, 0)
	_assert_ok(EffectHandlers.find_best_summon_slot(sp_e_lineup, false) == 1, "Enemy lineup finds Slot 1 when Slot 0 is taken")

	# 5. Mid-turn summon insertion into queue
	var summon_state := BattleState.new()
	# Suppose current_turn_step is 2 (Enemy Slot 1 has acted)
	sim.set("_current_turn_step", 2)
	var callback = func(unit: GachaBallInstance) -> bool:
		return unit.location_container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP

	# Summon in Player Slot 4 (step 1) -> should be rejected because step 1 <= 2
	var summon_p4 := GachaBallInstance.new()
	summon_p4.initialize(def)
	summon_p4.current_hp = 5
	summon_state.bm_add_instance(summon_p4, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 4)
	var prev_q_size = sim.actor_queue_size()
	sim.insert_summoned_unit(summon_p4, true, callback)
	_assert_ok(sim.actor_queue_size() == prev_q_size, "Summon in already-acted slot (step 1 <= 2) is not queued")

	# Summon in Player Slot 2 (step 5) -> should be accepted because step 5 > 2
	var summon_p2 := GachaBallInstance.new()
	summon_p2.initialize(def)
	summon_p2.current_hp = 5
	summon_state.bm_add_instance(summon_p2, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 2)
	sim.insert_summoned_unit(summon_p2, true, callback)
	_assert_ok(sim.actor_queue_size() == prev_q_size + 1, "Summon in future slot (step 5 > 2) is queued")
	_assert_ok(sim.get_actor_queue().has(summon_p2), "Summoned unit is present in actor queue")

	# 6. Shelf summon slot search (Left to Right: 0 -> Size - 1)
	var shelf_state := BattleState.new()
	shelf_state.player_shelf_slots_unlocked = C.SHELF_CAP
	var p_shelf := shelf_state.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF)
	var e_shelf := shelf_state.get_container(C.BATTLE_CONTAINER_TAGS.ENEMY_SHELF)

	# Empty shelf: Player and Enemy both find Slot 0 (leftmost)
	_assert_ok(EffectHandlers.find_best_summon_slot(p_shelf, true) == 0, "Empty player shelf finds Slot 0 (leftmost)")
	_assert_ok(EffectHandlers.find_best_summon_slot(e_shelf, false) == 0, "Empty enemy shelf finds Slot 0 (leftmost)")

	# If Slot 0 is taken, Player finds Slot 1
	var b0 := GachaBallInstance.new()
	b0.initialize(def)
	shelf_state.bm_add_instance(b0, C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF, 0)
	_assert_ok(EffectHandlers.find_best_summon_slot(p_shelf, true) == 1, "Player shelf finds Slot 1 when Slot 0 is taken")

	# If Slots 0 and 2 are taken, Player finds Slot 1 (first available from left to right)
	var b2 := GachaBallInstance.new()
	b2.initialize(def)
	shelf_state.bm_add_instance(b2, C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF, 2)
	_assert_ok(EffectHandlers.find_best_summon_slot(p_shelf, true) == 1, "Player shelf finds Slot 1 when Slots 0 and 2 are taken")

	# If Slots 0 through 6 are taken, Player finds Slot 7 (rightmost)
	for i in range(1, 7):
		if i == 2:
			continue
		var bi := GachaBallInstance.new()
		bi.initialize(def)
		shelf_state.bm_add_instance(bi, C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF, i)
	_assert_ok(EffectHandlers.find_best_summon_slot(p_shelf, true) == 7, "Player shelf finds Slot 7 when Slots 0-6 are taken")

	# If all 8 slots are taken, returns -1
	var b7 := GachaBallInstance.new()
	b7.initialize(def)
	shelf_state.bm_add_instance(b7, C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF, 7)
	_assert_ok(EffectHandlers.find_best_summon_slot(p_shelf, true) == -1, "Full player shelf returns -1")

	# 7. End-to-end Recruiting Charm shelf summon (left to right placement)
	var recruit_bm = BattleManagerScript.new()
	add_child(recruit_bm)
	recruit_bm.add_to_group("battle_manager")
	GameManager.register_battle_manager(recruit_bm)

	var recruit_rs = RunState.new()
	recruit_rs.initialize_run(&"hero_bounty_hunter", &"deck_nihongo_starter", "REGULAR", "FULL")
	recruit_rs.gold = 5
	var old_rs_rec = GameManager.run_state
	GameManager.run_state = recruit_rs

	var recruiting_effect: EffectDefinition = Database.trinkets[&"trinket_recruiting_charm"].ability_definitions[0].effects[0]
	var recruit_ctx := TriggerContext.new()
	recruit_ctx.is_simulation = true
	recruit_ctx.trigger_type = C.TRIGGER_AT_TURN_START

	# First summon: Shelf is empty, so Coinling must be placed in Slot 0 (leftmost)
	var res1 := recruiting_effect.execute("trinket_uuid", [], recruit_bm, recruit_ctx)
	_assert_ok(res1.state_applied and not res1.summon_units_request.is_empty(), "Recruiting Charm executes with gold and open shelf")
	_assert_ok(res1.summon_container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF, "Recruiting Charm targets PlayerShelf")
	
	var cmd1 := SummonUnitsCommand.new(EffectRequest.new("trinket_uuid", &"ability_trinket_recruiting_charm", recruiting_effect, [], recruit_ctx), sim, recruit_bm, res1)
	var out_evts1: Array[CombatEvent] = []
	var death_track1: Dictionary = {}
	cmd1.execute(out_evts1, death_track1)

	var placed_uuid1: String = recruit_bm.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF).get_uuid(0)
	_assert_ok(not placed_uuid1.is_empty(), "First Coinling placed in shelf Slot 0 (leftmost)")
	var placed_unit1: GachaBallInstance = recruit_bm.get_instance_by_uuid(placed_uuid1)
	_assert_ok(placed_unit1 != null and placed_unit1.definition_id == &"?MerSpe", "Placed unit in Slot 0 is Coinling (?MerSpe)")

	# Second summon: Slot 0 occupied, so next Coinling must be placed in Slot 1
	var res2 := recruiting_effect.execute("trinket_uuid", [], recruit_bm, recruit_ctx)
	var cmd2 := SummonUnitsCommand.new(EffectRequest.new("trinket_uuid", &"ability_trinket_recruiting_charm", recruiting_effect, [], recruit_ctx), sim, recruit_bm, res2)
	var out_evts2: Array[CombatEvent] = []
	var death_track2: Dictionary = {}
	cmd2.execute(out_evts2, death_track2)

	var placed_uuid2: String = recruit_bm.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF).get_uuid(1)
	_assert_ok(not placed_uuid2.is_empty(), "Second Coinling placed in shelf Slot 1 (left to right)")
	var placed_unit2: GachaBallInstance = recruit_bm.get_instance_by_uuid(placed_uuid2)
	_assert_ok(placed_unit2 != null and placed_unit2.definition_id == &"?MerSpe", "Placed unit in Slot 1 is Coinling (?MerSpe)")
	_assert_ok(recruit_rs.gold == 3, "2 Gold spent for 2 hires (5 - 2 = 3)")

	# 5. Fire Banner Free Fire Crest Check
	var fire_drafter := FireBannerDrafter.new()
	var fire_enc_low: EncounterDefinition = fire_drafter.draft_lineup(3)
	_assert_ok(fire_enc_low.banner_trinket_id == &"trinket_banner_fire_phalanx", "Low budget banner ID is trinket_banner_fire_phalanx")
	_assert_ok(fire_enc_low.enemy_trinket_ids.has(&"trinket_trait_fire"), "Fire Banner gives Fire Crest for free at low budget (3G)")
	_assert_ok(fire_enc_low.enemy_placements.size() >= 2, "Lineup has core units drafted without 5G deduction")

	var fire_enc_high: EncounterDefinition = fire_drafter.draft_lineup(15)
	_assert_ok(fire_enc_high.banner_trinket_id == &"trinket_banner_fire_phalanx", "High budget banner ID is trinket_banner_fire_phalanx")
	_assert_ok(fire_enc_high.enemy_trinket_ids.has(&"trinket_trait_fire"), "Fire Banner gives Fire Crest for free at high budget (15G)")

	GameManager.run_state = old_rs_rec
	recruit_bm.queue_free()
	GameManager.unregister_battle_manager()
