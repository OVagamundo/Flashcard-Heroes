extends Control

const COST_GOLD: int = 5
const BLACK_MARKET_CONTAINER: StringName = &"BlackMarket"
const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")
const ChoiceWindowScene = preload("res://scenes/BlackMarketChoiceWindow.tscn")
const RejectionFeedbackScript = preload("res://scripts/vfx/RejectionFeedback.gd")
const InputUtils = preload("res://scripts/InputUtils.gd")

@onready var title_label: Label = %TitleLabel
@onready var open_inventory_button: Button = %OpenInventoryButton
@onready var leave_button: Button = %LeaveButton
@onready var foreground_ui: Control = $ForegroundUI
@onready var instruction_label: Label = %InstructionLabel
@onready var service_area: Control = %ServiceArea
@onready var black_market_slot: Control = %BlackMarketSlot

var _choice_backdrop: ColorRect = null
var _choice_window: BlackMarketChoiceWindow = null
var _service_visible: bool = false
var _action_in_progress: bool = false

var _staged_source_location: LocationIdentifier = null
var _staged_source_uuid: String = ""
var _staged_source_view_id: int = -1
var _staged_source_definition_id: StringName = &""
var _staged_display_name: String = ""
var _staged_visual_data: Dictionary = {}

func _ready() -> void:
	add_to_group("black_market_controller")
	open_inventory_button.pressed.connect(_on_open_inventory_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	gui_input.connect(_on_gui_input)
	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()
	_mount_overlay()
	_ensure_choice_backdrop()
	if black_market_slot.has_method("set_controller"):
		black_market_slot.set_controller(self)
	set_process(true)

func _exit_tree() -> void:
	if SignalBus.locale_changed.is_connected(_update_localized_text):
		SignalBus.locale_changed.disconnect(_update_localized_text)
	_cancel_staged_transaction(false)
	if is_instance_valid(foreground_ui):
		foreground_ui.queue_free()

func _process(_delta: float) -> void:
	var should_show := WindowManager.is_run_inventory_window_open()
	if should_show != _service_visible:
		if not should_show and _has_staged_transaction():
			_cancel_staged_transaction(false)
		_set_service_visible(should_show)

func _unhandled_input(event: InputEvent) -> void:
	if not _has_staged_transaction():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel_staged_transaction(true)
		get_viewport().set_input_as_handled()

func _update_localized_text() -> void:
	title_label.text = tr("ui.black_market_title")
	open_inventory_button.text = tr("ui.black_market_open_inventory")
	leave_button.text = tr("ui.leave")
	instruction_label.text = tr("ui.black_market_instructions")

func can_accept_black_market_drop(source_loc: LocationIdentifier) -> bool:
	if _action_in_progress or _has_staged_transaction():
		return false
	if not WindowManager.is_run_inventory_window_interactive():
		return false
	if not is_instance_valid(source_loc):
		return false
	return _is_run_inventory_source(source_loc)

func handle_black_market_drop(source_loc: LocationIdentifier, source_view: Control) -> bool:
	if not can_accept_black_market_drop(source_loc):
		return false
	return _stage_black_market_transaction(source_loc, source_view)

func handle_black_market_selection_action(source_loc: LocationIdentifier) -> bool:
	if not can_accept_black_market_drop(source_loc):
		return false
	var source_view := _find_ball_view_for_location(source_loc)
	if not is_instance_valid(source_view):
		return false
	var parent_window := WindowManager.find_ancestor_window_for_view(source_view)
	if is_instance_valid(parent_window):
		WindowManager.close_children_of(parent_window)
	return _stage_black_market_transaction(source_loc, source_view)

func _stage_black_market_transaction(source_loc: LocationIdentifier, source_view: Control) -> bool:
	var instance := GameManager.get_instance_from_location(source_loc)
	if not is_instance_valid(instance):
		return false
	var definition = instance.get_definition()
	if not is_instance_valid(definition):
		return false

	_staged_source_location = source_loc
	_staged_source_uuid = instance.ball_uuid
	_staged_source_view_id = source_view.get_instance_id() if is_instance_valid(source_view) else -1
	_staged_source_definition_id = definition.id
	_staged_display_name = tr(definition.display_name_key) if not String(definition.display_name_key).is_empty() else String(definition.id)
	_staged_visual_data = VisualDataAdapter.create_visual_data(instance)
	if is_instance_valid(source_view):
		source_view.visible = false
		source_view.modulate.a = 0.0

	if black_market_slot.has_method("show_staged_visual"):
		black_market_slot.show_staged_visual(_staged_visual_data)
	_show_choice_window()
	return true

func _mount_overlay() -> void:
	var overlay_host := get_tree().get_first_node_in_group("background_ui_layer")
	if not is_instance_valid(overlay_host):
		return
	if foreground_ui.get_parent() == overlay_host:
		return
	var previous_parent := foreground_ui.get_parent()
	if is_instance_valid(previous_parent):
		previous_parent.remove_child(foreground_ui)
	overlay_host.add_child(foreground_ui)
	foreground_ui.hide()

func _ensure_choice_backdrop() -> void:
	if is_instance_valid(_choice_backdrop):
		return
	_choice_backdrop = ColorRect.new()
	_choice_backdrop.name = "ChoiceBackdrop"
	_choice_backdrop.visible = false
	_choice_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_choice_backdrop.color = Color(0, 0, 0, 0)
	_choice_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choice_backdrop.set_offsets_preset(Control.PRESET_FULL_RECT)
	_choice_backdrop.gui_input.connect(_on_choice_backdrop_gui_input)
	foreground_ui.add_child(_choice_backdrop)

func _set_service_visible(visible: bool) -> void:
	_service_visible = visible
	if is_instance_valid(foreground_ui):
		foreground_ui.visible = visible

func _show_choice_window() -> void:
	if not is_instance_valid(_choice_backdrop):
		return
	_choice_backdrop.visible = true
	if is_instance_valid(_choice_window):
		_choice_window.queue_free()

	_choice_window = ChoiceWindowScene.instantiate() as BlackMarketChoiceWindow
	_choice_backdrop.add_child(_choice_window)
	_choice_window.populate(_staged_display_name)
	_choice_window.remove_requested.connect(_on_remove_requested)
	_choice_window.transform_requested.connect(_on_transform_requested)
	call_deferred("_position_choice_window")

func _position_choice_window() -> void:
	if not is_instance_valid(_choice_window):
		return
	_choice_window.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var window_size := _choice_window.size
	if window_size == Vector2.ZERO:
		window_size = _choice_window.custom_minimum_size
	var slot_rect := black_market_slot.get_global_rect()
	var viewport_rect := get_viewport().get_visible_rect()
	var target_position := Vector2(
		slot_rect.get_center().x - (window_size.x * 0.5),
		slot_rect.position.y - window_size.y - 24.0
	)
	target_position.x = clampf(target_position.x, 24.0, viewport_rect.size.x - window_size.x - 24.0)
	target_position.y = maxf(24.0, target_position.y)
	_choice_window.position = target_position

func _close_choice_window() -> void:
	if is_instance_valid(_choice_window):
		_choice_window.queue_free()
	_choice_window = null
	if is_instance_valid(_choice_backdrop):
		_choice_backdrop.visible = false

func _dismiss_choice_window_keep_blocker() -> void:
	if is_instance_valid(_choice_window):
		_choice_window.queue_free()
	_choice_window = null
	if is_instance_valid(_choice_backdrop):
		_choice_backdrop.visible = true

func _cancel_staged_transaction(play_bounce: bool) -> void:
	if not _has_staged_transaction():
		return
	_restore_staged_source_view(play_bounce)
	if black_market_slot.has_method("clear_staged_visual"):
		black_market_slot.clear_staged_visual()
	_close_choice_window()
	_clear_stage_state()
	_action_in_progress = false

func _restore_staged_source_view(play_bounce: bool) -> void:
	if _staged_source_view_id == -1:
		return
	var source_view = instance_from_id(_staged_source_view_id)
	if not is_instance_valid(source_view) or not source_view is Control:
		return
	source_view.visible = true
	source_view.modulate.a = 1.0
	if play_bounce and source_view.has_method("play_landing_bounce"):
		source_view.play_landing_bounce()

func _clear_stage_state() -> void:
	_staged_source_location = null
	_staged_source_uuid = ""
	_staged_source_view_id = -1
	_staged_source_definition_id = &""
	_staged_display_name = ""
	_staged_visual_data = {}

func _has_staged_transaction() -> bool:
	return is_instance_valid(_staged_source_location) and not _staged_source_uuid.is_empty()

func _spend_gold_or_reject() -> bool:
	if not is_instance_valid(GameManager.run_state):
		return false
	if GameManager.run_state.spend_gold(COST_GOLD):
		return true

	var main_node = GameManager._active_main_node
	var gold_group = main_node.get_node_or_null("%GoldGroup") if is_instance_valid(main_node) else null
	RejectionFeedbackScript.play_rejection_with_counter(service_area, gold_group, get_tree())
	return false

func _draw_transform_definition(source_definition_id: StringName, source_tier: int) -> GachaBallDefinition:
	var eligible: Array[GachaBallDefinition] = []
	for definition in Database.get_all_pool_definitions():
		if not is_instance_valid(definition):
			continue
		if definition.id == source_definition_id:
			continue
		if definition.tier != source_tier:
			continue
		eligible.append(definition)

	if eligible.is_empty():
		return null
	return eligible[randi() % eligible.size()]

func _is_run_inventory_source(source_loc: LocationIdentifier) -> bool:
	return String(source_loc.container).begins_with("RunInventoryT")

func _find_ball_view_for_location(loc: LocationIdentifier) -> Control:
	return _resolve_ball_view(WindowManager.find_view_for_location(loc))

func _resolve_ball_view(anchor: Control) -> Control:
	if not is_instance_valid(anchor):
		return null
	if anchor is GachaBallView:
		return anchor
	for child in anchor.get_children():
		if child is GachaBallView:
			return child
	return null

func _on_remove_requested() -> void:
	if _action_in_progress or not _has_staged_transaction():
		return
	if not _spend_gold_or_reject():
		return

	_action_in_progress = true
	_dismiss_choice_window_keep_blocker()
	if black_market_slot.has_method("clear_staged_visual"):
		black_market_slot.clear_staged_visual()

	GameManager.run_state.remove_instance(_staged_source_uuid)

	_close_choice_window()
	_clear_stage_state()
	_action_in_progress = false

func _on_transform_requested() -> void:
	if _action_in_progress or not _has_staged_transaction():
		return

	var source_instance := GameManager.run_state.get_instance_by_uuid(_staged_source_uuid)
	if not is_instance_valid(source_instance):
		_cancel_staged_transaction(false)
		return

	var source_definition = source_instance.get_definition()
	if not is_instance_valid(source_definition):
		_cancel_staged_transaction(false)
		return

	var result_definition := _draw_transform_definition(source_definition.id, int(source_definition.tier))
	if not is_instance_valid(result_definition):
		return
	if not _spend_gold_or_reject():
		return

	_action_in_progress = true
	var target_location := _staged_source_location
	_dismiss_choice_window_keep_blocker()
	if black_market_slot.has_method("clear_staged_visual"):
		black_market_slot.clear_staged_visual()

	GameManager.run_state.remove_instance(_staged_source_uuid)

	var new_instance := GachaBallInstance.new()
	new_instance.initialize(result_definition)
	GameManager.run_state.add_instance(new_instance, target_location.container, target_location.index)
	GameManager.run_state.unlock_recipe_for_result(result_definition.id)

	var target_view := await _prepare_transform_target_view(target_location)
	await _animate_transform_to_slot(VisualDataAdapter.create_visual_data(new_instance), target_view)

	_close_choice_window()
	_clear_stage_state()
	_action_in_progress = false

func _prepare_transform_target_view(target_location: LocationIdentifier) -> Control:
	await get_tree().process_frame
	var target_anchor := WindowManager.find_view_for_location(target_location)
	var target_ball_view := _resolve_ball_view(target_anchor)

	if is_instance_valid(target_ball_view):
		target_ball_view.visible = false
		target_ball_view.modulate.a = 0.0

	return target_ball_view

func _animate_transform_to_slot(visual_data: Dictionary, target_view: Control) -> void:
	var main_node = GameManager._active_main_node
	if not is_instance_valid(main_node) or not is_instance_valid(target_view):
		if is_instance_valid(target_view):
			target_view.visible = true
			target_view.modulate.a = 1.0
		return

	var start_center := black_market_slot.get_global_rect().get_center()
	var end_center := target_view.get_global_rect().get_center()

	var anim_ball = GachaBallViewScene.instantiate()
	var effects_layer = main_node.get_node_or_null("EffectsLayer")
	if is_instance_valid(effects_layer):
		effects_layer.add_child(anim_ball)
	else:
		add_child(anim_ball)

	anim_ball.force_inventory_mode = true
	anim_ball.custom_minimum_size = Vector2(128, 128)
	anim_ball.size = Vector2(128, 128)
	anim_ball.populate(null, visual_data, false, false)
	anim_ball.set_is_interactive(false)
	anim_ball.pivot_offset = anim_ball.size / 2.0
	anim_ball.global_position = start_center - anim_ball.pivot_offset

	var control_point := Vector2(
		(start_center.x + end_center.x) * 0.5,
		min(start_center.y, end_center.y) - 200.0
	)

	Audio.play_sfx("ui_drag_drop")

	var tween := anim_ball.create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_method(func(t: float):
		var eased_t := pow(t, 1.05)
		var inv_t := 1.0 - eased_t
		var pos := (inv_t * inv_t * start_center) \
			+ (2.0 * inv_t * eased_t * control_point) \
			+ (eased_t * eased_t * end_center)
		anim_ball.global_position = pos - anim_ball.pivot_offset
	, 0.0, 1.0, 0.45)

	await tween.finished
	anim_ball.queue_free()

	target_view.visible = true
	target_view.modulate.a = 1.0
	if target_view.has_method("play_landing_bounce"):
		target_view.play_landing_bounce()

func _on_open_inventory_pressed() -> void:
	if WindowManager.is_any_inspection_window_open():
		WindowManager.close_all_inspection_windows()
	else:
		SignalBus.emit_signal("inspect_inventory_requested")

func _on_leave_pressed() -> void:
	SignalBus.emit_signal("path_choice_scene_requested")
	queue_free()

func _on_gui_input(event: InputEvent) -> void:
	if _has_staged_transaction():
		return
	if InputUtils.is_primary_pointer_press(event):
		var context = InteractionContext.new()
		context.source_view_instance_id = get_instance_id()
		context.event_type = &"SINGLE_CLICK"
		context.location = null
		context.entity_uuid = ""
		context.entity_type = &"WINDOW_BACKGROUND"
		context.interaction_mode = &"FULLY_INTERACTIVE"
		context.window_group_id = 0
		SignalBus.emit_signal("interaction_context_received", context)
		get_viewport().set_input_as_handled()

func _on_choice_backdrop_gui_input(event: InputEvent) -> void:
	if _action_in_progress:
		get_viewport().set_input_as_handled()
		accept_event()
		return
	if InputUtils.is_primary_pointer_press(event):
		_cancel_staged_transaction(true)
		get_viewport().set_input_as_handled()
		accept_event()
