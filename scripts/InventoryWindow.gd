class_name InventoryWindow
extends Control

const _GachaBallView = preload("res://scenes/GachaBallView.tscn")
const _SlotView = preload("res://scenes/SlotView.tscn")

@onready var panel_container: PanelContainer = %PanelContainer
@onready var title_label: Label = %TitleLabel
@onready var tier_1_grid: GridContainer = %Tier1Grid
@onready var tier_2_grid: GridContainer = %Tier2Grid
@onready var tier_3_grid: GridContainer = %Tier3Grid

var _is_battle_context: bool = false
var _data_source: Dictionary
var _grids_initialized: bool = false

func _ready() -> void:
	panel_container.gui_input.connect(_on_panel_gui_input)
	SignalBus.inventory_ui_refresh_requested.connect(_on_ui_refresh)
	tier_1_grid.gui_input.connect(_on_grid_gui_input)
	tier_2_grid.gui_input.connect(_on_grid_gui_input)
	tier_3_grid.gui_input.connect(_on_grid_gui_input)
	
	# Connect to locale changes
	SignalBus.locale_changed.connect(_update_localized_text)

func _update_localized_text() -> void:
	# Update tier labels if they exist
	var tier_labels = get_tree().get_nodes_in_group("tier_labels")
	for label in tier_labels:
		if label.name == "Tier1Label":
			label.text = tr("ui.tier_1")
		elif label.name == "Tier2Label":
			label.text = tr("ui.tier_2")
		elif label.name == "Tier3Label":
			label.text = tr("ui.tier_3")

func _exit_tree() -> void:
	if SignalBus.is_connected("inventory_ui_refresh_requested", _on_ui_refresh):
		SignalBus.inventory_ui_refresh_requested.disconnect(_on_ui_refresh)
	# Disconnect child gui_input hooks if still connected
	if is_instance_valid(panel_container) and panel_container.gui_input.is_connected(_on_panel_gui_input):
		panel_container.gui_input.disconnect(_on_panel_gui_input)
	if is_instance_valid(tier_1_grid) and tier_1_grid.gui_input.is_connected(_on_grid_gui_input):
		tier_1_grid.gui_input.disconnect(_on_grid_gui_input)
	if is_instance_valid(tier_2_grid) and tier_2_grid.gui_input.is_connected(_on_grid_gui_input):
		tier_2_grid.gui_input.disconnect(_on_grid_gui_input)
	if is_instance_valid(tier_3_grid) and tier_3_grid.gui_input.is_connected(_on_grid_gui_input):
		tier_3_grid.gui_input.disconnect(_on_grid_gui_input)
	# Ensure any active drag is ended before this window and its children are freed
	if GlobalInteractionRouter.is_drag_active():
		GlobalInteractionRouter.end_drag(false)
		GlobalInteractionRouter.end_drag_visuals(false)

func populate(context: Dictionary) -> void:
	title_label.text = context.get("title", "Inventory")
	_is_battle_context = context.get("is_battle_context", false)
	_data_source = context.get("inventory")
	
	# Trigger the initial population and drawing of the grids.
	_populate_grids()

func _on_ui_refresh() -> void:
	if not self.visible:
		return
	# On refresh, just re-populate the content of the existing slots.
	_populate_grids()

func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if GlobalInteractionRouter.is_drag_active():
			GlobalInteractionRouter.end_drag(false)
			return
		
		# Create and emit InteractionContext for window background
		var context = InteractionContext.new()
		context.source_view_instance_id = get_instance_id()
		context.event_type = &"SINGLE_CLICK"
		context.location = null # No specific location for background
		context.entity_uuid = ""
		context.entity_type = &"WINDOW_BACKGROUND"
		context.interaction_mode = &"FULLY_INTERACTIVE"
		context.window_group_id = 1 # Inspection windows group
		
		SignalBus.emit_signal("interaction_context_received", context)
		get_viewport().set_input_as_handled()

func _on_grid_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Only clear selection if the click is not on a SlotView
		var target = get_viewport().gui_get_focus_owner()
		if not (target and target is SlotView):
			# Create and emit InteractionContext for grid background
			var context = InteractionContext.new()
			context.source_view_instance_id = get_instance_id()
			context.event_type = &"SINGLE_CLICK"
			context.location = null # No specific location for grid background
			context.entity_uuid = ""
			context.entity_type = &"WINDOW_BACKGROUND"
			context.interaction_mode = &"FULLY_INTERACTIVE"
			context.window_group_id = 1 # Inspection windows group
			
			SignalBus.emit_signal("interaction_context_received", context)
			get_viewport().set_input_as_handled()

func _initialize_grids_if_needed() -> void:
	if _grids_initialized:
		return
	
	# Inventory uses 2x scale (192x192px) square slots with no gaps (Matches 2x gachaball)
	const INVENTORY_SLOT_SIZE: int = 192
	
	var grids: Dictionary = {1: tier_1_grid, 2: tier_2_grid, 3: tier_3_grid}
	for tier in grids:
		var grid_node = grids[tier]
		var container_name = &"RunInventoryT%d" % tier if not _is_battle_context else &"BattleInventoryT%d" % tier
		var container: DataContainer = _data_source.get(container_name)
		if not is_instance_valid(container):
			continue
			
		var slot_count = container.get_all_uuids().size()
		for i in range(slot_count):
			var slot_view = _SlotView.instantiate()
			# Use 2x scale for inventory window (same as battle board)
			slot_view.set_size_scale(2.0)
			# Force square slots matching 2x sprite size
			slot_view.custom_minimum_size = Vector2(INVENTORY_SLOT_SIZE, INVENTORY_SLOT_SIZE)
			grid_node.add_child(slot_view)
			# Configure interaction context for run inventory slots (FULLY_INTERACTIVE)
			slot_view.set_interaction_context(&"FULLY_INTERACTIVE", 0)
		
	
	_grids_initialized = true

func _populate_grids() -> void:
	if not _data_source:
		return

	# This will create the 16 SlotViews per grid, but only on the first run.
	_initialize_grids_if_needed()

	var data_owner = get_tree().get_first_node_in_group("battle_manager") if _is_battle_context else GameManager.run_state
	if not is_instance_valid(data_owner):
		return

	# --- Step 1: Correctly identify all equipped items ---
	var equipped_item_uuids: Dictionary = {}
	var unit_container_names: Array[StringName] = [&"PlayerLineup", &"PlayerBench"]
	for container_name in unit_container_names:
		var unit_container = data_owner.get_container(container_name)
		if is_instance_valid(unit_container):
			var all_uuids_in_container = unit_container.get_all_uuids()
			for i in range(all_uuids_in_container.size()):
				var loc = LocationIdentifier.new(container_name, i)
				var unit_instance = GameManager.get_instance_from_location(loc)
				if is_instance_valid(unit_instance):
					for item_uuid in unit_instance.equipped_item_uuids:
						if not item_uuid.is_empty():
							equipped_item_uuids[item_uuid] = true

	# --- Step 2: Iterate through the persistent slots and update their content ---
	var grids: Dictionary = {1: tier_1_grid, 2: tier_2_grid, 3: tier_3_grid}
	for tier in grids:
		var grid_node = grids[tier]
		var container_name = &"RunInventoryT%d" % tier if not _is_battle_context else &"BattleInventoryT%d" % tier
		var container: DataContainer = _data_source.get(container_name)
		if not is_instance_valid(container):
			continue

		var all_uuids = container.get_all_uuids()
		var slot_views = grid_node.get_children()

		for i in range(slot_views.size()):
			var slot_view: SlotView = slot_views[i]
			# Clear any previous content (except indicator overlay)
			for child in slot_view.get_children():
				# Skip the indicator overlay (TextureRect with z_index 10)
				if child is TextureRect and child.z_index == 10:
					continue
				child.queue_free()

			var loc = LocationIdentifier.new(container_name, i)
			slot_view.populate(loc) # Always update the location data on the slot
			# Ensure interaction context is set for run inventory
			slot_view.set_interaction_context(&"FULLY_INTERACTIVE", 0)

			if i >= all_uuids.size(): continue # Should not happen with growable containers

			var uuid_at_slot = all_uuids[i]
			if uuid_at_slot.is_empty() or equipped_item_uuids.has(uuid_at_slot):
				continue # Leave the slot empty

			var instance = GameManager.get_instance_from_location(loc)
			if is_instance_valid(instance):
				# Use adapter to create visual data
				var visual_data = VisualDataAdapter.create_visual_data(instance)
				slot_view.set_content(visual_data, true, false, false)
				
				# Configure interaction context - find GachaBallView among children
				var gacha_view: GachaBallView = null
				for child in slot_view.get_children():
					if child is GachaBallView:
						gacha_view = child
						break
				if is_instance_valid(gacha_view):
					gacha_view.set_interaction_context(&"FULLY_INTERACTIVE", instance.get_definition().category, 0)
