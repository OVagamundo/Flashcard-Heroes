extends Node

## The GlobalInteractionRouter is the single source of truth for interpreting user intent.
## It receives InteractionContext from clicked views and generates command queues.

## Command types that can be generated
enum CommandType {
	DESELECT,
	SELECT,
	OPEN_INSPECTION_WINDOW,
	CLOSE_ALL_INSPECTION_WINDOWS,
	CLOSE_CHILD_WINDOWS,
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
var _suppress_close_parent_window_id: int = -1
var _suppress_close_until_msec: int = 0

func _ready() -> void:
	# Register as singleton
	add_to_group("global_interaction_router")
	
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

func _exit_tree() -> void:
	# Scene cleanup per spec: clear drag and selection
	_end_drag_visuals(false)
	_is_drag_active = false
	_drag_origin_context = null
	# Emit deselect if needed
	if _current_selection != null:
		_emit_view_deselected(_current_selection)
		_emit_selection_changed(null)
	_is_drag_active = false
	_drag_origin_context = null
	# Disconnect SignalBus hooks connected in _ready()
	if SignalBus.interaction_context_received.is_connected(_on_interaction_context_received):
		SignalBus.interaction_context_received.disconnect(_on_interaction_context_received)
	if SignalBus.has_signal("selection_clear_requested") and SignalBus.selection_clear_requested.is_connected(_on_selection_clear_requested):
		SignalBus.selection_clear_requested.disconnect(_on_selection_clear_requested)
	if SignalBus.has_signal("battle_phase_changed") and SignalBus.battle_phase_changed.is_connected(_on_battle_phase_changed):
		SignalBus.battle_phase_changed.disconnect(_on_battle_phase_changed)

## Main entry point for processing interactions
func _on_interaction_context_received(context: InteractionContext) -> void:
	var command_queue: Array[Command] = []

	# Full input lock during COMBAT: ignore all interaction contexts
	if _is_combat_phase:
		return

	# Generate commands based on the interaction context and current state
	command_queue = _generate_command_queue(context)

	# Execute the command queue
	_execute_command_queue(command_queue)

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
		# 3) Close contextual windows (guarded by suppression) and clear selection
		if not _is_close_suppressed_now():
			_execute_close_all_inspection_windows()
		_execute_deselect()
		return

	# True background click: left mouse press not handled by any Control
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Close contextual windows and clear selection (guarded by suppression)
		if not _is_close_suppressed_now():
			_execute_close_all_inspection_windows()
		_execute_deselect()

## External signal handler: proactively clear selection when requested (e.g., scene transitions)
func _on_selection_clear_requested() -> void:
	# Always clear selection if present
	if _current_selection != null:
		_execute_deselect()
	# Also activate a brief, contextless close suppression to guard the very next click
	# after system-driven actions (e.g., shop purchase, reward choice). This prevents
	# GR-4 global close or background handlers from triggering immediately.
	var until_ts := Time.get_ticks_msec() + 240
	_suppress_close_parent_window_id = 0
	_suppress_close_until_msec = until_ts

## Track battle phase to enforce COMBAT gating
func _on_battle_phase_changed(phase_name: StringName) -> void:
	_is_combat_phase = phase_name == &"COMBAT"
	# If entering COMBAT, ensure any drag state and engine preview are cleared
	if _is_combat_phase:
		if _is_drag_active:
			end_drag(false)
		# Also cancel engine-managed drag preview to avoid lingering visuals
		var vp := get_viewport()
		if vp and vp.has_method("gui_cancel_drag"):
			vp.gui_cancel_drag()

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
				if not suppressed:
					commands.append(Command.new(CommandType.CLOSE_ALL_INSPECTION_WINDOWS))
	
	# Handle different entity types
	match context.entity_type:
		&"GLOBAL_BACKGROUND":
			# GR-4: Close on "True" Background Click
			# Guard with suppression to avoid closing immediately after an in-window action
			if not _is_close_suppressed_now():
				commands.append(Command.new(CommandType.CLOSE_ALL_INSPECTION_WINDOWS))
			
		&"WINDOW_BACKGROUND":
			# GR-6: Child Window Closure - prune that branch
			commands.append(Command.new(CommandType.CLOSE_CHILD_WINDOWS, {
				"window_group_id": context.window_group_id,
				"parent_window_id": context.source_view_instance_id
			}))
			
		&"UNIT", &"ITEM", &"TRINKET":
			commands.append_array(_handle_gachaball_interaction(context))
			
		&"EMPTY_SLOT":
			commands.append_array(_handle_empty_slot_interaction(context))
			
		&"UI_LINK":
			commands.append_array(_handle_ui_link_interaction(context))
	
	return commands

## Handle interactions with GachaBall instances
func _handle_gachaball_interaction(context: InteractionContext) -> Array[Command]:
	var commands: Array[Command] = []
	
	# Check for inspection events
	if _is_inspection_event(context):
		# Parent remains selected when its inspection window opens
		# GR-1: Open on Request
		commands.append(Command.new(CommandType.OPEN_INSPECTION_WINDOW, {
			"context": context,
			"anchor_view_id": context.source_view_instance_id
		}))
		return commands
	
	# Handle selection and action logic
	match context.interaction_mode:
		&"FULLY_INTERACTIVE":
			commands.append_array(_handle_fully_interactive(context))
		&"SELECTION_ONLY":
			commands.append_array(_handle_selection_only(context))
		&"INSPECTION_ONLY":
			# Single-click inspection - parent remains selected
			commands.append(Command.new(CommandType.OPEN_INSPECTION_WINDOW, {
				"context": context,
				"anchor_view_id": context.source_view_instance_id
			}))
	
	return commands

## Handle fully interactive contexts (battle board, inventory)
func _handle_fully_interactive(context: InteractionContext) -> Array[Command]:
	var commands: Array[Command] = []
	
	# Check if we have a current selection
	if _current_selection != null:
		# Re-Selection Inspects (S4): single-click on already-selected opens inspection
		# Keep parent selected when opening its inspection window
		if _current_selection.source_view_instance_id == context.source_view_instance_id:
			commands.append(Command.new(CommandType.OPEN_INSPECTION_WINDOW, {
				"context": context,
				"anchor_view_id": context.source_view_instance_id
			}))
			return commands
		
		# Check for inventory tier change rule
		if _is_inventory_tier_change(_current_selection, context):
			commands.append(Command.new(CommandType.DESELECT))
			commands.append(Command.new(CommandType.SELECT, {"context": context}))
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
	else:
		# No current selection, just select this item
		commands.append(Command.new(CommandType.SELECT, {"context": context}))
	
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
			# Keep parent selected when opening its inspection window
			commands.append(Command.new(CommandType.OPEN_INSPECTION_WINDOW, {
				"context": context,
				"anchor_view_id": context.source_view_instance_id
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

## Check if this is an inspection event (double-click in drag-enabled, single-click in drag-disabled)
func _is_inspection_event(context: InteractionContext) -> bool:
	if context.event_type == &"DOUBLE_CLICK":
		return context.interaction_mode == &"FULLY_INTERACTIVE" or context.interaction_mode == &"SELECTION_ONLY"
	elif context.event_type == &"SINGLE_CLICK":
		return context.interaction_mode == &"INSPECTION_ONLY"
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
	var view: Control = _find_view_by_instance_id(context.source_view_instance_id)
	if not view:
		return false
	var parent_window: Control = _window_manager.find_ancestor_window_for_view(view)
	return is_instance_valid(parent_window)

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
		CommandType.REQUEST_ACTION:
			_execute_request_action(command.context)
			# AUDIO HOOK: Action requested (usually a valid click)
			Audio.play_sfx("ui_click")
		CommandType.INVALID_ACTION:
			_execute_invalid_action()

## Execute deselect command
func _execute_deselect() -> void:
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
	
	if _window_manager and context:
		# Find the anchor view by instance ID
		var anchor_view = _find_view_by_instance_id(anchor_view_id)
		if anchor_view:
			# Use the public WindowManager API
			_window_manager.open_inspection_window(context.location, anchor_view)

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
	# Battle board containers (player-side only; enemy containers are inspection-only)
	if container_name in [&"PlayerLineup", &"PlayerBench"]:
		return &"BattleBoard"

	# Inventory containers (can interact with each other)
	if container_name.begins_with("RunInventoryT") or container_name.begins_with("BattleInventoryT"):
		return &"InventoryGrid"

	# Non-tiered item storage should also be treated as InventoryGrid
	if container_name == &"ItemInventory":
		return &"InventoryGrid"

	# Selection-only containers (can only be selected)
	if container_name in [&"Rewards", &"Shop"]:
		return &"SelectionOnly"

	# Equipped items (special handling)
	if container_name == C.CONTAINER_EQUIPPED_ITEM:
		return &"EquippedGrid"

	# Inspection-only containers (no actions allowed)
	if container_name in [&"DiscardPile", &"PlayerTrinkets", &"EnemyTrinkets", &"EnemyLineup"]:
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
	
	# Select the dragged item so user sees visual feedback
	_execute_select(origin_context)
	
	_is_drag_active = true
	_drag_origin_context = origin_context
	# Prune only child windows of the source's parent inspection window on drag start.
	# Do NOT close the parent window itself to avoid freeing the drag preview/source view.
	if _window_manager and origin_context != null:
		var src_view: Control = _find_view_by_instance_id(origin_context.source_view_instance_id)
		if src_view:
			var parent_window: Control = _window_manager.find_ancestor_window_for_view(src_view)
			if is_instance_valid(parent_window):
				_window_manager.close_children_of(parent_window)
	# Inform listeners that a drag has started (optional hook for visuals)
	if SignalBus.has_signal("drag_started"):
		SignalBus.emit_signal("drag_started", origin_context)
	
	# AUDIO HOOK: Drag Start
	Audio.play_sfx("ui_drag_start")

## Public API: end a drag operation (called by InteractionManager)
func end_drag(_was_handled: bool) -> void:
	_is_drag_active = false
	_drag_origin_context = null
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
		_drag_source_view.visible = false

func end_drag_visuals(was_handled: bool) -> void:
	_end_drag_visuals(was_handled)

func _end_drag_visuals(was_handled: bool) -> void:
	if is_instance_valid(_drag_source_view) and not was_handled:
		_drag_source_view.visible = true
	if is_instance_valid(_drag_placeholder):
		_drag_placeholder.queue_free()
	_drag_source_view = null
	_drag_placeholder = null

## Public API: query drag active state
func is_drag_active() -> bool:
	return _is_drag_active

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
