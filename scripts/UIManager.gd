extends Node

# Singleton for managing UI elements and their interactions
signal ui_element_opened(element)
signal ui_element_closed(element)

var current_open_element: Control = null
var ui_stack: Array[Control] = []

func _input(event: InputEvent) -> void:
    # Handle back button/escape key
    if event.is_action_pressed("ui_cancel") and current_open_element:
        close_current_ui()

func open_ui(element: Control, hide_previous: bool = true) -> void:
    if current_open_element == element:
        return
        
    if hide_previous and current_open_element:
        current_open_element.hide()
    
    if hide_previous:
        ui_stack.append(current_open_element)
    
    current_open_element = element
    element.show()
    element.grab_focus()
    emit_signal("ui_element_opened", element)

func close_current_ui() -> void:
    if not current_open_element:
        return
        
    current_open_element.hide()
    emit_signal("ui_element_closed", current_open_element)
    
    if ui_stack.size() > 0:
        var previous = ui_stack.pop_back()
        if is_instance_valid(previous):
            previous.show()
            current_open_element = previous
            previous.grab_focus()
        else:
            current_open_element = null
    else:
        current_open_element = null

func close_all_ui() -> void:
    while current_open_element:
        close_current_ui()
    ui_stack.clear()

func is_ui_open() -> bool:
    return current_open_element != null
