# res://scripts/SceneManager.gd
extends Node

## Manages all scene loading and transitions in response to EventBus signals.

var scene_paths: Dictionary = {
	"Title": "res://scenes/Title.tscn",
	"Loadout": "res://scenes/Loadout.tscn",
	"Main": "res://scenes/Main.tscn"
}
var current_scene: Node = null

func _ready() -> void:
	# Note: In Godot 4, direct connection syntax is preferred.
	EventBus.loadout_scene_requested.connect(_on_loadout_scene_requested)
	EventBus.main_scene_requested.connect(_on_main_scene_requested)
	
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)

func _on_loadout_scene_requested() -> void:
	_change_scene_to(scene_paths["Loadout"])

func _on_main_scene_requested() -> void:
	_change_scene_to(scene_paths["Main"])

func _change_scene_to(path: String) -> void:
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		
	var new_scene_res = load(path)
	if not new_scene_res:
		printerr("SceneManager: Failed to load scene at path: ", path)
		return
		
	current_scene = new_scene_res.instantiate()
	get_tree().root.add_child(current_scene)
