extends Control

const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")
const InputUtils = preload("res://scripts/InputUtils.gd")
const BLACK_MARKET_CONTAINER: StringName = &"BlackMarket"

var _controller: Node = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_controller(controller: Node) -> void:
	_controller = controller

func clear_staged_visual() -> void:
	for child in get_children():
		child.queue_free()

func show_staged_visual(visual_data: Dictionary) -> void:
	clear_staged_visual()
	if visual_data.is_empty():
		return

	var view = GachaBallViewScene.instantiate()
	add_child(view)
	if view.has_method("set_size_scale"):
		view.set_size_scale(1.0)
	view.custom_minimum_size = Vector2(96, 96)
	view.size = Vector2(96, 96)
	view.position = Vector2((size.x - 96.0) * 0.5, (size.y - 96.0) * 0.5)
	view.populate(null, visual_data, false, false)
	view.set_is_interactive(false)
	_recursively_set_mouse_ignore(view)

func _gui_input(event: InputEvent) -> void:
	if not InputUtils.is_primary_pointer_press(event):
		return
	get_viewport().set_input_as_handled()
	accept_event()
	if GlobalInteractionRouter.is_drag_active():
		return

	var context := InteractionContext.new()
	context.source_view_instance_id = get_instance_id()
	context.event_type = &"SINGLE_CLICK"
	context.location = LocationIdentifier.new(BLACK_MARKET_CONTAINER, 0)
	context.entity_uuid = ""
	context.entity_type = &"EMPTY_SLOT"
	context.interaction_mode = &"FULLY_INTERACTIVE"
	context.window_group_id = 1
	SignalBus.emit_signal("interaction_context_received", context)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has("source_loc")):
		return false
	if not is_instance_valid(_controller):
		return false
	if not _controller.has_method("can_accept_black_market_drop"):
		return false
	return _controller.can_accept_black_market_drop(data.source_loc)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary and data.has("source_loc")):
		return
	if not is_instance_valid(_controller):
		return

	var source_view: Control = GlobalInteractionRouter.get_drag_source_view()
	var handled := false
	if _controller.has_method("handle_black_market_drop"):
		handled = _controller.handle_black_market_drop(data.source_loc, source_view)

	GlobalInteractionRouter.end_drag(handled)

func _recursively_set_mouse_ignore(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_recursively_set_mouse_ignore(child)
