# res://scripts/BattleView.gd
class_name BattleView
extends Control

const SlotViewScene = preload("res://scenes/SlotView.tscn")
const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")

# --- UI Node References ---
@onready var player_lineup: HBoxContainer = %PlayerLineup
@onready var player_bench: HBoxContainer = get_node("TeamAreas/PlayerArea/BenchAndInventory/PlayerBench")
@onready var item_inventory: HBoxContainer = get_node("TeamAreas/PlayerArea/BenchAndInventory/ItemInventory")
@onready var enemy_lineup: HBoxContainer = %EnemyLineupContainer
@onready var gacha_token_label: Label = %GachaTokenLabel
@onready var discard_pile_button: Button = %DiscardPileButton
@onready var end_turn_button: Button = %EndTurnButton
@onready var enemy_trinket_bar: HBoxContainer = %EnemyTrinketBar

# --- Node References ---
var battle_manager: BattleManager

# --- Helper to convert placeholder PanelContainers into SlotView prefabs once ---
func _initialize_slots(ui_container: HBoxContainer, container_name: StringName) -> void:
	var slots: Array = ui_container.get_children()
	for i in range(slots.size()):
		var child = slots[i]
		if child is PanelContainer and child.get_script() != preload("res://scripts/SlotView.gd"):
			var loc := LocationIdentifier.new()
			loc.container = container_name
			loc.index = i
			var parent: Node = child.get_parent()
			var idx: int = child.get_index()
			child.free()
			var slot_view: PanelContainer = SlotViewScene.instantiate()
			parent.add_child(slot_view)
			parent.move_child(slot_view, idx)
			slot_view.populate(loc)
			
			# Apply battle-specific layout settings (responsive width, fixed height)
			slot_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot_view.custom_minimum_size = Vector2(0, 250)
			
			# Apply container-specific color scheme
			if slot_view.has_method("set_slot_color"):
				slot_view.set_slot_color(container_name)
			# EnemyLineup must be inspection-only: configure SlotView accordingly
			if container_name == &"EnemyLineup":
				slot_view.set_interaction_context(&"INSPECTION_ONLY", 0)

func _ready() -> void:
	# Guard against duplicate BattleView instances which would cause multiple
	# emissions of draw_gacha_requested per click.
	add_to_group("battle_view")
	var views := get_tree().get_nodes_in_group("battle_view")
	if views.size() > 1:
		queue_free()
		return
	battle_manager = get_node("BattleManager")
	if not is_instance_valid(battle_manager):
		return

	# Connect to all relevant state change signals
	SignalBus.battle_inventory_changed.connect(_redraw_board)
	SignalBus.gacha_tokens_changed.connect(_update_gacha_token_label)
	SignalBus.battle_phase_changed.connect(_on_battle_phase_changed)
	
	# Connect this view's buttons to emit the correct intent signals
	end_turn_button.pressed.connect(func(): SignalBus.emit_signal("end_turn_requested"))
	discard_pile_button.pressed.connect(func(): SignalBus.emit_signal("display_discard_pile_requested"))
	
	# Pre-instantiate SlotView nodes to avoid runtime replacement duplicates
	_initialize_slots(player_lineup, &"PlayerLineup")
	_initialize_slots(player_bench, &"PlayerBench")
	_initialize_slots(item_inventory, &"ItemInventory")
	_initialize_slots(enemy_lineup, &"EnemyLineup")
	_initialize_slots(enemy_trinket_bar, &"EnemyTrinkets")

	# The initial draw is now handled directly in _ready to avoid race conditions.
	# Subsequent updates will be handled by the battle_inventory_changed signal.
	_redraw_board()
	_on_battle_phase_changed(battle_manager.get_current_phase_name())

func _redraw_board() -> void:
	if not is_instance_valid(battle_manager):
		return
	
	# CRITICAL: NEVER redraw the board during animation phases!
	# The BattleAnimator owns all views during these phases (Puppet Mode).
	# Any board rebuild will destroy the registered views and break animations.
	var current_phase = battle_manager.get_current_phase()
	if current_phase == BattleManager.Phases.COMBAT or \
	   current_phase == BattleManager.Phases.START_OF_TURN or \
	   current_phase == BattleManager.Phases.END_OF_TURN:
		return
	
	_update_gacha_token_label(battle_manager.get_gacha_tokens())

	_populate_container(player_lineup, "PlayerLineup", false)
	_populate_container(player_bench, "PlayerBench", false)
	_populate_container(item_inventory, "ItemInventory", false)
	_populate_container(enemy_lineup, "EnemyLineup", true)
	_populate_enemy_trinkets()

	var discard_container = battle_manager.get_container(&"DiscardPile")
	if is_instance_valid(discard_container):
		var discard_count = discard_container.get_all_non_empty_uuids().size()
		discard_pile_button.text = tr("ui.discard_pile_count") % discard_count

func _populate_container(ui_container: HBoxContainer, container_name: StringName, is_enemy: bool) -> void:
	if not is_instance_valid(battle_manager):
		return
	
	var data_container = battle_manager.get_container(container_name)
	if not is_instance_valid(data_container):
		return
	
	# 1. Get all PanelContainer nodes (the slots) from the UI container.
	var slots: Array[PanelContainer] = []
	for child in ui_container.get_children():
		if child is PanelContainer:
			slots.append(child)

	# 2. Remove all children from every slot, including any pre-existing GachaBallView or other nodes.
	for slot in slots:
		for content in slot.get_children():
			content.queue_free() # Use queue_free to ensure Godot cleans up after this frame

	var uuids = data_container.get_all_uuids()

	# 3. Iterate through the permanent slots and populate them with fresh data.
	for i in range(slots.size()):
		var slot = slots[i]
		var loc := LocationIdentifier.new()
		loc.container = container_name
		loc.index = i

		var instance: GachaBallInstance = null
		if i < uuids.size():
			var uuid = uuids[i]
			instance = battle_manager.get_instance(uuid)

		if is_instance_valid(instance):
			# Create visual data using the adapter
			var visual_data = VisualDataAdapter.create_visual_data(instance)
			
			# Use SlotView's set_content to populate the view
			# This handles instantiation and population of GachaBallView internally
			slot.set_content(visual_data, true, is_enemy, is_enemy)
			
			# EnemyLineup must be inspection-only: configure GachaBallView accordingly
			# Note: We need to access the child view to set interaction context if needed,
			# but SlotView should ideally handle this. For now, we can access the child.
			if container_name == &"EnemyLineup":
				var def = instance.get_definition()
				if is_instance_valid(def):
					if slot.get_child_count() > 0:
						var view = slot.get_child(0)
						if view is GachaBallView:
							# In test mode, allow full interaction with enemy units
							if battle_manager.is_test_mode:
								view.set_interaction_context(&"FULLY_INTERACTIVE", def.category, 0)
							else:
								view.set_interaction_context(&"INSPECTION_ONLY", def.category, 0)

			slot.set_meta("location_identifier", loc)
		else:
			# If this slot is already a SlotView instance, simply update its location metadata.
			if slot.get_script() == preload("res://scripts/SlotView.gd"):
				slot.populate(loc)
				slot.set_meta("location_identifier", loc)
				# Ensure it's empty
				slot.set_content({}, false, false, false)
				# EnemyLineup must be inspection-only: configure SlotView accordingly
				if container_name == &"EnemyLineup":
					# In test mode, allow full interaction with enemy slots
					if battle_manager.is_test_mode:
						slot.set_interaction_context(&"FULLY_INTERACTIVE", 0)
					else:
						slot.set_interaction_context(&"INSPECTION_ONLY", 0)
				continue

			# Otherwise replace placeholder PanelContainer with a proper SlotView prefab.
			var parent := slot.get_parent()
			var idx: int = slot.get_index()
			# Remove placeholder; queue_free so Godot cleans up after this frame.
			slot.queue_free()
			var slot_view: PanelContainer = preload("res://scenes/SlotView.tscn").instantiate()
			parent.add_child(slot_view)
			parent.move_child(slot_view, idx)
			# Populate location data so it can handle clicks/drops.
			slot_view.populate(loc)
			slot_view.set_meta("location_identifier", loc)
			
			# Apply battle-specific layout settings (responsive width, fixed height)
			slot_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot_view.custom_minimum_size = Vector2(0, 250)
			
			# Apply container-specific color scheme
			if slot_view.has_method("set_slot_color"):
				slot_view.set_slot_color(container_name)
			# EnemyLineup must be inspection-only: configure SlotView accordingly
			if container_name == &"EnemyLineup":
				slot_view.set_interaction_context(&"INSPECTION_ONLY", 0)

func _update_gacha_token_label(new_amount: int) -> void:
	gacha_token_label.text = tr("ui.tokens_count") % new_amount

func _on_battle_phase_changed(phase_name: StringName) -> void:
	var is_management_phase = (phase_name == &"MANAGEMENT")
	var is_combat = (phase_name == &"COMBAT")
	# End Turn is only available during MANAGEMENT
	end_turn_button.disabled = not is_management_phase
	# Contextual/discovery buttons should be disabled only during COMBAT
	discard_pile_button.disabled = is_combat
	
	var main_node = get_tree().get_root().find_child("Main", true, false)
	if not is_instance_valid(main_node): return
	
	var draw_buttons_parent = main_node.get_node_or_null("VBoxContainer/BottomArea/HBoxContainer")
	if is_instance_valid(draw_buttons_parent):
		for button in draw_buttons_parent.get_children():
			if button is Button and button.name.begins_with("DrawTier"):
				button.disabled = is_combat
			# Also disable the InspectInventory button outside the battle view
			var inspect_btn := draw_buttons_parent.get_node_or_null("InspectInventoryButton")
			if inspect_btn is Button:
				inspect_btn.disabled = is_combat

	# Only redraw when entering MANAGEMENT phase (after all animations complete)
	# During animation phases (START_OF_TURN, COMBAT, END_OF_TURN), BattleAnimator
	# owns all views and updates them based on recorded events. Redrawing during
	# these phases destroys the views BattleAnimator is managing.
	if phase_name == &"MANAGEMENT":
		_redraw_board()

func _gui_input(event) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Create and emit InteractionContext for battle background
		var context = InteractionContext.new()
		context.source_view_instance_id = get_instance_id()
		context.event_type = &"SINGLE_CLICK"
		context.location = null # No specific location for background
		context.entity_uuid = ""
		context.entity_type = &"GLOBAL_BACKGROUND"
		context.interaction_mode = &"FULLY_INTERACTIVE"
		context.window_group_id = 0 # Main battle scene
		
		SignalBus.emit_signal("interaction_context_received", context)

func _populate_enemy_trinkets() -> void:
	if not is_instance_valid(battle_manager):
		return
	var slots = enemy_trinket_bar.get_children()
	for i in range(slots.size()):
		var slot_view = slots[i]
		for child in slot_view.get_children():
			child.queue_free()
		var loc = LocationIdentifier.new()
		loc.container = &"EnemyTrinkets"
		loc.index = i
		if slot_view.has_method("populate"):
			slot_view.populate(loc)
			if slot_view.has_method("set_interaction_context"):
				slot_view.set_interaction_context(&"INSPECTION_ONLY", 0)
		if i < battle_manager.enemy_trinkets.size():
			var instance = battle_manager.enemy_trinkets[i]
			if is_instance_valid(instance):
				var visual_data = VisualDataAdapter.create_visual_data(instance)
				slot_view.set_content(visual_data, true, true, false)
				if slot_view.get_child_count() > 0:
					var view = slot_view.get_child(0)
					if view is GachaBallView and view.has_method("set_interaction_context"):
						view.set_interaction_context(&"INSPECTION_ONLY", &"TRINKET", 0)
