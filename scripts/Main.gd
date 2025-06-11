extends Control

func _ready() -> void:
    # This requests the SceneManager to load the initial PathChoice scene
    # into the designated container within this scene.
    var dynamic_content_area = $VBoxContainer/DynamicContentArea
    EventBus.load_scene_in_container_requested.emit("res://scenes/PathChoice.tscn", dynamic_content_area)
