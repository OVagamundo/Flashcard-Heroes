# res://scripts/ChoiceWindow.gd
class_name ChoiceWindow
extends Control

const _GachaBallView = preload("res://scenes/GachaBallView.tscn")

@onready var merge_button: Button = %MergeButton
@onready var swap_button: Button = %SwapButton

var _source_location: LocationIdentifier
var _target_location: LocationIdentifier
var _recipe_id: StringName
var _source_view_instance_id: int = -1
var _choice_made: bool = false

func _ready() -> void:
	# Request interaction lock to prevent hover from closing this window
	if SignalBus.has_signal("interaction_lock_requested"):
		SignalBus.emit_signal("interaction_lock_requested", true)
		
	# Connect the SWAP button signal, as it's always available.

	# The MERGE button signal will be connected in populate() only if a valid recipe exists.
	swap_button.pressed.connect(func(): _on_choice_made(&"SWAP", &""))
	# Prune only child windows when clicking on this window's background
	gui_input.connect(_on_panel_gui_input)

func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Local background click inside this window should prune only its children.
		# Global outside clicks are handled by GIR to close the entire inspection group.
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	# Release interaction lock
	if SignalBus.has_signal("interaction_lock_requested"):
		SignalBus.emit_signal("interaction_lock_requested", false)
		
	# Restore visibility of source view if it was hidden (e.g. on Cancel)
	if _source_view_instance_id != -1:
		var view = instance_from_id(_source_view_instance_id)
		if is_instance_valid(view) and view is Control:
			view.visible = true
			view.modulate.a = 1.0
			
			# If no choice was made (Swap/Merge), it implies a Cancel/Close.
			# Trigger the standard "drop cancelled" bounce animation.
			if not _choice_made and view.has_method("play_landing_bounce"):
				# We need to defer this slightly to ensure the view interacts with layout correctly after being hidden
				# But play_landing_bounce usually handles that.
				view.play_landing_bounce()


func populate(context: Dictionary) -> void:
	_source_location = context.get("source_location")
	_target_location = context.get("target_location")
	_recipe_id = context.get("recipe_id")
	_source_view_instance_id = context.get("source_view_id", -1)


	# MODIFIED: All button configuration logic is now here, inside populate().
	# This guarantees it runs AFTER the context data has been received.
	if _recipe_id:
		# A valid recipe exists. Enable the button and connect its signal.
		merge_button.disabled = false
		# Ensure we don't connect the signal multiple times if populate were ever called again.
		if not merge_button.is_connected("pressed", _on_merge_pressed):
			merge_button.pressed.connect(_on_merge_pressed)
	else:
		# No valid recipe. The button should be disabled.
		merge_button.disabled = true

func _on_merge_pressed() -> void:
	# This function is now a dedicated handler for the merge button press.
	_on_choice_made(&"MERGE", _recipe_id)

func _on_choice_made(choice: StringName, recipe_id: StringName) -> void:
	_choice_made = true
	# The signature now matches the new, more robust SignalBus signal.
	SignalBus.emit_signal("choice_made", choice, _source_location, _target_location, recipe_id)
	SignalBus.emit_signal("close_top_contextual_requested")