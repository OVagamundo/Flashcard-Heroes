# res://scripts/MergeEncounter.gd
extends Control

## Merge Encounter - Allows players to merge gachaballs for gold
## Merging here bypasses recipe locks and unlocks the recipe for the run.

@onready var title_label: Label = %TitleLabel
@onready var open_inventory_button: Button = %OpenInventoryButton
@onready var leave_button: Button = %LeaveButton

var _last_inventory_open: bool = false

func _ready() -> void:
	add_to_group("merge_encounter_controller")
	
	open_inventory_button.pressed.connect(_on_open_inventory_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	
	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()
	
	# Set process to monitor inventory state
	set_process(true)

func _exit_tree() -> void:
	if SignalBus.locale_changed.is_connected(_update_localized_text):
		SignalBus.locale_changed.disconnect(_update_localized_text)
		
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node):
		if main_node.has_method("hide_action_instruction"):
			main_node.hide_action_instruction()

func _process(_delta: float) -> void:
	var is_open := WindowManager.is_run_inventory_window_open()
	if is_open != _last_inventory_open:
		_last_inventory_open = is_open
		var main_node = GameManager._active_main_node
		if is_instance_valid(main_node):
			if is_open:
				if main_node.has_method("show_action_instruction"):
					main_node.show_action_instruction(tr("ui.merge_encounter_instruction"))
			else:
				if main_node.has_method("hide_action_instruction"):
					main_node.hide_action_instruction()

func _update_localized_text() -> void:
	title_label.text = tr("ui.merge_encounter_title")
	open_inventory_button.text = tr("ui.merge_encounter_open_inventory")
	leave_button.text = tr("ui.leave")

func _on_open_inventory_pressed() -> void:
	if WindowManager.is_any_inspection_window_open():
		WindowManager.close_all_inspection_windows()
	else:
		SignalBus.emit_signal("inspect_inventory_requested")

func _on_leave_pressed() -> void:
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node):
		if main_node.has_method("hide_action_instruction"):
			main_node.hide_action_instruction()
			
	SignalBus.emit_signal("path_choice_scene_requested")
	queue_free()
