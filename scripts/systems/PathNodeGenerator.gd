# res://scripts/systems/PathNodeGenerator.gd
class_name PathNodeGenerator
extends RefCounted

## Generates daily path node offerings (Boss, guaranteed Elite milestones, or weighted
## encounter pools) while preserving deterministic RNG draw ordering for seed parity.

const MAX_TIER_ELITES: int = 4
const MAX_RUN_ELITES: int = 12
const ELITE_PROGRESS_THRESHOLDS: Array[float] = [0.20, 0.40, 0.60, 0.80]


static func generate_path_nodes(gm: Node) -> Array[PathNodeDefinition]:
	var run_state: RunState = gm.run_state
	if not is_instance_valid(run_state):
		return []

	if gm.loading_from_save:
		gm.loading_from_save = false
		if not run_state.available_path_nodes.is_empty():
			if DemoContent.is_demo_mode():
				for node_index: int in range(run_state.available_path_nodes.size() - 1, -1, -1):
					if run_state.available_path_nodes[node_index].node_type == &"SURPRISE":
						run_state.available_path_nodes.remove_at(node_index)
			if not run_state.available_path_nodes.is_empty():
				return run_state.available_path_nodes

	run_state.advance_day(1)
	EncounterTransactionEngine.update_director_run_state(gm, DirectorRunState.Purpose.NODE_GENERATION)

	var boss_level: int = run_state.bosses_defeated + 1
	var selected_nodes: Array[PathNodeDefinition] = []
	var offers_boss: bool = boss_level <= run_state.get_boss_count() and run_state.get_mastered_card_count() >= run_state.get_boss_mastery_threshold(boss_level)

	if offers_boss:
		run_state.reveal_boss(boss_level)
		var node_def := PathNodeDefinition.new()
		node_def.node_type = "BATTLE"
		node_def.subtype = "BOSS"
		node_def.display_name_key = "ui.boss"
		node_def.boss_level = boss_level
		node_def.difficulty = boss_level
		selected_nodes.append(node_def)
	else:
		var tier_progress: float = run_state.get_tier_progress()
		var can_encounter_elite: bool = (run_state.elites_encountered_in_tier < MAX_TIER_ELITES) and (run_state.elites_defeated < MAX_RUN_ELITES)

		var is_elite_guaranteed: bool = false
		if can_encounter_elite:
			for m_idx: int in range(ELITE_PROGRESS_THRESHOLDS.size()):
				if tier_progress >= ELITE_PROGRESS_THRESHOLDS[m_idx] and not run_state.elite_milestones_offered.has(m_idx):
					is_elite_guaranteed = true
					run_state.elite_milestones_offered.append(m_idx)

		if is_elite_guaranteed:
			var elite_def := PathNodeDefinition.new()
			elite_def.node_type = "BATTLE"
			elite_def.subtype = "ELITE"
			elite_def.display_name_key = "ui.elite_battle_node"
			elite_def.base_weight = 350
			selected_nodes.append(elite_def)

			var pool: Array[PathNodeDefinition] = _build_candidate_pool(run_state, false)
			selected_nodes.append_array(_draw_unique_nodes(pool, 2, gm.director, gm.director_run_state))
			RNGManager.map_rng.shuffle(selected_nodes)
		else:
			var pool: Array[PathNodeDefinition] = _build_candidate_pool(run_state, can_encounter_elite)
			selected_nodes.append_array(_draw_unique_nodes(pool, 3, gm.director, gm.director_run_state))

	run_state.available_path_nodes = selected_nodes

	for node_def: PathNodeDefinition in selected_nodes:
		var dict_key: String = _node_history_key(node_def.node_type, node_def.subtype)
		run_state.encounter_last_offered_day[dict_key] = run_state.day

	if not gm.is_replay_run:
		SaveManager.save_run(run_state)

	if offers_boss:
		SignalBus.run_data_changed.emit()

	return selected_nodes


static func _build_candidate_pool(run_state: RunState, include_elite: bool) -> Array[PathNodeDefinition]:
	var candidate_types: Array[Dictionary] = [
		{"type": "BATTLE", "subtype": "", "name": "ui.battle_node", "base_w": 1500},
		{"type": "SHOP", "subtype": "", "name": "ui.shop_node", "base_w": 100},
		{"type": "MERGE", "subtype": "", "name": "ui.merge_node", "base_w": 100},
		{"type": "SHRINE", "subtype": "", "name": "ui.shrine_node", "base_w": 100},
	]
	if not DemoContent.is_demo_mode():
		candidate_types.append({"type": "SURPRISE", "subtype": "", "name": "ui.surprise_node", "base_w": 100})
	candidate_types.append({"type": "DOJO", "subtype": "", "name": "ui.training_grounds_node", "base_w": 100})
	if include_elite:
		candidate_types.append({"type": "BATTLE", "subtype": "ELITE", "name": "ui.elite_battle_node", "base_w": 350})

	var pool: Array[PathNodeDefinition] = []
	var current_day: int = run_state.day
	for t: Dictionary in candidate_types:
		var dict_key: String = _node_history_key(t["type"], t["subtype"])
		var last_offered: int = int(run_state.encounter_last_offered_day.get(dict_key, 0))
		var days_since: int = current_day - last_offered
		var def := PathNodeDefinition.new()
		def.node_type = t["type"]
		def.subtype = t["subtype"]
		def.display_name_key = t["name"]
		def.base_weight = int(t["base_w"]) + (days_since * 10)
		pool.append(def)
	return pool


static func _draw_unique_nodes(
	pool: Array[PathNodeDefinition],
	count: int,
	director: WeightedPoolDirector,
	director_run_state: DirectorRunState
) -> Array[PathNodeDefinition]:
	var drawn_nodes: Array[PathNodeDefinition] = []
	var remaining: Array[PathNodeDefinition] = pool
	for _i: int in range(count):
		if remaining.is_empty():
			break
		var drawn: PathNodeDefinition = director.draw_item(remaining, director_run_state, RNGManager.map_rng) as PathNodeDefinition
		if is_instance_valid(drawn):
			drawn_nodes.append(drawn)
			var next_pool: Array[PathNodeDefinition] = []
			for p: PathNodeDefinition in remaining:
				if p.node_type != drawn.node_type or p.subtype != drawn.subtype:
					next_pool.append(p)
			remaining = next_pool
	return drawn_nodes


static func _node_history_key(node_type: String, subtype: String) -> String:
	return node_type + "_" + subtype if not subtype.is_empty() else node_type
