<!-- Original: scripts/BattleManager.gd -->

```gdscript
extends Node
class_name BattleManager

# --- TDD: Battle State Machine ---
enum Phases { START_OF_TURN, MANAGEMENT, COMBAT, END_OF_TURN, BATTLE_OVER }
var _current_battle_phase: Phases

# --- TDD: Data-Driven State ---
var _battle_instances: Dictionary = {} 
var _data_containers: Dictionary = {} 

var _gacha_tokens: int = 0
var _draw_pools: Dictionary = { 1: [], 2: [], 3: [] }

func _ready():
	add_to_group("battle_manager")
	_setup_battle()
	_connect_signals()

	GameManager.is_in_battle = true
	EventBus.emit_signal("battle_state_changed", true)
	EventBus.emit_signal("battle_inventory_changed")

	_change_phase(Phases.START_OF_TURN)

func _exit_tree():
	GameManager.is_in_battle = false
	EventBus.emit_signal("battle_state_changed", false)
	if EventBus.is_connected("end_turn_requested", _on_end_turn_requested):
		EventBus.end_turn_requested.disconnect(_on_end_turn_requested)
	if EventBus.is_connected("draw_gacha_requested", _on_draw_gacha_requested):
		EventBus.draw_gacha_requested.disconnect(_on_draw_gacha_requested)
	if EventBus.is_connected("unit_inventory_changed", _on_unit_inventory_changed):
		EventBus.unit_inventory_changed.disconnect(_on_unit_inventory_changed)


func _connect_signals():
	# This is now fully compliant with the TDD. BattleManager only listens to abstract signals.
	EventBus.end_turn_requested.connect(_on_end_turn_requested)
	EventBus.draw_gacha_requested.connect(_on_draw_gacha_requested)
	EventBus.unit_inventory_changed.connect(_on_unit_inventory_changed)

# --- Public API for Managers ---
func get_instance(uuid: String) -> GachaBallInstance:
	return _battle_instances.get(uuid)

func get_all_instances() -> Dictionary:
	return _battle_instances

func get_container(container_name: StringName) -> DataContainer:
	return _data_containers.get(container_name)

func remove_instance_by_uuid(uuid: String):
	if _battle_instances.has(uuid):
		_battle_instances.erase(uuid)

func get_instance_by_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc):
		return null

	if loc.container == &"equipped_item":
		var owner_unit = get_instance(loc.get("unit_uuid")) 
		if is_instance_valid(owner_unit):
			var item_uuid = owner_unit.get_equipped_item_uuid_at_index(loc.index)
			return get_instance(item_uuid)
		return null

	if _data_containers.has(loc.container):
		var container = _data_containers[loc.container]
		var uuid = container.get_uuid(loc.index)
		return get_instance(uuid)

	return null

# --- Battle Setup ---
func _setup_battle():
	# 1. Initialize all temporary DataContainers as per TDD
	_data_containers[&"PlayerLineup"] = FixedArrayContainer.new(6)
	_data_containers[&"PlayerBench"] = FixedArrayContainer.new(3)
	_data_containers[&"ItemInventory"] = FixedArrayContainer.new(3)
	_data_containers[&"EnemyLineup"] = FixedArrayContainer.new(6)
	_data_containers[&"BattleInventoryT1"] = GrowableGridContainer.new(16)
	_data_containers[&"BattleInventoryT2"] = GrowableGridContainer.new(16)
	_data_containers[&"BattleInventoryT3"] = GrowableGridContainer.new(16)
	_data_containers[&"DiscardPile"] = GrowableGridContainer.new(16)

	# 2. Create a battle copy of the player's hero and place it.
	var player_hero_copy = GameManager.run_state.hero_instance.create_battle_copy()
	_battle_instances[player_hero_copy.ball_uuid] = player_hero_copy
	_data_containers[&"PlayerLineup"].set_uuid(0, player_hero_copy.ball_uuid)

	# 3. Create battle copies of the player's RUN INVENTORY.
	if is_instance_valid(GameManager.run_state):
		for container_name in GameManager.run_state.run_inventory_containers:
			var run_container = GameManager.run_state.get_container(container_name)
			if not is_instance_valid(run_container): continue

			for uuid in run_container.get_all_non_empty_uuids():
				var permanent_instance = GameManager.run_state.run_instances.get(uuid)
				if is_instance_valid(permanent_instance):
					var battle_copy = permanent_instance.create_battle_copy()
					_battle_instances[battle_copy.ball_uuid] = battle_copy
					
					var def = battle_copy.get_definition()
					if not is_instance_valid(def): continue
						
					# Populate draw pools
					if _draw_pools.has(def.tier):
						_draw_pools[def.tier].append(battle_copy.ball_uuid)

					# THIS IS THE CRUCIAL FIX:
					# Find the correct battle inventory container and add the new UUID.
					var battle_container_name = &"BattleInventoryT%d" % def.tier
					var battle_container = get_container(battle_container_name)
					if is_instance_valid(battle_container):
						var empty_idx = battle_container.find_first_empty_slot()
						battle_container.set_uuid(empty_idx, battle_copy.ball_uuid)

	# 4. Setup the enemy lineup
	_setup_enemy_lineup()
	
	# 5. Recalculate stats for all units now that they are all created
	for instance in _battle_instances.values():
		if is_instance_valid(instance) and instance.get_definition().category == &"UNIT":
			instance.recalculate_stats(_battle_instances)

func _setup_enemy_lineup():
	var enemy_unit_ids = [&"enemy_hero", &"unit_t1_a", &"unit_t1_b", &"unit_t2_c", &"unit_t3_d"]
	var all_item_defs = Database.items.values()
	var enemy_lineup_container = _data_containers[&"EnemyLineup"]

	for i in range(min(enemy_unit_ids.size(), 6)):
		var unit_def = Database.get_definition(enemy_unit_ids[i])
		if unit_def:
			var enemy_instance = GachaBallInstance.new()
			enemy_instance.initialize(unit_def)
			_battle_instances[enemy_instance.ball_uuid] = enemy_instance
			
			for j in range(enemy_instance.equipped_item_uuids.size()):
				if not all_item_defs.is_empty():
					var item_def = all_item_defs.pick_random()
					var item_instance = GachaBallInstance.new()
					item_instance.initialize(item_def)
					_battle_instances[item_instance.ball_uuid] = item_instance
					enemy_instance.equipped_item_uuids[j] = item_instance.ball_uuid
			
			enemy_lineup_container.set_uuid(i, enemy_instance.ball_uuid)

# --- State Machine Logic ---
func _change_phase(new_phase: Phases):
	if _current_battle_phase == Phases.BATTLE_OVER: return

	_current_battle_phase = new_phase
	var phase_name = StringName(Phases.keys()[new_phase])
	EventBus.emit_signal("battle_phase_changed", phase_name)
	print("BattleManager: Entering phase -> ", phase_name)
	
	match _current_battle_phase:
		Phases.START_OF_TURN: await _enter_start_of_turn_phase()
		Phases.MANAGEMENT: _enter_management_phase()
		Phases.COMBAT: await _enter_combat_phase()
		Phases.END_OF_TURN: _enter_end_of_turn_phase()

func _enter_start_of_turn_phase():
	_gacha_tokens += 5
	EventBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
	_change_phase(Phases.MANAGEMENT)

func _enter_management_phase():
	pass

func _enter_combat_phase():
	await _execute_combat_resolution()
	_change_phase(Phases.END_OF_TURN)

func _enter_end_of_turn_phase():
	var all_enemies_defeated = _data_containers[&"EnemyLineup"].get_all_non_empty_uuids().is_empty()
	var player_hero_uuid = _data_containers[&"PlayerLineup"].get_uuid(0)
	var player_hero_instance = get_instance(player_hero_uuid)
	var player_hero_defeated = not is_instance_valid(player_hero_instance) or player_hero_instance.current_hp <= 0

	if all_enemies_defeated:
		_current_battle_phase = Phases.BATTLE_OVER
		WindowManager.open_end_battle_popup(true)
	elif player_hero_defeated:
		_current_battle_phase = Phases.BATTLE_OVER
		WindowManager.open_end_battle_popup(false)
	else:
		_change_phase(Phases.START_OF_TURN)

func _execute_combat_resolution():
	print("--- COMBAT PHASE START ---")
	var basic_attack_def = Database.abilities.get(&"basic_attack")
	if not basic_attack_def:
		printerr("BasicAttack ability not found in Database.")
		return

	var player_lineup_uuids = _data_containers[&"PlayerLineup"].get_all_uuids()
	var enemy_lineup_uuids = _data_containers[&"EnemyLineup"].get_all_uuids()

	for i in range(player_lineup_uuids.size() - 1, -1, -1):
		var attacker_uuid = player_lineup_uuids[i]
		if not attacker_uuid: continue
		var attacker = get_instance(attacker_uuid)
		if not is_instance_valid(attacker) or attacker.current_hp <= 0: continue

		var target = _get_frontmost_target(true)
		if is_instance_valid(target):
			AbilityResolver.execute_effect(basic_attack_def.effect, attacker, [target], self)
			_check_for_deaths()
			if _is_battle_over(): return
			await get_tree().create_timer(0.5).timeout
		else: break

	for i in range(enemy_lineup_uuids.size() - 1, -1, -1):
		var attacker_uuid = enemy_lineup_uuids[i]
		if not attacker_uuid: continue
		var attacker = get_instance(attacker_uuid)
		if not is_instance_valid(attacker) or attacker.current_hp <= 0: continue

		var target = _get_frontmost_target(false)
		if is_instance_valid(target):
			AbilityResolver.execute_effect(basic_attack_def.effect, attacker, [target], self)
			_check_for_deaths()
			if _is_battle_over(): return
			await get_tree().create_timer(0.5).timeout
		else: break
		
	print("--- COMBAT PHASE END ---")

func _check_for_deaths():
	var uuids_to_process = _data_containers[&"PlayerLineup"].get_all_uuids() + _data_containers[&"EnemyLineup"].get_all_uuids()
	var inventory_changed = false
	for uuid in uuids_to_process:
		if uuid.is_empty(): continue
		var instance = get_instance(uuid)
		if is_instance_valid(instance) and instance.current_hp <= 0:
			print("Unit defeated: ", instance.get_definition().id)
			for container_name in _data_containers:
				var container = _data_containers[container_name]
				var index = container.get_all_uuids().find(uuid)
				if index != -1:
					container.set_uuid(index, "")
					_add_to_discard_pile(uuid)
					inventory_changed = true
					break
	if inventory_changed:
		EventBus.emit_signal("battle_inventory_changed")

func _is_battle_over() -> bool:
	return _data_containers[&"EnemyLineup"].get_all_non_empty_uuids().is_empty() or not is_instance_valid(get_instance(_data_containers[&"PlayerLineup"].get_uuid(0)))

func _on_unit_inventory_changed(unit_uuid: String):
	if not _battle_instances.has(unit_uuid): return
	var unit_instance = _battle_instances[unit_uuid]
	if is_instance_valid(unit_instance):
		unit_instance.recalculate_stats(_battle_instances)
		EventBus.emit_signal("unit_stats_changed", unit_uuid)
		EventBus.emit_signal("battle_inventory_changed")

func _on_end_turn_requested():
	if _current_battle_phase == Phases.MANAGEMENT:
		_change_phase(Phases.COMBAT)

func _on_draw_gacha_requested(tier: int):
	var cost = tier
	if _gacha_tokens < cost:
		print("Not enough tokens to draw tier %d." % tier)
		return
	
	if not _draw_pools.has(tier) or _draw_pools[tier].is_empty():
		_reshuffle_discard_pile(tier)
		if _draw_pools[tier].is_empty():
			print("No items of tier %d in discard to reshuffle." % tier)
			return

	_gacha_tokens -= cost
	EventBus.emit_signal("gacha_tokens_changed", _gacha_tokens)

	var pool = _draw_pools[tier]
	var drawn_uuid = pool.pick_random()
	pool.erase(drawn_uuid)
	
	var drawn_instance = _battle_instances[drawn_uuid]
	var definition = drawn_instance.get_definition()

	var target_container_name: StringName
	match definition.category:
		&"UNIT":
			target_container_name = &"PlayerBench"
		&"ITEM":
			target_container_name = &"ItemInventory"
		&"GACHABALL":
			target_container_name = &"BattleInventoryT%d" % definition.tier

	var target_container = _data_containers[target_container_name]
	var empty_idx = target_container.find_first_empty_slot()
	
	if empty_idx != -1:
		target_container.set_uuid(empty_idx, drawn_uuid)
	else:
		_add_to_discard_pile(drawn_uuid)

	EventBus.emit_signal("battle_inventory_changed")

func _reshuffle_discard_pile(tier_to_reshuffle: int):
	var uuids_to_move = []
	var discard_container = _data_containers[&"DiscardPile"]
	for uuid in discard_container.get_all_non_empty_uuids():
		var instance = get_instance(uuid)
		if is_instance_valid(instance) and instance.get_definition().tier == tier_to_reshuffle:
			uuids_to_move.append(uuid)
	
	if uuids_to_move.is_empty(): return

	for uuid in uuids_to_move:
		_draw_pools[tier_to_reshuffle].append(uuid)
		var index = discard_container.get_all_uuids().find(uuid)
		if index != -1:
			discard_container.set_uuid(index, "")
	
	EventBus.emit_signal("battle_inventory_changed")

func _add_to_discard_pile(uuid: String):
	var discard_container = _data_containers[&"DiscardPile"]
	var empty_idx = discard_container.find_first_empty_slot()
	discard_container.set_uuid(empty_idx, uuid)

func get_battle_inventory() -> Dictionary:
	var inventory = {}
	for tier in [1, 2, 3]:
		var container_name = &"BattleInventoryT%d" % tier
		var container = get_container(container_name)
		var instances = []
		if is_instance_valid(container):
			for uuid in container.get_all_uuids():
				# This will correctly append null if the uuid is empty,
				# preserving the empty slots for the UI.
				instances.append(get_instance(uuid))
		inventory[tier] = instances
	return inventory

func get_discard_pile_inventory() -> Dictionary:
	var inventory = { 1: [], 2: [], 3: [] }
	for uuid in _data_containers[&"DiscardPile"].get_all_non_empty_uuids():
		var instance = get_instance(uuid)
		if is_instance_valid(instance):
			var tier = instance.get_definition().tier
			if inventory.has(tier):
				inventory[tier].append(instance)
	return inventory

func _get_frontmost_target(is_player_attacking: bool) -> GachaBallInstance:
	var target_lineup = _data_containers[&"EnemyLineup"] if is_player_attacking else _data_containers[&"PlayerLineup"]
	for uuid in target_lineup.get_all_uuids():
		if uuid.is_empty(): continue
		var instance = get_instance(uuid)
		if is_instance_valid(instance) and instance.current_hp > 0:
			return instance
	return null

```