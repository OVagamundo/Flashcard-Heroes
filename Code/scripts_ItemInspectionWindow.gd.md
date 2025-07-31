<!-- Original: scripts/ItemInspectionWindow.gd -->

```gdscript
class_name ItemInspectionWindow
extends "res://scripts/InspectionWindow.gd"

@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var internal_background: ColorRect = $InternalBackground

var _source_view: Control
var _instance: GachaBallInstance
var _location: LocationIdentifier
var _window_group_id: int = 1  # Inspection window group
var _stable_anchor: Control = null  # Stable anchor for positioning

func _ready():
	description_label.meta_clicked.connect(_on_description_meta_clicked)
	# Allow clicks on the description area to propagate to the root window so
	# WindowManager can register background clicks. Identical behaviour to
	# UnitInspectionWindow.
	description_label.mouse_filter = MOUSE_FILTER_PASS
	description_label.meta_hover_started.connect(func(_m): description_label.mouse_filter = MOUSE_FILTER_STOP)
	description_label.meta_hover_ended.connect(func(_m): description_label.mouse_filter = MOUSE_FILTER_PASS)
	internal_background.gui_input.connect(_on_internal_background_clicked)

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

	if not is_instance_valid(_source_view) or not is_instance_valid(_instance):
		printerr("ItemInspectionWindow: Invalid context provided.")
		queue_free()
		return

	var item_def = _instance.get_definition()
	if not is_instance_valid(item_def):
		queue_free()
		return

	# Set up stable anchor pattern
	_setup_stable_anchor()

	name_label.text = tr(item_def.display_name_key)
	var description_text = tr(item_def.description_key)
	
	# Add item effect description
	var effect_desc = ""
	if item_def.bonus_hp > 0 and item_def.bonus_pwr > 0:
		effect_desc = tr("item.effect.both").replace("(HP)", str(item_def.bonus_hp)).replace("(PWR)", str(item_def.bonus_pwr))
	elif item_def.bonus_hp > 0:
		effect_desc = tr("item.effect.hp").replace("(HP)", str(item_def.bonus_hp))
	elif item_def.bonus_pwr > 0:
		effect_desc = tr("item.effect.pwr").replace("(PWR)", str(item_def.bonus_pwr))
	
	if not effect_desc.is_empty():
		description_label.text = "%s\n\n%s\n\n[url=effect]EFFECTS[/url]" % [description_text, effect_desc]
	else:
		description_label.text = "%s\n\n[url=effect]EFFECTS[/url]" % description_text
	
	# Store the full definition for the child window to use.
	description_label.set_meta("effect_definition", item_def)

func _on_description_meta_clicked(meta):
	if meta == "effect":
		var definition = description_label.get_meta("effect_definition")
		if definition:
			var context = {"effect_definition": definition.ability_definitions}
			# --- THIS IS THE LINE TO CHANGE ---
			# The source_view for a child window is the parent window itself.
			var child_context = context.duplicate()
			child_context["source_view"] = self
			# --- END OF CHANGE ---
			WindowManager.open_child_inspection_window(self, &"EffectInspection", child_context)

func get_location() -> LocationIdentifier:
	return _location

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

```