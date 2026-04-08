extends Node

const InputUtils = preload("res://scripts/InputUtils.gd")

## The GlobalInteractionRouter is the single source of truth for interpreting user intent.
## It receives InteractionContext from clicked views and generates command queues.

## Command types that can be generated
enum CommandType {
	DESELECT,
	SELECT,
	OPEN_INSPECTION_WINDOW,
	CLOSE_ALL_INSPECTION_WINDOWS,
	CLOSE_CHILD_WINDOWS,
	CLOSE_TOP_CONTEXTUAL_WINDOW,
	REQUEST_ACTION,
	INVALID_ACTION
}

## Command structure for the command queue
class Command:
	var cmd: CommandType
	var context: Dictionary = {}
	
	func _init(command_type: CommandType, command_context: Dictionary = {}) -> void:
		cmd = command_type
		context = command_context

## Current selection state
var _current_selection: InteractionContext = null

## Reference to WindowManager for window operations
var _window_manager: Node = null

## Combat state (gated interactions during COMBAT phase)
var _is_combat_phase: bool = false

## Drag-and-drop state (centralized in GIR per spec)
var _is_drag_active: bool = false
var _drag_origin_context: InteractionContext = null
var _drag_source_view: Control = null
var _drag_placeholder: Control = null
var _drag_overlay_preview: Control = null
var _drag_preview_layer: CanvasLayer = null
var _suppress_close_parent_window_id: int = -1
var _suppress_close_until_msec: int = 0
var _is_ui_transitioning: bool = false

## Hover/Lock inspection state (SEPARATE from _current_selection)
var _locked_entity_view_id: int = -1 # instance_id of view with locked inspection
var _hover_entity_view_id: int = -1 # instance_id of view currently being hovered
var _is_inspection_locked: bool = false # true = sticky window, hover cannot replace

func _ready() -> void:
	# Register as singleton
	add_to_group("global_interaction_router")
	set_process(true)
	
	# Get references to other managers
	_window_manager = WindowManager
	
	# Connect to interaction signals
	SignalBus.interaction_context_received.connect(_on_interaction_context_received)
	# Proactively clear selection on scene transitions and other flows that request it
	if SignalBus.has_signal("selection_clear_requested"):
		SignalBus.selection_clear_requested.connect(_on_selection_clear_requested)
	# Track battle phase to gate interactions during COMBAT
	if SignalBus.has_signal("battle_phase_changed"):
		SignalBus.battle_phase_changed.connect(_on_battle_phase_changed)
	if SignalBus.has_signal("interaction_lock_requested"):
		SignalBus.interaction_lock_requested.connect(_on_interaction_lock_requested)
	
	SignalBus.battle_inventory_transition_started.connect(_on_battle_inventory_transition_started)
	SignalBus.battle_inventory_transition_finished.connect(_on_battle_inventory_transition_finished)
	
	# Connect to WindowManager closing signal to clear stale selections
	if _window_manager.has_signal("window_closed"):
		_window_manager.window_closed.connect(_on_window_closed)


func _exit_tree() -> void:
	# Scene cleanup per spec: clear drag and selection
	_end_drag_visuals(false)
	_is_drag_active = false
	_drag_origin_context = null
	# Clear hover/lock state
	_is_inspection_locked = false
	_locked_entity_view_id = -1
	_hover_entity_view_id = -1
	# Emit deselect if needed
	if _current_selection != null:
		_emit_view_deselected(_current_selection)
		_emit_selection_changed(null)
	_is_drag_active = false
	_drag_origin_context = null
	# Disconnect SignalBus hooks connected in _ready()
	if SignalBus.interaction_context_received.is_connected(_on_interaction_context_received):
		SignalBus.interaction_context_received.disconnect(_on_interaction_context_received)
	if SignalBus.has_signal("interaction_lock_requested") and SignalBus.interaction_lock_requested.is_connected(_on_interaction_lock_requested):
		SignalBus.interaction_lock_requested.disconnect(_on_interaction_lock_requested)
	if SignalBus.has_signal("node_selected") and SignalBus.node_selected.is_connected(_on_node_selected):
		SignalBus.node_selected.disconnect(_on_node_selected)
	if SignalBus.has_signal("selection_clear_requested") and SignalBus.selection_clear_requested.is_connected(_on_selection_clear_requested):
		SignalBus.selection_clear_requested.disconnect(_on_selection_clear_requested)
	if SignalBus.has_signal("battle_phase_changed") and SignalBus.battle_phase_changed.is_connected(_on_battle_phase_changed):
		SignalBus.battle_phase_changed.disconnect(_on_battle_phase_changed)
	if _window_manager and _window_manager.has_signal("window_closed"):
		if _window_manager.is_connected("window_closed", _on_window_closed):
			_window_manager.disconnect("window_closed", _on_window_closed)
	_clear_drag_overlay_preview()
	if is_instance_valid(_drag_preview_layer):
		_drag_preview_layer.queue_free()
	_drag_preview_layer = null

## Main entry point for processing interactions
func _on_interaction_context_received(context: InteractionContext) -> void:
	var command_queue: Array[Command] = []

	# Full input lock during COMBAT or UI Transitions
	if _is_combat_phase or _is_ui_transitioning:
		return

	# Hover events: handled separately, never enter the click-based command queue
	if context.event_type == &"HOVER_ENTER":
		_handle_hover_enter(context)
		return
	if context.event_type == &"HOVER_EXIT":
		_handle_hover_exit(context)
		return
		
	# Drag Start: handled separately to initialize drag state
	# ROBUSTNESS: Check both StringName and string to avoid type issues
	if context.event_type == &"DRAG_START" or str(context.event_type) == "DRAG_START":
		print("DEBUG_GIR: DRAG_START intercepted for ", context.entity_type)
		start_drag(context)
		return

	# Hover-to-Lock Promotion: if clicking the entity whose hover window is already
	# showing, promote the hover to a lock RIGHT NOW so the rest of the flow sees it
	# as "already locked" and skips close→reopen (brief L271-273: no churn).
	if _hover_entity_view_id != -1 and _hover_entity_view_id == context.source_view_instance_id:
		_is_inspection_locked = true
		_locked_entity_view_id = _hover_entity_view_id

	# Clear hover state on any click (hover is replaced by lock or selection)
	_hover_entity_view_id = -1

	# Generate commands based on the interaction context and current state
	command_queue = _generate_command_queue(context)
	
	if context.event_type != &"HOVER_ENTER" and context.event_type != &"HOVER_EXIT":
		print("DEBUG_GIR: Processing ", context.entity_type, " Event: ", context.event_type)
		print("DEBUG_GIR: Locked: ", _is_inspection_locked, " | LockedID: ", _locked_entity_view_id)
		print("DEBUG_GIR: Selection: ", _current_selection != null)
		print("DEBUG_GIR: Commands: ", command_queue.size())
		for cmd in command_queue:
			print("DEBUG_GIR: + CMD: ", cmd.cmd)

	# Execute the command queue
	_execute_command_queue(command_queue)

func _process(_delta: float) -> void:
	if is_instance_valid(_drag_overlay_preview):
		_drag_overlay_preview.global_position = get_viewport().get_mouse_position()

## High-priority input handling (Escape, true background)
func _unhandled_input(event: InputEvent) -> void:
	# Full input lock during COMBAT: swallow ESC/background clicks
	if _is_combat_phase:
		return
	# ESC: cancel drag, then modals, then contextual windows, then selection
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# 1) Cancel active drag if any
		if _is_drag_active:
			end_drag(false)
			_end_drag_visuals(false)
			return
		# 2) Try to close a modal (WindowManager listens to this signal)
		if SignalBus.has_signal("close_modal_requested"):
			SignalBus.emit_signal("close_modal_requested")
			return
		# 3) Clear lock/hover state
		_is_inspection_locked = false
		_locked_entity_view_id = -1
		_hover_entity_view_id = -1
		# 4) Close contextual windows (guarded by suppression) and clear selection
		if not _is_close_suppressed_now():
			_execute_close_all_inspection_windows()
		_execute_deselect()
		return

	# True background click: left mouse press not handled by any Control
	if InputUtils.is_primary_pointer_press(event):
		# Clear lock/hover state
		_is_inspection_locked = false
		_locked_entity_view_id = -1
		_hover_entity_view_id = -1
		# Close contextual windows and clear selection (guarded by suppression)
		if not _is_close_suppressed_now():
			_execute_close_all_inspection_windows()
		_execute_deselect()

## External signal handler: proactively clear selection when requested (e.g., scene transitions)
func _on_selection_clear_requested() -> void:
	# Clear lock/hover state
	_is_inspection_locked = false
	_locked_entity_view_id = -1
	_hover_entity_view_id = -1
	# Always clear selection if present
	if _current_selection != null:
		_execute_deselect()
	# Also activate a brief, contextless close suppression to guard the very next click
	# after system-driven actions (e.g., shop purchase, reward choice). This prevents
	# GR-4 global close or background handlers from triggering immediately.
	var until_ts := Time.get_ticks_msec() + 240
	_suppress_close_parent_window_id = 0
	_suppress_close_until_msec = until_ts

func _on_node_selected(_node_def: PathNodeDefinition) -> void:
	pass

# Handler for external lock requests
func _on_interaction_lock_requested(locked: bool) -> void:
	_is_inspection_locked = locked

## Track battle phase to enforce COMBAT gating
func _on_battle_phase_changed(phase_name: StringName) -> void:
	_is_combat_phase = phase_name == &"COMBAT"
	# If entering COMBAT, ensure any drag state and engine preview are cleared
	if _is_combat_phase:
		# Clear lock/hover state
		_is_inspection_locked = false
		_locked_entity_view_id = -1
		_hover_entity_view_id = -1
		if _is_drag_active:
			end_drag(false)
		# Also cancel engine-managed drag preview to avoid lingering visuals
		var vp := get_viewport()
		if vp and vp.has_method("gui_cancel_drag"):
			vp.gui_cancel_drag()

func _on_battle_inventory_transition_started(_is_opening: bool) -> void:
	_is_ui_transitioning = true
	if _is_drag_active:
		end_drag(false)

func _on_battle_inventory_transition_finished() -> void:
	_is_ui_transitioning = false

## Handler for WindowManager.window_closed signal
## Clears selection if the selected item was inside the closed window.
func _on_window_closed(window: Control) -> void:
	if _current_selection == null: return
	
	# Resolve the view for the current selection
	var sel_view_id = _current_selection.source_view_instance_id
	var sel_view = _find_view_by_instance_id(sel_view_id)
	
	if is_instance_valid(sel_view) and is_instance_valid(window):
		# check if selection is inside the closed window
		if window == sel_view or window.is_ancestor_of(sel_view):
			print("DEBUG_GIR: Selection invalidated by window close. Window=", window.get_class(), " Name=", window.name)
			_execute_deselect()

## Generate command queue based on interaction context and current state
func _generate_command_queue(context: InteractionContext) -> Array[Command]:
	var commands: Array[Command] = []
	
	# If a drag is active, this incoming context is the drop target.
	if _is_drag_active and _drag_origin_context != null:
		# Check if source is from a SelectionOnly context (Shop, Rewards)
		# In SelectionOnly contexts, dragging is for selection/inspection only - no actions are valid
		var source_group = get_context_group(_drag_origin_context.location.container) if _drag_origin_context.location else &""
		if source_group == &"SelectionOnly":
			# Keep the dragged item selected, don't try to process an action
			# The item was already selected in start_drag()
			return commands
		
		# For other contexts: Command Queue: [REQUEST_ACTION, DESELECT] (Rule S6)
		var req_ctx: Dictionary = {
			"source_context": _drag_origin_context,
			"target_context": context,
		}
		# Attach target parent window information for suppression
		var tgt_parent_id := _resolve_parent_window_id_for_context(context)
		if tgt_parent_id != -1:
			req_ctx["target_parent_window_id"] = tgt_parent_id
			req_ctx["is_inside_unit_inspection"] = _is_unit_inspection_window_id(tgt_parent_id)
		commands.append(Command.new(CommandType.REQUEST_ACTION, req_ctx))
		commands.append(Command.new(CommandType.DESELECT))
		return commands
	
	# TDD Rule: ANYWHERE outside window group should close entire group
	# IMPORTANT: Do NOT apply this to UI_LINK interactions, which originate inside windows
	if context.entity_type != &"UI_LINK":
		if _window_manager and _window_manager.is_any_inspection_window_open():
			# First, prune children when clicking anywhere inside a window (except explicit WINDOW_BACKGROUND, handled below)
			var src_view = _find_view_by_instance_id(context.source_view_instance_id)
			if src_view and context.entity_type != &"WINDOW_BACKGROUND":
				var parent_window: Control = _window_manager.find_ancestor_window_for_view(src_view)
				if is_instance_valid(parent_window):
					# Guard: do NOT prune children when clicking the anchor of a locked
					# inspection window. The locked child IS one of those children, and
					# pruning it would destroy it while lock state says "still open".
					# This divergence only matters in the Inventory context where
					# anchors live inside a tracked InventoryWindow (not on the battle board).
					var skip_prune := _is_inspection_locked and _locked_entity_view_id == context.source_view_instance_id
					if not skip_prune:
						commands.append(Command.new(CommandType.CLOSE_CHILD_WINDOWS, {
							"parent_window_id": parent_window.get_instance_id()
						}))
			# Next, if the click is outside all windows, close the entire group
			if not _is_click_inside_inspection_group(context):
				# Suppress global close if an in-window action just occurred. Prefer context-aware suppression,
				# but fall back to contextless suppression for true background contexts.
				var suppressed := _is_close_suppressed_for_context(context)
				if not suppressed and _is_close_suppressed_now():
					suppressed = true
				# Don't close the window if it's locked on the entity being clicked
				# (hover-to-lock promotion or re-click on locked entity)
				if not suppressed and _is_inspection_locked and _locked_entity_view_id == context.source_view_instance_id:
					suppressed = true
				if not suppressed:
					commands.append(Command.new(CommandType.CLOSE_ALL_INSPECTION_WINDOWS))
	
	# Handle different entity types
	match context.entity_type:
		&"GLOBAL_BACKGROUND":
			# GR-4: Close on "True" Background Click
			# Guard with suppression to avoid closing immediately after an in-window action
			if not _is_close_suppressed_now():
				commands.append(Command.new(CommandType.CLOSE_ALL_INSPECTION_WINDOWS))
				# User Feedback: Clicking outside should also deselect (not just close)
				commands.append(Command.new(CommandType.DESELECT))
			
		&"WINDOW_BACKGROUND":
			# GR-6: Child Window Closure - prune that branch
			commands.append(Command.new(CommandType.CLOSE_CHILD_WINDOWS, {
				"window_group_id": context.window_group_id,
				"parent_window_id": context.source_view_instance_id
			}))
			# User Feedback: Clicking window background should also deselect (not just close children)
			commands.append(Command.new(CommandType.DESELECT))
			
		&"UNIT", &"ITEM", &"TRINKET", &"CONSUMABLE":
			commands.append_array(_handle_gachaball_interaction(context))
			
		&"EMPTY_SLOT":
			commands.append_array(_handle_empty_slot_interaction(context))
			
		&"UI_LINK":
			commands.append_array(_handle_ui_link_interaction(context))
	
	return commands

# ---------------------------------------------------------------------------
# Hover-to-Inspect Handlers (PC Only)
# ---------------------------------------------------------------------------

## PC hover-to-inspect: open temporary inspection if conditions allow
func _handle_hover_enter(context: InteractionContext) -> void:
	# Guard: don't hover if dragging, locked, or suppressed
	if _is_drag_active: return
	if _is_inspection_locked: return
	if _is_close_suppressed_now(): return
	# Guard: duplicate hover (same entity)
	if context.source_view_instance_id == _hover_entity_view_id: return

	_hover_entity_view_id = context.source_view_instance_id

	# Guard: If an inventory window is currently dominating the screen,
	# we MUST NOT allow hovers on entities that exist OUTSIDE that inventory window.
	# Otherwise, interacting with the background battle board will cause a Focus Change
	# and automatically close the inventory.
	if _window_manager and _window_manager.is_any_inventory_window_open():
		var source_view = _find_view_by_instance_id(context.source_view_instance_id)
		if is_instance_valid(source_view):
			var ancestor_window = _window_manager.find_ancestor_window_for_view(source_view)
			# If the hovered item doesn't belong to any window, or belongs to a different window, block it.
			if not is_instance_valid(ancestor_window) or not _window_manager.is_any_inventory_window_open(): # Actually, we just check if it's in a window at all since inventory is active
				# Ensure we check if the ancestor window itself is an inventory window
				var is_hovered_inside_inventory = false
				if ancestor_window:
					if ancestor_window.has_meta("window_type"):
						var t = ancestor_window.get_meta("window_type")
						if t == &"Inventory" or t == &"DiscardPile":
							is_hovered_inside_inventory = true
					elif "InventoryWindow" in ancestor_window.name or "DiscardPileWindow" in ancestor_window.name:
						is_hovered_inside_inventory = true
				
				if not is_hovered_inside_inventory:
					_hover_entity_view_id = -1
					return

	# Open inspection via command queue
	var commands: Array[Command] = []
	commands.append(Command.new(CommandType.OPEN_INSPECTION_WINDOW, {
		"context": context,
		"anchor_view_id": context.source_view_instance_id
	}))
	_execute_command_queue(commands)

## PC hover-exit: close temporary inspection if not locked
func _handle_hover_exit(context: InteractionContext) -> void:
	# Only close if this exit matches the current hover
	if context.source_view_instance_id != _hover_entity_view_id: return
	_hover_entity_view_id = -1

	# Don't close if locked (the window is now sticky)
	if _is_inspection_locked: return
	# Don't close during drag (drag cleared hover already)
	if _is_drag_active: return
	# Respect suppression (brief L147, L329: do not close outside suppression guard)
	if _is_close_suppressed_now(): return

	# Close ONLY the topmost window — NOT all windows.
	# The hover-opened inspection is always the top of _active_inspection_group.
	# Using CLOSE_ALL would destroy parent windows (e.g., InventoryWindow) — brief L179.
	if _window_manager:
		_window_manager.close_top_contextual_window()

## Handle interactions with GachaBall instances
func _handle_gachaball_interaction(context: InteractionContext) -> Array[Command]:
	var commands: Array[Command] = []
	
	# Legacy: _is_inspection_event() now always returns false;
	# hover replaces double-click, and lock replaces single-click inspection.
	
	# Handle selection and action logic
	match context.interaction_mode:
		&"FULLY_INTERACTIVE":
			commands.append_array(_handle_fully_interactive(context))
		&"SELECTION_ONLY":
			commands.append_array(_handle_selection_only(context))
		&"INSPECTION_ONLY":
			# Single-click locks inspection (no selection in InspectionOnly)
			if _is_inspection_locked and _locked_entity_view_id == context.source_view_instance_id:
				# BATTLE BOARD FIX: Already locked on this entity -> Toggle Off (Close)
				commands.append(Command.new(CommandType.CLOSE_TOP_CONTEXTUAL_WINDOW))
				commands.append(Command.new(CommandType.DESELECT))
			else:
				commands.append(Command.new(CommandType.OPEN_INSPECTION_WINDOW, {
					"context": context,
					"anchor_view_id": context.source_view_instance_id,
					"lock": true
				}))
	
	return commands

## Handle fully interactive contexts (battle board, inventory)
func _handle_fully_interactive(context: InteractionContext) -> Array[Command]:
	var commands: Array[Command] = []
	
	# Check if we have a current selection
	if _current_selection != null:
		# S4: Re-selection on already-locked entity -> Toggle Off (Close Top & Deselect)
		if _is_inspection_locked and _locked_entity_view_id == context.source_view_instance_id:
			# Use CLOSE_TOP to pop just the inspection, not the parent Inventory
			commands.append(Command.new(CommandType.CLOSE_TOP_CONTEXTUAL_WINDOW))
			commands.append(Command.new(CommandType.DESELECT))
			return commands
		
		# Re-Selection Inspects (S4): single-click on already-selected opens inspection + locks
		# Keep parent selected when opening its inspection window
		if _current_selection.source_view_instance_id == context.source_view_instance_id:
			commands.append(Command.new(CommandType.OPEN_INSPECTION_WINDOW, {
				"context": context,
				"anchor_view_id": context.source_view_instance_id,
				"lock": true
			}))
			return commands
		
		# Check for inventory tier change rule
		if _is_inventory_tier_change(_current_selection, context):
			commands.append(Command.new(CommandType.DESELECT))
			commands.append(Command.new(CommandType.SELECT, {"context": context}))
			# Lock inspection on new entity
			commands.append(Command.new(CommandType.OPEN_INSPECTION_WINDOW, {
				"context": context,
				"anchor_view_id": context.source_view_instance_id,
				"lock": true
			}))
			return commands
		
		# Check if this is a valid action target
		if _is_valid_action_target(_current_selection, context):
			var req_ctx: Dictionary = {
				"source_context": _current_selection,
				"target_context": context,
			}
			var tgt_parent_id := _resolve_parent_window_id_for_context(context)
			if tgt_parent_id != -1:
				req_ctx["target_parent_window_id"] = tgt_parent_id
				req_ctx["is_inside_unit_inspection"] = _is_unit_inspection_window_id(tgt_parent_id)
			commands.append(Command.new(CommandType.REQUEST_ACTION, req_ctx))
			# Clear selection after any action (valid or invalid)
			commands.append(Command.new(CommandType.DESELECT))
		else:
			# Not a valid action target - this is a "Change of Focus" (Rule S2)
			# Only close windows if clicking OUTSIDE the inspection group
			# Clicks on selectable items INSIDE windows should preserve the window
			var click_inside_window = _is_click_inside_inspection_group(context)
			if not click_inside_window and not _is_close_suppressed_for_context(context):
				# GR-5: Close on Invalid Action Click (only for clicks outside windows)
				commands.append(Command.new(CommandType.CLOSE_ALL_INSPECTION_WINDOWS))
			commands.append(Command.new(CommandType.DESELECT))
			commands.append(Command.new(CommandType.SELECT, {"context": context}))
			# Replace lock to new entity
			commands.append(Command.new(CommandType.OPEN_INSPECTION_WINDOW, {
				"context": context,
				"anchor_view_id": context.source_view_instance_id,
				"lock": true
			}))
	else:
		# No current selection -> select + lock inspection
		commands.append(Command.new(CommandType.SELECT, {"context": context}))
		# If already locked on this entity (hover promoted to lock), don't reopen
		if not (_is_inspection_locked and _locked_entity_view_id == context.source_view_instance_id):
			commands.append(Command.new(CommandType.OPEN_INSPECTION_WINDOW, {
				"context": context,
				"anchor_view_id": context.source_view_instance_id,
				"lock": true
			}))
	
	return commands

## Handle selection-only contexts (shop, rewards)
func _handle_selection_only(context: InteractionContext) -> Array[Command]:
	var commands: Array[Command] = []
	
	# In selection-only contexts, clicking the already-selected item should open inspection (S4 equivalent).
	if _current_selection != null:
		var same_view: bool = _current_selection.source_view_instance_id == context.source_view_instance_id
		var same_loc: bool = _current_selection.location and context.location \
			and _current_selection.location.container == context.location.container \
			and _current_selection.location.index == context.location.index
		if same_view or same_loc:
			# No-churn: already locked on this entity
			if _is_inspection_locked and _locked_entity_view_id == context.source_view_instance_id:
				return commands
			# Keep parent selected when opening its inspection window + lock
			commands.append(Command.new(CommandType.OPEN_INSPECTION_WINDOW, {
				"context": context,
				"anchor_view_id": context.source_view_instance_id,
				"lock": true
			}))
			return commands
	
	# Default: always change selection in selection-only contexts
	commands.append(Command.new(CommandType.DESELECT))
	commands.append(Command.new(CommandType.SELECT, {"context": context}))
	
	return commands

## Handle empty slot interactions
func _handle_empty_slot_interaction(context: InteractionContext) -> Array[Command]:
	var commands: Array[Command] = []
	
	# Check if we have a current selection
	if _current_selection != null:
		# Check for inventory tier change (special rule for inventory windows)
		if _is_inventory_tier_change(_current_selection, context):
			# TDD Rule: Inventory tier changes should be handled as selection changes
			commands.append(Command.new(CommandType.DESELECT))
			# Note: Empty slots don't get selected, so we just deselect
		# Check if this is a valid move target
		elif _is_valid_move_target(_current_selection, context):
			var req_ctx: Dictionary = {
				"source_context": _current_selection,
				"target_context": context,
			}
			var tgt_parent_id := _resolve_parent_window_id_for_context(context)
			if tgt_parent_id != -1:
				req_ctx["target_parent_window_id"] = tgt_parent_id
				req_ctx["is_inside_unit_inspection"] = _is_unit_inspection_window_id(tgt_parent_id)
			commands.append(Command.new(CommandType.REQUEST_ACTION, req_ctx))
			# Clear selection after any action (valid or invalid)
			commands.append(Command.new(CommandType.DESELECT))
		else:
			# Invalid target - only close windows if clicking OUTSIDE the inspection group
			var click_inside_window = _is_click_inside_inspection_group(context)
			if not click_inside_window and not _is_close_suppressed_for_context(context):
				commands.append(Command.new(CommandType.CLOSE_ALL_INSPECTION_WINDOWS))
			commands.append(Command.new(CommandType.DESELECT))
	
	return commands

## Handle UI link interactions (like "EFFECTS" links)
func _handle_ui_link_interaction(context: InteractionContext) -> Array[Command]:
	var commands: Array[Command] = []
	
	# TDD Rule: Effects link should close existing children of the current window
	# Resolve the actual parent window containing the link, even if the source id is a child label
	var parent_window_id: int = -1
	if _window_manager:
		var src_view: Control = _find_view_by_instance_id(context.source_view_instance_id)
		if src_view:
			var parent_window: Control = _window_manager.find_ancestor_window_for_view(src_view)
			if is_instance_valid(parent_window):
				parent_window_id = parent_window.get_instance_id()
	# Fallback to the raw source id if mapping fails (best effort)
	if parent_window_id == -1:
		parent_window_id = context.source_view_instance_id
	# Close children of the resolved parent window
	commands.append(Command.new(CommandType.CLOSE_CHILD_WINDOWS, {
		"parent_window_id": parent_window_id
	}))
	
	# Then open the effects inspection window (parent remains selected)
	commands.append(Command.new(CommandType.OPEN_INSPECTION_WINDOW, {
		"context": context,
		"anchor_view_id": context.source_view_instance_id
	}))
	
	return commands

## Legacy: inspection is now handled by hover + lock. This always returns false.
func _is_inspection_event(_context: InteractionContext) -> bool:
	return false

## Check if this is an inventory tier change (special rule for inventory windows)
func _is_inventory_tier_change(selection: InteractionContext, new_context: InteractionContext) -> bool:
	if not selection or not new_context or not selection.location or not new_context.location:
		return false
	
	var selection_container = selection.location.container
	var new_container = new_context.location.container
	
	# Check if both are InventoryT containers but different tiers
	if selection_container.begins_with("RunInventoryT") and new_container.begins_with("RunInventoryT"):
		return selection_container != new_container
	if selection_container.begins_with("BattleInventoryT") and new_container.begins_with("BattleInventoryT"):
		return selection_container != new_container
	
	return false

## Check if the target is valid for an action with the current selection
func _is_valid_action_target(selection: InteractionContext, target: InteractionContext) -> bool:
	# Check if both contexts have valid locations
	if not selection or not target or not selection.location or not target.location:
		return false
	
	# Check if they're in the same functional group (can interact with each other)
	var selection_group = get_context_group(selection.location.container)
	var target_group = get_context_group(target.location.container)
	
	# Same group means they can interact
	if selection_group == target_group:
		return true

	# Allow equipping: Inventory -> Equipped
	if selection_group == &"InventoryGrid" and target_group == &"EquippedGrid":
		return true

	# Allow equipping onto units: Inventory -> BattleBoard (click item then click unit)
	if selection_group == &"InventoryGrid" and target_group == &"BattleBoard":
		return true

	# Allow consumables: Inventory -> InspectionOnly (e.g. EnemyLineup)
	# This enables using consumables on enemy units despite them being InspectionOnly
	if selection_group == &"InventoryGrid" and target_group == &"InspectionOnly":
		if selection.entity_type == &"CONSUMABLE":
			return true
	
	# Special case: Inventory tier changes should be handled as selection changes, not actions
	if _is_inventory_tier_change(selection, target):
		return false
	
	return false

## Check if the empty slot is a valid move target for the current selection
func _is_valid_move_target(selection: InteractionContext, target: InteractionContext) -> bool:
	# Check if both contexts have valid locations
	if not selection or not target or not selection.location or not target.location:
		return false
	
	# Check if they're in the same functional group
	var selection_group = get_context_group(selection.location.container)
	var target_group = get_context_group(target.location.container)
	
	# Same group means they can interact
	if selection_group == target_group:
		return true

	# Allow inventory click-to-act on the Black Market service slot.
	if selection_group == &"InventoryGrid" and target.location.container == &"BlackMarket":
		return true

	# Allow equipping: Inventory -> Equipped
	if selection_group == &"InventoryGrid" and target_group == &"EquippedGrid":
		return true
	
	# Special case: Inventory tier changes should be handled as selection changes, not invalid actions
	if _is_inventory_tier_change(selection, target):
		return false # This will trigger selection change instead of invalid action
	
	return false

## Check if a click is inside the inspection window group
func _is_click_inside_inspection_group(context: InteractionContext) -> bool:
	if not _window_manager:
		return false
	if _is_black_market_target_context(context):
		return true
	var view: Control = _find_view_by_instance_id(context.source_view_instance_id)
	if not view:
		return false
	var parent_window: Control = _window_manager.find_ancestor_window_for_view(view)
	return is_instance_valid(parent_window)

func _is_black_market_target_context(context: InteractionContext) -> bool:
	if context == null or not is_instance_valid(context.location):
		return false
	return context.location.container == &"BlackMarket" and WindowManager.is_run_inventory_window_open()

## Temporary suppression after in-window actions: prevent closing the parent inspection window
func _activate_close_suppression_for_view(view: Control, duration_msec: int = 200) -> void:
	if not _window_manager or not is_instance_valid(view):
		return
	var parent_window: Control = _window_manager.find_ancestor_window_for_view(view)
	if is_instance_valid(parent_window):
		var until_ts := Time.get_ticks_msec() + duration_msec
		_suppress_close_parent_window_id = parent_window.get_instance_id()
		_suppress_close_until_msec = until_ts


# Directly activate suppression for a known parent window id (public API)
func activate_close_suppression_for_window_id(window_id: int, duration_msec: int = 220) -> void:
	if window_id <= 0:
		return
	var until_ts := Time.get_ticks_msec() + duration_msec
	_suppress_close_parent_window_id = window_id
	_suppress_close_until_msec = until_ts

func _is_close_suppressed_for_context(context: InteractionContext) -> bool:
	if Time.get_ticks_msec() > _suppress_close_until_msec:
		return false
	if not _window_manager or context == null:
		return false
	var v: Control = _find_view_by_instance_id(context.source_view_instance_id)
	if not v:
		return false
	var parent_window: Control = _window_manager.find_ancestor_window_for_view(v)
	return is_instance_valid(parent_window) and parent_window.get_instance_id() == _suppress_close_parent_window_id

# Resolve the parent inspection window id for a given interaction context's source view
func _resolve_parent_window_id_for_context(context: InteractionContext) -> int:
	if not _window_manager or context == null:
		return -1
	var v: Control = _find_view_by_instance_id(context.source_view_instance_id)
	if not v:
		return -1
	var parent_window: Control = _window_manager.find_ancestor_window_for_view(v)
	return parent_window.get_instance_id() if is_instance_valid(parent_window) else -1

## Contextless suppression check (for true background events)
func _is_close_suppressed_now() -> bool:
	# Contextless suppression: only care about the active time window.
	# This allows stage-1 global suppression (id=0) from end_drag() to block
	# background closures before precise window-tied suppression is established.
	var now := Time.get_ticks_msec()
	var active := now <= _suppress_close_until_msec
	return active

# Heuristic: check whether a given window id refers to a UnitInspection window
func _is_unit_inspection_window_id(window_id: int) -> bool:
	var node := instance_from_id(window_id)
	if not is_instance_valid(node) or not (node is Control):
		return false
	var ctrl := node as Control
	# Prefer explicit name check
	if ctrl.name.findn("UnitInspection") != -1:
		return true
	# Fallbacks: try to infer from script path
	var s = ctrl.get_script()
	if is_instance_valid(s):
		var res_path: String = s.resource_path
		if res_path.findn("UnitInspection") != -1:
			return true
	return false

## Execute the command queue
func _execute_command_queue(commands: Array[Command]) -> void:
	for command in commands:
		_execute_command(command)

## Execute a single command
func _execute_command(command: Command) -> void:
	match command.cmd:
		CommandType.DESELECT:
			_execute_deselect()
			# No sound for deselect usually, or maybe a soft one
		CommandType.SELECT:
			_execute_select(command.context.get("context"))
			Audio.play_sfx("ui_select")
		CommandType.OPEN_INSPECTION_WINDOW:
			_execute_open_inspection_window(command.context)
		CommandType.CLOSE_ALL_INSPECTION_WINDOWS:
			_execute_close_all_inspection_windows()
		CommandType.CLOSE_CHILD_WINDOWS:
			_execute_close_child_windows(command.context.get("window_group_id", 0), command.context.get("parent_window_id", -1))
		CommandType.CLOSE_TOP_CONTEXTUAL_WINDOW:
			if _window_manager:
				_window_manager.close_top_contextual_window()
		CommandType.REQUEST_ACTION:
			_execute_request_action(command.context)
			# AUDIO HOOK: Action requested (usually a valid click)
			Audio.play_sfx("ui_click")
		CommandType.INVALID_ACTION:
			_execute_invalid_action()

## Execute deselect command
func _execute_deselect() -> void:
	# Only clear lock state if it is an INSPECTION lock (tied to a specific entity).
	# If _locked_entity_view_id is -1 but _is_inspection_locked is true, it is a SYSTEM/MODAL lock 
	# (e.g., ChoiceWindow) that must be preserved.
	if _locked_entity_view_id != -1:
		_is_inspection_locked = false
		_locked_entity_view_id = -1
	
	if _current_selection != null:
		_emit_view_deselected(_current_selection)
		_emit_selection_changed(null)
		_current_selection = null

## Execute select command
func _execute_select(context: InteractionContext) -> void:
	# Update our selection state and emit signals
	var view = _find_view_by_instance_id(context.source_view_instance_id)
	_current_selection = context
	if view:
		SignalBus.emit_signal("view_selected", view, context.location)
		_emit_selection_changed(context.location)

## Execute open inspection window command
func _execute_open_inspection_window(command_context: Dictionary) -> void:
	var context: InteractionContext = command_context.get("context")
	var anchor_view_id: int = command_context.get("anchor_view_id", 0)
	var should_lock: bool = command_context.get("lock", false)
	
	if _window_manager and context:
		# Find the anchor view by instance ID
		var anchor_view = _find_view_by_instance_id(anchor_view_id)
		if anchor_view:
			# Use the public WindowManager API
			_window_manager.open_inspection_window(context.location, anchor_view)
			if should_lock:
				_is_inspection_locked = true
				_locked_entity_view_id = anchor_view_id

## Execute close all inspection windows command
func _execute_close_all_inspection_windows() -> void:
	if _window_manager:
		_window_manager.close_all_inspection_windows()

## Execute close child windows command
func _execute_close_child_windows(window_group_id: int, parent_window_id: int = -1) -> void:
	if _window_manager:
		_window_manager.close_child_windows(window_group_id, parent_window_id)

## Execute request action command
func _execute_request_action(command_context: Dictionary) -> void:
	# COMBAT-phase gate: full lockout, no side-effects
	if _is_combat_phase:
		return
	var source_context: InteractionContext = command_context.get("source_context")
	var target_context: InteractionContext = command_context.get("target_context")
	
	if source_context and target_context:
		# Prefer explicit window-id suppression if provided by command context
		var tgt_parent_id: int = command_context.get("target_parent_window_id", -1)
		var inside_unit: bool = command_context.get("is_inside_unit_inspection", false)
		if tgt_parent_id != -1:
			# Slightly longer suppression when inside unit inspection to absorb UI refresh bursts
			activate_close_suppression_for_window_id(tgt_parent_id, 280 if inside_unit else 220)
		else:
			# Activate short-lived suppression tied to the parent window where the action occurs.
			# For equipping into a UnitInspectionWindow, the TARGET view is inside the unit window.
			var tgt_view: Control = _find_view_by_instance_id(target_context.source_view_instance_id)
			if tgt_view:
				_activate_close_suppression_for_view(tgt_view)
			else:
				# Fallback: tie suppression to the source view's parent (covers drag from inventory)
				var src_view: Control = _find_view_by_instance_id(source_context.source_view_instance_id)
				if src_view:
					_activate_close_suppression_for_view(src_view)
		SignalBus.emit_signal("try_inventory_action",
			source_context.location,
			target_context.location)

## Execute invalid action command
func _execute_invalid_action() -> void:
	# GR-5 resolution: close contextual windows and clear selection
	_execute_close_all_inspection_windows()
	_execute_deselect()

## Emit selection changed uniformly
func _emit_selection_changed(loc: LocationIdentifier) -> void:
	SignalBus.emit_signal("selection_changed", loc)

## Emit view deselected using the stored selection
func _emit_view_deselected(sel: InteractionContext) -> void:
	var view = _find_view_by_instance_id(sel.source_view_instance_id)
	if view:
		SignalBus.emit_signal("view_deselected", view)

## Find a view by its instance ID
func _find_view_by_instance_id(instance_id: int) -> Control:
	# Fast path: use engine lookup, then ascend to nearest Control
	if instance_id <= 0:
		return null
	var obj := instance_from_id(instance_id)
	if is_instance_valid(obj):
		if obj is Control:
			return obj as Control
		# If the id belongs to a non-Control (e.g. TextureRect child), walk up to nearest Control
		var n: Node = obj
		while is_instance_valid(n) and not (n is Control) and n != get_tree().root:
			n = n.get_parent()
		if n is Control:
			return n as Control
	return null

## Public API for external systems to set selection
func set_current_selection(context: InteractionContext) -> void:
	_current_selection = context

## Public API for external systems to get current selection
func get_current_selection() -> InteractionContext:
	return _current_selection

## Public API for external systems to clear selection
func clear_current_selection() -> void:
	_current_selection = null

## Public method to get the functional group of a container (migrated from InteractionManager)
func get_context_group(container_name: StringName) -> StringName:
	return _get_container_functional_group(container_name)

## Internal container functional group resolver
func _get_container_functional_group(container_name: StringName) -> StringName:
	# Battle board containers
	if container_name in [&"PlayerLineup", &"PlayerBench"]:
		return &"BattleBoard"
	
	# Test mode parity: allow full BattleBoard interactions on enemy board containers.
	if GameManager.is_test_mode and container_name in [&"EnemyLineup", &"EnemyBench"]:
		return &"BattleBoard"

	# Inventory containers (can interact with each other)
	if container_name.begins_with("RunInventoryT") or container_name.begins_with("BattleInventoryT"):
		return &"InventoryGrid"

	# Selection-only containers (can only be selected)
	if container_name in [&"Rewards", &"Shop"]:
		return &"SelectionOnly"

	# Equipped items (special handling)
	if container_name == C.CONTAINER_EQUIPPED_ITEM:
		return &"EquippedGrid"

	# Inspection-only containers (no actions allowed)
	if container_name in [&"DiscardPile", &"PlayerTrinkets", &"EnemyTrinkets", &"EnemyLineup", &"EnemyBench"]:
		return &"InspectionOnly"


	return &"Unknown"

## Public API: start a drag operation (called by InteractionManager)
func start_drag(origin_context: InteractionContext) -> void:
	# Full input lock during COMBAT: do not start drags
	if _is_combat_phase:
		return
	
	# Per docs: "It clears any current selection"
	if _current_selection != null:
		_execute_deselect()
	
	# 1. Clear lock/hover state
	_is_inspection_locked = false
	_locked_entity_view_id = -1
	_hover_entity_view_id = -1
	
	_is_drag_active = true
	_drag_origin_context = origin_context

	# Context-Aware Window Management:
	# - If dragging from an active window (e.g., Inventory), keep it open to preserve the source.
	# - If dragging from the main view (BattleBoard), close all windows to prevent floating inspections.
	if _window_manager and origin_context != null:
		var src_view: Control = _find_view_by_instance_id(origin_context.source_view_instance_id)
		if src_view:
			var parent_window: Control = _window_manager.find_ancestor_window_for_view(src_view)
			if is_instance_valid(parent_window):
				# Dragging from inside a window -> Close only its children
				_window_manager.close_children_of(parent_window)
			else:
				# Dragging from main view -> Close everything to avoid floating windows
				if _window_manager.has_method("close_all_inspection_windows"):
					_window_manager.close_all_inspection_windows()

	# Select the dragged item so user sees visual feedback
	# CRITICAL: Do this AFTER closing windows. Window closure logic might trigger side-effects
	# (like focus changes or context updates) that could inadvertently deselect the item.
	# By selecting LAST, we ensure the drag selection "wins".
	_execute_select(origin_context)
	
	# Inform listeners that a drag has started (optional hook for visuals)
	if SignalBus.has_signal("drag_started"):
		SignalBus.emit_signal("drag_started", origin_context)
	
	# AUDIO HOOK: Drag Start
	Audio.play_sfx("ui_drag_start")

## Public API: end a drag operation (called by InteractionManager)
func end_drag(_was_handled: bool) -> void:
	_is_drag_active = false
	_drag_origin_context = null
	# Clear the drag-selection set by start_drag._execute_select.
	# On handled drops, ACTION → DESELECT already cleared this; on failed drops it's stuck.
	_execute_deselect()
	# Clear lock/hover state to prevent stale state after drag
	_hover_entity_view_id = -1
	
	# Only clear if we aren't in a persistent lock state (though usually drag overrides all)
	# For safety, we clear it, assuming the drag end will re-establish context if needed.
	_is_inspection_locked = false

	# Stage-1 suppression: if the drag produced a handled drop, briefly suppress true background
	# close so that the ensuing REQUEST_ACTION can set precise window-tied suppression.
	if _was_handled:
		# Stage-1 suppression: if the drag produced a handled drop, briefly suppress true background
		# close so that the ensuing REQUEST_ACTION can set precise window-tied suppression.
		# Use a minimal duration; precise suppression will override shortly after
		_suppress_close_parent_window_id = 0
		var until_ts := Time.get_ticks_msec() + 420
		_suppress_close_until_msec = until_ts
	# Centralize drag visual cleanup so views don't have to decide
	# IMMEDIATE VISUAL CLEANUP: Do not defer this. 
	_end_drag_visuals(_was_handled)
	
	# AUDIO HOOK: Drag End
	if _was_handled:
		Audio.play_sfx("ui_drag_drop")
	else:
		Audio.play_sfx("ui_deselect")
	
	# Inform listeners that a drag has ended (optional hook for visuals)
	if SignalBus.has_signal("drag_ended"):
		SignalBus.emit_signal("drag_ended", _was_handled)

## Lightweight helpers to manage drag visuals centrally (temporary until DragVisualController)
func start_drag_visuals(source_view: Control, placeholder: Control) -> void:
	# Full input lock during COMBAT: suppress visuals and free placeholder to avoid leaks
	if _is_combat_phase:
		if is_instance_valid(placeholder):
			placeholder.queue_free()
		return
	_drag_source_view = source_view
	_drag_placeholder = placeholder
	if is_instance_valid(_drag_source_view):
		# Force invisibility via alpha as well as visible property.
		# This is a fail-safe against top_level nodes (like hopping animations)
		# that might bypass parent visibility or render unexpectedly.
		_drag_source_view.visible = false
		_drag_source_view.modulate.a = 0.0

func end_drag_visuals(was_handled: bool) -> void:
	_end_drag_visuals(was_handled)

func _end_drag_visuals(was_handled: bool) -> void:
	if is_instance_valid(_drag_source_view) and not was_handled:
		_drag_source_view.visible = true
		_drag_source_view.modulate.a = 1.0 # Restore visibility
	# If handled (consumed), let the game logic destroy/move it, but if it remains, ensure it's visible
	elif is_instance_valid(_drag_source_view):
		# Even if handled, we should restore alpha in case the view is reused/pooled
		_drag_source_view.modulate.a = 1.0
		
	if is_instance_valid(_drag_placeholder):
		_drag_placeholder.queue_free()
	_clear_drag_overlay_preview()
	_drag_source_view = null
	_drag_placeholder = null

func set_drag_overlay_preview(preview: Control) -> void:
	_clear_drag_overlay_preview()
	if not is_instance_valid(preview):
		return
	_drag_overlay_preview = preview
	_drag_overlay_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_get_drag_preview_layer().add_child(_drag_overlay_preview)
	_drag_overlay_preview.global_position = get_viewport().get_mouse_position()

func _clear_drag_overlay_preview() -> void:
	if is_instance_valid(_drag_overlay_preview):
		_drag_overlay_preview.queue_free()
	_drag_overlay_preview = null

func _get_drag_preview_layer() -> CanvasLayer:
	if is_instance_valid(_drag_preview_layer):
		return _drag_preview_layer
	_drag_preview_layer = CanvasLayer.new()
	_drag_preview_layer.name = "DragPreviewLayer"
	_drag_preview_layer.layer = 1023
	get_tree().root.add_child(_drag_preview_layer)
	return _drag_preview_layer

## Public API: query drag active state
func is_drag_active() -> bool:
	return _is_drag_active

## Public API: get the current drag source view (for transferring ownership/visibility)
func get_drag_source_view() -> Control:
	return _drag_source_view

## Public API: expose COMBAT lock state for views
func is_combat_locked() -> bool:
	return _is_combat_phase

## Public API: expose suppression state for WindowManager
func is_close_suppressed_for_window_id(window_id: int) -> bool:
	# Valid only within the active suppression window
	var now := Time.get_ticks_msec()
	if now > _suppress_close_until_msec:
		return false
	if window_id <= 0:
		return false
	var res := window_id == _suppress_close_parent_window_id
	return res

func is_close_suppressed_now() -> bool:
	# Contextless suppression: time-window only
	return Time.get_ticks_msec() <= _suppress_close_until_msec

# --- Drag & Drop Accessors ---

func get_drag_origin_context() -> InteractionContext:
	return _drag_origin_context
