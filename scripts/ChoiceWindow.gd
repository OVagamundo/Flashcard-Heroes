class_name ChoiceWindow
extends Control

const LocationIdentifier = preload("res://scripts/LocationIdentifier.gd")

@onready var merge_button: Button = %MergeButton
@onready var swap_button: Button = %SwapButton

var _source_location: LocationIdentifier
var _target_location: LocationIdentifier

func populate(context: Dictionary):
	_source_location = context.get("source_location")
	_target_location = context.get("target_location")

func _ready():
	merge_button.pressed.connect(func(): _on_choice_made(&"MERGE", _source_location, _target_location))
	swap_button.pressed.connect(func(): _on_choice_made(&"SWAP", _source_location, _target_location))

func _on_choice_made(choice: StringName, source_location: LocationIdentifier, target_location: LocationIdentifier):
	EventBus.emit_signal("choice_made", choice, source_location, target_location)
	EventBus.emit_signal("close_modal_requested")
