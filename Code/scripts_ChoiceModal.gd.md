<!-- Original: scripts/ChoiceModal.gd -->

```gdscript
# res://scripts/ChoiceModal.gd
extends Control

@onready var merge_button: Button = %MergeButton
@onready var swap_button: Button = %SwapButton

func _ready():
	merge_button.pressed.connect(func(): _on_choice_made(&"MERGE"))
	swap_button.pressed.connect(func(): _on_choice_made(&"SWAP"))

func _on_choice_made(choice: StringName):
	EventBus.emit_signal("choice_made", choice)
	EventBus.emit_signal("close_modal_requested")
```