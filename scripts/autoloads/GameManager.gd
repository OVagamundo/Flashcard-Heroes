extends Node

# Game state signals
signal scene_changed(scene_path: String)
signal game_paused()
signal game_resumed()

# Scene paths
const SCENES = {
	"title": "res://scenes/screens/TitleScreen.tscn",
	"path_choice": "res://scenes/screens/PathChoiceScreen.tscn",
	"battle": "res://scenes/core/battle/BattleScreen.tscn",
	"game_over": "res://scenes/screens/GameOverScreen.tscn"
}

var current_scene: Node = null
var is_paused: bool = false

func _ready() -> void:
	# Set as the root node
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)

# Change scenes with optional transition effects
func change_scene(scene_key: String, transition_data: Variant = null) -> void:
	var scene_path = SCENES.get(scene_key, "")
	if scene_path.is_empty():
		push_error("Invalid scene key: " + scene_key)
		return
	
	# Load the next scene
	var loader = ResourceLoader.load_threaded_request(scene_path)
	if loader == null:
		push_error("Failed to load scene: " + scene_path)
		return
	
	# Wait for the loader to finish
	var scene = ResourceLoader.load_threaded_get(scene_path)
	if not scene:
		push_error("Failed to get loaded scene: " + scene_path)
		return
	
	# Replace current scene
	call_deferred("_deferred_change_scene", scene, transition_data)

# Internal function to handle scene change
@export_file("*.tscn") var initial_scene: String = ""

func _deferred_change_scene(scene: PackedScene, _transition_data: Variant) -> void:
	# Free current scene
	if current_scene:
		current_scene.queue_free()
	
	# Instance new scene
	var new_scene = scene.instantiate()
	
	# Add it to the active scene as a child of root
	get_tree().root.add_child(new_scene)
	
	# Set as current scene
	current_scene = new_scene
	
	# Emit signal
	emit_signal("scene_changed", scene.resource_path)

# Pause/Resume game
func set_pause(p_paused: bool) -> void:
	is_paused = p_paused
	get_tree().paused = p_paused
	if p_paused:
		emit_signal("game_paused")
	else:
		emit_signal("game_resumed")

func toggle_pause() -> void:
	set_pause(not is_paused)
