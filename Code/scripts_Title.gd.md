<!-- Original: scripts/Title.gd -->

```gdscript
# res://scripts/Title.gd
extends Control

@onready var start_run_button: Button = %StartRunButton

func _ready():
	# The Title screen should now transition to the Loadout scene, not start a run directly.
	start_run_button.pressed.connect(func(): EventBus.emit_signal("loadout_scene_requested"))

```