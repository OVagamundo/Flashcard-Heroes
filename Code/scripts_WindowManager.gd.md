<!-- Original: scripts/WindowManager.gd -->

```gdscript
# res://scripts/WindowManager.gd
extends Node

## Manages the entire lifecycle of all pop-up windows (Modals, Inspection).
## It is the single source of truth for window state, hierarchy, positioning,
## and universal closing logic, as per the TDD.

# --- Properties ---
var _open_windows: Array[Control] = []
var _window_scenes: Dictionary = {}
var _modal_layer: CanvasLayer = null

# --- Constants ---
const INSPECTION_WINDOW_MARGIN = 10.0

# --- Engine Methods ---
func _ready() -> void:
	# Preload all window scenes for fast instantiation.
	_window_scenes = {
		&"Inventory": preload("res://scenes/InventoryModal.tscn"),
		&"DiscardPile": preload("res://scenes/DiscardPileModal.tscn"),
		&"UnitInspection": preload("res://scenes/UnitInspectionModal.tscn"),
		&"ItemInspection": preload("res://scenes/ui/ItemInspectionWindow.tscn"),
		&"ChoicePrompt": preload("res://scenes/ChoicePromptUI.tscn"),
	}

	# Connect to EventBus signals that request windows.
	EventBus.inspect_inventory_requested.connect(_on_inspect_inventory_requested)
	EventBus.inspection_requested.connect(_on_inspection_requested)
	
	# Connect to signals that close windows.
	EventBus.close_modal_requested.connect(_close_topmost_window)
	EventBus.main_scene_requested.connect(_close_all_windows)
	EventBus.loadout_scene_requested.connect(_close_all_windows)


func _unhandled_input(event: InputEvent) -> void:
	if _open_windows.is_empty():
		return

	# Universal Escape key to close the topmost window.
	if event.is_action_pressed("ui_cancel"):
		_close_topmost_window()
		get_viewport().set_input_as_handled()
		return

	# Universal click-outside-to-close logic.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if InteractionManager.is_drag_active: return

		var click_pos = event.get_global_position()
		var is_click_inside_any_window: bool = false
		for window in _open_windows:
			if window.get_global_rect().has_point(click_pos):
				is_click_inside_any_window = true
				break
		
		if not is_click_inside_any_window:
			_close_all_windows()
			get_viewport().set_input_as_handled()


# --- Public Methods ---
func open_workspace_window(type: StringName, context_data: Dictionary = {}) -> void:
	if not _window_scenes.has(type):
		printerr("WindowManager: Tried to open unknown workspace window type: ", type)
		return

	# Workspace windows are modal; close everything else first.
	_close_all_windows()

	var window_instance = _window_scenes[type].instantiate()
	_get_modal_layer().add_child(window_instance)
	_open_windows.push_back(window_instance)

	if window_instance.has_method("populate"):
		window_instance.populate(context_data)


func open_inspection_window(source_view: Control) -> void:
	if not source_view is GachaBallView: return
	var instance_data = source_view.get_instance_data()
	if not instance_data: return
	var definition = Database.units.get(instance_data.definition_id, Database.items.get(instance_data.definition_id))
	if not definition: return

	var window_type = &"UnitInspection" if definition.category == &"UNIT" else &"ItemInspection"
	var window_instance = _window_scenes[window_type].instantiate()
	
	_get_modal_layer().add_child(window_instance)
	
	if window_instance.has_method("populate"):
		window_instance.populate({"source_view": source_view})

	# Must wait one frame for the container to resize based on content.
	await get_tree().process_frame
	
	window_instance.global_position = _calculate_window_position(source_view, window_instance)
	_open_windows.push_back(window_instance)


# --- Private Signal Handlers ---
func _on_inspect_inventory_requested():
	var context = {}
	if GameManager.run_state:
		context["inventory"] = GameManager.run_state.run_inventory
		context["title"] = "Run Inventory"
		context["is_interactive"] = true
		context["connect_to_refresh"] = true
		open_workspace_window(&"Inventory", context)


func _on_inspection_requested(source_view: Control):
	_close_inspection_windows()
	open_inspection_window(source_view)


# --- Private Helper Methods ---
func _calculate_window_position(source_view: Control, new_window: Control) -> Vector2:
	var viewport_rect = get_viewport().get_visible_rect()
	var source_rect = source_view.get_global_rect()
	var window_size = new_window.size

	var positions_to_try = [
		Vector2(source_rect.end.x + INSPECTION_WINDOW_MARGIN, source_rect.position.y), # Right
		Vector2(source_rect.position.x - window_size.x - INSPECTION_WINDOW_MARGIN, source_rect.position.y), # Left
		Vector2(source_rect.position.x, source_rect.end.y + INSPECTION_WINDOW_MARGIN), # Bottom
		Vector2(source_rect.position.x, source_rect.position.y - window_size.y - INSPECTION_WINDOW_MARGIN), # Top
	]

	for pos in positions_to_try:
		var window_rect = Rect2(pos, window_size)
		if viewport_rect.encloses(window_rect):
			return pos

	return Vector2(INSPECTION_WINDOW_MARGIN, INSPECTION_WINDOW_MARGIN)


func _get_modal_layer() -> CanvasLayer:
	if not is_instance_valid(_modal_layer):
		var nodes = get_tree().get_nodes_in_group("modal_layer")
		if not nodes.is_empty():
			_modal_layer = nodes[0]
		else:
			printerr("WindowManager: CRITICAL - No node found in group 'modal_layer'. Modals cannot be displayed.")
			_modal_layer = CanvasLayer.new()
			_modal_layer.layer = 128
			get_tree().root.add_child(_modal_layer)
	return _modal_layer


func _close_topmost_window() -> void:
	if not _open_windows.is_empty():
		var window = _open_windows.pop_back()
		if is_instance_valid(window):
			window.queue_free()


func _close_all_windows() -> void:
	for window in _open_windows:
		if is_instance_valid(window):
			window.queue_free()
	_open_windows.clear()


func _close_inspection_windows() -> void:
	var remaining_windows = []
	for window in _open_windows:
		var is_inspection = window is UnitInspectionModal or window is ItemInspectionWindow
		if is_inspection and is_instance_valid(window):
			window.queue_free()
		else:
			remaining_windows.append(window)
	_open_windows = remaining_windows

```