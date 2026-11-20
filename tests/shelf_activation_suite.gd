extends Node

const C = preload("res://scripts/Constants.gd")
const BattleManagerScript = preload("res://scripts/BattleManager.gd")

var bm: BattleManagerScript
var checks: int = 0
var failures: int = 0

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _reset() -> void:
	bm._state = BattleState.new()
	bm._state.player_shelf_slots_unlocked = C.PLAYER_SHELF_CAP
	bm._combat = CombatSimulator.new()
	GameManager.run_state = RunState.new()
	GameManager.run_state.gold = 30
	GameManager.run_state.current_room_tokens = 5

func _add(definition_id: StringName, container: StringName, level: int = 1) -> GachaBallInstance:
	var instance := GachaBallInstance.new()
	var definition: Resource = Database.get_definition(definition_id)
	if definition is TrinketDefinition:
		instance.initialize_from_trinket(definition)
	else:
		instance.initialize(definition)
	instance.level = level
	assert(bm._state.bm_add_instance(instance, container), "Test placement failed: %s" % definition_id)
	return instance

func _equip(holder: GachaBallInstance, definition_id: StringName) -> GachaBallInstance:
	var item := GachaBallInstance.new()
	item.initialize(Database.get_definition(definition_id))
	if holder.location_container_tag in [&"PlayerShelf", &"EnemyShelf"]:
		# Seed a legacy carried-equipment fixture without invoking a gameplay equip.
		bm._state.register_instance(item)
		holder.equipped_item_uuids[0] = item.ball_uuid
		item.equipped_on_uuid = holder.ball_uuid
		item.equipped_slot_index = 0
		item.location_container_tag = C.CONTAINER_EQUIPPED_ITEM
		item.location_slot_index = 0
		holder.equip_item_bonus(item)
		return item
	assert(InventoryOperations.register_and_equip_item(bm._state, item, holder.ball_uuid).success)
	return item

func _trigger(trigger: StringName, context: TriggerContext = null) -> Array[CombatEvent]:
	if context == null:
		context = TriggerContext.new()
	context.is_simulation = true
	AbilityResolver.process_trigger(trigger, context)
	return bm._combat.process_reaction_queue(bm, {})

func _test_gold_and_merge() -> void:
	_reset()
	var active: GachaBallInstance = _add(&"?MerSpe", &"PlayerLineup")
	var shelf: GachaBallInstance = _add(&"?MerSpe", &"PlayerShelf")
	_equip(active, &"item_mercenary_emblem")
	_equip(shelf, &"item_mercenary_emblem")
	var active_hp: int = active.current_hp
	var shelf_hp: int = shelf.current_hp
	_trigger(C.TRIGGER_ON_GOLD_EARNED)
	_check(active.current_hp == active_hp + 2, "Active Coinling and Mercenary Emblem must both react to Gold")
	_check(shelf.current_hp == shelf_hp, "Shelved Coinling and Mercenary Emblem must not react to Gold")
	assert(bm._state.transfer_instance_to_container(shelf, &"PlayerLineup") >= 0)
	_trigger(C.TRIGGER_ON_GOLD_EARNED)
	_check(shelf.current_hp == shelf_hp + 2, "Redeployed mercenary must resume without catching up skipped Gold")

	_reset()
	active = _add(&"EFFWSpeApp", &"PlayerLineup")
	shelf = _add(&"EFFWSpeApp", &"PlayerShelf")
	var merged: GachaBallInstance = _add(&"ETnkPla", &"PlayerLineup")
	_add(&"trinket_tier1_insignia", &"PlayerTrinkets")
	active_hp = active.current_hp
	shelf_hp = shelf.current_hp
	var merged_hp: int = merged.current_hp
	var merge_context := TriggerContext.new()
	merge_context.merged_uuid = merged.ball_uuid
	merge_context.merged_team = "PLAYER"
	merge_context.merge_container = &"PlayerLineup"
	_trigger(C.TRIGGER_ON_MERGE, merge_context)
	_check(active.current_hp == active_hp + 2, "Active Blendroid must react to a Lineup merge")
	_check(shelf.current_hp == shelf_hp, "Shelved Blendroid must not react to merges")
	_check(merged.current_hp == merged_hp + 1, "Insignia must buff an eligible Lineup merge result")

func _test_healing_and_equipment() -> void:
	_reset()
	var active: GachaBallInstance = _add(&"EFTnkMec", &"PlayerLineup")
	var shelf: GachaBallInstance = _add(&"EFTnkMec", &"PlayerShelf")
	var initial_hp: int = shelf.current_hp
	_equip(active, &"item_t1_a")
	_equip(shelf, &"item_t1_a")
	_check(shelf.current_hp == initial_hp + 1, "A carried-equipment fixture retains its initial static equipment stats")
	var active_hp: int = active.current_hp
	var shelf_hp: int = shelf.current_hp
	_trigger(C.TRIGGER_AT_TURN_START)
	_check(active.current_hp == active_hp + 2, "Candy must heal its active holder")
	_check(shelf.current_hp == shelf_hp, "Candy must not heal its shelf holder")
	_check(active.get_status_effect_amount(&"armor") == 1, "Active Bramblee must react to healing")
	var potion: GachaBallInstance = _add(&"item_potion_t1", &"PlayerShelf")
	GameManager.is_in_battle = true
	InventoryManager._use_consumable(potion, shelf)
	_check(shelf.current_hp == shelf_hp, "Consumables must reject Shelf residents")
	_check(shelf.get_status_effect_amount(&"armor") == 0 and shelf.get_status_effect_amount(&"spikes") == 0, "Consumable healing must not activate shelved Bramblee")

func _test_ally_reactions_and_traits() -> void:
	for team: String in ["Player", "Enemy"]:
		_reset()
		var active: GachaBallInstance = _add(&"EWFigCos", StringName(team + "Lineup"))
		var shelf: GachaBallInstance = _add(&"EWFigCos", StringName(team + "Shelf"))
		var casualty: GachaBallInstance = _add(&"FFigMec", StringName(team + "Lineup"))
		var context := TriggerContext.new()
		context.ally_knocked_out_uuid = casualty.ball_uuid
		context.ally_knocked_out_team = team.to_upper()
		var active_pwr: int = active.current_pwr
		var shelf_pwr: int = shelf.current_pwr
		_trigger(C.TRIGGER_WHEN_ALLY_KNOCKED_OUT, context)
		_check(active.current_pwr == active_pwr + 1, "%s active Bogmantle must react to ally knockouts" % team)
		_check(shelf.current_pwr == shelf_pwr, "%s shelved Bogmantle must not react to ally knockouts" % team)

	_reset()
	var plants: Array[GachaBallInstance] = []
	for index: int in range(5):
		plants.append(_add(&"ETnkPla", &"PlayerLineup"))
	var shelf_plant: GachaBallInstance = _add(&"ETnkPla", &"PlayerShelf")
	_add(&"trinket_trait_plant", &"PlayerTrinkets")
	_check(bm.get_active_traits("PLAYER").get("PLANT", 0) >= 5, "Plant test must activate the heal-to-Spikes trait")
	bm.apply_stat_delta(shelf_plant, "hp", 4, "", C.ACTION_HEAL, true, C.CATEGORY_CONSUMABLE)
	bm.apply_stat_delta(plants[0], "hp", 4, "", C.ACTION_HEAL, true, C.CATEGORY_CONSUMABLE)
	_check(shelf_plant.get_status_effect_amount(&"spikes") == 0, "Shelf healing must not activate Plant trait Spikes")
	_check(plants[0].get_status_effect_amount(&"spikes") == 1, "Lineup healing must still activate Plant trait Spikes")

func _test_bubblegunger_pool() -> void:
	for level: int in range(1, 4):
		_reset()
		var active: GachaBallInstance = _add(&"EFWASpeFod", &"PlayerLineup", level)
		var shelf: GachaBallInstance = _add(&"EFWASpeFod", &"PlayerShelf", level)
		var stored: GachaBallInstance = _add(&"EFWASpeFod", &"BattleInventoryT3")
		_add(&"EFWASpeFod", &"DiscardPile")
		var enemy: GachaBallInstance = _add(&"EFWASpeFod", &"EnemyLineup")
		var events: Array[CombatEvent] = _trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED)
		var expected_bonus: int = 3 * (level + 2)
		_check(active.current_pwr == 4 + expected_bonus, "BubbleGunger L%d must count shelf, machine and discard copies" % level)
		_check(shelf.current_pwr == 4, "Sealed BubbleGunger L%d must retain its PWR" % level)
		_check(enemy.current_pwr == 4, "BubbleGunger must count allied copies only")
		var shelf_event_found: bool = false
		for event: CombatEvent in events:
			if event.target_uuids.has(shelf.ball_uuid):
				shelf_event_found = true
		_check(not shelf_event_found, "Sealed BubbleGunger must not emit a PWR change event")
		assert(bm._state.transfer_instance_to_container(stored, &"PlayerShelf") >= 0)
		_trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED)
		_check(active.current_pwr == 4 + expected_bonus, "Moving a counted copy must not change BubbleGunger's bonus")
		bm._state.bm_remove_instance(stored.ball_uuid)
		_trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED)
		_check(active.current_pwr == 4 + 2 * (level + 2), "Removing a copy must recalculate BubbleGunger's bonus")
		_check(shelf.current_pwr == 4, "Sealed BubbleGunger must remain unchanged when the copy count changes")

func _test_passive_exceptions() -> void:
	_reset()
	var growing: GachaBallInstance = _add(&"FWAASpeToy", &"PlayerShelf")
	var active_growing: GachaBallInstance = _add(&"FWAASpeToy", &"PlayerLineup")
	_equip(growing, &"item_t1_a")
	var old_hp: int = growing.current_hp
	var active_hp: int = active_growing.current_hp
	_trigger(C.TRIGGER_AT_TURN_START)
	_check(growing.current_hp == old_hp + 3, "Wind-up-kun must grow on the shelf without activating Candy")
	_check(active_growing.current_hp == active_hp, "Wind-up-kun must not gain shelf growth in the lineup")
	var furnair: GachaBallInstance = _add(&"FASpeApp", &"PlayerShelf")
	var old_pwr: int = furnair.current_pwr
	_trigger(C.TRIGGER_ON_GACHA_TOKENS_CHANGED)
	_check(furnair.current_pwr == old_pwr, "Sealed Furnair must not recalculate token PWR")
	GameManager.run_state.current_room_tokens = 2
	_trigger(C.TRIGGER_ON_GACHA_TOKENS_CHANGED)
	_check(furnair.current_pwr == old_pwr, "Sealed Furnair remains unchanged when Tokens are spent")

	_reset()
	var holder: GachaBallInstance = _add(&"FFigMec", &"PlayerShelf")
	var seal: GachaBallInstance = _equip(holder, &"item_golden_seal")
	old_hp = holder.current_hp
	_trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED)
	_check(holder.current_hp == old_hp, "Golden Seal must not recalculate while its holder is sealed")
	GameManager.run_state.gold = 10
	_trigger(C.TRIGGER_ON_GOLD_SPENT)
	_check(holder.current_hp == old_hp, "Golden Seal must not update a sealed holder after Gold changes")
	InventoryOperations.move_instance_to_discard(bm._state, seal)
	old_hp = holder.current_hp
	_trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED)
	_check(holder.current_hp == old_hp, "A sealed fixture has no active Golden Seal bonus to remove")

	_reset()
	holder = _add(&"FFigMec", &"PlayerShelf")
	_equip(holder, &"item_t2_d")
	_add(&"item_t2_d", &"BattleInventoryT2")
	old_pwr = holder.current_pwr
	_trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED)
	_check(holder.current_pwr == old_pwr, "Slime Cell must not update a sealed holder")

func _test_trinket_targets() -> void:
	_reset()
	var active: GachaBallInstance = _add(&"FFigMec", &"PlayerLineup")
	var ally: GachaBallInstance = _add(&"FFigMec", &"PlayerLineup")
	var shelf: GachaBallInstance = _add(&"FFigMec", &"PlayerShelf")
	var enemy: GachaBallInstance = _add(&"FFigMec", &"EnemyLineup")
	_add(&"trinket_armor_aura", &"PlayerTrinkets")
	_trigger(C.TRIGGER_AT_TURN_START)
	_check(active.get_status_effect_amount(&"armor") == 0, "Armor Aura must wait until pre-combat")
	_trigger(C.TRIGGER_PRE_COMBAT)
	_check(active.get_status_effect_amount(&"armor") == 1, "Armor Aura must grant 1 Armor to active allies in pre-combat")
	_check(ally.get_status_effect_amount(&"armor") == 1, "Armor Aura must grant 1 Armor to every active ally")
	_check(shelf.get_status_effect_amount(&"armor") == 0, "Armor Aura must not affect shelved allies")
	_check(enemy.get_status_effect_amount(&"armor") == 0, "Armor Aura must not affect the opposing lineup")
	_add(&"trinket_rusty_ring", &"PlayerTrinkets")
	_add(&"trinket_twin_charm", &"PlayerTrinkets")
	var old_hp: int = shelf.current_hp
	var old_pwr: int = shelf.current_pwr
	_trigger(C.TRIGGER_AT_BATTLE_START)
	_trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED)
	_check(shelf.current_hp == old_hp, "Rusty Ring must not buff sealed Shelf capsules")
	_check(shelf.current_pwr == old_pwr, "Rusty Ring and Twin Charm must not update sealed Shelf PWR")

func _test_status_pause_and_resume() -> void:
	_reset()
	var active: GachaBallInstance = _add(&"FFigMec", &"PlayerLineup")
	var shelf: GachaBallInstance = _add(&"FFigMec", &"PlayerShelf")
	active.set_current_hp_silent(30)
	shelf.set_current_hp_silent(30)
	var statuses: Dictionary[StringName, int] = {&"burn": 4, &"static": 3, &"armor": 5, &"spikes": 3, &"bounty": 2, &"reinforce": 2}
	for unit: GachaBallInstance in [active, shelf]:
		for status: StringName in statuses:
			unit.add_status_effect_silent(status, statuses[status])
	var all_units: Array[GachaBallInstance] = [active, shelf]
	var events: Array[CombatEvent] = []
	for phase: String in ["START_OF_TURN", "END_OF_TURN"]:
		for status_definition: CombatEffectDefinition in CombatEffectRegistry.get_turn_effects(phase):
			bm._process_status_turn_effect(status_definition, all_units, events, {})
	_check(shelf.current_hp == 30, "Burn must not damage a shelf unit")
	for status: StringName in statuses:
		_check(shelf.get_status_effect_amount(status) == statuses[status], "Shelf %s stacks must remain frozen" % status)
	_check(active.current_hp == 26, "Burn must still damage active units")
	_check(active.get_status_effect_amount(&"static") == 2, "Active Static must still decay")
	assert(bm._state.transfer_instance_to_container(shelf, &"PlayerLineup") >= 0)
	bm._process_status_turn_effect(CombatEffectRegistry.get_definition(&"burn"), [shelf], events, {})
	_check(shelf.current_hp == 26, "Redeployed Burn must resume for one turn without catch-up damage")
	_check(shelf.get_status_effect_amount(&"burn") == active.get_status_effect_amount(&"burn"), "Redeployed Burn must decay normally")

	_reset()
	shelf = _add(&"FFigMec", &"PlayerShelf")
	var attacker: GachaBallInstance = _add(&"FFigMec", &"EnemyLineup")
	shelf.set_current_hp_silent(20)
	shelf.add_status_effect_silent(&"armor", 5)
	shelf.add_status_effect_silent(&"spikes", 3)
	shelf.add_status_effect_silent(&"static", 2)
	var attacker_hp: int = attacker.current_hp
	bm.apply_damage(shelf, 1, C.DamageType.MELEE, attacker.ball_uuid)
	_check(shelf.current_hp == 19 and shelf.get_status_effect_amount(&"armor") == 5, "Shelf Armor must not activate or be consumed")
	_check(attacker.current_hp == attacker_hp and shelf.get_status_effect_amount(&"spikes") == 3, "Shelf Spikes must not retaliate or lose stacks")
	KnockoutProcessor._process_static_collateral_damage(bm, shelf, shelf.get_location(), "PLAYER", events)
	_check(shelf.get_status_effect_amount(&"static") == 2, "Shelf Static must not discharge on knockout")
	shelf.add_status_effect_silent(&"bounty", 2)
	var gold_before: int = GameManager.run_state.gold
	KnockoutProcessor._process_bounty_death(bm, shelf, events, shelf.get_location())
	_check(GameManager.run_state.gold == gold_before and shelf.get_status_effect_amount(&"bounty") == 2, "Shelf Bounty must not activate or consume stacks")
	assert(bm._state.transfer_instance_to_container(shelf, &"PlayerLineup") >= 0)
	bm.apply_damage(shelf, 1, C.DamageType.MELEE, attacker.ball_uuid)
	_check(shelf.current_hp == 19 and shelf.get_status_effect_amount(&"armor") == 4, "Redeployed Armor must resume absorbing damage")
	_check(attacker.current_hp == attacker_hp - 3 and shelf.get_status_effect_amount(&"spikes") == 2, "Redeployed Spikes must resume retaliation")

func _run() -> void:
	RNGManager.initialize(73410)
	var previous_run: RunState = GameManager.run_state
	bm = BattleManagerScript.new()
	add_child(bm)
	_test_gold_and_merge()
	_test_healing_and_equipment()
	_test_ally_reactions_and_traits()
	_test_bubblegunger_pool()
	_test_passive_exceptions()
	_test_trinket_targets()
	_test_status_pause_and_resume()
	GameManager.run_state = previous_run
	bm.free()
	print("Shelf activation suite: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
