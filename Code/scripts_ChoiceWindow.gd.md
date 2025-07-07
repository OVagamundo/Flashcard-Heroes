<!-- Original: scripts/ChoiceWindow.gd -->

```gdscript
# res://scripts/ChoiceWindow.gd
class_name ChoiceWindow
extends Control

@onready var merge_button: Button = %MergeButton
@onready var swap_button: Button = %SwapButton

func _ready():
	merge_button.pressed.connect(func(): _on_choice_made(&"MERGE"))
	swap_button.pressed.connect(func(): _on_choice_made(&"SWAP"))
	# REFACTOR: Removed connection to close_modal_requested.
	# The WindowManager is solely responsible for closing this window.
	# This script's only job is to report the choice that was made.

func _on_choice_made(choice: StringName):
	EventBus.emit_signal("choice_made", choice)
	# The choice has been made. Request that the modal be closed.
	# The WindowManager will hear this and perform the action.
	EventBus.emit_signal("close_modal_requested")

```