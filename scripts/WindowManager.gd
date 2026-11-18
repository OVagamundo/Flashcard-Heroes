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
	&"BattleInventory": load("res://scenes/BattleInventoryWindow.tscn"),
	&"DiscardPile": load("res://scenes/DiscardPileWindow.tscn"),
	&"ChoiceWindow": load("res://scenes/ChoiceWindow.tscn"),
	&"UnitInspection": load("res://scenes/UnitInspectionWindow.tscn"),
	&"ItemInspection": load("res://scenes/ItemInspectionWindow.tscn"),
	&"TraitInspection": load("res://scenes/TraitInspectionWindow.tscn"), # NEW
	&"EffectInspection": load("res://scenes/EffectInspectionWindow.tscn"),
	&"Options": load("res://scenes/OptionsWindow.tscn"),
}

var _modal_stack: Array[Control] = []
var _active_tutorial_overlay: TutorialPopup = null
var _pending_tutorial_overlays: Array[Dictionary] = []
var _active_inspection_group: Array[Control] = []
var _modal_child_windows: Dictionary = {}
var is_glossary_locked: bool = true
const _GlossaryTogglePillScene = preload("res://scenes/GlossaryTogglePill.tscn")
var _glossary_pill: Control = null
const INSPECTION_WINDOW_WIDTH: float = 360.0
const GLOSSARY_WINDOW_WIDTH: float = 260.0

var _tracked_windows: Dictionary = {}
var _modal_layer: CanvasLayer = null
var _background_ui_layer: CanvasLayer = null
var _vfx_layer: CanvasLayer = null

var _persistent_inventory_window: Control = null
var _persistent_battle_inventory_window: Control = null
var _persistent_discard_pile_window: Control = null

signal window_closed(window: Control)


func _ready() -> void:
	# FINAL FIX: Input processing is REMOVED. The WindowManager is now a pure service.
	# It no longer interprets raw input; it only executes commands from the GIR.
	set_process_input(false)
	process_mode = Node.PROCESS_MODE_ALWAYS

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
	SignalBus.path_choice_scene_requested.connect(_close_all_windows)

	call_deferred("_setup_persistent_inventory")
	call_deferred("_setup_persistent_discard_pile")
	
	# Create/destroy the battle inventory window when entering/leaving battle
	if SignalBus.has_signal("battle_state_changed"):
		SignalBus.battle_state_changed.connect(_on_battle_state_changed_wm)
	window_closed.connect(_on_window_closed_options_check)

func _setup_persistent_inventory() -> void:
	if not _window_scenes.has(&"Inventory"):
		return
	_persistent_inventory_window = _window_scenes[&"Inventory"].instantiate()
	_persistent_inventory_window.name = "PersistentInventoryWindow" # Good for debugging
	_persistent_inventory_window.set_meta("window_type", &"Inventory")
	_get_background_ui_layer().add_child(_persistent_inventory_window)
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
	_get_background_ui_layer().add_child(_persistent_discard_pile_window)
	_persistent_discard_pile_window.hide()
	# Root starts off-screen right as defined in .tscn (position.x = 1920)
	_persistent_discard_pile_window.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _setup_persistent_battle_inventory() -> void:
	if is_instance_valid(_persistent_battle_inventory_window):
		return
	if not _window_scenes.has(&"BattleInventory"):
		return
	_persistent_battle_inventory_window = _window_scenes[&"BattleInventory"].instantiate()
	_persistent_battle_inventory_window.name = "PersistentBattleInventoryWindow"
	_persistent_battle_inventory_window.set_meta("window_type", &"Inventory")
	_get_background_ui_layer().add_child(_persistent_battle_inventory_window)
	# Starts hidden — the window stays in tree for physics persistence
	_persistent_battle_inventory_window.visible = true
	_persistent_battle_inventory_window.position = Vector2.ZERO
	_persistent_battle_inventory_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Start in closed state (trays down)
	if _persistent_battle_inventory_window.has_method("set_open_progress"):
		_persistent_battle_inventory_window.set_open_progress(0.0)

func _teardown_persistent_battle_inventory() -> void:
	if not is_instance_valid(_persistent_battle_inventory_window):
		return
	# Remove from inspection group if tracked
	var idx = _active_inspection_group.find(_persistent_battle_inventory_window)
	if idx != -1:
		_active_inspection_group.remove_at(idx)
	_kill_inventory_motion_tween(_persistent_battle_inventory_window)
	_persistent_battle_inventory_window.queue_free()
	_persistent_battle_inventory_window = null

func _on_battle_state_changed_wm(is_in_battle: bool) -> void:
	if is_in_battle:
		_setup_persistent_battle_inventory()
	else:
		_teardown_persistent_battle_inventory()


# --- PUBLIC API ---

func get_replay_modal_stack() -> Array[String]:
	var result: Array[String] = []
	for window in _modal_stack:
		if not is_instance_valid(window) or window.is_queued_for_deletion():
			continue
		result.append(String(window.get_meta("window_type", window.name)))
	return result

# This function is ONLY for true "Hermetic Modals" that halt game flow.
func open_modal_window(type: StringName, context: Dictionary = {}, preserve_windows: bool = false) -> Control:
	if not _window_scenes.has(type):
		push_error("[WindowManager] ERROR: Window type not found in _window_scenes: " + str(type))
		return null
	if not preserve_windows:
		_close_all_windows() # True modals are exclusive.

	var window_instance = _window_scenes[type].instantiate()
	window_instance.set_meta("window_type", type)
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

	var tutorial_id: StringName = context.get("tutorial_id", &"")
	if _active_tutorial_overlay != null:
		if _active_tutorial_overlay.get_tutorial_id() == tutorial_id:
			return _active_tutorial_overlay
		for queued_context: Dictionary in _pending_tutorial_overlays:
			if StringName(queued_context.get("tutorial_id", &"")) == tutorial_id:
				return _active_tutorial_overlay
		_pending_tutorial_overlays.append(context.duplicate())
		return _active_tutorial_overlay

	return _create_tutorial_overlay(context)


func get_tutorial_popup(tutorial_id: StringName) -> TutorialPopup:
	if _active_tutorial_overlay != null and _active_tutorial_overlay.get_tutorial_id() == tutorial_id:
		return _active_tutorial_overlay
	return null

func is_tutorial_overlay_open() -> bool:
	return _active_tutorial_overlay != null


func is_game_paused_by_tutorial() -> bool:
	return _active_tutorial_overlay != null and _active_tutorial_overlay.is_pausing_game()


func advance_tutorial_page(tutorial_id: StringName, target_page: int) -> void:
	if ActionQueue.is_headless_mode():
		return
	var popup := get_tutorial_popup(tutorial_id)
	assert(popup != null, "No active tutorial popup for page advance: %s" % tutorial_id)
	popup.set_page(target_page)


func close_tutorial_overlay(tutorial_id: StringName) -> void:
	if ActionQueue.is_headless_mode():
		return
	var popup := get_tutorial_popup(tutorial_id)
	assert(popup != null, "No active tutorial popup to dismiss: %s" % tutorial_id)
	popup._close_popup()


func _create_tutorial_overlay(context: Dictionary) -> TutorialPopup:
	# Do NOT close existing windows - tutorials overlay on top
	var window_instance := _window_scenes[&"TutorialPopup"].instantiate() as TutorialPopup
	window_instance.set_meta("window_type", &"TutorialPopup")
	_active_tutorial_overlay = window_instance
	window_instance.tree_exited.connect(_on_tutorial_overlay_exited.bind(window_instance.get_instance_id()), CONNECT_ONE_SHOT)
	_get_modal_layer().add_child(window_instance)
	window_instance.z_index = 100 # Ensure tutorial renders above all
	# Add to modal stack so it can be properly cleaned up
	_modal_stack.push_back(window_instance)
	_register_window(window_instance, true)
	
	window_instance.populate(context)
	
	_animate_modal_open_deferred(window_instance)
	
	return window_instance


func _on_tutorial_overlay_exited(window_id: int) -> void:
	assert(_active_tutorial_overlay.get_instance_id() == window_id, "Active tutorial overlay changed before it exited")
	_active_tutorial_overlay = null
	_update_tree_pause_state()
	call_deferred("_open_next_tutorial_overlay")


func _open_next_tutorial_overlay() -> void:
	if _active_tutorial_overlay != null:
		return
	while not _pending_tutorial_overlays.is_empty():
		var context: Dictionary = _pending_tutorial_overlays.pop_front()
		var tutorial_id: StringName = context.get("tutorial_id", &"")
		if not TutorialManager.tutorials_enabled or TutorialManager.is_completed(tutorial_id):
			continue
		_create_tutorial_overlay(context)
		return

# Public entry point for the Inventory Window.
# Routes to the dedicated BattleInventoryWindow during battle, or the
# run-mode grid InventoryWindow outside of battle.
func open_inventory_window() -> void:
	var is_battle := GameManager.is_in_battle
	var win: Control = _persistent_battle_inventory_window if is_battle else _persistent_inventory_window
	if not is_instance_valid(win):
		if is_battle:
			_setup_persistent_battle_inventory()
			win = _persistent_battle_inventory_window
		else:
			_setup_persistent_inventory()
			win = _persistent_inventory_window
		if not is_instance_valid(win):
			# Fallback if still uninitialized
			var fallback_type: StringName = &"BattleInventory" if is_battle else &"Inventory"
			var context: Dictionary = {
				"window_type": fallback_type,
				"populate_context": _get_battle_inventory_populate_context() if is_battle else _get_run_inventory_populate_context()
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

	var ctx = _get_battle_inventory_populate_context() if is_battle else _get_run_inventory_populate_context()
	if win.has_method("populate"):
		win.populate(ctx)

	if not _active_inspection_group.has(win):
		_active_inspection_group.push_back(win)

	if _is_battle_inventory_window(win):
		_animate_battle_inventory_open(win)
	else:
		_animate_inventory_window_open(win)

# Back-compat shim for GIR callers that still use the old private name
func _open_inspection_window(loc: LocationIdentifier, source_view: Control) -> void:
	open_inspection_window(loc, source_view)

# Public API: open a child contextual window anchored to an existing window/view.
func open_child_contextual_window(window_type: StringName, anchor_view: Control, populate_ctx: Dictionary = {}) -> Control:
	if not is_instance_valid(anchor_view): return null
	var context: Dictionary = {
		"window_type": window_type,
		"anchor_view": anchor_view,
		"populate_context": populate_ctx,
	}
	return _open_contextual_window(context)

# Public entry point for the Discard Window.
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

	# We are about to open the Discard, so close all other contexts gently
	for iter_win in _active_inspection_group:
		if is_instance_valid(iter_win) and iter_win != win:
			stop_tracking_window(iter_win.get_instance_id())
			_queue_free_with_optional_inventory_animation(iter_win)

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

func open_description_inspection_window(title_key: String, description_key: String, source_view: Control) -> void:
	var context: Dictionary = {
		"window_type": &"EffectInspection",
		"populate_context": {
			"effect_definition": [{
				"name_key": title_key,
				"description_key": description_key
			}]
		},
		"anchor_view": source_view
	}
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
func close_children_of(parent_window: Control, include_glossary: bool = true) -> void:
	var parent_index = _active_inspection_group.find(parent_window)
	if parent_index == -1: return
	for i in range(_active_inspection_group.size() - 1, parent_index, -1):
		var child_window = _active_inspection_group[i]
		if is_instance_valid(child_window):
			if not include_glossary and child_window is EffectInspectionWindow:
				continue
			_active_inspection_group.remove_at(i)
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
func close_all_inspection_windows(keep_inventory: bool = false) -> void:
	# AUDIO HOOK: Window close sound (play once even if multiple windows)
	if not _active_inspection_group.is_empty():
		Audio.play_sfx("ui_window_close")
	
	# Iterate backwards and remove from active group
	for i in range(_active_inspection_group.size() - 1, -1, -1):
		var window = _active_inspection_group[i]
		if is_instance_valid(window):
			if keep_inventory and _is_persistent_inventory_window(window):
				continue
			_active_inspection_group.remove_at(i)
			stop_tracking_window(window.get_instance_id())
			_queue_free_with_optional_inventory_animation(window)

	_close_glossary_pill()

# Public API: explicitly close the run or battle inventory window drawer
func close_inventory_window(is_battle: bool = false) -> void:
	var win: Control = _persistent_battle_inventory_window if is_battle else _persistent_inventory_window
	if is_instance_valid(win):
		close_children_of(win)
		stop_tracking_window(win.get_instance_id())
		_queue_free_with_optional_inventory_animation(win)

# Public API: explicitly close the Discard drawer
func close_discard_pile_window() -> void:
	var win: Control = _persistent_discard_pile_window
	if is_instance_valid(win):
		close_children_of(win)
		stop_tracking_window(win.get_instance_id())
		_queue_free_with_optional_inventory_animation(win)

# Public query function for the GIR.
func is_any_inspection_window_open() -> bool:
	for i in range(_active_inspection_group.size() - 1, -1, -1):
		var w = _active_inspection_group[i]
		if not is_instance_valid(w):
			_active_inspection_group.remove_at(i)
			continue
		if not _is_persistent_inventory_window(w) and w != _glossary_pill:
			return true
	return false

## Public API: checks if the current mouse cursor is over any active inspection window or glossary pill.
func is_mouse_over_inspection_cluster() -> bool:
	var mouse_pos = get_viewport().get_mouse_position()
	if is_instance_valid(_glossary_pill) and _glossary_pill.is_inside_tree() and _glossary_pill.visible:
		if _get_screen_rect(_glossary_pill).has_point(mouse_pos):
			return true
	for w in _active_inspection_group:
		if is_instance_valid(w) and w.is_inside_tree() and w.visible and not _is_persistent_inventory_window(w):
			if _get_screen_rect(w).has_point(mouse_pos):
				return true
	return false

func get_top_contextual_window() -> Control:
	for i in range(_active_inspection_group.size() - 1, -1, -1):
		var win = _active_inspection_group[i]
		if is_instance_valid(win):
			return win
	return null

# Public API: check if the merge preview ChoiceWindow is currently open
func is_choice_window_open() -> bool:
	for i in range(_active_inspection_group.size() - 1, -1, -1):
		var w = _active_inspection_group[i]
		if not is_instance_valid(w) or w.is_queued_for_deletion():
			continue
		if w is ChoiceWindow or (w.has_meta("window_type") and w.get_meta("window_type") == &"ChoiceWindow"):
			return true
	return false

# Public API: check if a screen point is inside the active ChoiceWindow
func is_point_inside_choice_window(pos: Vector2) -> bool:
	for i in range(_active_inspection_group.size() - 1, -1, -1):
		var w = _active_inspection_group[i]
		if not is_instance_valid(w) or w.is_queued_for_deletion() or not w.is_visible_in_tree():
			continue
		if w is ChoiceWindow or (w.has_meta("window_type") and w.get_meta("window_type") == &"ChoiceWindow"):
			var rect: Rect2 = _get_screen_rect(w)
			if rect.has_point(pos):
				return true
	return false

# Public API: check if any modal window is currently open
func is_modal_open() -> bool:
	return not _modal_stack.is_empty()

# Public API: check if ANY base inventory window (Battle, Run, or Discard) is currently open
func is_any_inventory_window_open() -> bool:
	for i in range(_active_inspection_group.size() - 1, -1, -1):
		var win = _active_inspection_group[i]
		if not is_instance_valid(win):
			continue
		if win.has_meta(_WM_META_CLOSING) and bool(win.get_meta(_WM_META_CLOSING)):
			continue
		if win.has_meta("window_type"):
			var type = win.get_meta("window_type")
			if type == &"Inventory" or type == &"DiscardPile":
				return true
		# Fallbacks if meta is missing
		if win == _persistent_inventory_window or win == _persistent_battle_inventory_window or win == _persistent_discard_pile_window:
			return true
	return false

func is_run_inventory_window_open() -> bool:
	if not is_instance_valid(_persistent_inventory_window):
		return false
	return _persistent_inventory_window in _active_inspection_group \
		and _persistent_inventory_window.visible \
		and not (_persistent_inventory_window.has_meta(_WM_META_CLOSING) and bool(_persistent_inventory_window.get_meta(_WM_META_CLOSING)))

func is_battle_inventory_window_open() -> bool:
	if not is_instance_valid(_persistent_battle_inventory_window):
		return false
	return _persistent_battle_inventory_window in _active_inspection_group \
		and _persistent_battle_inventory_window.visible \
		and not (_persistent_battle_inventory_window.has_meta(_WM_META_CLOSING) and bool(_persistent_battle_inventory_window.get_meta(_WM_META_CLOSING)))

func is_discard_pile_window_open() -> bool:
	if not is_instance_valid(_persistent_discard_pile_window):
		return false
	return _persistent_discard_pile_window in _active_inspection_group \
		and _persistent_discard_pile_window.visible \
		and not (_persistent_discard_pile_window.has_meta(_WM_META_CLOSING) and bool(_persistent_discard_pile_window.get_meta(_WM_META_CLOSING)))

func is_run_inventory_window_interactive() -> bool:
	if not is_run_inventory_window_open():
		return false
	if _persistent_inventory_window.has_meta(_WM_META_OPENING) and bool(_persistent_inventory_window.get_meta(_WM_META_OPENING)):
		return false
	if _persistent_inventory_window.has_meta(_WM_META_CLOSING) and bool(_persistent_inventory_window.get_meta(_WM_META_CLOSING)):
		return false
	return true

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

# Checks if a given global screen point is inside any active inspection window.
func is_point_inside_any_inspection_window(pos: Vector2) -> bool:
	if is_instance_valid(_glossary_pill) and _glossary_pill.is_inside_tree() and _glossary_pill.visible:
		if _get_screen_rect(_glossary_pill).has_point(pos):
			return true
	for i in range(_active_inspection_group.size() - 1, -1, -1):
		var w = _active_inspection_group[i]
		if is_instance_valid(w) and w.is_visible_in_tree():
			if _get_screen_rect(w).has_point(pos):
				return true
	return false

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
		close_children_of(clicked_window, not is_glossary_locked)


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
	if (window is InspectionWindow and (window as InspectionWindow).parent_inspection_window_id == -1) or window is ChoiceWindow:
		_close_glossary_pill()
	var idx := _active_inspection_group.find(window)
	if idx != -1:
		_active_inspection_group.remove_at(idx)
	stop_tracking_window(window_id)
	_queue_free_with_optional_inventory_animation(window)

var _combat_paused_by_options: bool = false

func has_any_contextual_windows() -> bool:
	for w in _active_inspection_group:
		if is_instance_valid(w) and w.is_visible_in_tree() and not (w.has_meta(_WM_META_CLOSING) and bool(w.get_meta(_WM_META_CLOSING))):
			return true
	return false

func is_options_window_open() -> bool:
	for w in _active_inspection_group:
		if is_instance_valid(w) and w.get_meta("window_type", &"") == &"Options":
			return not (w.has_meta(_WM_META_CLOSING) and bool(w.get_meta(_WM_META_CLOSING)))
	for w in _modal_stack:
		if is_instance_valid(w) and w.get_meta("window_type", &"") == &"Options":
			return not (w.has_meta(_WM_META_CLOSING) and bool(w.get_meta(_WM_META_CLOSING)))
	return false

func get_options_window() -> Control:
	for w in _active_inspection_group:
		if is_instance_valid(w) and w.get_meta("window_type", &"") == &"Options":
			return w
	for w in _modal_stack:
		if is_instance_valid(w) and w.get_meta("window_type", &"") == &"Options":
			return w
	return null

func open_options_window() -> Control:
	if is_options_window_open():
		return get_options_window()
	if is_instance_valid(GameManager) and GameManager.is_in_battle:
		var animator = Engine.get_main_loop().root.get_node_or_null("/root/BattleAnimator")
		var is_already_paused = is_instance_valid(animator) and animator.has_method("is_paused") and animator.is_paused()
		if not is_already_paused:
			_combat_paused_by_options = true
			if is_instance_valid(ActionQueue):
				ActionQueue.request(PauseRunAction.new(true))
			else:
				var bv = get_tree().get_first_node_in_group("battle_view")
				if is_instance_valid(bv) and bv.has_method("execute_pause"):
					bv.execute_pause()
	var context: Dictionary = {
		"window_type": &"Options",
		"populate_context": {}
	}
	return _open_contextual_window(context)

func close_options_window() -> void:
	var win = get_options_window()
	if is_instance_valid(win):
		request_close_inspection_window(win, &"USER_CLOSE")

func toggle_options_window() -> void:
	if is_options_window_open():
		close_options_window()
	else:
		open_options_window()

func _on_window_closed_options_check(window: Control) -> void:
	if is_instance_valid(window) and window.get_meta("window_type", &"") == &"Options":
		if _combat_paused_by_options:
			_combat_paused_by_options = false
			if is_instance_valid(ActionQueue):
				ActionQueue.request(PauseRunAction.new(false))
			else:
				var bv = get_tree().get_first_node_in_group("battle_view")
				if is_instance_valid(bv) and bv.has_method("execute_speed"):
					bv.execute_speed(AnimationConstants.speed_factor)


# --- CORE INTERNAL LOGIC ---


# This unified function handles the creation and management of ALL Contextual Windows.
func _open_contextual_window(context: Dictionary) -> Control:
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
		close_all_inspection_windows(true)

	if not _window_scenes.has(window_type):
		return

	var window_instance = _window_scenes[window_type].instantiate()
	
	# ENFORCE WIDTH IMMEDIATELY: Set the desired width before adding to tree or populating.
	# This ensures all height calculations (fit_content) are based on the final width from frame 1.
	if window_instance is InspectionWindow:
		var target_w = GLOSSARY_WINDOW_WIDTH if window_type == &"EffectInspection" else INSPECTION_WINDOW_WIDTH
		window_instance.custom_minimum_size = Vector2(target_w, 0)
		window_instance.enforce_display_only()
		
	window_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		
	_get_modal_layer().add_child(window_instance)
	
	# CRITICAL: Do NOT use hide() here. Hidden nodes often skip layout calculations in Godot 4.
	# instead, set alpha to 0 and show it to force the engine to calculate final shrunk bounds
	# before we measure and position it in _deferred_position.
	window_instance.modulate.a = 0.0
	window_instance.show()
	
	# MOUSE CONFLICT FIX: Move the window far off-screen while it sits at 
	# alpha 0.0 during the 3-frame measurement delay. This prevents it 
	# from intercepting mouse events and breaking hover for units near (0,0).
	# Position is finalized in _deferred_position.
	_set_window_screen_position(window_instance, Vector2(-2000, -2000))
	
	window_instance.z_index = 100 # Render above local z-index elevations
	window_instance.set_meta("window_type", window_type) # Tag for identification
	
	_register_window(window_instance, false) # Register as NON-modal.
	_active_inspection_group.push_back(window_instance)
	_update_tree_pause_state()
	
	if window_instance is InspectionWindow:
		var parent_id: int = parent_window.get_instance_id() if is_instance_valid(parent_window) else -1
		(window_instance as InspectionWindow).parent_inspection_window_id = parent_id

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
		_track_inspection_anchor(window_instance, anchor_view, loc, pos_hint)
	
	return window_instance


# --- HELPER FUNCTIONS ---


func _deferred_position(window: Control, anchor: Control, parent_window: Control, pos_hint: String = "") -> void:
	if not is_instance_valid(window): return
	# We wait FOUR frames because inspection windows wait THREE frames to shrink to content,
	# and we want to measure their final settled dimensions.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# ASYNC SAFETY CHECK: Window might have been freed during the await frame
	if not is_instance_valid(window): return

	if window is InspectionWindow or window is ChoiceWindow:
		var target_w = GLOSSARY_WINDOW_WIDTH if window is EffectInspectionWindow else INSPECTION_WINDOW_WIDTH
		window.size = Vector2(target_w, 0)
		window.reset_size()

	# Safety check for anchor and parent which might have been freed during the await
	var safe_anchor: Control = anchor if is_instance_valid(anchor) else null
	var safe_parent: Control = parent_window if is_instance_valid(parent_window) else null
	
	# If the anchor was valid when we started but is now invalid (freed), we should close the window
	# unless it was null to begin with.
	if anchor != null and safe_anchor == null:
		request_close_inspection_window(window, &"ANCHOR_FREED_ASYNC")
		return

	var position := _calculate_contextual_window_position(safe_anchor, safe_parent, window, pos_hint)

	# Set position in screen space accounting for canvas transforms
	_set_window_screen_position(window, position)
	# Second pass: after the window is visible and fully laid out, finalize position
	call_deferred("_finalize_position", window, safe_anchor, safe_parent, pos_hint)

func _finalize_position(window: Control, anchor: Control, parent_window: Control, pos_hint: String = "") -> void:
	if not is_instance_valid(window): return
	await get_tree().process_frame
	
	# ASYNC SAFETY CHECK: Window or dependencies might have been freed during the await frame
	if not is_instance_valid(window): return
	
	if window is InspectionWindow or window is ChoiceWindow:
		var target_w = GLOSSARY_WINDOW_WIDTH if window is EffectInspectionWindow else INSPECTION_WINDOW_WIDTH
		window.size = Vector2(target_w, 0)
		window.reset_size()
	
	var safe_anchor: Control = anchor if is_instance_valid(anchor) else null
	var safe_parent: Control = parent_window if is_instance_valid(parent_window) else null
	
	if anchor != null and safe_anchor == null:
		request_close_inspection_window(window, &"ANCHOR_FREED_ASYNC")
		return

	var position := _calculate_contextual_window_position(safe_anchor, safe_parent, window, pos_hint)
	_set_window_screen_position(window, position)
	_animate_window_open(window)
	
	if safe_parent == null and (window is InspectionWindow or window is ChoiceWindow):
		call_deferred("_setup_and_layout_child_windows", window, safe_anchor)
		call_deferred("_update_glossary_pill_for_root", window)

func toggle_glossary_lock() -> void:
	set_glossary_locked(not is_glossary_locked)

func set_glossary_locked(val: bool) -> void:
	if is_glossary_locked == val:
		return
	is_glossary_locked = val
	Audio.play_sfx("ui_click")
	SignalBus.emit_signal("glossary_lock_changed", is_glossary_locked)
	_refresh_glossary_windows_state()

func _collect_recursive_glossary_specs(root_window: Control) -> Array[Dictionary]:
	var initial_terms: Array[String] = []
	if root_window is InspectionWindow:
		initial_terms = (root_window as InspectionWindow).get_glossary_terms()
	elif root_window is ChoiceWindow:
		initial_terms = (root_window as ChoiceWindow).get_glossary_terms()
	
	# Also collect terms from any currently active child windows attached to this root (like equipped items)
	var root_id = root_window.get_instance_id()
	for w in _active_inspection_group:
		if is_instance_valid(w) and w is InspectionWindow and not (w is EffectInspectionWindow):
			var insp_w: InspectionWindow = w as InspectionWindow
			if insp_w.parent_inspection_window_id == root_id:
				initial_terms.append_array(insp_w.get_glossary_terms())
	
	var seen_terms: Dictionary = {}
	if root_window is EffectInspectionWindow:
		var own_meta: String = (root_window as EffectInspectionWindow).get_own_keyword_canonical()
		if not own_meta.is_empty():
			seen_terms[own_meta] = true

	var specs: Array[Dictionary] = []
	var queue: Array[String] = initial_terms.duplicate()
	
	while not queue.is_empty():
		var raw_key: String = queue.pop_front()
		var info: Dictionary = DescriptionParser.get_keyword_info(raw_key)
		if info.is_empty():
			continue
		var canonical: String = info.get("meta", raw_key)
		if seen_terms.has(canonical):
			continue
		seen_terms[canonical] = true
		
		specs.append({
			"window_type": &"EffectInspection",
			"populate_context": {
				"effect_definition": {
					"name_key": info.name_key,
					"description_key": info.desc_key,
					"color": info.color
				},
				"is_inside_unit_inspection": true,
				"target_parent_window_id": root_id
			}
		})
		
		# Recursive BFS: scan this keyword's description for nested glossary terms
		var desc_key: String = info.get("desc_key", "")
		if not desc_key.is_empty():
			var translated_desc: String = tr(desc_key)
			var nested_terms: Array[String] = DescriptionParser.find_keywords(translated_desc)
			for nested_key in nested_terms:
				var nested_info: Dictionary = DescriptionParser.get_keyword_info(nested_key)
				var nested_canonical: String = nested_info.get("meta", nested_key) if not nested_info.is_empty() else nested_key
				if not seen_terms.has(nested_canonical):
					queue.append(nested_key)
				
	return specs

func _refresh_glossary_windows_state() -> void:
	if not is_glossary_locked:
		# Close all EffectInspection child windows in active contextual group
		var has_removed := false
		var root_w: Control = null
		var root_anc: Control = null
		for i in range(_active_inspection_group.size() - 1, -1, -1):
			var w = _active_inspection_group[i]
			if is_instance_valid(w):
				if w is EffectInspectionWindow and (w as InspectionWindow).parent_inspection_window_id != -1:
					_active_inspection_group.remove_at(i)
					stop_tracking_window(w.get_instance_id())
					w.queue_free()
					has_removed = true
				elif (w is InspectionWindow and (w as InspectionWindow).parent_inspection_window_id == -1) or w is ChoiceWindow:
					root_w = w
					root_anc = get_anchor_for_window(w)
		
		# Reposition root window without glossary clearance
		if is_instance_valid(root_w) and is_instance_valid(root_anc):
			var pos_hint := get_pos_hint_for_window(root_w)
			var pos := _calculate_contextual_window_position(root_anc, null, root_w, pos_hint)
			_set_window_screen_position(root_w, pos)
			_update_glossary_pill_position(root_w)

		# If any non-glossary child windows remain (e.g. equipped items), re-layout them
		if has_removed and is_instance_valid(root_w):
			var remaining_children: Array[Control] = []
			for w in _active_inspection_group:
				if is_instance_valid(w) and w != root_w and w is InspectionWindow:
					remaining_children.append(w)
			if not remaining_children.is_empty():
				var s_rect = _get_screen_rect(root_anc) if is_instance_valid(root_anc) else Rect2()
				_layout_child_windows(s_rect, root_w, remaining_children)

		# Also clear modal child windows
		for m_id in _modal_child_windows:
			var list: Array = _modal_child_windows[m_id]
			for w in list:
				if is_instance_valid(w):
					stop_tracking_window(w.get_instance_id())
					w.queue_free()
		_modal_child_windows.clear()
	else:
		# Find the root inspection window in contextual group if open
		var root_w: Control = null
		var root_anc: Control = null
		for w in _active_inspection_group:
			if is_instance_valid(w):
				if (w is InspectionWindow and (w as InspectionWindow).parent_inspection_window_id == -1) or w is ChoiceWindow:
					root_w = w
					root_anc = get_anchor_for_window(w)
					break
		
		if is_instance_valid(root_w):
			if is_instance_valid(root_anc):
				var pos_hint := get_pos_hint_for_window(root_w)
				var pos := _calculate_contextual_window_position(root_anc, null, root_w, pos_hint)
				_set_window_screen_position(root_w, pos)
				_update_glossary_pill_position(root_w)
			_spawn_and_layout_glossary_only(root_w, root_anc)
			
		# Also check if modal preview is open
		var active_modal = _modal_stack.back() if not _modal_stack.is_empty() else null
		if is_instance_valid(active_modal):
			var insp_container = active_modal.get_node_or_null("%InspectionContainer")
			if insp_container:
				for ch in insp_container.get_children():
					if ch is InspectionWindow:
						setup_child_windows_for_modal(active_modal, ch)
						break

func _spawn_and_layout_glossary_only(root_window: Control, anchor: Control) -> void:
	if not is_instance_valid(root_window) or not root_window.is_inside_tree():
		return
	
	# CLEANUP FIRST: remove any old/duplicate EffectInspection windows before spawning
	for i in range(_active_inspection_group.size() - 1, -1, -1):
		var w = _active_inspection_group[i]
		if is_instance_valid(w) and w is EffectInspectionWindow and w != root_window:
			_active_inspection_group.remove_at(i)
			stop_tracking_window(w.get_instance_id())
			w.queue_free()
			_active_inspection_group.remove_at(i)
			stop_tracking_window(w.get_instance_id())
			w.queue_free()

	if not is_glossary_locked:
		return

	var glossary_specs = _collect_recursive_glossary_specs(root_window)
	if glossary_specs.is_empty():
		return
	
	var new_glossary_windows: Array[Control] = []
	for spec in glossary_specs:
		var w_type: StringName = spec.get("window_type", &"")
		if not _window_scenes.has(w_type):
			continue
		var child_instance = _window_scenes[w_type].instantiate()
		if child_instance is InspectionWindow:
			child_instance.custom_minimum_size = Vector2(GLOSSARY_WINDOW_WIDTH, 0)
			(child_instance as InspectionWindow).parent_inspection_window_id = root_window.get_instance_id()
			child_instance.enforce_display_only()
		child_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		_get_modal_layer().add_child(child_instance)
		child_instance.modulate.a = 0.0
		child_instance.show()
		_set_window_screen_position(child_instance, Vector2(-2000, -2000))
		child_instance.z_index = 100
		child_instance.set_meta("window_type", w_type)
		_register_window(child_instance, false)
		_active_inspection_group.push_back(child_instance)
		
		var child_insp := child_instance as InspectionWindow
		assert(child_insp != null, "Child window must be an InspectionWindow: %s" % w_type)
		child_insp.populate(spec.get("populate_context", {}))
		child_insp.enforce_display_only()
			
		new_glossary_windows.append(child_instance)
	
	if new_glossary_windows.is_empty():
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not is_glossary_locked or not is_instance_valid(root_window) or not root_window.is_inside_tree():
		for child in new_glossary_windows:
			if is_instance_valid(child):
				var idx = _active_inspection_group.find(child)
				if idx != -1:
					_active_inspection_group.remove_at(idx)
				stop_tracking_window(child.get_instance_id())
				child.queue_free()
		return
	
	for child in new_glossary_windows:
		if is_instance_valid(child) and child is InspectionWindow:
			child.size = Vector2(GLOSSARY_WINDOW_WIDTH, 0)
			child.reset_size()
	
	# Gather all child windows of root (both items and glossary) for unified layout
	var all_children: Array[Control] = []
	for w in _active_inspection_group:
		if is_instance_valid(w) and w != root_window and w is InspectionWindow:
			all_children.append(w)
	
	var source_rect = _get_screen_rect(anchor) if is_instance_valid(anchor) else Rect2()
	_layout_child_windows(source_rect, root_window, all_children)
	
	for child in new_glossary_windows:
		if is_instance_valid(child):
			_animate_window_open(child)

func setup_child_windows_for_modal(modal: Control, preview_win: InspectionWindow) -> void:
	if not is_instance_valid(modal) or not modal.is_inside_tree():
		return
	if not is_instance_valid(preview_win) or not preview_win.is_inside_tree():
		return
	
	close_modal_child_windows(modal)
	if not is_glossary_locked:
		return
	
	var specs = _collect_recursive_glossary_specs(preview_win)
	if specs.is_empty():
		return
	
	var modal_id = modal.get_instance_id()
	var child_windows: Array[Control] = []
	for spec in specs:
		var w_type: StringName = spec.get("window_type", &"")
		if not _window_scenes.has(w_type):
			continue
		var child_instance = _window_scenes[w_type].instantiate()
		if child_instance is InspectionWindow:
			child_instance.custom_minimum_size = Vector2(GLOSSARY_WINDOW_WIDTH, 0)
			(child_instance as InspectionWindow).parent_inspection_window_id = preview_win.get_instance_id()
			child_instance.enforce_display_only()
		child_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		_get_modal_layer().add_child(child_instance)
		child_instance.modulate.a = 0.0
		child_instance.show()
		_set_window_screen_position(child_instance, Vector2(-2000, -2000))
		child_instance.z_index = 200
		child_instance.set_meta("window_type", w_type)
		_register_window(child_instance, false)
		
		var child_insp := child_instance as InspectionWindow
		assert(child_insp != null, "Child window must be an InspectionWindow: %s" % w_type)
		child_insp.populate(spec.get("populate_context", {}))
		child_insp.enforce_display_only()
			
		child_windows.append(child_instance)
	
	_modal_child_windows[modal_id] = child_windows
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not is_instance_valid(modal) or not modal.is_inside_tree():
		close_modal_child_windows(modal)
		return
	
	for child in child_windows:
		if is_instance_valid(child) and child is InspectionWindow:
			child.size = Vector2(GLOSSARY_WINDOW_WIDTH, 0)
			child.reset_size()
	
	_layout_child_windows(Rect2(), modal, child_windows)
	
	for child in child_windows:
		if is_instance_valid(child):
			_animate_window_open(child)

func close_modal_child_windows(modal: Control) -> void:
	if not is_instance_valid(modal):
		return
	var modal_id = modal.get_instance_id()
	if _modal_child_windows.has(modal_id):
		var list: Array = _modal_child_windows[modal_id]
		for w in list:
			if is_instance_valid(w):
				stop_tracking_window(w.get_instance_id())
				w.queue_free()
		_modal_child_windows.erase(modal_id)

func _setup_and_layout_child_windows(root_window: Control, anchor: Control) -> void:
	if not is_instance_valid(root_window) or not root_window.is_inside_tree():
		return
	if not (root_window is InspectionWindow or root_window is ChoiceWindow):
		return
	
	var specs: Array[Dictionary] = []
	if root_window is InspectionWindow:
		specs = (root_window as InspectionWindow).get_child_window_specs()
	elif root_window is ChoiceWindow:
		specs = (root_window as ChoiceWindow).get_child_window_specs()
	
	if is_glossary_locked:
		var glossary_specs = _collect_recursive_glossary_specs(root_window)
		specs.append_array(glossary_specs)
	
	if specs.is_empty():
		return
	
	var child_windows: Array[Control] = []
	for spec in specs:
		var w_type: StringName = spec.get("window_type", &"")
		if not _window_scenes.has(w_type):
			continue
		var child_instance = _window_scenes[w_type].instantiate()
		if child_instance is InspectionWindow:
			var target_w = GLOSSARY_WINDOW_WIDTH if w_type == &"EffectInspection" else INSPECTION_WINDOW_WIDTH
			child_instance.custom_minimum_size = Vector2(target_w, 0)
			(child_instance as InspectionWindow).parent_inspection_window_id = root_window.get_instance_id()
			child_instance.enforce_display_only()
		child_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		_get_modal_layer().add_child(child_instance)
		child_instance.modulate.a = 0.0
		child_instance.show()
		_set_window_screen_position(child_instance, Vector2(-2000, -2000))
		child_instance.z_index = 100
		child_instance.set_meta("window_type", w_type)
		_register_window(child_instance, false)
		_active_inspection_group.push_back(child_instance)
		
		var child_insp := child_instance as InspectionWindow
		assert(child_insp != null, "Child window must be an InspectionWindow: %s" % w_type)
		child_insp.populate(spec.get("populate_context", {}))
		child_insp.enforce_display_only()
			
		child_windows.append(child_instance)
	
	if child_windows.is_empty():
		return
	
	# Wait for child windows layout to settle
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not is_instance_valid(root_window) or not root_window.is_inside_tree():
		for child in child_windows:
			if is_instance_valid(child):
				child.queue_free()
		return

	# If glossary was toggled off during awaits, clean up any glossary windows
	if not is_glossary_locked:
		for i in range(child_windows.size() - 1, -1, -1):
			var ch = child_windows[i]
			if is_instance_valid(ch) and ch is EffectInspectionWindow:
				child_windows.remove_at(i)
				var a_idx = _active_inspection_group.find(ch)
				if a_idx != -1:
					_active_inspection_group.remove_at(a_idx)
				stop_tracking_window(ch.get_instance_id())
				ch.queue_free()
	
	for child in child_windows:
		if is_instance_valid(child) and child is InspectionWindow:
			var target_w = GLOSSARY_WINDOW_WIDTH if child is EffectInspectionWindow else INSPECTION_WINDOW_WIDTH
			child.size = Vector2(target_w, 0)
			child.reset_size()
	
	var source_rect = _get_screen_rect(anchor) if is_instance_valid(anchor) else Rect2()
	_layout_child_windows(source_rect, root_window, child_windows)
	
	for child in child_windows:
		if is_instance_valid(child):
			_animate_window_open(child)

func _layout_child_windows(source_rect: Rect2, root_window: Control, children: Array[Control]) -> void:
	if children.is_empty() or not is_instance_valid(root_window):
		return
	var root_rect = _get_screen_rect(root_window)
	var viewport_rect := get_viewport().get_visible_rect()
	var margin: float = 8.0 # Edge-to-edge gap between windows
	var screen_margin: float = 12.0 # Keep off screen borders
	
	# 1. Separate children into Secondary (equipped items, traits) and Tertiary (glossary effect cards)
	var secondary_windows: Array[Control] = []
	var glossary_windows: Array[Control] = []
	for child in children:
		if is_instance_valid(child) and child.is_inside_tree():
			if child is EffectInspectionWindow:
				glossary_windows.append(child)
			else:
				secondary_windows.append(child)

	# 2. Layout Secondary Windows (Equipped Items) - dock directly beside root_rect to form compound_rect
	var compound_rect: Rect2 = root_rect
	var place_sec_right: bool = true
	if source_rect.size != Vector2.ZERO:
		# If root is placed to the right of anchor, secondary docks on the right of root away from anchor
		place_sec_right = root_rect.position.x >= source_rect.get_center().x
	else:
		place_sec_right = (viewport_rect.end.x - root_rect.end.x) >= (root_rect.position.x - viewport_rect.position.x)
		
	var sec_x: float = (root_rect.end.x + margin) if place_sec_right else (root_rect.position.x - INSPECTION_WINDOW_WIDTH - margin)
	# Check boundary fit; if not fitting, check opposite side as long as it doesn't overlap source_rect
	if place_sec_right and sec_x + INSPECTION_WINDOW_WIDTH > viewport_rect.end.x - screen_margin:
		var alt_x = root_rect.position.x - INSPECTION_WINDOW_WIDTH - margin
		if source_rect.size == Vector2.ZERO or alt_x >= source_rect.end.x:
			place_sec_right = false
			sec_x = alt_x
	elif not place_sec_right and sec_x < viewport_rect.position.x + screen_margin:
		var alt_x = root_rect.end.x + margin
		if source_rect.size == Vector2.ZERO or alt_x + INSPECTION_WINDOW_WIDTH <= source_rect.position.x:
			place_sec_right = true
			sec_x = alt_x

	for sec in secondary_windows:
		var sz = _get_window_size(sec)
		var pos = Vector2(sec_x, root_rect.position.y)
		pos.y = clampf(pos.y, viewport_rect.position.y + screen_margin, viewport_rect.end.y - sz.y - screen_margin)
		pos.x = clampf(pos.x, viewport_rect.position.x + screen_margin, viewport_rect.end.x - sz.x - screen_margin)
		_set_window_screen_position(sec, pos)
		compound_rect = compound_rect.merge(Rect2(pos, sz))
		if place_sec_right:
			sec_x += sz.x + margin
		else:
			sec_x -= (sz.x + margin)

	if glossary_windows.is_empty():
		return

	# 3. Layout Tertiary Glossary Cards in a Dedicated Unidirectional Outward Tray
	var space_tray_right: float = viewport_rect.end.x - compound_rect.end.x - screen_margin
	var space_tray_left: float = compound_rect.position.x - viewport_rect.position.x - screen_margin
	
	# SACRED ANCHOR INVARIANT: Tray must NEVER overlap source_rect!
	var tray_on_right: bool = true
	if source_rect.size != Vector2.ZERO:
		if source_rect.position.x >= compound_rect.end.x - 20.0:
			# Anchor is to the right of compound -> tray MUST go to the left!
			tray_on_right = false
		elif source_rect.end.x <= compound_rect.position.x + 20.0:
			# Anchor is to the left of compound -> tray MUST go to the right!
			tray_on_right = true
		else:
			tray_on_right = space_tray_right >= space_tray_left
	else:
		tray_on_right = space_tray_right >= space_tray_left

	# Measure glossary windows
	var card_sizes: Array[Vector2] = []
	for gw in glossary_windows:
		gw.custom_minimum_size = Vector2(GLOSSARY_WINDOW_WIDTH, 0)
		gw.size = Vector2(GLOSSARY_WINDOW_WIDTH, 0)
		gw.reset_size()
		card_sizes.append(_get_window_size(gw))

	# Pack glossary cards into columns
	var available_height: float = viewport_rect.size.y - (2.0 * screen_margin)
	var card_gap: float = 4.0
	var col_gap: float = 6.0
	var col_width: float = GLOSSARY_WINDOW_WIDTH

	var columns: Array[Array] = []
	var cur_col: Array = []
	var cur_col_h: float = 0.0

	for i in range(glossary_windows.size()):
		var h = card_sizes[i].y
		if not cur_col.is_empty() and (cur_col_h + card_gap + h > available_height):
			columns.append(cur_col)
			cur_col = []
			cur_col_h = 0.0
		
		cur_col.append(i)
		cur_col_h += (card_gap if cur_col_h > 0.0 else 0.0) + h

	if not cur_col.is_empty():
		columns.append(cur_col)

	# Position columns strictly outward in the tray direction
	var cur_col_x: float = (compound_rect.end.x + margin) if tray_on_right else compound_rect.position.x - margin
	
	for col in columns:
		var max_col_w: float = col_width
		for idx in col:
			max_col_w = maxf(max_col_w, card_sizes[idx].x)

		var col_x: float = cur_col_x if tray_on_right else (cur_col_x - max_col_w)

		# Calculate total height of this column to center/align vertically
		var total_col_h: float = 0.0
		for idx in col:
			total_col_h += card_sizes[idx].y + card_gap
		total_col_h -= card_gap

		# Align column top with compound_rect.position.y, but ensure it fits on screen
		var cur_y: float = compound_rect.position.y
		if cur_y + total_col_h > viewport_rect.end.y - screen_margin:
			cur_y = maxf(screen_margin, viewport_rect.end.y - screen_margin - total_col_h)

		for idx in col:
			var card: Control = glossary_windows[idx]
			var sz: Vector2 = card_sizes[idx]
			_set_window_screen_position(card, Vector2(col_x, cur_y))
			cur_y += sz.y + card_gap

		if tray_on_right:
			cur_col_x += max_col_w + col_gap
		else:
			cur_col_x -= (max_col_w + col_gap)

	# 4. Outer Screen Clamp: ensure glossary cards never go off-screen, preserving root alignment
	var min_allowed_x: float = viewport_rect.position.x + screen_margin
	var max_allowed_x: float = viewport_rect.end.x - screen_margin
	for gw in glossary_windows:
		if is_instance_valid(gw) and gw.is_inside_tree():
			var gw_sz = _get_window_size(gw)
			gw.position.x = clampf(gw.position.x, min_allowed_x, max_allowed_x - gw_sz.x)

func _is_persistent_inventory_window(window: Control) -> bool:
	return is_instance_valid(window) and (window == _persistent_inventory_window or window == _persistent_battle_inventory_window or window == _persistent_discard_pile_window)

## Public API: checks whether a given node is structurally contained inside any persistent inventory/discard window.
func is_view_inside_inventory(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	var current: Node = node
	while is_instance_valid(current) and current != get_tree().root:
		if current is Control and _is_persistent_inventory_window(current as Control):
			return true
		current = current.get_parent()
	return false

func get_anchor_for_window(window: Control) -> Control:
	if not is_instance_valid(window):
		return null
	var tracking_info: Dictionary = _tracked_windows.get(window.get_instance_id(), {})
	var anchor = tracking_info.get("anchor", null)
	return anchor if is_instance_valid(anchor) else null

func get_pos_hint_for_window(window: Control) -> String:
	if not is_instance_valid(window):
		return ""
	var tracking_info: Dictionary = _tracked_windows.get(window.get_instance_id(), {})
	return tracking_info.get("pos_hint", "")

func _update_glossary_pill_for_root(root_window: Control) -> void:
	if not is_instance_valid(root_window) or not root_window.is_inside_tree():
		_close_glossary_pill()
		return
	if not (root_window is InspectionWindow or root_window is ChoiceWindow):
		_close_glossary_pill()
		return
	if root_window is InspectionWindow and (root_window as InspectionWindow).parent_inspection_window_id != -1:
		_close_glossary_pill()
		return
	
	var glossary_specs = _collect_recursive_glossary_specs(root_window)
	if glossary_specs.is_empty():
		_close_glossary_pill()
		return
		
	if not is_instance_valid(_glossary_pill):
		_glossary_pill = _GlossaryTogglePillScene.instantiate()
		_glossary_pill.process_mode = Node.PROCESS_MODE_ALWAYS
		_get_modal_layer().add_child(_glossary_pill)
		_glossary_pill.z_index = 101
		_register_window(_glossary_pill, false)
	else:
		_glossary_pill.z_index = 101
		
	_glossary_pill.show()
	_update_glossary_pill_position(root_window)

func _update_glossary_pill_position(root_window: Control) -> void:
	if not is_instance_valid(_glossary_pill) or not is_instance_valid(root_window):
		return
	
	_glossary_pill.reset_size()
	var pill_sz = GlossaryTogglePill.FIXED_SIZE
	var root_rect = _get_screen_rect(root_window)
	var viewport_rect = get_viewport().get_visible_rect()
	var margin: float = 8.0
	
	# Align flush with bottom-right edge of root_window
	var x: float = root_rect.end.x - pill_sz.x
	var y: float = root_rect.end.y + 2.0
	
	# If not enough room below root_rect, place directly above root_rect
	if y + pill_sz.y > viewport_rect.end.y - margin:
		y = root_rect.position.y - pill_sz.y - 2.0
		
	x = clampf(x, viewport_rect.position.x + margin, viewport_rect.end.x - pill_sz.x - margin)
	y = clampf(y, viewport_rect.position.y + margin, viewport_rect.end.y - pill_sz.y - margin)
	
	_set_window_screen_position(_glossary_pill, Vector2(x, y))

func _close_glossary_pill() -> void:
	if is_instance_valid(_glossary_pill):
		stop_tracking_window(_glossary_pill.get_instance_id())
		_glossary_pill.queue_free()
		_glossary_pill = null

func close_glossary_pill() -> void:
	_close_glossary_pill()

func _find_ancestor_inspection_window(node: Node) -> Control:
	if not is_instance_valid(node): return null
	# First, treat the node itself as a candidate parent window
	var self_idx := _index_in_active_group(node)
	if self_idx != -1:
		var w = _active_inspection_group[self_idx]
		if not _is_persistent_inventory_window(w):
			return w
		return null
	# Then walk ancestors
	var current := node.get_parent()
	while is_instance_valid(current) and current != get_tree().root:
		var idx := _index_in_active_group(current)
		if idx != -1:
			var w = _active_inspection_group[idx]
			if not _is_persistent_inventory_window(w):
				return w
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

# Public API: find the entity view (e.g. GachaBallView) for a location, unwrapping SlotView if necessary
func find_entity_view_for_location(loc: LocationIdentifier) -> Control:
	var slot_or_view = find_view_for_location(loc)
	if not is_instance_valid(slot_or_view):
		return null
	if slot_or_view is GachaBallView or slot_or_view.has_method("play_landing_bounce"):
		return slot_or_view
	for child in slot_or_view.get_children():
		if not child.is_queued_for_deletion() and (child is GachaBallView or (child is Control and child.has_method("play_landing_bounce"))):
			return child
	return slot_or_view

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

func _get_run_inventory_populate_context() -> Dictionary:
	var inventory_data: Dictionary = {}
	var run_state = GameManager.run_state
	if is_instance_valid(run_state):
		inventory_data = run_state.get_run_inventory_containers()
	return {"inventory": inventory_data, "is_battle_context": false, "title": "Run Inventory", "is_interactive": true}

func _get_battle_inventory_populate_context() -> Dictionary:
	var inventory_data: Dictionary = {}
	var bm = get_tree().get_first_node_in_group("battle_manager")
	if is_instance_valid(bm):
		inventory_data = bm.get_battle_inventory()
	return {"inventory": inventory_data, "is_battle_context": true, "title": "Battle Inventory", "is_interactive": true}

# Legacy shim — kept for any callers that haven't been updated yet
func _get_inventory_populate_context() -> Dictionary:
	return _get_battle_inventory_populate_context() if GameManager.is_in_battle else _get_run_inventory_populate_context()

func _get_discard_pile_populate_context() -> Dictionary:
	var inventory_data: Array = []
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		if is_instance_valid(bm): inventory_data = bm.get_discard_pile_inventory()
	return {"inventory": inventory_data, "is_battle_context": GameManager.is_in_battle, "title": tr("ui.discard_pile"), "is_interactive": false}

func _derive_window_payload(loc: LocationIdentifier, source_view: Control) -> Dictionary:
	var payload: Dictionary = {}
	var instance: GachaBallInstance
	var window_type: StringName
	var context: Dictionary
	if is_instance_valid(loc):
		# Fallback 1: Try UUID lookup first if source view provides it.
		# This is CRITICAL during combat animations because units might have died
		# in the simulation and moved to Discard (Player) or been erased (Enemy).
		var target_uuid: String = ""
		if is_instance_valid(source_view):
			var gb_view := source_view as GachaBallView
			if gb_view:
				target_uuid = gb_view.get_instance_uuid()
			elif source_view.has_meta("bound_uuid"):
				target_uuid = str(source_view.get_meta("bound_uuid"))
			elif is_instance_valid(source_view.get_parent()):
				var pgb := source_view.get_parent() as PhysicsGachaBall
				if pgb:
					target_uuid = pgb.instance_uuid
		
		if not target_uuid.is_empty():
			instance = GameManager.get_instance_by_uuid(target_uuid)
				
		# Fallback 2: Normal location lookup
		if not is_instance_valid(instance):
			instance = GameManager.get_instance_from_location(loc)
			
		# Fallback 3: Explicit instance from source view metadata or parent (e.g. Loadout preview)
		if not is_instance_valid(instance):
			if source_view.has_meta("gachaball_instance"):
				instance = source_view.get_meta("gachaball_instance")
			elif is_instance_valid(source_view.get_parent()) and source_view.get_parent().has_meta("gachaball_instance"):
				instance = source_view.get_parent().get_meta("gachaball_instance")
			elif is_instance_valid(loc) and loc.has_meta("gachaball_instance"):
				instance = loc.get_meta("gachaball_instance")
			
		if not is_instance_valid(instance): return {}
		var def = instance.get_definition()
		var is_preview_mode: bool = source_view.get_meta("is_preview", false) or (is_instance_valid(loc) and loc.get_meta("is_preview", false)) or not is_instance_valid(GameManager.run_state)
		if def.category == &"UNIT":
			window_type = &"UnitInspection"
			context = {"source_view": source_view, "instance": instance, "location": loc, "is_preview": is_preview_mode}
			if loc.container == &"EnemyLineup":
				context["is_enemy_context"] = true
		elif def.category in [&"ITEM", &"TRINKET", &"CONSUMABLE"]:
			window_type = &"ItemInspection"
			context = {"source_view": source_view, "instance": instance, "location": loc, "is_preview": is_preview_mode}
			# Equipped items: prefer positioning relative to the parent UnitInspectionWindow,
			# not the tiny equipped slot view. Provide a hint so positioning prefers the parent window rect.
			if loc.container == C.CONTAINER_EQUIPPED_ITEM:
				# Augment context so WindowManager can resolve the correct parent window reliably.
				var unit_parent: Control = find_ancestor_window_for_view(source_view)
				if is_instance_valid(unit_parent) and unit_parent is UnitInspectionWindow:
					context["is_inside_unit_inspection"] = true
					context["target_parent_window_id"] = unit_parent.get_instance_id()
				payload["positioning_hint"] = "use_parent_window"
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
func _track_inspection_anchor(window_instance: Control, anchor: Control, loc: LocationIdentifier, pos_hint: String = "") -> void:
	if not is_instance_valid(window_instance) or not is_instance_valid(anchor): return
	var window_id = window_instance.get_instance_id()
	var anchor_id = anchor.get_instance_id()
	var geom_callable := Callable(self , "_on_inspection_anchor_moved").bind(window_id, anchor_id, pos_hint)
	if not anchor.is_connected("item_rect_changed", geom_callable):
		anchor.item_rect_changed.connect(geom_callable, CONNECT_DEFERRED)
	var freed_callable := Callable(self , "_on_inspection_anchor_freed").bind(window_id, anchor_id, loc, geom_callable)
	if not anchor.is_connected("tree_exited", freed_callable):
		anchor.tree_exited.connect(freed_callable, CONNECT_DEFERRED)
	_tracked_windows[window_id] = {"anchor": anchor, "geom_callable": geom_callable, "freed_callable": freed_callable, "pos_hint": pos_hint}

func stop_tracking_window(window_id: int) -> void:
	# Emit signal that window is closing/stopping tracking
	# We try to get the instance to pass it.
	var window = instance_from_id(window_id)
	if is_instance_valid(window) and window is Control:
		window_closed.emit(window)
	
	call_deferred("_update_tree_pause_state")

	if not _tracked_windows.has(window_id): return
	var tracking_info = _tracked_windows[window_id]
	var anchor = tracking_info["anchor"]
	if is_instance_valid(anchor):
		if anchor.is_connected("item_rect_changed", tracking_info["geom_callable"]):
			anchor.item_rect_changed.disconnect(tracking_info["geom_callable"])
		if anchor.is_connected("tree_exited", tracking_info["freed_callable"]):
			anchor.tree_exited.disconnect(tracking_info["freed_callable"])
	
	_tracked_windows.erase(window_id)

func _on_inspection_anchor_moved(window_id: int, anchor_id: int, pos_hint: String = "") -> void:
	var window_instance = instance_from_id(window_id) as Control
	var anchor = instance_from_id(anchor_id) as Control
	if is_instance_valid(anchor) and is_instance_valid(window_instance):
		var pos := _calculate_contextual_window_position(anchor, null, window_instance, pos_hint)
		_set_window_screen_position(window_instance, pos)
		
		var source_rect = _get_screen_rect(anchor)
		var children: Array[Control] = []
		var parent_idx = _active_inspection_group.find(window_instance)
		if parent_idx != -1:
			for i in range(parent_idx + 1, _active_inspection_group.size()):
				var ch = _active_inspection_group[i]
				if is_instance_valid(ch):
					children.append(ch)
		if not children.is_empty():
			_layout_child_windows(source_rect, window_instance, children)
		_update_glossary_pill_position(window_instance)


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
	if _modal_child_windows.has(window_id):
		var list: Array = _modal_child_windows[window_id]
		for w in list:
			if is_instance_valid(w):
				stop_tracking_window(w.get_instance_id())
				w.queue_free()
		_modal_child_windows.erase(window_id)
	var stack = _modal_stack if was_modal else _active_inspection_group
	for i in range(stack.size() - 1, -1, -1):
		var window = stack[i]
		if not is_instance_valid(window) or window.get_instance_id() == window_id:
			stack.remove_at(i)
	if was_modal and ActionQueue.is_busy():
		var act = ActionQueue.get_active_action()
		if act is AcknowledgeFlashcardIntroAction or act is SelectFlashcardIntroCardAction \
			or act is SubmitFlashcardAnswerAction or act is SkipFlashcardAction \
			or act is DismissTutorialAction \
			or act is AcknowledgeRunCompleteAction:
			ActionQueue.finish_action(act)

func _close_top_modal() -> void:
	if not _modal_stack.is_empty():
		var window = _modal_stack.pop_back()
		if is_instance_valid(window):
			window.queue_free()
		return

func close_choice_window() -> void:
	for i in range(_active_inspection_group.size() - 1, -1, -1):
		var w = _active_inspection_group[i]
		if is_instance_valid(w) and w is ChoiceWindow:
			close_children_of(w)
			stop_tracking_window(w.get_instance_id())
			_active_inspection_group.remove_at(i)
			_queue_free_with_optional_inventory_animation(w)
	_close_glossary_pill()

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

func close_all_windows() -> void:
	_close_all_windows()

func _close_all_windows() -> void:
	_pending_tutorial_overlays.clear()
	close_all_inspection_windows(false)
	while not _modal_stack.is_empty():
		_close_top_modal()

func _calculate_window_position(source_view: Control, new_window: Control) -> Vector2:
	if not is_instance_valid(source_view): return Vector2.ZERO
	var src = _get_screen_rect(source_view)
	var win_sz = _get_window_size(new_window)
	var viewport_rect = get_viewport().get_visible_rect()
	var margin: float = INSPECTION_WINDOW_MARGIN
	var screen_margin: float = 12.0
	
	# Clearance checking: account for glossary tray width if glossary is locked
	var required_width: float = win_sz.x
	if is_glossary_locked and (new_window is InspectionWindow or new_window is ChoiceWindow):
		var specs: Array[Dictionary] = _collect_recursive_glossary_specs(new_window)
		if not specs.is_empty():
			required_width += 8.0 + GLOSSARY_WINDOW_WIDTH
		
	var space_right: float = viewport_rect.end.x - src.end.x - margin - screen_margin
	var space_left: float = src.position.x - viewport_rect.position.x - margin - screen_margin
	
	var place_right: bool = true
	if space_right >= required_width and space_left >= required_width:
		place_right = space_right >= space_left
	elif space_right >= required_width:
		place_right = true
	elif space_left >= required_width:
		place_right = false
	else:
		place_right = space_right >= space_left
		
	var x: float = (src.end.x + margin) if place_right else (src.position.x - win_sz.x - margin)
	var max_x = (viewport_rect.end.x - required_width - screen_margin) if (place_right and is_glossary_locked) else (viewport_rect.end.x - win_sz.x - screen_margin)
	var min_x = (viewport_rect.position.x + screen_margin + (required_width - win_sz.x)) if (not place_right and is_glossary_locked) else (viewport_rect.position.x + screen_margin)
	x = clampf(x, min_x, max_x)
	
	# SACRED ANCHOR INVARIANT: Window must NEVER overlap src horizontally
	if place_right and x < src.end.x:
		if space_left >= win_sz.x:
			x = src.position.x - win_sz.x - margin
	elif not place_right and x + win_sz.x > src.position.x:
		if space_right >= win_sz.x:
			x = src.end.x + margin
			
	# Vertical: align the window's base (bottom) with the source center
	var y: float = src.get_center().y - win_sz.y
	y = clampf(y, viewport_rect.position.y + screen_margin, viewport_rect.end.y - win_sz.y - screen_margin)
	
	return Vector2(x, y)

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
	
	# Vertical: align the window's base (bottom) with the anchor center
	var y: float = anchor_rect.get_center().y - child_sz.y
	
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
	var size: Vector2 = ctrl.size
	if size == Vector2.ZERO:
		var min_sz: Vector2 = ctrl.get_combined_minimum_size()
		if min_sz != Vector2.ZERO:
			size = min_sz
	var xf: Transform2D = ctrl.get_global_transform_with_canvas()
	var p0: Vector2 = xf * Vector2(0, 0)
	var p1: Vector2 = xf * Vector2(size.x, 0)
	var p2: Vector2 = xf * Vector2(0, size.y)
	var p3: Vector2 = xf * Vector2(size.x, size.y)
	var min_x: float = min(p0.x, min(p1.x, min(p2.x, p3.x)))
	var max_x: float = max(p0.x, max(p1.x, max(p2.x, p3.x)))
	var min_y: float = min(p0.y, min(p1.y, min(p2.y, p3.y)))
	var max_y: float = max(p0.y, max(p1.y, max(p2.y, p3.y)))
	var rect: Rect2 = Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
	var viewport: Viewport = ctrl.get_viewport()
	var root_viewport: Viewport = get_viewport()
	if viewport != root_viewport and viewport is SubViewport:
		var viewport_host: Node = viewport.get_parent()
		if viewport_host is SubViewportContainer:
			var host_rect: Rect2 = _get_screen_rect(viewport_host as Control)
			var viewport_size: Vector2 = Vector2(viewport.size)
			if viewport_size.x > 0.0 and viewport_size.y > 0.0:
				var scale: Vector2 = Vector2(
					host_rect.size.x / viewport_size.x,
					host_rect.size.y / viewport_size.y
				)
				rect.position = host_rect.position + rect.position * scale
				rect.size *= scale
			else:
				rect.position += host_rect.position
	return rect

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
	# For inspection windows, combined_minimum_size is much more reliable than 'size'
	# during the first few frames of population/layout.
	if window is EffectInspectionWindow:
		window.custom_minimum_size = Vector2(GLOSSARY_WINDOW_WIDTH, 0)
		window.size = Vector2(GLOSSARY_WINDOW_WIDTH, 0)
		window.reset_size()
		var min_sz := window.get_combined_minimum_size()
		return Vector2(GLOSSARY_WINDOW_WIDTH, maxf(min_sz.y, window.size.y))
	elif window is InspectionWindow or window is ChoiceWindow:
		window.custom_minimum_size = Vector2(INSPECTION_WINDOW_WIDTH, 0)
		window.size = Vector2(INSPECTION_WINDOW_WIDTH, 0)
		window.reset_size()
		var min_sz := window.get_combined_minimum_size()
		if min_sz != Vector2.ZERO:
			return Vector2(maxf(min_sz.x, INSPECTION_WINDOW_WIDTH), min_sz.y)
			
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

func _calculate_contextual_window_position(anchor: Control, parent_window: Control, window: Control, pos_hint: String = "") -> Vector2:
	var position: Vector2
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
		var viewport_rect: Rect2 = get_viewport().get_visible_rect()
		var vp_pos: Vector2 = Vector2(viewport_rect.position)
		var vp_size: Vector2 = Vector2(viewport_rect.size)
		position = vp_pos + vp_size / 2.0 - _get_window_size(window) / 2.0
	
	return position

func _update_tree_pause_state() -> void:
	var has_tooltip = false
	for i in range(_active_inspection_group.size() - 1, -1, -1):
		var w = _active_inspection_group[i]
		if not is_instance_valid(w):
			_active_inspection_group.remove_at(i)
			continue
		if w.has_meta("window_type"):
			var t = w.get_meta("window_type")
			if t in [&"UnitInspection", &"ItemInspection", &"TraitInspection", &"EffectInspection"]:
				has_tooltip = true
	if has_tooltip:
		has_tooltip = GlobalInteractionRouter.is_inspection_locked()
		
	# Only freeze the game for inspection windows during battle contexts.
	# Outside of battle, the game should not freeze when inspecting.
	if not GameManager.is_in_battle:
		has_tooltip = false
		
	get_tree().paused = has_tooltip or is_game_paused_by_tutorial()

func _get_modal_layer() -> CanvasLayer:
	if not is_instance_valid(_modal_layer):
		_modal_layer = get_tree().get_first_node_in_group("modal_layer")
		if not is_instance_valid(_modal_layer):
			_modal_layer = CanvasLayer.new()
			_modal_layer.name = "ModalLayerFailsafe"
			_modal_layer.layer = 120 # Standardized Modal Layer
			get_tree().root.add_child(_modal_layer)
	return _modal_layer

func get_vfx_layer() -> CanvasLayer:
	if not is_instance_valid(_vfx_layer):
		_vfx_layer = get_tree().get_first_node_in_group("vfx_layer")
		if not is_instance_valid(_vfx_layer):
			_vfx_layer = CanvasLayer.new()
			_vfx_layer.name = "GlobalVFXLayer"
			_vfx_layer.layer = 150 # Above all UI
			_vfx_layer.add_to_group("vfx_layer")
			get_tree().root.call_deferred("add_child", _vfx_layer)
	return _vfx_layer

func clear_vfx_layer() -> void:
	if is_instance_valid(_vfx_layer):
		for child in _vfx_layer.get_children():
			child.queue_free()

func _get_background_ui_layer() -> CanvasLayer:
	if not is_instance_valid(_background_ui_layer):
		_background_ui_layer = get_tree().get_first_node_in_group("background_ui_layer")
		if not is_instance_valid(_background_ui_layer):
			# Create a failsafe background layer if missing
			_background_ui_layer = CanvasLayer.new()
			_background_ui_layer.name = "BackgroundLayerFailsafe"
			_background_ui_layer.layer = 40
			get_tree().root.add_child(_background_ui_layer)
	return _background_ui_layer

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

# Discard slides horizontally from the right
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
	if window.has_method("prepare_for_open"):
		window.prepare_for_open()

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

func _is_battle_inventory_window(window: Control) -> bool:
	return is_instance_valid(window) and window == _persistent_battle_inventory_window

func _queue_free_with_optional_inventory_animation(window: Control) -> void:
	if not is_instance_valid(window):
		return
	if window == _persistent_battle_inventory_window:
		var idx = _active_inspection_group.find(window)
		if idx != -1:
			_active_inspection_group.remove_at(idx)
		_animate_battle_inventory_close(window)
		return
	if window == _persistent_inventory_window:
		var idx = _active_inspection_group.find(window)
		if idx != -1:
			_active_inspection_group.remove_at(idx)
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
	if _is_battle_inventory_window(window):
		_animate_battle_inventory_open(window)
		return
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

	# The inner PanelContainer sits at Y = 340..880 natively (flush above the 200px machine bases at Y = 880).
	var base_top: float = 340.0
	var base_bottom: float = 880.0
	
	# Start panel just below the Y = 880 clip line (inside the machine bases)
	var start_delta: float = 540.0
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
	# Delegate battle inventory to its dedicated close function
	if _is_battle_inventory_window(window):
		_animate_battle_inventory_close(window)
		return true
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
	
	var base_top: float = 340.0
	var base_bottom: float = 880.0
	var final_delta: float = 540.0
	
	var tween: Tween = window.create_tween()
	window.set_meta(_WM_META_ANIM_TWEEN, tween)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Slide the panel container back down behind the machine bases (Y = 880)
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
				var idx = _active_inspection_group.find(window)
				if idx != -1:
					_active_inspection_group.remove_at(idx)
			else:
				window.queue_free()
	)
	return true

# --- BATTLE INVENTORY ANIMATION ---
# Dedicated open/close for the persistent BattleInventoryWindow.
# Uses tray motion (set_open_progress) instead of panel offset animation.
# Tray motion imparts real physics to the balls via AnimatableBody2D,
# so no apply_jolt() is needed.

func _animate_battle_inventory_open(window: Control) -> void:
	if not is_instance_valid(window): return
	if window.has_meta(_WM_META_OPENING) and bool(window.get_meta(_WM_META_OPENING)): return

	window.set_meta(_WM_META_OPENING, true)
	window.set_meta(_WM_META_CLOSING, false)

	if window.has_method("prepare_for_open"):
		window.prepare_for_open()

	_kill_inventory_motion_tween(window)
	Audio.play_sfx("ui_window_open")

	var duration: float = 0.45
	if window.has_method("get_open_duration"):
		duration = window.get_open_duration()

	var tween: Tween = window.create_tween()
	window.set_meta(_WM_META_ANIM_TWEEN, tween)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)

	tween.tween_method(
		Callable(window, "set_open_progress"),
		window.get_open_progress() if window.has_method("get_open_progress") else 0.0,
		1.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.chain().tween_callback(func():
		if is_instance_valid(window):
			window.set_meta(_WM_META_OPENING, false)
			if window.has_method("finish_open"):
				window.finish_open()
			if window.has_meta(_WM_META_ANIM_TWEEN):
				window.remove_meta(_WM_META_ANIM_TWEEN)
	)

func _animate_battle_inventory_close(window: Control) -> void:
	if not is_instance_valid(window): return
	if window.has_meta(_WM_META_CLOSING) and bool(window.get_meta(_WM_META_CLOSING)): return

	window.set_meta(_WM_META_OPENING, false)
	window.set_meta(_WM_META_CLOSING, true)

	if window.has_method("prepare_for_close"):
		window.prepare_for_close()

	_kill_inventory_motion_tween(window)

	var duration: float = 0.35
	if window.has_method("get_close_duration"):
		duration = window.get_close_duration()

	var tween: Tween = window.create_tween()
	window.set_meta(_WM_META_ANIM_TWEEN, tween)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)

	tween.tween_method(
		Callable(window, "set_open_progress"),
		window.get_open_progress() if window.has_method("get_open_progress") else 1.0,
		0.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.chain().tween_callback(func():
		if is_instance_valid(window):
			window.set_meta(_WM_META_CLOSING, false)
			if window.has_method("finish_close"):
				window.finish_close()
			if window.has_meta(_WM_META_ANIM_TWEEN):
				window.remove_meta(_WM_META_ANIM_TWEEN)
			# Do NOT hide — the window stays alive for physics persistence
	)

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

	# Set pivot to center for nice scaling
	window.pivot_offset = window.size / 2.0
	
	# Initial visibility: Show instantly
	window.modulate.a = 1.0
	window.show()
	
	# Reset scale to neutral for the 'instant' look
	window.scale = Vector2.ONE
	
	# Audio
	Audio.play_sfx("ui_window_open")
	
	# Tween: Subtle bouncy overshoot AFTER it's open
	var tween = window.create_tween()
	
	# IMPORTANT: Ensure animation runs even if the game is paused
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Subtle overshoot (1.0 -> 1.04 -> 1.0)
	tween.tween_property(window, "scale", Vector2(1.04, 1.04), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(window, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if root_window is TutorialPopup:
		var tutorial_popup := root_window as TutorialPopup
		tween.finished.connect(tutorial_popup.set_interaction_enabled.bind(true))
