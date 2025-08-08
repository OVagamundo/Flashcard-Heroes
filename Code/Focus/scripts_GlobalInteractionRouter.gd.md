<!-- Original: scripts/GlobalInteractionRouter.gd -->

```gdscript
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
	
	func _init(command_type: CommandType, command_context: Dictionary = {}):
		cmd = command_type
		context = command_context

## Current selection state
var _current_selection: InteractionContext = null

## Reference to InteractionManager for selection state
var _interaction_manager: Node = null

## Reference to WindowManager for window operations
var _window_manager: Node = null

func _ready():
	# Register as singleton
	add_to_group("global_interaction_router")
	
	# Get references to other managers
	_interaction_manager = InteractionManager
	_window_manager = WindowManager
	
	# Connect to interaction signals
	EventBus.interaction_context_received.connect(_on_interaction_context_received)

## Main entry point for processing interactions
func _on_interaction_context_received(context: InteractionContext):
	print("GlobalInteractionRouter: Received interaction context - entity_type: ", context.entity_type, ", source_id: ", context.source_view_instance_id)
	
	# Validate state before processing
	if _interaction_manager:
		if not _interaction_manager.validate_selection_state():
			print("GlobalInteractionRouter: Invalid state detected, forcing cleanup")
			_interaction_manager.clear_selection()
			_interaction_manager.cancel_active_drag()
	
	var command_queue: Array[Command] = []
	
	# Generate commands based on the interaction context and current state
	command_queue = _generate_command_queue(context)
	
	# Execute the command queue
	_execute_command_queue(command_queue)

## Generate command queue based on interaction context and current state
func _generate_command_queue(context: InteractionContext) -> Array[Command]:
	var commands: Array[Command] = []
	
	print("GlobalInteractionRouter: Generating commands for entity_type: ", context.entity_type)
	
	# TDD Rule: ANYWHERE outside window group should close entire group
	# Check if inspection windows are open and this click is outside the window group
	if _window_manager and _window_manager.is_any_inspection_window_open():
		# Check if this click is outside the inspection window group
		if not _is_click_inside_inspection_group(context):
			# This is a click outside the window group - close entire group
			commands.append(Command.new(CommandType.CLOSE_ALL_INSPECTION_WINDOWS))
			# Continue processing the click normally
	
	# Handle different entity types
	match context.entity_type:
		&"GLOBAL_BACKGROUND":
			# GR-4: Close on "True" Background Click
			commands.append(Command.new(CommandType.CLOSE_ALL_INSPECTION_WINDOWS))
			
		&"WINDOW_BACKGROUND":
			# GR-6: Child Window Closure - prune that branch
			print("GlobalInteractionRouter: WINDOW_BACKGROUND click received from window ID: ", context.source_view_instance_id)
			commands.append(Command.new(CommandType.CLOSE_CHILD_WINDOWS, {
				"window_group_id": context.window_group_id,
				"parent_window_id": context.source_view_instance_id
			}))
			
		&"UNIT", &"ITEM":
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
		# GR-2: Clear Selection on Open
		commands.append(Command.new(CommandType.DESELECT))
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
			# Single-click inspection
			commands.append(Command.new(CommandType.DESELECT))
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
		# Check if clicking on the same item (deselect it)
		if _current_selection.source_view_instance_id == context.source_view_instance_id:
			commands.append(Command.new(CommandType.DESELECT))
			return commands
		
		# Check for inventory tier change rule
		if _is_inventory_tier_change(_current_selection, context):
			commands.append(Command.new(CommandType.DESELECT))
			commands.append(Command.new(CommandType.SELECT, {"context": context}))
			return commands
		
		# Check if this is a valid action target
		if _is_valid_action_target(_current_selection, context):
			commands.append(Command.new(CommandType.REQUEST_ACTION, {
				"source_context": _current_selection,
				"target_context": context
			}))
			# Clear selection after any action (valid or invalid)
			commands.append(Command.new(CommandType.DESELECT))
		else:
			# GR-5: Close on Invalid Action Click
			commands.append(Command.new(CommandType.CLOSE_ALL_INSPECTION_WINDOWS))
			commands.append(Command.new(CommandType.DESELECT))
	else:
		# No current selection, just select this item
		commands.append(Command.new(CommandType.SELECT, {"context": context}))
	
	return commands

## Handle selection-only contexts (shop, rewards)
func _handle_selection_only(context: InteractionContext) -> Array[Command]:
	var commands: Array[Command] = []
	
	# GR rule: Always change selection in selection-only contexts
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
			commands.append(Command.new(CommandType.REQUEST_ACTION, {
				"source_context": _current_selection,
				"target_context": context
			}))
			# Clear selection after any action (valid or invalid)
			commands.append(Command.new(CommandType.DESELECT))
		else:
			# Invalid action - clear selection and close inspection windows
			commands.append(Command.new(CommandType.CLOSE_ALL_INSPECTION_WINDOWS))
			commands.append(Command.new(CommandType.DESELECT))
	
	return commands

## Handle UI link interactions (like "EFFECTS" links)
func _handle_ui_link_interaction(context: InteractionContext) -> Array[Command]:
	var commands: Array[Command] = []
	
	# TDD Rule: Effects link should close existing children of the current window
	# The context.source_view_instance_id should be the window containing the EFFECTS link
	# We need to close any children of that specific window
	commands.append(Command.new(CommandType.CLOSE_CHILD_WINDOWS, {
		"parent_window_id": context.source_view_instance_id
	}))
	
	# Then open the effects inspection window
	commands.append(Command.new(CommandType.DESELECT))
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
	var selection_group = InteractionManager.get_context_group(selection.location.container)
	var target_group = InteractionManager.get_context_group(target.location.container)
	
	# Same group means they can interact
	if selection_group == target_group:
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
	var selection_group = InteractionManager.get_context_group(selection.location.container)
	var target_group = InteractionManager.get_context_group(target.location.container)
	
	# Same group means they can interact
	if selection_group == target_group:
		return true
	
	# Special case: Inventory tier changes should be handled as selection changes, not invalid actions
	if _is_inventory_tier_change(selection, target):
		return false  # This will trigger selection change instead of invalid action
	
	return false

## Check if a click is inside the inspection window group
func _is_click_inside_inspection_group(context: InteractionContext) -> bool:
	# Check if the source view is part of an inspection window
	if _window_manager:
		var view = _find_view_by_instance_id(context.source_view_instance_id)
		if view:
			return _window_manager.find_window_in_group(view) != -1
	return false

## Execute the command queue
func _execute_command_queue(commands: Array[Command]):
	print("GlobalInteractionRouter: Executing command queue with ", commands.size(), " commands")
	for command in commands:
		print("GlobalInteractionRouter: Executing command: ", command.cmd)
		_execute_command(command)

## Execute a single command
func _execute_command(command: Command):
	match command.cmd:
		CommandType.DESELECT:
			_execute_deselect()
		CommandType.SELECT:
			_execute_select(command.context.get("context"))
		CommandType.OPEN_INSPECTION_WINDOW:
			_execute_open_inspection_window(command.context)
		CommandType.CLOSE_ALL_INSPECTION_WINDOWS:
			_execute_close_all_inspection_windows()
		CommandType.CLOSE_CHILD_WINDOWS:
			_execute_close_child_windows(command.context.get("window_group_id", 0), command.context.get("parent_window_id", -1))
		CommandType.REQUEST_ACTION:
			_execute_request_action(command.context)
		CommandType.INVALID_ACTION:
			_execute_invalid_action()

## Execute deselect command
func _execute_deselect():
	_current_selection = null
	if _interaction_manager:
		_interaction_manager.clear_selection()

## Execute select command
func _execute_select(context: InteractionContext):
	print("GlobalInteractionRouter: Executing SELECT command for entity_type: ", context.entity_type, ", source_id: ", context.source_view_instance_id)
	if _interaction_manager:
		# Find the view by instance ID and call the new selection method
		var view = _find_view_by_instance_id(context.source_view_instance_id)
		if view:
			print("GlobalInteractionRouter: Found view, calling handle_selection_request")
			_interaction_manager.handle_selection_request(view, context.location)
			# Update our selection state to match InteractionManager
			_current_selection = context
		else:
			print("GlobalInteractionRouter: ERROR - Could not find view with instance_id: ", context.source_view_instance_id)

## Execute open inspection window command
func _execute_open_inspection_window(command_context: Dictionary):
	var context: InteractionContext = command_context.get("context")
	var anchor_view_id: int = command_context.get("anchor_view_id", 0)
	
	if _window_manager and context:
		# Find the anchor view by instance ID
		var anchor_view = _find_view_by_instance_id(anchor_view_id)
		if anchor_view:
			# Use the correct WindowManager method
			_window_manager._open_inspection_window(context.location, anchor_view)

## Execute close all inspection windows command
func _execute_close_all_inspection_windows():
	if _window_manager:
		_window_manager.close_all_inspection_windows()

## Execute close child windows command
func _execute_close_child_windows(window_group_id: int, parent_window_id: int = -1):
	if _window_manager:
		_window_manager.close_child_windows(window_group_id, parent_window_id)

## Execute request action command
func _execute_request_action(command_context: Dictionary):
	var source_context: InteractionContext = command_context.get("source_context")
	var target_context: InteractionContext = command_context.get("target_context")
	
	if source_context and target_context:
		EventBus.emit_signal("try_inventory_action", 
			source_context.location, 
			target_context.location)

## Execute invalid action command
func _execute_invalid_action():
	if _interaction_manager:
		_interaction_manager._resolve_and_clear_invalid_interaction()

## Find a view by its instance ID
func _find_view_by_instance_id(instance_id: int) -> Control:
	# Search for the view in the scene tree
	var root = get_tree().root
	return _find_view_recursive(root, instance_id)

## Recursively search for a view with the given instance ID
func _find_view_recursive(node: Node, target_id: int) -> Control:
	if node is Control and node.get_instance_id() == target_id:
		return node as Control
	
	for child in node.get_children():
		var result = _find_view_recursive(child, target_id)
		if result:
			return result
	
	return null

## Public API for external systems to set selection
func set_current_selection(context: InteractionContext):
	_current_selection = context

## Public API for external systems to get current selection
func get_current_selection() -> InteractionContext:
	return _current_selection

## Public API for external systems to clear selection
func clear_current_selection():
	_current_selection = null 

```