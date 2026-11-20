extends Node

const C = preload("res://scripts/Constants.gd")

class BannerBattleFixture extends BattleView:
	func _ready() -> void:
		set_process(false)
		add_to_group("battle_view")
		battle_manager = get_node("BattleManager") as BattleManager
		_initialize_slots(player_lineup, &"PlayerLineup")
		_initialize_slots(player_shelf, &"PlayerShelf")
		_initialize_slots(enemy_lineup, &"EnemyLineup")
		_initialize_slots(enemy_trinket_bar, &"EnemyTrinkets")

var failures: int = 0
var checks: int = 0
var fixture: BattleView
var battle: BattleManager

func _ready() -> void:
	if SignalBus.main_scene_requested.is_connected(SceneManager._on_main_scene_requested):
		SignalBus.main_scene_requested.disconnect(SceneManager._on_main_scene_requested)
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _has_focus_outline(sprite: CanvasItem) -> bool:
	var outline: Node2D = sprite.get_node_or_null("FocusOutline") as Node2D
	return outline != null and outline.is_visible_in_tree()

func _reset() -> void:
	battle._state = BattleState.new()
	battle._combat = CombatSimulator.new()
	battle._current_battle_phase = BattleManager.Phases.MANAGEMENT

func _banner() -> GachaBallInstance:
	return battle.get_instance_by_location(LocationIdentifier.new(C.BATTLE_CONTAINER_TAGS.ENEMY_BANNER, 0))

func _test_all_banners() -> void:
	var ids: Array[StringName] = []
	for definition: TrinketDefinition in Database.trinkets.values():
		if definition.is_banner:
			ids.append(definition.id)
	_check(ids.size() == 21, "Every existing banner needs a dedicated battlefield asset")
	for id: StringName in ids:
		_reset()
		RNGManager.initialize(42)
		var encounter: EncounterDefinition = BannerDraftingRegistry.get_drafter(id).draft_lineup(16, {"daily_budget": 16})
		_check(not encounter.enemy_trinket_ids.has(id), "Drafted banner still occupies a trinket slot: %s" % id)
		BattleSetup.setup_enemy_trinkets(battle._state, encounter)
		var banner: GachaBallInstance = _banner()
		_check(banner != null and banner.definition_id == id, "Dedicated banner missing after setup: %s" % id)
		_check(battle.enemy_trinkets.size() == encounter.enemy_trinket_ids.size(), "Banner leaked into trinket bar cache")
		_check(AbilityResolver._get_instance_team(banner, battle) == "ENEMY", "Banner lost enemy team affiliation")
		fixture._populate_enemy_banner()
		_check(fixture.enemy_banner_view.visible and fixture.enemy_banner_view.get_instance_uuid() == banner.ball_uuid, "Banner presentation does not match the selected encounter")
		_check(battle._state.validate_state_consistency(), "Banner setup broke container consistency")

func _test_capacity_and_legacy() -> void:
	_reset()
	var encounter: EncounterDefinition = EncounterDefinition.new()
	encounter.banner_trinket_id = &"trinket_banner_fire_phalanx"
	for definition: TrinketDefinition in Database.trinkets.values():
		if not definition.is_banner and not definition.is_player_exclusive and encounter.enemy_trinket_ids.size() < C.ENEMY_TRINKET_CAP:
			encounter.enemy_trinket_ids.append(definition.id)
	BattleSetup.setup_enemy_trinkets(battle._state, encounter)
	_check(battle.enemy_trinkets.size() == C.ENEMY_TRINKET_CAP and _banner() != null, "A banner must coexist with all nine enemy trinkets")
	var first_instance: GachaBallInstance = battle.get_all_instances().values()[0]
	_check(first_instance == _banner(), "Banner must preserve its original ability ordering before enemy trinkets")
	_reset()
	encounter.enemy_trinket_ids.push_front(encounter.banner_trinket_id)
	BattleSetup.setup_enemy_trinkets(battle._state, encounter)
	_check(battle.enemy_trinkets.size() == C.ENEMY_TRINKET_CAP and battle.get_all_instances().size() == C.ENEMY_TRINKET_CAP + 1, "Legacy encounter banners must migrate without duplication or lost trinkets")

func _add_unit(id: StringName, container: StringName, slot: int) -> GachaBallInstance:
	var unit: GachaBallInstance = GachaBallInstance.new()
	unit.initialize(Database.get_definition(id) as GachaBallDefinition)
	assert(battle.bm_add_instance(unit, container, slot))
	return unit

func _test_presentation_and_inspection() -> void:
	_reset()
	var encounter: EncounterDefinition = EncounterDefinition.new()
	encounter.banner_trinket_id = &"trinket_banner_fire_phalanx"
	encounter.enemy_trinket_ids = [&"trinket_trait_fire"]
	BattleSetup.setup_enemy_trinkets(battle._state, encounter)
	var units: Array[StringName] = [&"ETnkPla", &"FFigMec", &"WSupAni", &"FFigMec", &"ETnkPla"]
	for slot: int in range(5):
		_add_unit(units[slot], &"PlayerLineup", slot)
		_add_unit(units[slot], &"EnemyLineup", slot)
	fixture._populate_container(fixture.player_lineup, &"PlayerLineup", false)
	fixture._populate_container(fixture.enemy_lineup, &"EnemyLineup", true)
	fixture._populate_enemy_trinkets()
	fixture._populate_enemy_banner()
	var view: EnemyBannerView = fixture.enemy_banner_view
	var pole_position: Vector2 = view.global_position + Vector2(EnemyBannerView.POLE_X, view.size.y)
	_check(is_equal_approx(pole_position.x, fixture.player_lineup.get_global_rect().end.x) and is_equal_approx(pole_position.x, fixture.enemy_lineup.global_position.x), "Banner pole must stand exactly between the two teams")
	_check(is_equal_approx(pole_position.y, fixture.enemy_lineup.get_global_rect().end.y), "Banner pole must share the lineup baseline")
	var background: CanvasItem = fixture.get_node("Background") as CanvasItem
	_check(background.z_index < view.z_index and view.z_index < (fixture.enemy_lineup.get_child(0) as CanvasItem).z_index, "Banner must render above background and behind platforms and units")
	for container: HBoxContainer in [fixture.player_lineup, fixture.enemy_lineup]:
		var slot: SlotView = container.get_child(0) as SlotView
		var expected_light: Color = SlotView.PLAYER_LINEUP_LIGHT if container == fixture.player_lineup else SlotView.ENEMY_LINEUP_SHADE
		slot.set_slot_effect(&"death")
		_check(slot._background_style.modulate_color == expected_light, "Slot effects must retain team lighting")
		_check(slot.modulate == Color.WHITE, "Platform lighting must not recolor unit sprites")
		slot.set_slot_effect(&"")
	await get_tree().process_frame
	_move_pointer(view.global_position + Vector2(44, 88))
	await get_tree().create_timer(InputUtils.HOVER_PEEK_DELAY_SEC + 0.1).timeout
	var windows: Array[Control] = WindowManager._active_inspection_group
	var inspection: ItemInspectionWindow = windows[0] as ItemInspectionWindow if not windows.is_empty() else null
	_check(inspection != null and inspection._instance == _banner(), "Hovering the banner cloth over the enemy lineup must open the banner inspection")
	_check(_has_focus_outline(view._texture_rect), "An inspected banner must have a white outline")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var pixels: Image = view.get_viewport().get_texture().get_image()
		var point := Vector2i(view.get_global_transform_with_canvas() * Vector2(-1, 32))
		var edge: Color = pixels.get_pixelv(point)
		_check(minf(edge.r, minf(edge.g, edge.b)) > 0.95, "The white outline must render beyond the left edge of the banner texture")
	_move_pointer(view.global_position + Vector2(94, 146))
	await get_tree().create_timer(InputUtils.HOVER_PEEK_DELAY_SEC + 0.1).timeout
	var unit_inspection: UnitInspectionWindow = windows[0] as UnitInspectionWindow if not windows.is_empty() else null
	_check(unit_inspection != null, "Hovering the front enemy's sprite where it covers the banner must open the unit inspection")
	var unit_view: GachaBallView = WindowManager.find_entity_view_for_location(LocationIdentifier.new(&"EnemyLineup", 0)) as GachaBallView
	var unit_art: TextureRect = unit_view._get_active_visual_sprite()
	_check(_has_focus_outline(unit_art) and not _has_focus_outline(view._texture_rect), "Switching inspection must move the outline to the new source")
	GlobalInteractionRouter.get_peek_controller().cancel()
	_check(not _has_focus_outline(unit_art), "Closing inspection must clear its outline")
	_move_pointer(view.global_position + Vector2(108, 175))
	await get_tree().process_frame
	var hovered: Control = view.get_viewport().gui_get_hovered_control()
	var front_slot: SlotView = fixture.enemy_lineup.get_child(0) as SlotView
	_check(hovered != null and (hovered == front_slot or front_slot.is_ancestor_of(hovered)), "Transparent banner padding must still allow interaction with the enemy lineup")
	GlobalInteractionRouter.get_peek_controller().cancel()
	BattleAnimator._register_all_puppets(VisualDataAdapter.create_board_snapshot(battle.get_all_instances()))
	BattleAnimator.play_trinket_activation(_banner().ball_uuid, _banner().definition_id, true)
	_check(not BattleAnimator.get_live_position(_banner().ball_uuid).is_empty(), "Banner activation must retain its VCR projectile source position")
	_check(BattleAnimator._visual_registry[_banner().ball_uuid] == view, "VCR must register the banner rather than a trinket bar slot")
	BattleAnimator._visual_registry.clear()
	BattleAnimator._position_snapshot.clear()

	var trinket_loc := LocationIdentifier.new(&"EnemyTrinkets", 0)
	var trinket_view: GachaBallView = WindowManager.find_entity_view_for_location(trinket_loc) as GachaBallView
	WindowManager.open_inspection_window(trinket_loc, trinket_view)
	_check(_has_focus_outline(trinket_view.icon_rect), "An inspected trinket must have a white outline")
	WindowManager.close_all_inspection_windows()
	_check(not _has_focus_outline(trinket_view.icon_rect), "Closing the trinket inspection must clear its outline")

func _test_item_selection_and_inspection() -> void:
	var item: GachaBallInstance = GachaBallInstance.new()
	var definition: GachaBallDefinition = Database.get_definition(&"item_t1_a") as GachaBallDefinition
	item.initialize(definition)
	assert(battle.bm_add_instance(item, &"PlayerShelf", 0))
	fixture._populate_container(fixture.player_shelf, &"PlayerShelf", false)
	var loc: LocationIdentifier = item.get_location()
	var item_view: GachaBallView = WindowManager.find_entity_view_for_location(loc) as GachaBallView
	assert(item_view != null, "The Shelf fixture must render the test item")
	var artwork: TextureRect = item_view._get_active_visual_sprite()
	SelectEntityAction.new(loc, item.ball_uuid, item_view.get_instance_id()).execute()
	_check(_has_focus_outline(artwork), "A selected item must outline its artwork")
	WindowManager.open_inspection_window(loc, item_view)
	WindowManager.close_all_inspection_windows()
	_check(_has_focus_outline(artwork), "Closing inspection must preserve the selection outline")
	WindowManager.open_inspection_window(loc, item_view)
	GlobalInteractionRouter.apply_deselect_entity()
	_check(_has_focus_outline(artwork), "Deselecting must preserve an open inspection's outline")
	WindowManager.close_all_inspection_windows()
	_check(not _has_focus_outline(artwork), "The item outline must clear once both states end")

	var unit_loc := LocationIdentifier.new(&"PlayerLineup", 0)
	var unit_view: GachaBallView = WindowManager.find_entity_view_for_location(unit_loc) as GachaBallView
	SelectEntityAction.new(unit_loc).execute()
	_check(_has_focus_outline(unit_view._get_active_visual_sprite()), "Selection by location must outline the unit artwork instead of its slot")
	GlobalInteractionRouter.apply_deselect_entity()

	var tray_item: GachaBallInstance = GachaBallInstance.new()
	tray_item.initialize(definition)
	assert(battle.bm_add_instance(tray_item, &"BattleInventoryT1", 0))
	var capsule: PhysicsGachaBall = preload("res://scenes/PhysicsGachaBall.tscn").instantiate()
	capsule.freeze = true
	capsule.position = Vector2(400, 640)
	var tray_loc: LocationIdentifier = tray_item.get_location()
	capsule.populate(tray_item.ball_uuid, definition.category, tray_loc, definition.icon)
	fixture.add_child(capsule)
	SelectEntityAction.new(tray_loc).execute()
	_check(_has_focus_outline(capsule.icon_sprite), "Selecting a capsule in an inventory tray must outline its item")
	GlobalInteractionRouter.apply_deselect_entity()
	WindowManager.open_inspection_window(tray_loc, capsule.ui_anchor)
	_check(_has_focus_outline(capsule.icon_sprite), "Inspecting a capsule in an inventory tray must outline its item")
	WindowManager.close_all_inspection_windows()
	_check(not _has_focus_outline(capsule.icon_sprite), "The inventory tray outline must clear when the inspection closes")

func _test_combat_banner_inspection() -> void:
	var banner: EnemyBannerView = fixture.enemy_banner_view
	var cloth: Vector2 = banner.global_position + Vector2(44, 88)
	var front_unit: Vector2 = banner.global_position + Vector2(94, 146)
	SignalBus.battle_phase_changed.emit(&"COMBAT")
	_pointer_button(cloth, true)
	_check(get_tree().paused and _has_focus_outline(banner._texture_rect), "Pressing on banner cloth during combat must pin the banner inspection and pause playback")
	_pointer_button(cloth, false)

	_pointer_button(front_unit, true)
	_check(get_tree().paused and WindowManager.get_top_contextual_window() is UnitInspectionWindow, "Clicking the unit in front of a pinned banner must switch inspection to the unit")
	_pointer_button(front_unit, false)

	_pointer_button(cloth, true)
	_check(get_tree().paused and _has_focus_outline(banner._texture_rect), "Clicking exposed cloth while a unit is pinned must switch inspection to the banner")
	_pointer_button(cloth, false)

	_pointer_button(cloth, true)
	_check(not get_tree().paused and not _has_focus_outline(banner._texture_rect), "Clicking the pinned banner again must clear its outline and resume playback")
	_pointer_button(cloth, false)
	SignalBus.battle_phase_changed.emit(&"MANAGEMENT")

	battle._is_animating_management_queue = true
	_pointer_button(cloth, true)
	_check(get_tree().paused and _has_focus_outline(banner._texture_rect), "A click must also pin banner inspection during animation playback outside the combat phase")
	_pointer_button(cloth, false)
	_pointer_button(Vector2(900, 570), true)
	_check(not get_tree().paused and not _has_focus_outline(banner._texture_rect), "Clicking away from a pinned banner must resume playback")
	_pointer_button(Vector2(900, 570), false)
	battle._is_animating_management_queue = false

	ActionQueue.set_replay_mode(true)
	var recorded_inspection := InspectEntityAction.new(_banner().get_location())
	ActionQueue.request(recorded_inspection, ActionQueue.RequestSource.REPLAY)
	_check(get_tree().paused and _has_focus_outline(banner._texture_rect), "A replayed inspection must locate the banner using its battlefield location")
	ActionQueue.request(CloseInspectionAction.new(), ActionQueue.RequestSource.REPLAY)
	ActionQueue.set_replay_mode(false)

func _pointer_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	get_tree().root.push_input(event, true)

func _move_pointer(position: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)

func _test_reinforcement_trigger() -> void:
	_reset()
	var encounter: EncounterDefinition = EncounterDefinition.new()
	encounter.banner_trinket_id = &"trinket_banner_fire_phalanx"
	encounter.enemy_trinket_ids = [&"trinket_trait_fire"]
	BattleSetup.setup_enemy_trinkets(battle._state, encounter)
	_add_unit(&"EFTnkMec", &"EnemyLineup", 0)
	var context: TriggerContext = TriggerContext.new()
	context.is_simulation = true
	context.turn = 1
	context.current_day = 6
	AbilityResolver.process_trigger(C.TRIGGER_AT_TURN_END, context)
	var events: Array[CombatEvent] = battle._combat.process_reaction_queue(battle, {})
	var summons: int = 0
	var enemy_activation: bool = false
	for event: CombatEvent in events:
		if event.type == CombatEvent.Type.SUMMON:
			summons += 1
		for activation: CombatTrinketActivation in event.trinket_activations:
			if activation.visual_uuid == _banner().ball_uuid:
				enemy_activation = activation.is_enemy
	_check(summons > 0 and enemy_activation, "Dedicated banner must still reinforce and emit enemy activation events through the normal trigger pipeline")
	_check(battle._state.validate_state_consistency(), "Banner reinforcements broke state consistency")

func _run() -> void:
	get_tree().root.size = Vector2i(1920, 1080)
	get_tree().get_first_node_in_group("audio_manager").remove_from_group("audio_manager")
	RNGManager.initialize(42)
	GameManager.run_state = RunState.new()
	GameManager.is_in_battle = true
	# Mount the real HUD and battle viewport without starting path generation and autosave.
	var main: Control = preload("res://scenes/Main.tscn").instantiate()
	main.set_script(null)
	add_child(main)
	fixture = (load("res://scenes/Battle.tscn") as PackedScene).instantiate() as BattleView
	fixture.set_script(BannerBattleFixture)
	main.get_node("%SceneSlot").add_child(fixture)
	battle = fixture.get_node("BattleManager") as BattleManager
	await get_tree().process_frame
	_test_all_banners()
	_test_capacity_and_legacy()
	_test_reinforcement_trigger()
	await _test_presentation_and_inspection()
	_test_item_selection_and_inspection()
	await get_tree().process_frame
	_test_combat_banner_inspection()
	if OS.get_cmdline_user_args().has("--write-preview"):
		await RenderingServer.frame_post_draw
		var result: Error = get_viewport().get_texture().get_image().save_png("res://scratch/nobori_battle_preview.png")
		_check(result == OK, "Could not render banner integration preview")
	WindowManager.close_all_inspection_windows()
	GameManager.unregister_battle_manager()
	GameManager.is_in_battle = false
	main.queue_free()
	await get_tree().process_frame
	print("BANNER DISPLAY SUITE: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
