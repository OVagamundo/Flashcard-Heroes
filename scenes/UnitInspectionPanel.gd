extends Panel

# Constants
const PANEL_MARGIN = 10
const PANEL_MIN_SIZE = Vector2(300, 200)

signal closed()

# UI elements
@onready var name_label: Label = $VBoxContainer/HeaderContainer/NameLabel
@onready var tier_type_label: Label = $VBoxContainer/TierTypeLabel
@onready var hp_label: Label = $VBoxContainer/StatsContainer/HPLabel
@onready var pwr_label: Label = $VBoxContainer/StatsContainer/PWRLabel
@onready var ability_container: VBoxContainer = $VBoxContainer/AbilityContainer

# Reference to UI manager
@onready var ui_manager = get_node_or_null("/root/UIManager")

func _init() -> void:
	# Set up panel appearance
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25)
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_color = Color(0.5, 0.5, 0.6)
	add_theme_stylebox_override("panel", style)
	
	# Configure for modal behavior
	mouse_filter = Control.MOUSE_FILTER_STOP  # Block mouse events from passing through
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = PANEL_MIN_SIZE
	
	# Make sure the panel receives mouse events
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Enable input processing
	set_process_input(true)
	set_process_unhandled_input(true)
	z_index = 1000  # Ensure it's on top
	
	# Make sure the panel's background receives input
	add_to_group("modal_panel")

# Initialize the panel
func _ready() -> void:
	size = Vector2(300, 400)
	position = Vector2(100, 100)  # Will be updated in display()
	z_index = 100
	top_level = true
	
	# Connect signals
	visibility_changed.connect(_on_visibility_changed)
	
	# Set up close button if it exists
	var close_button = get_node_or_null("CloseButton")
	if close_button:
		close_button.pressed.connect(close)
	
	# Set up input handling
	set_process_input(true)
	set_process_unhandled_input(true)
	z_index = 100

# Handle mouse enter/exit for hover effects
func _on_mouse_entered() -> void:
	pass

func _on_mouse_exited() -> void:
	pass

# Handle mouse input for the panel
func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	# Handle ESC key to close
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	
	# Handle mouse clicks
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Convert to local coordinates
		var local_pos = get_local_mouse_position()
		var panel_rect = Rect2(Vector2.ZERO, size)
		
		# If click is outside the panel, close it
		if not panel_rect.has_point(local_pos):
			close()
			get_viewport().set_input_as_handled()
		else:
			# Consume the click to prevent it from reaching other nodes
			get_viewport().set_input_as_handled()
			accept_event()

# Handle GUI input (for focus and other UI interactions)
func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
		
	# Consume all GUI input to prevent it from reaching other nodes
	accept_event()



# Called when visibility changes
func _on_visibility_changed() -> void:
	if visible:
		# When shown, make sure we have focus
		grab_focus()
	elif not is_queued_for_deletion():
		# When hidden, close the panel if not already being deleted
		close()

func display(unit_data: Resource, unit_screen_pos: Vector2) -> void:
	# Make sure we're in the tree
	if not is_inside_tree():
		get_tree().root.add_child(self)
		await get_tree().process_frame
		
	if not is_inside_tree():
		push_error("UnitInspectionPanel: Failed to add to scene tree")
		return
		
	# Update panel content
	if name_label:
		name_label.text = unit_data.display_name
	
	if tier_type_label:
		tier_type_label.text = "Tier %d • %s" % [unit_data.tier, unit_data.unit_type_tag]
	
	# Show the panel and position it
	if hp_label:
		hp_label.text = "HP: %d" % unit_data.max_hp
	
	if pwr_label:
		pwr_label.text = "PWR: %d" % unit_data.pwr
	
	# Clear existing ability labels
	if ability_container:
		for child in ability_container.get_children():
			child.queue_free()
	
	# Add ability description
	if ability_container and unit_data.ability_description and unit_data.ability_description.strip_edges() != "":
		var label = Label.new()
		label.text = "• %s" % unit_data.ability_description
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		ability_container.add_child(label)
	
	# Wait for the next frame to ensure proper sizing
	await get_tree().process_frame
	
	# Position the panel near the unit but ensure it's on screen
	var viewport_size = get_viewport_rect().size
	var current_panel_size = size
	
	# Position to the right of the unit by default
	var target_pos = unit_screen_pos + Vector2(40, 0)
	
	# Adjust if panel would go off-screen
	if target_pos.x + current_panel_size.x > viewport_size.x - PANEL_MARGIN:
		target_pos.x = unit_screen_pos.x - current_panel_size.x - 10
	
	if target_pos.y + current_panel_size.y > viewport_size.y - PANEL_MARGIN:
		target_pos.y = viewport_size.y - current_panel_size.y - PANEL_MARGIN
	
	# Ensure panel stays within screen bounds
	target_pos.x = max(PANEL_MARGIN, min(target_pos.x, viewport_size.x - current_panel_size.x - PANEL_MARGIN))
	target_pos.y = max(PANEL_MARGIN, min(target_pos.y, viewport_size.y - current_panel_size.y - PANEL_MARGIN))
	
	position = target_pos
	
	# Show the panel and grab focus
	show()
	
	# Set focus for keyboard navigation
	if focus_mode != Control.FOCUS_NONE:
		grab_focus()
		
	# Notify UI manager
	if ui_manager:
		ui_manager.open_ui(self)

# Position the panel near the specified screen position
func position_panel_near(screen_pos: Vector2) -> void:
	var viewport_size = get_viewport_rect().size
	var panel_size = size
	
	# Default position to the right of the unit
	var target_position = screen_pos + Vector2(60, -panel_size.y / 2)
	
	# Adjust if it would go off-screen right
	if target_position.x + panel_size.x > viewport_size.x - PANEL_MARGIN:
		target_position.x = screen_pos.x - panel_size.x - 20  # Show to the left
	
	# Adjust if it would go off-screen bottom
	if target_position.y + panel_size.y > viewport_size.y - PANEL_MARGIN:
		target_position.y = viewport_size.y - panel_size.y - PANEL_MARGIN
	
	# Adjust if it would go off-screen top
	target_position.y = max(PANEL_MARGIN, target_position.y)
	
	# Ensure position is within screen bounds
	target_position.x = clamp(target_position.x, PANEL_MARGIN, viewport_size.x - panel_size.x - PANEL_MARGIN)
	target_position.y = clamp(target_position.y, PANEL_MARGIN, viewport_size.y - panel_size.y - PANEL_MARGIN)
	
	position = target_position

# Show the panel centered on screen
func popup_centered() -> void:
	var viewport_size = get_viewport_rect().size
	position = (viewport_size - size) * 0.5
	show()
	
	# Notify UI manager
	if ui_manager:
		ui_manager.open_ui(self)

# Close the panel and clean up
func close() -> void:
	if is_queued_for_deletion() or not is_inside_tree():
		return
	
	# Hide first to stop input processing
	hide()
	
	# Notify UI manager to close modal state
	if ui_manager and ui_manager.current_open_element == self:
		ui_manager.close_current_ui()
	
	# Emit closed signal
	if not closed.is_connected(_on_closed):
		closed.emit()
	
	# Clean up and remove from scene
	queue_free()

# Helper method for cleanup
func _on_closed() -> void:
	# Additional cleanup if needed
	pass

# Clean up when the panel is removed from the scene tree
func _exit_tree() -> void:
	if is_queued_for_deletion():
		return
		
	if ui_manager and ui_manager.current_open_element == self:
		ui_manager.close_current_ui()
		
	# Disconnect any remaining signals to prevent memory leaks
	for connection in closed.get_connections():
		closed.disconnect(connection.callable)
