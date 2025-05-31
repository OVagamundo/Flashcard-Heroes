extends Control
class_name Unit

# Sprite paths
const HERO_SPRITE_PATH = "res://assets/images/UnitSprites/Sprite01.png"
const UNIT_SPRITE_PATH = "res://assets/images/UnitSprites/Sprite02.png"

# --- Signals --- #
signal unit_died(unit: Unit) # Emitted when this unit's HP reaches 0
# signal unit_selected(unit: Unit) # Kept for potential direct selection logic if needed

# --- Node References ---
@onready var unit_visual_panel: Panel = $VBoxContainer/UnitVisualPanel
@onready var unit_sprite: Sprite2D = $VBoxContainer/UnitVisualPanel/Sprite2D
@onready var hp_label: Label = $VBoxContainer/HPLabel
@onready var pwr_label: Label = $VBoxContainer/PWRLabel
@onready var unit_name_label: Label = $VBoxContainer/UnitNameLabel
@onready var tier_label: Label = $VBoxContainer/UnitVisualPanel/TierBadge/TierLabel

# --- Public Properties --- #
var is_currently_selected: bool = false

var unit_data: UnitData         # Holds the static data for this unit type
var current_hp: int             # Current health points
var is_player_team_unit: bool = true # Flag to identify team, set during initialization
var unit_type: String = ""      # Type of unit (offensive, defensive, etc.)
var tier: int = 1               # Unit tier (1 for basic, 2 for merged, etc.)

# --- Constants for Visual Selection --- #
const SELECTED_VISUAL_MODULATE: Color = Color(1.2, 1.2, 0.7, 1.0) # Brighter, slightly yellowish
const DESELECTED_VISUAL_MODULATE: Color = Color(1.0, 1.0, 1.0) # Neutral modulate

# --- Constants for Label Colors --- #
const PLAYER_LABEL_COLOR: Color = Color(0.3, 0.7, 1.0)  # A clear blue
const ENEMY_LABEL_COLOR: Color = Color(1.0, 0.4, 0.4)   # A clear red

# --- Godot Lifecycle Methods --- #
func _ready():
	self.z_index = 1 # Ensure unit renders on top of slot's base visuals
	# Wait for the next frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Initialize visual panel if it exists
	if is_instance_valid(unit_visual_panel):
		unit_visual_panel.self_modulate = DESELECTED_VISUAL_MODULATE

# --- Public Methods --- # 
func initialize(data: UnitData, is_player: bool, base_tint_color: Color) -> void:
	if not data:
		push_error("Unit.initialize(): UnitData is null! Cannot initialize unit.")
		return

	self.unit_data = data
	self.current_hp = data.max_hp
	self.is_player_team_unit = is_player
	self.unit_type = data.unit_type_tag
	self.tier = data.tier

		# Apply tint color to visual elements
	if is_instance_valid(unit_visual_panel):
		unit_visual_panel.self_modulate = base_tint_color
	
	# Set the appropriate sprite and flip if needed
	_update_sprite()

	# Force update the display
	call_deferred("_update_display")

func take_damage(amount: int) -> void:
	if current_hp <= 0: # Already dead, no further action
		return

	var old_hp = current_hp
	current_hp = max(0, current_hp - amount)
	# print(get_name_for_log(), " took ", amount, " damage. HP: ", current_hp, "/", unit_data.max_hp if unit_data else "N/A")

	_update_display()

	EventBus.unit_health_changed.emit(self, current_hp, old_hp, unit_data.max_hp if unit_data else 0)

	if current_hp <= 0:
		# print(get_name_for_log(), " has died.")
		unit_died.emit(self)
		EventBus.unit_died.emit(self) # Global event for battle system
		# Actual removal/queue_free is handled by Battle.gd to manage arrays properly

func perform_basic_attack(target_unit: Unit) -> void:
	if not unit_data or not is_instance_valid(target_unit) or target_unit.current_hp <= 0:
		# print_error(get_name_for_log(), " attack failed: Invalid unit_data, target, or target already dead.")
		return

	var damage = unit_data.pwr
	# print(get_name_for_log(), " attacks ", target_unit.get_name_for_log(), " for ", damage, " damage.")

	EventBus.unit_action_initiated.emit(self, "basic_attack", target_unit)
	target_unit.take_damage(damage)
	EventBus.unit_action_completed.emit(self, "basic_attack", {"target": target_unit, "damage_dealt": damage})

func get_display_name() -> String:
	if unit_data:
		return unit_data.display_name
	return "Unknown Unit"

func update_selection_visual(is_selected: bool) -> void:
	is_currently_selected = is_selected
	if is_instance_valid(unit_visual_panel):
		unit_visual_panel.self_modulate = SELECTED_VISUAL_MODULATE if is_selected else DESELECTED_VISUAL_MODULATE

func get_name_for_log() -> String:
	var team_prefix = "Player" if is_player_team_unit else "Enemy"
	if unit_data:
		return "%s %s (HP: %d/%d)" % [team_prefix, unit_data.display_name, current_hp, unit_data.max_hp]
	return "%s Unknown Unit" % team_prefix

# --- Private Helper Methods --- #
func _update_sprite() -> void:
	if not is_instance_valid(unit_sprite) or not unit_data:
		return
	
	# Set the appropriate sprite based on unit type
	if unit_data.unit_type_tag == "hero":
		unit_sprite.texture = load(HERO_SPRITE_PATH)
	else:
		unit_sprite.texture = load(UNIT_SPRITE_PATH)
	
	# Flip the sprite for enemy units
	unit_sprite.flip_h = not is_player_team_unit

func _update_display() -> void:
	# Ensure we have valid unit data
	if not unit_data:
		push_error("Unit._update_display(): unit_data is null")
		return

	# Update HP and PWR labels
	if is_instance_valid(hp_label):
		hp_label.text = "HP: %d" % current_hp
		
	if is_instance_valid(pwr_label):
		pwr_label.text = "PWR: %d" % unit_data.pwr

	# Update name and tier
	if is_instance_valid(unit_name_label):
		unit_name_label.text = unit_data.display_name
		
	if is_instance_valid(tier_label):
		tier_label.text = "T%d" % tier

	# Set label colors based on team
	var label_color = PLAYER_LABEL_COLOR if is_player_team_unit else ENEMY_LABEL_COLOR

	# Apply colors to labels
	for label in [hp_label, pwr_label]:
		if is_instance_valid(label):
			label.modulate = Color.WHITE
			label.add_theme_color_override("font_color", label_color)

	# The UnitVisualPanel (ellipse) is tinted by Battle.gd using self.modulate on the root Unit node.
	# No need to directly color unit_visual_panel here unless a more complex style is required.

# --- Input Handling for Selection (Optional) --- #
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if unit_data: # Ensure unit is properly initialized
			# print(get_name_for_log(), " clicked.")
			EventBus.unit_selected_for_action.emit(self)
			# unit_selected.emit(self) # If direct signal handling is preferred for selection
