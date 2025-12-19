class_name TestEnvironmentManager
extends Control

# This manager handles the "God Mode" UI and logic for the Test Environment.
# It is instantiated into the TestBattle scene.

var battle_manager: BattleManager

var debug_panel: PanelContainer
var unit_list: ItemList
var item_list: ItemList
var trinket_list: ItemList

var _selected_unit_id: StringName
var _selected_item_id: StringName
var _selected_trinket_id: StringName
var _spawn_target_is_enemy: bool = false


func _ready() -> void:
	# Self-destruct if not in test mode
	if not GameManager.is_test_mode:
		queue_free()
		return

	if not OS.is_debug_build():
		queue_free()
		return
	
	# Get BattleManager from parent (sibling node)
	battle_manager = get_parent().get_node("BattleManager")
	assert(is_instance_valid(battle_manager), "TestEnvironmentManager: Could not find BattleManager")
		
	# Wait for BattleManager to be ready
	await get_tree().process_frame

	battle_manager.is_test_mode = true
	_build_ui()
	_setup_debug_ui()


func _build_ui() -> void:
	# Create a CanvasLayer to ensure the debug UI is always on top and uses screen coordinates
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100 # High z-index
	add_child(canvas_layer)
	
	# Create Debug Panel
	debug_panel = PanelContainer.new()
	debug_panel.name = "DebugPanel"
	canvas_layer.add_child(debug_panel)
	
	# Position: Bottom Center
	debug_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	debug_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	debug_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	debug_panel.custom_minimum_size = Vector2(400, 300)
	
	# Apply margin from bottom (negative value moves it up)
	# Note: With PRESET_CENTER_BOTTOM, offset_bottom is 0 by default.
	debug_panel.offset_bottom = -20
	debug_panel.offset_top = -320 # Height 300 + Margin 20
	
	# Make Draggable
	debug_panel.gui_input.connect(_on_debug_panel_gui_input)
	
	var vbox = VBoxContainer.new()
	debug_panel.add_child(vbox)
	
	var label = Label.new()
	label.text = "DEBUG MENU (Drag to Move)"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)


	var tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tab_container)
	
	# Units Tab
	var units_tab = VBoxContainer.new()
	units_tab.name = "Units"
	tab_container.add_child(units_tab)
	
	unit_list = ItemList.new()
	unit_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	unit_list.item_selected.connect(_on_unit_list_item_selected)
	units_tab.add_child(unit_list)
	
	var spawn_unit_btn = Button.new()
	spawn_unit_btn.text = "Spawn Unit"
	spawn_unit_btn.pressed.connect(_on_spawn_unit_pressed)
	units_tab.add_child(spawn_unit_btn)

	# Items Tab
	var items_tab = VBoxContainer.new()
	items_tab.name = "Items"
	tab_container.add_child(items_tab)
	
	item_list = ItemList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.item_selected.connect(_on_item_list_item_selected)
	items_tab.add_child(item_list)
	
	var spawn_item_btn = Button.new()
	spawn_item_btn.text = "Spawn Item"
	spawn_item_btn.pressed.connect(_on_spawn_item_pressed)
	items_tab.add_child(spawn_item_btn)

	# Trinkets Tab
	var trinkets_tab = VBoxContainer.new()
	trinkets_tab.name = "Trinkets"
	tab_container.add_child(trinkets_tab)
	
	trinket_list = ItemList.new()
	trinket_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trinket_list.item_selected.connect(_on_trinket_list_item_selected)
	trinkets_tab.add_child(trinket_list)
	
	var spawn_trinket_btn = Button.new()
	spawn_trinket_btn.text = "Spawn Trinket"
	spawn_trinket_btn.pressed.connect(_on_spawn_trinket_pressed)
	trinkets_tab.add_child(spawn_trinket_btn)

	# Add Spawn Target Toggle at the top
	var toggle_hbox = HBoxContainer.new()
	vbox.add_child(toggle_hbox)
	vbox.move_child(toggle_hbox, 1) # Place after label
	
	var toggle_label = Label.new()
	toggle_label.text = "Target: Player"
	toggle_hbox.add_child(toggle_label)
	
	var toggle = CheckButton.new()
	toggle.toggled.connect(func(toggled):
		_spawn_target_is_enemy = toggled
		toggle_label.text = "Target: Enemy" if toggled else "Target: Player"
	)
	toggle_hbox.add_child(toggle)
	
	# Add Battle Start trigger button
	var battle_start_btn = Button.new()
	battle_start_btn.text = "Trigger Battle Start"
	battle_start_btn.pressed.connect(_on_trigger_battle_start_pressed)
	vbox.add_child(battle_start_btn)
	vbox.move_child(battle_start_btn, 2) # Place after toggle

func _setup_debug_ui() -> void:
	# Populate lists
	_populate_units()
	_populate_items()
	_populate_trinkets()
	
func _populate_units() -> void:
	unit_list.clear()
	for id in Database.units:
		var def = Database.units[id]
		unit_list.add_item(tr(def.display_name_key) + " (" + str(id) + ")", null, true)
		unit_list.set_item_metadata(unit_list.get_item_count() - 1, id)
	
	if unit_list.get_item_count() > 0:
		unit_list.select(0)
		_selected_unit_id = unit_list.get_item_metadata(0)

func _populate_items() -> void:
	item_list.clear()
	for id in Database.items:
		var def = Database.items[id]
		item_list.add_item(tr(def.display_name_key) + " (" + str(id) + ")", null, true)
		item_list.set_item_metadata(item_list.get_item_count() - 1, id)

	if item_list.get_item_count() > 0:
		item_list.select(0)
		_selected_item_id = item_list.get_item_metadata(0)

func _populate_trinkets() -> void:
	trinket_list.clear()
	for id in Database.trinkets:
		var def = Database.trinkets[id]
		trinket_list.add_item(tr(def.name_key) + " (" + str(id) + ")", null, true)
		trinket_list.set_item_metadata(trinket_list.get_item_count() - 1, id)
	
	if trinket_list.get_item_count() > 0:
		trinket_list.select(0)
		_selected_trinket_id = trinket_list.get_item_metadata(0)

func _on_spawn_unit_pressed() -> void:
	var selection = unit_list.get_selected_items()
	if selection.size() == 0: return
	
	var index = selection[0]
	var id = unit_list.get_item_metadata(index)
	
	# Use BattleManager's test mode helper for proper initialization parity
	var instance = battle_manager.register_test_unit(id, _spawn_target_is_enemy)
	if is_instance_valid(instance):
		SignalBus.emit_signal("battle_inventory_changed")
		# Emit granular signals for HP and PWR
		SignalBus.emit_signal("unit_stat_changed", instance.ball_uuid, &"hp", 0, instance.current_hp)
		SignalBus.emit_signal("unit_stat_changed", instance.ball_uuid, &"pwr", 0, instance.current_pwr)

func _on_spawn_item_pressed() -> void:
	var selection = item_list.get_selected_items()
	if selection.size() == 0: return
	
	var index = selection[0]
	var id = item_list.get_item_metadata(index)
	
	# Spawn items to inventory for BOTH player and enemy targets
	# User can then manually equip them onto any unit (player or enemy)
	var def = Database.get_definition(id)
	if not def: return
	var instance = GachaBallInstance.new()
	instance.initialize(def)
	battle_manager.bm_add_instance(instance, BattleManager.BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY)
	SignalBus.emit_signal("battle_inventory_changed")
	print("[TestMode] Spawned item: %s to inventory" % id)

func _on_spawn_trinket_pressed() -> void:
	var selection = trinket_list.get_selected_items()
	if selection.size() == 0:
		return
	
	var index = selection[0]
	var id = trinket_list.get_item_metadata(index)
	
	# Use BattleManager's test mode helper for proper initialization parity
	var instance = battle_manager.register_test_trinket(id, _spawn_target_is_enemy)
	if is_instance_valid(instance):
		SignalBus.emit_signal("battle_inventory_changed")


func _on_unit_list_item_selected(index: int) -> void:
	_selected_unit_id = unit_list.get_item_metadata(index)

func _on_item_list_item_selected(index: int) -> void:
	_selected_item_id = item_list.get_item_metadata(index)

func _on_trinket_list_item_selected(index: int) -> void:
	_selected_trinket_id = trinket_list.get_item_metadata(index)

var _is_dragging_panel: bool = false
var _drag_offset: Vector2

func _on_debug_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging_panel = true
				_drag_offset = debug_panel.get_global_mouse_position() - debug_panel.global_position
			else:
				_is_dragging_panel = false
	elif event is InputEventMouseMotion and _is_dragging_panel:
		debug_panel.global_position = debug_panel.get_global_mouse_position() - _drag_offset

func _on_trigger_battle_start_pressed() -> void:
	# Trigger on_battle_start abilities for all units on the board
	# This ensures perfect parity with real battle initialization
	battle_manager.trigger_test_battle_start()
