<!-- Original: scripts/DiscardPileModal.gd -->

```gdscript
# res://scripts/DiscardPileModal.gd
extends Control

const GACHA_BALL_VIEW_SCENE = preload("res://scenes/GachaBallView.tscn")

@onready var discard_grid: GridContainer = %DiscardGrid

func _ready():
	# TDD Compliance: This modal uses the standard BackgroundBlocker,
	# so no special detection logic is needed here.
	pass

func populate(context: Dictionary):
	var discard_pile_data = context.get("discard_pile", [])
	
	for child in discard_grid.get_children():
		child.queue_free()
		
	for instance_data in discard_pile_data:
		if is_instance_valid(instance_data):
			var view = GACHA_BALL_VIEW_SCENE.instantiate()
			discard_grid.add_child(view)
			view.set_instance_data(instance_data)
			# TDD: Items in the discard pile are for inspection only, not interaction.
			view.is_selectable = false

```