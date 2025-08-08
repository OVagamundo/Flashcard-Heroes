# res://scripts/WindowManager.gd
extends Node

const INSPECTION_WINDOW_MARGIN = 20.0

var _window_scenes: Dictionary = {
	# --- Hermetic Modals (Managed by _modal_stack, use open_modal_window) ---
	&"EndBattlePopup": load("res://scenes/EndBattlePopup.tscn"),
	&"FlashcardMinigame": load("res://scenes/FlashcardMinigame.tscn"),
	&"ResultsPopup": load("res://scenes/ResultsPopup.tscn"),
	
	# --- Contextual Windows (Managed by _active_inspection_group) ---
	&"Inventory": load("res://scenes/InventoryWindow.tscn"),
	&"DiscardPile": load("res://scenes/DiscardPileWindow.tscn"),
	&"ChoiceWindow": load("res://scenes/ChoiceWindow.tscn"),
	&"UnitInspection": load("res://scenes/UnitInspectionWindow.tscn"),
	&"ItemInspection": load("res://scenes/ItemInspectionWindow.tscn"),
	&"EffectInspection": load("res://scenes/EffectInspectionWindow.tscn"),
}

var _modal_stack: Array[Control] = []
var _active_inspection_group: Array[Control] = []

var _tracked_windows: Dictionary = {}
var _modal_layer: CanvasLayer = null


func _ready():
	# FINAL FIX: Input processing is REMOVED. The WindowManager is now a pure service.
	# It no longer interprets raw input; it only executes commands from the GIR.
	set_process_input(false)

	# FINAL FIX: Signal connections now point to the clean, public API functions,
	# and all old, internal handler functions (_on_..._requested) have been removed.
	SignalBus.inspect_inventory_requested.connect(open_inventory_window)
	SignalBus.display_discard_pile_requested.connect(open_discard_pile_window)
	SignalBus.inspection_requested.connect(open_inspection_window)
	SignalBus.open_choice_window_requested.connect(open_choice_window)
	SignalBus.close_modal_requested.connect(_close_top_modal)
	
	SignalBus.main_scene_requested.connect(_close_all_windows)
	SignalBus.loadout_scene_requested.connect(_close_all_windows)
	SignalBus.title_scene_requested.connect(_close_all_windows)
	SignalBus.path_choice_scene_requested.connect(close_all_inspection_windows)


# --- PUBLIC API ---

# This function is ONLY for true "Hermetic Modals" that halt game flow.
func open_modal_window(type: StringName, context: Dictionary = {}):
	if not _window_scenes.has(type): return
	_close_all_windows() # True modals are exclusive.

	var window_instance = _window_scenes[type].instantiate()
	_get_modal_layer().add_child(window_instance)
	_modal_stack.push_back(window_instance)
	_register_window(window_instance, true)
	
	if window_instance.has_method("populate"):
		window_instance.populate(context)

# Public entry point for the Inventory Window.
func open_inventory_window():
	var context = {
		"window_type": &"Inventory",
		"populate_context": _get_inventory_populate_context()
	}
	_open_contextual_window(context)

# Back-compat shim for GIR callers that still use the old private name
func _open_inspection_window(loc: LocationIdentifier, source_view: Control):
	open_inspection_window(loc, source_view)

# Public API: open a child contextual window anchored to an existing window/view.
func open_child_contextual_window(window_type: StringName, anchor_view: Control, populate_ctx: Dictionary = {}):
	if not is_instance_valid(anchor_view): return
	var context = {
		"window_type": window_type,
		"anchor_view": anchor_view,
		"populate_context": populate_ctx,
	}
	_open_contextual_window(context)

# Public entry point for the Discard Pile Window.
func open_discard_pile_window():
	var context = {
		"window_type": &"DiscardPile",
		"populate_context": _get_discard_pile_populate_context()
	}
	_open_contextual_window(context)

# Public entry point for the Choice Window.
# Optionally provide an anchor_view to dynamically position near a target view (e.g., target GachaBall).
func open_choice_window(populate_ctx: Dictionary, anchor_view: Control = null):
	var anchor := anchor_view
	if not is_instance_valid(anchor):
		# Attempt to resolve from target_location if provided in context
		var target_loc: LocationIdentifier = populate_ctx.get("target_location")
		if is_instance_valid(target_loc):
			anchor = find_view_for_location(target_loc)
			print("Resolved anchor from target_location")
		if not is_instance_valid(anchor):
			# Fallback: attempt to resolve from source_location
			var source_loc: LocationIdentifier = populate_ctx.get("source_location")
			if is_instance_valid(source_loc):
				anchor = find_view_for_location(source_loc)
				print("Resolved anchor from source_location")
	var context = {
		"window_type": &"ChoiceWindow",
		"populate_context": populate_ctx,
		"anchor_view": anchor,
		"positioning_hint": "top_center_over_anchor",
	}
	_open_contextual_window(context)

# Public entry point for all inspection windows (Unit, Item, Effect).
func open_inspection_window(loc: LocationIdentifier, source_view: Control):
	if not is_instance_valid(source_view): return

	var payload = _derive_window_payload(loc, source_view)
	if payload.is_empty(): return

	var context = {
		"window_type": payload.get("window_type"),
		"populate_context": payload.get("context"),
		"anchor_view": source_view,
	}
	_open_contextual_window(context)

# Public API for GIR (Rule W3 - Window Pruning).
func close_children_of(parent_window: Control):
	var parent_index = _active_inspection_group.find(parent_window)
	if parent_index == -1: return

	var child_count = _active_inspection_group.size() - (parent_index + 1)
	if child_count > 0:
		for i in range(child_count):
			var child_window = _active_inspection_group.pop_back()
			if is_instance_valid(child_window):
				stop_tracking_window(child_window.get_instance_id())
				child_window.queue_free()

# Back-compat API expected by GIR: resolve parent by instance_id and prune its children
func close_child_windows(window_group_id: int, parent_window_id: int = -1):
	if parent_window_id == -1:
		return
	var parent_window: Control = null
	for w in _active_inspection_group:
		if is_instance_valid(w) and w.get_instance_id() == parent_window_id:
			parent_window = w
			break
	if parent_window:
		close_children_of(parent_window)

# Public API for GIR (Rules W2, W4, W5).
func close_all_inspection_windows():
	for window in _active_inspection_group:
		if is_instance_valid(window):
			stop_tracking_window(window.get_instance_id())
			window.queue_free()
	_active_inspection_group.clear()

	# no-op if already empty

# Public query function for the GIR.
func is_any_inspection_window_open() -> bool:
	return not _active_inspection_group.is_empty()

# Public helper queried by GIR to know if a view is part of the current inspection group.
# Returns the index within `_active_inspection_group`, or -1 if not present.
func find_window_in_group(view: Control) -> int:
	# Walk up ancestors to see if any is a tracked inspection window
	var current: Node = view
	while is_instance_valid(current) and current != get_tree().root:
		var idx := _index_in_active_group(current)
		if idx != -1:
			return idx
		current = current.get_parent()
	return -1

# Helper: safe index check by instance_id to avoid typed Array[Control] validation errors
func _index_in_active_group(node: Node) -> int:
	for i in range(_active_inspection_group.size()):
		var w = _active_inspection_group[i]
		if is_instance_valid(w) and is_instance_valid(node) and w.get_instance_id() == node.get_instance_id():
			return i
	return -1

# Public API for inspection windows to handle background clicks locally.
# Windows should call this from their `_gui_input` when detecting a click on their
# background. This prunes only the descendants of the clicked window (W3),
# while GIR handles truly global background clicks.
func handle_inspection_background_click(clicked_window: Control):
	if not is_instance_valid(clicked_window):
		return
	# Use index lookup to avoid typed array validation issues on non-Control nodes
	var idx := _index_in_active_group(clicked_window)
	if idx != -1:
		close_children_of(clicked_window)


# --- CORE INTERNAL LOGIC ---

# This unified function handles the creation and management of ALL Contextual Windows.
func _open_contextual_window(context: Dictionary):
	var window_type: StringName = context.get("window_type")
	var anchor_view: Control = context.get("anchor_view", null)
	var populate_context: Dictionary = context.get("populate_context", {})
	
	# Rule W1 Implementation: Distinguish between root and child requests.
	var parent_window = _find_ancestor_inspection_window(anchor_view)
	# Robust fallback: if we have an anchor but could not resolve its ancestor window,
	# assume the top of the active inspection group is the intended parent (e.g., Inventory)
	# to avoid closing the entire group and losing the anchor.
	if parent_window == null and is_instance_valid(anchor_view) and not _active_inspection_group.is_empty():
		parent_window = _active_inspection_group.back()

	if parent_window:
		# It's a child request. Prune other children of the same parent.
		close_children_of(parent_window)
	else:
		# It's a new root request. Close the entire previous group.
		close_all_inspection_windows()

	if not _window_scenes.has(window_type): return

	var window_instance = _window_scenes[window_type].instantiate()
	# Hide until fully positioned to prevent a single-frame flash at default position
	window_instance.visible = false
	_active_inspection_group.push_back(window_instance)
	_get_modal_layer().add_child(window_instance)
	_register_window(window_instance, false) # Register as NON-modal.

	if window_instance.has_method("populate"):
		window_instance.populate(populate_context)

	var pos_hint: String = context.get("positioning_hint", "")
	call_deferred("_deferred_position", window_instance, anchor_view, parent_window, pos_hint)
	
	if parent_window == null and anchor_view != null:
		var loc = populate_context.get("location")
		if loc == null:
			loc = populate_context.get("target_location")
		_track_inspection_anchor(window_instance, anchor_view, loc)


# --- HELPER FUNCTIONS ---

func _deferred_position(window: Control, anchor: Control, parent_window: Control, pos_hint: String = ""):
	if not is_instance_valid(window): return
	# Ensure layout has settled for the newly added window before measuring
	await get_tree().process_frame

	var position: Vector2
	# Always prefer positioning relative to the actual anchor view if available.
	# Parent window existence should not override anchor-based placement.
	if is_instance_valid(anchor):
		if pos_hint == "center_over_anchor":
			position = _calculate_centered_over_anchor(anchor, window)
		elif pos_hint == "top_center_over_anchor":
			position = _calculate_top_center_over_anchor(anchor, window)
		else:
			position = _calculate_window_position(anchor, window)
	elif is_instance_valid(parent_window):
		position = _calculate_child_window_position(parent_window, window)
	else: # It's a root fixed-position window (Inventory, etc.)
		var viewport_rect = get_viewport().get_visible_rect()
		position = viewport_rect.position + viewport_rect.size / 2.0 - window.size / 2.0
	
	window.set_global_position(position)
	# Now that the window is correctly positioned, reveal it
	window.show()

func _find_ancestor_inspection_window(node: Node) -> Control:
	if not is_instance_valid(node): return null
	# First, treat the node itself as a candidate parent window
	var self_idx := _index_in_active_group(node)
	if self_idx != -1:
		return node as Control
	# Then walk ancestors
	var current := node.get_parent()
	while is_instance_valid(current) and current != get_tree().root:
		var idx := _index_in_active_group(current)
		if idx != -1:
			return current as Control
		current = current.get_parent()
	return null

# Public helper: resolve the ancestor inspection window for an arbitrary node
func find_ancestor_window_for_view(node: Node) -> Control:
	return _find_ancestor_inspection_window(node)

# Public helper: resolve a Control view for a given LocationIdentifier, if present in the scene.
func find_view_for_location(loc: LocationIdentifier) -> Control:
	if not is_instance_valid(loc):
		return null
	# Breadth-first traversal to find any Control with matching location metadata
	var queue: Array = [get_tree().root]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		for child in node.get_children():
			queue.push_back(child)
		if node is Control and node.has_meta("location_identifier"):
			var meta_loc = node.get_meta("location_identifier")
			if _locations_equal(meta_loc, loc):
				return node as Control
	return null

# Helper: compare two LocationIdentifier values safely (by fields)
func _locations_equal(a, b) -> bool:
	if a == null or b == null:
		return false
	# Field-wise comparison via Object.get() to avoid relying on reference equality
	var a_container = a.get("container") if a is Object else null
	var b_container = b.get("container") if b is Object else null
	var a_index = a.get("index") if a is Object else -1
	var b_index = b.get("index") if b is Object else -1
	var a_unit = a.get("unit_uuid") if a is Object else ""
	var b_unit = b.get("unit_uuid") if b is Object else ""
	return a_container == b_container and a_index == b_index and a_unit == b_unit

func _get_inventory_populate_context() -> Dictionary:
	var is_battle = GameManager.is_in_battle
	var inventory_data = {}
	var title = ""
	if is_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		if is_instance_valid(bm): inventory_data = bm.get_battle_inventory()
		title = "Battle Inventory"
	else:
		var run_state = GameManager.run_state
		if is_instance_valid(run_state): inventory_data = run_state.get_run_inventory_containers()
		title = "Run Inventory"
	return { "inventory": inventory_data, "is_battle_context": is_battle, "title": title, "is_interactive": true }

func _get_discard_pile_populate_context() -> Dictionary:
	var inventory_data = []
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		if is_instance_valid(bm): inventory_data = bm.get_discard_pile_inventory()
	return { "inventory": inventory_data, "is_battle_context": GameManager.is_in_battle, "title": "Discard Pile", "is_interactive": false }

func _derive_window_payload(loc: LocationIdentifier, source_view: Control) -> Dictionary:
	var payload := {}
	var instance: GachaBallInstance
	var window_type: StringName
	var context: Dictionary
	if is_instance_valid(loc):
		instance = GameManager.get_instance_from_location(loc)
		if not is_instance_valid(instance): return {}
		var def = instance.get_definition()
		if def.category == &"UNIT":
			window_type = &"UnitInspection"
			context = {"source_view": source_view, "instance": instance, "location": loc}
			if loc.container == &"EnemyLineup": context["is_enemy_context"] = true
		elif def.category == &"ITEM":
			window_type = &"ItemInspection"
			context = {"source_view": source_view, "instance": instance, "location": loc}
		else: return {}
	elif source_view.has_meta("effect_definition"):
		var effect_def = source_view.get_meta("effect_definition")
		if effect_def == null: return {}
		window_type = &"EffectInspection"
		context = {"source_view": source_view, "effect_definition": effect_def}
	else: return {}
	payload["window_type"] = window_type
	payload["context"] = context
	return payload
 
 # Anchor tracking policy:
 # - Applied ONLY for ROOT contextual windows with a valid `anchor_view`.
 #   See call site in `_open_contextual_window` when `parent_window == null` and
 #   `anchor_view != null` (lines where we gate the tracking).
 # - Child windows do NOT track anchors (their position is derived from parent).
 # - Root fixed-position windows (e.g., Inventory) also do NOT track anchors.
func _track_inspection_anchor(window_instance: Control, anchor: Control, loc: LocationIdentifier):
	if not is_instance_valid(window_instance) or not is_instance_valid(anchor): return
	var window_id = window_instance.get_instance_id()
	var geom_callable := Callable(self, "_on_inspection_anchor_moved").bind(window_instance, anchor)
	if not anchor.is_connected("item_rect_changed", geom_callable):
		anchor.item_rect_changed.connect(geom_callable, CONNECT_DEFERRED)
	var freed_callable := Callable(self, "_on_inspection_anchor_freed").bind(window_id, anchor.get_instance_id(), loc, geom_callable)
	if not anchor.is_connected("tree_exited", freed_callable):
		anchor.tree_exited.connect(freed_callable, CONNECT_DEFERRED)
	_tracked_windows[window_id] = { "anchor": anchor, "geom_callable": geom_callable, "freed_callable": freed_callable }

func stop_tracking_window(window_id: int):
	if not _tracked_windows.has(window_id): return
	var tracking_info = _tracked_windows[window_id]
	var anchor = tracking_info["anchor"]
	if is_instance_valid(anchor):
		if anchor.is_connected("item_rect_changed", tracking_info["geom_callable"]):
			anchor.item_rect_changed.disconnect(tracking_info["geom_callable"])
		if anchor.is_connected("tree_exited", tracking_info["freed_callable"]):
			anchor.tree_exited.disconnect(tracking_info["freed_callable"])
	_tracked_windows.erase(window_id)

func _on_inspection_anchor_moved(window_instance: Control, anchor: Control):
	if is_instance_valid(anchor) and is_instance_valid(window_instance):
		window_instance.global_position = _calculate_window_position(anchor, window_instance)

func _on_inspection_anchor_freed(window_id: int, old_anchor_id: int, _loc: LocationIdentifier, geom_callable: Callable):
	var old_anchor = instance_from_id(old_anchor_id)
	var window_instance = instance_from_id(window_id)
	if is_instance_valid(old_anchor) and old_anchor.is_connected("item_rect_changed", geom_callable):
		old_anchor.item_rect_changed.disconnect(geom_callable)
	if is_instance_valid(window_instance):
		window_instance.queue_free()

# FINAL FIX: This function is now correctly defined and used for lifecycle cleanup.
func _register_window(window_instance: Control, is_modal: bool):
	if not is_instance_valid(window_instance): return
	var freed_callable := Callable(self, "_on_window_freed").bind(window_instance.get_instance_id(), is_modal)
	if not window_instance.is_connected("tree_exited", freed_callable):
		window_instance.tree_exited.connect(freed_callable, CONNECT_DEFERRED)

func _on_window_freed(window_id: int, was_modal: bool):
	if not was_modal:
		stop_tracking_window(window_id)
	var stack = _modal_stack if was_modal else _active_inspection_group
	for i in range(stack.size() - 1, -1, -1):
		var window = stack[i]
		if not is_instance_valid(window) or window.get_instance_id() == window_id:
			stack.remove_at(i)

func _close_top_modal():
	if not _modal_stack.is_empty():
		var window = _modal_stack.pop_back()
		if is_instance_valid(window):
			window.queue_free()
		return
	# Fallback: close the top contextual window if no modals are open
	if not _active_inspection_group.is_empty():
		var top_window = _active_inspection_group.back()
		if is_instance_valid(top_window):
			top_window.queue_free()

func _close_all_windows():
	close_all_inspection_windows()
	while not _modal_stack.is_empty():
		_close_top_modal()

func _calculate_window_position(source_view: Control, new_window: Control) -> Vector2:
	if not is_instance_valid(source_view): return Vector2.ZERO
	var viewport_rect = get_viewport().get_visible_rect()
	var source_rect = source_view.get_global_rect()
	var window_size = _get_window_size(new_window)
	var is_source_on_right_side = source_rect.get_center().x > viewport_rect.size.x / 2.0
	var pos_right = Vector2(source_rect.end.x + INSPECTION_WINDOW_MARGIN, source_rect.position.y)
	var pos_left = Vector2(source_rect.position.x - window_size.x - INSPECTION_WINDOW_MARGIN, source_rect.position.y)
	if is_source_on_right_side:
		if viewport_rect.encloses(Rect2(pos_left, window_size)): return pos_left
	else:
		if viewport_rect.encloses(Rect2(pos_right, window_size)): return pos_right
	var pos_down = Vector2(source_rect.position.x, source_rect.end.y + INSPECTION_WINDOW_MARGIN)
	if viewport_rect.encloses(Rect2(pos_down, window_size)): return pos_down
	var pos_up = Vector2(source_rect.position.x, source_rect.position.y - window_size.y - INSPECTION_WINDOW_MARGIN)
	if viewport_rect.encloses(Rect2(pos_up, window_size)): return pos_up
	if is_source_on_right_side:
		if viewport_rect.encloses(Rect2(pos_right, window_size)): return pos_right
	else:
		if viewport_rect.encloses(Rect2(pos_left, window_size)): return pos_left
	return Vector2(INSPECTION_WINDOW_MARGIN, INSPECTION_WINDOW_MARGIN)

# Position helper to center a window over its anchor, clamped to the viewport with a small margin
func _calculate_centered_over_anchor(anchor: Control, new_window: Control) -> Vector2:
	var viewport_rect = get_viewport().get_visible_rect()
	var anchor_rect = anchor.get_global_rect()
	var window_size = _get_window_size(new_window)
	var desired = anchor_rect.get_center() - window_size / 2.0
	# Clamp within viewport with margin
	var margin: float = INSPECTION_WINDOW_MARGIN
	desired.x = clampf(desired.x, viewport_rect.position.x + margin, viewport_rect.end.x - window_size.x - margin)
	desired.y = clampf(desired.y, viewport_rect.position.y + margin, viewport_rect.end.y - window_size.y - margin)
	return desired

# Position helper to place window centered horizontally above the anchor (top-center), clamped to viewport
func _calculate_top_center_over_anchor(anchor: Control, new_window: Control) -> Vector2:
	var viewport_rect = get_viewport().get_visible_rect()
	var anchor_rect = anchor.get_global_rect()
	var window_size = _get_window_size(new_window)
	# Center horizontally, place above the anchor with a margin
	var desired = Vector2(
		anchor_rect.get_center().x - window_size.x / 2.0,
		anchor_rect.position.y - window_size.y - INSPECTION_WINDOW_MARGIN
	)
	# Clamp within viewport with margin
	var margin: float = INSPECTION_WINDOW_MARGIN
	desired.x = clampf(desired.x, viewport_rect.position.x + margin, viewport_rect.end.x - window_size.x - margin)
	desired.y = clampf(desired.y, viewport_rect.position.y + margin, viewport_rect.end.y - window_size.y - margin)
	return desired

func _get_window_size(window: Control) -> Vector2:
	var sz := window.size
	if sz == Vector2.ZERO:
		# Use combined minimum size as a reliable fallback before layout settles
		var min_sz := window.get_combined_minimum_size()
		if min_sz != Vector2.ZERO:
			return min_sz
	return sz

func _calculate_child_window_position(parent_window: Control, child_window: Control) -> Vector2:
	return _calculate_window_position(parent_window, child_window)

func _get_modal_layer() -> CanvasLayer:
	if not is_instance_valid(_modal_layer):
		_modal_layer = get_tree().get_first_node_in_group("modal_layer")
		if not is_instance_valid(_modal_layer):
			printerr("WindowManager: CRITICAL - No node in group 'modal_layer' found in scene tree.")
			_modal_layer = CanvasLayer.new()
			_modal_layer.name = "ModalLayerFailsafe"
			get_tree().root.add_child(_modal_layer)
	return _modal_layer
