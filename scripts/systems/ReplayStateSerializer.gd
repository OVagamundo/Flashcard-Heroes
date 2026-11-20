# res://scripts/systems/ReplayStateSerializer.gd
class_name ReplayStateSerializer
extends RefCounted

## Serializes and restores GameManager's logical/replay state snapshots,
## temporary encounter containers, and DirectorRunState checkpoints.

const FixedArrayContainerScript = preload("res://scripts/FixedArrayContainer.gd")


static func build_replay_state_snapshot(gm: Node) -> Dictionary:
	var run_snapshot: Dictionary = {}
	if is_instance_valid(gm.run_state):
		run_snapshot = gm.run_state.to_save_dict()
		run_snapshot.erase("elapsed_simulation_time")
		var rng_state: Dictionary = run_snapshot.get("rng_state", {}).duplicate(true)
		var rng_streams: Dictionary = rng_state.get("streams", {}).duplicate(true)
		rng_streams.erase("cosmetic")
		rng_state["streams"] = rng_streams
		run_snapshot["rng_state"] = rng_state

	var bm: BattleManager = gm._active_battle_manager as BattleManager
	return {
		"run_state": run_snapshot,
		"is_in_battle": gm.is_in_battle,
		"gacha_discounts_used": gm.gacha_discounts_used.duplicate(true),
		"temporary_rewards": snapshot_temporary_instances(gm._temporary_reward_master_dict),
		"temporary_shop": snapshot_temporary_instances(gm._temporary_shop_master_dict),
		"temporary_gold_reward": gm._temporary_gold_reward,
		"reward_reroll_cost": gm.run_state.get_elite_reward_reroll_cost() if is_instance_valid(gm.run_state) else 5,
		"reward_room_active": gm._reward_room_active,
		"reward_study_used": gm._reward_study_used,
		"shop_reroll_cost": gm._reroll_cost,
		"rest_site_type": gm.current_rest_site_type,
		"rest_site_active": gm._rest_site_active,
		"rest_site_study_used": gm._rest_site_study_used,
		"rest_site_prizes": gm._temporary_rest_site_prizes.duplicate(true),
		"trinity_drawn": [gm._trinity_t1_drawn, gm._trinity_t2_drawn, gm._trinity_t3_drawn, gm._trinity_rewarded],
		"director_run_state": snapshot_director_run_state(gm.director_run_state),
		"encounter_director_run_state": snapshot_director_run_state(EncounterGenerator.director_run_state),
		"tutorial_state": TutorialManager.get_state_snapshot(),
		"flashcard_state": FlashcardManager.get_replay_state_snapshot(),
		"battle_state": bm.get_replay_state_snapshot() if is_instance_valid(bm) else {},
	}


static func build_replay_manager_state(gm: Node) -> Dictionary:
	return {
		"gacha_discounts_used": gm.gacha_discounts_used.duplicate(true),
		"temporary_rewards": snapshot_temporary_instances(gm._temporary_reward_master_dict),
		"temporary_reward_container_size": gm._temporary_reward_container.get_size() if is_instance_valid(gm._temporary_reward_container) else 0,
		"temporary_shop": snapshot_temporary_instances(gm._temporary_shop_master_dict),
		"temporary_shop_container_size": gm._temporary_shop_container.get_size() if is_instance_valid(gm._temporary_shop_container) else 0,
		"temporary_gold_reward": gm._temporary_gold_reward,
		"reward_reroll_cost": gm._reward_reroll_cost,
		"reward_room_active": gm._reward_room_active,
		"reward_study_used": gm._reward_study_used,
		"shop_reroll_cost": gm._reroll_cost,
		"rest_site_type": gm.current_rest_site_type,
		"rest_site_active": gm._rest_site_active,
		"rest_site_study_used": gm._rest_site_study_used,
		"rest_site_prizes": gm._temporary_rest_site_prizes.duplicate(true),
		"trinity_drawn": [gm._trinity_t1_drawn, gm._trinity_t2_drawn, gm._trinity_t3_drawn, gm._trinity_rewarded],
		"is_in_battle": gm.is_in_battle,
		"combat_speed_factor": AnimationConstants.speed_factor,
		"tutorial_state": TutorialManager.get_state_snapshot(),
		"director_run_state": snapshot_director_run_state(gm.director_run_state),
		"encounter_director_run_state": snapshot_director_run_state(EncounterGenerator.director_run_state),
	}


static func restore_replay_manager_state(gm: Node, data: Dictionary) -> void:
	gm._reset_replay_transient_state()
	var saved_discounts: Dictionary = data.get("gacha_discounts_used", {})
	gm.gacha_discounts_used = {}
	for tier: int in [1, 2, 3]:
		gm.gacha_discounts_used[tier] = bool(saved_discounts.get(str(tier), saved_discounts.get(tier, false)))

	var restored_rewards: Dictionary = restore_temporary_instances(
		data.get("temporary_rewards", []),
		int(data.get("temporary_reward_container_size", 0))
	)
	gm._temporary_reward_master_dict = restored_rewards["instances"]
	gm._temporary_reward_container = restored_rewards["container"]

	var restored_shop: Dictionary = restore_temporary_instances(
		data.get("temporary_shop", []),
		int(data.get("temporary_shop_container_size", 0))
	)
	gm._temporary_shop_master_dict = restored_shop["instances"]
	gm._temporary_shop_container = restored_shop["container"]

	gm._temporary_gold_reward = int(data.get("temporary_gold_reward", 0))
	gm._reward_reroll_cost = int(data.get("reward_reroll_cost", 5))
	if is_instance_valid(gm.run_state):
		gm.run_state.elite_reward_reroll_cost = gm._reward_reroll_cost
	gm._reward_room_active = bool(data.get("reward_room_active", false))
	gm._reward_study_used = bool(data.get("reward_study_used", false))
	gm._reroll_cost = int(data.get("shop_reroll_cost", 1))
	gm.current_rest_site_type = int(data.get("rest_site_type", 0))
	gm._rest_site_active = bool(data.get("rest_site_active", false))
	gm._rest_site_study_used = bool(data.get("rest_site_study_used", false))
	gm._temporary_rest_site_prizes.clear()
	for prize in data.get("rest_site_prizes", []):
		if prize is Dictionary:
			gm._temporary_rest_site_prizes.append((prize as Dictionary).duplicate(true))

	var trinity_state: Array = data.get("trinity_drawn", [false, false, false, false])
	gm._trinity_t1_drawn = bool(trinity_state[0]) if trinity_state.size() > 0 else false
	gm._trinity_t2_drawn = bool(trinity_state[1]) if trinity_state.size() > 1 else false
	gm._trinity_t3_drawn = bool(trinity_state[2]) if trinity_state.size() > 2 else false
	gm._trinity_rewarded = bool(trinity_state[3]) if trinity_state.size() > 3 else false

	gm.is_in_battle = bool(data.get("is_in_battle", false))
	AnimationConstants.speed_factor = float(data.get("combat_speed_factor", 1.0))

	var tutorial_state: Variant = data.get("tutorial_state", {})
	if tutorial_state is Dictionary and not (tutorial_state as Dictionary).is_empty():
		TutorialManager.set_temporary_replay_state(tutorial_state as Dictionary)

	gm.director_run_state = restore_director_run_state(data.get("director_run_state", {}))
	EncounterGenerator.director_run_state = restore_director_run_state(data.get("encounter_director_run_state", {}))


static func snapshot_temporary_instances(instances: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var uuids: Array = instances.keys()
	uuids.sort()
	for uuid in uuids:
		var instance: GachaBallInstance = instances[uuid] as GachaBallInstance
		if is_instance_valid(instance):
			result.append({"uuid": String(uuid), "instance": instance.to_save_dict()})
	return result


static func restore_temporary_instances(serialized: Array, container_size: int) -> Dictionary:
	var instances: Dictionary = {}
	var container: DataContainer = FixedArrayContainerScript.new(container_size) if container_size > 0 else null
	for entry in serialized:
		if not (entry is Dictionary):
			continue
		var uuid: String = String((entry as Dictionary).get("uuid", ""))
		var instance_data: Variant = (entry as Dictionary).get("instance", {})
		if uuid.is_empty() or not (instance_data is Dictionary):
			continue
		var instance := GachaBallInstance.new()
		instance.from_save_dict(instance_data as Dictionary)
		instances[uuid] = instance
		if is_instance_valid(container):
			var slot: int = instance.location_slot_index
			if slot >= 0 and slot < container.get_size():
				container.set_uuid(slot, uuid)
	return {"instances": instances, "container": container}


static func snapshot_director_run_state(state: DirectorRunState) -> Dictionary:
	if not is_instance_valid(state):
		return {}
	return {
		"current_purpose": int(state.current_purpose),
		"current_day": state.current_day,
		"player_gold": state.player_gold,
		"flashcard_mastery": state.flashcard_mastery,
		"unlock_percentage": state.unlock_percentage,
		"unlocked_recipes": state.unlocked_recipes.duplicate(),
		"encountered_bosses": state.encountered_bosses.duplicate(),
		"excluded_entity_ids": state.excluded_entity_ids.duplicate(),
	}


static func restore_director_run_state(data: Dictionary) -> DirectorRunState:
	var state := DirectorRunState.new()
	match int(data.get("current_purpose", DirectorRunState.Purpose.ANY)):
		DirectorRunState.Purpose.ENCOUNTER:
			state.current_purpose = DirectorRunState.Purpose.ENCOUNTER
		DirectorRunState.Purpose.SHOP:
			state.current_purpose = DirectorRunState.Purpose.SHOP
		DirectorRunState.Purpose.REWARD:
			state.current_purpose = DirectorRunState.Purpose.REWARD
		DirectorRunState.Purpose.NODE_GENERATION:
			state.current_purpose = DirectorRunState.Purpose.NODE_GENERATION
		_:
			state.current_purpose = DirectorRunState.Purpose.ANY
	state.current_day = int(data.get("current_day", 1))
	state.player_gold = int(data.get("player_gold", 0))
	state.flashcard_mastery = float(data.get("flashcard_mastery", 0.0))
	state.unlock_percentage = float(data.get("unlock_percentage", 0.0))
	for recipe_id in data.get("unlocked_recipes", []):
		state.unlocked_recipes.append(String(recipe_id))
	for boss_id in data.get("encountered_bosses", []):
		state.encountered_bosses.append(String(boss_id))
	for entity_id in data.get("excluded_entity_ids", []):
		state.excluded_entity_ids.append(StringName(entity_id))
	return state
