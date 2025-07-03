# res://scripts/tests/TestInspectionSystem.gd
extends Control

const TEST_ITEM_VIEW_SCENE = preload("res://scenes/tests/TestItemView.tscn")
const TEST_INVENTORY_MODAL_SCENE = preload("res://scenes/tests/TestInventoryModal.tscn")

@onready var open_inventory_button: Button = %OpenInventoryButton
@onready var item_grid: GridContainer = %ItemGrid
@onready var modal_layer: CanvasLayer = %ModalLayer
@onready var test_window_manager: TestWindowManager = $TestWindowManager

var _active_modal = null

var _test_item_db = {
	"sword": {"id": "sword", "name": "Sword", "desc": "A sharp sword.", "children": [
		{"id": "effect_sharp", "name": "Sharp", "desc": "Deals extra damage.", "children": []}
	]},
	"shield": {"id": "shield", "name": "Shield", "desc": "A sturdy shield.", "children": [
		{"id": "effect_block", "name": "Block", "desc": "Reduces incoming damage.", "children": []},
		{"id": "effect_reflect", "name": "Reflect", "desc": "Returns some damage.", "children": [
			{"id": "sub_effect_fire", "name": "Fire", "desc": "Also burns the attacker.", "children": []}
		]}
	]},
	"potion": {"id": "potion", "name": "Potion", "desc": "A healing potion.", "children": []}
}

var _test_inventory_data = {
	"1": [
		{"id": "inv_sword", "name": "Inv Sword", "desc": "An inventory sword."},
		{"id": "inv_potion", "name": "Inv Potion", "desc": "An inventory potion."},
	],
	"2": [
		{"id": "inv_shield", "name": "Inv Shield", "desc": "An inventory shield.", "children": [
			{"id": "inv_reflect", "name": "Inv Reflect", "desc": "Reflects damage."}
		]}
	]
}

func _ready():
	test_window_manager.initialize(modal_layer)
	open_inventory_button.pressed.connect(_on_open_inventory_pressed)
	
	# The test system now properly uses the global EventBus for inspection requests,
	# just like the main game.
	EventBus.inspection_requested.connect(test_window_manager.open_inspection_window)
	
	# Populate the main screen with some items
	for item_id in _test_item_db:
		var item_data = _test_item_db[item_id]
		var view = TEST_ITEM_VIEW_SCENE.instantiate()
		item_grid.add_child(view)
		view.initialize(item_data)
		# NOTE: The connection is no longer made here. The view now talks to InteractionManager.

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		# This is the final fallback for a "global background click".
		var click_pos = event.global_position
		
		# Ignore if click is inside the modal content area
		if is_instance_valid(_active_modal) and _active_modal.get_node("PanelContainer").get_global_rect().has_point(click_pos):
			return
			
		# Ignore if click is inside any inspection window.
		for window in test_window_manager.get_all_windows():
			if is_instance_valid(window) and window.get_global_rect().has_point(click_pos):
				return
		
		# If we get here, it's a true background click.
		get_viewport().set_input_as_handled()
		InteractionManager.clear_selection()
		test_window_manager.close_all_inspection_windows()

func _close_active_modal():
	if is_instance_valid(_active_modal):
		# We must disconnect the one-shot signal to prevent an error if the modal
		# is closed by other means (e.g. opening a new one).
		if EventBus.is_connected("background_clicked", _close_active_modal):
			EventBus.background_clicked.disconnect(_close_active_modal)
		
		# Prevent orphaned windows by closing any inspections spawned from the modal.
		InteractionManager.clear_selection()
		test_window_manager.close_all_inspection_windows()
		
		_active_modal.queue_free()
		_active_modal = null

func _on_open_inventory_pressed():
	# Prevent orphaned windows by closing any main-screen inspections before opening modal.
	InteractionManager.clear_selection()
	test_window_manager.close_all_inspection_windows()
	
	_close_active_modal()
		
	_active_modal = TEST_INVENTORY_MODAL_SCENE.instantiate()
	modal_layer.add_child(_active_modal)
	_active_modal.populate(_test_inventory_data, test_window_manager)
	
	# The background blocker now correctly handles closing its own modal.
	EventBus.background_clicked.connect(_close_active_modal, CONNECT_ONE_SHOT)
