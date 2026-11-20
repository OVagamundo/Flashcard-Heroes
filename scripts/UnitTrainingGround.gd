# res://scripts/UnitTrainingGround.gd
class_name UnitTrainingGround
extends EncounterBase

## Unit Training Ground - Train units' HP or PWR using flashcard tokens.
## Mirrors Shrine UI flow with training-specific drop zones.

const TRAIN_COST_GOLD: int = 5
const SlotViewScene = preload("res://scenes/SlotView.tscn")

@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var open_inventory_button: Button = %OpenInventoryButton
@onready var leave_button: Button = %LeaveButton

var _action_in_progress: bool = false
var _training_stat: String = "" # "hp" or "pwr"
var _training_unit_data: Dictionary = {}
var _training_unit_location: LocationIdentifier = null
var _tokens: int:
	get:
		if is_instance_valid(GameManager.run_state):
			return GameManager.run_state.get_room_tokens()
		return 0
	set(val):
		if is_instance_valid(GameManager.run_state):
			GameManager.run_state.current_room_tokens = val

# Popup references (built programmatically)
var _popup_root: CenterContainer = null
var _popup_panel: PanelContainer = null
var _popup_unit_slot: Control = null
var _popup_ball_view: GachaBallView = null
var _popup_btn_1: Button = null
var _popup_btn_2: Button = null
var _popup_btn_3: Button = null
var _popup_done_btn: Button = null
var _popup_title_label: Label = null


func _ready() -> void:
	open_inventory_button.pressed.connect(_toggle_run_inventory)
	leave_button.pressed.connect(_on_leave_pressed)
	gui_input.connect(_handle_inventory_encounter_background_click)
	SignalBus.locale_changed.connect(_update_localized_text)
	SignalBus.action_drop_zone_1_activated.connect(_on_train_hp_requested)
	SignalBus.action_drop_zone_2_activated.connect(_on_train_pwr_requested)
	FlashcardManager.minigame_finished.connect(_on_flashcard_completed)
	_update_localized_text()
	set_process(true)
	_build_training_popup()
	var main_node: Node = GameManager._active_main_node
	if is_instance_valid(main_node):
		main_node.set_action_zone_texts(tr("ui.utg_drop_hp"), tr("ui.utg_drop_pwr"), true)


func _exit_tree() -> void:
	if SignalBus.locale_changed.is_connected(_update_localized_text):
		SignalBus.locale_changed.disconnect(_update_localized_text)
	if SignalBus.action_drop_zone_1_activated.is_connected(_on_train_hp_requested):
		SignalBus.action_drop_zone_1_activated.disconnect(_on_train_hp_requested)
	if SignalBus.action_drop_zone_2_activated.is_connected(_on_train_pwr_requested):
		SignalBus.action_drop_zone_2_activated.disconnect(_on_train_pwr_requested)
	if FlashcardManager.minigame_finished.is_connected(_on_flashcard_completed):
		FlashcardManager.minigame_finished.disconnect(_on_flashcard_completed)
	var main_node: Node = GameManager._active_main_node
	if is_instance_valid(main_node):
		main_node.set_action_zone_texts("", "")
		main_node.hide_action_instruction()
		main_node.hide_split_action_drop_zones()
	if is_instance_valid(_popup_root):
		_popup_root.queue_free()


func _process(_delta: float) -> void:
	var is_open: bool = WindowManager.is_run_inventory_window_open()
	if is_open != _last_inventory_open:
		_last_inventory_open = is_open
		var main_node: Node = GameManager._active_main_node
		if is_instance_valid(main_node):
			if is_open:
				main_node.show_action_instruction(tr("ui.utg_instruction"))
			else:
				main_node.hide_action_instruction()
				main_node.hide_split_action_drop_zones()


func _update_localized_text() -> void:
	title_label.text = tr("ui.utg_title")
	if is_instance_valid(description_label):
		description_label.text = tr("ui.utg_desc")
	open_inventory_button.text = tr("ui.utg_btn")
	leave_button.text = tr("ui.leave")


# --- Training requests ---

func _on_train_hp_requested(is_drag: bool = false, mouse_pos: Vector2 = Vector2.ZERO) -> void:
	_request_training("hp", is_drag, mouse_pos)


func _on_train_pwr_requested(is_drag: bool = false, mouse_pos: Vector2 = Vector2.ZERO) -> void:
	_request_training("pwr", is_drag, mouse_pos)


func _request_training(stat: String, is_drag: bool, mouse_pos: Vector2) -> void:
	var item_data: Dictionary = _get_selected_run_inventory_entry(true)
	if item_data.is_empty():
		return
	var drop: Dictionary = _resolve_drop_interaction(is_drag, mouse_pos)
	var drop_pos: Vector2 = drop["drop_pos"]
	var action := StartTrainingAction.new(item_data["uuid"], stat, drop["interaction_type"], drop_pos)
	if not ActionQueue.request(action):
		var main_node: Node = GameManager._active_main_node
		var gold_group: Control = main_node.get_node_or_null("%GoldGroup") as Control if is_instance_valid(main_node) else null
		var zone: Control = (main_node.get_action_zone_1() if stat == "hp" else main_node.get_action_zone_2()) if is_instance_valid(main_node) else null
		var target: Control = zone if is_instance_valid(zone) else open_inventory_button
		RejectionFeedbackScript.play_rejection_with_counter(target, gold_group, get_tree())
		if is_drag:
			ActionQueue.request(CancelDragAction.new(item_data["location"], null, "insufficient_gold", drop_pos))
		else:
			GlobalInteractionRouter.apply_deselect_entity()


func execute_start_training_visuals(target_uuid: String, stat: String, p_drop_pos: Vector2 = Vector2.ZERO) -> void:
	if _action_in_progress:
		return
	var item_data: Dictionary = _resolve_run_inventory_entry_by_uuid(target_uuid, true)
	if item_data.is_empty():
		return

	_action_in_progress = true
	_training_stat = stat
	_training_unit_data = item_data
	_training_unit_location = item_data["location"] as LocationIdentifier

	var slot_view: Control = WindowManager.find_view_for_location(_training_unit_location) as Control
	var fallback_pos: Vector2 = slot_view.get_global_rect().get_center() if is_instance_valid(slot_view) else Vector2.ZERO
	var interaction_pos: Vector2 = _consume_animation_start_pos(fallback_pos, p_drop_pos)

	_update_token_display()
	SignalBus.selection_clear_requested.emit()

	var vfx_ball: GachaBallView = null
	var unit_inst: GachaBallInstance = item_data.get("instance") as GachaBallInstance
	if is_instance_valid(unit_inst):
		vfx_ball = _spawn_static_vfx_gachaball(VisualDataAdapter.create_visual_data(unit_inst), interaction_pos)

	if is_instance_valid(slot_view):
		for child in slot_view.get_children():
			if child is GachaBallView:
				(child as GachaBallView).modulate.a = 0.0
				(child as GachaBallView).visible = false

	CurrencyAnimator.animate_gold_spend(TRAIN_COST_GOLD, interaction_pos, func() -> void:
		if is_instance_valid(vfx_ball):
			vfx_ball.queue_free()
		Audio.play_sfx("ui_drag_drop")
		if is_instance_valid(GameManager.run_state):
			FlashcardManager.start_minigame(GameManager.run_state, GameManager.run_state.active_deck_ids)
		_action_in_progress = false
		_finish_active_action()
	)


func _update_token_display(val: int = _tokens) -> void:
	SignalBus.gacha_tokens_changed.emit(val)


func _on_flashcard_completed(_results: Dictionary) -> void:
	WindowManager.close_all_inspection_windows(true)
	_show_training_popup()


# --- Training Popup ---

func _build_training_popup() -> void:
	_popup_root = CenterContainer.new()
	_popup_root.name = "TrainingPopupRoot"
	_popup_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_root.visible = false

	_popup_panel = PanelContainer.new()
	_popup_panel.name = "TrainingPopupPanel"
	_popup_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_popup_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(30)
	_popup_panel.add_theme_stylebox_override("panel", style)
	_popup_root.add_child(_popup_panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.custom_minimum_size = Vector2(440, 0)
	vbox.add_theme_constant_override("separation", 20)
	_popup_panel.add_child(vbox)

	_popup_title_label = Label.new()
	_popup_title_label.text = tr("ui.utg_popup_title")
	_popup_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_title_label.add_theme_font_size_override("font_size", 28)
	_popup_title_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92))
	vbox.add_child(_popup_title_label)

	var unit_center := CenterContainer.new()
	unit_center.custom_minimum_size = Vector2(192, 192)
	vbox.add_child(unit_center)

	var unit_slot := Control.new()
	unit_slot.custom_minimum_size = Vector2(192, 192)
	unit_slot.name = "UnitSlot"
	unit_center.add_child(unit_slot)
	_popup_unit_slot = unit_slot

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_hbox)

	_popup_btn_1 = _create_token_train_button(1, "1 Token")
	_popup_btn_2 = _create_token_train_button(2, "2 Tokens")
	_popup_btn_3 = _create_token_train_button(3, "3 Tokens")
	btn_hbox.add_child(_popup_btn_1)
	btn_hbox.add_child(_popup_btn_2)
	btn_hbox.add_child(_popup_btn_3)

	_popup_done_btn = Button.new()
	_popup_done_btn.text = tr("ui.utg_done")
	_popup_done_btn.custom_minimum_size = Vector2(0, 40)
	_popup_done_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_popup_done_btn.pressed.connect(_on_popup_done)
	vbox.add_child(_popup_done_btn)

	var modal_layer: Node = get_tree().get_first_node_in_group("modal_layer")
	if not is_instance_valid(modal_layer):
		modal_layer = WindowManager._get_modal_layer()
	if is_instance_valid(modal_layer):
		modal_layer.add_child(_popup_root)
	else:
		add_child(_popup_root)


func _create_token_train_button(cost: int, label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(140, 60)
	btn.pressed.connect(func() -> void: ActionQueue.request(TrainUnitStatAction.new(cost)))
	return btn


func _show_training_popup() -> void:
	var unit_inst: GachaBallInstance = _training_unit_data.get("instance") as GachaBallInstance
	if not is_instance_valid(unit_inst):
		_action_in_progress = false
		return

	if is_instance_valid(_popup_unit_slot):
		for c in _popup_unit_slot.get_children():
			c.queue_free()
		await get_tree().process_frame

		var visual_data: Dictionary = VisualDataAdapter.create_visual_data(unit_inst)
		var slot_view: SlotView = SlotViewScene.instantiate() as SlotView
		slot_view.set_size_scale(2.0)
		slot_view.custom_minimum_size = Vector2(C.SLOT_SIZE_2X, C.SLOT_SIZE_2X)
		slot_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot_view.set_slot_color(&"PlayerLineup")
		_popup_unit_slot.add_child(slot_view)
		if SignalBus.unit_stat_changed.is_connected(slot_view._on_unit_stat_changed):
			SignalBus.unit_stat_changed.disconnect(slot_view._on_unit_stat_changed)
		_popup_ball_view = slot_view.set_content(visual_data, false, false)
		if is_instance_valid(_popup_ball_view):
			_popup_ball_view.set_is_interactive(false)
			_popup_ball_view.set_animation_controller_active(false)

	_update_popup_buttons()
	_popup_root.visible = true
	_popup_root.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(_popup_root, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_popup_buttons() -> void:
	_popup_btn_1.disabled = _tokens < 1
	_popup_btn_2.disabled = _tokens < 2
	_popup_btn_3.disabled = _tokens < 3
	_popup_btn_1.text = "1 Token"
	_popup_btn_2.text = "2 Tokens"
	_popup_btn_3.text = "3 Tokens"


func play_transaction_log(event_log: Dictionary) -> void:
	if not event_log.get("success", false):
		_finish_active_action()
		return
	var cost: int = int(event_log.get("token_cost", 1))
	var roll: int = int(event_log.get("roll", -1))
	execute_train_visuals(cost, roll)


func execute_train_visuals(cost: int, roll: int = -1) -> void:
	await _spend_tokens_and_train(cost, roll)
	_finish_active_action()


func _spend_tokens_and_train(cost: int, pre_rolled_value: int = -1) -> void:
	var roll: int = pre_rolled_value
	var unit_uuid: String = _training_unit_data.get("uuid", "")
	if roll == -1:
		if _tokens < cost:
			return
		_tokens -= cost
		roll = GameManager.roll_training_reward(cost)
		if not unit_uuid.is_empty() and is_instance_valid(GameManager.run_state) and roll > 0:
			var hp_delta: int = roll if _training_stat == "hp" else 0
			var pwr_delta: int = roll if _training_stat == "pwr" else 0
			GameManager.run_state.modify_unit_base_stats(unit_uuid, hp_delta, pwr_delta)

	_update_token_display()
	_update_popup_buttons()

	if unit_uuid.is_empty() or not is_instance_valid(GameManager.run_state):
		return

	if is_instance_valid(_popup_ball_view):
		var center: Vector2 = _popup_ball_view.get_global_rect().get_center()
		var proj: Node = VFXFactory.spawn_projectile_on_layer(roll, _training_stat, center, center, true)
		if is_instance_valid(proj):
			proj.launch()
			await proj.impact

		var instance: GachaBallInstance = GameManager.run_state.get_instance_by_uuid(unit_uuid)
		if is_instance_valid(instance):
			var new_val: int = instance.current_hp if _training_stat == "hp" else instance.current_pwr
			_popup_ball_view.animate_stat_change(new_val, roll, _training_stat, false)

		await _play_buff_hop()
	else:
		Audio.play_sfx("unit_buff")


func _play_buff_hop() -> void:
	if not is_instance_valid(_popup_ball_view):
		return
	Audio.play_sfx("unit_buff")

	var icon: Control = _popup_ball_view.icon_rect if is_instance_valid(_popup_ball_view.icon_rect) else _popup_ball_view
	if not is_instance_valid(icon):
		return

	icon.pivot_offset = Vector2(icon.size.x / 2.0, icon.size.y)
	var move_tween: Tween = _popup_ball_view.create_tween()
	move_tween.tween_property(_popup_ball_view, "position", Vector2(0, -30.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	move_tween.tween_property(_popup_ball_view, "position", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var deform_tween: Tween = icon.create_tween()
	deform_tween.tween_property(icon, "scale", Vector2(0.85, 1.15), 0.03).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	deform_tween.tween_property(icon, "scale", Vector2(1.15, 0.85), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	deform_tween.tween_property(icon, "scale", Vector2(0.85, 1.15), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	deform_tween.tween_property(icon, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	var flash_color: Color = Color.RED if _training_stat == "hp" else Color.MEDIUM_PURPLE
	_popup_ball_view.modulate = Color(flash_color.r * 1.3, flash_color.g * 1.3, flash_color.b * 1.3, 1.0)
	var color_tween: Tween = _popup_ball_view.create_tween()
	color_tween.tween_property(_popup_ball_view, "modulate", Color.WHITE, 0.3)

	await deform_tween.finished
	icon.scale = Vector2.ONE
	_popup_ball_view.position = Vector2.ZERO


func _on_popup_done() -> void:
	ActionQueue.request(CloseTrainingPopupAction.new())


func _close_training_popup() -> void:
	if not is_instance_valid(_popup_panel):
		return

	var target_view: Control = WindowManager.find_view_for_location(_training_unit_location) as Control
	var start_pos: Vector2 = _popup_ball_view.get_global_rect().get_center() if is_instance_valid(_popup_ball_view) else Vector2.ZERO

	var tween: Tween = create_tween()
	tween.tween_property(_popup_root, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func() -> void: _popup_root.visible = false)

	var unit_inst: GachaBallInstance = _training_unit_data.get("instance") as GachaBallInstance
	if is_instance_valid(unit_inst) and start_pos != Vector2.ZERO:
		var vfx_ball: GachaBallView = _spawn_static_vfx_gachaball(VisualDataAdapter.create_visual_data(unit_inst), start_pos)
		if is_instance_valid(target_view):
			var ball_in_slot: GachaBallView = _resolve_ball_view(target_view)
			if is_instance_valid(ball_in_slot):
				ball_in_slot.visible = false
				ball_in_slot.modulate.a = 0.0
			await _animate_vfx_ball_to_slot(vfx_ball, start_pos, target_view, 0.55)
		else:
			vfx_ball.queue_free()
	elif is_instance_valid(target_view):
		var ball_in_slot: GachaBallView = _resolve_ball_view(target_view)
		if is_instance_valid(ball_in_slot):
			ball_in_slot.visible = true
			ball_in_slot.modulate.a = 1.0

	_action_in_progress = false
	_training_unit_data = {}
	_training_unit_location = null
	_training_stat = ""
	_update_token_display(0)
	if ActionQueue.get_active_action() is CloseTrainingPopupAction:
		_finish_active_action()


func _on_leave_pressed() -> void:
	ActionQueue.request(LeaveTrainingAction.new())


func execute_leave_visuals() -> void:
	var main_node: Node = GameManager._active_main_node
	if is_instance_valid(main_node):
		main_node.hide_action_instruction()
		main_node.hide_split_action_drop_zones()
	_update_token_display(0)
	SignalBus.path_choice_scene_requested.emit()
	queue_free()
