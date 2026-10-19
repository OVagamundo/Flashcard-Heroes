# res://scripts/ChoiceWindow.gd
class_name ChoiceWindow
extends Control

const _UnitInspectionWindowScene = preload("res://scenes/UnitInspectionWindow.tscn")
const _ItemInspectionWindowScene = preload("res://scenes/ItemInspectionWindow.tscn")
const InputUtils = preload("res://scripts/InputUtils.gd")

@onready var merge_button: Button = %MergeButton
@onready var swap_button: Button = %SwapButton
@onready var title_label: Label = %Label
@onready var result_image: TextureRect = %ResultImage
@onready var inspection_container: MarginContainer = %InspectionContainer
@onready var buttons_separator: HSeparator = %ButtonsSeparator

var _source_location: LocationIdentifier
var _target_location: LocationIdentifier
var _recipe_id: StringName
var _result_id: StringName
var _source_view_instance_id: int = -1
var _choice_made: bool = false
var _drop_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Request interaction lock to prevent hover from closing this window
	if SignalBus.has_signal("interaction_lock_requested"):
		SignalBus.emit_signal("interaction_lock_requested", true)
		
	# Connect the SWAP button signal, as it's always available.
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
	if not _choice_made and _source_view_instance_id != -1:
		var effective_drop_pos: Vector2 = _drop_pos
		if effective_drop_pos.is_zero_approx() and is_instance_valid(_target_location) and is_instance_valid(WindowManager):
			var tgt_v = WindowManager.find_view_for_location(_target_location)
			if is_instance_valid(tgt_v):
				effective_drop_pos = tgt_v.get_global_rect().get_center()

		if is_instance_valid(ActionQueue) and not ActionQueue.is_replay_mode():
			ActionQueue.request(CancelDragAction.new(_source_location, _target_location, "cancelled_choice", effective_drop_pos, _source_view_instance_id))
		else:
			var view = instance_from_id(_source_view_instance_id)
			if is_instance_valid(view) and view is Control:
				view.visible = true
				view.modulate.a = 1.0
				if not effective_drop_pos.is_zero_approx() and view.has_method("play_snap_back_from"):
					view.play_snap_back_from(effective_drop_pos)
				elif view.has_method("play_landing_bounce"):
					view.play_landing_bounce()


func populate(context: Dictionary) -> void:
	_source_location = context.get("source_location")
	_target_location = context.get("target_location")
	_recipe_id = context.get("recipe_id")
	_result_id = context.get("result_id", &"")
	_source_view_instance_id = context.get("source_view_id", -1)
	_drop_pos = context.get("drop_pos", Vector2.ZERO)

	_update_localized_text()

	# Clear any previous preview inspection views
	if is_instance_valid(inspection_container):
		for child in inspection_container.get_children():
			inspection_container.remove_child(child)
			child.queue_free()

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
			
		var preview_instance: GachaBallInstance = context.get("preview_instance")
		if not is_instance_valid(preview_instance) and is_instance_valid(_source_location) and is_instance_valid(_target_location):
			var data_owner: Object = null
			if GameManager.is_in_battle:
				data_owner = get_tree().get_first_node_in_group("battle_manager")
			else:
				data_owner = GameManager.run_state
			if is_instance_valid(data_owner):
				var all_instances: Dictionary = data_owner.get_all_instances() if data_owner.has_method("get_all_instances") else {}
				var src_inst = GameManager.get_instance_from_location(_source_location)
				var tgt_inst = GameManager.get_instance_from_location(_target_location)
				if is_instance_valid(src_inst) and is_instance_valid(tgt_inst):
					preview_instance = MergeManager.get_preview_merge_instance(src_inst, tgt_inst, _source_location, _target_location, all_instances)

		var preview_loaded := false
		if is_instance_valid(preview_instance):
			var def = preview_instance.get_definition()
			if is_instance_valid(def):
				var is_unit = def.category == &"UNIT"
				var inspection_view: InspectionWindow = _UnitInspectionWindowScene.instantiate() if is_unit else _ItemInspectionWindowScene.instantiate()
				
				inspection_container.add_child(inspection_view)
				inspection_view.custom_minimum_size = Vector2.ZERO
				inspection_view.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
				
				var inspect_ctx: Dictionary = {
					"source_view": self,
					"instance": preview_instance,
					"location": _target_location,
					"is_preview": true,
					"recipe_id": _recipe_id
				}
				inspection_view.populate(inspect_ctx)
				inspection_view.custom_minimum_size = Vector2.ZERO
				inspection_view.enforce_display_only()

				inspection_container.visible = true
				if is_instance_valid(buttons_separator):
					buttons_separator.visible = true
				if is_instance_valid(title_label):
					title_label.visible = false
				if is_instance_valid(result_image):
					result_image.visible = false
				custom_minimum_size = Vector2(480, 0)
				preview_loaded = true
				call_deferred("_deferred_shrink")

		if not preview_loaded:
			if is_instance_valid(inspection_container):
				inspection_container.visible = false
			if is_instance_valid(buttons_separator):
				buttons_separator.visible = false
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
		if is_instance_valid(result_image):
			result_image.visible = false
		if is_instance_valid(inspection_container):
			inspection_container.visible = false
		if is_instance_valid(buttons_separator):
			buttons_separator.visible = false
		if is_instance_valid(title_label):
			title_label.visible = true

	reset_size()

func _deferred_shrink() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	if is_instance_valid(inspection_container):
		for child in inspection_container.get_children():
			if child is Control:
				child.custom_minimum_size = Vector2.ZERO
	custom_minimum_size = Vector2(480, 0)
	size = Vector2(480, 0)
	reset_size()

func _on_merge_pressed() -> void:
	# This function is now a dedicated handler for the merge button press.
	_on_choice_made(&"MERGE", _recipe_id)

func _on_choice_made(choice: StringName, recipe_id: StringName) -> void:
	_choice_made = true
	if is_instance_valid(ActionQueue):
		if choice == &"MERGE":
			var action: GameAction
			if is_instance_valid(MergeManager) and MergeManager.is_merge_encounter_active():
				action = MergeEncounterAction.new(_source_location, _target_location, recipe_id)
			else:
				action = ConfirmMergeAction.new(_source_location, _target_location, recipe_id)
			ActionQueue.request(action)
		elif choice == &"SWAP":
			var action := ConfirmSwapAction.new(_source_location, _target_location)
			ActionQueue.request(action)
	else:
		push_error("[ChoiceWindow] ActionQueue unavailable for choice.")
