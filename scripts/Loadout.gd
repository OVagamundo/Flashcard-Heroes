# res://scripts/Loadout.gd
extends Control
class_name Loadout

func _ready() -> void:
	var begin_button: Button = $CenterContainer/BeginButton
	if begin_button:
		# Connect the signal directly. Manual disconnection in _exit_tree is
		# unnecessary and was causing a crash. Godot handles this automatically.
		begin_button.pressed.connect(
			_on_begin_button_pressed,
			CONNECT_DEFERRED
		)
	else:
		printerr("FATAL: Could not find BeginButton in Loadout.tscn. The scene may be corrupt.")

func _on_begin_button_pressed() -> void:
	EventBus.emit_signal("main_scene_requested")
