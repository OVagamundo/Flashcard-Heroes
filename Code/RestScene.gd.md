<!-- Original: RestScene.gd -->

```gdscript
extends VBoxContainer

@onready var back_button = $BackButton

func _ready():
	back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed():
	# Load PathOptions into the same container as this scene
	EventBus.load_scene_in_container_requested.emit(
		"res://scenes/PathOptions.tscn",
		get_parent()
	)

```