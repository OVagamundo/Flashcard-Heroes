extends Node

const C = preload("res://scripts/Constants.gd")
const BattleManagerScript = preload("res://scripts/BattleManager.gd")
const EffectTransferItemBehindScript = preload("res://scripts/EffectTransferItemBehind.gd")

func _assert_ok(cond: bool, msg: String) -> void:
	if not cond:
		push_error("ASSERTION FAILED: " + msg)
		get_tree().quit(1)

func _make_equipped_loc(unit_uuid: String, slot_idx: int = 0) -> LocationIdentifier:
	var loc := LocationIdentifier.new(C.CONTAINER_EQUIPPED_ITEM, slot_idx)
	loc.unit_uuid = unit_uuid
	return loc

func _ready() -> void:
	print("=== Starting Atomic State Verification Suite ===")

	# ----------------------------------------------------------------------
	# TEST 1: RunState atomic operations, Hero slot movement, Equip/Swap/Merge with full bench
	# ----------------------------------------------------------------------
	print("[1/7] Testing RunState atomic operations & Hero slot preservation...")
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
		if d.category == &"UNIT" and inst.definition_id == &"ETnkPlaToy":
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

	# Move it2 to PlayerBench:0, swap equipped it1 <-> bench it2 in BOTH directions, then move equipped item to empty bench slot
	_assert_ok(rs.move_instance(it2.get_location(), LocationIdentifier.new(&"PlayerBench", 0)), "Move it2 to PlayerBench:0")
	var hero_eq_loc := _make_equipped_loc(hero.ball_uuid, 0)
	var bench0_loc := LocationIdentifier.new(&"PlayerBench", 0)
	_assert_ok(rs.swap_instances(bench0_loc, hero_eq_loc), "Swap bench -> equipped in RunState")
	_assert_ok(hero.equipped_item_uuids[0] == it2.ball_uuid and rs.get_container(&"PlayerBench").get_uuid(0) == it1.ball_uuid, "Swap 1 verified")
	_assert_ok(rs.swap_instances(hero_eq_loc, bench0_loc), "Swap equipped -> bench in RunState")
	_assert_ok(hero.equipped_item_uuids[0] == it1.ball_uuid and rs.get_container(&"PlayerBench").get_uuid(0) == it2.ball_uuid, "Swap 2 verified")

	var bench1_loc := LocationIdentifier.new(&"PlayerBench", 1)
	_assert_ok(rs.move_instance(hero_eq_loc, bench1_loc), "Unequip hero item to PlayerBench:1 via move_instance")
	_assert_ok(hero.equipped_item_uuids[0].is_empty() and rs.get_container(&"PlayerBench").get_uuid(1) == it1.ball_uuid, "Hero item unequipped cleanly")
	_assert_ok(rs.equip_item(it1.ball_uuid, hero.ball_uuid, 0), "Re-equip it1 on hero")
	_assert_ok(rs.equip_item(it2.ball_uuid, u1.ball_uuid, 0), "Equip it2 on u1")

	# Fill ALL 5 PlayerBench slots in RunState and test:
	# (a) replacing u1's equipped item from RunInventoryT1 while bench is full -> must reject cleanly WITHOUT corrupting state!
	# (b) merging u1 + u2 on PlayerLineup while PlayerBench is 100% full -> must succeed and preserve it2 on merged unit!
	# (c) merging an item onto an equipped item while PlayerBench is 100% full -> must succeed!
	for slot_i in range(C.BENCH_CAP):
		if rs.get_container(&"PlayerBench").get_uuid(slot_i).is_empty():
			var dummy := GachaBallInstance.new()
			dummy.initialize(Database.get_definition(&"FFigMecApp"))
			_assert_ok(rs.add_instance(dummy, &"PlayerBench", slot_i), "Fill RunState bench slot %d" % slot_i)

	var extra_inv_item := GachaBallInstance.new()
	extra_inv_item.initialize(Database.get_definition(&"item_t1_a"))
	_assert_ok(rs.add_instance(extra_inv_item, &"RunInventoryT1", -1), "Add extra_inv_item to RunInventoryT1")
	var rejected_full_replace := rs.equip_item(extra_inv_item.ball_uuid, u1.ball_uuid, 0)
	_assert_ok(not rejected_full_replace, "RunState.equip_item from non-bench must cleanly reject when bench full")
	_assert_ok(rs._validate_state_consistency(), "RunState consistent after rejected full-bench equip")
	_assert_ok(u1.equipped_item_uuids[0] == it2.ball_uuid, "u1 still holds it2 after rejected replace")

	# Now equip from PlayerBench:0 onto u1 while PlayerBench is full -> frees bench slot 0, so must SUCCEED!
	var bench_item := GachaBallInstance.new()
	bench_item.initialize(Database.get_definition(&"item_claim_ticket"))
	rs.remove_instance(rs.get_container(&"PlayerBench").get_uuid(0))
	_assert_ok(rs.add_instance(bench_item, &"PlayerBench", 0), "Place bench_item at PlayerBench:0")
	_assert_ok(rs.equip_item(bench_item.ball_uuid, u1.ball_uuid, 0), "Equip from full PlayerBench onto equipped u1 must succeed")
	_assert_ok(u1.equipped_item_uuids[0] == bench_item.ball_uuid and it2.location_container_tag == &"PlayerBench", "Swapped old item into freed bench slot")

	# Merge u1 (ETnkPlaToy at Lineup:0 with bench_item) + ?MerSpe at Lineup:1 while PlayerBench is 100% full!
	rs.remove_instance(u2.ball_uuid)
	var mer_unit := GachaBallInstance.new()
	mer_unit.initialize(Database.get_definition(&"?MerSpe"))
	_assert_ok(rs.add_instance(mer_unit, &"PlayerLineup", 1), "Place ?MerSpe at PlayerLineup:1")
	var extra_eq := GachaBallInstance.new()
	extra_eq.initialize(Database.get_definition(&"item_t1_b"))
	_assert_ok(rs.register_and_equip_item(extra_eq, mer_unit.ball_uuid, 0), "register_and_equip_item on mer_unit with full bench")

	InventoryManager._merge(
		LocationIdentifier.new(&"PlayerLineup", 1),
		LocationIdentifier.new(&"PlayerLineup", 0),
		&""
	)
	_assert_ok(rs._validate_state_consistency(), "RunState consistent after full-bench lineup unit merge")
	var merged_lineup_unit := rs.get_instance_by_location(LocationIdentifier.new(&"PlayerLineup", 0))
	_assert_ok(is_instance_valid(merged_lineup_unit) and not merged_lineup_unit.equipped_item_uuids[0].is_empty(), "Merged lineup unit inherited item with full bench")

	# Merge item_t1_a onto bench_item equipped on merged_lineup_unit while PlayerBench is STILL 100% full!
	# First ensure merged_lineup_unit has item_claim_ticket equipped (it had bench_item = item_claim_ticket or extra_eq = item_t1_b)
	var eq_on_merged := rs.get_instance_by_uuid(merged_lineup_unit.equipped_item_uuids[0])
	var partner_def_id := &"item_claim_ticket" if eq_on_merged.definition_id == &"item_t1_b" else &"item_t1_a"
	var merge_src_item := GachaBallInstance.new()
	merge_src_item.initialize(Database.get_definition(partner_def_id))
	_assert_ok(rs.add_instance(merge_src_item, &"RunInventoryT1", -1), "Place partner item in RunInventoryT1")
	InventoryManager._merge(
		merge_src_item.get_location(),
		_make_equipped_loc(merged_lineup_unit.ball_uuid, 0),
		&""
	)
	_assert_ok(rs._validate_state_consistency(), "RunState consistent after full-bench equipped item merge")

	# Clear extra bench dummies so battle test starts with clean bench
	for slot_i in range(C.BENCH_CAP):
		var buuid := rs.get_container(&"PlayerBench").get_uuid(slot_i)
		if not buuid.is_empty():
			rs.remove_instance(buuid)

	# ----------------------------------------------------------------------
	# TEST 2: BattleSetup, Staged Hero at Slot 2, Enemy Entrance w/ Equipment, RunInventory lookup in battle, Victory Hero Slot
	# ----------------------------------------------------------------------
	print("[2/7] Testing BattleSetup, Staged Hero at Slot 2, and Entrance Sequences...")
	var bm = BattleManagerScript.new()
	add_child(bm)
	bm.add_to_group("battle_manager")
	GameManager.register_battle_manager(bm)
	GameManager.is_in_battle = true

	var encounter_def = EncounterGenerator.generate_encounter(1)
	# Ensure at least one enemy placement has 2 items to test both initial equip AND replacement to EnemyGraveyard during entrance!
	if encounter_def.enemy_placements.size() > 0:
		encounter_def.enemy_placements[0]["equipment"] = [&"item_t1_a", &"item_t1_b"]

	bm._setup_battle(encounter_def)
	_assert_ok(bm._bm_validate_state_consistency(), "BattleState consistent immediately after _setup_battle (hero staged)")
	_assert_ok(not bm._state.staged_hero_placement.is_empty(), "Hero is staged before entrance")
	_assert_ok(int(bm._state.staged_hero_placement.get("position", -1)) == 2, "Staged hero remembers PlayerLineup slot 2")
	_assert_ok(not bm._battle_instances.has(bm._state.staged_hero_instance.ball_uuid), "Staged hero not prematurely registered in _battle_instances")

	# Verify GameManager.get_instance_from_location resolves RunInventoryT1 during battle without polluting BattleState!
	var run_t1_probe := GameManager.get_instance_from_location(LocationIdentifier.new(&"RunInventoryT1", 0))
	_assert_ok(bm.get_container(&"RunInventoryT1") == null, "BattleState did not create fake RunInventoryT1 container")
	_assert_ok(run_t1_probe == rs.get_instance_by_location(LocationIdentifier.new(&"RunInventoryT1", 0)), "GameManager routed RunInventoryT1 to RunState during battle")

	await bm.execute_hero_entrance_sequence()
	_assert_ok(bm._bm_validate_state_consistency(), "BattleState consistent after hero entrance")
	var battle_hero := bm.get_instance_by_location(LocationIdentifier.new(&"PlayerLineup", 2))
	_assert_ok(is_instance_valid(battle_hero) and battle_hero.get_definition().is_hero, "Battle hero entered at PlayerLineup:2")
	_assert_ok(not battle_hero.equipped_item_uuids[0].is_empty(), "Battle hero brought equipped item")
	_assert_ok(bm.get_hero_uuid() == battle_hero.ball_uuid, "get_hero_uuid() finds hero at slot 2")

	await bm.execute_enemy_entrance_sequence()
	_assert_ok(bm._bm_validate_state_consistency(), "BattleState consistent after enemy entrance with equipment")
	# Replaced enemy item from 2-item placement should be in EnemyGraveyard, NOT player's DiscardPile!
	_assert_ok(bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE).is_empty(), "Player DiscardPile not polluted by enemy replaced item")

	# Simulate battle victory check on RunState hero slot
	bm._on_battle_victory()
	_assert_ok(rs.hero_instance.location_slot_index == 2, "RunState hero remained at PlayerLineup:2 after _on_battle_victory()")
	_assert_ok(rs._validate_state_consistency(), "RunState still consistent after _on_battle_victory()")

	# ----------------------------------------------------------------------
	# TEST 3: Gacha Draws, Bench Overflow to Discard, Draw from Discard, Reshuffle, Selective Penalty Reshuffle
	# ----------------------------------------------------------------------
	print("[3/7] Testing Gacha Draws, Bench Overflow, Discard Draw, and Reshuffles...")
	bm.add_gacha_tokens(50)
	var draw_count := 0
	while true:
		var evts = bm.bm_draw_gacha_instance(1)
		if evts.is_empty():
			break
		draw_count += 1
		_assert_ok(bm._bm_validate_state_consistency(), "Consistent after draw #%d" % draw_count)
	_assert_ok(draw_count > C.BENCH_CAP, "Drew enough balls to overflow PlayerBench into DiscardPile")
	_assert_ok(bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE).size() > 0, "Overflow balls went to DiscardPile")

	# Draw from discard back to tier tray
	var discard_draw_evts: Array[CombatEvent] = bm.bm_draw_from_discard()
	_assert_ok(not discard_draw_evts.is_empty(), "bm_draw_from_discard succeeded")
	_assert_ok(bm._bm_validate_state_consistency(), "Consistent after bm_draw_from_discard")

	# Selective reshuffle via _on_battle_inventory_penalty on a DiscardPile ball
	var rem_discard := bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	if not rem_discard.is_empty():
		var pen_uuid := rem_discard[0].ball_uuid
		bm._on_battle_inventory_penalty(pen_uuid)
		_assert_ok(bm._bm_validate_state_consistency(), "Consistent after _on_battle_inventory_penalty selective reshuffle")
		_assert_ok(String(bm.get_instance(pen_uuid).location_container_tag).begins_with("BattleInventoryT"), "Selective reshuffle returned ball to tray")

	# Full tier reshuffle from discard
	if not bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE).is_empty():
		bm._state.reshuffle_tier_from_discard(1)
		_assert_ok(bm._bm_validate_state_consistency(), "Consistent after reshuffle_tier_from_discard(1)")

	# ----------------------------------------------------------------------
	# TEST 4: Battle Equip, Replace, Move, Swap, Full-Bench Unit Remove, Full-Bench Merges
	# ----------------------------------------------------------------------
	print("[4/7] Testing Battle Equip/Replace/Swap, Full-Bench Remove, and Full-Bench Merges...")
	var b_item1 := GachaBallInstance.new()
	b_item1.initialize(Database.get_definition(&"item_claim_ticket"))
	var b_item2 := GachaBallInstance.new()
	b_item2.initialize(Database.get_definition(&"item_t1_a"))
	_assert_ok(bm.bm_register_and_equip_item(b_item1, battle_hero.ball_uuid, 0), "bm_register_and_equip_item replaced hero item to DiscardPile")
	_assert_ok(bm._bm_validate_state_consistency(), "Consistent after bm_register_and_equip_item")

	# Ensure PlayerBench is 100% full
	for slot_i in range(C.BENCH_CAP):
		if bm.get_container(&"PlayerBench").get_uuid(slot_i).is_empty():
			var filler := GachaBallInstance.new()
			filler.initialize(Database.get_definition(&"FFigMecApp"))
			_assert_ok(bm.bm_add_instance(filler, &"PlayerBench", slot_i), "Fill battle bench slot %d" % slot_i)

	# Remove a player unit that has an equipped item while PlayerBench is 100% full -> item must overflow to DiscardPile!
	var temp_unit := GachaBallInstance.new()
	temp_unit.initialize(Database.get_definition(&"FFigMecApp"))
	var free_lineup_slot := bm.get_container(&"PlayerLineup").find_first_empty_slot()
	_assert_ok(free_lineup_slot != -1, "Found free PlayerLineup slot for temp_unit")
	_assert_ok(bm.bm_add_instance(temp_unit, &"PlayerLineup", free_lineup_slot), "Placed temp_unit")
	_assert_ok(bm.bm_register_and_equip_item(b_item2, temp_unit.ball_uuid, 0), "Equipped b_item2 on temp_unit")
	_assert_ok(bm.bm_remove_instance(temp_unit.ball_uuid), "Removed temp_unit with full PlayerBench")
	_assert_ok(bm._bm_validate_state_consistency(), "Consistent after removing equipped unit with full bench")
	_assert_ok(b_item2.location_container_tag == C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE, "Orphaned item overflowed to DiscardPile")

	# Battle merge onto equipped item while PlayerBench is 100% full!
	var b_item3 := GachaBallInstance.new()
	b_item3.initialize(Database.get_definition(&"item_t1_a"))
	_assert_ok(bm.bm_add_instance(b_item3, &"BattleInventoryT1", -1), "Added b_item3 to BattleInventoryT1")
	var bm_merge_res: Dictionary = bm.bm_merge_instances(
		b_item3.get_location(),
		_make_equipped_loc(battle_hero.ball_uuid, 0)
	)
	_assert_ok(bm_merge_res.get("success", false), "bm_merge_instances onto equipped item succeeded with full bench")
	_assert_ok(bm._bm_validate_state_consistency(), "Consistent after full-bench bm_merge_instances onto equipped item")

	# Swap equipped item with bench item in BattleManager (both directions)
	var swap_bench_item := GachaBallInstance.new()
	swap_bench_item.initialize(Database.get_definition(&"item_t1_b"))
	bm.bm_remove_instance(bm.get_container(&"PlayerBench").get_uuid(0))
	_assert_ok(bm.bm_add_instance(swap_bench_item, &"PlayerBench", 0), "Placed swap_bench_item at PlayerBench:0")
	var bh_eq_loc := _make_equipped_loc(battle_hero.ball_uuid, 0)
	var b_bench0_loc := LocationIdentifier.new(&"PlayerBench", 0)
	_assert_ok(bm.bm_swap_instances(b_bench0_loc, bh_eq_loc), "Battle swap bench -> equipped")
	_assert_ok(bm.bm_swap_instances(bh_eq_loc, b_bench0_loc), "Battle swap equipped -> bench")
	_assert_ok(bm._bm_validate_state_consistency(), "Consistent after battle equipped swaps")

	# ----------------------------------------------------------------------
	# TEST 5: EffectTransferItemBehind & EffectHandlers.handle_mirror_transform
	# ----------------------------------------------------------------------
	print("[5/7] Testing EffectTransferItemBehind & handle_mirror_transform...")
	# Ensure PlayerLineup:3 has a unit with an item so unit behind at PlayerLineup:2 (hero) receives a copy!
	if not bm.get_container(&"PlayerLineup").get_uuid(3).is_empty():
		bm.bm_remove_instance(bm.get_container(&"PlayerLineup").get_uuid(3))
	var bearer := GachaBallInstance.new()
	bearer.initialize(Database.get_definition(&"ETnkPlaToy"))
	_assert_ok(bm.bm_add_instance(bearer, &"PlayerLineup", 3), "Placed bearer at PlayerLineup:3")
	var bearer_item := GachaBallInstance.new()
	bearer_item.initialize(Database.get_definition(&"item_t1_b"))
	_assert_ok(bm.bm_register_and_equip_item(bearer_item, bearer.ball_uuid, 0, true), "Equipped bearer_item")

	var transfer_eff := EffectTransferItemBehindScript.new()
	transfer_eff.parameters = {"pass_count": 1}
	var eq_snap := DeathProcessor.snapshot_equipped_items(bearer, bm.get_all_instances())
	var eff_res := transfer_eff.execute(
		bearer.ball_uuid,
		[battle_hero.ball_uuid] as Array[String],
		bm,
		{
			"is_simulation": true,
			"equipped_items": eq_snap,
			"dying_location": bearer.get_location(),
			"dying_team": "PLAYER"
		}
	)
	_assert_ok(eff_res.state_applied, "EffectTransferItemBehind applied")
	_assert_ok(bm._bm_validate_state_consistency(), "Consistent after EffectTransferItemBehind")

	# Mirror transform bearer (with bearer_item equipped!) into FFigMecApp
	var transform_res := EffectHandlers.handle_mirror_transform(
		null,
		{
			"self_uuid": bearer.ball_uuid,
			"target_unit_id": &"FFigMecApp",
			"target_name": "Fire Fighter",
			"target_level": 2
		},
		bm
	)
	_assert_ok(transform_res.new_instances.size() == 1, "handle_mirror_transform created transformed unit")
	bm._apply_summon_result(transform_res)
	_assert_ok(bm._bm_validate_state_consistency(), "Consistent after handle_mirror_transform + _apply_summon_result")
	var transformed_unit: GachaBallInstance = transform_res.new_instances[0]
	_assert_ok(transformed_unit.equipped_item_uuids[0] == bearer_item.ball_uuid, "handle_mirror_transform preserved equipped item")

	# ----------------------------------------------------------------------
	# TEST 6: Enemy Death Cleanup (EnemyGraveyard) & Deferred Erasure Flush
	# ----------------------------------------------------------------------
	print("[6/7] Testing Enemy Death Cleanup to EnemyGraveyard & Deferred Erasure...")
	var enemies := bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	if enemies.is_empty():
		var e_spawn := GachaBallInstance.new()
		e_spawn.initialize(Database.get_definition(&"FFigMecApp"))
		bm.bm_add_instance(e_spawn, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, 0)
		enemies = bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)

	var doomed_enemy := enemies[0]
	var enemy_eq := GachaBallInstance.new()
	enemy_eq.initialize(Database.get_definition(&"item_t1_a"))
	bm.bm_register_and_equip_item(enemy_eq, doomed_enemy.ball_uuid, 0, true)
	var doomed_eq_uuid := doomed_enemy.equipped_item_uuids[0]

	doomed_enemy.current_hp = 0
	DeathProcessor.register_death(bm._state, doomed_enemy, &"COMBAT")
	bm._perform_unit_death_cleanup(doomed_enemy)

	# CRITICAL: Validate consistency BEFORE _flush_deferred_enemy_erasures! (Zero skip-exceptions!)
	_assert_ok(bm._bm_validate_state_consistency(), "Consistent WHILE enemy & item are awaiting deferred erasure in EnemyGraveyard!")
	_assert_ok(doomed_enemy.location_container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_GRAVEYARD, "Dead enemy moved to EnemyGraveyard")
	_assert_ok(bm.get_instance(doomed_eq_uuid).location_container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_GRAVEYARD, "Dead enemy's item moved to EnemyGraveyard")

	bm._flush_deferred_enemy_erasures()
	_assert_ok(bm._bm_validate_state_consistency(), "Consistent AFTER _flush_deferred_enemy_erasures")
	_assert_ok(bm.get_instance(doomed_enemy.ball_uuid) == null and bm.get_instance(doomed_eq_uuid) == null, "Deferred enemy & item erased cleanly")

	# ----------------------------------------------------------------------
	# TEST 7: Full Multi-Turn Combat Resolution Stress Test
	# ----------------------------------------------------------------------
	print("[7/7] Running Multi-Turn Combat Simulation Stress Test...")
	for seed_offset in range(3):
		var bm2 = BattleManagerScript.new()
		add_child(bm2)
		GameManager.register_battle_manager(bm2)
		var enc = EncounterGenerator.generate_encounter(seed_offset + 1)
		bm2._setup_battle(enc)
		_assert_ok(bm2._bm_validate_state_consistency(), "Sim %d setup consistent" % seed_offset)
		await bm2.execute_hero_entrance_sequence()
		await bm2.execute_enemy_entrance_sequence()
		_assert_ok(bm2._bm_validate_state_consistency(), "Sim %d post-entrance consistent" % seed_offset)

		# Place lethal counter unit (FFigMecApp) at PlayerLineup:4
		if bm2.get_container(&"PlayerLineup").get_uuid(4).is_empty():
			var lc := GachaBallInstance.new()
			lc.initialize(Database.get_definition(&"FFigMecApp"))
			bm2.bm_add_instance(lc, &"PlayerLineup", 4)

		for turn_idx in range(5):
			if bm2._is_battle_over():
				break
			bm2._state.clear_turn_data()
			bm2._populate_actor_queue()
			var turn_events: Array[CombatEvent] = []
			var death_tracking: Dictionary = {}
			var safety := 0
			while not bm2._actor_queue.is_empty() and safety < 30:
				safety += 1
				var actor: GachaBallInstance = bm2._actor_queue.pop_front()
				if not is_instance_valid(actor) or actor.current_hp <= 0:
					continue
				if actor.location_container_tag != C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP and actor.location_container_tag != C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
					continue
				var basic_ab = bm2.get_basic_attack_for(actor)
				if is_instance_valid(basic_ab) and not basic_ab.effects.is_empty():
					var targets = bm2.resolve_target(actor.ball_uuid, basic_ab.effects[0].target_type, {})
					var req := EffectRequest.new(actor.ball_uuid, basic_ab.id, basic_ab.effects[0], targets, {}, 0)
					bm2.enqueue_effect_request(req)
					turn_events.append_array(bm2._combat.process_reaction_queue(bm2, death_tracking))
					DeathProcessor.check_for_deaths_with_counter_delay(true, turn_events, death_tracking, bm2)
					DeathProcessor.process_completed_counter_deaths(turn_events, death_tracking, bm2)
					_assert_ok(bm2._bm_validate_state_consistency(), "Sim %d turn %d step %d consistent" % [seed_offset, turn_idx, safety])
			bm2._finalize_deaths()
			_assert_ok(bm2._bm_validate_state_consistency(), "Sim %d turn %d post-finalize consistent" % [seed_offset, turn_idx])

		bm2.queue_free()

	bm.queue_free()
	GameManager.unregister_battle_manager()
	GameManager.is_in_battle = false

	print("=== ALL ATOMIC STATE TESTS PASSED WITH ZERO VIOLATIONS! ===")
	get_tree().quit(0)
