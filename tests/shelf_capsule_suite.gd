extends Node

const C = preload("res://scripts/Constants.gd")

class PurchaseViewFixture extends BattleView:
	func _ready() -> void:
		pass

class TokenHudFixture extends Control:
	var visual_tokens: int = 20
	var flights: int = 0
	var machine_changes: Array[Vector2i] = []
	func animate_machine_inventory_change(tier: int, delta: int) -> void:
		machine_changes.append(Vector2i(tier, delta))
	func get_gacha_machine(tier: int) -> Control:
		return get_node("GachaMachine%d" % tier) as Control
	func get_discard_machine() -> Control:
		return get_node("GachaMachineDiscard") as Control
	func begin_token_animation() -> void:
		flights += 1
	func modify_visual_tokens(delta: int, _pop: bool = true) -> void:
		visual_tokens += delta
	func end_token_animation() -> void:
		flights -= 1
		assert(flights >= 0)
		if flights == 0:
			assert(visual_tokens == GameManager.run_state.current_room_tokens)

var battle: BattleManager
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
	battle._state = BattleState.new()
	battle._combat = CombatSimulator.new()
	battle._current_battle_phase = BattleManager.Phases.START_OF_TURN
	GameManager.run_state = RunState.new()
	GameManager.run_state.current_room_tokens = 20
	GameManager.run_state.gold = 30

func _add(definition_id: StringName, container: StringName) -> GachaBallInstance:
	var instance: GachaBallInstance = GachaBallInstance.new()
	var definition: Resource = Database.get_definition(definition_id)
	assert(definition != null, "Missing test definition: %s" % definition_id)
	if definition is TrinketDefinition:
		instance.initialize_from_trinket(definition)
	else:
		instance.initialize(definition)
	assert(battle._state.bm_add_instance(instance, container))
	return instance

func _trigger(trigger: StringName, context: TriggerContext = null) -> Array[CombatEvent]:
	if context == null:
		context = TriggerContext.new()
	context.is_simulation = true
	AbilityResolver.process_trigger(trigger, context)
	return battle._combat.process_reaction_queue(battle, {})

func _test_purchase_and_placement() -> void:
	_reset()
	_check(battle.get_player_shelf_slots_unlocked() == 3, "Every battle starts with three Shelf slots")
	battle._current_battle_phase = BattleManager.Phases.MANAGEMENT
	var tokens_before: int = battle.get_gacha_tokens()
	var action: PurchaseShelfSlotAction = PurchaseShelfSlotAction.new()
	_check(action.validate(), "A management Shelf purchase is valid")
	action.execute()
	_check(battle.get_player_shelf_slots_unlocked() == 4, "Purchase unlocks exactly one slot synchronously")
	_check(battle.get_gacha_tokens() == tokens_before - 1, "Purchase spends exactly one Token")
	_check(ActionFactory.create_from_dict(action.to_dict()) is PurchaseShelfSlotAction, "Purchase survives action serialization")
	battle._current_battle_phase = BattleManager.Phases.START_OF_TURN
	var first: GachaBallInstance = _add(&"FFigMec", &"PlayerShelf")
	var second: GachaBallInstance = _add(&"FFigMec", &"PlayerShelf")
	_check(MergeManager.find_recipe(first, second, first.get_location(), second.get_location(), battle.get_all_instances()) == null, "Shelf capsules cannot merge with each other")
	_check(InventoryOperations.swap_instances(battle._state, first.get_location(), second.get_location()).success, "Sealed capsules can swap on Shelf")
	var lineup_unit: GachaBallInstance = _add(&"FFigMec", &"PlayerLineup")
	_check(not InventoryOperations.swap_instances(battle._state, first.get_location(), lineup_unit.get_location()).success, "A cross-row swap cannot send a deployed unit back to Shelf")
	_check(not ConfirmSwapAction.new(first.get_location(), lineup_unit.get_location()).validate(), "The action boundary rejects a swap that would return a deployed unit to Shelf")
	_check(battle._state.transfer_instance_to_container(lineup_unit, &"PlayerShelf") == -1, "Atomic transfer rejects Lineup to Shelf")
	var item: GachaBallInstance = _add(&"item_t1_a", &"PlayerShelf")
	_check(not InventoryOperations.equip_item(battle._state, item.ball_uuid, first.ball_uuid).success, "Equipment cannot target a Shelf resident")
	_check(InventoryOperations.equip_item(battle._state, item.ball_uuid, lineup_unit.ball_uuid).success, "A sealed item equips directly onto a Lineup unit")
	_check(not VisualDataAdapter.create_visual_data(item, battle.get_all_instances()).capsule_sealed, "Equipping opens the item capsule")
	var potion: GachaBallInstance = _add(&"item_potion_t1", &"PlayerShelf")
	var shelf_hp: int = first.current_hp
	InventoryManager._use_consumable(potion, first)
	_check(first.current_hp == shelf_hp and battle.get_instance_by_uuid(potion.ball_uuid) == potion, "Consumables cannot affect Shelf residents or be consumed by an invalid Shelf use")
	_check(battle.bm_merge_instances(first.get_location(), second.get_location()).is_empty(), "The authoritative merge API rejects Shelf targets")
	var merge_item: GachaBallInstance = _add(&"item_t1_a", &"PlayerShelf")
	GameManager.run_state.unlock_recipe_for_result(&"item_t2_a")
	var item_merge: Dictionary = battle.bm_merge_instances(merge_item.get_location(), item.get_location())
	_check(item_merge.get("success", false), "A sealed equipment capsule can merge directly into a Lineup equipped item")
	if item_merge.get("success", false):
		var merged_item: GachaBallInstance = item_merge.merged_instance
		_check(merged_item.equipped_on_uuid == lineup_unit.ball_uuid, "Merged equipment stays equipped on its Lineup holder")
		_check(battle._state.bm_remove_instance(lineup_unit.ball_uuid).success, "Removing an equipped deployed unit does not attempt a forbidden Shelf transfer")
		_check(merged_item.location_container_tag == &"DiscardPile", "Equipment whose holder leaves goes to Discard instead of Shelf")
	_check(battle._state.validate_state_consistency(), "Placement operations preserve container consistency")

func _test_entry_and_recycling() -> void:
	_reset()
	_add(&"trinket_tier1_insignia", &"PlayerTrinkets")
	_add(&"trinket_rusty_ring", &"PlayerTrinkets")
	var unit: GachaBallInstance = _add(&"FFigMec", &"BattleInventoryT1")
	var initial_hp: int = unit.current_hp
	var initial_pwr: int = unit.current_pwr
	var draw_events: Array[CombatEvent] = battle.bm_draw_gacha_instance(1)
	_check(not draw_events.is_empty(), "A machine draw produces its event sequence")
	_check(unit.location_container_tag == &"PlayerShelf", "Draw lands on Shelf")
	_check(VisualDataAdapter.create_visual_data(unit, battle.get_all_instances()).capsule_sealed, "A Shelf ball stays sealed")
	_check(unit.current_hp == initial_hp and unit.current_pwr == initial_pwr, "Insignia and Ring do not modify a sealed draw")
	_check(InventoryOperations.move_instance(battle._state, unit.get_location(), LocationIdentifier.new(&"PlayerLineup", 0)).success, "A sealed unit deploys to an empty Lineup slot")
	battle._process_lineup_entry(unit)
	battle._combat.process_reaction_queue(battle, {})
	_check(unit.current_hp == initial_hp + 2 and unit.current_pwr == initial_pwr + 2, "Deployment applies Insignia and Ring exactly once")
	_check(not VisualDataAdapter.create_visual_data(unit, battle.get_all_instances()).capsule_sealed, "Lineup deployment opens the capsule")
	_trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED)
	_check(unit.current_hp == initial_hp + 2 and unit.current_pwr == initial_pwr + 2, "Rearrangement/passive refresh does not repeat entry buffs")
	_check(InventoryOperations.move_instance_to_discard(battle._state, unit, false).success, "Deployed unit can enter Discard")
	_check(InventoryOperations.draw_from_discard(battle._state).success, "Discard recycling returns a ball to its machine")
	var recycled: InventoryOperations.DrawResult = InventoryOperations.draw_from_tier(battle._state, 1)
	_check(recycled.success and unit.location_container_tag == &"PlayerShelf", "Recycled ball can be drawn sealed onto Shelf")
	_check(unit.current_hp == initial_hp and unit.current_pwr == initial_pwr, "Recycling clears previous battle entry buffs")
	assert(battle._state.transfer_instance_to_container(unit, &"PlayerLineup", 0) == 0)
	battle._process_lineup_entry(unit)
	battle._combat.process_reaction_queue(battle, {})
	_check(unit.current_hp == initial_hp + 2 and unit.current_pwr == initial_pwr + 2, "A recycled capsule receives fresh entry buffs when redeployed")
	var merge_source: GachaBallInstance = _add(&"FFigMec", &"PlayerShelf")
	var merge_result: Dictionary = battle.bm_merge_instances(merge_source.get_location(), unit.get_location())
	_check(merge_result.get("success", false), "A sealed unit can merge directly into its eligible Lineup target")
	if merge_result.get("success", false):
		var merged_unit: GachaBallInstance = merge_result.merged_instance
		_check(merged_unit.location_container_tag == &"PlayerLineup" and merged_unit.level == 2, "A unit merge opens the source and leaves the result in Lineup")
		_check(not VisualDataAdapter.create_visual_data(merged_unit, battle.get_all_instances()).capsule_sealed, "A merge result does not regain a capsule")

func _test_sealed_stats_and_summons() -> void:
	_reset()
	var active: GachaBallInstance = _add(&"EFWASpeFod", &"PlayerLineup")
	var sealed: GachaBallInstance = _add(&"EFWASpeFod", &"PlayerShelf")
	_add(&"EFWASpeFod", &"BattleInventoryT3")
	_add(&"EFWASpeFod", &"DiscardPile")
	var active_pwr: int = active.current_pwr
	var sealed_pwr: int = sealed.current_pwr
	_trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED)
	_check(active.current_pwr == active_pwr + 9, "BubbleGunger still counts Shelf, machine and discarded copies")
	_check(sealed.current_pwr == sealed_pwr, "A sealed BubbleGunger does not recalculate PWR")
	var windup: GachaBallInstance = _add(&"FWAASpeToy", &"PlayerShelf")
	var hp_before: int = windup.current_hp
	var pwr_before: int = windup.current_pwr
	_trigger(C.TRIGGER_AT_TURN_START)
	_check(windup.current_hp == hp_before + 3 and windup.current_pwr == pwr_before + 3, "Wind-up-kun keeps its Shelf HP/PWR growth")
	var token_unit: GachaBallInstance = _add(&"FASpeApp", &"PlayerShelf")
	var token_pwr: int = token_unit.current_pwr
	_trigger(C.TRIGGER_ON_GACHA_TOKENS_CHANGED)
	_check(token_unit.current_pwr == token_pwr, "Sealed token-scaling units do not update PWR")
	var summon_payload: CombatPayload = EffectHandlers._make_summon_payload("", sealed.ball_uuid, sealed.get_location(), VisualDataAdapter.create_visual_data(sealed))
	_check(summon_payload.new_unit_snapshot.capsule_sealed, "Shelf summons carry a sealed presentation snapshot")

func _test_plunder_machine_exception() -> void:
	_reset()
	var target: GachaBallInstance = _add(&"FFigMec", &"EnemyLineup")
	var item: GachaBallInstance = GachaBallInstance.new()
	item.initialize(Database.get_definition(&"item_t2_a"))
	assert(InventoryOperations.register_and_equip_item(battle._state, item, target.ball_uuid).success)
	var potion: GachaBallInstance = _add(&"consumable_potion_plunder", &"PlayerShelf")
	var definition: GachaBallDefinition = potion.get_definition() as GachaBallDefinition
	var effect: EffectDefinition = definition.ability_definitions[0].effects[0]
	var context: TriggerContext = TriggerContext.new()
	context.is_simulation = true
	var result: EffectResult = effect.execute(potion.ball_uuid, [target.ball_uuid], battle, context)
	_check(result.state_applied, "Plunder strips an equipped Lineup item")
	_check(item.location_container_tag == &"BattleInventoryT2", "Plunder sends the item directly to its matching tier machine")
	_check(not target.equipped_item_uuids.has(item.ball_uuid), "Plunder removes the item's holder link")
	_check(battle.get_container(&"DiscardPile").get_all_non_empty_uuids().is_empty(), "Plunder bypasses Discard as an explicit exception")
	var machine_event: CombatEvent = result.events[0]
	_check(machine_event.type == CombatEvent.Type.SUMMON and machine_event.visual_payload.new_unit_snapshot.get("capsule_sealed", false), "The machine arrival event carries a sealed item snapshot")
	var draw: InventoryOperations.DrawResult = InventoryOperations.draw_from_tier(battle._state, 2)
	_check(draw.success and draw.drawn_uuid == item.ball_uuid and item.location_container_tag == &"PlayerShelf", "A plundered item can be drawn normally onto the Shelf")
	_check(VisualDataAdapter.create_visual_data(item, battle.get_all_instances()).capsule_sealed, "The plundered item's next Shelf draw remains sealed")
	var recipient: GachaBallInstance = _add(&"FFigMec", &"PlayerLineup")
	_check(InventoryOperations.equip_item(battle._state, item.ball_uuid, recipient.ball_uuid).success, "The redrawn item can open on a new Lineup holder")
	_check(battle._state.validate_state_consistency(), "Plunder, redraw and re-equipping preserve container consistency")

func _test_draw_tracking() -> void:
	_reset()
	var charm: GachaBallInstance = _add(&"trinket_trinity_charm", &"PlayerTrinkets")
	for tier: int in [1, 2, 3]:
		var context: TriggerContext = TriggerContext.new()
		context.tier = tier
		_trigger(C.TRIGGER_ON_GACHA_DRAW, context)
	_check(charm.get_status_effect_amount(&"trinity_rewarded_this_cycle") == 1, "True draw reactions remain active before deployment")
	_check(battle.get_gacha_tokens() == 21, "Trinity Charm still awards its Token after all three tiers are drawn")

func _test_purchase_presentation() -> void:
	battle.free()
	var view: PurchaseViewFixture = PurchaseViewFixture.new()
	for node_name: String in ["PlayerLineup", "PlayerShelf", "EnemyLineupContainer", "EnemyTrinketBar", "EndTurnButton"]:
		var child: Control = Button.new() if node_name == "EndTurnButton" else HBoxContainer.new()
		child.name = node_name
		view.add_child(child)
		child.owner = view
		child.unique_name_in_owner = true
	add_child(view)
	battle = BattleManager.new()
	view.add_child(battle)
	GameManager.register_battle_manager(battle)
	view.battle_manager = battle
	_reset()
	battle._current_battle_phase = BattleManager.Phases.MANAGEMENT
	var hud: TokenHudFixture = TokenHudFixture.new()
	add_child(hud)
	GameManager.register_main_node(hud)
	var group: Control = Control.new()
	group.name = "TokenGroup"
	hud.add_child(group)
	group.owner = hud
	group.unique_name_in_owner = true
	group.position = Vector2(80, 40)
	group.size = Vector2(100, 40)
	var icon: TextureRect = TextureRect.new()
	icon.name = "TokenIcon"
	icon.size = Vector2(32, 32)
	group.add_child(icon)
	var shelf: HBoxContainer = view.player_shelf
	for slot_index: int in range(8):
		var slot: SlotView = preload("res://scenes/SlotView.tscn").instantiate()
		shelf.add_child(slot)
		slot.custom_minimum_size = Vector2(188, 188)
		slot.populate(LocationIdentifier.new(&"PlayerShelf", slot_index))
	view._update_shelf_slot_states()
	var next_slot: SlotView = shelf.get_child(3) as SlotView
	_check(next_slot._shelf_lock_overlay is Control and not next_slot._shelf_lock_overlay is ColorRect, "Locked slots do not draw an opaque rectangular overlay")
	_check(next_slot._background_style.modulate_color.a == 1.0 and next_slot._background_style.modulate_color.r < 1.0, "Darkening changes sprite RGB and preserves asset alpha")
	next_slot._on_shelf_lock_overlay_mouse_entered()
	_check(next_slot._shelf_hover_outline.visible, "The next purchasable slot displays a white silhouette outline on hover")
	next_slot._on_shelf_lock_overlay_mouse_exited()
	var resident: GachaBallInstance = _add(&"FFigMec", &"PlayerShelf")
	var capsule_view: GachaBallView = (shelf.get_child(0) as SlotView).set_content(VisualDataAdapter.create_visual_data(resident), false)
	_check(capsule_view.has_node("GachaBallOverlay"), "Shelf presentation retains the capsule asset")
	await _test_capsule_geometry(capsule_view)
	ActionQueue.set_headless_mode(false)
	_check(ActionQueue.request(PurchaseShelfSlotAction.new()), "The visual purchase action starts")
	_check(battle.get_player_shelf_slots_unlocked() == 4 and next_slot._shelf_slot_locked, "Authoritative unlock is synchronous while presentation stays dark during token flight")
	_check(ActionQueue.is_busy(), "Interaction stays locked during purchase presentation")
	await ActionQueue.queue_idle
	_check(not next_slot._shelf_slot_locked and next_slot.scale == Vector2.ONE, "Token arrival reveals the slot and the pop returns to its canonical scale")
	_check(hud.visual_tokens == 19 and hud.flights == 0, "Token flight decrements the HUD exactly once and balances its animation guards")
	ActionQueue.set_headless_mode(true)
	await _test_draw_presentation(view, hud)
	GameManager.unregister_main_node()

func _test_capsule_geometry(shelf_ball: GachaBallView) -> void:
	var machine_ball: PhysicsGachaBall = load("res://scenes/PhysicsGachaBall.tscn").instantiate()
	machine_ball.freeze = true
	add_child(machine_ball)
	await get_tree().process_frame
	var shell: Sprite2D = shelf_ball.get_node("GachaBallOverlay") as Sprite2D
	var machine_size: Vector2 = machine_ball.capsule_sprite.texture.get_size() * machine_ball.capsule_sprite.scale
	_check((shell.texture.get_size() * shell.scale).is_equal_approx(machine_size), "Shelf capsules match the physical machine capsule diameter")
	_check(is_equal_approx(shell.position.y + machine_size.y * 0.5, 133.0), "The capsule bottom rests on the Shelf surface instead of crossing through it")
	var content: TextureRect = shelf_ball.icon_rect.get_node("UnitSprite") as TextureRect
	_check(content.get_global_rect().get_center().is_equal_approx(shelf_ball.get_global_transform() * shell.position), "The unit is centered inside its Shelf capsule")
	_check(shelf_ball.size.is_equal_approx(Vector2(188, 188)), "The sealed capsule does not stretch the 188px Shelf slot")
	var preview: Control = shelf_ball._build_drag_preview_visual()
	var preview_shell: TextureRect = preview.get_child(0) as TextureRect
	_check(preview_shell.size.is_equal_approx(machine_size), "Dragging a sealed capsule preserves the machine capsule size")
	preview.free()
	machine_ball.free()
	var trinket: GachaBallInstance = _add(&"trinket_rusty_ring", &"PlayerTrinkets")
	var trinket_slot: SlotView = load("res://scenes/SlotView.tscn").instantiate()
	trinket_slot.set_size_scale(1.0)
	trinket_slot.custom_minimum_size = Vector2(98, 98)
	add_child(trinket_slot)
	trinket_slot.populate(LocationIdentifier.new(&"PlayerTrinkets", 0))
	var trinket_view: GachaBallView = trinket_slot.set_content(VisualDataAdapter.create_visual_data(trinket), false)
	await get_tree().process_frame
	_check(trinket_view.icon_rect.texture == trinket.get_definition().icon and not trinket_view.icon_rect.has_node("UnitSprite"), "Trinkets fit their HUD cell instead of inheriting authored item sizing")
	_check(trinket_view.icon_rect.size.x >= 96.0 and trinket_view.icon_rect.size.y >= 96.0, "Trinkets retain their full HUD display footprint")
	trinket_slot.free()

func _test_draw_presentation(view: BattleView, hud: TokenHudFixture) -> void:
	var machine: Control = Control.new()
	machine.name = "GachaMachine1"
	hud.add_child(machine)
	machine.owner = hud
	machine.unique_name_in_owner = true
	machine.position = Vector2(80, 800)
	machine.size = Vector2(240, 160)
	var knob: Control = Control.new()
	knob.name = "KnobButton"
	machine.add_child(knob)
	knob.size = Vector2(40, 40)
	var tutorial_state: Dictionary = TutorialManager.get_state_snapshot()
	TutorialManager.set_temporary_replay_state({"tutorials_enabled": false, "completed_tutorials": ["first_draw"]})
	var drawn: GachaBallInstance = _add(&"FFigMec", &"BattleInventoryT1")
	var result: InventoryOperations.DrawResult = InventoryOperations.draw_from_tier(battle._state, 1)
	_check(result.success, "The visual draw has an authoritative Shelf destination")
	view._on_gacha_draw_animated(result, VisualDataAdapter.create_visual_data(drawn, battle.get_all_instances()))
	var flying_ball: GachaBallView = null
	for child: Node in WindowManager.get_vfx_layer().get_children():
		if child is GachaBallView and child.get_instance_uuid() == drawn.ball_uuid:
			flying_ball = child as GachaBallView
	_check(flying_ball != null and flying_ball.force_inventory_mode and flying_ball.has_node("GachaBallOverlay"), "The draw instantiates a sealed flight capsule after autoload initialization")
	var flight_capsule_size: Vector2 = flying_ball.get_capsule_rect().size
	_check(flight_capsule_size == Vector2(96, 96), "The flight uses the same 96px capsule as the machines")
	var completed_result: InventoryOperations.DrawResult = await SignalBus.gacha_draw_animation_completed
	_check(completed_result == result, "The actual draw flight and landing finish for the same draw")
	var destination: SlotView = view.player_shelf.get_child(result.dest_slot) as SlotView
	var landed_ball: GachaBallView = null
	for child: Node in destination.get_children():
		if child is GachaBallView and child.get_instance_uuid() == drawn.ball_uuid:
			landed_ball = child as GachaBallView
	_check(landed_ball != null and landed_ball.has_node("GachaBallOverlay"), "The drawn unit lands in its Shelf slot with its capsule intact")
	_check(flight_capsule_size == landed_ball.get_capsule_rect().size, "Flight and Shelf presentation use identical capsule sizes")
	_check(not view._pending_animated_uuids.has(drawn.ball_uuid), "The completed draw clears its pending presentation state")
	_check(hud.machine_changes == [Vector2i(1, -1)], "The draw updates its machine counter exactly once")
	var discard: Button = Button.new()
	discard.name = "GachaMachineDiscard"
	hud.add_child(discard)
	discard.owner = hud
	discard.unique_name_in_owner = true
	discard.position = Vector2(1500, 800)
	discard.size = Vector2(200, 160)
	var discard_knob: Control = Control.new()
	discard_knob.name = "KnobButton"
	discard.add_child(discard_knob)
	discard_knob.size = Vector2(40, 40)
	_check(InventoryOperations.move_instance_to_discard(battle._state, drawn).success, "The return-flight fixture places its capsule in Discard")
	var returned: InventoryOperations.DrawResult = InventoryOperations.draw_from_discard(battle._state)
	view._on_gacha_draw_animated(returned, VisualDataAdapter.create_visual_data(drawn, battle.get_all_instances()))
	var return_flight: GachaBallView = null
	for child: Node in WindowManager.get_vfx_layer().get_children():
		if child is GachaBallView and child.get_instance_uuid() == drawn.ball_uuid and not child.is_queued_for_deletion():
			return_flight = child as GachaBallView
	completed_result = await SignalBus.gacha_draw_animation_completed
	_check(completed_result == returned and (return_flight.get_capsule_rect().size * return_flight.scale).is_equal_approx(flight_capsule_size), "Recycling reaches the machine at the same native capsule size")
	_check((return_flight.get_global_transform() * return_flight.get_capsule_rect().get_center()).is_equal_approx(knob.get_global_rect().get_center()), "The return capsule's center reaches the machine knob without a size offset")
	await return_flight.tree_exited
	TutorialManager.restore_state_snapshot(tutorial_state)

func _run() -> void:
	RNGManager.initialize(73410)
	ActionQueue.set_headless_mode(true)
	GameManager.is_in_battle = true
	battle = BattleManager.new()
	add_child(battle)
	GameManager.register_battle_manager(battle)
	_test_purchase_and_placement()
	_test_entry_and_recycling()
	_test_sealed_stats_and_summons()
	_test_plunder_machine_exception()
	_test_draw_tracking()
	await _test_purchase_presentation()
	print("Shelf capsule suite: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
