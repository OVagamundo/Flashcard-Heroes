class_name TraitTracker
extends PanelContainer

const InputUtils = preload("res://scripts/InputUtils.gd")
const InspectionTrigger = preload("res://scripts/ui/InspectionTrigger.gd")

@onready var icon_rect: TextureRect = $HBoxContainer/Icon
@onready var name_label: Label = $HBoxContainer/VBoxContainer/NameLabel
@onready var count_label: Label = $HBoxContainer/VBoxContainer/CountLabel

var _current_trait_id: String = ""
var _inspection_trigger: InspectionTrigger = null

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_inspection_trigger = InspectionTrigger.new()
	_inspection_trigger.setup(self, func():
		if _current_trait_id.is_empty():
			return {}
		return {"trait_id": _current_trait_id}
	)

func _exit_tree() -> void:
	if is_instance_valid(_inspection_trigger):
		_inspection_trigger.cancel()

func _on_mouse_entered() -> void:
	if is_instance_valid(_inspection_trigger):
		_inspection_trigger.on_mouse_entered()

func _on_mouse_exited() -> void:
	if is_instance_valid(_inspection_trigger):
		_inspection_trigger.on_mouse_exited()

func populate(trait_name: String, count: int, is_active: bool) -> void:
	# Set Icon based on trait name
	_current_trait_id = trait_name
	var trait_def: Dictionary = C.TRAIT_DEFINITIONS.get(trait_name, {})
	if is_instance_valid(icon_rect):
		if trait_def.has("icon_path") and ResourceLoader.exists(trait_def["icon_path"]):
			icon_rect.texture = load(trait_def["icon_path"])
		else:
			match trait_name:
				"FIRE":
					icon_rect.texture = preload("res://assets/Realistic/sprites/trinkets/Trinket7A.png")
				"EARTH":
					icon_rect.texture = preload("res://assets/Realistic/sprites/trinkets/Trinket6A.png")
				"WATER":
					icon_rect.texture = preload("res://assets/Realistic/sprites/items/WaterEmblem.png")
				"AIR":
					icon_rect.texture = preload("res://assets/Realistic/sprites/items/AirEmblem.png")
	
	if is_instance_valid(name_label):
		var display_key = trait_def.get("display_name_key", "")
		if not display_key.is_empty():
			name_label.text = tr(display_key)
		else:
			name_label.text = trait_name.capitalize()
	
	# Set Count text with dynamic threshold
	var levels: Array = trait_def.get("levels", [])
	var threshold = int(levels[0].get("min", 2)) if not levels.is_empty() else (2 if trait_name in ["WATER", "AIR"] else 3)
	if is_instance_valid(count_label):
		count_label.text = "%d / %d" % [count, threshold]

	
	# Style based on activation
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	
	if is_active:
		# Active: Brighter background, Gold/Silver border
		style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(1.0, 0.84, 0.0, 1.0) # Gold-ish
		
		if is_instance_valid(name_label): name_label.modulate = Color(1, 1, 1, 1)
		if is_instance_valid(count_label): count_label.modulate = Color(1, 1, 1, 1)
		modulate = Color(1, 1, 1, 1)
	else:
		# Inactive: Darker background, no border
		style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.4, 0.4, 0.4, 0.5)
		
		if is_instance_valid(name_label): name_label.modulate = Color(0.7, 0.7, 0.7, 1)
		if is_instance_valid(count_label): count_label.modulate = Color(0.7, 0.7, 0.7, 1)
		modulate = Color(1, 1, 1, 0.9)
		
	add_theme_stylebox_override("panel", style)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if is_instance_valid(_inspection_trigger):
				_inspection_trigger.on_pointer_pressed(event.position)
			accept_event()
		else:
			if is_instance_valid(_inspection_trigger):
				_inspection_trigger.on_pointer_released()
			accept_event()
		return

	if event is InputEventScreenDrag:
		if is_instance_valid(_inspection_trigger):
			_inspection_trigger.on_motion(event.position)
		accept_event()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if InputUtils.should_ignore_mouse_pointer_event(event):
			return
		if event.is_pressed():
			if is_instance_valid(_inspection_trigger):
				_inspection_trigger.on_pointer_pressed(event.position)
			accept_event()
		else:
			if is_instance_valid(_inspection_trigger):
				_inspection_trigger.on_pointer_released()
			accept_event()
