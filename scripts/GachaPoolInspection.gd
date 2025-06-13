extends PanelContainer

# UI References
@onready var title: Label = $"VBoxContainer_TitleBar#Title"
@onready var grid_container: GridContainer = $"VBoxContainer_ScrollContainer#GridContainer"
@onready var close_button: Button = $"VBoxContainer_TitleBar#CloseButton"
@onready var close_button2: Button = $"VBoxContainer_Footer#CloseButton2"

func _ready():
	# Connect close buttons
	close_button.pressed.connect(hide)
	close_button2.pressed.connect(hide)
	
	# Ensure we receive input events
	mouse_filter = Control.MOUSE_FILTER_STOP

func _input(event: InputEvent) -> void:
	# Only process if visible and it's a left mouse button press
	if visible and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Convert event position to global coordinates
		var mouse_pos = get_global_mouse_position()
		var panel_rect = get_global_rect()
		
		# Check if click is outside the panel
		if not panel_rect.has_point(mouse_pos):
			hide()
			# Prevent the event from propagating further
			get_viewport().set_input_as_handled()

func setup_gacha_pool():
	# Clear existing children
	for child in grid_container.get_children():
		child.queue_free()
	# The grid will remain empty for now, as per the user's current goal.
