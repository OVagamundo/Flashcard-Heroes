# res://scripts/WindowManager.gd
extends Node

const INSPECTION_WINDOW_MARGIN = 20.0

var _window_scenes: Dictionary = {
	# --- Hermetic Modals (Managed by _modal_stack, use open_modal_window) ---
	&"EndBattlePopup": load("res://scenes/EndBattlePopup.tscn"),
	&"RunCompletePopup": load("res://scenes/RunCompletePopup.tscn"),
	&"FlashcardMinigame": load("res://scenes/FlashcardMinigame.tscn"),
	&"ResultsPopup": load("res://scenes/ResultsPopup.tscn"),
	&"TutorialPopup": load("res://scenes/TutorialPopup.tscn"),
	
	# --- Contextual Windows (Managed by _active_inspection_group) ---
	&"Inventory": load("res://scenes/InventoryWindow.tscn"),
	&"DiscardPile": load("res://scenes/DiscardPileWindow.tscn"),
	&"ChoiceWindow": load("res://scenes/ChoiceWindow.tscn"),
	&"UnitInspection": load("res://scenes/UnitInspectionWindow.tscn"),
	&"ItemInspection": load("res://scenes/ItemInspectionWindow.tscn"),
	&"TraitInspection": load("res://scenes/TraitInspectionWindow.tscn"), # NEW
	&"EffectInspection": load("res://scenes/EffectInspectionWindow.tscn"),
	&"Options": load("res://scenes/OptionsWindow.tscn"),
}

var _modal_stack: Array[Control] = []
var _active_inspection_group: Array[Control] = []

var _tracked_windows: Dictionary = {}
var _modal_layer: CanvasLayer = null

var _persistent_inventory_window: Control = null
var _persistent_discard_pile_window: Control = null

signal window_closed(window: Control)


func _ready() -> void:
	# FINAL FIX: Input processing is REMOVED. The WindowManager is now a pure service.
	# It no longer interprets raw input; it only executes commands from the GIR.
	set_process_input(false)

	# FINAL FIX: Signal connections now point to the clean, public API functions,
	# and all old, internal handler functions (_on_..._requested) have been removed.
	SignalBus.inspect_inventory_requested.connect(open_inventory_window)
	SignalBus.display_discard_pile_requested.connect(open_discard_pile_window)
	SignalBus.inspection_requested.connect(open_inspection_window)
	SignalBus.trait_inspection_requested.connect(open_trait_inspection_window) # NEW
	SignalBus.open_choice_window_requested.connect(open_choice_window)
	SignalBus.close_modal_requested.connect(_close_top_modal)
	SignalBus.close_top_contextual_requested.connect(close_top_contextual_window)
	
	SignalBus.main_scene_requested.connect(_close_all_windows)
	SignalBus.loadout_scene_requested.connect(_close_all_windows)
	SignalBus.title_scene_requested.connect(_close_all_windows)
	SignalBus.path_choice_scene_requested.connect(close_all_inspection_windows)

	call_deferred("_setup_persistent_inventory")
	call_deferred("_setup_persistent_discard_pile")

func _setup_persistent_inventory() -> void:
	if not _window_scenes.has(&"Inventory"):
		return
	_persistent_inventory_window = _window_scenes[&"Inventory"].instantiate()
	_persistent_inventory_window.name = "PersistentInventoryWindow" # Good for debugging
	_persistent_inventory_window.set_meta("window_type", &"Inventory")
	_get_modal_layer().add_child(_persistent_inventory_window)
	_persistent_inventory_window.hide()
	
	# Keep the root window on screen (0,0) so the base mask is visible when shown.
	# The inner panel will animate its offset_y coordinates.
	_persistent_inventory_window.position = Vector2.ZERO
	_persistent_inventory_window.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _setup_persistent_discard_pile() -> void:
	if not _window_scenes.has(&"DiscardPile"):
		return
	_persistent_discard_pile_window = _window_scenes[&"DiscardPile"].instantiate()
	_persistent_discard_pile_window.name = "PersistentDiscardPileWindow"
	_persistent_discard_pile_window.set_meta("window_type", &"DiscardPile")
	_get_modal_layer().add_child(_persistent_discard_pile_window)
	_persistent_discard_pile_window.hide()
	# Root starts off-screen right as defined in .tscn (position.x = 1920)
	_persistent_discard_pile_window.mouse_filter = Control.MOUSE_FILTER_IGNORE


# --- PUBLIC API ---

# This function is ONLY for true "Hermetic Modals" that halt game flow.
func open_modal_window(type: StringName, context: Dictionary = {}) -> Control:
	if not _window_scenes.has(type):
		push_error("[WindowManager] ERROR: Window type not found in _window_scenes: " + str(type))
		return null
	_close_all_windows() # True modals are exclusive.

	var window_instance = _window_scenes[type].instantiate()
	_get_modal_layer().add_child(window_instance)
	window_instance.z_index = 100 # Ensure modal renders above elevated local z-indexes
	_modal_stack.push_back(window_instance)
	_register_window(window_instance, true)
	
	if window_instance.has_method("populate"):
		window_instance.populate(context)

	# Modals usually don't wait for layout, but we need size for pivot.
	# Let's wait a frame to be safe, similar to contextual windows, or just assume size is ready if it's a scene root with size set.
	# For safety and consistency with contextual logic:
	_animate_modal_open_deferred(window_instance)

	return window_instance

func _animate_modal_open_deferred(window: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(window):
		_animate_window_open(window)


## Opens a tutorial popup as an overlay WITHOUT closing existing windows.
## This allows tutorials to appear on top of FlashcardMinigame, InventoryWindow, etc.
func open_tutorial_overlay(context: Dictionary = {}) -> Control:
	if not _window_scenes.has(&"TutorialPopup"):
		push_error("[WindowManager] TutorialPopup not found in _window_scenes")
		return null
	
	# Do NOT close existing windows - tutorials overlay on top
	var window_instance = _window_scenes[&"TutorialPopup"].instantiate()
	_get_modal_layer().add_child(window_instance)
	window_instance.z_index = 100 # Ensure tutorial renders above all
	# Add to modal stack so it can be properly cleaned up
	_modal_stack.push_back(window_instance)
	_register_window(window_instance, true)
	
	if window_instance.has_method("populate"):
		window_instance.populate(context)
	
	_animate_modal_open_deferred(window_instance)
	
	return window_instance

# Public entry point for the Inventory Window.
func open_inventory_window() -> void:
	var win = _persistent_inventory_window
	if not is_instance_valid(win):
		# Fallback if uninitialized
		var context: Dictionary = {
			"window_type": &"Inventory",
			"populate_context": _get_inventory_populate_context()
		}
		_open_contextual_window(context)
		return

	var opening: bool = win.has_meta(_WM_META_OPENING) and bool(win.get_meta(_WM_META_OPENING))
	var closing: bool = win.has_meta(_WM_META_CLOSING) and bool(win.get_meta(_WM_META_CLOSING))
	
	if win in _active_inspection_group:
		if opening or not closing:
			return # Already open or currently opening

	# We are about to open the inventory, so close all other contexts gently
	for iter_win in _active_inspection_group:
		if is_instance_valid(iter_win) and iter_win != win:
			stop_tracking_window(iter_win.get_instance_id())
			_queue_free_with_optional_inventory_animation(iter_win)
	
	var ctx = _get_inventory_populate_context()
	if win.has_method("populate"):
		win.populate(ctx)
	
	if not _active_inspection_group.has(win):
		_active_inspection_group.push_back(win)
		
	_animate_inventory_window_open(win)

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
	var win = _persistent_discard_pile_window
	if not is_instance_valid(win):
		return

	var opening: bool = win.has_meta(_WM_META_OPENING) and bool(win.get_meta(_WM_META_OPENING))
	var closing: bool = win.has_meta(_WM_META_CLOSING) and bool(win.get_meta(_WM_META_CLOSING))

	# Toggle: if already open (and not currently closing), close it
	if win in _active_inspection_group:
		if opening or not closing:
			# Already open — close it
			var idx = _active_inspection_group.find(win)
			if idx != -1:
				_active_inspection_group.remove_at(idx)
			_animate_discard_pile_close(win)
			return

	var ctx = _get_discard_pile_populate_context()
	if win.has_method("populate"):
		win.populate(ctx)

	if not _active_inspection_group.has(win):
		_active_inspection_group.push_back(win)

	_animate_discard_pile_open(win)

func get_persistent_discard_pile_window() -> Control:
	return _persistent_discard_pile_window

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

# Public entry point for Trait Inspection.
func open_trait_inspection_window(trait_id: String, source_view: Control) -> void:
	if not is_instance_valid(source_view): return
	
	# Fetch active count from BattleManager
	var bm = get_tree().get_first_node_in_group("battle_manager")
	if not is_instance_valid(bm): return
	
	# TODO: BattleManager.get_active_traits takes a team ("PLAYER" or "ENEMY")
	# We need to intuit the team. If Traits are only for player for now:
	# But actually BattleView creates traits for both sides.
	# We can check parent name? BattleView > TraitHUD > PlayerTraits/EnemyTraits
	# source_view is the TraitTracker.
	var team = "PLAYER"
	var parent_container = source_view.get_parent()
	if is_instance_valid(parent_container):
		if parent_container.name == "EnemyTraits":
			team = "ENEMY"
	
	var all_traits: Dictionary = bm.get_active_traits(team)
	var count = all_traits.get(trait_id, 0)
	
	var context: Dictionary = {
		"window_type": &"TraitInspection",
		"populate_context": {
			"trait_id": trait_id,
			"source_view": source_view,
			"count": count
		},
		"anchor_view": source_view
	}
	# Use standard positioning logic (will use _track_inspection_anchor because parent_window is null)
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
			_queue_free_with_optional_inventory_animation(child_window)

# Back-compat API expected by GIR: resolve parent by instance_id and prune its children
func close_child_windows(_window_group_id: int, parent_window_id: int = -1) -> void:
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
	# AUDIO HOOK: Window close sound (play once even if multiple windows)
	if not _active_inspection_group.is_empty():
		Audio.play_sfx("ui_window_close")
	
	for window in _active_inspection_group:
		if is_instance_valid(window):
			stop_tracking_window(window.get_instance_id())
			_queue_free_with_optional_inventory_animation(window)

	# no-op if already empty

# Public query function for the GIR.
func is_any_inspection_window_open() -> bool:
	for i in range(_active_inspection_group.size() - 1, -1, -1):
		if not is_instance_valid(_active_inspection_group[i]):
			_active_inspection_group.remove_at(i)
	return not _active_inspection_group.is_empty()

# Public API: check if ANY base inventory window (Battle, Run, or Discard Pile) is currently open
func is_any_inventory_window_open() -> bool:
	for i in range(_active_inspection_group.size() - 1, -1, -1):
		var win = _active_inspection_group[i]
		if not is_instance_valid(win):
			continue
		if win.has_meta("window_type"):
			var type = win.get_meta("window_type")
			if type == &"Inventory" or type == &"DiscardPile":
				return true
		# Fallbacks if meta is missing
		if win == _persistent_inventory_window or win == _persistent_discard_pile_window:
			return true
	return false

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
func request_close_inspection_window(window: Control, _cause: StringName = &"") -> void:
	if not is_instance_valid(window):
		return
	var window_id := window.get_instance_id()
	# Respect GIR suppression to avoid premature closures during interactions.
	var suppressed_for_id: bool = GlobalInteractionRouter.is_close_suppressed_for_window_id(window_id)
	var suppressed_now: bool = GlobalInteractionRouter.is_close_suppressed_now()
	if suppressed_for_id or suppressed_now:
		return
	stop_tracking_window(window_id)
	_queue_free_with_optional_inventory_animation(window)


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
	window_instance.z_index = 100 # Render above local z-index elevations (like hovered gachaballs = 40)
	window_instance.set_meta("window_type", window_type) # Tag for identification
	
	_register_window(window_instance, false) # Register as NON-modal.
	_active_inspection_group.push_back(window_instance)
	
	# AUDIO HOOK: Window open sound is now handled in _animate_window_open
	# Audio.play_sfx("ui_window_open")

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
	
	# ASYNC SAFETY CHECK: Window might have been freed during the await frame
	if not is_instance_valid(window): return

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
	
	# ASYNC SAFETY CHECK: Window might have been freed during the await frame
	if not is_instance_valid(window): return
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
	_set_window_screen_position(window, position)
	_animate_window_open(window)

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
		elif def.category == &"CONSUMABLE":
			window_type = &"ItemInspection" # Reuse ItemInspection for consumables
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
	var anchor_id = anchor.get_instance_id()
	var geom_callable := Callable(self , "_on_inspection_anchor_moved").bind(window_id, anchor_id)
	if not anchor.is_connected("item_rect_changed", geom_callable):
		anchor.item_rect_changed.connect(geom_callable, CONNECT_DEFERRED)
	var freed_callable := Callable(self , "_on_inspection_anchor_freed").bind(window_id, anchor_id, loc, geom_callable)
	if not anchor.is_connected("tree_exited", freed_callable):
		anchor.tree_exited.connect(freed_callable, CONNECT_DEFERRED)
	_tracked_windows[window_id] = {"anchor": anchor, "geom_callable": geom_callable, "freed_callable": freed_callable}

func stop_tracking_window(window_id: int) -> void:
	# Emit signal that window is closing/stopping tracking
	# We try to get the instance to pass it.
	var window = instance_from_id(window_id)
	if is_instance_valid(window) and window is Control:
		window_closed.emit(window)

	if not _tracked_windows.has(window_id): return
	var tracking_info = _tracked_windows[window_id]
	var anchor = tracking_info["anchor"]
	if is_instance_valid(anchor):
		if anchor.is_connected("item_rect_changed", tracking_info["geom_callable"]):
			anchor.item_rect_changed.disconnect(tracking_info["geom_callable"])
		if anchor.is_connected("tree_exited", tracking_info["freed_callable"]):
			anchor.tree_exited.disconnect(tracking_info["freed_callable"])
	_tracked_windows.erase(window_id)

func _on_inspection_anchor_moved(window_id: int, anchor_id: int) -> void:
	var window_instance = instance_from_id(window_id) as Control
	var anchor = instance_from_id(anchor_id) as Control
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
		var _suppressed_for_id: bool = GlobalInteractionRouter.is_close_suppressed_for_window_id(window_id)
		var _suppressed_now: bool = GlobalInteractionRouter.is_close_suppressed_now()
		request_close_inspection_window(window_instance, &"ANCHOR_FREED")

# FINAL FIX: This function is now correctly defined and used for lifecycle cleanup.
func _register_window(window_instance: Control, is_modal: bool) -> void:
	if not is_instance_valid(window_instance): return
	var freed_callable := Callable(self , "_on_window_freed").bind(window_instance.get_instance_id(), is_modal)
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
			# PROTECT BASE WINDOWS:
			# Inventory and DiscardPile are "Base" contextual windows.
			# They should never be popped by a generic "Back" or "Toggle" command (CLOSE_TOP).
			# They should only be closed by explicit navigation commands (CLOSE_ALL).
			if top_window.has_meta("window_type"):
				var type = top_window.get_meta("window_type")
				if type == &"Inventory" or type == &"DiscardPile":
					return
			_queue_free_with_optional_inventory_animation(top_window)

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

# --- UI ANIMATION ---

const UI_OPEN_REVEAL_SHADER = preload("res://assets/shaders/ui_open_reveal.gdshader")
const INVENTORY_WINDOW_OPEN_RISE_PX: float = 680.0
const INVENTORY_WINDOW_OPEN_OVERSHOOT_PX: float = 10.0
const INVENTORY_WINDOW_CLOSE_DROP_PX: float = 680.0
const INVENTORY_WINDOW_CLOSE_PULL_PX: float = 12.0
const _WM_META_OPENING: StringName = &"wm_opening"
const _WM_META_CLOSING: StringName = &"wm_closing"
const _WM_META_ANIM_TWEEN: StringName = &"wm_anim_tween"

# Discard pile slides horizontally from the right
const DISCARD_PILE_HIDDEN_X: float = 1920.0
const DISCARD_PILE_OPEN_X: float = 640.0

func _is_discard_pile_window(window: Control) -> bool:
	if not is_instance_valid(window):
		return false
	if window.has_meta("window_type") and window.get_meta("window_type") == &"DiscardPile":
		return true
	return false

func _animate_discard_pile_open(window: Control) -> void:
	if not is_instance_valid(window): return
	if window.has_meta(_WM_META_OPENING) and bool(window.get_meta(_WM_META_OPENING)): return

	window.set_meta(_WM_META_OPENING, true)
	window.set_meta(_WM_META_CLOSING, false)

	# Start off-screen right and show
	window.position.x = DISCARD_PILE_HIDDEN_X
	window.show()
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_kill_inventory_motion_tween(window)
	Audio.play_sfx("ui_window_open")

	var tween: Tween = window.create_tween()
	window.set_meta(_WM_META_ANIM_TWEEN, tween)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween.tween_property(window, "position:x", DISCARD_PILE_OPEN_X, 0.45
		).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	tween.chain().tween_callback(func():
		if is_instance_valid(window):
			window.set_meta(_WM_META_OPENING, false)
			if window is DiscardPileWindow:
				window.call_deferred("on_window_opened")
			window.mouse_filter = Control.MOUSE_FILTER_STOP
			if window.has_meta(_WM_META_ANIM_TWEEN):
				window.remove_meta(_WM_META_ANIM_TWEEN)
	)

func _animate_discard_pile_close(window: Control) -> void:
	if not is_instance_valid(window): return
	if window.has_meta(_WM_META_CLOSING) and bool(window.get_meta(_WM_META_CLOSING)): return

	window.set_meta(_WM_META_OPENING, false)
	window.set_meta(_WM_META_CLOSING, true)
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_kill_inventory_motion_tween(window)

	var tween: Tween = window.create_tween()
	window.set_meta(_WM_META_ANIM_TWEEN, tween)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween.tween_property(window, "position:x", DISCARD_PILE_HIDDEN_X, 0.35
		).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)

	tween.chain().tween_callback(func():
		if is_instance_valid(window):
			window.set_meta(_WM_META_CLOSING, false)
			if window.has_meta(_WM_META_ANIM_TWEEN):
				window.remove_meta(_WM_META_ANIM_TWEEN)
			window.hide()
	)

func _is_inventory_window(window: Control) -> bool:
	if not is_instance_valid(window):
		return false
	if window.has_meta("window_type") and window.get_meta("window_type") == &"Inventory":
		return true
	if "InventoryWindow" in window.name:
		return true
	var script_ref: Script = window.get_script() as Script
	if script_ref != null:
		var script_path: String = script_ref.resource_path
		if script_path.ends_with("InventoryWindow.gd"):
			return true
	return false

func _queue_free_with_optional_inventory_animation(window: Control) -> void:
	if not is_instance_valid(window):
		return
	if window == _persistent_inventory_window:
		_animate_inventory_window_close(window)
		return
	if window == _persistent_discard_pile_window:
		var idx = _active_inspection_group.find(window)
		if idx != -1:
			_active_inspection_group.remove_at(idx)
		_animate_discard_pile_close(window)
		return
	if _animate_inventory_window_close(window):
		return
	window.queue_free()

func _kill_inventory_motion_tween(window: Control) -> void:
	if not is_instance_valid(window):
		return
	if not window.has_meta(_WM_META_ANIM_TWEEN):
		return
	var existing_tween: Tween = window.get_meta(_WM_META_ANIM_TWEEN) as Tween
	if is_instance_valid(existing_tween):
		existing_tween.kill()
	window.remove_meta(_WM_META_ANIM_TWEEN)

func _is_full_rect_anchored(control: Control) -> bool:
	return is_equal_approx(control.anchor_left, 0.0) \
		and is_equal_approx(control.anchor_top, 0.0) \
		and is_equal_approx(control.anchor_right, 1.0) \
		and is_equal_approx(control.anchor_bottom, 1.0)

func _apply_vertical_offset_delta(delta: float, control: Control, base_top: float, base_bottom: float) -> void:
	if not is_instance_valid(control):
		return
	control.offset_top = base_top + delta
	control.offset_bottom = base_bottom + delta

func _set_inventory_motion_delta(control: Control, use_offsets: bool, base_top: float, base_bottom: float, base_pos: Vector2, delta: float) -> void:
	if use_offsets:
		_apply_vertical_offset_delta(delta, control, base_top, base_bottom)
	else:
		control.position = base_pos + Vector2(0.0, delta)

func _tween_inventory_vertical_step(
	tween: Tween,
	control: Control,
	use_offsets: bool,
	base_top: float,
	base_bottom: float,
	base_pos: Vector2,
	from_delta: float,
	to_delta: float,
	duration: float,
	trans: Tween.TransitionType,
	_ease: Tween.EaseType
) -> void:
	if use_offsets:
		tween.tween_method(
			func(val): _apply_vertical_offset_delta(val, control, base_top, base_bottom),
			from_delta,
			to_delta,
			duration
		).set_trans(trans).set_ease(_ease)
	else:
		tween.tween_property(
			control,
			"position",
			base_pos + Vector2(0.0, to_delta),
			duration
		).set_trans(trans).set_ease(_ease)

func _animate_inventory_window_open(window: Control) -> void:
	if not is_instance_valid(window): return
	if window.has_meta(_WM_META_OPENING) and bool(window.get_meta(_WM_META_OPENING)): return
	
	window.set_meta(_WM_META_OPENING, true)
	window.set_meta(_WM_META_CLOSING, false)
	
	var anim_target: Control = window
	if window.has_method("get_window_to_animate"):
		var candidate = window.get_window_to_animate()
		if is_instance_valid(candidate):
			anim_target = candidate
			
	window.show()
	
	# Prevent interactions during the animation
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in window.get_children():
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_kill_inventory_motion_tween(window)
	
	Audio.play_sfx("ui_window_open")

	# Base layout is driven by anchors for the window.
	# The inner PanelContainer has an offset_top of 162 natively.
	var base_top: float = 162.0
	var base_bottom: float = -238.0
	
	# Start panel completely below screen
	var start_delta: float = get_viewport().get_visible_rect().size.y
	_apply_vertical_offset_delta(start_delta, anim_target, base_top, base_bottom)
	
	var tween: Tween = window.create_tween()
	window.set_meta(_WM_META_ANIM_TWEEN, tween)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Slide the panel container up to its authored offset (delta = 0)
	tween.tween_method(
		Callable(self , "_apply_vertical_offset_delta").bind(anim_target, base_top, base_bottom),
		start_delta,
		0.0,
		0.45
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(func():
		if is_instance_valid(window):
			window.set_meta(_WM_META_OPENING, false)
			
			# Jolt the physics balls (upward slam)
			if window is InventoryWindow:
				var upward_jolt = Vector2(0, -500)
				window.tier_1_physics.apply_jolt(upward_jolt)
				window.tier_2_physics.apply_jolt(upward_jolt)
				window.tier_3_physics.apply_jolt(upward_jolt)
			
			# Restore interactions once fully open
			window.mouse_filter = Control.MOUSE_FILTER_PASS
			for child in window.get_children():
				if child is PanelContainer:
					child.mouse_filter = Control.MOUSE_FILTER_PASS
				else:
					child.mouse_filter = Control.MOUSE_FILTER_IGNORE
					
			if window.has_meta(_WM_META_ANIM_TWEEN):
				window.remove_meta(_WM_META_ANIM_TWEEN)
	)

func _animate_inventory_window_close(window: Control) -> bool:
	if not _is_inventory_window(window): return false
	if not is_instance_valid(window): return true
	if window.has_meta(_WM_META_CLOSING) and bool(window.get_meta(_WM_META_CLOSING)): return true
	
	window.set_meta(_WM_META_OPENING, false)
	window.set_meta(_WM_META_CLOSING, true)
	
	var anim_target: Control = window
	if window.has_method("get_window_to_animate"):
		var candidate = window.get_window_to_animate()
		if is_instance_valid(candidate):
			anim_target = candidate
	
	# Block interactions out instantly
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in window.get_children():
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_kill_inventory_motion_tween(window)
	
	var base_top: float = 162.0
	var base_bottom: float = -238.0
	var final_delta: float = get_viewport().get_visible_rect().size.y
	
	var tween: Tween = window.create_tween()
	window.set_meta(_WM_META_ANIM_TWEEN, tween)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Slide the panel container back down
	tween.tween_method(
		Callable(self , "_apply_vertical_offset_delta").bind(anim_target, base_top, base_bottom),
		0.0,
		final_delta,
		0.35
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	
	tween.chain().tween_callback(func():
		if is_instance_valid(window):
			window.set_meta(_WM_META_CLOSING, false)
			if window.has_meta(_WM_META_ANIM_TWEEN):
				window.remove_meta(_WM_META_ANIM_TWEEN)
			if window == _persistent_inventory_window:
				window.hide()
				
				# Jolt the physics balls (downward slam)
				if window is InventoryWindow:
					var downward_jolt = Vector2(0, 400)
					window.tier_1_physics.apply_jolt(downward_jolt)
					window.tier_2_physics.apply_jolt(downward_jolt)
					window.tier_3_physics.apply_jolt(downward_jolt)
				
				var idx = _active_inspection_group.find(window)
				if idx != -1:
					_active_inspection_group.remove_at(idx)
			else:
				window.queue_free()
	)
	return true

func _animate_window_open(window: Control) -> void:
	if not is_instance_valid(window): return
	var root_window: Control = window
	var is_inventory_window: bool = _is_inventory_window(root_window)
	if is_inventory_window:
		_animate_inventory_window_open(root_window)
		return
	
	# If the window has specific logic to provide the animation target (e.g., inner panel vs root blocker), use it
	if window.has_method("get_window_to_animate"):
		window = window.get_window_to_animate()
		if not is_instance_valid(window): return

	
	# Prepare shader material
	var mat = ShaderMaterial.new()
	mat.shader = UI_OPEN_REVEAL_SHADER
	# Make sure it's unique so tweens don't conflict if we had shared resources (though new() handles that)
	window.material = mat
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("shine_strength", 0.5)
	mat.set_shader_parameter("shine_color", Color(1.0, 1.0, 1.0, 0.5))
	
	# Initial transform state
	window.scale = Vector2(0.95, 0.95)
	# Set pivot to center for nice scaling
	window.pivot_offset = window.size / 2.0
	
	# Initial visibility
	window.modulate.a = 1.0
	window.show()
	
	# Audio
	Audio.play_sfx("ui_window_open")
	
	# Tween
	# CORRECT IMPLEMENTATION: Bind tween to the window itself.
	# If the window is freed (e.g. closed mid-animation), the tween is automatically killed.
	# This prevents "Lambda capture freed" errors naturally without defensive checks.
	var tween = window.create_tween()
	
	# IMPORTANT: Ensure animation runs even if the game is paused
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Scale up slightly
	tween.tween_property(window, "scale", Vector2.ONE, 0.5)
	
	# Reveal via shader
	# Use a simpler ease for the wipe
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(mat, "shader_parameter/progress", 1.0, 0.5)
	
	# Cleanup
	# Safe to use lambda here because if window is freed, tween dies and this never runs.
	tween.chain().tween_callback(func():
		window.material = null
	)
