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

# Track connected buttons to avoid duplicate connections
var _connected_buttons: Dictionary = {}

func _ready() -> void:
	# INITIALIZE AUDIO MANAGER EARLY (before any scenes)
	# This ensures it exists for Title/Loadout which run before Main.gd
	if not get_tree().has_group("audio_manager"):
		var audio_manager = preload("res://scripts/AudioManager.gd").new()
		audio_manager.name = "AudioManager"
		add_child(audio_manager)
		audio_manager.add_to_group("audio_manager")
	
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)

	SignalBus.title_scene_requested.connect(_on_title_scene_requested)
	SignalBus.loadout_scene_requested.connect(_on_loadout_scene_requested)
	SignalBus.main_scene_requested.connect(_on_main_scene_requested)
	
	# GLOBAL BUTTON HOVER SOUNDS: Connect to node_added to hook all buttons
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	"""Hook into all buttons for hover/focus sounds"""
	if node is Button and not _connected_buttons.has(node.get_instance_id()):
		node.mouse_entered.connect(_on_button_hovered)
		node.focus_entered.connect(_on_button_hovered)
		# Clean up tracking when button is freed
		node.tree_exited.connect(_on_button_freed.bind(node.get_instance_id()))
		_connected_buttons[node.get_instance_id()] = true

func _on_button_hovered() -> void:
	"""Play hover sound for buttons"""
	Audio.play_sfx("ui_hover")

func _on_button_freed(instance_id: int) -> void:
	"""Clean up tracking when button is freed"""
	_connected_buttons.erase(instance_id)


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
	
	var holder: Node = current_scene.get_node_or_null("%SceneSlot")
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
