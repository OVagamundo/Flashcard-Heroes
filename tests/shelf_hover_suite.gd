extends Node

# Exercise real DRAW playback and native GUI mouse events. A pointer that
# arrives during playback must be reconciled when the interaction lock ends.
enum PointerArrival { BEFORE_LANDING, AT_LANDING, AFTER_UNLOCK }

class BoardFixture extends BattleView:
	func _ready() -> void:
		pass

class HudFixture extends Control:
	func animate_machine_inventory_change(_tier: int, _delta: int) -> void:
		pass

var board: BoardFixture
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

func _move_pointer(position: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)

func _add_unit(container: StringName) -> GachaBallInstance:
	var unit: GachaBallInstance = GachaBallInstance.new()
	unit.initialize(Database.get_definition(&"FFigMec"))
	assert(battle._state.bm_add_instance(unit, container))
	return unit

func _ball(slot_index: int) -> GachaBallView:
	for node: Node in board.player_shelf.get_child(slot_index).get_children():
		if node is GachaBallView and not node.is_queued_for_deletion():
			return node as GachaBallView
	return null

func _run() -> void:
	get_tree().root.size = Vector2i(1920, 1080)
	RNGManager.initialize(73410)
	ActionQueue.set_headless_mode(true)
	GameManager.run_state = RunState.new()
	GameManager.run_state.current_room_tokens = 20
	GameManager.is_in_battle = true
	TutorialManager.set_temporary_replay_state({"tutorials_enabled": false, "completed_tutorials": ["first_draw"]})
	board = BoardFixture.new()
	board.name = "HoverBoard"
	board.size = Vector2(1920, 1080)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for row_index: int in range(4):
		var row: HBoxContainer = HBoxContainer.new()
		row.name = ["PlayerLineup", "PlayerShelf", "EnemyLineupContainer", "EnemyTrinketBar"][row_index]
		row.position = Vector2(40, 150 + row_index * 220)
		board.add_child(row)
		row.owner = board
		row.unique_name_in_owner = true
	var ready_button: Button = Button.new()
	ready_button.name = "EndTurnButton"
	board.add_child(ready_button)
	ready_button.owner = board
	ready_button.unique_name_in_owner = true
	var banner: EnemyBannerView = EnemyBannerView.new()
	banner.name = "EnemyBanner"
	board.add_child(banner)
	banner.owner = board
	banner.unique_name_in_owner = true
	add_child(board)
	board.add_to_group("battle_view")
	battle = BattleManager.new()
	board.add_child(battle)
	board.battle_manager = battle
	battle._state = BattleState.new()
	battle._state.player_shelf_slots_unlocked = 5
	battle._combat = CombatSimulator.new()
	battle._current_battle_phase = BattleManager.Phases.MANAGEMENT
	for row: HBoxContainer in [board.player_lineup, board.player_shelf, board.enemy_lineup]:
		var tag: StringName = &"EnemyLineup" if row == board.enemy_lineup else StringName(row.name)
		for index: int in range(5):
			var slot: SlotView = preload("res://scenes/SlotView.tscn").instantiate()
			row.add_child(slot)
			slot.custom_minimum_size = Vector2(188, 188)
			slot.populate(LocationIdentifier.new(tag, index))
	_add_unit(&"PlayerLineup")
	_add_unit(&"EnemyLineup")
	board._resolve_battle_animator()
	battle.management_animation_queue_completed.connect(board._on_turn_animation_finished_redraw)
	SignalBus.battle_inventory_changed.connect(board._redraw_board)
	SignalBus.gacha_draw_animated.connect(board._on_gacha_draw_animated)
	var hud: HudFixture = HudFixture.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	GameManager.register_main_node(hud)
	var machine: Control = Control.new()
	machine.name = "GachaMachine1"
	machine.position = Vector2(80, 800)
	machine.size = Vector2(240, 160)
	hud.add_child(machine)
	machine.owner = hud
	machine.unique_name_in_owner = true
	var knob: Control = Control.new()
	knob.name = "KnobButton"
	knob.size = Vector2(40, 40)
	machine.add_child(knob)
	board._redraw_board()
	WindowManager.get_vfx_layer()
	await get_tree().process_frame
	await _draw_case(PointerArrival.BEFORE_LANDING, false)
	await _draw_case(PointerArrival.AT_LANDING, false)
	await _draw_case(PointerArrival.AFTER_UNLOCK, false)
	await _draw_case(PointerArrival.BEFORE_LANDING, true)
	await _draw_case(PointerArrival.BEFORE_LANDING, false, true)
	print("Shelf hover suite: %d checks, %d failures" % [checks, failures])
	GlobalInteractionRouter.get_peek_controller().cancel()
	GameManager.unregister_main_node()
	GameManager.unregister_battle_manager()
	board.queue_free()
	hud.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures > 0 else 0)

func _draw_case(arrival: PointerArrival, leave_before_finish: bool, redraw_during_playback: bool = false) -> void:
	WindowManager.close_all_inspection_windows(true)
	GlobalInteractionRouter.get_peek_controller().cancel()
	var unit: GachaBallInstance = _add_unit(&"BattleInventoryT1")
	var destination_index: int = battle._state.find_first_empty_player_shelf_slot()
	var slot: SlotView = board.player_shelf.get_child(destination_index) as SlotView
	var target: Vector2 = slot.get_global_transform() * GachaBallView.shelf_capsule_center(slot.size)
	_move_pointer(Vector2(100, 820))
	battle._on_draw_gacha_requested(1)
	if redraw_during_playback:
		board._redraw_board()
		_check(board._pending_board_redraw, "An inventory refresh defers replacement views until playback ends")
	if arrival == PointerArrival.BEFORE_LANDING:
		_move_pointer(target)
	elif arrival == PointerArrival.AT_LANDING:
		await SignalBus.gacha_draw_animation_completed
		_check(GlobalInteractionRouter.is_vcr_playing(), "Entry at visual completion still occurs under the playback lock")
		_move_pointer(target)
	if leave_before_finish:
		await get_tree().create_timer(0.2).timeout
		_move_pointer(Vector2(1850, 1000))
	await battle.management_animation_queue_completed
	await get_tree().process_frame
	_check(not GlobalInteractionRouter.is_vcr_playing(), "The test reaches the unlocked playback state")
	var landed: GachaBallView = _ball(destination_index)
	_check(landed != null and landed.get_instance_uuid() == unit.ball_uuid, "The real draw sequence leaves the drawn capsule on Shelf")
	if arrival == PointerArrival.AFTER_UNLOCK:
		_move_pointer(target)
	await get_tree().create_timer(0.7).timeout
	var expected_hover: bool = not leave_before_finish
	_check(get_viewport().get_mouse_position().is_equal_approx(Vector2(1850, 1000) if leave_before_finish else target), "The pointer remains stationary at its intended final position")
	_check(landed._is_hovered == expected_hover, "Hover follows the pointer after playback unlock, including a pointer parked before landing")
	_check((landed._hover_amount > 0.9) == expected_hover, "The hover animation follows the final pointer position")
	_check(GlobalInteractionRouter.get_peek_controller().is_peek_open() == expected_hover, "Inspection opens without requiring another mouse entry")
