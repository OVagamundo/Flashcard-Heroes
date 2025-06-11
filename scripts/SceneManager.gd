extends Node

var _current_scene: Node

func _ready() -> void:
    EventBus.change_scene_to_file_requested.connect(_on_change_scene_to_file_requested)
    EventBus.load_scene_in_container_requested.connect(_on_load_scene_in_container_requested)

func _on_change_scene_to_file_requested(scene_path: String) -> void:
    if _current_scene:
        _current_scene.queue_free()
        _current_scene = null

    var scene_resource = load(scene_path)
    if scene_resource:
        _current_scene = scene_resource.instantiate()
        get_tree().root.add_child(_current_scene)
    else:
        print("Error: Could not load scene at path: " + scene_path)

func _on_load_scene_in_container_requested(scene_path: String, container: Node) -> void:
    if not is_instance_valid(container):
        print("Error: Container for scene loading is not valid.")
        return

    # Free existing children in the container
    for child in container.get_children():
        child.queue_free()

    var scene_resource = load(scene_path)
    if scene_resource:
        var new_scene_instance = scene_resource.instantiate()
        container.add_child(new_scene_instance)
    else:
        print("Error: Could not load scene at path: " + scene_path)
