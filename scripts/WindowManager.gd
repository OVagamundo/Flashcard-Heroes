# res://scripts/WindowManager.gd
extends Node

## Manages the entire lifecycle of all pop-up windows (Workspace and Inspection).
## It is the single source of truth for window state, hierarchy, and positioning.

# An array used as a stack to track the hierarchy of open windows.
var _open_windows: Array[Control] = []

# Preloads all window scenes for fast instantiation.
var _window_scenes: Dictionary = {
	"INVENTORY": preload("res://scenes/InventoryModal.tscn"),
	"DISCARD_PILE": preload("res://scenes/DiscardPileModal.tscn"),
	"UNIT_INSPECTION": preload("res://scenes/UnitInspectionModal.tscn"),
	"ITEM_INSPECTION": preload("res://scenes/ui/ItemInspectionWindow.tscn")
}


func _ready() -> void:
	# Connect to signals that request windows to be opened.
	EventBus.inspect_inventory_requested.connect(func(): open_workspace_window("INVENTORY", {}))
	EventBus.display_discard_pile_requested.connect(func(ctx): open_workspace_window("DISCARD_PILE", ctx))
	EventBus.inspection_requested.connect(_on_inspection_requested)


func _unhandled_input(event: InputEvent) -> void:
	# TDD 5.4: Universal Window Closing Logic
	if _open_windows.is_empty() or not event is InputEventMouseButton:
		return

	# We only care about pressed events that are not part of a drag.
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.is_pressed():
		return

	# Check if the click was outside the topmost window.
	var topmost_window: Control = _open_windows.back()
	if not topmost_window.get_global_rect().has_point(mouse_event.global_position):
		close_window(topmost_window)
		# Do not mark as handled, so clicks can fall through to the UI below.


func open_workspace_window(type: StringName, context_data: Dictionary) -> void:
	# TDD 3.7: Workspace windows are large, modal-like, and close others.
	close_all_windows()

	if not _window_scenes.has(type):
		printerr("WindowManager: Unknown workspace window type: ", type)
		return

	var window_instance: Control = _window_scenes[type].instantiate()
	_add_window_to_scene(window_instance, context_data)


func _on_inspection_requested(source_view: Control) -> void:
	# TDD 3.7 / 5.3: Handle the request to inspect a view.
	if not is_instance_valid(source_view) or not source_view is GachaBallView:
		return

	var gacha_view := source_view as GachaBallView
	var instance_data: GachaBallInstance = gacha_view.get_instance_data()
	if not instance_data:
		return

	# Determine if it's a Unit or an Item and open the correct window.
	var definition = Database.get_definition(instance_data.definition_id)
	if not definition:
		return

	var window_type: StringName
	match definition.category:
		"UNIT":
			window_type = "UNIT_INSPECTION"
		"ITEM":
			window_type = "ITEM_INSPECTION"
		_:
			return # Do not open a window for unknown categories.

	open_inspection_window(window_type, source_view)


func open_inspection_window(type: StringName, source_view: Control) -> void:
	# TDD 3.7: Inspection windows are smaller and context-sensitive.
	# For now, we will close all windows for simplicity.
	# The full TDD implementation would have more complex hierarchy logic.
	close_all_windows()

	if not _window_scenes.has(type):
		printerr("WindowManager: Unknown inspection window type: ", type)
		return

	var window_instance: Control = _window_scenes[type].instantiate()
	var context = {"source_view": source_view}
	_add_window_to_scene(window_instance, context)

	# TDD 3.7: Positioning logic would go here.
	# For now, we'll just center it.
	window_instance.set_anchors_and_offsets_preset(Control.PRESET_CENTER)


func _add_window_to_scene(window: Control, context: Dictionary) -> void:
	# The get_tree().root assumes Main.tscn is the root scene with a CanvasLayer.
	# This might need to be adjusted depending on the final scene structure.
	var ui_layer = get_tree().root.get_node_or_null("Main/UILayer")
	if not ui_layer:
		printerr("WindowManager: Could not find UILayer in Main scene!")
		# As a fallback, add to the root, but this is not ideal.
		get_tree().root.add_child(window)
	else:
		ui_layer.add_child(window)

	_open_windows.push_back(window)

	# If the window has a 'populate_data' function, call it.
	if window.has_method("populate_data"):
		window.call("populate_data", context)


func close_window(window: Control) -> void:
	if not is_instance_valid(window):
		return

	var index = _open_windows.find(window)
	if index != -1:
		_open_windows.remove_at(index)
	
	window.queue_free()


func close_all_windows() -> void:
	for window in _open_windows:
		window.queue_free()
	_open_windows.clear()
