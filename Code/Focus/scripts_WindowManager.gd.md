<!-- Original: scripts/WindowManager.gd -->

```gdscript
# res://scripts/WindowManager.gd
extends Node


const INSPECTION_WINDOW_MARGIN = 20.0

# Using load for scenes to avoid circular preload dependencies.
var _window_scenes: Dictionary = {
	# Modal Windows
	&"Inventory": load("res://scenes/InventoryWindow.tscn"),
	&"DiscardPile": load("res://scenes/DiscardPileWindow.tscn"),
	&"ChoiceWindow": load("res://scenes/ChoiceWindow.tscn"),
	&"EndBattlePopup": load("res://scenes/EndBattlePopup.tscn"),
	&"FlashcardMinigame": load("res://scenes/FlashcardMinigame.tscn"),
	&"ResultsPopup": load("res://scenes/ResultsPopup.tscn"),
	# Non-Modal Inspection Windows
	&"UnitInspection": load("res://scenes/UnitInspectionWindow.tscn"),
	&"ItemInspection": load("res://scenes/ItemInspectionWindow.tscn"),
	&"EffectInspection": load("res://scenes/EffectInspectionWindow.tscn"),
}

var _modal_stack: Array[Control] = []
var _active_inspection_group: Array[Control] = [] # The single, active chain of inspection windows.
var _tracked_windows: Dictionary = {} # Stores info about tracked windows for cleanup.
var _modal_layer: CanvasLayer = null

# Enhanced tracking for better window management
var _window_hierarchy: Dictionary = {} # Maps window instance IDs to their parent/child relationships
var _window_group_registry: Dictionary = {} # Maps window group IDs to window lists
var _instance_id_to_window: Dictionary = {} # Maps instance IDs to window references for quick lookup
var _cleanup_timer: Timer = null # Timer for proactive cleanup

func _ready():
	# Ensure this node can process input events
	set_process_input(true)
	print("WindowManager: _ready called, input processing enabled")
	
	# Initialize cleanup timer for proactive cleanup
	_cleanup_timer = Timer.new()
	_cleanup_timer.wait_time = 5.0  # Run cleanup every 5 seconds
	_cleanup_timer.timeout.connect(_proactive_cleanup)
	add_child(_cleanup_timer)
	_cleanup_timer.start()
	
	EventBus.inspect_inventory_requested.connect(_on_inspect_inventory_requested)
	EventBus.display_discard_pile_requested.connect(_on_display_discard_pile_requested)
	EventBus.inspection_requested.connect(_open_root_inspection_window)
	EventBus.close_modal_requested.connect(_close_top_modal)
	EventBus.background_clicked.connect(_on_background_blocker_clicked)
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.battle_state_changed.connect(_on_battle_state_changed)
	EventBus.path_choice_scene_requested.connect(_on_path_choice_scene_requested)
	
	# Scene changes should close all windows
	EventBus.main_scene_requested.connect(_close_all_windows)
	EventBus.loadout_scene_requested.connect(_close_all_windows)
	EventBus.title_scene_requested.connect(_close_all_windows)

func _input(event: InputEvent):
	_cleanup_invalid_windows()
	
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if InteractionManager.is_drag_active():
			InteractionManager.cancel_active_drag()
		elif not _modal_stack.is_empty():
			_close_top_modal()
		elif not _active_inspection_group.is_empty():
			close_all_inspection_windows()
		else:
			EventBus.emit_signal("selection_clear_requested")
		return
	
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()):
		return

	# If a modal is open, its blocker handles input. The global handler does nothing.
	if not _modal_stack.is_empty():
		return

	# If no inspection windows are open, there's nothing for this handler to do.
	if _active_inspection_group.is_empty():
		return

	# --- THE DEFINITIVE INPUT ROUTER ---
	var top_most_clicked_window: Control = null
	# Iterate in reverse (from top-most to bottom-most) to find which window was clicked.
	for i in range(_active_inspection_group.size() - 1, -1, -1):
		var window = _active_inspection_group[i]
		if is_instance_valid(window) and window.get_global_rect().has_point(event.position):
			top_most_clicked_window = window
			break

	if top_most_clicked_window:
		# A click inside an inspection window. Let the window handle it internally.
		# The inspection windows have their own _gui_input handlers for background clicks.
		# We don't interfere here - let the window's internal logic handle it.
		return
	else:
		# The click was not inside ANY open inspection window.
		# This is a "true" global background click. Close everything.
		close_all_inspection_windows()
		# We DO NOT consume the event here, allowing it to "click-through" to
		# select another unit, as per the TDD.

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
		return null
	
	# TDD Rule: General-purpose modals are exclusive. Close any active one first.
	_close_all_windows()

	# Clear any active selection when opening a major modal view.
	EventBus.emit_signal("selection_clear_requested")

	var window_instance = _window_scenes[type].instantiate()
	_get_modal_layer().add_child(window_instance)
	_modal_stack.push_back(window_instance)
	
	# Enhanced registration with group ID 0 (main windows)
	_register_window_enhanced(window_instance, true, 0)
	
	if window_instance.has_method("populate"):
		window_instance.populate(context)
	
	return window_instance

func open_end_battle_popup(is_victory: bool):
	open_modal_window(&"EndBattlePopup", {"is_victory": is_victory})

func _on_inspect_inventory_requested():
	EventBus.emit_signal("selection_clear_requested")
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
			inventory_data = run_state.get_run_inventory_containers()
		title = "Run Inventory"
	
	var context = {
		"inventory": inventory_data,
		"is_battle_context": is_battle,
		"title": title,
		"is_interactive": true
	}
	
	open_modal_window(&"Inventory", context)

func _on_display_discard_pile_requested():
	EventBus.emit_signal("selection_clear_requested")
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

	# TDD Rule: Clicking a window closes its descendants.
	var child_count = _active_inspection_group.size() - (window_index + 1)
	if child_count > 0:
		for i in range(child_count):
			var child_window = _active_inspection_group.pop_back()
			if is_instance_valid(child_window):
				child_window.queue_free()
	
	# After handling window closure, clear any active selection.
	# This prevents the race condition and ensures consistent state.
	EventBus.emit_signal("selection_clear_requested")

func close_all_inspection_windows():
	print("WindowManager: Closing all inspection windows. Count: ", _active_inspection_group.size())
	
	# First, clean up any invalid windows
	_cleanup_invalid_windows()
	
	for window in _active_inspection_group:
		if is_instance_valid(window):
			# Clean up tracking data before freeing the window
			stop_tracking_window(window.get_instance_id())
			window.queue_free()
	_active_inspection_group.clear()
	print("WindowManager: All inspection windows closed. Tracking data count: ", _tracked_windows.size())

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
	# TDD 4.3.II: This rule applies to all inspection windows, root or child.
	EventBus.emit_signal("selection_clear_requested")

	if not _window_scenes.has(window_type):
		printerr("WindowManager: Window scene not found for type: %s" % window_type)
		return

	_close_children_of(parent_window)

	var window_instance = _window_scenes[window_type].instantiate()
	_active_inspection_group.append(window_instance)
	# REVERTED: Children MUST be added to the global modal layer to render correctly.
	_get_modal_layer().add_child(window_instance)
	_register_window(window_instance, false)

	if window_instance.has_method("populate"):
		window_instance.populate(context)

	# Position the child window in global coordinates relative to its parent
	# This ensures proper positioning without overlapping
	# Use call_deferred to ensure the window is fully set up before positioning
	window_instance.call_deferred("_position_child_window", parent_window)

func _close_children_of(parent_window: Control):
	var parent_index = find_window_in_group(parent_window)
	if parent_index == -1:
		return

	var child_count = _active_inspection_group.size() - (parent_index + 1)
	if child_count > 0:
		for i in range(child_count):
			var child_window = _active_inspection_group.pop_back()
			if is_instance_valid(child_window):
				# The window is about to be freed. We must stop tracking it by its ID.
				stop_tracking_window(child_window.get_instance_id())
				child_window.queue_free()


# Helper: find nearest ancestor that is in the active inspection group
func _find_ancestor_inspection_window(node: Node) -> Control:
	var current := node.get_parent() # Start search from the parent
	while is_instance_valid(current) and current != get_tree().root:
		if current is InspectionWindow and _active_inspection_group.has(current):
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
	# TDD 4.3.II: "Opening any inspection window immediately clears the active selection."
	EventBus.emit_signal("selection_clear_requested")

	# Check if a window already exists for this location
	for window in _active_inspection_group:
		# Check if the window has a location and if it matches.
		if is_instance_valid(window) and window.has_method("get_location"):
			var window_loc = window.get_location()
			if is_instance_valid(window_loc) and window_loc.is_equal(loc):
				# Window already exists for this location, don't create another one
				return
	
	var parent_window := _find_ancestor_inspection_window(source_view)
	if parent_window != null:
		var payload := _derive_window_payload(loc, source_view)
		if payload.is_empty():
			return
		open_child_inspection_window(parent_window, payload["window_type"], payload["context"])
		return
	
	_open_inspection_window(loc, source_view)

func _on_selection_changed(new_location: LocationIdentifier):
	# If a new selection is made on a "root" view (not inside an inspection window),
	# close all existing inspection windows.
	if new_location != null:
		var source_view = find_view_by_location(new_location)
		if is_instance_valid(source_view):
			# If the new selection is NOT inside an existing inspection window group,
			# it's a "root" selection, so we clear out any old windows.
			if find_window_in_group(source_view) == -1:
				close_all_inspection_windows()

func _on_battle_state_changed(is_in_battle: bool):
	# When battle ends (is_in_battle becomes false), close all inspection windows
	# because their anchors (battle UI elements) are about to be destroyed
	if not is_in_battle:
		print("WindowManager: Battle ended, closing all inspection windows. Active group size: ", _active_inspection_group.size())
		# Use call_deferred to ensure proper cleanup order
		call_deferred("close_all_inspection_windows")
	else:
		print("WindowManager: Battle started. Active group size: ", _active_inspection_group.size())

func _on_path_choice_scene_requested():
	# When transitioning to path choice (after reward scene), close all inspection windows
	# because the reward scene is about to be destroyed
	print("WindowManager: Path choice requested, closing all inspection windows")
	close_all_inspection_windows()

func _cleanup_invalid_windows():
	# Remove any invalid windows from the active inspection group
	var i = 0
	while i < _active_inspection_group.size():
		var window = _active_inspection_group[i]
		if not is_instance_valid(window):
			print("WindowManager: Removing invalid window from active group")
			_active_inspection_group.remove_at(i)
			# Don't increment i since we removed an element
		else:
			i += 1
	
	# Remove any invalid windows from the modal stack
	i = 0
	while i < _modal_stack.size():
		var modal = _modal_stack[i]
		if not is_instance_valid(modal):
			print("WindowManager: Removing invalid modal from modal stack")
			_modal_stack.remove_at(i)
			# Don't increment i since we removed an element
		else:
			i += 1

# --- Private: Inspection Window Logic ---



func _open_inspection_window(loc: LocationIdentifier, source_view: Control):
	print("WindowManager: Opening inspection window for location: ", loc.container, " [", loc.index, "]")
	
	# TDD Rule: Single Active Group - Close entire previous group when opening new root-level window
	# Check if the source view is NOT part of an existing inspection window group
	if find_window_in_group(source_view) == -1:
		# This is a new root-level window, so close the entire previous group
		close_all_inspection_windows()
	
	var window_type: StringName
	var context: Dictionary
	var instance: GachaBallInstance

	if is_instance_valid(loc):
		instance = GameManager.get_instance_from_location(loc)
		if not is_instance_valid(instance):
			print("WindowManager: No instance found for location")
			return

		var def = instance.get_definition()
		window_type = &"UnitInspection" if def.category == &"UNIT" else &"ItemInspection"
		context = {"source_view": source_view, "instance": instance, "location": loc}
		
		if loc.container == &"EnemyLineup":
			context["is_enemy_context"] = true
		print("WindowManager: Opening ", window_type, " window for ", def.category, " instance")

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
	_get_modal_layer().add_child(window_instance)
	
	# Enhanced registration with group ID 1 (inspection windows)
	_register_window_enhanced(window_instance, false, 1)
	
	if window_instance.has_method("populate"):
		window_instance.populate(context)
	
	# Use call_deferred for robust positioning after the window is fully set up
	window_instance.call_deferred("_position_root_window", source_view)
	
	# Dynamic tracking of the anchor as it moves or is replaced.
	# We can do this immediately; it doesn't need to be deferred.
	_track_inspection_anchor(window_instance, source_view, loc)




# --- Private: Helper Methods ---

func _track_inspection_anchor(window_instance: Control, anchor: Control, loc: LocationIdentifier) -> void:
	# Find a stable anchor instead of using the volatile GachaBallView
	var stable_anchor = _find_stable_anchor(anchor)
	
	if not is_instance_valid(window_instance) or not is_instance_valid(stable_anchor):
		return
	# Use the window's instance ID as the key for tracking.
	var window_id = window_instance.get_instance_id()

	print("WindowManager: Tracking window ID: ", window_id, " with anchor: ", stable_anchor.name, " (", stable_anchor.get_class(), ")")

	# Connect geometry change using bound callable (avoid capturing freed references)
	var geom_callable := Callable(self, "_on_inspection_anchor_moved").bind(window_instance, stable_anchor)
	if not stable_anchor.is_connected("item_rect_changed", geom_callable):
		stable_anchor.item_rect_changed.connect(geom_callable, CONNECT_DEFERRED)
	# Connect anchor freed using bound callable. Pass the anchor itself so we can
	# disconnect its signals reliably when it's freed.
	var freed_callable := Callable(self, "_on_inspection_anchor_freed").bind(window_instance.get_instance_id(), stable_anchor.get_instance_id(), loc, geom_callable)
	if not stable_anchor.is_connected("tree_exited", freed_callable):
		stable_anchor.tree_exited.connect(freed_callable, CONNECT_DEFERRED)
		print("WindowManager: Connected tree_exited signal for anchor: ", stable_anchor.name)

	# Store tracking info using the instance ID.
	_tracked_windows[window_id] = {
		"anchor": stable_anchor,
		"geom_callable": geom_callable,
		"freed_callable": freed_callable
	}

func _find_stable_anchor(original_anchor: Control) -> Control:
	# If the original anchor is already a stable container, use it
	if original_anchor.get_class() == "SlotView" or original_anchor.get_class() == "PanelContainer":
		return original_anchor
	
	# Otherwise, find the nearest stable container parent
	var current = original_anchor
	while is_instance_valid(current) and current != get_tree().root:
		if current.get_class() == "SlotView" or current.get_class() == "PanelContainer":
			return current
		current = current.get_parent()
	
	# If no stable container found, fall back to the original anchor
	return original_anchor

func stop_tracking_window(window_id: int) -> void:
	if not _tracked_windows.has(window_id):
		return

	var tracking_info = _tracked_windows[window_id]
	var anchor = tracking_info["anchor"]
	var geom_callable = tracking_info["geom_callable"]
	var freed_callable = tracking_info["freed_callable"]

	# The anchor might have already been freed, so we must check if it's valid
	# before trying to disconnect signals from it.
	if is_instance_valid(anchor):
		if anchor.is_connected("item_rect_changed", geom_callable):
			anchor.item_rect_changed.disconnect(geom_callable)
		if anchor.is_connected("tree_exited", freed_callable):
			anchor.tree_exited.disconnect(freed_callable)
	
	_tracked_windows.erase(window_id)
	print("WindowManager: Stopped tracking window ID: ", window_id, ". Remaining tracking data: ", _tracked_windows.size())

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
	# CRITICAL FIX: The window is being freed. We MUST clean up its tracking data
	# to prevent dangling signal connections. This is now possible because we use the ID.
	if not was_modal:
		stop_tracking_window(window_id)
	
	# Clean up enhanced tracking structures
	_instance_id_to_window.erase(window_id)
	_window_hierarchy.erase(window_id)
	
	# Clean up from group registry
	for group_id in _window_group_registry:
		var window_ids = _window_group_registry[group_id]
		window_ids.erase(window_id)
	
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



func _on_inspection_anchor_freed(window_instance_id: int, old_anchor_id: int, _loc: LocationIdentifier, geom_callable: Callable) -> void:
	print("WindowManager: Anchor freed for window ID: ", window_instance_id)
	var old_anchor = instance_from_id(old_anchor_id)
	var window_instance = instance_from_id(window_instance_id)

	if is_instance_valid(old_anchor):
		if old_anchor.is_connected("item_rect_changed", geom_callable):
			old_anchor.item_rect_changed.disconnect(geom_callable)
	
	# SAFE BEHAVIOR: If the anchor is gone, the inspection window is no longer
	# relevant and must be closed to prevent crashes and orphaned UI.
	if is_instance_valid(window_instance):
		print("WindowManager: Closing window due to anchor being freed")
		window_instance.queue_free()
	else:
		print("WindowManager: Window instance is invalid, cannot close")


func _close_top_modal():
	if not _modal_stack.is_empty():
		var window = _modal_stack.pop_back()
		if is_instance_valid(window):
			# Only close inspection windows when true modal windows close, not dialog windows
			# Check if it's a ChoiceWindow by looking at the script class name
			var should_close_inspections = window.get_script() == null or window.get_script().get_global_name() != "ChoiceWindow"
			if should_close_inspections:
				close_all_inspection_windows()
			EventBus.emit_signal("selection_clear_requested")
			window.queue_free()

func _close_all_windows():
	while not _modal_stack.is_empty():
		var window = _modal_stack.pop_back()
		if is_instance_valid(window):
			window.queue_free()
	close_all_inspection_windows()

func find_window_in_group(control_node: Node) -> int:
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
	
	# Determine if the source is on the left or right side of the screen
	var viewport_center_x = viewport_rect.size.x / 2
	var source_center_x = source_pos.x + (source_size.x / 2)
	var is_source_on_right_side = source_center_x > viewport_center_x
	
	# Screen-aware positioning: prefer opposite side of source's screen position
	if is_source_on_right_side:
		# Source is on the right side, try positioning window to the left first
		var pos_left = Vector2(source_rect.position.x - window_size.x - INSPECTION_WINDOW_MARGIN, source_rect.position.y)
		if viewport_rect.encloses(Rect2(pos_left, window_size)):
			return pos_left
		
		# If not enough room on the left, try below
		var pos_down = Vector2(source_rect.position.x, source_rect.end.y + INSPECTION_WINDOW_MARGIN)
		if viewport_rect.encloses(Rect2(pos_down, window_size)):
			return pos_down
		
		# If not enough room below, try above
		var pos_up = Vector2(source_rect.position.x, source_rect.position.y - window_size.y - INSPECTION_WINDOW_MARGIN)
		if viewport_rect.encloses(Rect2(pos_up, window_size)):
			return pos_up
		
		# Last resort: try to the right
		var pos_right = Vector2(source_rect.end.x + INSPECTION_WINDOW_MARGIN, source_rect.position.y)
		if viewport_rect.encloses(Rect2(pos_right, window_size)):
			return pos_right
	else:
		# Source is on the left side, try positioning window to the right first
		var pos_right = Vector2(source_rect.end.x + INSPECTION_WINDOW_MARGIN, source_rect.position.y)
		if viewport_rect.encloses(Rect2(pos_right, window_size)):
			return pos_right
		
		# If not enough room on the right, try below
		var pos_down = Vector2(source_rect.position.x, source_rect.end.y + INSPECTION_WINDOW_MARGIN)
		if viewport_rect.encloses(Rect2(pos_down, window_size)):
			return pos_down
		
		# If not enough room below, try above
		var pos_up = Vector2(source_rect.position.x, source_rect.position.y - window_size.y - INSPECTION_WINDOW_MARGIN)
		if viewport_rect.encloses(Rect2(pos_up, window_size)):
			return pos_up
		
		# Last resort: try to the left
		var pos_left = Vector2(source_rect.position.x - window_size.x - INSPECTION_WINDOW_MARGIN, source_rect.position.y)
		if viewport_rect.encloses(Rect2(pos_left, window_size)):
			return pos_left
	
	# Fallback: position in the top-left corner
	return Vector2(INSPECTION_WINDOW_MARGIN, INSPECTION_WINDOW_MARGIN)

func _calculate_child_window_position(parent_window: Control, child_window: Control) -> Vector2:
	# Position child windows in global coordinates relative to their parent
	# This ensures they don't overlap and are properly positioned
	var parent_global_pos = parent_window.get_global_transform().origin
	var parent_size = parent_window.size
	var child_size = child_window.size
	
	# Get the viewport to check bounds
	var viewport_rect = get_viewport().get_visible_rect()
	var viewport_center_x = viewport_rect.size.x / 2
	
	# Determine if the parent is on the left or right side of the screen
	var parent_center_x = parent_global_pos.x + (parent_size.x / 2)
	var is_parent_on_right_side = parent_center_x > viewport_center_x
	
	# Screen-aware positioning: prefer opposite side of parent's screen position
	if is_parent_on_right_side:
		print("WindowManager: Parent is on right side, trying left first")
		# Parent is on the right side, try positioning child to the left first
		var pos_left = Vector2(parent_global_pos.x - child_size.x - INSPECTION_WINDOW_MARGIN, parent_global_pos.y)
		if viewport_rect.encloses(Rect2(pos_left, child_size)):
			return pos_left
		
		# If not enough room on the left, try below
		var pos_below = Vector2(parent_global_pos.x, parent_global_pos.y + parent_size.y + INSPECTION_WINDOW_MARGIN)
		if viewport_rect.encloses(Rect2(pos_below, child_size)):
			return pos_below
		
		# If not enough room below, try above
		var pos_above = Vector2(parent_global_pos.x, parent_global_pos.y - child_size.y - INSPECTION_WINDOW_MARGIN)
		if viewport_rect.encloses(Rect2(pos_above, child_size)):
			return pos_above
		
		# Last resort: try to the right
		var pos_right = Vector2(parent_global_pos.x + parent_size.x + INSPECTION_WINDOW_MARGIN, parent_global_pos.y)
		if viewport_rect.encloses(Rect2(pos_right, child_size)):
			return pos_right
	else:
		# Parent is on the left side, try positioning child to the right first
		var pos_right = Vector2(parent_global_pos.x + parent_size.x + INSPECTION_WINDOW_MARGIN, parent_global_pos.y)
		if viewport_rect.encloses(Rect2(pos_right, child_size)):
			return pos_right
		
		# If not enough room on the right, try below
		var pos_below = Vector2(parent_global_pos.x, parent_global_pos.y + parent_size.y + INSPECTION_WINDOW_MARGIN)
		if viewport_rect.encloses(Rect2(pos_below, child_size)):
			return pos_below
		
		# If not enough room below, try above
		var pos_above = Vector2(parent_global_pos.x, parent_global_pos.y - child_size.y - INSPECTION_WINDOW_MARGIN)
		if viewport_rect.encloses(Rect2(pos_above, child_size)):
			return pos_above
		
		# Last resort: try to the left
		var pos_left = Vector2(parent_global_pos.x - child_size.x - INSPECTION_WINDOW_MARGIN, parent_global_pos.y)
		if viewport_rect.encloses(Rect2(pos_left, child_size)):
			return pos_left
	
	# Fallback: position in the top-right corner of the parent
	return Vector2(parent_global_pos.x + parent_size.x - child_size.x - INSPECTION_WINDOW_MARGIN, parent_global_pos.y + INSPECTION_WINDOW_MARGIN)




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
		if not nodes.is_empty(): 
			_modal_layer = nodes[0]
			print("WindowManager: Found existing modal layer: ", _modal_layer.name)
		else:
			printerr("WindowManager: CRITICAL - No node in group 'modal_layer'.")
			_modal_layer = CanvasLayer.new()
			get_tree().root.add_child(_modal_layer)
			print("WindowManager: Created new modal layer")
	return _modal_layer

func is_any_inspection_window_open() -> bool:
	# This helper allows other scripts to query the window state without accessing private variables.
	return not _active_inspection_group.is_empty()

## Close child windows based on window group ID or parent window ID
func close_child_windows(window_group_id: int, parent_window_id: int = -1):
	print("WindowManager: close_child_windows called with group_id: ", window_group_id, ", parent_id: ", parent_window_id)
	# TDD Rule: Close only the children of a specific parent window
	if parent_window_id != -1:
		print("WindowManager: Looking for parent window with ID: ", parent_window_id)
		print("WindowManager: Active inspection group size: ", _active_inspection_group.size())
		# Close children of the specific parent window
		var parent_index = -1
		for i in range(_active_inspection_group.size()):
			var window_id = _active_inspection_group[i].get_instance_id()
			print("WindowManager: Window ", i, " has ID: ", window_id)
			if window_id == parent_window_id:
				parent_index = i
				print("WindowManager: Found parent window at index: ", i)
				break
		
		if parent_index != -1:
			# Close all windows that come after the parent (children)
			var child_count = _active_inspection_group.size() - (parent_index + 1)
			if child_count > 0:
				for i in range(child_count):
					var child_window = _active_inspection_group.pop_back()
					if is_instance_valid(child_window):
						stop_tracking_window(child_window.get_instance_id())
						child_window.queue_free()
	elif window_group_id == 1 and not _active_inspection_group.is_empty():
		# Fallback: Close children of the top-most window
		var parent_index = _active_inspection_group.size() - 1
		
		# Close all windows that come after the parent (children)
		var child_count = _active_inspection_group.size() - (parent_index + 1)
		if child_count > 0:
			for i in range(child_count):
				var child_window = _active_inspection_group.pop_back()
				if is_instance_valid(child_window):
					stop_tracking_window(child_window.get_instance_id())
					child_window.queue_free()
	elif window_group_id == 0:
		# Close all windows (both modals and inspections)
		close_all_inspection_windows()
		# Also close any open modals
		while not _modal_stack.is_empty():
			_close_top_modal()

# --- Enhanced Window Management Methods ---

## Enhanced window registration with instance ID tracking
func _register_window_enhanced(window_instance: Control, is_modal: bool, window_group_id: int = 0):
	if not is_instance_valid(window_instance):
		return
	
	var window_id = window_instance.get_instance_id()
	
	# Register in instance ID lookup
	_instance_id_to_window[window_id] = window_instance
	
	# Register in window group registry
	if not _window_group_registry.has(window_group_id):
		_window_group_registry[window_group_id] = []
	_window_group_registry[window_group_id].append(window_id)
	
	# Register in hierarchy (for inspection windows)
	if not is_modal and not _active_inspection_group.is_empty():
		var parent_window = _active_inspection_group.back()
		if is_instance_valid(parent_window):
			var parent_id = parent_window.get_instance_id()
			_window_hierarchy[window_id] = parent_id
	
	# Connect cleanup signals
	_register_window(window_instance, is_modal)

## Enhanced proactive cleanup function
func _proactive_cleanup():
	# Clean up invalid windows from all tracking structures
	_cleanup_invalid_windows()
	_cleanup_invalid_instance_ids()
	_cleanup_invalid_hierarchy_entries()
	_cleanup_invalid_group_registry_entries()

## Clean up invalid instance ID mappings
func _cleanup_invalid_instance_ids():
	var invalid_ids = []
	for window_id in _instance_id_to_window:
		var window = _instance_id_to_window[window_id]
		if not is_instance_valid(window):
			invalid_ids.append(window_id)
	
	for window_id in invalid_ids:
		_instance_id_to_window.erase(window_id)
		print("WindowManager: Cleaned up invalid instance ID mapping: ", window_id)

## Clean up invalid hierarchy entries
func _cleanup_invalid_hierarchy_entries():
	var invalid_entries = []
	for window_id in _window_hierarchy:
		var parent_id = _window_hierarchy[window_id]
		if not instance_from_id(parent_id) or not instance_from_id(window_id):
			invalid_entries.append(window_id)
	
	for window_id in invalid_entries:
		_window_hierarchy.erase(window_id)
		print("WindowManager: Cleaned up invalid hierarchy entry: ", window_id)

## Clean up invalid group registry entries
func _cleanup_invalid_group_registry_entries():
	for group_id in _window_group_registry:
		var window_ids = _window_group_registry[group_id]
		var valid_ids = []
		for window_id in window_ids:
			if instance_from_id(window_id):
				valid_ids.append(window_id)
		_window_group_registry[group_id] = valid_ids

## Get window by instance ID (enhanced lookup)
func get_window_by_instance_id(instance_id: int) -> Control:
	if _instance_id_to_window.has(instance_id):
		var window = _instance_id_to_window[instance_id]
		if is_instance_valid(window):
			return window
		else:
			# Clean up invalid reference
			_instance_id_to_window.erase(instance_id)
	return null

## Get all windows in a group
func get_windows_in_group(group_id: int) -> Array[Control]:
	var windows: Array[Control] = []
	if _window_group_registry.has(group_id):
		for window_id in _window_group_registry[group_id]:
			var window = get_window_by_instance_id(window_id)
			if is_instance_valid(window):
				windows.append(window)
	return windows

## Close all windows in a specific group
func close_windows_in_group(group_id: int):
	var windows = get_windows_in_group(group_id)
	for window in windows:
		if is_instance_valid(window):
			window.queue_free()

## Enhanced window hierarchy management
func get_child_windows(parent_window_id: int) -> Array[int]:
	var child_ids: Array[int] = []
	for window_id in _window_hierarchy:
		if _window_hierarchy[window_id] == parent_window_id:
			child_ids.append(window_id)
	return child_ids

## Close all child windows of a specific parent
func close_child_windows_of_parent(parent_window_id: int):
	var child_ids = get_child_windows(parent_window_id)
	for child_id in child_ids:
		var child_window = get_window_by_instance_id(child_id)
		if is_instance_valid(child_window):
			child_window.queue_free()

## Enhanced window statistics
func get_window_statistics() -> Dictionary:
	return {
		"modal_count": _modal_stack.size(),
		"inspection_count": _active_inspection_group.size(),
		"tracked_count": _tracked_windows.size(),
		"instance_id_count": _instance_id_to_window.size(),
		"hierarchy_count": _window_hierarchy.size(),
		"group_registry_count": _window_group_registry.size()
	}

```