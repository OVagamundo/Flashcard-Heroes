extends Control

# UI References (for scene structure only, no logic)
@onready var top_bar: Control = $VBoxContainer/TopBar
@onready var dynamic_content: Control = $VBoxContainer/DynamicContent
@onready var bottom_bar: Control = $VBoxContainer/BottomBar
@onready var popup_layer: CanvasLayer = $PopupLayer

func _ready() -> void:
	# Connect to EventBus for scene changes
	EventBus.load_scene_in_container_requested.connect(_on_load_scene_requested)
	
	# Load initial scene into dynamic content area
	EventBus.load_scene_in_container_requested.emit("res://scenes/PathOptions.tscn", dynamic_content)

func _on_load_scene_requested(scene_path: String, container: Node) -> void:
	# Clear existing children
	for child in container.get_children():
		child.queue_free()
	
	# Load and add the new scene
	var scene = load(scene_path)
	if scene:
		var instance = scene.instantiate()
		container.add_child(instance)

func _on_menu_pressed() -> void:
	# Use EventBus for all scene transitions
	EventBus.change_scene_to_file_requested.emit("res://scenes/Title.tscn")
