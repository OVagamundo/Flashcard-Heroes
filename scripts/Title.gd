extends Control

func _ready() -> void:
	$VBoxContainer/NewGameButton.pressed.connect(_on_new_game_pressed)

func _on_new_game_pressed() -> void:
	EventBus.change_scene_to_file_requested.emit("res://scenes/Loadout.tscn")
