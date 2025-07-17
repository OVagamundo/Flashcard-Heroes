<!-- Original: scripts/Title.gd -->

```gdscript
# res://scripts/Title.gd
extends Control

@onready var start_run_button: Button = %StartRunButton

func _ready():
	start_run_button.pressed.connect(func(): EventBus.emit_signal("start_run_requested"))


```