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

# Maximum slots per tier grid as per TDD table 2.2
const RUN_GRID_CAPACITY = 16

func _ready():
	panel_container.gui_input.connect(_on_panel_gui_input)

func _exit_tree():
	if EventBus.is_connected("inventory_ui_refresh_requested", _on_ui_refresh):
		EventBus.inventory_ui_refresh_requested.disconnect(_on_ui_refresh)

func _on_ui_refresh():
	if not self.visible: 
		return
		
	var data_owner = get_tree().get_first_node_in_group("battle_manager") if _is_battle_context else GameManager.run_state
	if not is_instance_valid(data_owner): 
		return
	
	var inventory_data
	if _is_battle_context:
		inventory_data = data_owner.get_battle_inventory()
	else:
		inventory_data = data_owner.run_inventory_containers
			
	if inventory_data:
		_populate_grids(inventory_data, true)

func populate(context: Dictionary):
	title_label.text = context.get("title", "Inventory")
	var is_interactive = context.get("is_interactive", true)
	_is_battle_context = context.get("is_battle_context", false)
	
	if not EventBus.is_connected("inventory_ui_refresh_requested", _on_ui_refresh):
		EventBus.inventory_ui_refresh_requested.connect(_on_ui_refresh)

	# Initial population call
	_on_ui_refresh()

func _on_panel_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if InteractionManager.is_drag_active():
			InteractionManager.end_drag(false)
			return
		WindowManager.close_all_inspection_windows()
		get_viewport().set_input_as_handled()

func _populate_grids(inventory_data: Dictionary, is_interactive: bool):
	var grids = { 1: tier_1_grid, 2: tier_2_grid, 3: tier_3_grid }
	for grid in grids.values():
		for child in grid.get_children():
			child.queue_free()

	if not inventory_data: 
		return

	var data_owner = get_tree().get_first_node_in_group("battle_manager") if _is_battle_context else GameManager.run_state
	if not is_instance_valid(data_owner): 
		return
		
	var all_instances_db = data_owner.get_all_instances()
	var equipped_item_uuids := {}
	if _is_battle_context:
		var all_unit_uuids = data_owner.get_container(&"PlayerLineup").get_all_uuids() + data_owner.get_container(&"PlayerBench").get_all_uuids()
		for unit_uuid in all_unit_uuids:
			if not unit_uuid.is_empty():
				var unit_instance = all_instances_db.get(unit_uuid)
				if is_instance_valid(unit_instance):
					for item_uuid in unit_instance.equipped_item_uuids:
						if not item_uuid.is_empty():
							equipped_item_uuids[item_uuid] = true

	for tier in grids:
		var target_grid = grids[tier]
		var container_name = &"RunInventoryT%d" % tier if not _is_battle_context else &"BattleInventoryT%d" % tier
		
		if not inventory_data.has(container_name): 
			continue

		var container: DataContainer = inventory_data[container_name]
		if not is_instance_valid(container): 
			continue
		
		var all_uuids = container.get_all_uuids()
		for i in range(all_uuids.size()):
			var uuid = all_uuids[i]
			var instance = all_instances_db.get(uuid) if not uuid.is_empty() else null
			var loc = LocationIdentifier.new()
			loc.tier = tier
			loc.index = i
			loc.container = container_name
			
			var is_equipped = is_instance_valid(instance) and equipped_item_uuids.has(instance.ball_uuid)

			if is_instance_valid(instance) and not is_equipped:
				var view = _GachaBallView.instantiate()
				target_grid.add_child(view)
				view.populate(loc, instance, is_interactive)
			elif is_interactive:
				var slot_view = _SlotView.instantiate()
				target_grid.add_child(slot_view)
				slot_view.populate(loc)
