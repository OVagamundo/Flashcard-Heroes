<!-- Original: scripts/WindowManager.gd -->

```gdscript
# res://scripts/WindowManager.gd
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
}

# --- State ---
var _modal_stack: Array[Dictionary] = []
# TDD: Each inner array is a hierarchical chain of inspection windows.
var _inspection_window_groups: Array[Array] = []
var _modal_layer: CanvasLayer = null

# --- Engine Callbacks ---
func _ready():
	EventBus.inspect_inventory_requested.connect(func(): open_workspace_window(&"Inventory"))
	EventBus.display_discard_pile_requested.connect(func(): open_workspace_window(&"DiscardPile"))
	EventBus.inspection_requested.connect(open_inspection_window)
	EventBus.main_scene_requested.connect(_close_all_windows)
	EventBus.loadout_scene_requested.connect(_close_all_windows)

	# Centralized input event handling
	EventBus.close_modal_requested.connect(_close_top_modal)
	EventBus.background_clicked.connect(_on_background_blocker_clicked)

func _unhandled_input(event: InputEvent) -> void:
	# TDD Rule 3.2.3: This is the final authority on unhandled input.

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		# Pressing Esc first cancels a drag, then closes a modal, then inspection windows, then deselects.
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
		# If a drag is active, any background click should cancel it and do nothing else.
		if InteractionManager.is_drag_active():
			InteractionManager.cancel_active_drag()
			get_viewport().set_input_as_handled()
			return

		var click_pos = event.global_position
		
		# 1. Is the click inside any modal window's content panel? If so, ignore.
		for entry in _modal_stack:
			var window = entry.get("window")
			if is_instance_valid(window) and window.get_node("PanelContainer").get_global_rect().has_point(click_pos):
				return # The modal's own logic or blocker will handle it.
		
		# 2. Is the click inside any inspection window? If so, ignore.
		for group in _inspection_window_groups:
			for window in group:
				if is_instance_valid(window) and window.get_global_rect().has_point(click_pos):
					return # The inspection window's own STOP filter will handle it.
		
		# 3. Is the click on the currently selected view? If so, ignore.
		var selected_view = InteractionManager.get_selected_view()
		if is_instance_valid(selected_view) and selected_view.get_global_rect().has_point(click_pos):
			return

		# 4. If all checks fail, it's a true background click.
		get_viewport().set_input_as_handled()
		_global_deselect_and_close_inspections()

# --- Public Methods: Window Management ---

func handle_inspection_window_click(clicked_window: Control):
	# TDD Rule 3.2.1.4: Hierarchical Pruning
	var parent_info = _find_parent_group(clicked_window)
	if parent_info.group:
		var parent_group = parent_info.group
		var parent_index = parent_info.index
		# Prune: Close all windows that are children of the clicked one.
		while parent_group.size() > parent_index + 1:
			var window_to_close = parent_group.pop_back()
			if is_instance_valid(window_to_close):
				window_to_close.queue_free()

func open_workspace_window(type: StringName) -> void:
	if not _window_scenes.has(type): return
	_close_all_windows()
	var context = _get_workspace_context(type)
	_open_modal(type, context)

func open_dialog_window(type: StringName, context_data: Dictionary = {}) -> void:
	if not _window_scenes.has(type): return
	# Dialogs like ChoiceModal should not close existing inspection windows
	# as they are part of the same action flow.
	_open_modal(type, context_data)

func open_inspection_window(source_view: Control) -> void:
	# Guard clause to ignore views not from the main game (e.g., TestItemView).
	# This allows the TestWindowManager to handle them without crashing the global manager.
	if not source_view.has_method("get_instance_data"): return
	
	var instance_data = source_view.get_instance_data()
	if not instance_data: return
	var definition = Database.units.get(instance_data.definition_id, Database.items.get(instance_data.definition_id))
	if not definition: return
	
	var window_type = &"UnitInspection" if definition.category == &"UNIT" else &"ItemInspection"
	var window_instance = _window_scenes[window_type].instantiate()
	
	var parent_info = _find_parent_group(source_view)

	# TDD Rule 3.2.1.3: Exclusive Inspection Chains
	if not parent_info.group:
		close_all_inspection_windows()

	if parent_info.group:
		var parent_group = parent_info.group
		var parent_index = parent_info.index
		while parent_group.size() > parent_index + 1:
			var descendant_to_close = parent_group.pop_back()
			if is_instance_valid(descendant_to_close): descendant_to_close.queue_free()
		# TDD Rule 3.2.1.3: Exclusive Inspection Chains - Add to existing group
		parent_group.push_back(window_instance)
	else:
		# TDD Rule 3.2.1.3: Exclusive Inspection Chains - Create new group
		close_all_inspection_windows() # Ensure no other inspection chains are open
		var new_group: Array[Control] = [window_instance]
		_inspection_window_groups.push_back(new_group)
		
	_get_modal_layer().add_child(window_instance)
	if window_instance.has_method("populate"):
		window_instance.populate({"source_view": source_view})
	
	await get_tree().process_frame
	window_instance.global_position = _calculate_window_position(source_view, window_instance)
	
# --- Private Helper Methods ---

func _on_background_blocker_clicked():
	if not _modal_stack.is_empty():
		_close_top_modal()

func _close_top_modal():
	if not _modal_stack.is_empty():
		var entry = _modal_stack.pop_back()
		if is_instance_valid(entry.window):
			entry.window.queue_free()
		# TDD Rule 3.2.1.5: Modal Context Cleanup
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
```