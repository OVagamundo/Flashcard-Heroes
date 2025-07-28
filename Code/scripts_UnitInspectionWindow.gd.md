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

var _inspected_unit_uuid: String
var _source_view: Control
var _instance: GachaBallInstance
var _location: LocationIdentifier
var _is_enemy_context: bool = false

func _ready():
	EventBus.battle_inventory_changed.connect(_on_inventory_changed)
	EventBus.unit_inventory_changed.connect(_on_unit_inventory_changed)
	EventBus.run_data_changed.connect(_on_inventory_changed)
	EventBus.unit_stats_changed.connect(_on_unit_stats_changed)
	description_label.meta_clicked.connect(_on_description_meta_clicked)
	description_label.mouse_filter = MOUSE_FILTER_PASS
	description_label.meta_hover_started.connect(_on_description_meta_hover_started)
	description_label.meta_hover_ended.connect(_on_description_meta_hover_ended)

func _exit_tree():
	if EventBus.is_connected("battle_inventory_changed", _on_inventory_changed):
		EventBus.battle_inventory_changed.disconnect(_on_inventory_changed)
	if EventBus.is_connected("unit_inventory_changed", _on_unit_inventory_changed):
		EventBus.unit_inventory_changed.disconnect(_on_unit_inventory_changed)
	if EventBus.is_connected("run_data_changed", _on_inventory_changed):
		EventBus.run_data_changed.disconnect(_on_inventory_changed)
	if EventBus.is_connected("unit_stats_changed", _on_unit_stats_changed):
		EventBus.unit_stats_changed.disconnect(_on_unit_stats_changed)

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		WindowManager.handle_inspection_background_click(self)
		EventBus.emit_signal("selection_clear_requested")
		get_viewport().set_input_as_handled()

# Fallback: if a child Control consumes the event before it reaches _gui_input,
# this unhandled_input ensures we still prune child windows when the user
# clicks anywhere inside the unit window background.
func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Only act if the click occurred inside this window's rect.
		if get_global_rect().has_point(event.position):
			WindowManager.handle_inspection_background_click(self)
			get_viewport().set_input_as_handled()

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

	name_label.text = tr(unit_definition.display_name_key)
	var description_text = tr(unit_definition.description_key)
	
	# Add basic attack description for units
	var basic_attack_desc = tr("ability.basic_attack.desc")
	# Replace (PWR) with the actual power value
	basic_attack_desc = basic_attack_desc.replace("(PWR)", str(_instance.current_pwr))
	
	_update_description()

	# --- Core UI Population Logic ---
	_rebuild_item_grid()


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

		var item_uuid = _instance.get_equipped_item_uuid(i)

		if not item_uuid.is_empty() and all_instances_db.has(item_uuid):
			var item_instance = all_instances_db[item_uuid]
			var gacha_view = _GachaBallView.instantiate()
			slot_view.add_child(gacha_view)
			# The GachaBallView gets the same location data as its parent slot.
			var is_interactive = not _is_enemy_context
			var single_click_inspect = _is_enemy_context
			gacha_view.populate(loc, item_instance, is_interactive, single_click_inspect)
	

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