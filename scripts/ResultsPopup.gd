# res://scripts/ResultsPopup.gd
extends Control

## A modal popup used to display the outcome of an event, like the flashcard mini-game.
## TDD Section 4.1: ResultsPopup.gd

signal results_acknowledged

@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var confirm_button: Button = %ConfirmButton

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)

func populate(context: Dictionary) -> void:
	"""Populates the popup with the given content"""
	# Coerce any untyped Array in context to Array[String] to satisfy strict typing
	var raw_args: Variant = context.get("populate_args", null)
	var populate_args: Array[String] = []
	if raw_args is Array:
		for v in raw_args:
			populate_args.append(String(v))
	
	if populate_args.size() >= 3:
		title_label.text = populate_args[0]
		message_label.text = populate_args[1]
		confirm_button.text = populate_args[2]
	else:
		title_label.text = context.get("title", "")
		message_label.text = context.get("message", "")
		confirm_button.text = context.get("button_text", "OK")

func _on_confirm_pressed() -> void:
	"""Handles confirm button press"""
	SignalBus.emit_signal("results_acknowledged")
	queue_free()

func get_window_to_animate() -> Control:
	return $CenterContainer/PanelContainer
