class_name DiscardPileWindow
extends Control

const LocationIdentifier = preload("res://scripts/LocationIdentifier.gd")
const _GachaBallView = preload("res://scenes/GachaBallView.tscn")

@onready var discard_grid: GridContainer = %DiscardGrid
@onready var panel_container: PanelContainer = %PanelContainer

const DISCARD_PILE_CONTAINER_TAG = &"DISCARD_PILE"

func _ready():
	panel_container.gui_input.connect(_on_panel_gui_input)

func _on_panel_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		WindowManager.close_all_inspection_windows()
		get_viewport().set_input_as_handled()

func populate(context: Dictionary):
	var discard_pile_data = context.get("discard_pile", [])
	
	for child in discard_grid.get_children():
		child.queue_free()
		
	for i in range(discard_pile_data.size()):
		var instance_data = discard_pile_data[i]
		if is_instance_valid(instance_data):
			var view = _GachaBallView.instantiate()
			discard_grid.add_child(view)
			var loc = LocationIdentifier.new()
			loc.tier = 0 # Discard pile doesn't use tiers
			loc.index = i
			loc.container = DISCARD_PILE_CONTAINER_TAG
			view.populate(loc, instance_data, false)
