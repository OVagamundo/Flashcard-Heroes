# res://scripts/InventoryModal.gd
extends Control

const GACHA_BALL_VIEW_SCENE = preload("res://scenes/GachaBallView.tscn")
const SLOT_VIEW_SCENE = preload("res://scenes/SlotView.tscn")

@onready var panel_container: PanelContainer = %PanelContainer
@onready var title_label: Label = %TitleLabel
@onready var tier_1_grid: GridContainer = %Tier1Grid
@onready var tier_2_grid: GridContainer = %Tier2Grid
@onready var tier_3_grid: GridContainer = %Tier3Grid

var _is_battle_context: bool = false

func _ready():
	# Connect the panel's input signal to our new handler.
	panel_container.gui_input.connect(_on_panel_gui_input)

func _exit_tree():
	if EventBus.is_connected("run_inventory_changed", _populate_grids_from_run_inventory):
		EventBus.run_inventory_changed.disconnect(_populate_grids_from_run_inventory)
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
		if not EventBus.is_connected("run_inventory_changed", _populate_grids_from_run_inventory):
			EventBus.run_inventory_changed.connect(_populate_grids_from_run_inventory)
	
	_populate_grids(context.get("inventory", {}), is_interactive)

func _populate_grids_from_run_inventory():
	if is_instance_valid(GameManager.run_state):
		_populate_grids(GameManager.run_state.run_inventory, true)

# This new function is the fix. It mirrors the logic from the test scene.
func _on_panel_gui_input(event: InputEvent):
	# If a click reaches this panel, it means it wasn't on a button or an item view.
	# This is a click on the modal's own "background".
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Tell the global manager to close any open inspection windows.
		WindowManager.close_all_inspection_windows()
		# Consume the input so it doesn't also trigger the BackgroundBlocker behind this panel.
		get_viewport().set_input_as_handled()

func _populate_grids_from_battle_inventory():
	var battle_manager = get_tree().get_first_node_in_group("battle_manager")
	if is_instance_valid(battle_manager):
		_populate_grids(battle_manager.get_battle_inventory(), true)

func _populate_grids(inventory_data: Dictionary, is_interactive: bool):
	var grids = { 1: tier_1_grid, 2: tier_2_grid, 3: tier_3_grid }
	
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
			
			if is_instance_valid(instance):
				var view = GACHA_BALL_VIEW_SCENE.instantiate()
				target_grid.add_child(view)
				view.set_instance_data(instance)
				view.initialize(tier, i)
				view.is_selectable = is_interactive
			elif is_interactive:
				var slot_view = SLOT_VIEW_SCENE.instantiate()
				target_grid.add_child(slot_view)
				slot_view.initialize(tier, i)
