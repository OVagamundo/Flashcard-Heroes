# res://scripts/SceneManager.gd
extends Node

## Manages all scene loading and transitions in response to SignalBus signals.

const SCENE_PATHS: Dictionary = {
	"Title": "res://scenes/Title.tscn",
	"Loadout": "res://scenes/Loadout.tscn",
	"Main": "res://scenes/Main.tscn"
}


var current_scene: Node = null

func _ready() -> void:
	# INITIALIZE AUDIO MANAGER EARLY (before any scenes)
	# This ensures it exists for Title/Loadout which run before Main.gd
	if not get_tree().has_group("audio_manager"):
		var audio_manager: Node = preload("res://scripts/AudioManager.gd").new()
		audio_manager.name = "AudioManager"
		add_child(audio_manager)
		audio_manager.add_to_group("audio_manager")
	
	var root: Window = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)

	SignalBus.title_scene_requested.connect(_on_title_scene_requested)
	SignalBus.loadout_scene_requested.connect(_on_loadout_scene_requested)
	SignalBus.main_scene_requested.connect(_on_main_scene_requested)
	
	# GLOBAL BUTTON HOVER SOUNDS: Connect to node_added to hook all buttons
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is Button:
		var button := node as Button
		if not button.mouse_entered.is_connected(_on_button_hovered):
			button.mouse_entered.connect(_on_button_hovered)
		if not button.focus_entered.is_connected(_on_button_hovered):
			button.focus_entered.connect(_on_button_hovered)

func _on_button_hovered() -> void:
	Audio.play_sfx("ui_hover")


func _on_title_scene_requested() -> void:
	_change_scene_to(SCENE_PATHS["Title"])

func _on_loadout_scene_requested() -> void:
	_change_scene_to(SCENE_PATHS["Loadout"])

func _on_main_scene_requested() -> void:
	_change_scene_to(SCENE_PATHS["Main"])


func _change_scene_to(path: String) -> void:
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		# Wait a frame to ensure the old scene is fully removed before adding the new one.
		await get_tree().process_frame

	var new_scene_res: PackedScene = load(path) as PackedScene
	assert(new_scene_res != null, "SceneManager: Failed to load scene at %s" % path)
		
	current_scene = new_scene_res.instantiate()
	get_tree().root.add_child(current_scene)
	get_tree().current_scene = current_scene
	if ActionQueue.is_busy():
		ActionQueue.finish_action(ActionQueue.get_active_action())
