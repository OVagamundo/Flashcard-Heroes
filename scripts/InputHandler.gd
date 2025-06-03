extends Node

# Input actions and their default keybinds
const INPUT_ACTIONS = {
    "ui_up": KEY_W,
    "ui_down": KEY_S,
    "ui_left": KEY_A,
    "ui_right": KEY_D,
    "ui_accept": KEY_ENTER,
    "ui_cancel": KEY_ESCAPE,
    "ui_focus_next": KEY_TAB,
    "inspect_unit": KEY_I,
    "end_turn": KEY_SPACE
}

# Input state
var is_input_enabled: bool = true
var ui_manager: Node = null
var event_bus: Node = null

# Reference to the current scene's viewport
var current_viewport: Viewport = null

func _ready() -> void:
    # Get necessary nodes
    ui_manager = get_node_or_null("/root/UIManager")
    event_bus = get_node_or_null("/root/EventBus")
    current_viewport = get_viewport()
    
    # Set up input actions
    setup_input_actions()
    
    # Connect to UI manager signals if available
    if ui_manager:
        if ui_manager.has_signal("ui_element_opened"):
            ui_manager.ui_element_opened.connect(_on_ui_element_opened)
        if ui_manager.has_signal("ui_element_closed"):
            ui_manager.ui_element_closed.connect(_on_ui_element_closed)
    
    # Set up input processing
    set_process_input(true)
    set_process_unhandled_input(true)

func setup_input_actions() -> void:
    # Clear existing actions to prevent duplicates
    for action in InputMap.get_actions():
        InputMap.action_erase_events(action)
    
    # Create and configure input actions
    for action in INPUT_ACTIONS:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        
        # Skip mouse buttons as they're handled differently
        if action in ["left_click", "right_click"]:
            var mouse_event = InputEventMouseButton.new()
            mouse_event.button_index = INPUT_ACTIONS[action]
            InputMap.action_add_event(action, mouse_event)
        else:
            var key_event = InputEventKey.new()
            key_event.keycode = INPUT_ACTIONS[action]
            InputMap.action_add_event(action, key_event)

func _input(event: InputEvent) -> void:
    # Handle ESC key globally
    if event.is_action_pressed("ui_cancel"):
        _handle_cancel()
        get_viewport().set_input_as_handled()
        return
    
    # If modal UI is open, let it handle ALL input
    if ui_manager and ui_manager.current_open_element:
        # The modal element will handle its own input via _gui_input and _input
        # We just need to block further processing here
        get_viewport().set_input_as_handled()
        return
    
    # Process other inputs only if no modal UI is open
    if not is_input_enabled or not should_process_input():
        return
    
    # Handle global keyboard shortcuts
    if event.is_action_pressed("inspect_unit"):
        _handle_inspect_shortcut()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("end_turn"):
        _handle_end_turn()
        get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	print("InputHandler - Unhandled input: ", event)
	# Handle modal UI clicks
	if ui_manager and ui_manager.current_open_element:
		print("  - Modal UI is open")
		if event is InputEventMouseButton and event.pressed:
			print("  - Mouse button pressed in modal context")
			var panel = ui_manager.current_open_element
			if panel.has_method("_on_background_clicked"):
				print("  - Forwarding to panel")
				panel._on_background_clicked(event)
				get_viewport().set_input_as_handled()
				return
		get_viewport().set_input_as_handled()
		print("  - Input handled by InputHandler")
		return
		
	if not is_input_enabled or not should_process_input():
		return
	
	# Handle left clicks in the game world
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click(event)
		# Mark as handled to prevent further processing
		get_viewport().set_input_as_handled()

func _handle_left_click(event: InputEventMouseButton) -> void:
    # Let battle handle the click
    var battle = get_node_or_null("/root/Battle")
    if battle and battle.has_method("handle_unit_click"):
        battle.handle_unit_click(event.position)

# Handle the inspect unit keyboard shortcut
func _handle_inspect_shortcut() -> void:
    var battle = get_node_or_null("/root/Battle")
    if battle and battle.has_method("inspect_selected_unit"):
        battle.inspect_selected_unit()

func _handle_inspect_selected() -> void:
    var battle = get_node_or_null("/root/Battle")
    if battle and battle.has_method("inspect_selected_unit"):
        battle.inspect_selected_unit()

func _handle_end_turn() -> void:
    # Only allow ending turn if no UI is open or if the UI allows it
    if not ui_manager or not ui_manager.is_ui_open():
        event_bus.emit_signal("end_turn_pressed")

func _handle_cancel() -> void:
    if ui_manager and ui_manager.current_open_element:
        ui_manager.close_current_ui()
        get_viewport().set_input_as_handled()
    else:
        # Handle other cancel actions (e.g., deselect unit)
        var battle = get_node_or_null("/root/Battle")
        if battle and battle.has_method("_clear_selection"):
            battle._clear_selection()

func _on_ui_element_opened(_element: Control) -> void:
    # UI element opened
    pass

func _on_ui_element_closed(_element: Control) -> void:
    # UI element closed
    pass

# Check if input should be processed
func should_process_input() -> bool:
    if not is_input_enabled:
        return false
        
    # Don't process input if UI is blocking
    if ui_manager and ui_manager.is_ui_open():
        return false
        
    return true

# Placeholder for hover functionality (removed)

# Enable/disable all input processing
func set_input_enabled(enabled: bool) -> void:
    is_input_enabled = enabled
    set_process_input(enabled)
    set_process_unhandled_input(enabled)
