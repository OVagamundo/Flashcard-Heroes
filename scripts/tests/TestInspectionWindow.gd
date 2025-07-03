# res://scripts/tests/TestInspectionWindow.gd
extends PanelContainer
class_name TestInspectionWindow

signal background_clicked(window: Control)

const TEST_ITEM_VIEW_SCENE = preload("res://scenes/tests/TestItemView.tscn")

@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel
@onready var item_grid: GridContainer = %ItemGrid
@onready var equipped_items_label: Label = %EquippedItemsLabel

var _test_window_manager: Node

func _gui_input(event: InputEvent):
	# This detects a click on the panel's background (not on a child control).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		emit_signal("background_clicked", self)
		# Consume input to stop it from being a "global" background click.
		get_viewport().set_input_as_handled()

func populate(item_data: Dictionary, test_window_manager: Node):
	_test_window_manager = test_window_manager
	name_label.text = item_data.get("name", "N/A")
	description_label.text = item_data.get("desc", "")
	
	var child_items = item_data.get("children", [])
	
	for child in item_grid.get_children():
		child.queue_free()
		
	if child_items.is_empty():
		equipped_items_label.visible = false
		item_grid.visible = false
		return
	
	equipped_items_label.visible = true
	item_grid.visible = true
	
	for child_data in child_items:
		var view = TEST_ITEM_VIEW_SCENE.instantiate()
		item_grid.add_child(view)
		view.initialize(child_data)
		# Child views inside an inspection window are inspect-only, not selectable.
		view.is_selectable = false
