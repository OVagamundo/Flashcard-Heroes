<!-- Original: scripts/DiscardPileModal.gd -->

```gdscript
# res://scripts/DiscardPileModal.gd
extends Control

const GACHA_BALL_VIEW_SCENE = preload("res://scenes/GachaBallView.tscn")

@onready var discard_grid: GridContainer = %DiscardGrid

func _ready():
	EventBus.close_modal_requested.connect(queue_free)

func populate(context: Dictionary):
	var discard_pile_data = context.get("discard_pile", [])
	
	for child in discard_grid.get_children():
		child.queue_free()
		
	for instance_data in discard_pile_data:
		var view = GACHA_BALL_VIEW_SCENE.instantiate()
		discard_grid.add_child(view)
		view.set_instance_data(instance_data)
		# Items in the discard pile view cannot be interacted with.
		view.is_interactable = false
```