<!-- Original: scripts/ChoicePromptUI.gd -->

```gdscript
# res://scripts/ChoicePromptUI.gd
extends Control

@onready var merge_button: Button = %MergeButton
@onready var swap_button: Button = %SwapButton

func _ready():
    merge_button.pressed.connect(func(): _on_choice_made(&"MERGE"))
    swap_button.pressed.connect(func(): _on_choice_made(&"SWAP"))
    # This modal can also be closed, which cancels the action.
    EventBus.close_modal_requested.connect(queue_free)

func _on_choice_made(choice: StringName):
    EventBus.emit_signal("choice_made", choice)
    queue_free()

```