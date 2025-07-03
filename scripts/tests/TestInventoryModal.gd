# res://scripts/tests/TestInventoryModal.gd
extends Control
class_name TestInventoryModal

const TEST_ITEM_VIEW_SCENE = preload("res://scenes/tests/TestItemView.tscn")

@onready var panel_container: PanelContainer = %PanelContainer
@onready var tier_1_grid: GridContainer = %Tier1Grid
@onready var tier_2_grid: GridContainer = %Tier2Grid

var _test_window_manager: Node

func _ready():
	panel_container.gui_input.connect(_on_panel_gui_input)
	var blocker = find_child("BackgroundBlocker")
	if blocker:
		# The blocker emits a global EventBus signal. We listen to that signal
		# in the main test script, not here. This direct connection was incorrect
		# and causing a crash.
		pass

func _on_panel_gui_input(event: InputEvent):
	# This is the key logic for "clicking on the empty grid area".
	# If a click reaches this panel, it means it wasn't on a button or an item.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# The responsibility for closing windows is now fully on the manager.
		# This control only needs to handle its own behavior.
		# For a click on the background of the modal, we want to close any
		# open inspection windows that came from it.
		if _test_window_manager:
			_test_window_manager.close_all_inspection_windows()
		get_viewport().set_input_as_handled()

func populate(inventory_data: Dictionary, test_window_manager: Node):
	_test_window_manager = test_window_manager
	var grids = { 1: tier_1_grid, 2: tier_2_grid }
	
	for grid in grids.values():
		for child in grid.get_children():
			child.queue_free()

	if not inventory_data: return
	
	for tier_str in inventory_data:
		var tier = int(tier_str)
		if not grids.has(tier): continue
		
		var target_grid = grids[tier]
		var tier_data_array = inventory_data[tier_str]
		
		for item_data in tier_data_array:
			var view = TEST_ITEM_VIEW_SCENE.instantiate()
			target_grid.add_child(view)
			view.initialize(item_data)
