# res://scripts/BattleView.gd
class_name BattleView
extends Control

const C = preload("res://scripts/Constants.gd")
const SlotViewScene = preload("res://scenes/SlotView.tscn")
const InputUtils = preload("res://scripts/InputUtils.gd")

# --- UI Node References ---
@onready var player_lineup: HBoxContainer = %PlayerLineup
@onready var player_shelf: HBoxContainer = %PlayerShelf
@onready var enemy_lineup: HBoxContainer = %EnemyLineupContainer
@onready var end_turn_button: Button = %EndTurnButton
@onready var enemy_trinket_bar: HBoxContainer = %EnemyTrinketBar
@onready var enemy_banner_view: EnemyBannerView = %EnemyBanner

var discard_pile_button: Control:
	get:
		if is_instance_valid(_discard_pile_button):
			return _discard_pile_button
		if has_node("%DiscardPileButton"):
			return get_node("%DiscardPileButton") as Control
		var main_node: Node = GameManager.get_main_node()
		if is_instance_valid(main_node):
			var node: Control = main_node.get_node_or_null("%GachaMachineDiscard") as Control
			if is_instance_valid(node):
				return node
		return null
	set(val):
		_discard_pile_button = val
var _discard_pile_button: Control = null

var turn_controls: HBoxContainer
var order_button: Button
var preview_button: Button
var token_tray: Control

var battle_manager: BattleManager
var _visual_discard_count: int = 0
var _battle_animator: Node = null
var _pending_board_redraw: bool = false
var _pending_shelf_purchase_index: int = -1
var _waiting_for_management_tutorial: bool = false
var _waiting_for_first_draw_tutorial: bool = false
var _pending_animated_uuids: Array[String] = []
var _turn_preview: BattleTurnPreviewOverlay = BattleTurnPreviewOverlay.new()


func _initialize_slots(ui_container: HBoxContainer, container_name: StringName) -> void:
	var slots: Array[Node] = ui_container.get_children()
	for i: int in range(slots.size()):
		var child: Node = slots[i]
		var slot_view: SlotView = null
		var loc := LocationIdentifier.new(container_name, i)
		if child is SlotView:
			slot_view = child as SlotView
			slot_view.populate(loc)
		elif child is PanelContainer:
			var parent: Node = child.get_parent()
			var idx: int = child.get_index()
			child.free()
			slot_view = SlotViewScene.instantiate() as SlotView
			parent.add_child(slot_view)
			parent.move_child(slot_view, idx)
			slot_view.populate(loc)

		if not is_instance_valid(slot_view):
			continue

		if container_name == &"EnemyTrinkets":
			slot_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			slot_view.custom_minimum_size = Vector2(98, 98)
			slot_view.set_size_scale(1.0)
		else:
			slot_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			slot_view.custom_minimum_size = Vector2(C.SLOT_SIZE_2X, C.SLOT_SIZE_2X)
			slot_view.set_size_scale(2.0)

		slot_view.set_slot_color(container_name)
		if container_name in [&"EnemyLineup", &"EnemyTrinkets"]:
			slot_view.set_interaction_context(&"INSPECTION_ONLY", 0)
		if container_name == &"PlayerShelf":
			if not slot_view.shelf_slot_purchase_requested.is_connected(_on_shelf_slot_purchase_requested):
				slot_view.shelf_slot_purchase_requested.connect(_on_shelf_slot_purchase_requested)


func _ready() -> void:
	add_to_group("battle_view")
	if get_tree().get_nodes_in_group("battle_view").size() > 1:
		queue_free()
		return
	battle_manager = get_node("BattleManager") as BattleManager
	if not is_instance_valid(battle_manager):
		return

	SignalBus.battle_inventory_changed.connect(_redraw_board)
	SignalBus.battle_phase_changed.connect(_on_battle_phase_changed)
	battle_manager.management_animation_queue_completed.connect(_on_turn_animation_finished_redraw)
	SignalBus.battle_entry_animation_requested.connect(_on_battle_entry_animation_requested)
	SignalBus.results_acknowledged.connect(_on_results_acknowledged)

	ActionQueue.action_completed.connect(_on_action_completed)
	ActionQueue.action_started.connect(_close_preview_for_action)
	ActionQueue.queue_idle.connect(_on_action_queue_idle)

	turn_controls = %TurnControls
	order_button = %OrderButton
	preview_button = %PreviewButton
	token_tray = %BattleTokenTray

	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	end_turn_button.resized.connect(_position_combat_controls)
	order_button.button_down.connect(func() -> void: _turn_preview.order_button_held = true)
	order_button.button_up.connect(func() -> void: _turn_preview.order_button_held = false)
	preview_button.button_down.connect(_begin_turn_preview)
	preview_button.button_up.connect(_end_turn_preview)

	var main: Node = GameManager.get_main_node()
	if is_instance_valid(main):
		main.set_battle_token_tray(token_tray)
	if is_instance_valid(discard_pile_button) and not discard_pile_button.pressed.is_connected(_on_discard_pile_pressed):
		discard_pile_button.pressed.connect(_on_discard_pile_pressed)

	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()

	_initialize_slots(player_lineup, &"PlayerLineup")
	_initialize_slots(player_shelf, &"PlayerShelf")
	_initialize_slots(enemy_lineup, &"EnemyLineup")
	_initialize_slots(enemy_trinket_bar, &"EnemyTrinkets")
	_position_combat_controls()
	_update_shelf_slot_states()

	_redraw_board()
	_on_battle_phase_changed(battle_manager.get_current_phase_name())
	var viewport: Viewport = get_viewport()
	if is_instance_valid(viewport) and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)

	_resolve_battle_animator()
	var current_speed: float = AnimationConstants.speed_factor
	if is_instance_valid(_battle_animator):
		_battle_animator.play_continuous(current_speed)
	SignalBus.combat_speed_changed.emit(current_speed)


func _exit_tree() -> void:
	var main: Node = GameManager.get_main_node()
	if is_instance_valid(main) and is_instance_valid(token_tray):
		main.clear_battle_token_tray(token_tray)
	if is_instance_valid(discard_pile_button) and discard_pile_button.pressed.is_connected(_on_discard_pile_pressed):
		discard_pile_button.pressed.disconnect(_on_discard_pile_pressed)


func _resolve_battle_animator() -> void:
	if not is_instance_valid(_battle_animator):
		_battle_animator = BattleAnimator
	if is_instance_valid(_battle_animator):
		if not _battle_animator.turn_animation_finished.is_connected(_on_turn_animation_finished_redraw):
			_battle_animator.turn_animation_finished.connect(_on_turn_animation_finished_redraw)


func _on_turn_animation_finished_redraw() -> void:
	if _pending_board_redraw:
		_pending_board_redraw = false
		_redraw_board()
	_refresh_shelf_hover_after_playback()


func _refresh_shelf_hover_after_playback() -> void:
	await get_tree().process_frame
	if GlobalInteractionRouter.is_vcr_playing():
		return
	for slot: Node in player_shelf.get_children():
		for child: Node in slot.get_children():
			if child is GachaBallView and not child.is_queued_for_deletion():
				(child as GachaBallView).refresh_hover_state_from_pointer()


func _position_combat_controls() -> void:
	const CONTROL_HEIGHT: float = 40.0
	turn_controls.size = Vector2(end_turn_button.size.x, CONTROL_HEIGHT)
	turn_controls.global_position = end_turn_button.global_position - Vector2(0.0, turn_controls.size.y + 8.0)
	var controls_top: float = turn_controls.global_position.y
	token_tray.global_position.y = controls_top
	token_tray.size.y = end_turn_button.global_position.y + end_turn_button.size.y - controls_top


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_turn_preview.on_focus_lost(self)


func _process(_delta: float) -> void:
	if battle_manager == null:
		return
	_turn_preview.sync_controls(self)
	_position_combat_controls()
	_turn_preview.refresh_order_labels(self)


func _begin_turn_preview() -> void:
	_turn_preview.begin_preview(self)


func _end_turn_preview() -> void:
	_turn_preview.end_preview(self)


func _close_preview_for_action(_action: GameAction) -> void:
	_turn_preview.end_preview(self)


func _on_viewport_size_changed() -> void:
	_turn_preview.end_preview(self)


func _on_battle_entry_animation_requested() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	BattleDrawAnimator.animate_initial_unit_entry(self)


func _on_results_acknowledged() -> void:
	if battle_manager.get_current_phase() == BattleManager.Phases.MANAGEMENT:
		BattleDrawAnimator.show_battle_management_tutorial(self)
	else:
		_waiting_for_management_tutorial = true


func _on_discard_pile_pressed() -> void:
	if WindowManager.is_discard_pile_window_open():
		ActionQueue.request(CloseDiscardPileAction.new())
	else:
		ActionQueue.request(OpenDiscardPileAction.new())


func _update_localized_text() -> void:
	order_button.text = tr("ui.battle_order")
	preview_button.text = tr("ui.battle_preview")
	if is_instance_valid(end_turn_button):
		end_turn_button.text = tr("ui.ready")
	if is_instance_valid(discard_pile_button):
		discard_pile_button.text = "x%d/%d" % [_visual_discard_count, C.BATTLE_DISCARD_CAP]
	_update_shelf_slot_states()


func _on_shelf_slot_purchase_requested(_slot_index: int) -> void:
	ActionQueue.request(PurchaseShelfSlotAction.new())


func _update_shelf_slot_states() -> void:
	if not is_instance_valid(player_shelf) or not is_instance_valid(battle_manager):
		return
	var unlocked_slots: int = battle_manager.get_player_shelf_slots_unlocked()
	if _pending_shelf_purchase_index >= 0:
		unlocked_slots = mini(unlocked_slots, _pending_shelf_purchase_index)
	for slot_index: int in range(player_shelf.get_child_count()):
		var slot: SlotView = player_shelf.get_child(slot_index) as SlotView
		if is_instance_valid(slot):
			slot.set_shelf_slot_state(slot_index >= unlocked_slots, slot_index == unlocked_slots and _pending_shelf_purchase_index < 0)


func prepare_shelf_purchase(slot_index: int) -> void:
	_pending_shelf_purchase_index = slot_index
	_update_shelf_slot_states()
	GameManager.get_main_node().begin_token_animation()


func animate_shelf_purchase(slot_index: int, action: GameAction) -> void:
	var slot: SlotView = player_shelf.get_child(slot_index) as SlotView
	await CurrencyAnimator.animate_token_spend(C.SHELF_SLOT_TOKEN_COST, slot.get_global_rect().get_center())
	_pending_shelf_purchase_index = -1
	_update_shelf_slot_states()
	await slot.animate_shelf_unlock()
	GameManager.get_main_node().end_token_animation()
	if battle_manager.is_animating_management_queue():
		await battle_manager.management_animation_queue_completed
	ActionQueue.finish_action(action)


func play_lineup_capsule_open(source_location: LocationIdentifier, target_location: LocationIdentifier) -> void:
	BattleDrawAnimator.play_lineup_capsule_open(self, source_location, target_location)


func init_visual_discard_count(initial_count: int) -> void:
	_visual_discard_count = initial_count
	if is_instance_valid(discard_pile_button):
		discard_pile_button.text = "x%d/%d" % [_visual_discard_count, C.BATTLE_DISCARD_CAP]


func animate_discard_pile_arrival(amount: int = 1) -> void:
	_visual_discard_count = clampi(_visual_discard_count + amount, 0, C.BATTLE_DISCARD_CAP)
	if is_instance_valid(discard_pile_button):
		discard_pile_button.text = "x%d/%d" % [_visual_discard_count, C.BATTLE_DISCARD_CAP]
		play_machine_landing_bounce(discard_pile_button)


func play_machine_landing_bounce(machine: Control) -> void:
	if is_instance_valid(machine):
		GachaMachineBarPresenter.play_landing_bounce(machine)


func _redraw_board() -> void:
	if not is_instance_valid(battle_manager) or not is_inside_tree() or is_queued_for_deletion():
		return

	# NEVER redraw the board during animation phases (BattleAnimator owns all puppets).
	_resolve_battle_animator()
	var current_phase: int = battle_manager.get_current_phase()
	if current_phase == BattleManager.Phases.COMBAT or \
	   current_phase == BattleManager.Phases.START_OF_TURN or \
	   current_phase == BattleManager.Phases.END_OF_TURN or \
	   battle_manager.is_animations_playing():
		_pending_board_redraw = true
		return

	_pending_board_redraw = false

	_populate_container(player_lineup, &"PlayerLineup", false)
	_populate_container(player_shelf, &"PlayerShelf", false)
	_populate_container(enemy_lineup, &"EnemyLineup", true)
	_populate_enemy_trinkets()
	_populate_enemy_banner()

	var discard_container: DataContainer = battle_manager.get_container(&"DiscardPile")
	if is_instance_valid(discard_container):
		init_visual_discard_count(discard_container.get_all_non_empty_uuids().size())
	_update_shelf_slot_states()


func _populate_container(ui_container: HBoxContainer, container_name: StringName, is_enemy: bool) -> void:
	if not is_instance_valid(battle_manager):
		return

	var data_container: DataContainer = battle_manager.get_container(container_name)
	if not is_instance_valid(data_container):
		return

	var slots: Array[SlotView] = []
	for child in ui_container.get_children():
		if child is SlotView:
			slots.append(child as SlotView)

	for slot: SlotView in slots:
		for content in slot.get_children():
			if content.has_meta("slot_persistent_child"):
				continue
			content.queue_free()

	var uuids: Array[String] = data_container.get_all_uuids()
	for i: int in range(slots.size()):
		var slot: SlotView = slots[i]
		var loc := LocationIdentifier.new(container_name, i)

		var slot_effect: StringName = &""
		if container_name == &"PlayerLineup":
			slot_effect = battle_manager._state.player_slot_effects[i]
		elif container_name == &"EnemyLineup":
			slot_effect = battle_manager._state.enemy_slot_effects[i]

		var instance: GachaBallInstance = null
		if i < uuids.size():
			var uuid: String = uuids[i]
			if not (uuid in _pending_animated_uuids):
				instance = battle_manager.get_instance(uuid)

		slot.populate(loc)
		slot.set_meta("location_identifier", loc)

		if is_instance_valid(instance):
			var visual_data: Dictionary = VisualDataAdapter.create_visual_data(instance, battle_manager.get_all_instances())
			var view: GachaBallView = slot.set_content(visual_data, true, is_enemy)
			slot.set_slot_effect(slot_effect)
			if container_name == &"EnemyLineup" and is_instance_valid(view):
				var def: Resource = instance.get_definition()
				if def is GachaBallDefinition:
					view.set_interaction_context(&"INSPECTION_ONLY", (def as GachaBallDefinition).category, 0)
		else:
			slot.set_content({}, false, false)
			slot.set_slot_effect(slot_effect)
			if container_name == &"EnemyLineup":
				slot.set_interaction_context(&"INSPECTION_ONLY", 0)


func _populate_enemy_banner() -> void:
	var banner: GachaBallInstance = battle_manager.get_instance_by_location(LocationIdentifier.new(C.BATTLE_CONTAINER_TAGS.ENEMY_BANNER, 0))
	enemy_banner_view.populate(VisualDataAdapter.create_visual_data(banner) if banner != null else {})


func _populate_enemy_trinkets() -> void:
	if not is_instance_valid(battle_manager):
		return
	var slots: Array[Node] = enemy_trinket_bar.get_children()
	for i: int in range(slots.size()):
		var slot_view: SlotView = slots[i] as SlotView
		if not is_instance_valid(slot_view):
			continue
		for child in slot_view.get_children():
			if child is TextureRect and (child.z_index == 10 or child.z_index == -1):
				continue
			child.queue_free()

		var loc := LocationIdentifier.new(&"EnemyTrinkets", i)
		slot_view.set_size_scale(1.0)
		slot_view.populate(loc)
		slot_view.set_interaction_context(&"INSPECTION_ONLY", 0)

		if i < battle_manager.enemy_trinkets.size() and is_instance_valid(battle_manager.enemy_trinkets[i]):
			var visual_data: Dictionary = VisualDataAdapter.create_visual_data(battle_manager.enemy_trinkets[i])
			var view: GachaBallView = slot_view.set_content(visual_data, true, true)
			if is_instance_valid(view):
				view.set_interaction_context(&"INSPECTION_ONLY", &"TRINKET", 0)
		else:
			slot_view.set_content({})


func _on_battle_phase_changed(phase_name: StringName) -> void:
	_turn_preview.end_preview(self)
	_turn_preview.sync_controls(self)
	_turn_preview.refresh_order_labels(self)

	var is_management_phase: bool = (phase_name == &"MANAGEMENT")
	var is_combat: bool = (phase_name == &"COMBAT")
	end_turn_button.disabled = not is_management_phase
	if is_instance_valid(discard_pile_button):
		discard_pile_button.disabled = is_combat

	if is_management_phase:
		_redraw_board()
		if _waiting_for_management_tutorial:
			BattleDrawAnimator.show_battle_management_tutorial(self)
			_waiting_for_management_tutorial = false


func _gui_input(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		var context := InteractionContext.new()
		context.source_view_instance_id = get_instance_id()
		context.event_type = &"SINGLE_CLICK"
		context.location = null
		context.entity_uuid = ""
		context.entity_type = &"GLOBAL_BACKGROUND"
		context.interaction_mode = &"FULLY_INTERACTIVE"
		context.window_group_id = 0
		SignalBus.interaction_context_received.emit(context)


func animate_gacha_draw(draw_result: InventoryOperations.DrawResult, new_unit_snapshot: Dictionary) -> void:
	await BattleDrawAnimator.animate_gacha_draw(self, draw_result, new_unit_snapshot)


func _on_action_completed(action: GameAction) -> void:
	if action is DrawGachaAction and _waiting_for_first_draw_tutorial:
		_waiting_for_first_draw_tutorial = false
		call_deferred("_show_first_draw_tutorial")


func _on_action_queue_idle() -> void:
	if _waiting_for_first_draw_tutorial:
		_waiting_for_first_draw_tutorial = false
		call_deferred("_show_first_draw_tutorial")


func _show_first_draw_tutorial() -> void:
	BattleDrawAnimator.show_first_draw_tutorial(self)


func _on_end_turn_button_pressed() -> void:
	var bm: BattleManager = GameManager.get_battle_manager() as BattleManager
	if is_instance_valid(bm) and bm.is_animations_playing():
		return
	ActionQueue.request(EndTurnAction.new())


func execute_pause() -> void:
	_resolve_battle_animator()
	if is_instance_valid(_battle_animator):
		_battle_animator.pause_combat()
	SignalBus.combat_pause_changed.emit(true)


func execute_speed(speed: float) -> void:
	_resolve_battle_animator()
	if is_instance_valid(_battle_animator):
		_battle_animator.play_continuous(speed)
	SignalBus.combat_speed_changed.emit(speed)
