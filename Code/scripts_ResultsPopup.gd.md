<!-- Original: scripts/ResultsPopup.gd -->

```gdscript
# res://scripts/ResultsPopup.gd
extends Control

## A modal popup used to display the outcome of an event, like the flashcard mini-game.
## TDD Section 4.1: ResultsPopup.gd

signal results_acknowledged

@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var confirm_button: Button = %ConfirmButton

func _ready():
	confirm_button.pressed.connect(_on_confirm_pressed)

func populate(context: Dictionary) -> void:
	"""Populates the popup with the given content"""
	var populate_args = context.get("populate_args", ["", "", ""])
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
	EventBus.emit_signal("results_acknowledged")
	queue_free() 
```