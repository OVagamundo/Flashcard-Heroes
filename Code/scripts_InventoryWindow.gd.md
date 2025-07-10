<!-- Original: scripts/InventoryWindow.gd -->

```gdscript
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

# TDD-compliant container names for the run inventory.
const RUN_CONTAINER_NAMES = {
	1: &"RunInventoryT1",
	2: &"RunInventoryT2",
	3: &"RunInventoryT3",
}

func _ready():
	panel_container.gui_input.connect(_on_panel_gui_input)

func _exit_tree():
	if EventBus.is_connected("run_data_changed", _populate_grids_from_run_inventory):
		EventBus.run_data_changed.disconnect(_populate_grids_from_run_inventory)
	if EventBus.is_connected("battle_inventory_changed", _populate_grids_from_battle_inventory):
		EventBus.battle_inventory_changed.disconnect(_populate_grids_from_battle_inventory)

func populate(context: Dictionary):
	title_label.text = context.get("title", "Inventory")
	var is_interactive = context.get("is_interactive", true)
	_is_battle_context = context.get("is_battle_context", false)
	
	if _is_battle_context:
		if not EventBus.is_connected("battle_inventory_changed", _populate_grids_from_battle_inventory):
			EventBus.battle_inventory_changed.connect(_populate_grids_from_battle_inventory)
	else: # Run context
		if not EventBus.is_connected("run_data_changed", _populate_grids_from_run_inventory):
			EventBus.run_data_changed.connect(_populate_grids_from_run_inventory)
	
	_populate_grids(context.get("inventory", {}), is_interactive)

func _populate_grids_from_run_inventory():
	if not is_instance_valid(GameManager.run_state):
		return

	var inventory_data = {}
	for tier in RUN_CONTAINER_NAMES:
		var container_name = RUN_CONTAINER_NAMES[tier]
		var container = GameManager.run_state.get_container(container_name)
		if not is_instance_valid(container):
			continue

		var tier_data_array = []
		var uuids = container.get_all_uuids()
		for uuid in uuids:
			if uuid.is_empty():
				tier_data_array.append(null)
			else:
				var instance = GameManager.run_state.run_instances.get(uuid)
				tier_data_array.append(instance)
		
		inventory_data[tier] = tier_data_array

	_populate_grids(inventory_data, true)

func _on_panel_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if InteractionManager.is_drag_active():
			InteractionManager.end_drag(false)
			return
		WindowManager.close_all_inspection_windows()
		get_viewport().set_input_as_handled()

func _populate_grids_from_battle_inventory():
	var battle_manager = get_tree().get_first_node_in_group("battle_manager")
	if is_instance_valid(battle_manager):
		_populate_grids(battle_manager.get_battle_inventory(), true)

func _populate_grids(inventory_data: Dictionary, is_interactive: bool):
	var grids = { 1: tier_1_grid, 2: tier_2_grid, 3: tier_3_grid }
	
	var equipped_item_uuids = {} # Using a Dictionary as a HashSet
	if _is_battle_context:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		if is_instance_valid(bm):
			var all_unit_uuids = bm.get_container(&"PlayerLineup").get_all_uuids() + bm.get_container(&"PlayerBench").get_all_uuids()
			for unit_uuid in all_unit_uuids:
				var unit_instance = bm.get_instance_from_uuid(unit_uuid)
				if is_instance_valid(unit_instance):
					for item_uuid in unit_instance.equipped_item_uuids:
						if not item_uuid.is_empty():
							equipped_item_uuids[item_uuid] = true

	for grid in grids.values():
		for child in grid.get_children():
			child.queue_free()

	if not inventory_data: return
	
	for tier in grids:
		if not inventory_data.has(tier): continue
		
		var target_grid = grids[tier]
		var tier_data_array = inventory_data[tier]
		
		for i in range(tier_data_array.size()):
			var instance = tier_data_array[i]
			var loc = LocationIdentifier.new()
			loc.tier = tier
			loc.index = i
			# Use the correct container name based on context
			if _is_battle_context:
				# TODO: Battle inventory containers might have different names
				loc.container = &"Tier%dInventory" % tier # Placeholder
			else:
				loc.container = RUN_CONTAINER_NAMES[tier]
			
			var is_equipped = is_instance_valid(instance) and equipped_item_uuids.has(instance.ball_uuid)

			if is_instance_valid(instance) and not is_equipped:
				var view = _GachaBallView.instantiate()
				target_grid.add_child(view)
				view.populate(loc, instance, is_interactive)
			elif is_interactive:
				var slot_view = _SlotView.instantiate()
				target_grid.add_child(slot_view)
				slot_view.populate(loc)

```