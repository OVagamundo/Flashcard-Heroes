extends Node

# Signal definitions for scene management
# Note: Signals are connected dynamically at runtime
signal change_scene_to_file_requested(scene_path: String)  # Used for full scene transitions
signal load_scene_in_container_requested(scene_path: String, container: Node)  # Used for loading scenes into containers
signal gacha_inspection_requested(gacha_machine_id: String, machine_global_position: Vector2, machine_size: Vector2) # Signal to request opening the gacha inspection window
signal draw_gacha_requested(tier: int) # Signal to request drawing from a gacha machine
