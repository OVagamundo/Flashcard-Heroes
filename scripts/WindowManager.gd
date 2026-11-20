# res://scripts/WindowManager.gd
extends Node

const INSPECTION_WINDOW_MARGIN: float = TooltipPositioner.INSPECTION_WINDOW_MARGIN
const INSPECTION_WINDOW_WIDTH: float = TooltipPositioner.INSPECTION_WINDOW_WIDTH
const GLOSSARY_WINDOW_WIDTH: float = TooltipPositioner.GLOSSARY_WINDOW_WIDTH

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
var is_glossary_locked: bool = true

var _tracked_windows: Dictionary = {}
var _inspection_sources: Dictionary[int, int] = {}
var _location_view_registry: LocationViewRegistry = LocationViewRegistry.new()
var _drawer_animator: DrawerAnimator = DrawerAnimator.new()
var _glossary_controller: GlossaryClusterController = GlossaryClusterController.new()
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

	SignalBus.close_modal_requested.connect(_close_top_modal)
	
	SignalBus.main_scene_requested.connect(_close_all_windows)
	SignalBus.loadout_scene_requested.connect(_close_all_windows)
	SignalBus.title_scene_requested.connect(_close_all_windows)
	SignalBus.path_choice_scene_requested.connect(_close_all_windows)

	call_deferred("_setup_persistent_inventory")
	call_deferred("_setup_persistent_discard_pile")
	
	# Create/destroy the battle inventory window when entering/leaving battle
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
	(_persistent_battle_inventory_window as BattleInventoryWindow).set_open_progress(0.0)

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

	var opening: bool = _drawer_animator.is_opening(win)
	var closing: bool = _drawer_animator.is_closing(win)

	if win in _active_inspection_group:
		if opening or not closing:
			return # Already open or currently opening

	# We are about to open the inventory, so close all other contexts gently
	for iter_win in _active_inspection_group:
		if is_instance_valid(iter_win) and iter_win != win:
			stop_tracking_window(iter_win.get_instance_id())
			_queue_free_with_optional_inventory_animation(iter_win)

	var ctx: Dictionary = _get_battle_inventory_populate_context() if is_battle else _get_run_inventory_populate_context()
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
	var win: Control = _persistent_discard_pile_window
	if not is_instance_valid(win):
		return

	var opening: bool = _drawer_animator.is_opening(win)
	var closing: bool = _drawer_animator.is_closing(win)

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

	var ctx: Dictionary = _get_discard_pile_populate_context()
	(win as DiscardPileWindow).populate(ctx)

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
	var pill: Control = _glossary_controller.get_glossary_pill()
	for i in range(_active_inspection_group.size() - 1, -1, -1):
		var w = _active_inspection_group[i]
		if not is_instance_valid(w):
			_active_inspection_group.remove_at(i)
			continue
		if not _is_persistent_inventory_window(w) and w != pill:
			return true
	return false

## Public API: checks if the current mouse cursor is over any active inspection window or glossary pill.
func is_mouse_over_inspection_cluster() -> bool:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	if _glossary_controller.is_point_inside_glossary_pill(mouse_pos, get_viewport()):
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
		if _drawer_animator.is_closing(win):
			continue
		if win.has_meta("window_type"):
			var type = win.get_meta("window_type")
			if type == &"Inventory" or type == &"DiscardPile":
				return true
		# Fallbacks if meta is missing
		if win == _persistent_inventory_window or win == _persistent_battle_inventory_window or win == _persistent_discard_pile_window:
			return true
	return false

func is_window_opening(window: Control) -> bool:
	return _drawer_animator.is_opening(window)

func is_window_closing(window: Control) -> bool:
	return _drawer_animator.is_closing(window)

func is_run_inventory_window_open() -> bool:
	if not is_instance_valid(_persistent_inventory_window):
		return false
	return _persistent_inventory_window in _active_inspection_group \
		and _persistent_inventory_window.visible \
		and not _drawer_animator.is_closing(_persistent_inventory_window)

func is_battle_inventory_window_open() -> bool:
	if not is_instance_valid(_persistent_battle_inventory_window):
		return false
	return _persistent_battle_inventory_window in _active_inspection_group \
		and _persistent_battle_inventory_window.visible \
		and not _drawer_animator.is_closing(_persistent_battle_inventory_window)

func is_discard_pile_window_open() -> bool:
	if not is_instance_valid(_persistent_discard_pile_window):
		return false
	return _persistent_discard_pile_window in _active_inspection_group \
		and _persistent_discard_pile_window.visible \
		and not _drawer_animator.is_closing(_persistent_discard_pile_window)

func is_run_inventory_window_interactive() -> bool:
	if not is_run_inventory_window_open():
		return false
	if _drawer_animator.is_opening(_persistent_inventory_window) or _drawer_animator.is_closing(_persistent_inventory_window):
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
	if _glossary_controller.is_point_inside_glossary_pill(pos, get_viewport()):
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
		if is_instance_valid(w) and w.is_visible_in_tree() and not _drawer_animator.is_closing(w):
			return true
	return false

func is_options_window_open() -> bool:
	for w in _active_inspection_group:
		if is_instance_valid(w) and w.get_meta("window_type", &"") == &"Options":
			return not _drawer_animator.is_closing(w)
	for w in _modal_stack:
		if is_instance_valid(w) and w.get_meta("window_type", &"") == &"Options":
			return not _drawer_animator.is_closing(w)
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
	if GameManager.is_in_battle:
		var is_already_paused: bool = BattleAnimator.is_paused()
		if not is_already_paused:
			_combat_paused_by_options = true
			ActionQueue.request(PauseRunAction.new(true))
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
			ActionQueue.request(PauseRunAction.new(false))


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

	window_instance.populate(populate_context)

	if anchor_view != null and window_instance in _active_inspection_group and (window_instance is UnitInspectionWindow or window_instance is ItemInspectionWindow):
		var source: Control = _entity_view_for_anchor(anchor_view)
		_inspection_sources[window_instance.get_instance_id()] = source.get_instance_id()
		SignalBus.view_inspection_changed.emit(source, true)

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
	return _glossary_controller.collect_recursive_glossary_specs(root_window, _active_inspection_group)

func _refresh_glossary_windows_state() -> void:
	_glossary_controller.refresh_glossary_windows_state(self)

func _spawn_and_layout_glossary_only(root_window: Control, anchor: Control) -> void:
	await _glossary_controller.spawn_and_layout_glossary_only(self, root_window, anchor)

func setup_child_windows_for_modal(modal: Control, preview_win: InspectionWindow) -> void:
	await _glossary_controller.setup_child_windows_for_modal(self, modal, preview_win)

func close_modal_child_windows(modal: Control) -> void:
	_glossary_controller.close_modal_child_windows(self, modal)

func _setup_and_layout_child_windows(root_window: Control, anchor: Control) -> void:
	await _glossary_controller.setup_and_layout_child_windows(self, root_window, anchor)

func _layout_child_windows(source_rect: Rect2, root_window: Control, children: Array[Control]) -> void:
	_glossary_controller.layout_child_windows(source_rect, root_window, children, get_viewport())

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
	_glossary_controller.update_glossary_pill_for_root(self, root_window)

func _update_glossary_pill_position(root_window: Control) -> void:
	_glossary_controller.update_glossary_pill_position(self, root_window)

func _close_glossary_pill() -> void:
	_glossary_controller.close_glossary_pill(self)

func close_glossary_pill() -> void:
	_glossary_controller.close_glossary_pill(self)

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

func register_location_view(loc: LocationIdentifier, view: Control, is_container: bool = false) -> void:
	_location_view_registry.register_view(loc, view, is_container)

func unregister_location_view(view: Control) -> void:
	_location_view_registry.unregister_view(view)

func find_view_for_location(loc: LocationIdentifier) -> Control:
	if not is_instance_valid(loc):
		return null
	if loc.container == C.BATTLE_CONTAINER_TAGS.ENEMY_BANNER and loc.index == 0:
		var banner: EnemyBannerView = get_tree().get_first_node_in_group("enemy_banner_view") as EnemyBannerView
		return banner if banner != null and banner.is_visible_in_tree() else null
	return _location_view_registry.find_view(loc)

# Public API: find the entity view (e.g. GachaBallView) for a location, unwrapping SlotView if necessary
func find_entity_view_for_location(loc: LocationIdentifier) -> Control:
	return _entity_view_for_anchor(find_view_for_location(loc))

func _entity_view_for_anchor(anchor: Control) -> Control:
	if anchor is SlotView:
		for child: Node in anchor.get_children():
			if child is GachaBallView and not child.is_queued_for_deletion():
				return child as GachaBallView
	return anchor

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
		
		# Snapshot Rule (BUG-VCR-01): During combat VCR playback, read strictly from
		# VisualSnapshotStore so mid-combat inspection never leaks future post-turn state.
		var is_vcr_snapshot: bool = false
		var snapshot_instances_db: Dictionary = {}
		if BattleAnimator.is_snapshot_playback_active():
			var store: VisualSnapshotStore = BattleAnimator.get_visual_snapshot_store()
			var resolved_uuid: String = target_uuid
			if resolved_uuid.is_empty():
				resolved_uuid = store.get_uuid_at_location(loc)
			if not resolved_uuid.is_empty() and store.has_uuid(resolved_uuid):
				instance = store.build_preview_instance(resolved_uuid)
				snapshot_instances_db = store.build_preview_db()
				is_vcr_snapshot = true

		if not is_vcr_snapshot and not target_uuid.is_empty():
			instance = GameManager.get_instance_by_uuid(target_uuid)
				
		# Fallback 2: Normal location lookup
		if not is_vcr_snapshot and not is_instance_valid(instance):
			instance = GameManager.get_instance_from_location(loc)
			
		# Fallback 3: Explicit instance from source view metadata or parent (e.g. Loadout preview)
		if not is_instance_valid(instance):
			if is_instance_valid(source_view) and source_view.has_meta("gachaball_instance"):
				instance = source_view.get_meta("gachaball_instance")
			elif is_instance_valid(source_view) and is_instance_valid(source_view.get_parent()) and source_view.get_parent().has_meta("gachaball_instance"):
				instance = source_view.get_parent().get_meta("gachaball_instance")
			elif is_instance_valid(loc) and loc.has_meta("gachaball_instance"):
				instance = loc.get_meta("gachaball_instance")
			
		if not is_instance_valid(instance): return {}
		var def = instance.get_definition()
		var is_preview_mode: bool = (is_instance_valid(source_view) and source_view.get_meta("is_preview", false)) or (is_instance_valid(loc) and loc.get_meta("is_preview", false)) or not is_instance_valid(GameManager.run_state)
		if def.category == &"UNIT":
			window_type = &"UnitInspection"
			context = {
				"source_view": source_view,
				"instance": instance,
				"location": loc,
				"is_preview": is_preview_mode,
				"is_vcr_snapshot": is_vcr_snapshot,
				"snapshot_instances_db": snapshot_instances_db
			}
			if loc.container == &"EnemyLineup":
				context["is_enemy_context"] = true
		elif def.category in [&"ITEM", &"TRINKET", &"CONSUMABLE"]:
			window_type = &"ItemInspection"
			context = {
				"source_view": source_view,
				"instance": instance,
				"location": loc,
				"is_preview": is_preview_mode,
				"is_vcr_snapshot": is_vcr_snapshot,
				"snapshot_instances_db": snapshot_instances_db
			}
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
	if _inspection_sources.has(window_id):
		var source_id: int = _inspection_sources[window_id]
		_inspection_sources.erase(window_id)
		var source: Control = instance_from_id(source_id) as Control
		if source != null and not _inspection_sources.values().has(source_id):
			SignalBus.view_inspection_changed.emit(source, false)

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
	_drawer_animator.clear_window_state(window_id)
	_glossary_controller.close_modal_child_windows_by_id(self, window_id)
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

func _has_glossary_clearance_specs(window: Control) -> bool:
	if not is_glossary_locked:
		return false
	if not (window is InspectionWindow or window is ChoiceWindow):
		return false
	return not _collect_recursive_glossary_specs(window).is_empty()

func _calculate_window_position(source_view: Control, new_window: Control) -> Vector2:
	return TooltipPositioner.calculate_window_position(
		source_view, new_window, get_viewport(), is_glossary_locked, _has_glossary_clearance_specs(new_window)
	)

func _calculate_child_window_position_from_anchor(_parent_window: Control, anchor: Control, child_window: Control) -> Vector2:
	return TooltipPositioner.calculate_child_window_position_from_anchor(anchor, child_window, get_viewport())

func _calculate_centered_over_anchor(anchor: Control, new_window: Control) -> Vector2:
	return TooltipPositioner.calculate_centered_over_anchor(anchor, new_window, get_viewport())

func _calculate_top_center_over_anchor(anchor: Control, new_window: Control) -> Vector2:
	return TooltipPositioner.calculate_top_center_over_anchor(anchor, new_window, get_viewport())

func _calculate_left_of_anchor(anchor: Control, new_window: Control) -> Vector2:
	return TooltipPositioner.calculate_left_of_anchor(anchor, new_window, get_viewport())

func _get_screen_rect(ctrl: Control) -> Rect2:
	return TooltipPositioner.get_screen_rect(ctrl, get_viewport())

func _set_window_screen_position(window: Control, screen_pos: Vector2) -> void:
	TooltipPositioner.set_window_screen_position(window, screen_pos)

func _find_canvas_layer(node: Node) -> CanvasLayer:
	return TooltipPositioner.find_canvas_layer(node)

func _get_window_size(window: Control) -> Vector2:
	return TooltipPositioner.get_window_size(window)

func _calculate_child_window_position(parent_window: Control, child_window: Control) -> Vector2:
	return TooltipPositioner.calculate_child_window_position(parent_window, child_window, get_viewport())

func _calculate_contextual_window_position(anchor: Control, parent_window: Control, window: Control, pos_hint: String = "") -> Vector2:
	return TooltipPositioner.calculate_contextual_window_position(
		anchor, parent_window, window, pos_hint, get_viewport(), is_glossary_locked, _has_glossary_clearance_specs(window)
	)

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
	return TooltipPositioner.clamp_window_to_viewport(pos, size, get_viewport().get_visible_rect())

# --- UI ANIMATION (Delegated to DrawerAnimator) ---

func _is_discard_pile_window(window: Control) -> bool:
	return _drawer_animator.is_discard_pile_window(window)

func _animate_discard_pile_open(window: Control) -> void:
	_drawer_animator.animate_discard_pile_open(window)

func _animate_discard_pile_close(window: Control) -> void:
	_drawer_animator.animate_discard_pile_close(window)

func _is_inventory_window(window: Control) -> bool:
	return _drawer_animator.is_inventory_window(window)

func _is_battle_inventory_window(window: Control) -> bool:
	return is_instance_valid(window) and window == _persistent_battle_inventory_window

func _queue_free_with_optional_inventory_animation(window: Control) -> void:
	if not is_instance_valid(window):
		return
	if window == _persistent_battle_inventory_window:
		var idx: int = _active_inspection_group.find(window)
		if idx != -1:
			_active_inspection_group.remove_at(idx)
		_animate_battle_inventory_close(window)
		return
	if window == _persistent_inventory_window:
		var idx: int = _active_inspection_group.find(window)
		if idx != -1:
			_active_inspection_group.remove_at(idx)
		_animate_inventory_window_close(window)
		return
	if window == _persistent_discard_pile_window:
		var idx: int = _active_inspection_group.find(window)
		if idx != -1:
			_active_inspection_group.remove_at(idx)
		_animate_discard_pile_close(window)
		return
	if _animate_inventory_window_close(window):
		return
	window.queue_free()

func _kill_inventory_motion_tween(window: Control) -> void:
	_drawer_animator.kill_motion_tween(window)

func _animate_inventory_window_open(window: Control) -> void:
	_drawer_animator.animate_inventory_window_open(window, _persistent_battle_inventory_window)

func _animate_inventory_window_close(window: Control) -> bool:
	return _drawer_animator.animate_inventory_window_close(
		window, _persistent_inventory_window, _persistent_battle_inventory_window, _active_inspection_group
	)

func _animate_battle_inventory_open(window: Control) -> void:
	_drawer_animator.animate_battle_inventory_open(window)

func _animate_battle_inventory_close(window: Control) -> void:
	_drawer_animator.animate_battle_inventory_close(window)

func _animate_window_open(window: Control) -> void:
	_drawer_animator.animate_window_open(window, _persistent_battle_inventory_window)
