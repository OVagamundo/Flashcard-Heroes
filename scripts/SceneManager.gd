extends Node

# Scene management for UI navigation
var _current_scene: Node

func _ready() -> void:
	# Connect to both types of scene transition signals
	EventBus.change_scene_to_file_requested.connect(_on_change_scene_to_file_requested)
	EventBus.load_scene_in_container_requested.connect(_on_load_scene_in_container_requested)
	
	# Store reference to current scene for full transitions
	_current_scene = get_tree().current_scene

# Handle full scene transitions (e.g., Title -> Main)
func _on_change_scene_to_file_requested(scene_path: String) -> void:
	# Clean up current scene
	if _current_scene:
		_current_scene.queue_free()
	
	# Load and show new scene
	var scene = load(scene_path)
	if scene:
		_current_scene = scene.instantiate()
		get_tree().root.add_child(_current_scene)
		get_tree().current_scene = _current_scene

# Handle loading scenes into containers (e.g., dynamic content in Main)
func _on_load_scene_in_container_requested(scene_path: String, container: Node) -> void:
	# Clear existing children from container
	for child in container.get_children():
		child.queue_free()
	
	# Load and add new scene to container
	var scene = load(scene_path)
	if scene:
		var instance = scene.instantiate()
		container.add_child(instance)
