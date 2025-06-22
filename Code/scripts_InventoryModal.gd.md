<!-- Original: scripts/InventoryModal.gd -->

```gdscript
# res://scripts/InventoryModal.gd
extends Control

const GACHA_BALL_VIEW_SCENE = preload("res://scenes/GachaBallView.tscn")

@export var title_label: Label
@export var tier_1_grid: GridContainer
@export var tier_2_grid: GridContainer
@export var tier_3_grid: GridContainer

var _is_displaying_run_inventory: bool = false

func _ready():
    EventBus.close_modal_requested.connect(queue_free)

func _notification(what):
    if what == NOTIFICATION_PREDELETE:
        if _is_displaying_run_inventory and GameManager.is_connected("run_inventory_changed", _populate_grids):
            GameManager.run_inventory_changed.disconnect(_populate_grids)

func display(source_inventory: Dictionary, title: String, connect_to_refresh: bool = false):
    title_label.text = title
    
    if connect_to_refresh:
        _is_displaying_run_inventory = true
        if not GameManager.is_connected("run_inventory_changed", _populate_grids):
            GameManager.run_inventory_changed.connect(_populate_grids)
    
    _populate_grids(source_inventory)

func _populate_grids(inventory_data: Dictionary = GameManager.run_state.run_inventory):
    # Clear all grids first
    for child in tier_1_grid.get_children(): child.queue_free()
    for child in tier_2_grid.get_children(): child.queue_free()
    for child in tier_3_grid.get_children(): child.queue_free()

    if not inventory_data:
        return

    var grids = {
        1: tier_1_grid,
        2: tier_2_grid,
        3: tier_3_grid,
        0: tier_1_grid # Hero (Tier 0) goes into the Tier 1 grid for display
    }

    for tier in inventory_data:
        if not grids.has(tier): continue
        var target_grid = grids[tier]
        for instance in inventory_data[tier]:
            var view = GACHA_BALL_VIEW_SCENE.instantiate()
            target_grid.add_child(view)
            view.set_instance_data(instance)
```