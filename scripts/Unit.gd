extends Control

class_name Unit

# --- Signals --- #
signal unit_died(unit: Unit) # Emitted when this unit's HP reaches 0
# signal unit_selected(unit: Unit) # Kept for potential direct selection logic if needed

# --- Exported Variables (NodePaths from Unit.tscn, set in Inspector) --- #
@export var unit_visual_panel: Panel
@export var hp_label: Label
@export var pwr_label: Label

# --- Public Properties --- #
var is_currently_selected: bool = false

var unit_data: UnitData         # Holds the static data for this unit type
var current_hp: int             # Current health points
var is_player_team_unit: bool = true # Flag to identify team, set during initialization

# --- Constants for Visual Selection --- #
const SELECTED_VISUAL_MODULATE: Color = Color(1.2, 1.2, 0.7, 1.0) # Brighter, slightly yellowish
const DESELECTED_VISUAL_MODULATE: Color = Color(1.0, 1.0, 1.0) # Neutral modulate

# --- Constants for Label Colors --- #
const PLAYER_LABEL_COLOR: Color = Color(0.3, 0.7, 1.0)  # A clear blue
const ENEMY_LABEL_COLOR: Color = Color(1.0, 0.4, 0.4)   # A clear red

# --- Godot Lifecycle Methods --- #
func _ready():
	self.z_index = 1 # Ensure unit renders on top of slot's base visuals
	# Initial display update is handled by initialize() as unit_data is needed.
	# If unit_data was an @export var and set in scene, _ready could do initial setup.
	# For now, initialize() is the main entry point for setting up a new unit.
	if is_instance_valid(unit_visual_panel):
		unit_visual_panel.self_modulate = DESELECTED_VISUAL_MODULATE
	pass

# --- Public Methods --- # 
func initialize(data: UnitData, is_player: bool, base_tint_color: Color) -> void:
	if not data:
		push_error("Unit.initialize(): UnitData is null! Cannot initialize unit.")
		return

	self.unit_data = data
	self.current_hp = unit_data.max_hp
	self.is_player_team_unit = is_player

	# The base_tint_color is applied to self_modulate by Battle.gd to tint the UnitVisualPanel
	# self.modulate = base_tint_color # This is done by Battle.gd

	_update_display()
	# print("Unit Initialized: ", unit_data.unit_name if unit_data else "N/A", ", HP: ", current_hp, ", Player: ", is_player_team_unit)

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

func update_selection_visual(selected_state: bool) -> void:
	is_currently_selected = selected_state
	if is_instance_valid(unit_visual_panel):
		if is_currently_selected:
			unit_visual_panel.self_modulate = SELECTED_VISUAL_MODULATE
		else:
			unit_visual_panel.self_modulate = DESELECTED_VISUAL_MODULATE

func get_name_for_log() -> String:
	var team_prefix = "Player" if is_player_team_unit else "Enemy"
	return "%s %s" % [team_prefix, get_display_name()]

# --- Private Helper Methods --- #
func _update_display() -> void:
	# Ensure nodes are valid and unit_data is present
	if not is_instance_valid(hp_label) or not is_instance_valid(pwr_label) or not unit_data:
		# This can occur if called before nodes are fully ready or if unit_data is missing.
		# print_debug("Unit._update_display(): Skipping, nodes or unit_data not ready for '" + self.name + "'")
		return

	hp_label.text = "HP: %s" % current_hp
	pwr_label.text = "PWR: %s" % unit_data.pwr

	var label_color_to_apply = PLAYER_LABEL_COLOR if is_player_team_unit else ENEMY_LABEL_COLOR

	# Reset modulate to ensure add_theme_color_override works as expected without interference
	hp_label.modulate = Color.WHITE 
	pwr_label.modulate = Color.WHITE

	# Apply the specific color to the font. The LabelSettings in Unit.tscn provides the outline.
	hp_label.add_theme_color_override("font_color", label_color_to_apply)
	pwr_label.add_theme_color_override("font_color", label_color_to_apply)

	# The UnitVisualPanel (ellipse) is tinted by Battle.gd using self.modulate on the root Unit node.
	# No need to directly color unit_visual_panel here unless a more complex style is required.

# --- Input Handling for Selection (Optional) --- #
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if unit_data: # Ensure unit is properly initialized
			# print(get_name_for_log(), " clicked.")
			EventBus.unit_selected_for_action.emit(self)
			# unit_selected.emit(self) # If direct signal handling is preferred for selection
