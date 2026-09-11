# res://scripts/ChoiceWindow.gd
class_name ChoiceWindow
extends Control

const _GachaBallView = preload("res://scenes/GachaBallView.tscn")
const InputUtils = preload("res://scripts/InputUtils.gd")

@onready var merge_button: Button = %MergeButton
@onready var swap_button: Button = %SwapButton
@onready var title_label: Label = %Label
@onready var result_image: TextureRect = %ResultImage

var _source_location: LocationIdentifier
var _target_location: LocationIdentifier
var _recipe_id: StringName
var _result_id: StringName
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
	
	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()

func _update_localized_text() -> void:
	swap_button.text = tr("ui.btn_swap")
	
	if MergeManager.is_merge_encounter_active():
		var cost = 5
		if is_instance_valid(GameManager.run_state):
			cost = GameManager.run_state.merge_encounter_cost
		merge_button.text = tr("ui.btn_merge_cost").format({"cost": str(cost)})
	else:
		merge_button.text = tr("ui.btn_merge")

func _on_panel_gui_input(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		# Local background click inside this window should prune only its children.
		# Global outside clicks are handled by GIR to close the entire inspection group.
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	# Release interaction lock
	if SignalBus.has_signal("interaction_lock_requested"):
		SignalBus.emit_signal("interaction_lock_requested", false)
		
	if SignalBus.locale_changed.is_connected(_update_localized_text):
		SignalBus.locale_changed.disconnect(_update_localized_text)
		
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
	_result_id = context.get("result_id", &"")
	_source_view_instance_id = context.get("source_view_id", -1)

	_update_localized_text()


	# MODIFIED: All button configuration logic is now here, inside populate().
	# This guarantees it runs AFTER the context data has been received.
	if _recipe_id:
		# A valid recipe exists. Enable the button and connect its signal.
		merge_button.disabled = false
		
		# MERGE ENCOUNTER: Disable if not enough gold
		if MergeManager.is_merge_encounter_active():
			if not is_instance_valid(GameManager.run_state) or GameManager.run_state.gold < GameManager.run_state.merge_encounter_cost:
				merge_button.disabled = true
		# Ensure we don't connect the signal multiple times if populate were ever called again.
		if not merge_button.is_connected("pressed", _on_merge_pressed):
			merge_button.pressed.connect(_on_merge_pressed)
			
		var result_id = _result_id
		if result_id == &"":
			var recipe = Database.recipes.get(_recipe_id)
			if recipe and recipe.result_id:
				result_id = recipe.result_id
				
		if result_id != &"":
			var result_def = Database.get_definition(result_id)
			if result_def and result_def.icon:
				result_image.texture = result_def.icon
				result_image.visible = true
				title_label.visible = false
	else:
		# No valid recipe. The button should be disabled.
		merge_button.disabled = true
		result_image.visible = false
		title_label.visible = true

func _on_merge_pressed() -> void:
	# This function is now a dedicated handler for the merge button press.
	_on_choice_made(&"MERGE", _recipe_id)

func _on_choice_made(choice: StringName, recipe_id: StringName) -> void:
	_choice_made = true
	# The signature now matches the new, more robust SignalBus signal.
	SignalBus.emit_signal("choice_made", choice, _source_location, _target_location, recipe_id)
	SignalBus.emit_signal("close_top_contextual_requested")
