<!-- Original: scripts/ChoicePromptUI.gd -->

```gdscript
# res://scripts/ChoicePromptUI.gd
extends Control

var merge_button: Button
var swap_button: Button

func _ready():
	# This script now builds its own UI to bypass scene file corruption.
	_create_ui()

	# Connect signals
	if is_instance_valid(merge_button) and is_instance_valid(swap_button):
		merge_button.pressed.connect(func(): _on_choice_made(&"MERGE"))
		swap_button.pressed.connect(func(): _on_choice_made(&"SWAP"))
	else:
		printerr("FATAL: ChoicePromptUI failed to create its own buttons.")
		
	EventBus.close_modal_requested.connect(queue_free)

func _on_choice_made(choice: StringName):
	EventBus.emit_signal("choice_made", choice)
	queue_free()

func _create_ui():
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Panel
	var panel = PanelContainer.new()
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.2, 0.2, 0.2, 1)
	panel.add_theme_stylebox_override("panel", stylebox)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(300, 150)
	add_child(panel)
	
	# VBox
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	# Label
	var label = Label.new()
	label.text = "Choose Action"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(label)
	
	# HBox for buttons
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(hbox)
	
	# Merge Button
	merge_button = Button.new()
	merge_button.text = "Merge"
	merge_button.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_child(merge_button)
	
	# Swap Button
	swap_button = Button.new()
	swap_button.text = "Swap"
	swap_button.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_child(swap_button)

```