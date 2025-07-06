# res://scripts/DiscardPileModal.gd
extends Control

# NOTE: We have removed the const preload from the top of the script.

@onready var discard_grid: GridContainer = %DiscardGrid

func _ready():
	# TDD Compliance: This modal uses the standard BackgroundBlocker,
	# so no special detection logic is needed here.
	pass

func populate(context: Dictionary):
	# FIX: Load the scene at runtime instead of preloading.
	var gacha_ball_view_scene = load("res://scenes/GachaBallView.tscn")

	var discard_pile_data = context.get("discard_pile", [])
	
	for child in discard_grid.get_children():
		child.queue_free()
		
	for instance_data in discard_pile_data:
		if is_instance_valid(instance_data):
			var view = gacha_ball_view_scene.instantiate()
			discard_grid.add_child(view)
			view.set_instance_data(instance_data)
			# TDD: Items in the discard pile are for inspection only, not interaction.
			view.is_selectable = false
