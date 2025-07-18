<!-- Original: scripts/WindowManager.gd -->

```gdscript
# res://scripts/WindowManager.gd
extends Node


const INSPECTION_WINDOW_MARGIN = 10.0

# Using preload for scenes that are fundamental to the UI.
var _window_scenes: Dictionary = {
	# Modal Windows
	&"Inventory": preload("res://scenes/InventoryWindow.tscn"),
	&"DiscardPile": preload("res://scenes/DiscardPileWindow.tscn"),
	&"ChoiceWindow": preload("res://scenes/ChoiceWindow.tscn"),
	&"EndBattlePopup": preload("res://scenes/EndBattlePopup.tscn"),
	# Non-Modal Inspection Windows
	&"UnitInspection": preload("res://scenes/UnitInspectionWindow.tscn"),
	&"ItemInspection": preload("res://scenes/ItemInspectionWindow.tscn"),
	&"EffectInspection": preload("res://scenes/EffectInspectionWindow.tscn"),
}

var _modal_stack: Array[Control] = []
var _active_inspection_group: Array[Control] = [] # The single, active chain of inspection windows.
var _tracked_windows: Dictionary = {} # Stores info about tracked windows for cleanup.
var _modal_layer: CanvasLayer = null

func _ready():
	EventBus.inspect_inventory_requested.connect(_on_inspect_inventory_requested)
	EventBus.display_discard_pile_requested.connect(_on_display_discard_pile_requested)
	EventBus.inspection_requested.connect(_open_root_inspection_window)
	EventBus.close_modal_requested.connect(_close_top_modal)
	EventBus.background_clicked.connect(_on_background_blocker_clicked)
	EventBus.selection_changed.connect(_on_selection_changed)
	
	# Scene changes should close all windows
	EventBus.main_scene_requested.connect(_close_all_windows)
	EventBus.loadout_scene_requested.connect(_close_all_windows)
	EventBus.title_scene_requested.connect(_close_all_windows)

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if InteractionManager.is_drag_active():
			InteractionManager.cancel_active_drag()
		elif not _modal_stack.is_empty():
			_close_top_modal()
		elif not _active_inspection_group.is_empty():
			close_all_inspection_windows()
		else:
			InteractionManager.clear_selection()

# --- Public API ---



func open_dialog_window(type: StringName, context: Dictionary = {}):
	if not _window_scenes.has(type): return
	
	# Dialogs are stacked on top of the current modal, not replacing it.
	var window_instance = _window_scenes[type].instantiate()
	_get_modal_layer().add_child(window_instance)
	_modal_stack.push_back(window_instance)
	
	if window_instance.has_method("populate"):
		window_instance.populate(context)

func open_modal_window(type: StringName, context: Dictionary = {}):
	if not _window_scenes.has(type): 
		return
	
	# TDD Rule: General-purpose modals are exclusive. Close any active one first.
	_close_all_windows()

	var window_instance = _window_scenes[type].instantiate()
	_get_modal_layer().add_child(window_instance)
	_modal_stack.push_back(window_instance)
	
	if window_instance.has_method("populate"):
		window_instance.populate(context)

func open_end_battle_popup(is_victory: bool):
	open_modal_window(&"EndBattlePopup", {"is_victory": is_victory})

func _on_inspect_inventory_requested():
	var is_battle = GameManager.is_in_battle
	var inventory_data = {}
	var title = ""
	
	if is_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		if is_instance_valid(bm):
			inventory_data = bm.get_battle_inventory()
		title = "Battle Inventory"
	else:
		var run_state = GameManager.run_state
		if is_instance_valid(run_state):
			inventory_data = run_state.run_inventory_containers
		title = "Run Inventory"
	
	var context = {
		"inventory": inventory_data,
		"is_battle_context": is_battle,
		"title": title,
		"is_interactive": true
	}
	
	open_modal_window(&"Inventory", context)

func _on_display_discard_pile_requested():
	var is_battle = GameManager.is_in_battle
	var inventory_data = {}
	var title = "Discard Pile"
	
	if is_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		if is_instance_valid(bm):
			inventory_data = bm.get_discard_pile_inventory()
	else:
		var run_state = GameManager.run_state
		if is_instance_valid(run_state):
			inventory_data = run_state.discard_pile_containers
	
	var context = {
		"inventory": inventory_data,
		"is_battle_context": is_battle,
		"title": title,
		"is_interactive": true
	}
	
	open_modal_window(&"DiscardPile", context)

func handle_inspection_background_click(clicked_window: Control):
	var window_index = _active_inspection_group.find(clicked_window)
	if window_index == -1: return

	# Close all windows that are children of the clicked one.
	# TDD Rule: Clicking a window closes its descendants.
	var child_count = _active_inspection_group.size() - (window_index + 1)
	if child_count > 0:
		for i in range(child_count):
			var child_window = _active_inspection_group.pop_back()
			if is_instance_valid(child_window):
				child_window.queue_free()

func close_all_inspection_windows():
	for window in _active_inspection_group:
		if is_instance_valid(window):
			window.queue_free()
	_active_inspection_group.clear()

# --- Signal Handlers ---

func _on_background_blocker_clicked():
	if not _modal_stack.is_empty():
		var top_modal = _modal_stack.back()
		# Don't close the end battle popup by clicking the background
		if top_modal is EndBattlePopup:
			return
		_close_top_modal()




func _deferred_position_and_track(window_id: int, anchor_id: int, loc: LocationIdentifier = null):
	var window_instance = instance_from_id(window_id)
	var anchor = instance_from_id(anchor_id)
	
	if not is_instance_valid(window_instance) or not is_instance_valid(anchor):
		if is_instance_valid(window_instance):
			window_instance.queue_free()
		return

	window_instance.global_position = _calculate_window_position(anchor, window_instance)
	
	if is_instance_valid(loc):
		_track_inspection_anchor(window_instance, anchor, loc)

func open_child_inspection_window(parent_window: Control, window_type: StringName, context: Dictionary):
	if not _window_scenes.has(window_type):
		printerr("WindowManager: Window scene not found for type: %s" % window_type)
		return

	_close_children_of(parent_window)

	var window_instance = _window_scenes[window_type].instantiate()
	window_instance.set_as_top_level(true)
	_active_inspection_group.append(window_instance)
	parent_window.add_child(window_instance)
	_register_window(window_instance, false)

	if window_instance.has_method("populate"):
		window_instance.populate(context)

	# Use call_deferred to position the window on the next idle frame. This
	# guarantees the window has been added to the tree and its final size
	# has been calculated, solving the race condition robustly.
	window_instance.call_deferred("set_global_position", _calculate_window_position(parent_window, window_instance))

func _close_children_of(parent_window: Control):
	var parent_index = _find_window_in_group(parent_window)
	if parent_index == -1:
		return

	var child_count = _active_inspection_group.size() - (parent_index + 1)
	if child_count > 0:
		for i in range(child_count):
			var child_window = _active_inspection_group.pop_back()
			if is_instance_valid(child_window):
				# Child windows are not tracked, but good practice to call this anyway.
				stop_tracking_window(child_window)
				child_window.queue_free()


# Helper: find nearest ancestor that is in the active inspection group
func _find_ancestor_inspection_window(node: Node) -> Control:
	var current := node
	while is_instance_valid(current) and current != get_tree().root:
		if current is Control and _active_inspection_group.has(current):
			return current as Control
		current = current.get_parent()
	return null

# Determine the window type + context that would be produced for a root inspection request.
# Reuses a slimmed-down version of the logic in _open_inspection_window so we can
# reuse it for child requests too.
func _derive_window_payload(loc: LocationIdentifier, source_view: Control) -> Dictionary:
	var payload := {}
	var instance: GachaBallInstance
	var window_type: StringName
	var context: Dictionary

	if is_instance_valid(loc):
		instance = GameManager.get_instance_from_location(loc)
		if not is_instance_valid(instance):
			return {}
		var def = instance.get_definition()

		if def.category == &"UNIT":
			window_type = &"UnitInspection"
			context = {"source_view": source_view, "instance": instance, "location": loc}
		elif def.category == &"ITEM":
			window_type = &"ItemInspection"
			context = {"source_view": source_view, "instance": instance, "location": loc}
		else:
			return {}
	elif source_view.has_meta("effect_definition"):
		var effect_def = source_view.get_meta("effect_definition")
		if effect_def == null:
			return {}
		window_type = &"EffectInspection"
		context = {"source_view": source_view, "effect_definition": effect_def}
	else:
		return {}

	payload["window_type"] = window_type
	payload["context"] = context
	return payload

func _open_root_inspection_window(loc: LocationIdentifier, source_view: Control):
	var parent_window := _find_ancestor_inspection_window(source_view)
	if parent_window != null:
		var payload := _derive_window_payload(loc, source_view)
		if payload.is_empty():
			return
		open_child_inspection_window(parent_window, payload["window_type"], payload["context"])
		return
	
	close_all_inspection_windows()
	_open_inspection_window(loc, source_view)

func _on_selection_changed(new_location: LocationIdentifier):
	# If a new selection is made on a "root" view (not inside an inspection window),
	# close all existing inspection windows.
	if new_location != null:
		var source_view = find_view_by_location(new_location)
		if is_instance_valid(source_view):
			# If the new selection is NOT inside an existing inspection window group,
			# it's a "root" selection, so we clear out any old windows.
			if _find_window_in_group(source_view) == -1:
				close_all_inspection_windows()

# --- Private: Inspection Window Logic ---



func _open_inspection_window(loc: LocationIdentifier, source_view: Control):
	var window_type: StringName
	var context: Dictionary
	var instance: GachaBallInstance

	if is_instance_valid(loc):
		instance = GameManager.get_instance_from_location(loc)
		if not is_instance_valid(instance):
			return

		var def = instance.get_definition()
		window_type = &"UnitInspection" if def.category == &"UNIT" else &"ItemInspection"
		context = {"source_view": source_view, "instance": instance, "location": loc}

	elif source_view.has_meta("effect_definition"):
		var effect_def = source_view.get_meta("effect_definition")
		if effect_def == null: return

		window_type = &"EffectInspection"
		context = {"source_view": source_view, "effect_definition": effect_def}

	else:
		printerr("WindowManager: Inspection requested from an invalid source.")
		return
	
	var window_instance = _window_scenes[window_type].instantiate()
	
	_active_inspection_group.push_back(window_instance)
	_register_window(window_instance, false)
	_get_modal_layer().add_child(window_instance)
	
	if window_instance.has_method("populate"):
		window_instance.populate(context)
	
	# Use call_deferred for robust positioning.
	window_instance.call_deferred("set_global_position", _calculate_window_position(source_view, window_instance))
	
	# Dynamic tracking of the anchor as it moves or is replaced.
	# We can do this immediately; it doesn't need to be deferred.
	_track_inspection_anchor(window_instance, source_view, loc)




# --- Private: Helper Methods ---

func _track_inspection_anchor(window_instance: Control, anchor: Control, loc: LocationIdentifier) -> void:
	if not is_instance_valid(window_instance) or not is_instance_valid(anchor):
		return
	# Connect geometry change using bound callable (avoid capturing freed references)
	var geom_callable := Callable(self, "_on_inspection_anchor_moved").bind(window_instance, anchor)
	if not anchor.is_connected("item_rect_changed", geom_callable):
		anchor.item_rect_changed.connect(geom_callable, CONNECT_DEFERRED)
	# Connect anchor freed using bound callable. Pass the anchor itself so we can
	# disconnect its signals reliably when it's freed.
	var freed_callable := Callable(self, "_on_inspection_anchor_freed").bind(window_instance.get_instance_id(), anchor.get_instance_id(), loc, geom_callable)
	if not anchor.is_connected("tree_exited", freed_callable):
		anchor.tree_exited.connect(freed_callable, CONNECT_DEFERRED)

	_tracked_windows[window_instance] = {
		"anchor": anchor,
		"geom_callable": geom_callable,
		"freed_callable": freed_callable
	}

func stop_tracking_window(window_instance: Control) -> void:
	if not _tracked_windows.has(window_instance):
		return

	var tracking_info = _tracked_windows[window_instance]
	var anchor = tracking_info["anchor"]
	var geom_callable = tracking_info["geom_callable"]
	var freed_callable = tracking_info["freed_callable"]

	if is_instance_valid(anchor):
		if anchor.is_connected("item_rect_changed", geom_callable):
			anchor.item_rect_changed.disconnect(geom_callable)
		if anchor.is_connected("tree_exited", freed_callable):
			anchor.tree_exited.disconnect(freed_callable)
	
	_tracked_windows.erase(window_instance)

func _on_inspection_anchor_moved(window_instance: Control, anchor: Control) -> void:
	# Guard against operating on an object that was freed since the signal was emitted.
	if is_instance_valid(anchor) and is_instance_valid(window_instance):
		window_instance.global_position = _calculate_window_position(anchor, window_instance)

# --- Private: Window Lifecycle Helpers ---

func _register_window(window_instance: Control, is_modal: bool) -> void:
	# Track the window so we can remove dead references when it is freed.
	if not is_instance_valid(window_instance):
		return
	# Connect using instance_id instead of the node reference because the object
	# will already be freed when the signal is emitted. Passing a stale reference
	# causes the "Cannot convert argument" error seen in the logs.
	var freed_callable := Callable(self, "_on_window_freed").bind(window_instance.get_instance_id(), is_modal)
	if not window_instance.is_connected("tree_exited", freed_callable):
		window_instance.tree_exited.connect(freed_callable, CONNECT_DEFERRED)

func _on_window_freed(window_id: int, was_modal: bool) -> void:
	# This function is now robust against race conditions. It finds the window
	# to remove by its ID, which is always valid, instead of its object
	# reference, which might be stale.
	if was_modal:
		for i in range(_modal_stack.size() - 1, -1, -1):
			var window = _modal_stack[i]
			if not is_instance_valid(window) or window.get_instance_id() == window_id:
				_modal_stack.remove_at(i)
	else:
		for i in range(_active_inspection_group.size() - 1, -1, -1):
			var window = _active_inspection_group[i]
			if not is_instance_valid(window) or window.get_instance_id() == window_id:
				_active_inspection_group.remove_at(i)
		
		# We still need to call stop_tracking_window for the specific window
		# that was freed, if it can be found by ID.
		var window_instance = instance_from_id(window_id)
		if is_instance_valid(window_instance):
			stop_tracking_window(window_instance)



func _on_inspection_anchor_freed(window_instance_id: int, old_anchor_id: int, _loc: LocationIdentifier, geom_callable: Callable) -> void:
	var old_anchor = instance_from_id(old_anchor_id)
	var window_instance = instance_from_id(window_instance_id)

	# The old anchor is being freed. We MUST disconnect signals from it to prevent
	# deferred calls on an invalid object, which would cause a crash.
	if is_instance_valid(old_anchor):
		if old_anchor.is_connected("item_rect_changed", geom_callable):
			old_anchor.item_rect_changed.disconnect(geom_callable)
	
	# SAFE BEHAVIOR: If the anchor is gone, the inspection window is no longer
	# relevant and must be closed to prevent crashes and orphaned UI.
	if is_instance_valid(window_instance):
		window_instance.queue_free()


func _close_top_modal():
	if not _modal_stack.is_empty():
		var window = _modal_stack.pop_back()
		if is_instance_valid(window):
			window.queue_free()
		# Closing a modal should also close any inspections on top of it.
		close_all_inspection_windows()

func _close_all_windows():
	while not _modal_stack.is_empty():
		var window = _modal_stack.pop_back()
		if is_instance_valid(window):
			window.queue_free()
	close_all_inspection_windows()

func _find_window_in_group(control_node: Node) -> int:
	var current : Node = control_node
	while is_instance_valid(current) and current != get_tree().root:
		# Only attempt the lookup if the node is a Control; the typed array would
		# otherwise throw a validation error.
		if current is Control:
			for i in range(_active_inspection_group.size()):
				if _active_inspection_group[i] == current:
					return i
		current = current.get_parent()
	return -1

func _calculate_window_position(source_view: Control, new_window: Control) -> Vector2:
	# Guard against a freed source_view, which can happen in race conditions.
	if not is_instance_valid(source_view):
		return Vector2.ZERO # Or some other safe default

	var viewport_rect = get_viewport().get_visible_rect()
	# This is the canonical way to get the true, absolute on-screen position
	# of a Control node, correctly resolving all parent and viewport transforms.
	var source_pos = source_view.get_global_transform().origin
	var source_size = source_view.size
	var source_rect = Rect2(source_pos, source_size)
	var window_size = new_window.size
	
	# Prefer positioning to the RIGHT of the source. If there isn't enough room,
	# try LEFT, then BELOW, and finally ABOVE as a last resort. This follows the
	# user-requested priority and the TDD rule that the child must not overlap
	# its parent.
	var pos_right = Vector2(source_rect.end.x + INSPECTION_WINDOW_MARGIN, source_rect.position.y)
	if viewport_rect.encloses(Rect2(pos_right, window_size)):
		return pos_right

	var pos_left = Vector2(source_rect.position.x - window_size.x - INSPECTION_WINDOW_MARGIN, source_rect.position.y)
	if viewport_rect.encloses(Rect2(pos_left, window_size)):
		return pos_left

	var pos_down = Vector2(source_rect.position.x, source_rect.end.y + INSPECTION_WINDOW_MARGIN)
	if viewport_rect.encloses(Rect2(pos_down, window_size)):
		return pos_down

	var pos_up = Vector2(source_rect.position.x, source_rect.position.y - window_size.y - INSPECTION_WINDOW_MARGIN)
	if viewport_rect.encloses(Rect2(pos_up, window_size)):
		return pos_up
	
	return Vector2(INSPECTION_WINDOW_MARGIN, INSPECTION_WINDOW_MARGIN)

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.button_index == MOUSE_BUTTON_LEFT or not event.is_pressed():
		return

	if not _active_inspection_group.is_empty():
		var click_is_inside_a_window = false
		for window in _active_inspection_group:
			if is_instance_valid(window) and window.get_global_rect().has_point(event.position):
				click_is_inside_a_window = true
				break
		
		if not click_is_inside_a_window:
			close_all_inspection_windows()
			# We DO NOT consume the input here, allowing it to "click through".


func find_view_by_location(loc: LocationIdentifier) -> Control:
	if not is_instance_valid(loc):
		return null
	
	# 1) Search inside the top-most modal window (if any).
	if not _modal_stack.is_empty():
		var top_modal = _modal_stack.back()
		# Defensive check: Ensure the node is valid before searching inside it.
		if is_instance_valid(top_modal):
			var found = _find_view_in_node(top_modal, loc)
			if is_instance_valid(found):
				return found
	
	# 2) Search inside the currently active inspection window chain (root first).
	if not _active_inspection_group.is_empty():
		# Iterate over a copy in case the array is modified during the search.
		for window in _active_inspection_group.duplicate():
			# Defensive check: Ensure the node is valid before searching inside it.
			if is_instance_valid(window):
				var found = _find_view_in_node(window, loc)
				if is_instance_valid(found):
					return found
	
	# 3) As a last resort, search the main scene content. This is necessary
	# for finding root-level views like those on the battle board.
	var main_scene = get_tree().root.find_child("Main", true, false)
	if is_instance_valid(main_scene):
		var content_holder = main_scene.get_node_or_null("VBoxContainer/ContentArea/SubViewport/MarginContainer")
		if is_instance_valid(content_holder):
			var found = _find_view_in_node(content_holder, loc)
			if is_instance_valid(found):
				return found

	return null

func _find_view_in_node(node: Node, loc: LocationIdentifier) -> Control:
	if node.has_meta("location_identifier"):
		var node_loc = node.get_meta("location_identifier")
		if node_loc.is_equal(loc):
			return node
	
	for child in node.get_children():
		var found = _find_view_in_node(child, loc)
		if is_instance_valid(found):
			return found
	
	return null

func _get_modal_layer() -> CanvasLayer:
	if not is_instance_valid(_modal_layer):
		var nodes = get_tree().get_nodes_in_group("modal_layer")
		if not nodes.is_empty(): _modal_layer = nodes[0]
		else:
			printerr("WindowManager: CRITICAL - No node in group 'modal_layer'.")
			_modal_layer = CanvasLayer.new()
			get_tree().root.add_child(_modal_layer)
	return _modal_layer

```