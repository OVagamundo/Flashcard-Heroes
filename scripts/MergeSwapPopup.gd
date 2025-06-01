extends Panel

# Signals
signal merge_pressed
signal swap_pressed
signal close_requested

@onready var merge_button = $VBoxContainer/MergeButton
@onready var swap_button = $VBoxContainer/SwapButton

func _ready():
	# Set the panel to not process input by default
	set_process_unhandled_input(false)

func _on_merge_button_pressed():
	merge_pressed.emit()

func _on_swap_button_pressed():
	swap_pressed.emit()

# Handle clicks outside the popup
func _on_background_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_requested.emit()

# Make sure the popup doesn't close when clicking on buttons
func _on_button_mouse_entered():
	set_process_unhandled_input(false)

func _on_button_mouse_exited():
	set_process_unhandled_input(true)

# Handle ESC key to close
func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()
