# res://scripts/GachaMachineDiscard.gd
class_name GachaMachineDiscard
extends Control

## Discard pile machine base that replaces DiscardPileButton in the UI.
## Positioned alongside the 3 gacha machines at the bottom of the screen.

signal pressed

var count_label: Label:
	get:
		if _count_label == null:
			_count_label = get_node_or_null("CountLabel")
		return _count_label
var _count_label: Label = null

var knob_button: TextureButton:
	get:
		if _knob_button == null:
			_knob_button = get_node_or_null("KnobButton")
		return _knob_button
var _knob_button: TextureButton = null

var machine_image: TextureRect:
	get:
		if _machine_image == null:
			_machine_image = get_node_or_null("MachineImage")
		return _machine_image
var _machine_image: TextureRect = null

var text: String = "":
	set(val):
		text = val
		if is_instance_valid(count_label):
			count_label.text = text

var disabled: bool = false:
	set(val):
		disabled = val
		modulate = Color(0.65, 0.65, 0.65, 1.0) if disabled else Color.WHITE
		mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if text.is_empty() and is_instance_valid(count_label) and not count_label.text.is_empty():
		text = count_label.text
	elif is_instance_valid(count_label):
		count_label.text = text

func _on_gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if is_instance_valid(knob_button) and knob_button.get_global_rect().has_point(get_global_mouse_position()):
		return
	var InputUtils = preload("res://scripts/InputUtils.gd")
	if InputUtils.is_primary_pointer_press(event):
		pressed.emit()
		get_viewport().set_input_as_handled()
		if InputUtils.is_touch_pointer_event(event):
			accept_event()

func _on_mouse_entered() -> void:
	if not disabled:
		Audio.play_sfx("ui_hover")
		if is_instance_valid(machine_image):
			machine_image.modulate = Color(1.1, 1.1, 1.1, 1.0)

func _on_mouse_exited() -> void:
	if is_instance_valid(machine_image):
		machine_image.modulate = Color.WHITE

func get_knob_button() -> TextureButton:
	return knob_button

func set_count(count: int) -> void:
	text = tr("ui.discard_pile_count") % count
