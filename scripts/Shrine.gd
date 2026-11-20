# res://scripts/Shrine.gd
extends EncounterBase

const BASE_REMOVE_COST: int = 5

@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var open_inventory_button: Button = %OpenInventoryButton
@onready var leave_button: Button = %LeaveButton

var _action_in_progress: bool = false


func _ready() -> void:
	add_to_group("shrine_controller")
	open_inventory_button.pressed.connect(_toggle_run_inventory)
	leave_button.pressed.connect(_on_leave_pressed)
	gui_input.connect(_handle_inventory_encounter_background_click)
	SignalBus.locale_changed.connect(_update_localized_text)
	SignalBus.action_drop_zone_2_activated.connect(_on_remove_requested)
	SignalBus.action_drop_zone_1_activated.connect(_on_transform_requested)
	_update_localized_text()
	set_process(true)


func _exit_tree() -> void:
	if SignalBus.locale_changed.is_connected(_update_localized_text):
		SignalBus.locale_changed.disconnect(_update_localized_text)
	if SignalBus.action_drop_zone_2_activated.is_connected(_on_remove_requested):
		SignalBus.action_drop_zone_2_activated.disconnect(_on_remove_requested)
	if SignalBus.action_drop_zone_1_activated.is_connected(_on_transform_requested):
		SignalBus.action_drop_zone_1_activated.disconnect(_on_transform_requested)
	var main_node: Node = GameManager._active_main_node
	if is_instance_valid(main_node):
		main_node.hide_action_instruction()
		main_node.hide_split_action_drop_zones()


func _process(_delta: float) -> void:
	var is_open: bool = WindowManager.is_run_inventory_window_open()
	if is_open != _last_inventory_open:
		_last_inventory_open = is_open
		var main_node: Node = GameManager._active_main_node
		if is_instance_valid(main_node):
			if is_open:
				_refresh_shrine_drop_zone_texts(main_node)
				main_node.show_action_instruction()
			else:
				main_node.hide_action_instruction()
				main_node.hide_split_action_drop_zones()


func _refresh_shrine_drop_zone_texts(main_node: Node) -> void:
	var transform_text: String = tr("ui.shrine_drop_transform").format({"cost": str(GameManager.get_shrine_transform_cost())})
	var remove_text: String = tr("ui.shrine_drop_remove").format({"cost": str(_get_remove_cost())})
	main_node.set_action_zone_texts(transform_text, remove_text)


func _update_localized_text() -> void:
	title_label.text = tr("ui.shrine_title")
	if is_instance_valid(description_label):
		description_label.text = tr("ui.shrine_desc")
	open_inventory_button.text = tr("ui.shrine_open_inventory")
	leave_button.text = tr("ui.leave")


func _get_remove_cost() -> int:
	if is_instance_valid(GameManager.run_state):
		return GameManager.run_state.get_shrine_remove_cost()
	return BASE_REMOVE_COST


func _play_zone_gold_rejection(zone_index: int) -> void:
	var main_node: Node = GameManager._active_main_node
	var gold_group: Control = main_node.get_node_or_null("%GoldGroup") as Control if is_instance_valid(main_node) else null
	var zone: Control = null
	if is_instance_valid(main_node):
		zone = main_node.get_action_zone_1() if zone_index == 1 else main_node.get_action_zone_2()
	var target: Control = zone if is_instance_valid(zone) else open_inventory_button
	RejectionFeedbackScript.play_rejection_with_counter(target, gold_group, get_tree())


func _on_remove_requested(is_drag: bool = false, mouse_pos: Vector2 = Vector2.ZERO) -> void:
	if _action_in_progress:
		return
	var item_data: Dictionary = _get_selected_run_inventory_entry(false)
	if item_data.is_empty():
		return
	var cost: int = _get_remove_cost()
	var drop: Dictionary = _resolve_drop_interaction(is_drag, mouse_pos)
	var drop_pos: Vector2 = drop["drop_pos"]
	var action := RemoveShrineAction.new(item_data["uuid"], cost, drop["interaction_type"], drop_pos)
	if not ActionQueue.request(action):
		_play_zone_gold_rejection(2)
		if is_drag:
			ActionQueue.request(CancelDragAction.new(item_data["location"], null, "insufficient_gold", drop_pos))
		else:
			GlobalInteractionRouter.apply_deselect_entity()


func execute_remove_visuals(target_uuid: String, cost: int, p_drop_pos: Vector2 = Vector2.ZERO) -> void:
	var item_data: Dictionary = _resolve_run_inventory_entry_by_uuid(target_uuid, false)
	if item_data.is_empty():
		_finish_active_action()
		return

	if not is_instance_valid(GameManager.run_state) or GameManager.run_state.gold < cost:
		_play_zone_gold_rejection(2)
		_finish_active_action()
		return

	_action_in_progress = true
	var source_location: LocationIdentifier = item_data["location"] as LocationIdentifier
	var source_anchor: Control = WindowManager.find_view_for_location(source_location) as Control
	var fallback_pos: Vector2 = source_anchor.get_global_rect().get_center() if is_instance_valid(source_anchor) else Vector2.ZERO
	var interaction_pos: Vector2 = _consume_animation_start_pos(fallback_pos, p_drop_pos)

	if is_instance_valid(source_anchor):
		for child in source_anchor.get_children():
			if child is GachaBallView:
				(child as GachaBallView).modulate.a = 0.0
				(child as GachaBallView).visible = false

	var vfx_ball: GachaBallView = _spawn_static_vfx_gachaball(VisualDataAdapter.create_visual_data(item_data["instance"]), interaction_pos)
	var main_node: Node = GameManager._active_main_node

	CurrencyAnimator.animate_gold_spend(cost, interaction_pos, func() -> void:
		SignalBus.shrine_action_requested.emit({
			"type": "remove",
			"cost": cost,
			"instance_uuid": item_data["uuid"],
		})
		_animate_gachaball_removal_vfx(vfx_ball)

		if is_instance_valid(main_node):
			_refresh_shrine_drop_zone_texts(main_node)
			main_node.show_split_action_drop_zones()
			SignalBus.selection_clear_requested.emit()
			Audio.play_sfx("ui_drag_drop")

		_action_in_progress = false
		_finish_active_action()
	)


func _on_transform_requested(is_drag: bool = false, mouse_pos: Vector2 = Vector2.ZERO) -> void:
	if _action_in_progress:
		return
	var item_data: Dictionary = _get_selected_run_inventory_entry(false)
	if item_data.is_empty():
		return
	var transform_cost: int = GameManager.get_shrine_transform_cost()
	var drop: Dictionary = _resolve_drop_interaction(is_drag, mouse_pos)
	var drop_pos: Vector2 = drop["drop_pos"]
	var action := TransformShrineAction.new(item_data["uuid"], transform_cost, drop["interaction_type"], drop_pos)
	if not ActionQueue.request(action):
		_play_zone_gold_rejection(1)
		if is_drag:
			ActionQueue.request(CancelDragAction.new(item_data["location"], null, "insufficient_gold", drop_pos))
		else:
			GlobalInteractionRouter.apply_deselect_entity()


func execute_transform_visuals(target_uuid: String, cost: int, p_drop_pos: Vector2 = Vector2.ZERO) -> void:
	var item_data: Dictionary = _resolve_run_inventory_entry_by_uuid(target_uuid, false)
	if item_data.is_empty():
		_finish_active_action()
		return

	var source_definition: Resource = item_data["definition"] as Resource
	var source_location: LocationIdentifier = item_data["location"] as LocationIdentifier
	var result_definition: GachaBallDefinition = GameManager.get_transform_result(source_definition)
	if not is_instance_valid(result_definition):
		_finish_active_action()
		return

	if not is_instance_valid(GameManager.run_state) or GameManager.run_state.gold < cost:
		_play_zone_gold_rejection(1)
		_finish_active_action()
		return

	_action_in_progress = true
	var target_slot_view: Control = WindowManager.find_view_for_location(source_location) as Control
	var fallback_pos: Vector2 = target_slot_view.get_global_rect().get_center() if is_instance_valid(target_slot_view) else Vector2.ZERO
	var interaction_pos: Vector2 = _consume_animation_start_pos(fallback_pos, p_drop_pos)

	if is_instance_valid(target_slot_view):
		target_slot_view.modulate.a = 0.0

	SignalBus.hide_slot_indicators.emit()
	SignalBus.selection_clear_requested.emit()

	var source_inst: GachaBallInstance = item_data["instance"] as GachaBallInstance
	var vfx_ball: GachaBallView = _spawn_static_vfx_gachaball(VisualDataAdapter.create_visual_data(source_inst), interaction_pos)

	CurrencyAnimator.animate_gold_spend(cost, interaction_pos, func() -> void:
		SignalBus.shrine_action_requested.emit({
			"type": "transform",
			"cost": cost,
			"instance_uuid": item_data["uuid"],
			"source_location": source_location,
			"result_definition": result_definition,
			"source_level": source_inst.level,
		})

		var temp_new_instance := GachaBallInstance.new()
		temp_new_instance.initialize(result_definition)
		var new_visual_data: Dictionary = VisualDataAdapter.create_visual_data(temp_new_instance)
		if is_instance_valid(vfx_ball):
			vfx_ball.populate(null, new_visual_data, false)

		var target_view: Control = await _prepare_transform_target_view(source_location)
		if interaction_pos != Vector2.ZERO and is_instance_valid(target_view):
			await _animate_vfx_ball_to_slot(vfx_ball, interaction_pos, target_view, 1.05)
		else:
			if is_instance_valid(vfx_ball):
				vfx_ball.queue_free()
			if is_instance_valid(target_view):
				target_view.visible = true
				target_view.modulate.a = 1.0
				var fallback_ball: GachaBallView = _resolve_ball_view(target_view)
				if is_instance_valid(fallback_ball):
					fallback_ball.play_landing_bounce()

		_action_in_progress = false
		_finish_active_action()
	)


func _prepare_transform_target_view(target_location: LocationIdentifier) -> Control:
	await get_tree().process_frame
	var target_anchor: Control = WindowManager.find_view_for_location(target_location) as Control
	var target_ball_view: GachaBallView = _resolve_ball_view(target_anchor)
	if is_instance_valid(target_ball_view):
		target_ball_view.modulate.a = 0.0
	return target_anchor


func _animate_gachaball_removal_vfx(vfx_ball: GachaBallView) -> void:
	if not is_instance_valid(vfx_ball):
		return
	var duration: float = 0.6
	var tween: Tween = vfx_ball.create_tween()
	tween.set_parallel(true)
	tween.tween_property(vfx_ball, "position", vfx_ball.position + Vector2(0.0, -100.0), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(vfx_ball, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(vfx_ball.queue_free)


func _on_leave_pressed() -> void:
	ActionQueue.request(LeaveShrineAction.new())


func execute_leave_visuals() -> void:
	var main_node: Node = GameManager._active_main_node
	if is_instance_valid(main_node):
		main_node.hide_action_instruction()
		main_node.hide_split_action_drop_zones()
	SignalBus.path_choice_scene_requested.emit()
	queue_free()
