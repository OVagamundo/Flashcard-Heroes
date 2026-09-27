# res://scratch/test_crr.gd
extends Node

const C = preload("res://scripts/Constants.gd")
const CausalReactionResolver = preload("res://scripts/battle/CausalReactionResolver.gd")

func _ready() -> void:
	print("\n====================================================")
	print("Running CausalReactionResolver (CRR) Unit Verification")
	print("====================================================")
	
	test_3_layer_priority_sorting()
	test_interception_draining()
	test_lethal_counter_draining()
	test_causal_lineage_stamping()
	test_scoped_draining()
	
	print("\n>>> ALL CRR UNIT TESTS PASSED SUCCESSFULLY! <<<")
	print("====================================================\n")
	get_tree().quit(0)

func test_3_layer_priority_sorting() -> void:
	print("Testing 3-Layer Priority Sorting Hierarchy...")
	var crr = CausalReactionResolver.new()
	
	# Layer 1 test: Priority 300 vs 200 vs 50 vs 0
	var req_prio_0 = _make_request("req_0", 0, &"UNIT", true, 0)
	var req_prio_300 = _make_request("req_300", 300, &"UNIT", true, 0)
	var req_prio_50 = _make_request("req_50", 50, &"UNIT", true, 0)
	var req_prio_200 = _make_request("req_200", 200, &"UNIT", true, 0)
	
	crr.enqueue_many([req_prio_0, req_prio_300, req_prio_50, req_prio_200])
	crr.sort_pending()
	
	var sorted = crr.get_pending_reactions()
	assert(sorted[0].priority == 300, "First must be priority 300")
	assert(sorted[1].priority == 200, "Second must be priority 200")
	assert(sorted[2].priority == 50, "Third must be priority 50")
	assert(sorted[3].priority == 0, "Fourth must be priority 0")
	crr.clear()
	
	# Layer 2 test: Same priority (100), UNIT (rank 1) vs ITEM (rank 2) vs TRINKET (rank 3)
	var req_item = _make_request("req_item", 100, &"ITEM", true, 0)
	var req_trinket = _make_request("req_trinket", 100, &"TRINKET", true, 0)
	var req_unit = _make_request("req_unit", 100, &"UNIT", true, 0)
	
	crr.enqueue_many([req_trinket, req_item, req_unit])
	crr.sort_pending()
	sorted = crr.get_pending_reactions()
	assert(sorted[0].category == &"UNIT", "UNIT must sort first in tie-break")
	assert(sorted[1].category == &"ITEM", "ITEM must sort second in tie-break")
	assert(sorted[2].category == &"TRINKET", "TRINKET must sort third in tie-break")
	crr.clear()
	
	# Layer 3 test: Visual Direction / Mirror Rule
	# Player slots: slot 4 > slot 0
	var req_player_slot_0 = _make_request("p_slot_0", 100, &"UNIT", true, 0)
	var req_player_slot_4 = _make_request("p_slot_4", 100, &"UNIT", true, 4)
	crr.enqueue_many([req_player_slot_0, req_player_slot_4])
	crr.sort_pending()
	sorted = crr.get_pending_reactions()
	assert(sorted[0].slot_index == 4, "Player slot 4 must execute before slot 0")
	crr.clear()
	
	# Enemy slots: slot 0 < slot 4
	var req_enemy_slot_0 = _make_request("e_slot_0", 100, &"UNIT", false, 0)
	var req_enemy_slot_4 = _make_request("e_slot_4", 100, &"UNIT", false, 4)
	crr.enqueue_many([req_enemy_slot_4, req_enemy_slot_0])
	crr.sort_pending()
	sorted = crr.get_pending_reactions()
	assert(sorted[0].slot_index == 0, "Enemy slot 0 must execute before slot 4")
	crr.clear()
	
	print("PASS: 3-Layer Priority Sorting Hierarchy verified.")

func test_interception_draining() -> void:
	print("Testing Interception Draining (Priority >= 300)...")
	var crr = CausalReactionResolver.new()
	var req_guardian = _make_request("guardian_intercept", 300, &"UNIT", true, 0)
	var req_standard = _make_request("standard_reaction", 100, &"UNIT", true, 1)
	var req_aegis = _make_request("aegis_save", 300, &"TRINKET", true, -1)
	
	crr.enqueue_many([req_standard, req_guardian, req_aegis])
	var intercepts = crr.drain_interceptions()
	
	assert(intercepts.size() == 2, "Must extract exactly 2 interceptors")
	assert(intercepts[0] == req_guardian, "Guardian (UNIT) must sort before Aegis (TRINKET)")
	assert(intercepts[1] == req_aegis, "Aegis must be second interceptor")
	assert(crr.size() == 1, "Remaining queue must have 1 request")
	assert(crr.get_pending_reactions()[0] == req_standard, "Standard reaction must remain in queue")
	print("PASS: Interception Draining verified.")

func test_lethal_counter_draining() -> void:
	print("Testing Lethal Counter Draining...")
	var crr = CausalReactionResolver.new()
	var bm = BattleManager.new()
	bm.is_test_mode = true
	add_child(bm)
	
	# Create counter unit with 0 HP (lethal damage)
	var counter_unit = GachaBallInstance.new()
	var counter_def: GachaBallDefinition = Database.get_definition(&"unit_t1_b")
	counter_unit.initialize(counter_def)
	counter_unit.ball_uuid = "counter_unit"
	counter_unit.current_hp = 0
	bm.bm_add_instance(counter_unit, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, 0)
	
	var req_counter = _make_request("counter_hit", 50, &"UNIT", false, 0)
	req_counter.source_uuid = "counter_unit"
	req_counter.ability_id = &"unit_tier1b_counter_on_hurt"
	
	var req_other = _make_request("normal_reaction", 50, &"UNIT", true, 0)
	req_other.source_uuid = "living_unit"
	
	crr.enqueue_many([req_other, req_counter])
	var lethal_counters = crr.drain_lethal_counters(bm)
	
	assert(lethal_counters.size() == 1, "Must extract 1 lethal counter")
	assert(lethal_counters[0].ability_id == &"unit_tier1b_counter_on_hurt", "Must be counter ability")
	assert(crr.size() == 1, "Non-lethal reaction must remain in queue")
	
	bm.free()
	print("PASS: Lethal Counter Draining verified.")

func test_causal_lineage_stamping() -> void:
	print("Testing Causal Lineage Stamping...")
	var evt_root = CombatEvent.new(CombatEvent.Type.DAMAGE, {"source_uuid": "attacker"})
	var evt_consequence = CombatEvent.new(CombatEvent.Type.HEAL, {"source_uuid": "defender"})
	
	assert(evt_consequence.cause_event_id == -1, "Initial cause_event_id must be -1")
	CausalReactionResolver.stamp_cause_id([evt_consequence], evt_root.event_id)
	assert(evt_consequence.cause_event_id == evt_root.event_id, "Cause ID must match root event ID")
	print("PASS: Causal Lineage Stamping verified.")

func test_scoped_draining() -> void:
	print("Testing Scoped Reaction Draining & Isolation...")
	var crr = CausalReactionResolver.new()
	
	# Pre-existing reaction in queue
	var req_pre = _make_request("pre_existing", 50, &"UNIT", true, 0)
	crr.enqueue(req_pre)
	assert(crr.size() == 1, "Queue should contain 1 pre-existing item")
	
	# Open Outer Scope (e.g. basic attack)
	var outer_scope = crr.begin_scope()
	var req_outer_1 = _make_request("outer_1", 100, &"UNIT", true, 1)
	var req_outer_2 = _make_request("outer_2", 200, &"ITEM", true, 0)
	crr.enqueue(req_outer_1)
	crr.enqueue(req_outer_2)
	assert(crr.size() == 3, "Queue should have 3 items total")
	
	# Open Nested Scope (e.g. cascade or nested trigger)
	var inner_scope = crr.begin_scope()
	var req_inner = _make_request("inner_1", 300, &"TRINKET", true, 2)
	crr.enqueue(req_inner)
	assert(crr.size() == 4, "Queue should have 4 items total")
	
	# Drain Inner Scope
	var inner_drained = crr.drain_scope(inner_scope)
	assert(inner_drained.size() == 1, "Inner scope must drain exactly 1 request")
	assert(inner_drained[0] == req_inner, "Inner scope request must match req_inner")
	assert(crr.size() == 3, "Queue should have 3 items after inner drain")
	
	# Drain Outer Scope
	var outer_drained = crr.drain_scope(outer_scope)
	assert(outer_drained.size() == 2, "Outer scope must drain exactly 2 requests")
	assert(outer_drained[0] == req_outer_2, "Priority 200 must sort before Priority 100")
	assert(outer_drained[1] == req_outer_1, "Priority 100 must be second")
	assert(crr.size() == 1, "Queue should have exactly 1 pre-existing request remaining")
	assert(crr.get_pending_reactions()[0] == req_pre, "Pre-existing request must be untouched")
	
	# Drain All
	var all_drained = crr.drain_all()
	assert(all_drained.size() == 1, "Drain all must drain pre-existing item")
	assert(crr.is_empty(), "Queue must now be empty")
	
	print("PASS: Scoped Reaction Draining & Isolation verified.")

func _make_request(id: String, prio: int, cat: StringName, is_player: bool, slot: int) -> EffectRequest:
	var effect = EffectDefinition.new()
	return EffectRequest.new(
		id,
		StringName(id),
		effect,
		[],
		{},
		prio,
		cat,
		is_player,
		slot,
		0
	)
