<!-- Original: scripts/InventoryModal.gd -->

```gdscript
# res://scripts/InventoryModal.gd
extends Control

const GACHA_BALL_VIEW_SCENE = preload("res://scenes/GachaBallView.tscn")

@onready var title_label: Label = %TitleLabel
@onready var tier_1_grid: GridContainer = %Tier1Grid
@onready var tier_2_grid: GridContainer = %Tier2Grid
@onready var tier_3_grid: GridContainer = %Tier3Grid

var _connect_to_refresh: bool = false

func _ready():
	EventBus.close_modal_requested.connect(queue_free)

func _exit_tree():
	if _connect_to_refresh and EventBus.is_connected("run_inventory_changed", _populate_grids_from_run_inventory):
		EventBus.run_inventory_changed.disconnect(_populate_grids_from_run_inventory)

func populate(context: Dictionary):
	title_label.text = context.get("title", "Inventory")
	var is_interactive = context.get("is_interactive", true)
	_connect_to_refresh = context.get("connect_to_refresh", false)
	
	if _connect_to_refresh:
		if not EventBus.is_connected("run_inventory_changed", _populate_grids_from_run_inventory):
			EventBus.run_inventory_changed.connect(_populate_grids_from_run_inventory)
	
	_populate_grids(context.get("inventory", {}), is_interactive)

func _populate_grids_from_run_inventory():
	if is_instance_valid(GameManager.run_state):
		_populate_grids(GameManager.run_state.run_inventory, true)

func _populate_grids(inventory_data: Dictionary, is_interactive: bool):
	var grids = { 1: tier_1_grid, 2: tier_2_grid, 3: tier_3_grid }
	
	for grid in grids.values():
		for child in grid.get_children():
			child.queue_free()

	if not inventory_data: return

	for tier in inventory_data:
		if not grids.has(tier): continue
		var target_grid = grids[tier]
		for instance in inventory_data[tier]:
			var view = GACHA_BALL_VIEW_SCENE.instantiate()
			target_grid.add_child(view)
			view.set_instance_data(instance)
			view.is_interactable = is_interactive

```