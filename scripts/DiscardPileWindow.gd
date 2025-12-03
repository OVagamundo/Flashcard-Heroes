class_name DiscardPileWindow
extends Control

const _GachaBallView = preload("res://scenes/GachaBallView.tscn")
const _SlotView = preload("res://scenes/SlotView.tscn")

@onready var discard_grid: GridContainer = %DiscardGrid
@onready var panel_container: PanelContainer = %PanelContainer

const DISCARD_PILE_CONTAINER_TAG = &"DiscardPile"

func _ready() -> void:
	panel_container.gui_input.connect(_on_panel_gui_input)

func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Prune only child inspection windows of this window to avoid global closures
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()

func populate(context: Dictionary) -> void:
	var discard_pile_data: Array = context.get("inventory", [])
	
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
			# Discard pile is inspection-only: disable selection/drag
			slot_view.set_interaction_context(&"INSPECTION_ONLY", 1)
			
			# Use adapter to create visual data
			var visual_data = VisualDataAdapter.create_visual_data(instance)
			slot_view.set_content(visual_data, true, true, false)
			
			# Enforce inspection-only behavior
			if slot_view.get_child_count() > 0:
				var gacha_view = slot_view.get_child(0)
				if gacha_view is GachaBallView:
					gacha_view.set_is_interactive(false)
					gacha_view.set_interaction_context(&"INSPECTION_ONLY", instance.get_definition().category, 1)
		else:
			var slot_view = _SlotView.instantiate()
			discard_grid.add_child(slot_view)
			slot_view.populate(loc)
			# Empty slots in discard pile are also inspection-only
			slot_view.set_interaction_context(&"INSPECTION_ONLY", 1)
