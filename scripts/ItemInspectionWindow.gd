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
	# Ensure the window root receives clicks for local pruning
	mouse_filter = MOUSE_FILTER_STOP
	# Allow non-link clicks to bubble to the window root so it can prune children
	description_label.mouse_filter = MOUSE_FILTER_PASS
	# Keep gui_input connected but do not consume non-link clicks (see handler below)
	description_label.gui_input.connect(_on_description_gui_input)

	# Prune children when clicking anywhere on the window background area
	if is_instance_valid(internal_background):
		internal_background.mouse_filter = MOUSE_FILTER_STOP
		internal_background.gui_input.connect(_on_internal_background_gui_input)
func _gui_input(event: InputEvent):
	# Local background-click handling: prune only this window's descendants.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()





func populate(context: Dictionary):
	_source_view = context.get("source_view")
	_instance = context.get("instance")
	_location = context.get("location")

	if not is_instance_valid(_source_view) or not is_instance_valid(_instance):
		printerr("ItemInspectionWindow: Invalid context provided.")
		WindowManager.request_close_inspection_window(self, &"INVALID_CONTEXT")
		return

	var item_def = _instance.get_definition()
	if not is_instance_valid(item_def):
		WindowManager.request_close_inspection_window(self, &"INVALID_DEFINITION")
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
			# Open EffectInspection as a CHILD contextual window anchored to this window.
			# Provide context so WindowManager can pick the correct parent (e.g., UnitInspection).
			var parent_win: Control = WindowManager.find_ancestor_window_for_view(self)
			var parent_id: int = parent_win.get_instance_id() if is_instance_valid(parent_win) else -1
			var inside_unit: bool = parent_win is UnitInspectionWindow
			WindowManager.open_child_contextual_window(
				&"EffectInspection",
				self,
				{
					"effect_definition": definition.ability_definitions,
					"is_inside_unit_inspection": inside_unit,
					"target_parent_window_id": parent_id
				}
			)
			# Prevent this click from propagating as a WINDOW_BACKGROUND/global click
			get_viewport().set_input_as_handled()
			accept_event()

func _on_description_gui_input(event: InputEvent):
	# No-op: non-link clicks should bubble to the window root to trigger pruning.
	# Link clicks are handled in _on_description_meta_clicked and are consumed there.
	pass

func _on_internal_background_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()
		accept_event()

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
	# Defer briefly to allow UI to settle (e.g., during inventory reflow) before deciding to close.
	# This avoids premature self-closing that can bypass WindowManager suppression during actions.
	var self_ref = self
	await get_tree().create_timer(0.25).timeout
	if not is_instance_valid(self_ref) or not is_instance_valid(self):
		return
	# Try to re-establish a stable anchor from the current source view
	_setup_stable_anchor()
	if not is_instance_valid(_stable_anchor):
		WindowManager.request_close_inspection_window(self, &"ANCHOR_LOST_NO_STABLE")

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
