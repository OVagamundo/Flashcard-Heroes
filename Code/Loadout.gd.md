<!-- Original: Loadout.gd -->

```gdscript
extends Control

func _ready() -> void:
    $VBoxContainer/StartButton.pressed.connect(_on_start_button_pressed)

func _on_start_button_pressed() -> void:
    EventBus.change_scene_to_file_requested.emit("res://scenes/Main.tscn")

```