<!-- Original: scripts/tests/TestWindowManager.gd -->

```gdscript
# res://scripts/tests/TestWindowManager.gd
extends Node
class_name TestWindowManager

const INSPECTION_WINDOW_MARGIN = 10.0
const TEST_INSPECTION_WINDOW_SCENE = preload("res://scenes/tests/TestInspectionWindow.tscn")

var _inspection_window_groups: Array[Array] = []
var _modal_layer: CanvasLayer

func initialize(modal_layer: CanvasLayer):
	_modal_layer = modal_layer
	EventBus.selection_context_changed.connect(_on_selection_context_changed)

func get_all_windows() -> Array[Control]:
	var all_windows: Array[Control] = []
	for group in _inspection_window_groups:
		all_windows.append_array(group)
	return all_windows

func open_inspection_window(source_view: Control) -> void:
	var item_data = source_view.get_meta("item_data")
	if not item_data: return

	var parent_info = _find_parent_group(source_view)
	
	# TDD Logic: If the source view is NOT part of an existing inspection window,
	# it's a new root request. Close everything else first.
	if not parent_info.group:
		close_all_inspection_windows()

	var window_instance = TEST_INSPECTION_WINDOW_SCENE.instantiate()
	window_instance.background_clicked.connect(handle_window_background_click)
	
	if parent_info.group:
		# This is a child inspection request. Add to the existing group.
		var parent_group = parent_info.group
		var parent_index = parent_info.index
		
		# Prune: Close all windows that are children of the clicked one's parent.
		while parent_group.size() > parent_index + 1:
			var descendant_to_close = parent_group.pop_back()
			if is_instance_valid(descendant_to_close): descendant_to_close.queue_free()
		parent_group.push_back(window_instance)
	else:
		# This is a new root inspection, so it starts a new group.
		var new_group: Array[Control] = [window_instance]
		_inspection_window_groups.push_back(new_group)
		
	_modal_layer.add_child(window_instance)
	window_instance.populate(item_data, self)
	
	# Wait for the window to get its size, then position it.
	await get_tree().process_frame
	window_instance.global_position = _calculate_window_position(source_view, window_instance)

func handle_window_background_click(clicked_window: Control):
	var parent_info = _find_parent_group(clicked_window)
	if parent_info.group:
		var parent_group = parent_info.group
		var parent_index = parent_info.index
		# Close all windows that are children of the clicked one.
		while parent_group.size() > parent_index + 1:
			var descendant_to_close = parent_group.pop_back()
			if is_instance_valid(descendant_to_close): descendant_to_close.queue_free()

func close_all_inspection_windows() -> void:
	for group in _inspection_window_groups:
		for window in group:
			if is_instance_valid(window):
				window.queue_free()
	_inspection_window_groups.clear()

func _find_parent_group(source_view: Control) -> Dictionary:
	var current_node = source_view
	# Ascend the tree until we hit a window or the root
	while is_instance_valid(current_node) and not current_node is Window and current_node != get_tree().root:
		# This guard prevents the 'find' method from being called with a non-Control node
		# (like a CanvasLayer), which was causing the type validation error.
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
	
	# Try right
	var pos_right = Vector2(source_rect.end.x + INSPECTION_WINDOW_MARGIN, source_rect.position.y)
	if viewport_rect.encloses(Rect2(pos_right, window_size)): return pos_right
	
	# Try left
	var pos_left = Vector2(source_rect.position.x - window_size.x - INSPECTION_WINDOW_MARGIN, source_rect.position.y)
	if viewport_rect.encloses(Rect2(pos_left, window_size)): return pos_left
	
	# Try below
	var pos_down = Vector2(source_rect.position.x, source_rect.end.y + INSPECTION_WINDOW_MARGIN)
	if viewport_rect.encloses(Rect2(pos_down, window_size)): return pos_down
	
	# Try above
	var pos_up = Vector2(source_rect.position.x, source_rect.position.y - window_size.y - INSPECTION_WINDOW_MARGIN)
	if viewport_rect.encloses(Rect2(pos_up, window_size)): return pos_up
	
	# Fallback to top-left corner
	return Vector2(INSPECTION_WINDOW_MARGIN, INSPECTION_WINDOW_MARGIN)

func _on_selection_context_changed(view: Control):
	# If the newly selected item is a "root" item (not part of an existing
	# inspection window chain), then close all open inspection windows.
	var parent_info = _find_parent_group(view)
	if not parent_info.group:
		close_all_inspection_windows()

```