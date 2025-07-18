<!-- Original: scripts/UnitInspectionWindow.gd -->

```gdscript
class_name UnitInspectionWindow
extends "res://scripts/InspectionWindow.gd"

const _GachaBallView = preload("res://scenes/GachaBallView.tscn")

@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var item_grid: GridContainer = %ItemGrid
@onready var item_grid_label: Label = %ItemGridLabel

var _inspected_unit_uuid: String
var _source_view: Control
var _instance: GachaBallInstance
var _location: LocationIdentifier

func _ready():
	EventBus.battle_inventory_changed.connect(_on_battle_inventory_changed)
	description_label.meta_clicked.connect(_on_description_meta_clicked)
	description_label.mouse_filter = MOUSE_FILTER_PASS
	description_label.meta_hover_started.connect(_on_description_meta_hover_started)
	description_label.meta_hover_ended.connect(_on_description_meta_hover_ended)

func _exit_tree():
	if EventBus.is_connected("battle_inventory_changed", _on_battle_inventory_changed):
		EventBus.battle_inventory_changed.disconnect(_on_battle_inventory_changed)

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()

func populate(context: Dictionary):
	_source_view = context.get("source_view")
	_instance = context.get("instance")
	_location = context.get("location")

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
	description_label.text = "%s\n\n[url=effect]EFFECTS[/url]" % description_text
	description_label.set_meta("definition", unit_definition)
	description_label.set_meta("effect_definition", unit_definition)

	for child in item_grid.get_children():
		child.queue_free()

	if unit_definition.item_slot_count == 0:
		item_grid_label.visible = false
		item_grid.visible = false
		return
	else:
		item_grid_label.visible = true
		item_grid.visible = true
		item_grid.columns = unit_definition.item_slot_count

	var equipped_items: Array[GachaBallInstance] = []
	if GameManager.is_in_battle:
		# TODO: Refactor with BattleManager helpers post-Phase 3
		var bm = get_tree().get_first_node_in_group("battle_manager")
		if is_instance_valid(bm):
			var all_instances_db = bm.get_all_instances()
			equipped_items = MergeManager._get_equipped_item_instances(_instance, all_instances_db)
	else:
		if is_instance_valid(GameManager.run_state):
			for item_uuid in _instance.equipped_item_uuids:
				var item_instance = GameManager.run_state.get_instance_by_uuid(item_uuid)
				if is_instance_valid(item_instance):
					equipped_items.append(item_instance)

	for i in range(unit_definition.item_slot_count):
		var item_instance = equipped_items[i] if i < equipped_items.size() else null

		if is_instance_valid(item_instance):
			var view = _GachaBallView.instantiate()
			item_grid.add_child(view)
			var loc = LocationIdentifier.new()
			loc.index = i
			loc.container = &"equipped_item"
			# This is crucial for the location to be complete
			loc.set("unit_uuid", _instance.ball_uuid) 
			view.populate(loc, item_instance, true, true)
		else:
			var placeholder = PanelContainer.new()
			placeholder.custom_minimum_size = Vector2(32, 32)
			var style = StyleBoxFlat.new()
			style.set_bg_color(Color(0, 0, 0, 0.4))
			style.set_border_width_all(1)
			style.set_border_color(Color(0.5, 0.5, 0.5, 0.8))
			placeholder.add_theme_stylebox_override("panel", style)
			item_grid.add_child(placeholder)

func _on_battle_inventory_changed():
	if self.visible and not _inspected_unit_uuid.is_empty():
		var current_location = _find_location_for_uuid(_inspected_unit_uuid)
		if is_instance_valid(current_location):
			populate({"source_location": current_location})
		else:
			queue_free()

func _find_location_for_uuid(uuid: String) -> LocationIdentifier:
	var battle_manager = get_tree().get_first_node_in_group("battle_manager")
	if not is_instance_valid(battle_manager):
		return null

	var all_board_data = (
		battle_manager.get_container(&"PlayerLineup").get_all_uuids() + battle_manager.get_container(&"PlayerBench").get_all_uuids() + battle_manager.get_container(&"ItemInventory").get_all_uuids()
	)
	for instance in all_board_data:
		if is_instance_valid(instance) and instance.ball_uuid == uuid and instance.has_meta("location"):
			return instance.get_meta("location") as LocationIdentifier
	return null

func _on_description_meta_clicked(meta):
	if meta == "effect":
		var definition = description_label.get_meta("effect_definition")
		if definition:
			var context = {"effect_definition": definition.ability_definitions}
			var child_context = context.duplicate()
			child_context["source_view"] = _source_view
			WindowManager.open_child_inspection_window(self, &"EffectInspection", child_context)

func _on_description_meta_hover_started(_meta):
	description_label.mouse_filter = MOUSE_FILTER_STOP

func _on_description_meta_hover_ended(_meta):
	description_label.mouse_filter = MOUSE_FILTER_PASS

```