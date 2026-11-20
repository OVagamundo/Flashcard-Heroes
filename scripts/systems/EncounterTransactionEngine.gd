# res://scripts/systems/EncounterTransactionEngine.gd
class_name EncounterTransactionEngine
extends RefCounted

## Executes authoritative non-battle encounter transactions and stock generation
## for GameManager: Shop, Reward/Elite Rewards, Shrine, RestSite, and Dojo.

const C = preload("res://scripts/Constants.gd")
const FixedArrayContainerScript = preload("res://scripts/FixedArrayContainer.gd")


static func update_director_run_state(gm: Node, purpose: DirectorRunState.Purpose = DirectorRunState.Purpose.ANY) -> void:
	var run_state: RunState = gm.run_state
	if not is_instance_valid(run_state):
		return
	var drs: DirectorRunState = gm.director_run_state
	drs.current_day = run_state.day
	drs.player_gold = run_state.gold
	drs.unlock_percentage = run_state.get_deck_unlock_percentage()
	drs.current_purpose = purpose
	drs.machine_trait_counts.clear()
	drs.machine_unit_counts.clear()
	drs.owned_crest_traits.clear()

	var weights_offers: bool = purpose in [DirectorRunState.Purpose.SHOP, DirectorRunState.Purpose.REWARD]
	if weights_offers:
		drs.unit_tag_overrides = run_state.dynamic_tag_overrides
		for tier: int in [1, 2, 3]:
			for unit: GachaBallInstance in run_state.get_inventory_tier_instances(tier):
				if unit.get_definition().category != C.CATEGORY_UNIT:
					continue
				drs.machine_unit_counts[unit.definition_id] = drs.machine_unit_counts.get(unit.definition_id, 0) + 1
				var counted_traits: Array[String] = []
				for tag: StringName in unit.get_active_tags(run_state.get_all_instances()):
					var trait_id: String = WeightedPoolDirector.normalize_trait_tag(tag)
					if C.TRAIT_DEFINITIONS.has(trait_id) and not counted_traits.has(trait_id):
						drs.machine_trait_counts[trait_id] = drs.machine_trait_counts.get(trait_id, 0) + 1
						counted_traits.append(trait_id)

	drs.unlocked_recipes.clear()
	for r_id in run_state.unlocked_recipes.keys():
		if run_state.unlocked_recipes[r_id]:
			drs.unlocked_recipes.append(String(r_id))

	drs.clear_exclusions()
	var trinket_container: DataContainer = run_state.get_container(RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS)
	if is_instance_valid(trinket_container):
		for uuid: String in trinket_container.get_all_non_empty_uuids():
			var inst: GachaBallInstance = run_state.get_instance_by_uuid(uuid)
			if is_instance_valid(inst):
				var def: Resource = inst.get_definition()
				if is_instance_valid(def):
					drs.exclude_entity(def.id)
					if weights_offers and def is TrinketDefinition:
						var trait_id: String = WeightedPoolDirector.get_crest_trait_id(def as TrinketDefinition)
						if not trait_id.is_empty() and not drs.owned_crest_traits.has(trait_id):
							drs.owned_crest_traits.append(trait_id)


static func generate_reward_stock(gm: Node) -> void:
	var run_state: RunState = gm.run_state
	gm._temporary_reward_master_dict.clear()
	gm._temporary_reward_container = FixedArrayContainerScript.new(3)

	var is_special_victory: bool = run_state.current_boss_level > 0 or run_state.current_elite_level > 0
	if is_special_victory:
		var eligible_trinkets: Array = Database.get_eligible_trinkets_for_reward()
		update_director_run_state(gm, DirectorRunState.Purpose.REWARD)
		var drawn_trinkets: Array = gm.director.draw_unique_items(eligible_trinkets, gm.director_run_state, 3, RNGManager.reward_rng)
		for i: int in range(drawn_trinkets.size()):
			var inst := GachaBallInstance.new()
			inst.initialize_from_trinket(drawn_trinkets[i])
			inst.location_container_tag = &"Rewards"
			inst.location_slot_index = i
			gm._temporary_reward_master_dict[inst.ball_uuid] = inst
			gm._temporary_reward_container.set_uuid(i, inst.ball_uuid)
	else:
		var all_defs: Array = Database.get_all_pool_definitions()
		if all_defs.is_empty():
			return
		update_director_run_state(gm, DirectorRunState.Purpose.REWARD)
		var drawn_rewards: Array = gm.director.draw_unique_items(all_defs, gm.director_run_state, 3, RNGManager.reward_rng)
		for i: int in range(drawn_rewards.size()):
			var inst := GachaBallInstance.new()
			inst.initialize(drawn_rewards[i])
			inst.location_container_tag = &"Rewards"
			inst.location_slot_index = i
			gm._temporary_reward_master_dict[inst.ball_uuid] = inst
			gm._temporary_reward_container.set_uuid(i, inst.ball_uuid)


static func handle_reward_chosen(gm: Node, payload: Dictionary) -> void:
	SignalBus.selection_clear_requested.emit()
	var run_state: RunState = gm.run_state

	if payload.get("type", "") == "gachaball":
		var chosen_uuid: String = payload.get("instance_uuid", "")
		if not chosen_uuid.is_empty() and gm._temporary_reward_master_dict.has(chosen_uuid):
			var selected_instance: GachaBallInstance = gm._temporary_reward_master_dict[chosen_uuid] as GachaBallInstance
			var def: Resource = selected_instance.get_definition()

			if is_instance_valid(gm._temporary_reward_container):
				var slot_idx: int = gm._temporary_reward_container.get_index_of_uuid(chosen_uuid)
				if slot_idx != -1:
					gm._temporary_reward_container.set_uuid(slot_idx, "")

			selected_instance.location_container_tag = &""
			selected_instance.location_slot_index = -1

			var container_name: StringName = _resolve_acquisition_container(def)
			run_state.add_instance(selected_instance, container_name, -1)
			if is_instance_valid(def):
				run_state.unlock_recipe_for_result(def.id)
	elif payload.get("type", "") == "gold":
		run_state.add_gold(int(payload.get("amount", 0)))

	run_state.current_boss_level = 0
	run_state.current_elite_level = 0


static func sell_reward_instance(gm: Node, instance_uuid: String) -> int:
	if not gm._temporary_reward_master_dict.has(instance_uuid):
		return 0
	var instance: GachaBallInstance = gm._temporary_reward_master_dict[instance_uuid] as GachaBallInstance
	var gold_yield: int = 1
	if is_instance_valid(gm.run_state) and (gm.run_state.current_boss_level > 0 or gm.run_state.current_elite_level > 0):
		gold_yield = 10
	elif is_instance_valid(instance):
		gold_yield = maxi(1, int(instance.get_gold_value() * 0.5))

	if is_instance_valid(gm.run_state):
		gm.run_state.add_gold(gold_yield)

	if is_instance_valid(gm._temporary_reward_container):
		var slot_idx: int = gm._temporary_reward_container.get_index_of_uuid(instance_uuid)
		if slot_idx != -1:
			gm._temporary_reward_container.set_uuid(slot_idx, "")
	gm._temporary_reward_master_dict.erase(instance_uuid)
	SignalBus.selection_clear_requested.emit()
	return gold_yield


static func simulate_reward_draw(gm: Node, tier: int, slot_index: int = -1) -> Dictionary:
	var run_state: RunState = gm.run_state
	if not is_instance_valid(run_state):
		return {"success": false, "error": "No active run_state"}

	var discount_active: bool = gm.is_bargain_charm_active(tier)
	var cost: int = gm.get_gacha_token_cost(tier)
	if run_state.get_room_tokens() < cost:
		return {"success": false, "error": "Insufficient room tokens"}

	run_state.spend_room_tokens(cost)
	if discount_active:
		gm.use_gacha_discount(tier)

	if gm._temporary_reward_container == null:
		gm._temporary_reward_container = FixedArrayContainerScript.new(5)

	if slot_index == -1:
		slot_index = gm._temporary_reward_container.find_first_empty_slot()
		if slot_index == -1:
			run_state.add_room_tokens(cost)
			if discount_active:
				gm.gacha_discounts_used[tier] = false
			return {"success": false, "error": "Lineup full"}

	var eligible: Array[GachaBallDefinition] = []
	for definition in Database.get_all_pool_definitions():
		if is_instance_valid(definition) and definition.tier == tier:
			eligible.append(definition)

	update_director_run_state(gm, DirectorRunState.Purpose.REWARD)
	var definition: GachaBallDefinition = gm.director.draw_item(eligible, gm.director_run_state, RNGManager.reward_rng) as GachaBallDefinition
	if definition == null:
		run_state.add_room_tokens(cost)
		if discount_active:
			gm.gacha_discounts_used[tier] = false
		return {"success": false, "error": "No eligible definitions"}

	var instance := GachaBallInstance.new()
	instance.initialize(definition)
	instance.location_container_tag = &"Rewards"
	instance.location_slot_index = slot_index
	gm._temporary_reward_master_dict[instance.ball_uuid] = instance
	gm._temporary_reward_container.set_uuid(slot_index, instance.ball_uuid)

	var trinity_triggered: bool = false
	if gm.has_trinket(&"trinket_trinity_charm") and not gm._trinity_rewarded:
		if tier == 1:
			gm._trinity_t1_drawn = true
		elif tier == 2:
			gm._trinity_t2_drawn = true
		elif tier == 3:
			gm._trinity_t3_drawn = true
		if gm._trinity_t1_drawn and gm._trinity_t2_drawn and gm._trinity_t3_drawn:
			gm._trinity_rewarded = true
			trinity_triggered = true
			run_state.add_room_tokens(1)

	return {
		"success": true,
		"transaction_type": &"REWARD_DRAW",
		"tier": tier,
		"cost": cost,
		"discount_applied": discount_active,
		"drawn_instance": instance,
		"slot_index": slot_index,
		"trinity_triggered": trinity_triggered,
		"remaining_tokens": run_state.get_room_tokens(),
	}


static func generate_shop_stock(gm: Node) -> void:
	gm._temporary_shop_master_dict.clear()
	gm._temporary_shop_container = FixedArrayContainerScript.new(3)

	var all_defs: Array = Database.get_all_pool_definitions()
	if all_defs.is_empty():
		return

	update_director_run_state(gm, DirectorRunState.Purpose.SHOP)
	var drawn_shop_items: Array = gm.director.draw_unique_items(all_defs, gm.director_run_state, 3, RNGManager.shop_rng)
	for i: int in range(drawn_shop_items.size()):
		var inst := GachaBallInstance.new()
		inst.initialize(drawn_shop_items[i])
		inst.location_container_tag = &"Shop"
		inst.location_slot_index = i
		gm._temporary_shop_master_dict[inst.ball_uuid] = inst
		gm._temporary_shop_container.set_uuid(i, inst.ball_uuid)


static func simulate_shop_purchase(gm: Node, instance_uuid: String, cost: int) -> Dictionary:
	if not gm._temporary_shop_master_dict.has(instance_uuid):
		return {"success": false, "error": "Instance not found in shop"}
	var run_state: RunState = gm.run_state
	if not is_instance_valid(run_state) or not run_state.spend_gold(cost):
		return {"success": false, "error": "Insufficient gold"}

	var purchased_instance: GachaBallInstance = gm._temporary_shop_master_dict[instance_uuid] as GachaBallInstance
	var def: Resource = purchased_instance.get_definition()
	var container_name: StringName = _resolve_acquisition_container(def)
	run_state.add_instance(purchased_instance, container_name, -1)
	if is_instance_valid(def):
		run_state.unlock_recipe_for_result(def.id)

	var slot_index: int = -1
	if is_instance_valid(gm._temporary_shop_container):
		slot_index = gm._temporary_shop_container.get_all_uuids().find(instance_uuid)
		if slot_index != -1:
			gm._temporary_shop_container.set_uuid(slot_index, "")

	gm._temporary_shop_master_dict.erase(instance_uuid)
	SignalBus.selection_clear_requested.emit()
	SignalBus.shop_stock_refreshed.emit({"shop_instances": gm._temporary_shop_master_dict.values(), "reroll_cost": gm._reroll_cost})

	return {
		"success": true,
		"transaction_type": &"SHOP_PURCHASE",
		"instance_uuid": instance_uuid,
		"purchased_instance": purchased_instance,
		"cost": cost,
		"slot_index": slot_index,
		"target_container": container_name,
		"remaining_gold": run_state.gold,
	}


static func reroll_shop(gm: Node) -> void:
	if not gm.run_state.spend_gold(gm._reroll_cost):
		return
	gm._reroll_cost += 1
	generate_shop_stock(gm)
	SignalBus.shop_stock_refreshed.emit({"shop_instances": gm._temporary_shop_master_dict.values(), "reroll_cost": gm._reroll_cost})


static func reroll_reward(gm: Node) -> void:
	var cost: int = gm.run_state.get_elite_reward_reroll_cost() if is_instance_valid(gm.run_state) else 5
	if not gm.run_state.spend_gold(cost):
		return
	gm.run_state.increase_elite_reward_reroll_cost()
	gm._reward_reroll_cost = gm.run_state.get_elite_reward_reroll_cost()
	generate_reward_stock(gm)
	SignalBus.reward_stock_refreshed.emit(gm.get_pending_rewards())


static func get_transform_result(source_definition: GachaBallDefinition) -> GachaBallDefinition:
	var eligible: Array[GachaBallDefinition] = []
	for definition in Database.get_all_pool_definitions():
		if not is_instance_valid(definition):
			continue
		if definition.id == source_definition.id or definition.tier != source_definition.tier or definition.category != source_definition.category:
			continue
		eligible.append(definition)
	if eligible.is_empty():
		return null
	return RNGManager.gacha_rng.pick_random(eligible)


static func handle_shrine_action(gm: Node, payload: Dictionary) -> void:
	var run_state: RunState = gm.run_state
	if not is_instance_valid(run_state):
		return
	var action_type: String = String(payload.get("type", ""))
	if action_type == "remove":
		var cost: int = int(payload["cost"])
		var instance_uuid: String = String(payload["instance_uuid"])
		if run_state.spend_gold(cost):
			run_state.remove_instance(instance_uuid)
			run_state.increase_shrine_remove_cost()
	elif action_type == "transform":
		var cost: int = int(payload["cost"])
		var instance_uuid: String = String(payload["instance_uuid"])
		var source_location: LocationIdentifier = payload["source_location"] as LocationIdentifier
		var result_definition: GachaBallDefinition = payload["result_definition"] as GachaBallDefinition
		var source_level: int = int(payload.get("source_level", 1))
		if not is_instance_valid(result_definition):
			return
		if run_state.spend_gold(cost):
			run_state.remove_instance(instance_uuid)
			var new_instance := GachaBallInstance.new()
			new_instance.initialize(result_definition)
			new_instance.level = source_level
			run_state.add_instance(new_instance, source_location.container, source_location.index)
			run_state.unlock_recipe_for_result(result_definition.id)


## Rolls a training reward value (stat increase or gold) for a given tier (1, 2, or 3 tokens).
## - Tier 1: 0 (10%), 1 (80%), 2 (10%)
## - Tier 2: 0 (10%), 1 (40%), 2 (40%), 3 (10%)
## - Tier 3: 0 (5%), 1 (15%), 2 (30%), 3 (30%), 4 (15%), 5 (5%)
static func roll_training_reward(tier: int) -> int:
	var roll_pct: int = RNGManager.reward_rng.randi_range(1, 100)
	match tier:
		1:
			if roll_pct <= 10:
				return 0
			if roll_pct <= 90:
				return 1
			return 2
		2:
			if roll_pct <= 10:
				return 0
			if roll_pct <= 50:
				return 1
			if roll_pct <= 90:
				return 2
			return 3
		3:
			if roll_pct <= 5:
				return 0
			if roll_pct <= 20:
				return 1
			if roll_pct <= 50:
				return 2
			if roll_pct <= 80:
				return 3
			if roll_pct <= 95:
				return 4
			return 5
		_:
			assert(false, "roll_training_reward: Invalid tier %d" % tier)
			return 0


static func simulate_rest_site_draw(gm: Node, tier: int) -> Dictionary:
	var run_state: RunState = gm.run_state
	if not is_instance_valid(run_state):
		return {"success": false, "error": "No active run_state"}
	var cost: int = tier
	if run_state.get_room_tokens() < cost:
		return {"success": false, "error": "Insufficient room tokens"}
	run_state.spend_room_tokens(cost)

	var value: int = roll_training_reward(tier)
	var slot_index: int = -1
	for i: int in range(4):
		var has_prize: bool = false
		for p: Dictionary in gm._temporary_rest_site_prizes:
			if int(p["slot_index"]) == i:
				has_prize = true
				break
		if not has_prize:
			slot_index = i
			break

	if slot_index == -1:
		if not gm._temporary_rest_site_prizes.is_empty():
			var oldest: Dictionary = gm._temporary_rest_site_prizes[0]
			apply_rest_site_prize_data(gm, oldest)
			gm._temporary_rest_site_prizes.remove_at(0)
			for rem: Dictionary in gm._temporary_rest_site_prizes:
				if int(rem["slot_index"]) > 0:
					rem["slot_index"] = int(rem["slot_index"]) - 1
			slot_index = 3
		else:
			slot_index = 0

	var prize_data: Dictionary = {
		"slot_index": slot_index,
		"hp_value": value if gm.current_rest_site_type == 0 else 0,
		"pwr_value": value if gm.current_rest_site_type == 1 else 0,
		"gold_value": value if gm.current_rest_site_type == 2 else 0,
	}
	gm._temporary_rest_site_prizes.append(prize_data)
	return {
		"success": true,
		"transaction_type": &"REST_SITE_DRAW",
		"tier": tier,
		"cost": cost,
		"prize_data": prize_data,
		"remaining_tokens": run_state.get_room_tokens(),
		"prizes_snapshot": gm._temporary_rest_site_prizes.duplicate(true),
	}


static func simulate_dojo_training(gm: Node, token_cost: int) -> Dictionary:
	var run_state: RunState = gm.run_state
	if not is_instance_valid(run_state):
		return {"success": false, "error": "No active run_state"}
	if run_state.get_room_tokens() < token_cost:
		return {"success": false, "error": "Insufficient room tokens"}

	run_state.spend_room_tokens(token_cost)
	var roll: int = roll_training_reward(token_cost)
	var uuid: String = run_state.training_unit_uuid
	var stat: String = run_state.training_stat
	var hp_delta: int = 0
	var pwr_delta: int = 0
	if not uuid.is_empty() and roll > 0:
		hp_delta = roll if stat == "hp" else 0
		pwr_delta = roll if stat == "pwr" else 0
		run_state.modify_unit_base_stats(uuid, hp_delta, pwr_delta)

	return {
		"success": true,
		"transaction_type": &"DOJO_TRAIN",
		"token_cost": token_cost,
		"roll": roll,
		"unit_uuid": uuid,
		"training_stat": stat,
		"hp_delta": hp_delta,
		"pwr_delta": pwr_delta,
		"remaining_tokens": run_state.get_room_tokens(),
	}


static func claim_rest_site_prize(gm: Node, slot_index: int) -> Dictionary:
	for i: int in range(gm._temporary_rest_site_prizes.size()):
		if int(gm._temporary_rest_site_prizes[i]["slot_index"]) == slot_index:
			var prize: Dictionary = gm._temporary_rest_site_prizes[i]
			gm._temporary_rest_site_prizes.remove_at(i)
			apply_rest_site_prize_data(gm, prize)
			return prize
	return {}


static func apply_rest_site_prize_data(gm: Node, prize_data: Dictionary) -> void:
	var run_state: RunState = gm.run_state
	if not is_instance_valid(run_state):
		return
	if gm.current_rest_site_type == 2:
		run_state.add_gold(int(prize_data.get("gold_value", 0)))
	elif is_instance_valid(run_state.hero_instance):
		run_state.modify_unit_base_stats(
			run_state.hero_instance.ball_uuid,
			int(prize_data.get("hp_value", 0)),
			int(prize_data.get("pwr_value", 0))
		)


static func auto_claim_all_rest_site_prizes(gm: Node) -> void:
	while not gm._temporary_rest_site_prizes.is_empty():
		var p: Dictionary = gm._temporary_rest_site_prizes[0]
		gm._temporary_rest_site_prizes.remove_at(0)
		apply_rest_site_prize_data(gm, p)


static func _resolve_acquisition_container(def: Resource) -> StringName:
	if is_instance_valid(def) and "category" in def and def.category == &"TRINKET":
		return RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS
	var tier_val: int = int((def as GachaBallDefinition).tier) if def is GachaBallDefinition else 1
	return &"RunInventoryT%d" % tier_val
