<!-- Original: scripts/SceneManager.gd -->

```gdscript
# res://scripts/SceneManager.gd
extends Node

## Manages all scene loading and transitions in response to SignalBus signals.

const SCENE_PATHS = {
	"Title": "res://scenes/Title.tscn",
	"Loadout": "res://scenes/Loadout.tscn",
	"Main": "res://scenes/Main.tscn",
	"PathChoiceContent": "res://scenes/PathChoice.tscn",
	"BattleContent": "res://scenes/Battle.tscn"
}

var current_scene: Node = null

func _ready() -> void:
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)

	SignalBus.title_scene_requested.connect(_on_title_scene_requested)
	SignalBus.loadout_scene_requested.connect(_on_loadout_scene_requested)
	SignalBus.main_scene_requested.connect(_on_main_scene_requested)

func _on_title_scene_requested() -> void:
	_change_scene_to(SCENE_PATHS["Title"])

func _on_loadout_scene_requested() -> void:
	_change_scene_to(SCENE_PATHS["Loadout"])

func _on_main_scene_requested() -> void:
	_change_scene_to(SCENE_PATHS["Main"])



func _load_content_scene(path: String) -> void:
	# Ensure Main is the active root; if not, switch to it first.
	if not is_instance_valid(current_scene) or current_scene.name != "Main":
		_change_scene_to(SCENE_PATHS["Main"])
		await get_tree().process_frame
	
	var holder_path := "VBoxContainer/ContentArea/SubViewport/MarginContainer"
	var holder: Node = current_scene.get_node(holder_path)
	if not is_instance_valid(holder):
		return
	# Clear old content
	for child in holder.get_children():
		child.queue_free()
	await get_tree().process_frame
	
	var res = load(path)
	if not res:
		return
	var inst = res.instantiate()
	holder.add_child(inst)
	
	# Optionally resize etc.
	
func _change_scene_to(path: String) -> void:
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		# Wait a frame to ensure the old scene is fully removed before adding the new one.
		await get_tree().process_frame

	var new_scene_res = load(path)
	if not new_scene_res:
		return
		
	current_scene = new_scene_res.instantiate()
	get_tree().root.add_child(current_scene)

```