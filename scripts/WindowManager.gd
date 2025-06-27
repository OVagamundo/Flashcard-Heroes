# res://scripts/WindowManager.gd
extends Node

var _open_windows: Array[Control] = []
var _window_scenes: Dictionary = {}
var _modal_layer: CanvasLayer = null

const INSPECTION_WINDOW_MARGIN = 10.0

func _ready():
	_window_scenes = {
		&"Inventory": preload("res://scenes/InventoryModal.tscn"),
		&"DiscardPile": preload("res://scenes/DiscardPileModal.tscn"),
		&"UnitInspection": preload("res://scenes/UnitInspectionWindow.tscn"),
		&"ItemInspection": preload("res://scenes/ItemInspectionWindow.tscn"),
		&"ChoicePrompt": preload("res://scenes/ChoicePromptUI.tscn"),
	}
	EventBus.inspect_inventory_requested.connect(func(): open_workspace_window(&"Inventory"))
	EventBus.display_discard_pile_requested.connect(func(): open_workspace_window(&"DiscardPile"))
	EventBus.inspection_requested.connect(open_inspection_window)
	
	EventBus.close_modal_requested.connect(_close_topmost_window)
	EventBus.main_scene_requested.connect(_close_all_windows)
	EventBus.loadout_scene_requested.connect(_close_all_windows)

func _unhandled_input(event: InputEvent) -> void:
	if _open_windows.is_empty(): return
	if event.is_action_pressed("ui_cancel"):
		_close_topmost_window()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if InteractionManager.is_drag_active: return
		var click_pos = event.get_global_position()
		for i in range(_open_windows.size() - 1, -1, -1):
			var window = _open_windows[i]
			if not window.get_global_rect().has_point(click_pos):
				_close_window_at_index(i)
			else:
				return
		get_viewport().set_input_as_handled()

func open_workspace_window(type: StringName) -> void:
	if not _window_scenes.has(type): return
	_close_all_windows()
	
	var context = {}
	if type == &"Inventory":
		if GameManager.is_in_battle:
			var battle_manager = get_tree().get_first_node_in_group("battle_manager")
			context = {
				"inventory": battle_manager.get_battle_inventory(),
				"title": "Battle Inventory (Temporary)",
				"is_interactive": true, "is_battle_context": true
			}
		else:
			context = {
				"inventory": GameManager.run_state.run_inventory,
				"title": "Run Inventory",
				"is_interactive": true, "is_battle_context": false
			}
	elif type == &"DiscardPile":
		if GameManager.is_in_battle:
			var battle_manager = get_tree().get_first_node_in_group("battle_manager")
			context = {"discard_pile": battle_manager.get_discard_pile()}

	var window_instance = _window_scenes[type].instantiate()
	_get_modal_layer().add_child(window_instance)
	_open_windows.push_back(window_instance)
	if window_instance.has_method("populate"):
		window_instance.populate(context)

func open_dialog_window(type: StringName, context_data: Dictionary = {}) -> void:
	if not _window_scenes.has(type): return
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
	_close_inspection_windows()
	var window_type = &"UnitInspection" if definition.category == &"UNIT" else &"ItemInspection"
	var window_instance = _window_scenes[window_type].instantiate()
	_get_modal_layer().add_child(window_instance)
	if window_instance.has_method("populate"):
		window_instance.populate({"source_view": source_view})
	await get_tree().process_frame
	window_instance.global_position = _calculate_window_position(source_view, window_instance)
	_open_windows.push_back(window_instance)

func is_window_open(type: StringName) -> bool:
	if not _window_scenes.has(type): return false
	var scene_path = _window_scenes[type].resource_path
	for window in _open_windows:
		if window.scene_file_path == scene_path:
			return true
	return false

func _calculate_window_position(source_view: Control, new_window: Control) -> Vector2:
	var viewport_rect = get_viewport().get_visible_rect()
	var source_rect = source_view.get_global_rect()
	var window_size = new_window.size
	var positions = [
		Vector2(source_rect.end.x + INSPECTION_WINDOW_MARGIN, source_rect.position.y),
		Vector2(source_rect.position.x - window_size.x - INSPECTION_WINDOW_MARGIN, source_rect.position.y),
		Vector2(source_rect.position.x, source_rect.end.y + INSPECTION_WINDOW_MARGIN),
		Vector2(source_rect.position.x, source_rect.position.y - window_size.y - INSPECTION_WINDOW_MARGIN),
	]
	for pos in positions:
		if viewport_rect.encloses(Rect2(pos, window_size)): return pos
	return Vector2(INSPECTION_WINDOW_MARGIN, INSPECTION_WINDOW_MARGIN)

func _get_modal_layer() -> CanvasLayer:
	if not is_instance_valid(_modal_layer):
		var nodes = get_tree().get_nodes_in_group("modal_layer")
		if not nodes.is_empty(): _modal_layer = nodes[0]
		else:
			printerr("WindowManager: CRITICAL - No node in group 'modal_layer'.")
			_modal_layer = CanvasLayer.new()
			get_tree().root.add_child(_modal_layer)
	return _modal_layer

func _close_topmost_window() -> void:
	if not _open_windows.is_empty():
		var window = _open_windows.pop_back()
		if is_instance_valid(window): window.queue_free()

func _close_window_at_index(index: int) -> void:
	if index >= 0 and index < _open_windows.size():
		var window = _open_windows[index]
		_open_windows.remove_at(index)
		if is_instance_valid(window): window.queue_free()

func _close_all_windows() -> void:
	for window in _open_windows:
		if is_instance_valid(window): window.queue_free()
	_open_windows.clear()

func _close_inspection_windows() -> void:
	var i = _open_windows.size() - 1
	while i >= 0:
		var window = _open_windows[i]
		if window is UnitInspectionWindow or window is ItemInspectionWindow:
			_close_window_at_index(i)
		i -= 1
