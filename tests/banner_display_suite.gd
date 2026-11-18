extends Node

const C = preload("res://scripts/Constants.gd")

class BannerBattleFixture extends BattleView:
	func _ready() -> void:
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
		_check(slot._background_style.modulate_color == expected_light and slot._slot_effect_overlay.self_modulate == expected_light, "Slot effects must retain team lighting")
		_check(slot.modulate == Color.WHITE, "Platform lighting must not recolor unit sprites")
		slot.set_slot_effect(&"")
	var payload: Dictionary = WindowManager._derive_window_payload(view._location, view)
	_check(payload["window_type"] == &"ItemInspection" and payload["context"]["instance"] == _banner(), "Hover inspection must resolve the banner at its dedicated location")
	view._inspection_trigger.on_mouse_entered()
	_check(GlobalInteractionRouter.get_peek_controller()._state == InspectionPeekController.State.ARMED, "Banner hover did not arm the shared inspection controller")
	view._inspection_trigger.cancel()
	BattleAnimator._register_all_puppets(VisualDataAdapter.create_board_snapshot(battle.get_all_instances()))
	BattleAnimator.play_trinket_activation(_banner().ball_uuid, _banner().definition_id, true)
	_check(not BattleAnimator.get_live_position(_banner().ball_uuid).is_empty(), "Banner activation must retain its VCR projectile source position")
	_check(BattleAnimator._visual_registry[_banner().ball_uuid] == view, "VCR must register the banner rather than a trinket bar slot")
	BattleAnimator._visual_registry.clear()
	BattleAnimator._position_snapshot.clear()

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
	RNGManager.initialize(42)
	GameManager.run_state = RunState.new()
	GameManager.is_in_battle = true
	fixture = (load("res://scenes/Battle.tscn") as PackedScene).instantiate() as BattleView
	fixture.set_script(BannerBattleFixture)
	add_child(fixture)
	battle = fixture.get_node("BattleManager") as BattleManager
	await get_tree().process_frame
	_test_all_banners()
	_test_capacity_and_legacy()
	_test_reinforcement_trigger()
	_test_presentation_and_inspection()
	if OS.get_cmdline_user_args().has("--write-preview"):
		await RenderingServer.frame_post_draw
		var result: Error = get_viewport().get_texture().get_image().save_png("res://scratch/nobori_battle_preview.png")
		_check(result == OK, "Could not render banner integration preview")
	WindowManager.close_all_inspection_windows()
	GameManager.unregister_battle_manager()
	GameManager.is_in_battle = false
	fixture.free()
	print("BANNER DISPLAY SUITE: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
