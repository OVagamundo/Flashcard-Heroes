<!-- Original: scripts/UnitInspectionWindow.gd -->

```gdscript
class_name UnitInspectionWindow
extends "res://scripts/InspectionWindow.gd"

const _GachaBallView = preload("res://scenes/GachaBallView.tscn")
const _SlotView = preload("res://scenes/SlotView.tscn")

@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var item_grid: GridContainer = %ItemGrid
@onready var item_grid_label: Label = %ItemGridLabel
@onready var internal_background: ColorRect = $InternalBackground

var _inspected_unit_uuid: String
var _source_view: Control
var _instance: GachaBallInstance
var _location: LocationIdentifier
var _is_enemy_context: bool = false
var _window_group_id: int = 1  # Inspection window group
var _stable_anchor: Control = null  # Stable anchor for positioning

func _ready():
	EventBus.battle_inventory_changed.connect(_on_inventory_changed)
	EventBus.unit_inventory_changed.connect(_on_unit_inventory_changed)
	EventBus.run_data_changed.connect(_on_inventory_changed)
	EventBus.unit_stats_changed.connect(_on_unit_stats_changed)
	description_label.meta_clicked.connect(_on_description_meta_clicked)
	description_label.mouse_filter = MOUSE_FILTER_PASS
	description_label.meta_hover_started.connect(_on_description_meta_hover_started)
	description_label.meta_hover_ended.connect(_on_description_meta_hover_ended)
	internal_background.gui_input.connect(_on_internal_background_clicked)

func _exit_tree():
	if EventBus.is_connected("battle_inventory_changed", _on_inventory_changed):
		EventBus.battle_inventory_changed.disconnect(_on_inventory_changed)
	if EventBus.is_connected("unit_inventory_changed", _on_unit_inventory_changed):
		EventBus.unit_inventory_changed.disconnect(_on_unit_inventory_changed)
	if EventBus.is_connected("run_data_changed", _on_inventory_changed):
		EventBus.run_data_changed.disconnect(_on_inventory_changed)
	if EventBus.is_connected("unit_stats_changed", _on_unit_stats_changed):
		EventBus.unit_stats_changed.disconnect(_on_unit_stats_changed)

func _on_internal_background_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Create and emit InteractionContext for inspection window background
		var context = InteractionContext.new()
		context.source_view_instance_id = get_instance_id()
		context.event_type = &"SINGLE_CLICK"
		context.location = null  # No specific location for background
		context.entity_uuid = ""
		context.entity_type = &"WINDOW_BACKGROUND"
		context.interaction_mode = &"FULLY_INTERACTIVE"
		context.window_group_id = 1  # Inspection window group
		
		EventBus.emit_signal("interaction_context_received", context)
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent):
	# Handle background clicks on the inspection window itself
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Check if the click is within the RichTextLabel's bounds (EFFECTS link)
		if description_label.get_global_rect().has_point(event.global_position):
			# This is a click on the text link area, don't interfere
			return
		
		# Check if the click is on the internal background (covers entire window area)
		var background_rect = internal_background.get_global_rect()
		if background_rect.has_point(event.global_position):
			# Create and emit InteractionContext for inspection window background
			var context = InteractionContext.new()
			context.source_view_instance_id = get_instance_id()
			context.event_type = &"SINGLE_CLICK"
			context.location = null  # No specific location for background
			context.entity_uuid = ""
			context.entity_type = &"WINDOW_BACKGROUND"
			context.interaction_mode = &"FULLY_INTERACTIVE"
			context.window_group_id = 1  # Inspection window group
			
			EventBus.emit_signal("interaction_context_received", context)
			get_viewport().set_input_as_handled()
			return
		
		# Check for other interactive elements
		var clicked_control = _get_control_at_position(event.global_position)
		if _is_interactive_element(clicked_control):
			return
		
		# If we reach here, it's a click on a non-interactive element, treat as background click
		var context = InteractionContext.new()
		context.source_view_instance_id = get_instance_id()
		context.event_type = &"SINGLE_CLICK"
		context.location = null  # No specific location for background
		context.entity_uuid = ""
		context.entity_type = &"WINDOW_BACKGROUND"
		context.interaction_mode = &"FULLY_INTERACTIVE"
		context.window_group_id = 1  # Inspection window group
		
		EventBus.emit_signal("interaction_context_received", context)
		get_viewport().set_input_as_handled()

func _get_control_at_position(position: Vector2) -> Control:
	# Recursively search for the control at the given position
	return _find_control_recursive(self, position)

func _find_control_recursive(node: Node, position: Vector2) -> Control:
	# Check if this node is a Control and contains the position
	if node is Control:
		var control = node as Control
		if control.get_global_rect().has_point(position):
			# This control contains the position, but check if any child also contains it
			for child in node.get_children():
				var child_result = _find_control_recursive(child, position)
				if is_instance_valid(child_result):
					return child_result
			# No child contains the position, so this is the deepest control
			return control
	
	# If this node is not a Control, check its children
	for child in node.get_children():
		var result = _find_control_recursive(child, position)
		if is_instance_valid(result):
			return result
	
	return null

func _is_interactive_element(control: Control) -> bool:
	if not is_instance_valid(control):
		return false
	
	# Check if it's a Button
	if control is Button:
		return true
	
	# Check if it has a specific class name that indicates interactivity
	var control_class = control.get_class()
	if control_class in ["Button", "LinkButton", "OptionButton", "CheckBox", "CheckButton", "RadioButton"]:
		return true
	
	# Check if it's a GachaBallView (interactive game element)
	if control is GachaBallView:
		return true
	
	# Check if it's a SlotView (interactive game element)
	if control is SlotView:
		return true
	
	return false


func populate(context: Dictionary):
	_source_view = context.get("source_view")
	_instance = context.get("instance")
	_location = context.get("location")
	_is_enemy_context = context.get("is_enemy_context", false)

	if not is_instance_valid(_source_view) or not is_instance_valid(_instance):
		printerr("UnitInspectionWindow: Invalid context provided.")
		queue_free()
		return

	var unit_definition = _instance.get_definition()
	if not is_instance_valid(unit_definition):
		queue_free()
		return

	_inspected_unit_uuid = _instance.ball_uuid

	# Set up stable anchor pattern
	_setup_stable_anchor()

	name_label.text = tr(unit_definition.display_name_key)
	var description_text = tr(unit_definition.description_key)
	
	# Add basic attack description for units
	var basic_attack_desc = tr("ability.basic_attack.desc")
	# Replace (PWR) with the actual power value
	basic_attack_desc = basic_attack_desc.replace("(PWR)", str(_instance.current_pwr))
	
	_update_description()

	# --- Core UI Population Logic ---
	_rebuild_item_grid()

## Set up stable anchor pattern for robust positioning
func _setup_stable_anchor():
	if is_instance_valid(_source_view):
		# Find the nearest stable container (SlotView or PanelContainer)
		_stable_anchor = _find_stable_anchor(_source_view)
		if is_instance_valid(_stable_anchor):
			# Connect to anchor movement for dynamic positioning
			_stable_anchor.item_rect_changed.connect(_on_anchor_moved)
			_stable_anchor.tree_exited.connect(_on_anchor_freed)

## Find stable anchor for positioning
func _find_stable_anchor(original_anchor: Control) -> Control:
	# If the original anchor is already a stable container, use it
	if original_anchor.get_class() == "SlotView" or original_anchor.get_class() == "PanelContainer":
		return original_anchor
	
	# Otherwise, find the nearest stable container parent
	var current = original_anchor
	while is_instance_valid(current) and current != get_tree().root:
		if current.get_class() == "SlotView" or current.get_class() == "PanelContainer":
			return current
		current = current.get_parent()
	
	# If no stable container found, fall back to the original anchor
	return original_anchor

## Handle anchor movement for dynamic positioning
func _on_anchor_moved():
	if is_instance_valid(_stable_anchor):
		# Reposition window relative to anchor
		global_position = _calculate_position_relative_to_anchor()

## Handle anchor being freed
func _on_anchor_freed():
	# If anchor is gone, close the window to prevent orphaned UI
	queue_free()

## Calculate position relative to stable anchor
func _calculate_position_relative_to_anchor() -> Vector2:
	if not is_instance_valid(_stable_anchor):
		return global_position
	
	var anchor_rect = _stable_anchor.get_global_rect()
	var window_size = size
	var viewport_rect = get_viewport().get_visible_rect()
	
	# Try to position to the right of the anchor
	var pos_right = Vector2(anchor_rect.end.x + 20, anchor_rect.position.y)
	if viewport_rect.encloses(Rect2(pos_right, window_size)):
		return pos_right
	
	# Try to position below the anchor
	var pos_below = Vector2(anchor_rect.position.x, anchor_rect.end.y + 20)
	if viewport_rect.encloses(Rect2(pos_below, window_size)):
		return pos_below
	
	# Try to position above the anchor
	var pos_above = Vector2(anchor_rect.position.x, anchor_rect.position.y - window_size.y - 20)
	if viewport_rect.encloses(Rect2(pos_above, window_size)):
		return pos_above
	
	# Fallback: position to the left of the anchor
	var pos_left = Vector2(anchor_rect.position.x - window_size.x - 20, anchor_rect.position.y)
	if viewport_rect.encloses(Rect2(pos_left, window_size)):
		return pos_left
	
	# Last resort: position in the top-right corner of the anchor
	return Vector2(anchor_rect.end.x - window_size.x - 20, anchor_rect.position.y + 20)


func _rebuild_item_grid():
	# This function now handles the complete lifecycle of the item grid UI.
	# It ensures that slots are persistent and correctly represent the data model.
	if not is_instance_valid(_instance): 
		return
	var unit_definition = _instance.get_definition()
	if not is_instance_valid(unit_definition): 
		return

	# Clear existing content from slots, but don't delete the slots themselves.
	for slot_view in item_grid.get_children():
		for content in slot_view.get_children():
			content.queue_free()

	# Ensure the correct number of persistent SlotViews exist.
	while item_grid.get_child_count() < unit_definition.item_slot_count:
		item_grid.add_child(_SlotView.instantiate())
	while item_grid.get_child_count() > unit_definition.item_slot_count:
		item_grid.get_child(item_grid.get_child_count() - 1).queue_free()

	if unit_definition.item_slot_count == 0:
		item_grid_label.visible = false
		item_grid.visible = false
		return
	else:
		item_grid_label.visible = true
		item_grid.visible = true
		item_grid.columns = unit_definition.item_slot_count

	var all_instances_db = _get_all_instances_db()
	if all_instances_db.is_empty(): 
		return

	# Iterate through all defined slots and populate them.
	for i in range(unit_definition.item_slot_count):
		var slot_view = item_grid.get_child(i)
		
		# CRITICAL: Create a valid LocationIdentifier for EVERY slot, empty or not.
		var loc = LocationIdentifier.new()
		loc.container = &"equipped_item"
		loc.index = i
		loc.unit_uuid = _instance.ball_uuid
		slot_view.populate(loc) # This makes the empty slot a valid drop target.
		
		# Set interaction context for the slot
		var slot_interaction_mode = &"INSPECTION_ONLY" if _is_enemy_context else &"FULLY_INTERACTIVE"
		slot_view.set_interaction_context(slot_interaction_mode, _window_group_id)

		var item_uuid = _instance.get_equipped_item_uuid(i)

		if not item_uuid.is_empty() and all_instances_db.has(item_uuid):
			var item_instance = all_instances_db[item_uuid]
			var gacha_view = _GachaBallView.instantiate()
			slot_view.add_child(gacha_view)
			
			# Enhanced contextual behavior for player vs enemy units
			var is_interactive = not _is_enemy_context
			var single_click_inspect = _is_enemy_context
			var interaction_mode = &"INSPECTION_ONLY" if _is_enemy_context else &"FULLY_INTERACTIVE"
			
			gacha_view.populate(loc, item_instance, true, single_click_inspect)
			gacha_view.set_is_interactive(is_interactive)
			gacha_view.set_interaction_context(interaction_mode, &"ITEM", _window_group_id)
	

func _update_description():
	if not is_instance_valid(_instance):
		return
	
	var unit_definition = _instance.get_definition()
	if not is_instance_valid(unit_definition):
		return
	
	var description_text = tr(unit_definition.description_key)
	
	# Add basic attack description for units
	var basic_attack_desc = tr("ability.basic_attack.desc")
	# Replace (PWR) with the actual power value
	basic_attack_desc = basic_attack_desc.replace("(PWR)", str(_instance.current_pwr))
	
	description_label.text = "%s\n\n%s\n\n[url=effect]EFFECTS[/url]" % [description_text, basic_attack_desc]
	description_label.set_meta("definition", unit_definition)
	description_label.set_meta("effect_definition", unit_definition)

func _on_unit_stats_changed(unit_uuid: String):
	if unit_uuid == _inspected_unit_uuid:
		# Update the instance reference and refresh the description
		var all_instances = _get_all_instances_db()
		var current_instance = all_instances.get(_inspected_unit_uuid)
		if is_instance_valid(current_instance):
			_instance = current_instance
			_update_description()

func _on_inventory_changed():
	if not is_instance_valid(self): 
		return
	# Check if the inspected unit still exists. If not, the window should close.
	var all_instances = _get_all_instances_db()
	var current_instance = all_instances.get(_inspected_unit_uuid)
	if not is_instance_valid(current_instance):
		queue_free()
		return
	
	# The unit still exists, so we just need to refresh the item grid.
	_instance = current_instance # Ensure we have the latest data
	_update_description()
	_rebuild_item_grid()

func _on_unit_inventory_changed(unit_uuid: String):
	if not is_instance_valid(self): 
		return
	
	# Only update if the changed unit is the one we're inspecting
	if unit_uuid != _inspected_unit_uuid:
		return
	
	# Check if the inspected unit still exists. If not, the window should close.
	var all_instances = _get_all_instances_db()
	var current_instance = all_instances.get(_inspected_unit_uuid)
	if not is_instance_valid(current_instance):
		queue_free()
		return
	
	# The unit still exists, so we just need to refresh the item grid.
	_instance = current_instance # Ensure we have the latest data
	_update_description()
	_rebuild_item_grid()

func _get_all_instances_db() -> Dictionary:
	var result: Dictionary
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		result = bm.get_all_instances() if is_instance_valid(bm) else {}
	else:
		result = GameManager.run_state.run_instances if is_instance_valid(GameManager.run_state) else {}
	
	return result

func _on_description_meta_clicked(meta):
	if meta == "effect":
		var definition = description_label.get_meta("effect_definition")
		if definition:
			var context = {"effect_definition": definition.ability_definitions}
			var child_context = context.duplicate()
			child_context["source_view"] = self # Pass the window itself as the anchor
			WindowManager.open_child_inspection_window(self, &"EffectInspection", child_context)

func _on_description_meta_hover_started(_meta):
	description_label.mouse_filter = MOUSE_FILTER_STOP

func _on_description_meta_hover_ended(_meta):
	description_label.mouse_filter = MOUSE_FILTER_PASS

func get_location() -> LocationIdentifier:
	return _location

```