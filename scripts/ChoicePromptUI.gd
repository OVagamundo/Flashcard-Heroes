# res://scripts/ChoicePromptUI.gd
extends Control

@onready var merge_button: Button = %MergeButton
@onready var swap_button: Button = %SwapButton

func _ready():
	merge_button.pressed.connect(func(): _on_choice_made(&"MERGE"))
	swap_button.pressed.connect(func(): _on_choice_made(&"SWAP"))
	# BUGFIX: Removed the line 'EventBus.close_modal_requested.connect(self.queue_free)'.
	# The WindowManager is solely responsible for closing this window.

func _on_choice_made(choice: StringName):
	EventBus.emit_signal("choice_made", choice)
	# The choice has been made, so we can now request that the modal be closed.
	EventBus.emit_signal("close_modal_requested")
