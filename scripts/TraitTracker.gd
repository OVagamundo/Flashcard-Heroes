class_name TraitTracker
extends PanelContainer

const InputUtils = preload("res://scripts/InputUtils.gd")

@onready var icon_rect: TextureRect = $HBoxContainer/Icon
@onready var name_label: Label = $HBoxContainer/VBoxContainer/NameLabel
@onready var count_label: Label = $HBoxContainer/VBoxContainer/CountLabel

var _current_trait_id: String = ""

func populate(trait_name: String, count: int, is_active: bool) -> void:
	# Set Icon based on trait name
	_current_trait_id = trait_name
	if is_instance_valid(icon_rect):
		match trait_name:
			"FIRE":
				icon_rect.texture = preload("res://assets/Realistic/sprites/trinkets/Trinket7A.png")
				if is_instance_valid(name_label): name_label.text = tr("trait.fire.name")
			"EARTH":
				icon_rect.texture = preload("res://assets/Realistic/sprites/trinkets/Trinket6A.png")
				if is_instance_valid(name_label): name_label.text = tr("trait.earth.name")
			"WATER":
				icon_rect.texture = preload("res://assets/Realistic/sprites/items/WaterEmblem.png")
				if is_instance_valid(name_label): name_label.text = tr("trait.water.name")
			"AIR":
				icon_rect.texture = preload("res://assets/Realistic/sprites/items/AirEmblem.png")
				if is_instance_valid(name_label): name_label.text = tr("trait.air.name")
			_:
				if is_instance_valid(name_label): name_label.text = trait_name
	
	# Set Count text with dynamic threshold (3 for Fire/Earth, 2 for Water/Wind)
	var threshold = 2 if trait_name in ["WATER", "AIR"] else 3
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
		
		style.border_color = Color(0.4, 0.4, 0.4, 0.5)
		
		if is_instance_valid(name_label): name_label.modulate = Color(0.7, 0.7, 0.7, 1)
		if is_instance_valid(count_label): count_label.modulate = Color(0.7, 0.7, 0.7, 1)
		modulate = Color(1, 1, 1, 0.9)
		
	add_theme_stylebox_override("panel", style)

func _gui_input(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		if not _current_trait_id.is_empty():
			# S6/W2: Clicking UI element clears selection
			SignalBus.emit_signal("selection_clear_requested")
			SignalBus.emit_signal("trait_inspection_requested", _current_trait_id, self)
			accept_event()
