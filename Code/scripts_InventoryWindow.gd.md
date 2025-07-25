<!-- Original: scripts/InventoryWindow.gd -->

```gdscript
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

	_initialize_grids_if_needed()

	# Use Variant type to handle both BattleManager and RunState types
	var data_owner = null
	if _is_battle_context:
		data_owner = get_tree().get_first_node_in_group("battle_manager")
	else:
		data_owner = GameManager.run_state

	if not is_instance_valid(data_owner):
		return

	# Track which items are currently equipped
	var equipped_item_uuids := {}
	var unit_container_names: Array[StringName] = [&"PlayerLineup", &"PlayerBench"]
	
	for container_name in unit_container_names:
		var unit_container = data_owner.get_container(container_name)
		if is_instance_valid(unit_container):
			for uuid in unit_container.get_all_non_empty_uuids():
				var unit_instance = GameManager.get_instance_by_uuid(uuid)
				if is_instance_valid(unit_instance):
					for item_uuid in unit_instance.equipped_item_uuids:
						if not item_uuid.is_empty():
							equipped_item_uuids[item_uuid] = true

	# Set up the grid containers
	var grids = { 1: tier_1_grid, 2: tier_2_grid, 3: tier_3_grid }
	var newly_created_views: Dictionary = {}

	# Populate each grid
	for tier in grids:
		var grid_node = grids[tier]
		var container_name: StringName = &"RunInventoryT%d" % tier if not _is_battle_context else &"BattleInventoryT%d" % tier
		var container = _data_source.get(container_name)
		if not is_instance_valid(container):
			continue

		var all_uuids = container.get_all_uuids()
		var slot_views = grid_node.get_children()

		for i in range(slot_views.size()):
			var slot_view: SlotView = slot_views[i]
			# Clear any existing content
			for child in slot_view.get_children():
				child.queue_free()

			# Create location and populate the slot
			var loc = LocationIdentifier.new(container_name, i)
			slot_view.populate(loc)

			# Skip if beyond current data
			if i >= all_uuids.size():
				continue

			var uuid_at_slot = all_uuids[i]

			# Skip empty or equipped items
			if uuid_at_slot.is_empty() or equipped_item_uuids.has(uuid_at_slot):
				continue

			# Create and populate the GachaBallView
			var instance = GameManager.get_instance_from_location(loc)
			if is_instance_valid(instance):
				var gacha_view = _GachaBallView.instantiate()
				slot_view.add_child(gacha_view)
				gacha_view.populate(loc, instance, true)
				newly_created_views[str(loc.container) + str(loc.index)] = gacha_view

	# Re-sync selection highlight after redraw
	var selected_loc = InteractionManager.get_selected_location()
	if is_instance_valid(selected_loc):
		var loc_key = str(selected_loc.container) + str(selected_loc.index)
		if newly_created_views.has(loc_key):
			var view_to_highlight = newly_created_views[loc_key]
			EventBus.emit_signal("view_selected", view_to_highlight, selected_loc)
			InteractionManager._selected_view = view_to_highlight

```