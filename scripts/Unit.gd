extends Control
class_name Unit

# UI elements
@onready var unit_button: TextureButton = $Button
@onready var unit_rect: ColorRect = $ColorRect
@onready var health_bar: ProgressBar = $Button/HealthBar if has_node("Button/HealthBar") else null
@onready var name_label: Label = $Button/NameLabel if has_node("Button/NameLabel") else null
@onready var attack_label: Label = $Button/AttackLabel if has_node("Button/AttackLabel") else null
@onready var defense_label: Label = $Button/DefenseLabel if has_node("Button/DefenseLabel") else null

# Debug function to check node paths
func _check_node_paths() -> void:
	print("Checking node paths:")
	print("- Button: ", has_node("Button"))
	print("- ColorRect: ", has_node("ColorRect"))
	if has_node("Button"):
		print("  - HealthBar: ", has_node("Button/HealthBar"))
		print("  - NameLabel: ", has_node("Button/NameLabel"))
		print("  - AttackLabel: ", has_node("Button/AttackLabel"))
		print("  - DefenseLabel: ", has_node("Button/DefenseLabel"))

# Cache the default style for hover/selection states
var default_style: StyleBoxFlat
var hover_style: StyleBoxFlat
var selected_style: StyleBoxFlat

var unit_data: UnitResource
var current_health: int
var current_attack: int
var current_defense: int

signal unit_clicked(unit: Unit)
signal unit_hovered(unit: Unit, is_hovered: bool)

func initialize(data: UnitResource) -> void:
	if not data:
		push_error("Unit.initialize(): data is null")
		return
	self.unit_data = data # Store data; _ready() will use it for setup

func _ready() -> void:
	# Debug: Print node paths for verification
	_check_node_paths()
	
	# Initialize styles (these don't depend on unit_data yet)
	default_style = StyleBoxFlat.new(); default_style.bg_color = Color(0.3, 0.3, 0.3, 0.7)
	hover_style = StyleBoxFlat.new(); hover_style.bg_color = Color(0.4, 0.4, 0.4, 0.8)
	selected_style = StyleBoxFlat.new(); selected_style.bg_color = Color(0.2, 0.6, 0.2, 0.8)
	
	# Setup button if it exists
	if unit_button:
		unit_button.focus_mode = Control.FOCUS_ALL
		if not unit_button.pressed.is_connected(_on_unit_clicked): unit_button.pressed.connect(_on_unit_clicked)
		if not unit_button.mouse_entered.is_connected(_on_mouse_entered): unit_button.mouse_entered.connect(_on_mouse_entered)
		if not unit_button.mouse_exited.is_connected(_on_mouse_exited): unit_button.mouse_exited.connect(_on_mouse_exited)
		
		# Show either button or colored rectangle
		if unit_button.texture_normal:
			unit_button.show()
			if unit_rect: unit_rect.hide()
		else:
			unit_button.hide()
			if unit_rect: unit_rect.show(); unit_rect.color = Color(0.5, 0.5, 0.8, 0.8)
		
		unit_button.add_theme_stylebox_override("normal", default_style)
	else:
		push_error("Unit._ready(): unit_button is null.")
	
	# Setup health bar base styles if it exists
	if health_bar:
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = Color(0.2, 0.8, 0.2) # Default green, will be updated by update_health_bar
		fill_style.border_width_bottom = 1; fill_style.border_width_left = 1; fill_style.border_width_right = 1; fill_style.border_width_top = 1
		fill_style.border_color = Color(0,0,0,1)
		health_bar.add_theme_stylebox_override("fill", fill_style)
		
		var bg_style = StyleBoxFlat.new(); bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.7)
		health_bar.add_theme_stylebox_override("background", bg_style)
	else:
		push_error("Unit._ready(): health_bar is null.")

	# Ensure unit_data was set by initialize()
	if not unit_data:
		push_error("Unit._ready(): unit_data is null. Cannot complete setup.")
		if name_label: name_label.text = "Error!"
		return # Stop further setup if no data

	# Initialize unit's current stats from unit_data
	current_health = unit_data.max_health
	current_attack = unit_data.attack
	current_defense = unit_data.defense

	# Safely update UI elements using unit_data
	if name_label:
		name_label.text = unit_data.display_name
	else:
		push_error("Unit._ready(): name_label is null when trying to set text from unit_data.")
	
	# Set team-specific appearance
	if unit_data.team == "enemy":
		self_modulate = Color(1, 0.8, 0.8)  # Slight red tint for enemies
		if name_label: # Check again for safety, though the one above should cover it
			name_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	
	update_health_bar() # Now uses initialized current_health and unit_data
	update_stats()      # Now uses initialized current_attack/defense

func update_health_bar() -> void:
	if not health_bar or not unit_data:
		push_error("Unit.update_health_bar(): Missing health_bar or unit_data")
		return
		
	var health_percent = float(current_health) / float(unit_data.max_health)
	health_bar.value = health_percent * 100.0
	
	# Create a stylebox for the health bar
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.8, 0.2)  # Default green
	
	# Update health bar color based on health percentage
	if health_percent <= 0.3:
		style.bg_color = Color(0.8, 0.2, 0.2)  # Red when low
	elif health_percent <= 0.6:
		style.bg_color = Color(1.0, 0.8, 0.2)  # Yellow when medium
		
	health_bar.add_theme_stylebox_override("fill", style)  # Green when healthy

func update_stats() -> void:
	if attack_label:
		attack_label.text = "ATK: %d" % current_attack
	else:
		push_error("Unit: attack_label is null in update_stats()")
		
	if defense_label:
		defense_label.text = "DEF: %d" % current_defense
	else:
		push_error("Unit: defense_label is null in update_stats()")

func take_damage(amount: int) -> void:
	var damage_taken = max(1, amount - current_defense)
	current_health = max(0, current_health - damage_taken)
	update_health_bar()
	
	if current_health <= 0:
		die()

func die() -> void:
	queue_free()
	EventBus.unit_died.emit(self)

func _on_unit_clicked() -> void:
	emit_signal("unit_clicked", self)

func _on_mouse_entered() -> void:
	emit_signal("unit_hovered", self, true)

func _on_mouse_exited() -> void:
	emit_signal("unit_hovered", self, false)
