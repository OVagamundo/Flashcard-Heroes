<!-- Original: scripts/InteractionManager.gd -->

```gdscript
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

func _ready():
	EventBus.close_modal_requested.connect(clear_selection)
	EventBus.main_scene_requested.connect(clear_selection)
	EventBus.selection_clear_requested.connect(clear_selection)
	EventBus.inventory_action_invalid.connect(_on_inventory_action_invalid)

## Handle selection requests from GlobalInteractionRouter
func handle_selection_request(view: Control, location: LocationIdentifier):
	if not is_instance_valid(location):
		clear_selection()
		return

	if _selected_view == view:
		return

	if not is_instance_valid(_selected_view):
		select_view(view, location)
		return

	# If we have a previous selection, try to perform an action
	var source_loc = _selected_location
	var target_loc = location
	
	# Check if the locations are compatible for actions
	if _are_locations_compatible_for_action(source_loc, target_loc):
		EventBus.emit_signal("try_inventory_action", source_loc, target_loc)
	else:
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
	if not is_instance_valid(view) or not is_instance_valid(location):
		clear_selection()
		return

	# If a different view was already selected, deselect it first.
	if is_instance_valid(_selected_view):
		clear_selection()

	_selected_view = view
	_selected_location = location
	
	EventBus.emit_signal("view_selected", _selected_view, _selected_location)
	EventBus.emit_signal("selection_changed", _selected_location)

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
	# This function's ONLY responsibility is to manage selection state. NO side effects.
	var previously_selected_view = _selected_view
	_selected_view = null
	_selected_location = null
	if is_instance_valid(previously_selected_view):
		EventBus.emit_signal("view_deselected", previously_selected_view)
	EventBus.emit_signal("selection_changed", null)

func get_selected_location() -> LocationIdentifier:
	return _selected_location

func get_selected_view() -> Control:
	return _selected_view

# --- Drag & Drop State Management ---

func is_drag_active() -> bool:
	return _is_drag_active

func get_drag_source_view() -> Control:
	return _drag_source_view

func start_drag(source_view: Control, placeholder: Control):
	if not is_instance_valid(source_view): return
	
	clear_selection() # A drag operation overrides any selection
	
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
		
	_is_drag_active = false
	_drag_source_view = null
	_drag_placeholder = null

func cancel_active_drag():
	if _is_drag_active:
		end_drag(false)

# Removed get_context_group - replaced by _get_container_functional_group
# which is used internally by the new selection system

```