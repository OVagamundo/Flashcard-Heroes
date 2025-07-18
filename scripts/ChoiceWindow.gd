# res://scripts/ChoiceWindow.gd
class_name ChoiceWindow
extends Control

const _GachaBallView = preload("res://scenes/GachaBallView.tscn")

@onready var merge_button: Button = %MergeButton
@onready var swap_button: Button = %SwapButton

var _source_location: LocationIdentifier
var _target_location: LocationIdentifier
var _recipe_id: StringName

func _ready():
	# Connect the SWAP button signal, as it's always available.
	# The MERGE button signal will be connected in populate() only if a valid recipe exists.
	swap_button.pressed.connect(func(): _on_choice_made(&"SWAP", &""))

func populate(context: Dictionary):
	_source_location = context.get("source_location")
	_target_location = context.get("target_location")
	_recipe_id = context.get("recipe_id")

	# MODIFIED: All button configuration logic is now here, inside populate().
	# This guarantees it runs AFTER the context data has been received.
	if _recipe_id:
		# A valid recipe exists. Enable the button and connect its signal.
		merge_button.disabled = false
		# Ensure we don't connect the signal multiple times if populate were ever called again.
		if not merge_button.is_connected("pressed", _on_merge_pressed):
			merge_button.pressed.connect(_on_merge_pressed)
	else:
		# No valid recipe. The button should be disabled.
		merge_button.disabled = true

func _on_merge_pressed():
	# This function is now a dedicated handler for the merge button press.
	_on_choice_made(&"MERGE", _recipe_id)

func _on_choice_made(choice: StringName, recipe_id: StringName):
	# The signature now matches the new, more robust EventBus signal.
	EventBus.emit_signal("choice_made", choice, _source_location, _target_location, recipe_id)
	EventBus.emit_signal("close_modal_requested")