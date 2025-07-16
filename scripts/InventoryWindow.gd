class_name InventoryWindow
extends Control

const LocationIdentifier = preload("res://scripts/LocationIdentifier.gd")
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

func _ready():
	panel_container.gui_input.connect(_on_panel_gui_input)
	EventBus.inventory_ui_refresh_requested.connect(_on_ui_refresh)

func _exit_tree():
	if EventBus.is_connected("inventory_ui_refresh_requested", _on_ui_refresh):
		EventBus.inventory_ui_refresh_requested.disconnect(_on_ui_refresh)

func populate(context: Dictionary):
	title_label.text = context.get("title", "Inventory")
	_is_battle_context = context.get("is_battle_context", false)
	_data_source = context.get("inventory")
	
	# Trigger the initial population and drawing of the grids.
	_populate_grids()

func _on_ui_refresh():
	if not self.visible:
		return
	# On refresh, just re-populate the content of the existing slots.
	_populate_grids()

func _on_panel_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if InteractionManager.is_drag_active():
			InteractionManager.end_drag(false)
			return
		WindowManager.close_all_inspection_windows()
		get_viewport().set_input_as_handled()

func _initialize_grids_if_needed():
	if _grids_initialized:
		return
	
	var grids = { 1: tier_1_grid, 2: tier_2_grid, 3: tier_3_grid }
	for tier in grids:
		var grid_node = grids[tier]
		var container_name = &"RunInventoryT%d" % tier if not _is_battle_context else &"BattleInventoryT%d" % tier
		var container = _data_source.get(container_name)
		if not is_instance_valid(container):
			continue
			
		var slot_count = container.get_all_uuids().size()
		for i in range(slot_count):
			var slot_view = _SlotView.instantiate()
			grid_node.add_child(slot_view)
	
	_grids_initialized = true

func _populate_grids():
	if not _data_source:
		return

	# This will create the 16 SlotViews per grid, but only on the first run.
	_initialize_grids_if_needed()

	var data_owner = get_tree().get_first_node_in_group("battle_manager") if _is_battle_context else GameManager.run_state
	if not is_instance_valid(data_owner):
		return

	# --- Step 1: Correctly identify all equipped items ---
	var equipped_item_uuids := {}
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
	var grids = { 1: tier_1_grid, 2: tier_2_grid, 3: tier_3_grid }
	for tier in grids:
		var grid_node = grids[tier]
		var container_name = &"RunInventoryT%d" % tier if not _is_battle_context else &"BattleInventoryT%d" % tier
		var container = _data_source.get(container_name)
		if not is_instance_valid(container):
			continue

		var all_uuids = container.get_all_uuids()
		var slot_views = grid_node.get_children()

		for i in range(slot_views.size()):
			var slot_view: SlotView = slot_views[i]
			# Clear any previous content (like a GachaBallView) from the slot.
			for child in slot_view.get_children():
				child.queue_free()

			var loc = LocationIdentifier.new(container_name, i)
			slot_view.populate(loc) # Always update the location data on the slot

			if i >= all_uuids.size(): continue # Should not happen with growable containers

			var uuid_at_slot = all_uuids[i]
			if uuid_at_slot.is_empty() or equipped_item_uuids.has(uuid_at_slot):
				continue # Leave the slot empty

			var instance = GameManager.get_instance_from_location(loc)
			if is_instance_valid(instance):
				var gacha_view = _GachaBallView.instantiate()
				slot_view.add_child(gacha_view)
				gacha_view.populate(loc, instance, true)
