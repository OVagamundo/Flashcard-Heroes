extends Node

signal style_changed

const SETTINGS_PATH := "user://art_style_settings.save"
var current_style: String = "Realistic" # "Realistic" or "PixelArt"

func _init() -> void:
	_load_settings()

func _ready() -> void:
	# Defer applying theme so the tree root is fully ready
	call_deferred("_apply_global_theme")
	if get_tree():
		get_tree().node_added.connect(_swap_node_texture)

func set_style(new_style: String) -> void:
	if current_style == new_style:
		return
	current_style = new_style
	_save_settings()
	_apply_global_theme()
	style_changed.emit()

func get_themed_texture(tex: Texture2D) -> Texture2D:
	if not is_instance_valid(tex) or tex.resource_path.is_empty():
		return tex
		
	var path = tex.resource_path
	
	# We want to identify the current style part of the path and swap it.
	# Standard path: res://assets/[STYLE_NAME]/...
	if not path.begins_with("res://assets/"):
		return tex
		
	var parts = path.split("/")
	if parts.size() < 4: # ["res:", "", "assets", "StyleName", ...]
		return tex
		
	var existing_style = parts[3]
	if existing_style == current_style:
		return tex
		
	# Build the target path by swapping the style folder name
	var target_parts = Array(parts)
	target_parts[3] = current_style
	var target_path = "/".join(target_parts)
	
	if ResourceLoader.exists(target_path):
		return load(target_path)
		
	# Fallback logic: If the requested style doesn't have the asset, try falling back to Realistic
	if current_style != "Realistic":
		target_parts[3] = "Realistic"
		var realistic_path = "/".join(target_parts)
		if existing_style != "Realistic" and ResourceLoader.exists(realistic_path):
			return load(realistic_path)
		
	# Fallback to the provided texture if the themed one doesn't exist yet
	return tex

func _apply_global_theme() -> void:
	# 1. Swap the Global UI Theme (Buttons, Panels, Fonts)
	var theme_path = "res://assets/" + current_style + "/ui/game_theme.tres"
	if ResourceLoader.exists(theme_path):
		var new_theme = load(theme_path)
		if get_tree() and get_tree().root:
			get_tree().root.theme = new_theme

	# 2. Automatically traverse the entire SceneTree and swap all hardcoded textures!
	if get_tree() and get_tree().root:
		_recursive_texture_swap(get_tree().root)

func _recursive_texture_swap(node: Node) -> void:
	if not is_instance_valid(node):
		return
		
	_swap_node_texture(node)
		
	for child in node.get_children():
		_recursive_texture_swap(child)

func _swap_node_texture(node: Node) -> void:
	if not is_instance_valid(node):
		return
		
	# Use reflection to find EVERY property that holds a texture, including custom script exports!
	for prop in node.get_property_list():
		if prop.type == TYPE_OBJECT:
			# Wrap in a try-catch equivalent to ensure safety
			var val = node.get(prop.name)
			if val is Texture2D:
				var new_tex = get_themed_texture(val)
				if new_tex != val:
					node.set(prop.name, new_tex)
			elif val is StyleBoxTexture and val.texture:
				var new_tex = get_themed_texture(val.texture)
				if new_tex != val.texture:
					val.texture = new_tex

func get_available_styles() -> Array[String]:
	var styles: Array[String] = []
	var dir = DirAccess.open("res://assets/")
	if dir:
		dir.list_dir_begin()
		var folder_name = dir.get_next()
		while folder_name != "":
			if dir.current_is_dir() and not folder_name.begins_with("."):
				# Filter out non-style utility folders
				var ignored_folders = ["fonts", "styles", "shaders", "audio", "Concept art", "1BIT"]
				if folder_name not in ignored_folders:
					styles.append(folder_name)
			folder_name = dir.get_next()
	
	# Ensure Realistic is always first
	if "Realistic" in styles:
		styles.erase("Realistic")
		styles.insert(0, "Realistic")
	
	return styles

func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_var({"current_style": current_style})
		file.close()

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file != null:
		var data: Variant = file.get_var()
		file.close()
		if data is Dictionary and data.has("current_style"):
			current_style = data["current_style"]
