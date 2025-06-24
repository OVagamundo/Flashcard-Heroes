<!-- Original: scripts/InventoryModal.gd -->

```gdscript
# res://scripts/InventoryModal.gd
extends Control

const GACHA_BALL_VIEW_SCENE = preload("res://scenes/GachaBallView.tscn")

@onready var title_label: Label = %TitleLabel
@onready var tier_1_grid: GridContainer = %Tier1Grid
@onready var tier_2_grid: GridContainer = %Tier2Grid
@onready var tier_3_grid: GridContainer = %Tier3Grid

var _is_displaying_run_inventory: bool = false
var _is_interactable: bool = true

func _ready():
	EventBus.close_modal_requested.connect(queue_free)

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if _is_displaying_run_inventory and GameManager.is_connected("run_inventory_changed", _populate_grids_from_run_inventory):
			GameManager.run_inventory_changed.disconnect(_populate_grids_from_run_inventory)

## Configures and displays the inventory modal.
## source_inventory: The tiered dictionary of GachaBallInstances to display.
## title: The text to show at the top of the modal.
## connect_to_refresh: If true, connects to GameManager.run_inventory_changed for auto-updates.
## is_interactable: If false, the GachaBallViews inside cannot be clicked or dragged.
func display(source_inventory: Dictionary, title: String, connect_to_refresh: bool = false, is_interactable: bool = true):
	title_label.text = title
	self._is_interactable = is_interactable
	
	if connect_to_refresh:
		_is_displaying_run_inventory = true
		if not GameManager.is_connected("run_inventory_changed", _populate_grids_from_run_inventory):
			GameManager.run_inventory_changed.connect(_populate_grids_from_run_inventory)
	
	_populate_grids(source_inventory)

# Wrapper function for the signal connection, which requires a no-argument method.
func _populate_grids_from_run_inventory():
	if is_instance_valid(GameManager.run_state):
		_populate_grids(GameManager.run_state.run_inventory)

func _populate_grids(inventory_data: Dictionary):
	# Clear all grids first
	for child in tier_1_grid.get_children(): child.queue_free()
	for child in tier_2_grid.get_children(): child.queue_free()
	for child in tier_3_grid.get_children(): child.queue_free()

	if not inventory_data:
		return

	var grids = {
		0: tier_1_grid, # Hero (Tier 0) goes into the Tier 1 grid for display
		1: tier_1_grid,
		2: tier_2_grid,
		3: tier_3_grid,
	}

	for tier in inventory_data:
		if not grids.has(tier): continue
		var target_grid = grids[tier]
		for instance in inventory_data[tier]:
			var view = GACHA_BALL_VIEW_SCENE.instantiate()
			target_grid.add_child(view)
			view.set_instance_data(instance)
			view.is_interactable = _is_interactable

```