# scripts/WindowManager.gd
extends Node

# --- Constants and Preloads ---
const INSPECTION_WINDOW_MARGIN = 10.0

# --- Scene Definitions ---
var _window_scenes: Dictionary = {
	# Modal Windows
	&"Inventory": preload("res://scenes/InventoryModal.tscn"),
	&"DiscardPile": preload("res://scenes/DiscardPileModal.tscn"),
	&"ChoiceModal": preload("res://scenes/ChoiceModal.tscn"),
	# Non-Modal Inspection Windows
	&"UnitInspection": preload("res://scenes/UnitInspectionWindow.tscn"),	
	&"ItemInspection": preload("res://scenes/ItemInspectionWindow.tscn"),
	# We reuse ItemInspectionWindow for effects, the script will handle the difference.
	&"EffectInspection": preload("res://scenes/ItemInspectionWindow.tscn"),
}

# --- State ---
var _modal_stack: Array[Dictionary] = []
var _inspection_window_groups: Array[Array] = []
var _modal_layer: CanvasLayer = null

# --- Engine Callbacks ---
func _ready():
	EventBus.inspect_inventory_requested.connect(func(): open_workspace_window(&"Inventory"))
	EventBus.display_discard_pile_requested.connect(func(): open_workspace_window(&"DiscardPile"))
	# This signal is now only for ROOT inspections (from the bench, inventory modal, etc.)
	EventBus.inspection_requested.connect(_open_root_inspection_window)
	EventBus.main_scene_requested.connect(_close_all_windows)
	EventBus.loadout_scene_requested.connect(_close_all_windows)
	EventBus.close_modal_requested.connect(_close_top_modal)
	EventBus.background_clicked.connect(_on_background_blocker_clicked)
	EventBus.global_background_clicked.connect(_global_deselect_and_close_inspections)
	EventBus.selection_context_changed.connect(_on_selection_context_changed)

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if InteractionManager.is_drag_active():
			InteractionManager.cancel_active_drag()
		elif not _modal_stack.is_empty():
			_close_top_modal()
		elif not _inspection_window_groups.is_empty():
			close_all_inspection_windows()
		else:
			InteractionManager.clear_selection()
		return

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		if InteractionManager.is_drag_active():
			InteractionManager.cancel_active_drag()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and InteractionManager.is_drag_active():
			InteractionManager.cancel_active_drag()
			get_viewport().set_input_as_handled()

# --- Public Methods: Window Management ---

func _on_selection_context_changed(view: Control):
	var parent_info = _find_parent_group(view)
	if not parent_info.group:
		close_all_inspection_windows()

func handle_inspection_window_click(clicked_window: Control):
	var parent_info = _find_parent_group(clicked_window)
	if parent_info.group:
		var parent_group = parent_info.group
		var parent_index = parent_info.index
		while parent_group.size() > parent_index + 1:
			var window_to_close = parent_group.pop_back()
			if is_instance_valid(window_to_close):
				window_to_close.queue_free()

func open_workspace_window(type: StringName):
	if not _window_scenes.has(type): return
	_close_all_windows()
	var context = _get_workspace_context(type)
	_open_modal(type, context)

func open_dialog_window(type: StringName, context_data: Dictionary = {}):
	if not _window_scenes.has(type): return
	_open_modal(type, context_data)

# NEW: This handles clicks on items INSIDE another inspection window.
func open_grandchild_inspection_window(source_view: Control):
	if not source_view.has_method("get_instance_data"): return
	
	var instance_data = source_view.get_instance_data()
	if not instance_data: return
	
	var definition = instance_data.get_definition()
	if not definition: return
	
	var window_type = &"UnitInspection" if definition.category == &"UNIT" else &"ItemInspection"
	var window_instance = _window_scenes[window_type].instantiate()
	
	var parent_info = _find_parent_group(source_view)
	if not parent_info.group:
		# This shouldn't happen for a child view, but as a fallback, treat it as a root.
		_open_root_inspection_window(source_view)
		return

	# This is the "sibling replacement" logic.
	var parent_group = parent_info.group
	var parent_index = parent_info.index
	while parent_group.size() > parent_index + 1:
		var descendant_to_close = parent_group.pop_back()
		if is_instance_valid(descendant_to_close): descendant_to_close.queue_free()
	
	parent_group.push_back(window_instance)
	
	_get_modal_layer().add_child(window_instance)
	if window_instance.has_method("populate"):
		window_instance.populate({"source_view": source_view})
	
	await get_tree().process_frame
	
	var positioning_anchor = parent_info.group[parent_info.index]
	window_instance.global_position = _calculate_window_position(positioning_anchor, window_instance)

# NEW: This handles opening an "effect" from an item/unit description.
func open_child_inspection_window(parent_window: Control, window_type: StringName, context: Dictionary):
	if not _window_scenes.has(window_type): return
		
	var parent_info = _find_parent_group(parent_window)
	if not parent_info.group: return
	
	var parent_group = parent_info.group
	var parent_index = parent_info.index
	while parent_group.size() > parent_index + 1:
		var descendant_to_close = parent_group.pop_back()
		if is_instance_valid(descendant_to_close): descendant_to_close.queue_free()

	var window_instance = _window_scenes[window_type].instantiate()
	parent_group.push_back(window_instance)
	
	_get_modal_layer().add_child(window_instance)
	if window_instance.has_method("populate"):
		window_instance.populate(context)

	await get_tree().process_frame
	window_instance.global_position = _calculate_window_position(parent_window, window_instance)


# --- Private Helper Methods ---

# RENAMED and SIMPLIFIED: This now only handles root-level inspections.
func _open_root_inspection_window(source_view: Control):
	if not source_view.has_method("get_instance_data"): return
	
	var instance_data = source_view.get_instance_data()
	if not instance_data: return
	var definition = instance_data.get_definition()
	if not definition: return
	
	# Close ALL other inspection chains first.
	close_all_inspection_windows()
	
	var window_type = &"UnitInspection" if definition.category == &"UNIT" else &"ItemInspection"
	var window_instance = _window_scenes[window_type].instantiate()
	
	# Create a new group for this new root chain.
	var new_group: Array[Control] = [window_instance]
	_inspection_window_groups.push_back(new_group)
		
	_get_modal_layer().add_child(window_instance)
	if window_instance.has_method("populate"):
		window_instance.populate({"source_view": source_view})
	
	await get_tree().process_frame
	window_instance.global_position = _calculate_window_position(source_view, window_instance)


func _on_background_blocker_clicked():
	if not _modal_stack.is_empty():
		_close_top_modal()

func _close_top_modal():
	if not _modal_stack.is_empty():
		var entry = _modal_stack.pop_back()
		if is_instance_valid(entry.window):
			entry.window.queue_free()
		close_all_inspection_windows()

func _global_deselect_and_close_inspections():
	InteractionManager.clear_selection()
	close_all_inspection_windows()

func _open_modal(type: StringName, context: Dictionary):
	var window_instance = _window_scenes[type].instantiate()
	_get_modal_layer().add_child(window_instance)
	_modal_stack.push_back({"window": window_instance})
	
	if window_instance.has_method("populate"):
		window_instance.populate(context)

func _get_workspace_context(type: StringName) -> Dictionary:
	if type == &"Inventory":
		if GameManager.is_in_battle:
			var bm = get_tree().get_first_node_in_group("battle_manager")
			return {"inventory": bm.get_battle_inventory(), "title": "Battle Inventory", "is_interactive": true, "is_battle_context": true}
		else:
			return {"inventory": GameManager.run_state.run_inventory, "title": "Run Inventory", "is_interactive": true, "is_battle_context": false}
	elif type == &"DiscardPile":
		if GameManager.is_in_battle:
			var bm = get_tree().get_first_node_in_group("battle_manager")
			return {"discard_pile": bm.get_discard_pile()}
	return {}

func _find_parent_group(source_view: Control) -> Dictionary:
	var current_node = source_view
	while is_instance_valid(current_node) and not current_node is Window and current_node != get_tree().root:
		if current_node is Control:
			for group in _inspection_window_groups:
				var window_index = group.find(current_node)
				if window_index != -1:
					return {"group": group, "index": window_index}
		current_node = current_node.get_parent()
	return {"group": null, "index": -1}

func _calculate_window_position(source_view: Control, new_window: Control) -> Vector2:
	var viewport_rect = get_viewport().get_visible_rect()
	var source_rect = source_view.get_global_rect()
	var window_size = new_window.size
	
	var final_pos := Vector2.ZERO

	var positions_to_try = [
		func(): return Vector2(source_rect.end.x + INSPECTION_WINDOW_MARGIN, source_rect.position.y),
		func(): return Vector2(source_rect.position.x - window_size.x - INSPECTION_WINDOW_MARGIN, source_rect.position.y),
		func(): return Vector2(source_rect.position.x, source_rect.end.y + INSPECTION_WINDOW_MARGIN),
		func(): return Vector2(source_rect.position.x, source_rect.position.y - window_size.y - INSPECTION_WINDOW_MARGIN),
	]

	for get_pos in positions_to_try:
		var pos = get_pos.call()
		var window_rect = Rect2(pos, window_size)
		if viewport_rect.encloses(window_rect):
			return pos

	final_pos = positions_to_try[0].call()
	
	final_pos.x = clamp(final_pos.x, viewport_rect.position.x, viewport_rect.end.x - window_size.x)
	final_pos.y = clamp(final_pos.y, viewport_rect.position.y, viewport_rect.end.y - window_size.y)

	return final_pos

func _get_modal_layer() -> CanvasLayer:
	if not is_instance_valid(_modal_layer):
		var nodes = get_tree().get_nodes_in_group("modal_layer")
		if not nodes.is_empty(): _modal_layer = nodes[0]
		else:
			printerr("WindowManager: CRITICAL - No node in group 'modal_layer'.")
			_modal_layer = CanvasLayer.new()
			get_tree().root.add_child(_modal_layer)
	return _modal_layer

func close_all_inspection_windows() -> void:
	for group in _inspection_window_groups:
		for window in group:
			if is_instance_valid(window):
				window.queue_free()
	_inspection_window_groups.clear()

func _close_all_windows() -> void:
	while not _modal_stack.is_empty():
		var entry = _modal_stack.pop_back()
		if is_instance_valid(entry.window): entry.window.queue_free()
	close_all_inspection_windows()