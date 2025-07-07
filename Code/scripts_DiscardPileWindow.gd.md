<!-- Original: scripts/DiscardPileWindow.gd -->

```gdscript
# res://scripts/DiscardPileWindow.gd
class_name DiscardPileWindow
extends Control

@onready var discard_grid: GridContainer = %DiscardGrid
@onready var panel_container: PanelContainer = %PanelContainer

func _ready():
	# Connect the panel's input signal to our new handler.
	panel_container.gui_input.connect(_on_panel_gui_input)

func _on_panel_gui_input(event: InputEvent):
	# If a click reaches this panel, it means it wasn't on an item view.
	# This is a click on the modal's own "background".
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Tell the global manager to close any open inspection windows.
		WindowManager.close_all_inspection_windows()
		# Consume the input so it doesn't also trigger the BackgroundBlocker behind this panel.
		get_viewport().set_input_as_handled()

func populate(context: Dictionary):
	var gacha_ball_view_scene = load("res://scenes/GachaBallView.tscn")
	var discard_pile_data = context.get("discard_pile", [])
	
	for child in discard_grid.get_children():
		child.queue_free()
		
	for instance_data in discard_pile_data:
		if is_instance_valid(instance_data):
			var view = gacha_ball_view_scene.instantiate()
			discard_grid.add_child(view)
			view.set_instance_data(instance_data)
			view.is_selectable = false

```