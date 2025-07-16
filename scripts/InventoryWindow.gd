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

# Maximum slots per tier grid as per TDD table 2.2
const RUN_GRID_CAPACITY = 16

func _ready():
	panel_container.gui_input.connect(_on_panel_gui_input)

func populate(context: Dictionary):
	title_label.text = context.get("title", "Inventory")
	var is_interactive = context.get("is_interactive", true)
	var inventory_data = context.get("inventory", {})
	var is_battle_context = context.get("is_battle_context", false)
	
	# Clear existing grids
	_populate_grids(inventory_data, is_interactive, is_battle_context)

func _on_panel_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if InteractionManager.is_drag_active():
			InteractionManager.end_drag(false)
			return
		WindowManager.close_all_inspection_windows()
		get_viewport().set_input_as_handled()

func _populate_grids(inventory_data: Dictionary, is_interactive: bool, is_battle_context: bool):
	var grids = { 1: tier_1_grid, 2: tier_2_grid, 3: tier_3_grid }
	for grid in grids.values():
		for child in grid.get_children():
			child.queue_free()

	if not inventory_data:
		return

	var data_owner = get_tree().get_first_node_in_group("battle_manager") if is_battle_context else GameManager.run_state
	if not is_instance_valid(data_owner):
		return

	# Determine which items are equipped and should not be shown in the grid
	var equipped_item_uuids := {}
	var unit_container_names: Array[StringName] = [&"PlayerLineup", &"PlayerBench"]
	for container_name in unit_container_names:
		var unit_container = data_owner.get_container(container_name)
		if is_instance_valid(unit_container):
			for unit_uuid in unit_container.get_all_non_empty_uuids():
				var unit_instance = data_owner.get_instance_by_location(LocationIdentifier.new(container_name, unit_container.get_all_uuids().find(unit_uuid)))
				if is_instance_valid(unit_instance):
					for item_uuid in unit_instance.equipped_item_uuids:
						if not item_uuid.is_empty():
							equipped_item_uuids[item_uuid] = true

	# Populate each tier grid with pre-fetched instances
	for tier in grids:
		var target_grid = grids[tier]
		var instances_in_tier = data_owner.get_inventory_tier_instances(tier)
		
		var container_name = &"RunInventoryT%d" % tier if not is_battle_context else &"BattleInventoryT%d" % tier
		var container = data_owner.get_container(container_name)
		var total_slots = container.get_all_uuids().size() if is_instance_valid(container) else instances_in_tier.size()

		var instance_map := {}
		for inst in instances_in_tier:
			instance_map[inst.ball_uuid] = inst

		for i in range(total_slots):
			var uuid_at_slot = container.get_uuid(i) if is_instance_valid(container) else ""
			
			if uuid_at_slot.is_empty() or not instance_map.has(uuid_at_slot):
				if is_interactive:
					var slot_view = _SlotView.instantiate()
					target_grid.add_child(slot_view)
					slot_view.populate(LocationIdentifier.new(container_name, i))
				continue

			if equipped_item_uuids.has(uuid_at_slot):
				continue

			var instance = instance_map[uuid_at_slot]
			var view = _GachaBallView.instantiate()
			target_grid.add_child(view)
			view.populate(LocationIdentifier.new(container_name, i), instance, is_interactive)
