<!-- Original: scripts/EndBattlePopup.gd -->

```gdscript
# res://scripts/EndBattlePopup.gd
extends Control
class_name EndBattlePopup

@onready var title_label: Label = %TitleLabel
@onready var return_button: Button = %ReturnButton

var _is_victory: bool = false

func _ready():
    return_button.pressed.connect(_on_return_button_pressed)

func populate(is_victory: bool):
    _is_victory = is_victory
    if is_victory:
        title_label.text = "VICTORY!"
        return_button.text = "Continue"
    else:
        title_label.text = "DEFEAT"
        return_button.text = "Return to Title"

func _on_return_button_pressed():
    if _is_victory:
        # Correctly returns to the main scene which shows the path choice.
        EventBus.emit_signal("main_scene_requested")
    else:
        # On defeat, returning to the title screen is correct.
        EventBus.emit_signal("title_scene_requested")
    
    # Close the popup itself.
    queue_free()

```