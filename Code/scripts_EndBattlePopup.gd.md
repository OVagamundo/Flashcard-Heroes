<!-- Original: scripts/EndBattlePopup.gd -->

```gdscript
# res://scripts/EndBattlePopup.gd
extends Control
class_name EndBattlePopup

@onready var title_label: Label = %TitleLabel
@onready var return_button: Button = %ReturnButton

func _ready():
    return_button.pressed.connect(_on_return_button_pressed)

func populate(is_victory: bool):
    if is_victory:
        title_label.text = "VICTORY!"
        return_button.text = "Continue"
    else:
        title_label.text = "DEFEAT"
        return_button.text = "Return to Title"

func _on_return_button_pressed():
    # This will eventually lead back to the path choice / map screen.
    # For now, it correctly returns to the title screen.
    EventBus.emit_signal("title_scene_requested")

```