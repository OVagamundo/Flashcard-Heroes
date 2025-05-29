extends Control

class_name UnitSlot

# --- Signals --- #
# Emitted when this slot is clicked, passing itself as an argument.
signal slot_clicked(slot: UnitSlot)

# --- Exported Variables (Optional, for visual cues like highlighting) --- #
@export var highlight_panel: Panel # Optional: A Panel node to show selection/valid target

# --- Public Properties --- #
var occupying_unit: Unit = null
var slot_id: String = "" # e.g., "lineup_0", "bench_1"
var is_lineup_slot: bool = false # True if this is a slot in the active battle lineup
var is_player_slot: bool = true # Assuming these slots are for player units initially

# --- Constants for Visuals --- #
const HIGHLIGHT_SELECTED = Color(0.2, 0.5, 1.0, 0.5)  # Blue
const HIGHLIGHT_MERGE = Color(0.2, 1.0, 0.2, 0.5)     # Green
const HIGHLIGHT_INVALID = Color(1.0, 0.2, 0.2, 0.5)   # Red
const NO_HIGHLIGHT = Color(0, 0, 0, 0)  # Transparent

# For backward compatibility
const DEFAULT_HIGHLIGHT_COLOR: Color = NO_HIGHLIGHT
const VALID_TARGET_HIGHLIGHT_COLOR: Color = HIGHLIGHT_MERGE

# --- Godot Lifecycle Methods --- #
func _ready():
	self.mouse_filter = Control.MOUSE_FILTER_STOP # Ensure this Control node can receive mouse events
	if is_instance_valid(highlight_panel):
		highlight_panel.visible = true
		highlight_panel.self_modulate = DEFAULT_HIGHLIGHT_COLOR

# --- Input Handling --- #
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# print("Slot ", slot_id, " clicked. Occupied by: ", occupying_unit.get_display_name() if occupying_unit else "Empty")
		EventBus.slot_clicked_for_action.emit(self)

# --- Public Methods --- #
func assign_unit(unit_node: Unit) -> void:
	if not is_instance_valid(unit_node):
		push_error("UnitSlot.assign_unit(): Attempted to assign an invalid unit node.")
		return

	if is_instance_valid(occupying_unit) and occupying_unit != unit_node:
		# This case should ideally be handled by Battle.gd logic before calling assign_unit
		# (e.g., clearing the slot first or performing a swap)
		push_warning("UnitSlot.assign_unit(): Slot %s is already occupied by %s. Overwriting with %s." % [slot_id, occupying_unit.get_display_name(), unit_node.get_display_name()])
		clear_unit() # Clear previous unit if any

	self.occupying_unit = unit_node
	# Ensure the unit is not parented elsewhere before adding
	if unit_node.get_parent():
		unit_node.get_parent().remove_child(unit_node)
	add_child(unit_node)
	# Position the unit; assuming Unit's root is a Control node and will fill/center in the slot.
	# If Unit's root is Node2D, you might need to set unit_node.position = self.size / 2 or similar.
	unit_node.position = Vector2.ZERO # Or center it: (size - unit_node.size) / 2.0
	unit_node.visible = true
	# print("UnitSlot.assign_unit(): Assigned ", unit_node.get_display_name(), " to slot ", slot_id)

func clear_unit() -> Unit:
	if is_instance_valid(occupying_unit):
		var unit_to_remove: Unit = occupying_unit
		self.occupying_unit = null
		if unit_to_remove.get_parent() == self:
			remove_child(unit_to_remove)
		# print("UnitSlot.clear_unit(): Cleared ", unit_to_remove.get_display_name(), " from slot ", slot_id)
		return unit_to_remove
	# print("UnitSlot.clear_unit(): Slot ", slot_id, " was already empty.")
	return null

func is_empty() -> bool:
	return occupying_unit == null or not is_instance_valid(occupying_unit)

# Basic highlight for valid drop target (can be expanded)
func set_highlight(type: String) -> void:
	if not is_instance_valid(highlight_panel):
		return
		
	match type:
		"selected":
			highlight_panel.self_modulate = HIGHLIGHT_SELECTED
			highlight_panel.visible = true
		"merge":
			highlight_panel.self_modulate = HIGHLIGHT_MERGE
			highlight_panel.visible = true
		"invalid":
			highlight_panel.self_modulate = HIGHLIGHT_INVALID
			highlight_panel.visible = true
		_:
			highlight_panel.visible = false

# For backward compatibility
func set_highlight_as_valid_target(is_valid: bool) -> void:
	set_highlight("merge" if is_valid else "")

# Helper to check if a Hero unit can be placed (Heroes can't go to bench slots)
func can_accommodate_hero() -> bool:
	return is_lineup_slot
