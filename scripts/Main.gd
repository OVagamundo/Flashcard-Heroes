extends Control

# UI References (for scene structure only, no logic)
@onready var top_bar: Control = $VBoxContainer/TopBar
@onready var dynamic_content: Control = $VBoxContainer/DynamicContent
@onready var bottom_bar: Control = $VBoxContainer/BottomBar
@onready var popup_layer: CanvasLayer = $PopupLayer

func _ready() -> void:
	# Connect to EventBus for scene changes
	EventBus.load_scene_in_container_requested.connect(_on_load_scene_requested)
	EventBus.gacha_inspection_requested.connect(_on_gacha_inspection_requested)
	
	# Load initial scene into dynamic content area
	EventBus.load_scene_in_container_requested.emit("res://scenes/PathOptions.tscn", dynamic_content)

var _gacha_inspection_windows: Dictionary = {} # Stores references to instantiated GachaPoolInspection windows

func _on_gacha_inspection_requested(gacha_machine_id: String, machine_global_position: Vector2, machine_size: Vector2):
	var gacha_inspection_window: Control

	if _gacha_inspection_windows.has(gacha_machine_id):
		gacha_inspection_window = _gacha_inspection_windows[gacha_machine_id]
	else:
		# Load and instantiate the scene only once per gacha_machine_id
		var gacha_inspection_scene = load("res://scenes/GachaPoolInspection.tscn")
		gacha_inspection_window = gacha_inspection_scene.instantiate()
		popup_layer.add_child(gacha_inspection_window)
		gacha_inspection_window.set_as_top_level(true) # Ensures it's drawn on top
		_gacha_inspection_windows[gacha_machine_id] = gacha_inspection_window

	gacha_inspection_window.visible = true # Make it visible

	# Position the window above the gacha machine
	var window_size = gacha_inspection_window.size
	# Calculate position to center window horizontally above the machine
	# And place it slightly above the machine vertically
	var x_pos = machine_global_position.x + (machine_size.x / 2) - (window_size.x / 2) - 10 # Adjusted by -10 pixels to shift left
	var y_pos = machine_global_position.y - window_size.y - 20 # 20 pixels above the machine
	gacha_inspection_window.position = Vector2(x_pos, y_pos)

	# No data passed to the inspection window for now, as per current goal.
	gacha_inspection_window.setup_gacha_pool()



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
