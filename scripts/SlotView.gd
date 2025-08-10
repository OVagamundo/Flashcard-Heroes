class_name SlotView
extends PanelContainer

var _location: LocationIdentifier

# InteractionContext properties
var _interaction_mode: StringName = &"FULLY_INTERACTIVE"
var _window_group_id: int = 0

func _ready():
	# Add a simple stylebox to make the empty slot visible.
	var style = StyleBoxFlat.new()
	style.set_bg_color(Color(0,0,0,0.2))
	style.set_border_width_all(1)
	style.set_border_color(Color(0.5, 0.5, 0.5, 0.5))
	add_theme_stylebox_override("panel", style)

func _exit_tree():
	# If a drag is active while this slot is being freed, end it to prevent leaks
	if GlobalInteractionRouter.is_drag_active():
		GlobalInteractionRouter.end_drag(false)
		GlobalInteractionRouter.end_drag_visuals(false)

func _notification(what):
	pass

func populate(loc: LocationIdentifier):
	self._location = loc
	set_meta("location_identifier", loc) # For InteractionManager and WindowManager

## Configure the interaction context for this slot
func set_interaction_context(interaction_mode: StringName, window_group_id: int = 0):
	_interaction_mode = interaction_mode
	_window_group_id = window_group_id

## Create and emit InteractionContext for this slot
func _create_interaction_context(event_type: StringName) -> InteractionContext:
	var context = InteractionContext.new()
	context.source_view_instance_id = get_instance_id()
	context.event_type = event_type
	context.location = _location
	context.entity_uuid = ""  # Empty slots have no entity
	context.entity_type = &"EMPTY_SLOT"
	context.interaction_mode = _interaction_mode
	context.window_group_id = _window_group_id
	return context

func _gui_input(event: InputEvent):
	if not is_instance_valid(_location): return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Do NOT consume the event here; allow child views to initiate drag

		# Create and emit InteractionContext
		var context = _create_interaction_context(&"SINGLE_CLICK")
		SignalBus.emit_signal("interaction_context_received", context)
		# If this is an empty slot (no child view), stop propagation so Main/Battle don't emit GLOBAL_BACKGROUND
		if get_child_count() == 0:
			get_viewport().set_input_as_handled()

func _can_drop_data(_at_position, data) -> bool:
	# Check if this is an inspection-only context
	if _interaction_mode == &"INSPECTION_ONLY":
		return false
		
	return data is Dictionary and data.has("source_loc")

func _drop_data(_at_position, data):
	# Check if this is an inspection-only context
	if _interaction_mode == &"INSPECTION_ONLY":
		return

	# Create a target interaction context and route via GIR
	var target_ctx = _create_interaction_context(&"DROP")
	SignalBus.emit_signal("interaction_context_received", target_ctx)

	# Do not end drag here; InventoryManager will decide handled/unhandled and
	# call GlobalInteractionRouter.end_drag(true/false) centrally.
