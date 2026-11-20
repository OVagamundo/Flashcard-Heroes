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
	SignalBus.interaction_lock_requested.emit(true)
		
	# Populate decides whether exchanging these two locations is legal.
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
	if is_instance_valid(WindowManager):
		WindowManager.close_children_of(self)
		WindowManager.close_glossary_pill()
		WindowManager.close_modal_child_windows(self)
	# Release interaction lock
	SignalBus.interaction_lock_requested.emit(false)
		
	if SignalBus.locale_changed.is_connected(_update_localized_text):
		SignalBus.locale_changed.disconnect(_update_localized_text)
		
	# Restore visibility of source view if it was hidden (e.g. on Cancel)
	if not _choice_made and _source_view_instance_id != -1:
		var effective_drop_pos: Vector2 = _drop_pos
		if effective_drop_pos.is_zero_approx() and is_instance_valid(_target_location) and is_instance_valid(WindowManager):
			var tgt_v = WindowManager.find_view_for_location(_target_location)
			if is_instance_valid(tgt_v):
				effective_drop_pos = tgt_v.get_global_rect().get_center()

		if not ActionQueue.is_replay_mode():
			ActionQueue.request(CancelDragAction.new(_source_location, _target_location, "cancelled_choice", effective_drop_pos))
		else:
			var view: GachaBallView = instance_from_id(_source_view_instance_id) as GachaBallView
			if is_instance_valid(view):
				view.visible = true
				view.modulate.a = 1.0
				if not effective_drop_pos.is_zero_approx():
					view.play_snap_back_from(effective_drop_pos)
				else:
					view.play_landing_bounce()


func populate(context: Dictionary) -> void:
	_source_location = context.get("source_location")
	_target_location = context.get("target_location")
	_recipe_id = context.get("recipe_id")
	_result_id = context.get("result_id", &"")
	_source_view_instance_id = context.get("source_view_id", -1)
	_drop_pos = context.get("drop_pos", Vector2.ZERO)
	var source_instance: GachaBallInstance = GameManager.get_instance_from_location(_source_location)
	var target_instance: GachaBallInstance = GameManager.get_instance_from_location(_target_location)
	assert(source_instance != null and target_instance != null, "ChoiceWindow requires both merge ingredients")
	swap_button.visible = InventoryManager.is_valid_placement(source_instance, _target_location) and InventoryManager.is_valid_placement(target_instance, _source_location)

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
			var all_instances: Dictionary = {}
			if GameManager.is_in_battle:
				var bm: BattleManager = get_tree().get_first_node_in_group("battle_manager") as BattleManager
				if is_instance_valid(bm):
					all_instances = bm.get_all_instances()
			elif is_instance_valid(GameManager.run_state):
				all_instances = GameManager.run_state.get_all_instances()
			if not all_instances.is_empty():
				var src_inst = GameManager.get_instance_from_location(_source_location)
				var tgt_inst = GameManager.get_instance_from_location(_target_location)
				if is_instance_valid(src_inst) and is_instance_valid(tgt_inst):
					preview_instance = MergeManager.get_preview_merge_instance(src_inst, tgt_inst, _source_location, _target_location, all_instances, _recipe_id)

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
				custom_minimum_size = Vector2(360, 0)
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
	call_deferred("_deferred_shrink_step", 3)

func _deferred_shrink_step(frames_remaining: int) -> void:
	if not is_inside_tree():
		return
	if frames_remaining > 0:
		call_deferred("_deferred_shrink_step", frames_remaining - 1)
		return
	if is_instance_valid(inspection_container):
		for child in inspection_container.get_children():
			if child is Control:
				child.custom_minimum_size = Vector2.ZERO
	custom_minimum_size = Vector2(360, 0)
	size = Vector2(360, 0)
	reset_size()

func _on_merge_pressed() -> void:
	# This function is now a dedicated handler for the merge button press.
	_on_choice_made(&"MERGE", _recipe_id)

func _on_choice_made(choice: StringName, recipe_id: StringName) -> void:
	_choice_made = true
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
		assert(false, "[ChoiceWindow] Unknown choice: %s" % String(choice))

func get_embedded_inspection_window() -> InspectionWindow:
	if is_instance_valid(inspection_container):
		for child in inspection_container.get_children():
			if child is InspectionWindow:
				return child
	return null

func get_glossary_terms() -> Array[String]:
	var insp = get_embedded_inspection_window()
	if is_instance_valid(insp):
		return insp.get_glossary_terms()
	return []

func get_child_window_specs() -> Array[Dictionary]:
	var insp = get_embedded_inspection_window()
	if is_instance_valid(insp):
		return insp.get_child_window_specs()
	return []
