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
	&"EffectInspection": preload("res://scenes/EffectInspectionWindow.tscn"),
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

func open_dialog_window(type: StringName, context: Dictionary = {}):
	if not _window_scenes.has(type): return
	
	# Dialogs are stacked on top of the current modal, not replacing it.
	var window_instance = _window_scenes[type].instantiate()
	_get_modal_layer().add_child(window_instance)
	_modal_stack.push_back(window_instance)
	
	if window_instance.has_method("populate"):
		window_instance.populate(context)

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
			var is_battle = GameManager.is_in_battle
			population_context["is_battle_context"] = is_battle
			if is_battle:
				var bm = get_tree().get_first_node_in_group("battle_manager")
				if is_instance_valid(bm):
					if type == &"Inventory":
						population_context["inventory"] = bm.get_battle_inventory()
					else: # DiscardPile
						population_context["inventory"] = bm.get_discard_pile_inventory()
			else: # Run context
				var run_state = GameManager.run_state
				if is_instance_valid(run_state):
					var inventory_data = {}
					for tier in [1, 2, 3]:
						var container_name = &"RunInventoryT%d" % tier
						if run_state.run_inventory_containers.has(container_name):
							var container = run_state.run_inventory_containers[container_name]
							var tier_instances = []
							for uuid in container.get_all_uuids():
								if uuid and run_state.run_instances.has(uuid):
									tier_instances.append(run_state.run_instances[uuid])
								else:
									tier_instances.append(null)
							inventory_data[tier] = tier_instances
					population_context["inventory"] = inventory_data
		
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





func open_child_inspection_window(parent_window: Control, window_type: StringName, context: Dictionary):
	if not _window_scenes.has(window_type):
		printerr("WindowManager: Window scene not found for type: %s" % window_type)
		return
		
	var parent_info = _find_parent_group(parent_window)
	if not parent_info.group:
		printerr("WindowManager: Could not find parent group for window: %s" % parent_window.name)
		return
	
	var parent_group = parent_info.group
	var parent_index = parent_info.index
	while parent_group.size() > parent_index + 1:
		var descendant_to_close = parent_group.pop_back()
		if is_instance_valid(descendant_to_close): descendant_to_close.queue_free()

	var window_instance = _window_scenes[window_type].instantiate()
	parent_group.push_back(window_instance)
	
	_get_modal_layer().add_child(window_instance)
	if window_instance.has_method("populate"):
		window_instance.populate(context)

	await get_tree().process_frame
	window_instance.global_position = _calculate_window_position(parent_window, window_instance)

func _open_root_inspection_window(loc: LocationIdentifier, source_view: Control):
	# TDD: A new root inspection closes all previous chains.
	close_all_inspection_windows()
	
	var new_group = []
	_inspection_window_groups.append(new_group)
	_open_inspection_window(loc, source_view, new_group)

func _on_selection_changed(new_location: LocationIdentifier):
	# If a new selection is made on a "root" view (not inside an inspection window),
	# close all existing inspection windows.
	if new_location != null:
		var source_view = find_view_by_location(new_location)
		if is_instance_valid(source_view):
			var parent_info = _find_parent_group(source_view)
			# If the new selection is NOT inside an existing inspection window group,
			# it's a "root" selection, so we clear out any old windows.
			if parent_info.group == null:
				close_all_inspection_windows()

# --- Private: Inspection Window Logic ---



func _open_inspection_window(loc: LocationIdentifier, source_view: Control, group: Array):
	# This function handles opening ANY inspection window, which can be for a unit/item or a child (like an effect).
	var window_type: StringName
	var context: Dictionary
	var instance: GachaBallInstance

	# TDD-Compliant Logic:
	# Case 1: The request has a LocationIdentifier. This is the primary, decoupled way to inspect a GachaBall.
	if is_instance_valid(loc):
		var data_owner = get_tree().get_first_node_in_group("battle_manager") as Object if GameManager.is_in_battle else GameManager.run_state as Object
		instance = data_owner.get_instance_by_location(loc)
		if not is_instance_valid(instance):
			printerr("WindowManager: Could not find instance for location: %s" % loc)
			return

		var def = instance.get_definition()
		window_type = &"UnitInspection" if def.category == &"UNIT" else &"ItemInspection"
		context = {"source_view": source_view, "instance": instance}

	# Case 2: The source view itself has metadata for an inspection (e.g., an effect icon inside another window).
	# This view does not have a LocationIdentifier.
	elif source_view.has_meta("effect_definition"):
		var effect_def = source_view.get_meta("effect_definition")
		if effect_def == null: return

		window_type = &"EffectInspection"
		context = {"source_view": source_view, "effect_definition": effect_def}

	else:
		# This is not a valid source for an inspection window.
		printerr("WindowManager: Inspection requested from an invalid source.")
		return
	
	var window_instance = _window_scenes[window_type].instantiate()
	
	group.push_back(window_instance)
	_get_modal_layer().add_child(window_instance)
	
	if window_instance.has_method("populate"):
		window_instance.populate(context)
	
	await get_tree().process_frame
	# It's possible the window was freed during populate if data was invalid.
	if is_instance_valid(window_instance):
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

func find_view_by_location(loc: LocationIdentifier) -> Control:
	if _modal_stack.is_empty() or not is_instance_valid(loc):
		return null
	
	var current_window = _modal_stack.back()
	return _find_view_in_node(current_window, loc)

func _find_view_in_node(node: Node, loc: LocationIdentifier) -> Control:
	if node.has_meta("location_identifier"):
		var node_loc = node.get_meta("location_identifier")
		if node_loc.is_equal(loc):
			return node
	
	for child in node.get_children():
		var found = _find_view_in_node(child, loc)
		if is_instance_valid(found):
			return found
	
	return null

func _get_modal_layer() -> CanvasLayer:
	if not is_instance_valid(_modal_layer):
		var nodes = get_tree().get_nodes_in_group("modal_layer")
		if not nodes.is_empty(): _modal_layer = nodes[0]
		else:
			printerr("WindowManager: CRITICAL - No node in group 'modal_layer'.")
			_modal_layer = CanvasLayer.new()
			get_tree().root.add_child(_modal_layer)
	return _modal_layer
