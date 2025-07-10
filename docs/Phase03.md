Phase 3: Window & Interaction Management - Implementation Plan
Objective:
To centralize all window lifecycle and UI interaction logic into the WindowManager and InteractionManager singletons. This will implement the TDD's strict architectural model for a predictable and robust UI, including modal exclusivity and hierarchical inspection window stacking.
Step 3.1: Create the End-of-Battle UI
Instruction: Create the new scene and script for the popup that appears when a battle concludes. WindowManager will be responsible for instantiating it.
<details>
<summary>Prompt for AI Code Editor</summary>
PROMPT:
Please perform the following file creation operations:
Create the file res://scenes/EndBattlePopup.tscn with the following content:
[gd_scene load_steps=3 format=3 uid="uid://b4c5d6e7f8hah"]

[ext_resource type="Script" path="res://scripts/EndBattlePopup.gd" id="1_abcde"]
[ext_resource type="PackedScene" uid="uid://b7vqgcyh6q8w" path="res://scenes/BackgroundBlocker.tscn" id="2_fghij"]

[node name="EndBattlePopup" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_abcde")

[node name="BackgroundBlocker" parent="." instance=ExtResource("2_fghij")]
color = Color(0, 0, 0, 0.75)

[node name="CenterContainer" type="CenterContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="PanelContainer" type="PanelContainer" parent="CenterContainer"]
custom_minimum_size = Vector2(400, 200)
layout_mode = 2

[node name="VBoxContainer" type="VBoxContainer" parent="CenterContainer/PanelContainer"]
layout_mode = 2
theme_override_constants/separation = 20
alignment = 1

[node name="TitleLabel" type="Label" parent="CenterContainer/PanelContainer/VBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
theme_override_font_sizes/font_size = 48
text = "VICTORY"
horizontal_alignment = 1
vertical_alignment = 1

[node name="ReturnButton" type="Button" parent="CenterContainer/PanelContainer/VBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 4
text = "Return to Path"

Create the file res://scripts/EndBattlePopup.gd with the following content:
# res://scripts/EndBattlePopup.gd
extends Control
class_name EndBattlePopup

@onready var title_label: Label = %TitleLabel
@onready var return_button: Button = %ReturnButton

func _ready():
    return_button.pressed.connect(_on_return_button_pressed)

func populate(is_victory: bool):
    if is_victory:
        title_label.text = "VICTORY!"
        return_button.text = "Continue"
    else:
        title_label.text = "DEFEAT"
        return_button.text = "Return to Title"

func _on_return_button_pressed():
    # This will eventually lead back to the path choice / map screen.
    # For now, it correctly returns to the title screen.
    EventBus.emit_signal("title_scene_requested")

</details>
Step 3.2: Implement the WindowManager
Instruction: Overwrite WindowManager.gd. This new version is the production-ready implementation that acts as the sole authority for all window lifecycles, as mandated by the TDD. It includes logic for the modal stack, inspection groups, and the new EndBattlePopup.
<details>
<summary>Prompt for AI Code Editor</summary>
PROMPT:
Overwrite the file res://scripts/WindowManager.gd with the following content:
# res://scripts/WindowManager.gd
extends Node

const INSPECTION_WINDOW_MARGIN = 10.0

# Using preload for scenes that are fundamental to the UI.
var _window_scenes: Dictionary = {
	# Modal Windows
	&"Inventory": preload("res://scenes/InventoryWindow.tscn"),
	&"DiscardPile": preload("res://scenes/DiscardPileWindow.tscn"),
	&"ChoiceWindow": preload("res://scenes/ChoiceWindow.tscn"),
	&"EndBattlePopup": preload("res://scenes/EndBattlePopup.tscn"),
	# Non-Modal Inspection Windows
	&"UnitInspection": preload("res://scenes/UnitInspectionWindow.tscn"),
	&"ItemInspection": preload("res://scenes/ItemInspectionWindow.tscn"),
	&"EffectInspection": preload("res://scenes/ItemInspectionWindow.tscn"),
}

var _modal_stack: Array[Control] = []
var _inspection_window_groups: Array[Array] = [] # Array of Arrays of Controls
var _modal_layer: CanvasLayer = null

func _ready():
	EventBus.inspect_inventory_requested.connect(func(): open_modal_window(&"Inventory"))
	EventBus.display_discard_pile_requested.connect(func(): open_modal_window(&"DiscardPile"))
	EventBus.inspection_requested.connect(_open_root_inspection_window)
	EventBus.close_modal_requested.connect(_close_top_modal)
	EventBus.background_clicked.connect(_on_background_blocker_clicked)
	EventBus.global_background_clicked.connect(_on_global_background_clicked)
	EventBus.selection_changed.connect(_on_selection_changed)
	
	# Scene changes should close all windows
	EventBus.main_scene_requested.connect(_close_all_windows)
	EventBus.loadout_scene_requested.connect(_close_all_windows)
	EventBus.title_scene_requested.connect(_close_all_windows)

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if InteractionManager.is_drag_active():
			InteractionManager.cancel_active_drag()
		elif not _modal_stack.is_empty():
			_close_top_modal()
		elif not _inspection_window_groups.is_empty():
			close_all_inspection_windows()
		else:
			InteractionManager.clear_selection()

# --- Public API ---

func open_modal_window(type: StringName, context: Dictionary = {}):
	if not _window_scenes.has(type): return
	
	# TDD Rule: General-purpose modals are exclusive. Close any active one first.
	_close_all_windows()

	var window_instance = _window_scenes[type].instantiate()
	_get_modal_layer().add_child(window_instance)
	_modal_stack.push_back(window_instance)
	
	if window_instance.has_method("populate"):
		# Pass a simplified context. The window is responsible for fetching its own data.
		var population_context = context
		if type == &"Inventory" or type == &"DiscardPile":
			population_context["is_battle_context"] = GameManager.is_in_battle
		
		window_instance.populate(population_context)

func open_end_battle_popup(is_victory: bool):
	open_modal_window(&"EndBattlePopup", {"is_victory": is_victory})

func handle_inspection_background_click(clicked_window: Control):
	var parent_info = _find_parent_group(clicked_window)
	if parent_info.group:
		var parent_group = parent_info.group
		var parent_index = parent_info.index
		# Prune children: Close all windows stacked on top of the clicked one.
		while parent_group.size() > parent_index + 1:
			var window_to_close = parent_group.pop_back()
			if is_instance_valid(window_to_close):
				window_to_close.queue_free()

func close_all_inspection_windows():
	for group in _inspection_window_groups:
		for window in group:
			if is_instance_valid(window):
				window.queue_free()
	_inspection_window_groups.clear()

# --- Signal Handlers ---

func _on_background_blocker_clicked():
	if not _modal_stack.is_empty():
		var top_modal = _modal_stack.back()
		# Don't close the end battle popup by clicking the background
		if top_modal is EndBattlePopup:
			return
		_close_top_modal()

func _on_global_background_clicked():
	InteractionManager.clear_selection()
	close_all_inspection_windows()

func _on_selection_changed(new_location: LocationIdentifier):
	# If a new selection is made on a "root" view (not inside an inspection window),
	# close all existing inspection windows.
	if new_location != null:
		var view = InteractionManager.get_selected_view()
		if is_instance_valid(view):
			var parent_info = _find_parent_group(view)
			if not parent_info.group:
				close_all_inspection_windows()

# --- Private: Inspection Window Logic ---

func _open_root_inspection_window(source_view: Control):
	# TDD Rule: A root inspection closes all other inspection groups.
	close_all_inspection_windows()
	
	var new_group: Array[Control] = []
	_inspection_window_groups.push_back(new_group)
	
	_open_inspection_window(source_view, new_group)

func _open_child_inspection_window(source_view: Control):
	var parent_info = _find_parent_group(source_view)
	if not parent_info.group:
		# Fallback: if a child can't find its parent group, treat it as a new root.
		_open_root_inspection_window(source_view)
		return

	# TDD Rule: Prune sibling windows before opening a new child.
	var parent_group = parent_info.group
	var parent_index = parent_info.index
	while parent_group.size() > parent_index + 1:
		var descendant_to_close = parent_group.pop_back()
		if is_instance_valid(descendant_to_close): descendant_to_close.queue_free()
	
	_open_inspection_window(source_view, parent_group)

func _open_inspection_window(source_view: Control, group: Array):
	if not source_view or not source_view.has_meta("location_identifier"): return
	
	var loc = source_view.get_meta("location_identifier")
	# Determine window type based on data
	var data_owner = get_tree().get_first_node_in_group("battle_manager") if GameManager.is_in_battle else GameManager.run_state
	var all_instances = data_owner.get_all_instances() if data_owner.has_method("get_all_instances") else data_owner.run_instances
	var uuid = data_owner.get_container(loc.container).get_uuid(loc.index)
	var instance = all_instances.get(uuid)
	if not is_instance_valid(instance): return
		
	var def = instance.get_definition()
	var window_type = &"UnitInspection" if def.category == &"UNIT" else &"ItemInspection"
	var window_instance = _window_scenes[window_type].instantiate()
	
	group.push_back(window_instance)
	_get_modal_layer().add_child(window_instance)
	
	if window_instance.has_method("populate"):
		window_instance.populate({"source_view": source_view})
	
	await get_tree().process_frame
	window_instance.global_position = _calculate_window_position(source_view, window_instance)

# --- Private: Helper Methods ---

func _close_top_modal():
	if not _modal_stack.is_empty():
		var window = _modal_stack.pop_back()
		if is_instance_valid(window):
			window.queue_free()
		# Closing a modal should also close any inspections on top of it.
		close_all_inspection_windows()

func _close_all_windows():
	while not _modal_stack.is_empty():
		var window = _modal_stack.pop_back()
		if is_instance_valid(window):
			window.queue_free()
	close_all_inspection_windows()

func _find_parent_group(control: Control) -> Dictionary:
	var current_node = control
	while is_instance_valid(current_node) and current_node != get_tree().root:
		for i in range(_inspection_window_groups.size()):
			var group = _inspection_window_groups[i]
			var window_index = group.find(current_node)
			if window_index != -1:
				return {"group": group, "index": window_index}
		current_node = current_node.get_parent()
	return {"group": null, "index": -1}

func _calculate_window_position(source_view: Control, new_window: Control) -> Vector2:
	var viewport_rect = get_viewport().get_visible_rect()
	var source_rect = source_view.get_global_rect()
	var window_size = new_window.size
	
	var pos_right = Vector2(source_rect.end.x + INSPECTION_WINDOW_MARGIN, source_rect.position.y)
	if viewport_rect.encloses(Rect2(pos_right, window_size)): return pos_right
	
	var pos_left = Vector2(source_rect.position.x - window_size.x - INSPECTION_WINDOW_MARGIN, source_rect.position.y)
	if viewport_rect.encloses(Rect2(pos_left, window_size)): return pos_left
	
	var pos_down = Vector2(source_rect.position.x, source_rect.end.y + INSPECTION_WINDOW_MARGIN)
	if viewport_rect.encloses(Rect2(pos_down, window_size)): return pos_down
	
	var pos_up = Vector2(source_rect.position.x, source_rect.position.y - window_size.y - INSPECTION_WINDOW_MARGIN)
	if viewport_rect.encloses(Rect2(pos_up, window_size)): return pos_up
	
	return Vector2(INSPECTION_WINDOW_MARGIN, INSPECTION_WINDOW_MARGIN)

func _get_modal_layer() -> CanvasLayer:
	if not is_instance_valid(_modal_layer):
		var nodes = get_tree().get_nodes_in_group("modal_layer")
		if not nodes.is_empty(): _modal_layer = nodes[0]
		else:
			printerr("WindowManager: CRITICAL - No node in group 'modal_layer'.")
			_modal_layer = CanvasLayer.new()
			get_tree().root.add_child(_modal_layer)
	return _modal_layer

</details>
Step 3.3: Refine InteractionManager
Instruction: Overwrite InteractionManager.gd. This new version correctly implements the TDD's intent. It uses LocationIdentifier as the primary state for logical actions, while still managing Control nodes for visual drag-and-drop operations.
<details>
<summary>Prompt for AI Code Editor</summary>
PROMPT:
Overwrite the file res://scripts/InteractionManager.gd with the following content:
# res://scripts/InteractionManager.gd
extends Node

## Manages the temporary UI state of a user's action, such as the currently
## selected view/location and any active drag-and-drop operations.

var _selected_location: LocationIdentifier = null
var _selected_view: Control = null

var _is_drag_active: bool = false
var _drag_source_view: Control = null
var _drag_placeholder: Control = null

func _ready():
	EventBus.close_modal_requested.connect(clear_selection)
	EventBus.main_scene_requested.connect(clear_selection)
	EventBus.battle_start_requested.connect(clear_selection)

func select_view(view: Control, location: LocationIdentifier):
	if not is_instance_valid(view) or not is_instance_valid(location):
		clear_selection()
		return

	# If clicking the same view again, do nothing to allow drag to start.
	if _selected_view == view:
		return

	# If a different view was already selected, deselect it first.
	if is_instance_valid(_selected_view):
		clear_selection()

	_selected_view = view
	_selected_location = location
	
	EventBus.emit_signal("view_selected", _selected_view, _selected_location)
	EventBus.emit_signal("selection_changed", _selected_location)

func clear_selection():
	if is_instance_valid(_selected_view):
		var previously_selected_view = _selected_view
		var previously_selected_loc = _selected_location
		
		_selected_view = null
		_selected_location = null
		
		EventBus.emit_signal("view_deselected", previously_selected_view)
		EventBus.emit_signal("selection_changed", null)

func get_selected_location() -> LocationIdentifier:
	return _selected_location

func get_selected_view() -> Control:
	return _selected_view

# --- Drag & Drop State Management ---

func is_drag_active() -> bool:
	return _is_drag_active

func get_drag_source_view() -> Control:
	return _drag_source_view

func start_drag(source_view: Control, placeholder: Control):
	if not is_instance_valid(source_view): return
	
	clear_selection() # A drag operation overrides any selection
	
	_is_drag_active = true
	_drag_source_view = source_view
	_drag_placeholder = placeholder
	
	# The view itself is made invisible, and the placeholder takes its spot
	# in the layout to prevent reflowing.
	source_view.visible = false

func end_drag(was_handled: bool):
	if not _is_drag_active: return
	
	# If drag was not handled (e.g., dropped on invalid area), restore visibility.
	if not was_handled and is_instance_valid(_drag_source_view):
		_drag_source_view.visible = true

	if is_instance_valid(_drag_placeholder):
		_drag_placeholder.queue_free()
		
	_is_drag_active = false
	_drag_source_view = null
	_drag_placeholder = null

func cancel_active_drag():
	if _is_drag_active:
		end_drag(false)

</details>