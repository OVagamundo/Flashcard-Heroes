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
	SignalBus.battle_inventory_changed.connect(_on_inventory_changed)
	SignalBus.unit_inventory_changed.connect(_on_unit_inventory_changed)
	SignalBus.run_data_changed.connect(_on_inventory_changed)
	SignalBus.unit_stats_changed.connect(_on_unit_stats_changed)
	description_label.meta_clicked.connect(_on_description_meta_clicked)
	# Ensure the window root receives clicks for local pruning
	mouse_filter = MOUSE_FILTER_STOP
	# Allow non-link clicks on the description to bubble to the window root
	# Hover handlers below will set STOP only while over UI links
	description_label.mouse_filter = MOUSE_FILTER_PASS

	# Prune children when clicking anywhere on the window background area
	if is_instance_valid(internal_background):
		internal_background.mouse_filter = MOUSE_FILTER_STOP
		internal_background.gui_input.connect(_on_internal_background_gui_input)

	# Also treat clicks on the item grid (empty slots area) as background for pruning
	if is_instance_valid(item_grid):
		item_grid.mouse_filter = MOUSE_FILTER_STOP
		item_grid.gui_input.connect(_on_item_grid_gui_input)

	# Configure child controls to allow bubbling so the root can prune children on generic clicks
	_configure_mouse_filters()

func _exit_tree():
	if SignalBus.is_connected("battle_inventory_changed", _on_inventory_changed):
		SignalBus.battle_inventory_changed.disconnect(_on_inventory_changed)
	if SignalBus.is_connected("unit_inventory_changed", _on_unit_inventory_changed):
		SignalBus.unit_inventory_changed.disconnect(_on_unit_inventory_changed)
	if SignalBus.is_connected("run_data_changed", _on_inventory_changed):
		SignalBus.run_data_changed.disconnect(_on_inventory_changed)
	if SignalBus.is_connected("unit_stats_changed", _on_unit_stats_changed):
		SignalBus.unit_stats_changed.disconnect(_on_unit_stats_changed)

func _gui_input(event: InputEvent):
	# Local background-click handling: prune only this window's descendants.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()

func populate(context: Dictionary):
	_source_view = context.get("source_view")
	_instance = context.get("instance")
	_location = context.get("location")
	_is_enemy_context = context.get("is_enemy_context", false)

	if not is_instance_valid(_source_view) or not is_instance_valid(_instance):
		WindowManager.request_close_inspection_window(self, &"INVALID_CONTEXT")
		return

	var unit_definition = _instance.get_definition()
	if not is_instance_valid(unit_definition):
		WindowManager.request_close_inspection_window(self, &"INVALID_DEFINITION")
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
	# Defer briefly to allow UI to settle (e.g., during inventory reflow) before deciding to close.
	# This avoids premature self-closing that bypasses WindowManager suppression during actions.
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
		WindowManager.request_close_inspection_window(self, &"INSTANCE_MISSING_AFTER_INVENTORY_CHANGE")
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
		WindowManager.request_close_inspection_window(self, &"INSTANCE_MISSING_AFTER_UNIT_INV_CHANGE")
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
			# Ensure EffectInspection uses the Unit window as its parent when inside unit inspection.
			var parent_win: Control = WindowManager.find_ancestor_window_for_view(self)
			var parent_id: int = parent_win.get_instance_id() if is_instance_valid(parent_win) else -1
			WindowManager.open_child_contextual_window(
				&"EffectInspection",
				self,
				{
					"effect_definition": definition.ability_definitions,
					"is_inside_unit_inspection": true,
					"target_parent_window_id": parent_id
				}
			)
			# Prevent this click from propagating as a WINDOW_BACKGROUND/global click
			get_viewport().set_input_as_handled()
			accept_event()

## Recursively set mouse filters to PASS for child controls that should bubble to the root
func _configure_mouse_filters():
	var stack: Array = [self]
	while not stack.is_empty():
		var node = stack.pop_back()
		for child in node.get_children():
			if child is Control:
				# Skip nodes that have explicit handlers or must remain STOP
				if child == internal_background or child == item_grid or child == description_label:
					pass
				else:
					(child as Control).mouse_filter = MOUSE_FILTER_PASS
				stack.append(child)

func _on_description_gui_input(event: InputEvent):
	# No-op: we rely on meta hover/click to manage link interactions.
	pass

func _on_internal_background_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()
		accept_event()

func _on_item_grid_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()
		accept_event()

func _on_description_meta_hover_started(_meta):
	description_label.mouse_filter = MOUSE_FILTER_STOP

func _on_description_meta_hover_ended(_meta):
	description_label.mouse_filter = MOUSE_FILTER_PASS

func get_location() -> LocationIdentifier:
	return _location
