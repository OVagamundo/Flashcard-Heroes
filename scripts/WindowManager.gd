# res://scripts/WindowManager.gd
extends Node

const INSPECTION_WINDOW_MARGIN = 20.0

var _window_scenes: Dictionary = {
	# --- Hermetic Modals (Managed by _modal_stack, use open_modal_window) ---
	&"EndBattlePopup": load("res://scenes/EndBattlePopup.tscn"),
	&"RunCompletePopup": load("res://scenes/RunCompletePopup.tscn"),
	&"FlashcardMinigame": load("res://scenes/FlashcardMinigame.tscn"),
	&"ResultsPopup": load("res://scenes/ResultsPopup.tscn"),
	
	# --- Contextual Windows (Managed by _active_inspection_group) ---
	&"Inventory": load("res://scenes/InventoryWindow.tscn"),
	&"DiscardPile": load("res://scenes/DiscardPileWindow.tscn"),
	&"ChoiceWindow": load("res://scenes/ChoiceWindow.tscn"),
	&"UnitInspection": load("res://scenes/UnitInspectionWindow.tscn"),
	&"ItemInspection": load("res://scenes/ItemInspectionWindow.tscn"),
	&"EffectInspection": load("res://scenes/EffectInspectionWindow.tscn"),
	&"Options": load("res://scenes/OptionsWindow.tscn"),
}

var _modal_stack: Array[Control] = []
var _active_inspection_group: Array[Control] = []

var _tracked_windows: Dictionary = {}
var _modal_layer: CanvasLayer = null


func _ready() -> void:
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
	SignalBus.close_top_contextual_requested.connect(close_top_contextual_window)
	
	SignalBus.main_scene_requested.connect(_close_all_windows)
	SignalBus.loadout_scene_requested.connect(_close_all_windows)
	SignalBus.title_scene_requested.connect(_close_all_windows)
	SignalBus.path_choice_scene_requested.connect(close_all_inspection_windows)


# --- PUBLIC API ---

# This function is ONLY for true "Hermetic Modals" that halt game flow.
func open_modal_window(type: StringName, context: Dictionary = {}) -> Control:
	if not _window_scenes.has(type):
		push_error("[WindowManager] ERROR: Window type not found in _window_scenes: " + str(type))
		return null
	_close_all_windows() # True modals are exclusive.

	var window_instance = _window_scenes[type].instantiate()
	_get_modal_layer().add_child(window_instance)
	_modal_stack.push_back(window_instance)
	_register_window(window_instance, true)
	
	if window_instance.has_method("populate"):
		window_instance.populate(context)

	return window_instance

# Public entry point for the Inventory Window.
func open_inventory_window() -> void:
	var context: Dictionary = {
		"window_type": &"Inventory",
		"populate_context": _get_inventory_populate_context()
	}
	_open_contextual_window(context)

# Back-compat shim for GIR callers that still use the old private name
func _open_inspection_window(loc: LocationIdentifier, source_view: Control) -> void:
	open_inspection_window(loc, source_view)

# Public API: open a child contextual window anchored to an existing window/view.
func open_child_contextual_window(window_type: StringName, anchor_view: Control, populate_ctx: Dictionary = {}) -> void:
	if not is_instance_valid(anchor_view): return
	var context: Dictionary = {
		"window_type": window_type,
		"anchor_view": anchor_view,
		"populate_context": populate_ctx,
	}
	_open_contextual_window(context)

# Public entry point for the Discard Pile Window.
func open_discard_pile_window() -> void:
	var context: Dictionary = {
		"window_type": &"DiscardPile",
		"populate_context": _get_discard_pile_populate_context()
	}
	_open_contextual_window(context)

# Public entry point for the Choice Window.
# Optionally provide an anchor_view to dynamically position near a target view (e.g., target GachaBall).
func open_choice_window(populate_ctx: Dictionary, anchor_view: Control = null) -> void:
	# ChoiceWindow is a dynamic-position contextual window (no blocker, non-exclusive).
	# Resolve anchor: prefer explicit anchor_view, then target_location, then source_location.
	var anchor: Control = anchor_view
	if not is_instance_valid(anchor):
		var target_loc: LocationIdentifier = populate_ctx.get("target_location")
		if is_instance_valid(target_loc):
			anchor = find_view_for_location(target_loc)
	if not is_instance_valid(anchor):
		var source_loc: LocationIdentifier = populate_ctx.get("source_location")
		if is_instance_valid(source_loc):
			anchor = find_view_for_location(source_loc)

	if not _window_scenes.has(&"ChoiceWindow"): return
	var context: Dictionary = {
		"window_type": &"ChoiceWindow",
		"populate_context": populate_ctx,
		"positioning_hint": "top_center_over_anchor",
	}
	if is_instance_valid(anchor):
		context["anchor_view"] = anchor
	_open_contextual_window(context)

# Public entry point for all inspection windows (Unit, Item, Effect).
func open_inspection_window(loc: LocationIdentifier, source_view: Control) -> void:
	if not is_instance_valid(source_view): return

	var payload = _derive_window_payload(loc, source_view)
	if payload.is_empty(): return

	var context: Dictionary = {
		"window_type": payload.get("window_type"),
		"populate_context": payload.get("context"),
		"anchor_view": source_view,
	}
	var pos_hint: String = payload.get("positioning_hint", "")
	if pos_hint != "":
		context["positioning_hint"] = pos_hint
	_open_contextual_window(context)

# Public API for GIR (Rule W3 - Window Pruning).
func close_children_of(parent_window: Control) -> void:
	var parent_index = _active_inspection_group.find(parent_window)
	if parent_index == -1: return
	for i in range(_active_inspection_group.size() - 1, parent_index, -1):
		var child_window = _active_inspection_group[i]
		if is_instance_valid(child_window):
			stop_tracking_window(child_window.get_instance_id())
			child_window.queue_free()

# Back-compat API expected by GIR: resolve parent by instance_id and prune its children
func close_child_windows(window_group_id: int, parent_window_id: int = -1) -> void:
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
func close_all_inspection_windows() -> void:
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
func handle_inspection_background_click(clicked_window: Control) -> void:
	if not is_instance_valid(clicked_window):
		return
	# Use index lookup to avoid typed array validation issues on non-Control nodes
	var idx := _index_in_active_group(clicked_window)
	if idx != -1:
		close_children_of(clicked_window)


# Suppression-aware close request for inspection windows.
# Windows and internal handlers (e.g., anchor-freed) must use this instead of queue_free.
func request_close_inspection_window(window: Control, cause: StringName = &"") -> void:
	if not is_instance_valid(window):
		return
	var window_id := window.get_instance_id()
	# Respect GIR suppression to avoid premature closures during interactions.
	var suppressed_for_id: bool = GlobalInteractionRouter.is_close_suppressed_for_window_id(window_id)
	var suppressed_now: bool = GlobalInteractionRouter.is_close_suppressed_now()
	if suppressed_for_id or suppressed_now:
		return
	stop_tracking_window(window_id)
	window.queue_free()


# --- CORE INTERNAL LOGIC ---

# This unified function handles the creation and management of ALL Contextual Windows.
func _open_contextual_window(context: Dictionary) -> void:
	# Block contextual windows triggered by user input during COMBAT.
	# This preserves strict input blocking while allowing true modals via open_modal_window.
	var gir := get_tree().get_first_node_in_group("global_interaction_router")
	if is_instance_valid(gir) and gir.has_method("is_combat_locked") and gir.is_combat_locked():
		return
	var window_type: StringName = context.get("window_type")
	var anchor_view: Control = context.get("anchor_view", null)
	var populate_context: Dictionary = context.get("populate_context", {})

	# Rule W1 Implementation with context-sensitive parent resolution.
	# Prefer explicit target_parent_window_id or unit-context hint over structural inference.
	var parent_window = _resolve_parent_window(anchor_view, populate_context)
	# Robust fallback: if we have an anchor but could not resolve its ancestor window,
	# enforce pruning policy: close children for child requests, close entire group for roots.
	if is_instance_valid(parent_window):
		close_children_of(parent_window)
	else:
		close_all_inspection_windows()

	if not _window_scenes.has(window_type):
		return

	var window_instance = _window_scenes[window_type].instantiate()
	_get_modal_layer().add_child(window_instance)
	# Prevent flashing before we compute final position
	window_instance.hide()
	_register_window(window_instance, false) # Register as NON-modal.
	_active_inspection_group.push_back(window_instance)

	if window_instance.has_method("populate"):
		window_instance.populate(populate_context)

	# (diagnostics removed)

	var pos_hint: String = context.get("positioning_hint", "")
	call_deferred("_deferred_position", window_instance, anchor_view, parent_window, pos_hint)
	
	if parent_window == null and anchor_view != null:
		var loc: LocationIdentifier = populate_context.get("location")
		if loc == null:
			loc = populate_context.get("target_location")
		_track_inspection_anchor(window_instance, anchor_view, loc)


# --- HELPER FUNCTIONS ---


func _deferred_position(window: Control, anchor: Control, parent_window: Control, pos_hint: String = "") -> void:
	if not is_instance_valid(window): return
	# Ensure layout has settled for the newly added window before measuring
	await get_tree().process_frame

	var position: Vector2
	# SIMPLIFIED RULE: If a parent window is provided, ALWAYS position relative to it.
	# This makes child windows independent of scene structure and canvas layers of anchors.
	if is_instance_valid(parent_window):
		# If caller requests parent-based placement (e.g., equipped items), ignore anchor.
		if pos_hint == "use_parent_window":
			position = _calculate_child_window_position(parent_window, window)
		# Prefer anchor-relative placement when anchor is available; clamp to viewport.
		elif is_instance_valid(anchor):
			position = _calculate_child_window_position_from_anchor(parent_window, anchor, window)
		else:
			position = _calculate_child_window_position(parent_window, window)
	elif is_instance_valid(anchor):
		# Root-anchored windows (no parent): allow specific hints; otherwise use general placement
		if pos_hint == "center_over_anchor":
			position = _calculate_centered_over_anchor(anchor, window)
		elif pos_hint == "top_center_over_anchor":
			position = _calculate_top_center_over_anchor(anchor, window)
		elif pos_hint == "left_of_anchor":
			position = _calculate_left_of_anchor(anchor, window)
		else:
			position = _calculate_window_position(anchor, window)
	else: # It's a root fixed-position window (Inventory, etc.)
		var viewport_rect = get_viewport().get_visible_rect()
		var vp_pos: Vector2 = Vector2(viewport_rect.position)
		var vp_size: Vector2 = Vector2(viewport_rect.size)
		position = vp_pos + vp_size / 2.0 - _get_window_size(window) / 2.0

	# Set position in screen space accounting for canvas transforms
	_set_window_screen_position(window, position)
	# Second pass: after the window is visible and fully laid out, finalize position
	call_deferred("_finalize_position", window, anchor, parent_window, pos_hint)

func _finalize_position(window: Control, anchor: Control, parent_window: Control, pos_hint: String = "") -> void:
	if not is_instance_valid(window): return
	await get_tree().process_frame
	var position: Vector2
	# Keep the simplified parent-first rule for child windows
	if is_instance_valid(parent_window):
		if pos_hint == "use_parent_window":
			position = _calculate_child_window_position(parent_window, window)
		elif is_instance_valid(anchor):
			position = _calculate_child_window_position_from_anchor(parent_window, anchor, window)
		else:
			position = _calculate_child_window_position(parent_window, window)
	elif is_instance_valid(anchor):
		if pos_hint == "center_over_anchor":
			position = _calculate_centered_over_anchor(anchor, window)
		elif pos_hint == "top_center_over_anchor":
			position = _calculate_top_center_over_anchor(anchor, window)
		elif pos_hint == "left_of_anchor":
			position = _calculate_left_of_anchor(anchor, window)
		else:
			position = _calculate_window_position(anchor, window)
	else:
		var viewport_rect = get_viewport().get_visible_rect()
		var vp_pos: Vector2 = Vector2(viewport_rect.position)
		var vp_size: Vector2 = Vector2(viewport_rect.size)
		position = vp_pos + vp_size / 2.0 - _get_window_size(window) / 2.0
	_set_window_screen_position(window, position)
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

# Context-sensitive parent resolver used by _open_contextual_window
func _resolve_parent_window(anchor_view: Control, populate_context: Dictionary) -> Control:
	# 1) Explicit parent by instance_id (authoritative)
	var explicit_id: int = populate_context.get("target_parent_window_id", -1)
	if explicit_id != -1:
		for w in _active_inspection_group:
			if is_instance_valid(w) and w.get_instance_id() == explicit_id:
				return w
		# If explicit id was provided but not found, fall back below.

	# 2) Inside UnitInspection context: choose the nearest UnitInspectionWindow already on the stack
	# Windows are siblings under the modal layer, so we cannot rely on ancestry here.
	var inside_unit: bool = populate_context.get("is_inside_unit_inspection", false)
	if inside_unit:
		for i in range(_active_inspection_group.size() - 1, -1, -1):
			var w = _active_inspection_group[i]
			if is_instance_valid(w) and w is UnitInspectionWindow:
				return w

	# 3) Structural fallback: nearest tracked inspection window
	var fallback = _find_ancestor_inspection_window(anchor_view)
	return fallback

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
			var meta_loc: LocationIdentifier = node.get_meta("location_identifier")
			if _locations_equal(meta_loc, loc):
				return node as Control
	return null

# Helper: compare two LocationIdentifier values safely (by fields)
func _locations_equal(a, b) -> bool:
	if a == null or b == null:
		return false
	# Field-wise comparison via Object.get() to avoid relying on reference equality
	var a_container: StringName = a.get("container") if a is Object else &""
	var b_container: StringName = b.get("container") if b is Object else &""
	var a_index: int = a.get("index") if a is Object else -1
	var b_index: int = b.get("index") if b is Object else -1
	var a_unit: String = a.get("unit_uuid") if a is Object else ""
	var b_unit: String = b.get("unit_uuid") if b is Object else ""
	return a_container == b_container and a_index == b_index and a_unit == b_unit

func _get_inventory_populate_context() -> Dictionary:
	var is_battle = GameManager.is_in_battle
	var inventory_data: Dictionary = {}
	var title = ""
	if is_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		if is_instance_valid(bm): inventory_data = bm.get_battle_inventory()
		title = "Battle Inventory"
	else:
		var run_state = GameManager.run_state
		if is_instance_valid(run_state): inventory_data = run_state.get_run_inventory_containers()
		title = "Run Inventory"
	return {"inventory": inventory_data, "is_battle_context": is_battle, "title": title, "is_interactive": true}

func _get_discard_pile_populate_context() -> Dictionary:
	var inventory_data: Array = []
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		if is_instance_valid(bm): inventory_data = bm.get_discard_pile_inventory()
	return {"inventory": inventory_data, "is_battle_context": GameManager.is_in_battle, "title": "Discard Pile", "is_interactive": false}

func _derive_window_payload(loc: LocationIdentifier, source_view: Control) -> Dictionary:
	var payload: Dictionary = {}
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
			if loc.container == &"EnemyLineup":
				context["is_enemy_context"] = true
		elif def.category == &"ITEM":
			window_type = &"ItemInspection"
			context = {"source_view": source_view, "instance": instance, "location": loc}
			# Equipped items: prefer positioning relative to the parent UnitInspectionWindow,
			# not the tiny equipped slot view. Provide a hint so positioning prefers the parent window rect.
			if loc.container == C.CONTAINER_EQUIPPED_ITEM:
				# Augment context so WindowManager can resolve the correct parent window reliably.
				var unit_parent: Control = find_ancestor_window_for_view(source_view)
				if is_instance_valid(unit_parent) and unit_parent is UnitInspectionWindow:
					context["is_inside_unit_inspection"] = true
					context["target_parent_window_id"] = unit_parent.get_instance_id()
				payload["positioning_hint"] = "use_parent_window"
		elif def.category == &"TRINKET":
			window_type = &"ItemInspection" # Reuse ItemInspection for trinkets
			context = {"source_view": source_view, "instance": instance, "location": loc}
		else: return {}
	elif source_view.has_meta("effect_definition"):
		var effect_def: Variant = source_view.get_meta("effect_definition")
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
func _track_inspection_anchor(window_instance: Control, anchor: Control, loc: LocationIdentifier) -> void:
	if not is_instance_valid(window_instance) or not is_instance_valid(anchor): return
	var window_id = window_instance.get_instance_id()
	var geom_callable := Callable(self, "_on_inspection_anchor_moved").bind(window_instance, anchor)
	if not anchor.is_connected("item_rect_changed", geom_callable):
		anchor.item_rect_changed.connect(geom_callable, CONNECT_DEFERRED)
	var freed_callable := Callable(self, "_on_inspection_anchor_freed").bind(window_id, anchor.get_instance_id(), loc, geom_callable)
	if not anchor.is_connected("tree_exited", freed_callable):
		anchor.tree_exited.connect(freed_callable, CONNECT_DEFERRED)
	_tracked_windows[window_id] = {"anchor": anchor, "geom_callable": geom_callable, "freed_callable": freed_callable}

func stop_tracking_window(window_id: int) -> void:
	if not _tracked_windows.has(window_id): return
	var tracking_info = _tracked_windows[window_id]
	var anchor = tracking_info["anchor"]
	if is_instance_valid(anchor):
		if anchor.is_connected("item_rect_changed", tracking_info["geom_callable"]):
			anchor.item_rect_changed.disconnect(tracking_info["geom_callable"])
		if anchor.is_connected("tree_exited", tracking_info["freed_callable"]):
			anchor.tree_exited.disconnect(tracking_info["freed_callable"])
	_tracked_windows.erase(window_id)

func _on_inspection_anchor_moved(window_instance: Control, anchor: Control) -> void:
	if is_instance_valid(anchor) and is_instance_valid(window_instance):
		var pos: Vector2 = _calculate_window_position(anchor, window_instance)
		_set_window_screen_position(window_instance, pos)


func _on_inspection_anchor_freed(window_id: int, old_anchor_id: int, _loc: LocationIdentifier, geom_callable: Callable) -> void:
	var old_anchor = instance_from_id(old_anchor_id)
	var window_instance = instance_from_id(window_id)
	if not is_instance_valid(window_instance):
		return
	if is_instance_valid(old_anchor) and old_anchor.is_connected("item_rect_changed", geom_callable):
		old_anchor.item_rect_changed.disconnect(geom_callable)
	if is_instance_valid(window_instance):
		var suppressed_for_id: bool = GlobalInteractionRouter.is_close_suppressed_for_window_id(window_id)
		var suppressed_now: bool = GlobalInteractionRouter.is_close_suppressed_now()
		request_close_inspection_window(window_instance, &"ANCHOR_FREED")

# FINAL FIX: This function is now correctly defined and used for lifecycle cleanup.
func _register_window(window_instance: Control, is_modal: bool) -> void:
	if not is_instance_valid(window_instance): return
	var freed_callable := Callable(self, "_on_window_freed").bind(window_instance.get_instance_id(), is_modal)
	if not window_instance.is_connected("tree_exited", freed_callable):
		window_instance.tree_exited.connect(freed_callable, CONNECT_DEFERRED)

func _on_window_freed(window_id: int, was_modal: bool) -> void:
	if not was_modal:
		stop_tracking_window(window_id)
	var stack = _modal_stack if was_modal else _active_inspection_group
	for i in range(stack.size() - 1, -1, -1):
		var window = stack[i]
		if not is_instance_valid(window) or window.get_instance_id() == window_id:
			stack.remove_at(i)

func _close_top_modal() -> void:
	if not _modal_stack.is_empty():
		var window = _modal_stack.pop_back()
		if is_instance_valid(window):
			window.queue_free()
		return

func close_top_contextual_window() -> void:
	if not _active_inspection_group.is_empty():
		var top_window = _active_inspection_group.back()
		if is_instance_valid(top_window):
			top_window.queue_free()

func _close_all_windows() -> void:
	close_all_inspection_windows()
	while not _modal_stack.is_empty():
		_close_top_modal()

func _calculate_window_position(source_view: Control, new_window: Control) -> Vector2:
	if not is_instance_valid(source_view): return Vector2.ZERO
	var src = _get_screen_rect(source_view)
	var win_sz = _get_window_size(new_window)
	var viewport_rect = get_viewport().get_visible_rect()
	var vp_center = viewport_rect.get_center()
	
	# Horizontal: place on the side opposite to the source half
	var place_right: bool = src.get_center().x <= vp_center.x
	var x: float = (src.end.x + INSPECTION_WINDOW_MARGIN) if place_right else (src.position.x - win_sz.x - INSPECTION_WINDOW_MARGIN)
	
	# Vertical alignment: align to top if source is on the top half; else align bottom
	var align_top: bool = src.get_center().y <= vp_center.y
	var y: float = src.position.y if align_top else (src.end.y - win_sz.y)
	
	return _clamp_window_to_viewport(Vector2(x, y), win_sz)

# Position child relative to its anchor, but decide side/top based on the parent window's quadrant.
func _calculate_child_window_position_from_anchor(parent_window: Control, anchor: Control, child_window: Control) -> Vector2:
	var parent_rect = _get_screen_rect(parent_window)
	var anchor_rect = _get_screen_rect(anchor)
	var child_sz = _get_window_size(child_window)
	var viewport_rect = get_viewport().get_visible_rect()
	var vp_center = viewport_rect.get_center()
	
	# Decide side/top using the ANCHOR's quadrant to keep behavior consistent with root-anchored windows.
	var place_right: bool = anchor_rect.get_center().x <= vp_center.x
	var x: float = (anchor_rect.end.x + INSPECTION_WINDOW_MARGIN) if place_right else (anchor_rect.position.x - child_sz.x - INSPECTION_WINDOW_MARGIN)
	
	var align_top: bool = anchor_rect.get_center().y <= vp_center.y
	var y: float = anchor_rect.position.y if align_top else (anchor_rect.end.y - child_sz.y)
	
	return _clamp_window_to_viewport(Vector2(x, y), child_sz)

# Position helper to center a window over its anchor, clamped to the viewport with a small margin
func _calculate_centered_over_anchor(anchor: Control, new_window: Control) -> Vector2:
	var anchor_rect = _get_screen_rect(anchor)
	var window_size = _get_window_size(new_window)
	var desired = anchor_rect.get_center() - window_size / 2.0
	return _clamp_window_to_viewport(desired, window_size)

# Position helper to place window centered horizontally above the anchor (top-center), clamped to viewport
func _calculate_top_center_over_anchor(anchor: Control, new_window: Control) -> Vector2:
	var viewport_rect = get_viewport().get_visible_rect()
	var anchor_rect = _get_screen_rect(anchor)
	var window_size = _get_window_size(new_window)
	var margin: float = INSPECTION_WINDOW_MARGIN
	
	# Center horizontally
	var x: float = anchor_rect.get_center().x - window_size.x / 2.0
	
	# Vertical: prefer above, flip if needed
	var above_y: float = anchor_rect.position.y - window_size.y - margin
	var below_y: float = anchor_rect.end.y + margin
	
	var viewport_top: float = float(viewport_rect.position.y) + margin
	var viewport_bottom: float = float(viewport_rect.end.y) - window_size.y - margin
	
	var y: float
	if above_y >= viewport_top:
		y = above_y
	elif below_y <= viewport_bottom:
		y = below_y
	else:
		# Neither fits fully; choose the option with more available space
		var space_above: float = float(anchor_rect.position.y) - float(viewport_rect.position.y) - margin
		var space_below: float = float(viewport_rect.end.y) - float(anchor_rect.end.y) - margin
		y = above_y if space_above >= space_below else below_y
		
	return _clamp_window_to_viewport(Vector2(x, y), window_size)

# Position helper to place window to the left of the anchor with sensible vertical alignment and viewport clamping.
func _calculate_left_of_anchor(anchor: Control, new_window: Control) -> Vector2:
	var viewport_rect = get_viewport().get_visible_rect()
	var anchor_rect = _get_screen_rect(anchor)
	var win_sz = _get_window_size(new_window)
	var margin: float = INSPECTION_WINDOW_MARGIN
	var viewport_left: float = float(viewport_rect.position.x) + margin
	
	# Try left of anchor; if it doesn't fit, fall back to right of anchor.
	var x_left: float = anchor_rect.position.x - win_sz.x - margin
	var x: float = x_left if x_left >= viewport_left else (anchor_rect.end.x + margin)
	
	# Vertical alignment: align top if anchor is in top half, else align bottom.
	var vp_center_y: float = float(viewport_rect.get_center().y)
	var align_top: bool = anchor_rect.get_center().y <= vp_center_y
	var y: float = (anchor_rect.position.y if align_top else (anchor_rect.end.y - win_sz.y))
	
	return _clamp_window_to_viewport(Vector2(x, y), win_sz)

func _get_screen_rect(ctrl: Control) -> Rect2:
	if not is_instance_valid(ctrl):
		return Rect2()
	var size := ctrl.size
	if size == Vector2.ZERO:
		var min_sz := ctrl.get_combined_minimum_size()
		if min_sz != Vector2.ZERO:
			size = min_sz
	var xf := ctrl.get_global_transform_with_canvas()
	var p0: Vector2 = xf * Vector2(0, 0)
	var p1: Vector2 = xf * Vector2(size.x, 0)
	var p2: Vector2 = xf * Vector2(0, size.y)
	var p3: Vector2 = xf * Vector2(size.x, size.y)
	var min_x = min(p0.x, min(p1.x, min(p2.x, p3.x)))
	var max_x = max(p0.x, max(p1.x, max(p2.x, p3.x)))
	var min_y = min(p0.y, min(p1.y, min(p2.y, p3.y)))
	var max_y = max(p0.y, max(p1.y, max(p2.y, p3.y)))
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _set_window_screen_position(window: Control, screen_pos: Vector2) -> void:
	# Convert a desired screen-space top-left position into the window's parent/canvas space
	var parent := window.get_parent()
	if parent is CanvasItem:
		# Ideal path: transform screen -> parent local, then assign
		var parent_xf := (parent as CanvasItem).get_global_transform_with_canvas()
		var parent_inv := parent_xf.affine_inverse()
		var local_in_parent: Vector2 = parent_inv * screen_pos
		window.position = local_in_parent
	else:
		# Fallback (e.g., parent is CanvasLayer): screen space == global space
		window.global_position = screen_pos

func _find_canvas_layer(node: Node) -> CanvasLayer:
	var current := node
	while is_instance_valid(current):
		if current is CanvasLayer:
			return current
		current = current.get_parent()
	return null

func _get_window_size(window: Control) -> Vector2:
	var sz := window.size
	if sz == Vector2.ZERO:
		# Use combined minimum size as a reliable fallback before layout settles
		var min_sz := window.get_combined_minimum_size()
		if min_sz != Vector2.ZERO:
			return min_sz
	return sz

func _calculate_child_window_position(parent_window: Control, child_window: Control) -> Vector2:
	# Deterministic quadrant-based placement relative to parent window's rect
	var viewport_rect = get_viewport().get_visible_rect()
	var vp_center = viewport_rect.get_center()
	var parent_rect = _get_screen_rect(parent_window)
	var child_sz = _get_window_size(child_window)
	var place_right: bool = parent_rect.get_center().x <= vp_center.x
	var x: float = (parent_rect.end.x + INSPECTION_WINDOW_MARGIN) if place_right else (parent_rect.position.x - child_sz.x - INSPECTION_WINDOW_MARGIN)
	var align_top: bool = parent_rect.get_center().y <= vp_center.y
	var y: float = parent_rect.position.y if align_top else (parent_rect.end.y - child_sz.y)
	var margin: float = INSPECTION_WINDOW_MARGIN
	x = clampf(x, viewport_rect.position.x + margin, viewport_rect.end.x - child_sz.x - margin)
	y = clampf(y, viewport_rect.position.y + margin, viewport_rect.end.y - child_sz.y - margin)
	return Vector2(x, y)

func _get_modal_layer() -> CanvasLayer:
	if not is_instance_valid(_modal_layer):
		_modal_layer = get_tree().get_first_node_in_group("modal_layer")
		if not is_instance_valid(_modal_layer):
			_modal_layer = CanvasLayer.new()
			_modal_layer.name = "ModalLayerFailsafe"
			get_tree().root.add_child(_modal_layer)
	return _modal_layer

func _clamp_window_to_viewport(pos: Vector2, size: Vector2) -> Vector2:
	var viewport_rect = get_viewport().get_visible_rect()
	var margin: float = INSPECTION_WINDOW_MARGIN
	var x = clampf(pos.x, viewport_rect.position.x + margin, viewport_rect.end.x - size.x - margin)
	var y = clampf(pos.y, viewport_rect.position.y + margin, viewport_rect.end.y - size.y - margin)
	return Vector2(x, y)
