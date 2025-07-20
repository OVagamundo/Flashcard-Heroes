class_name DiscardPileWindow
extends Control

const _GachaBallView = preload("res://scenes/GachaBallView.tscn")
const _SlotView = preload("res://scenes/SlotView.tscn")

@onready var discard_grid: GridContainer = %DiscardGrid
@onready var panel_container: PanelContainer = %PanelContainer

const DISCARD_PILE_CONTAINER_TAG = &"DiscardPile"

func _ready():
	panel_container.gui_input.connect(_on_panel_gui_input)

func _on_panel_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		WindowManager.close_all_inspection_windows()
		get_viewport().set_input_as_handled()

func populate(context: Dictionary):
	var discard_pile_data = context.get("inventory", [])
	
	for child in discard_grid.get_children():
		child.queue_free()
		
	for i in range(discard_pile_data.size()):
		var instance = discard_pile_data[i]
		
		var loc = LocationIdentifier.new()
		loc.index = i
		loc.container = DISCARD_PILE_CONTAINER_TAG

		if is_instance_valid(instance):
			# Create a SlotView to wrap the GachaBallView, similar to InventoryWindow
			var slot_view = _SlotView.instantiate()
			discard_grid.add_child(slot_view)
			slot_view.populate(loc)
			
			var gacha_view = _GachaBallView.instantiate()
			slot_view.add_child(gacha_view)
			gacha_view.populate(loc, instance, true, true)
		else:
			var slot_view = _SlotView.instantiate()
			discard_grid.add_child(slot_view)
			slot_view.populate(loc)
