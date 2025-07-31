# res://scripts/InteractionManager.gd
extends Node

## Manages the temporary UI state of a user's action, such as the currently
## selected view/location and any active drag-and-drop operations.
## Now works with GlobalInteractionRouter instead of handling actions directly.

var _selected_location: LocationIdentifier = null
var _selected_view: Control = null

var _is_drag_active: bool = false
var _drag_source_view: Control = null
var _drag_placeholder: Control = null

# State validation and atomic operations
var _last_state_change_frame: int = 0
var _is_state_transitioning: bool = false
var _global_router: Node = null

func _ready():
	EventBus.close_modal_requested.connect(clear_selection)
	EventBus.main_scene_requested.connect(clear_selection)
	EventBus.selection_clear_requested.connect(clear_selection)
	EventBus.inventory_action_invalid.connect(_on_inventory_action_invalid)
	
	# Get reference to GlobalInteractionRouter
	_global_router = get_node("/root/GlobalInteractionRouter")

func _process(_delta):
	# Periodic state validation to catch any inconsistencies
	# Temporarily disabled to debug selection issues
	pass
	# if not validate_selection_state():
	# 	print("InteractionManager: Periodic validation failed, forcing cleanup")
	# 	force_synchronize_states()
	# 	clear_selection()
	# 	cancel_active_drag()

## Handle selection requests from GlobalInteractionRouter
func handle_selection_request(view: Control, location: LocationIdentifier):
	print("InteractionManager: handle_selection_request called with view: ", view, ", location: ", location)
	if not is_instance_valid(location):
		print("InteractionManager: Invalid location, clearing selection")
		clear_selection()
		return

	if _selected_view == view:
		print("InteractionManager: Same view already selected, ignoring")
		return

	if not is_instance_valid(_selected_view):
		print("InteractionManager: No current selection, selecting new view")
		select_view(view, location)
		return

	# If we have a previous selection, try to perform an action
	var source_loc = _selected_location
	var target_loc = location
	
	print("InteractionManager: Previous selection exists, checking compatibility")
	# Check if the locations are compatible for actions
	if _are_locations_compatible_for_action(source_loc, target_loc):
		print("InteractionManager: Locations compatible, trying inventory action")
		EventBus.emit_signal("try_inventory_action", source_loc, target_loc)
	else:
		print("InteractionManager: Locations incompatible, changing selection")
		# Incompatible locations - just change selection
		select_view(view, location)

## Check if two locations are compatible for inventory actions
func _are_locations_compatible_for_action(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> bool:
	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
		return false
	
	# Same container - always compatible
	if source_loc.container == target_loc.container:
		return true
	
	# Different containers - check if they're in the same functional group
	var source_group = _get_container_functional_group(source_loc.container)
	var target_group = _get_container_functional_group(target_loc.container)
	
	return source_group == target_group

## Get the functional group of a container (replaces old context groups)
func _get_container_functional_group(container_name: StringName) -> StringName:
	# Battle board containers (can interact with each other)
	if container_name in [&"PlayerLineup", &"PlayerBench", &"ItemInventory"]:
		return &"BATTLE_BOARD"
	
	# Inventory containers (can interact with each other)
	if container_name.begins_with("RunInventoryT") or container_name.begins_with("BattleInventoryT"):
		return &"INVENTORY_GRID"

	# Selection-only containers (can only be selected)
	if container_name in [&"Rewards", &"Shop"]:
		return &"SELECTION_ONLY"

	# Equipped items (special handling)
	if container_name == &"equipped_item":
		return &"EQUIPPED_GRID"
	
	# Inspection-only containers (no actions allowed)
	if container_name in [&"EnemyLineup", &"DiscardPile"]:
		return &"INSPECTION_ONLY"

	return &"UNKNOWN"

## Public method to get the functional group of a container (for backward compatibility)
func get_context_group(container_name: StringName) -> StringName:
	return _get_container_functional_group(container_name)

func select_view(view: Control, location: LocationIdentifier):
	print("InteractionManager: select_view called with view: ", view, ", location: ", location)
	# Prevent concurrent state transitions
	if _is_state_transitioning:
		print("InteractionManager: State transition in progress, ignoring select_view call")
		return
	
	_is_state_transitioning = true
	
	if not is_instance_valid(view) or not is_instance_valid(location):
		print("InteractionManager: Invalid view or location in select_view")
		clear_selection()
		_is_state_transitioning = false
		return

	# If a different view was already selected, deselect it first.
	if is_instance_valid(_selected_view):
		print("InteractionManager: Deselecting previous view before selecting new one")
		clear_selection()

	_selected_view = view
	_selected_location = location
	_last_state_change_frame = Engine.get_process_frames()
	
	# Update GlobalInteractionRouter's selection state to match
	if _global_router:
		# Create an InteractionContext for the router
		var context = InteractionContext.new()
		context.source_view_instance_id = view.get_instance_id()
		context.location = location
		context.entity_uuid = ""  # Will be set by the view if needed
		context.entity_type = &"UNIT"  # Default, will be overridden by view
		context.interaction_mode = &"FULLY_INTERACTIVE"  # Default
		context.window_group_id = 0
		_global_router.set_current_selection(context)
	
	print("InteractionManager: Emitting view_selected and selection_changed signals")
	EventBus.emit_signal("view_selected", _selected_view, _selected_location)
	EventBus.emit_signal("selection_changed", _selected_location)
	
	_is_state_transitioning = false

func _resolve_and_clear_invalid_interaction():
	# This function is the single, authoritative implementation of TDD Rule [GR-5].
	# It performs the two required actions in the correct order.
	# Now called by GlobalInteractionRouter when invalid actions are detected.
	WindowManager.close_all_inspection_windows()
	clear_selection()

func _on_inventory_action_invalid(_source_loc: LocationIdentifier, _target_loc: LocationIdentifier):
	# The InventoryManager has confirmed the action is logically invalid.
	# We now resolve this invalid UI state.
	_resolve_and_clear_invalid_interaction()

func clear_selection():
	print("InteractionManager: clear_selection called")
	# This function's ONLY responsibility is to manage selection state. NO side effects.
	# Prevent redundant calls to avoid race conditions
	if _selected_view == null and _selected_location == null:
		print("InteractionManager: Selection already cleared, ignoring")
		return  # Already cleared, don't emit signals again
	
	# Prevent concurrent state transitions
	if _is_state_transitioning:
		print("InteractionManager: State transition in progress, ignoring clear_selection call")
		return
	
	_is_state_transitioning = true
	
	var previously_selected_view = _selected_view
	_selected_view = null
	_selected_location = null
	_last_state_change_frame = Engine.get_process_frames()
	
	# Also clear GlobalInteractionRouter's selection state
	if _global_router:
		_global_router.clear_current_selection()
	
	print("InteractionManager: Emitting view_deselected and selection_changed signals")
	if is_instance_valid(previously_selected_view):
		EventBus.emit_signal("view_deselected", previously_selected_view)
	EventBus.emit_signal("selection_changed", null)
	
	_is_state_transitioning = false

func get_selected_location() -> LocationIdentifier:
	return _selected_location

func get_selected_view() -> Control:
	return _selected_view

## State validation and debugging
func validate_selection_state() -> bool:
	# Ensure internal state consistency
	var has_selection = _selected_view != null and _selected_location != null
	var has_drag = _is_drag_active and _drag_source_view != null
	
	# Rule: Cannot have both selection and drag active
	if has_selection and has_drag:
		print("InteractionManager: INVALID STATE - Both selection and drag active!")
		return false
	
	# Rule: If drag is active, selection should be null
	if has_drag and has_selection:
		print("InteractionManager: INVALID STATE - Drag active but selection not cleared!")
		return false
	
	# Rule: GlobalInteractionRouter state should match InteractionManager state
	if _global_router:
		var router_has_selection = _global_router.get_current_selection() != null
		if has_selection != router_has_selection:
			print("InteractionManager: INVALID STATE - Router and Manager selection states don't match!")
			print("InteractionManager has selection: ", has_selection, ", Router has selection: ", router_has_selection)
			return false
	
	return true

func get_state_debug_info() -> String:
	var router_state = "Unknown"
	if _global_router:
		router_state = "Active" if _global_router.get_current_selection() != null else "None"
	
	return "Selection: %s, Drag: %s, Router: %s, Frame: %d" % [
		"Active" if _selected_view != null else "None",
		"Active" if _is_drag_active else "None",
		router_state,
		_last_state_change_frame
	]

func force_synchronize_states():
	# Force synchronization between InteractionManager and GlobalInteractionRouter
	if _global_router:
		var router_has_selection = _global_router.get_current_selection() != null
		var manager_has_selection = _selected_view != null
		
		if router_has_selection and not manager_has_selection:
			print("InteractionManager: Forcing router selection clear")
			_global_router.clear_current_selection()
		elif manager_has_selection and not router_has_selection:
			print("InteractionManager: Forcing manager selection clear")
			clear_selection()

# --- Drag & Drop State Management ---

func is_drag_active() -> bool:
	return _is_drag_active

func get_drag_source_view() -> Control:
	return _drag_source_view

func start_drag(source_view: Control, placeholder: Control):
	if not is_instance_valid(source_view): return
	
	# Clear any existing selection when starting drag
	clear_selection()
	
	# Also clear GlobalInteractionRouter's selection state
	if _global_router:
		_global_router.clear_current_selection()
	
	_is_drag_active = true
	_drag_source_view = source_view
	_drag_placeholder = placeholder
	
	# The view itself is made invisible, and the placeholder takes its spot
	# in the layout to prevent reflowing.
	source_view.visible = false

func end_drag(was_handled: bool):
	if not _is_drag_active: return
	
	# If drag was not handled (e.g., dropped on invalid area), restore visibility.
	if not was_handled and is_instance_valid(_drag_source_view):
		_drag_source_view.visible = true

	if is_instance_valid(_drag_placeholder):
		_drag_placeholder.queue_free()
		
	# Always clear drag state, regardless of success
	_is_drag_active = false
	_drag_source_view = null
	_drag_placeholder = null
	
	# Ensure selection is cleared after any drag operation
	# This prevents the "next click not registered" issue
	clear_selection()
	
	# Also ensure GlobalInteractionRouter's selection state is cleared
	if _global_router:
		_global_router.clear_current_selection()

func cancel_active_drag():
	if _is_drag_active:
		end_drag(false)

# Removed get_context_group - replaced by _get_container_functional_group
# which is used internally by the new selection system
