extends Window

@onready var unit1_preview: Panel = $VBoxContainer/HBoxContainer/Unit1Preview
@onready var unit2_preview: Panel = $VBoxContainer/HBoxContainer/Unit2Preview
@onready var result_preview: Panel = $VBoxContainer/HBoxContainer/ResultPreview

func _init() -> void:
	# Set window properties
	self.title = "Merge Units"
	self.size = Vector2(400, 200)
	self.unresizable = true
	self.transient = true
	self.exclusive = true
	self.close_requested.connect(_on_close_requested)
	self.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect buttons if they exist
	var cancel_button = $VBoxContainer/ButtonContainer/CancelButton
	var confirm_button = $VBoxContainer/ButtonContainer/ConfirmButton
	
	if cancel_button and not cancel_button.pressed.is_connected(_on_cancel_pressed):
		cancel_button.pressed.connect(_on_cancel_pressed)
	if confirm_button and not confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.connect(_on_confirm_pressed)
	
	# Make sure the window is on top
	move_to_foreground()
	
	# Connect the close signal if not already connected
	if not close_requested.is_connected(_on_close_requested):
		close_requested.connect(_on_close_requested)

func setup(unit1: Node, unit2: Node, result_unit_data: Resource) -> void:
	if not is_instance_valid(unit1) or not is_instance_valid(unit2) or not result_unit_data:
		print("Invalid units or result data for merge preview")
		queue_free()
		return

	var success = true
	var error_message = ""

	# Set title with unit names
	self.title = "Merge %s and %s" % [unit1.unit_data.display_name, unit2.unit_data.display_name]
	
	# Clear previous previews
	_clear_preview(unit1_preview)
	_clear_preview(unit2_preview)
	_clear_preview(result_preview)
	
	# Set up new previews
	if unit1 and unit1.has_method("get_unit_data"):
		if not _setup_unit_preview(unit1_preview, unit1.unit_data):
			success = false
			error_message = "Failed to setup unit1 preview"
	else:
		print("Unit1 is missing get_unit_data method")
		success = false
		error_message = "Unit1 is missing get_unit_data method"
		
	if unit2 and unit2.has_method("get_unit_data"):
		if not _setup_unit_preview(unit2_preview, unit2.unit_data):
			success = false
			error_message = "Failed to setup unit2 preview"
	else:
		print("Unit2 is missing get_unit_data method")
		success = false
		error_message = "Unit2 is missing get_unit_data method"
		
	if result_unit_data:
		if not _setup_unit_preview(result_preview, result_unit_data):
			success = false
			error_message = "Failed to setup result preview"
	else:
		print("Missing result unit data")
		success = false
		error_message = "Missing result unit data"
	
	if not success:
		print("Error in merge preview setup: ", error_message)
		push_error("Error in merge preview setup: " + error_message)
		queue_free()


func _setup_unit_preview(container: Panel, unit_data: Resource) -> void:
	if not container:
		return
		
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var texture_rect = TextureRect.new()
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	if unit_data and unit_data.get("texture"):
		texture_rect.texture = unit_data.texture
	
	# Add unit name and tier
	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = "%s (T%d)" % [unit_data.display_name, unit_data.tier] if unit_data else "?"
	
	vbox.add_child(texture_rect)
	vbox.add_child(label)
	container.add_child(vbox)

func _clear_preview(container: Panel) -> void:
	if container:
		for child in container.get_children():
			child.queue_free()

func _on_confirm_pressed() -> void:
	print("Merge confirmed by button")
	hide()
	confirmed.emit()

func _on_cancel_pressed() -> void:
	print("Merge canceled by button")
	hide()
	canceled.emit()

func _on_close_requested() -> void:
	print("Merge window closed")
	hide()
	canceled.emit()

func move_to_foreground() -> void:
	# Move window to foreground
	if is_inside_tree():
		var viewport = get_viewport()
		if viewport:
			move_to_foreground()
			grab_focus()

# Signals
signal confirmed
signal canceled
