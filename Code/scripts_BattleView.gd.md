<!-- Original: scripts/BattleView.gd -->

```gdscript
# res://scripts/BattleView.gd
class_name BattleView
extends Control

const GachaBallView = preload("res://scenes/GachaBallView.tscn")
const SlotView = preload("res://scenes/SlotView.tscn")

# --- UI Node References ---
@onready var player_lineup: HBoxContainer = %PlayerLineup
@onready var player_bench: HBoxContainer = get_node("TeamAreas/PlayerArea/BenchAndInventory/PlayerBench")
@onready var item_inventory: HBoxContainer = get_node("TeamAreas/PlayerArea/BenchAndInventory/ItemInventory")
@onready var enemy_lineup: HBoxContainer = %EnemyLineupContainer
@onready var gacha_token_label: Label = %GachaTokenLabel
@onready var discard_pile_button: Button = %DiscardPileButton
@onready var end_turn_button: Button = %EndTurnButton

# --- Node References ---
var battle_manager: BattleManager

# --- Helper to convert placeholder PanelContainers into SlotView prefabs once ---
func _initialize_slots(ui_container: HBoxContainer, container_name: StringName):
	var slots: Array = ui_container.get_children()
	var SlotViewScene := preload("res://scenes/SlotView.tscn")
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
			# EnemyLineup must be inspection-only: configure SlotView accordingly
			if container_name == &"EnemyLineup":
				slot_view.set_interaction_context(&"INSPECTION_ONLY", 0)

func _ready():
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

	# The initial draw is now handled directly in _ready to avoid race conditions.
	# Subsequent updates will be handled by the battle_inventory_changed signal.
	_redraw_board()
	_on_battle_phase_changed(battle_manager.get_current_phase_name())

func _redraw_board():
	if not is_instance_valid(battle_manager): 
		return
	
	_update_gacha_token_label(battle_manager.get_gacha_tokens())

	_populate_container(player_lineup, "PlayerLineup", false)
	_populate_container(player_bench, "PlayerBench", false)
	_populate_container(item_inventory, "ItemInventory", false)
	_populate_container(enemy_lineup, "EnemyLineup", true)

	var discard_container = battle_manager.get_container(&"DiscardPile")
	if is_instance_valid(discard_container):
		var discard_count = discard_container.get_all_non_empty_uuids().size()
		discard_pile_button.text = "Discard Pile (%d)" % discard_count

func _populate_container(ui_container: HBoxContainer, container_name: StringName, is_enemy: bool):
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

		var instance = null
		if i < uuids.size():
			var uuid = uuids[i]
			instance = battle_manager.get_instance(uuid)

		if is_instance_valid(instance):
			var view = GachaBallView.instantiate()
			slot.add_child(view)
			
			# --- THIS IS THE LINE TO CHANGE ---
			# The third argument `is_inspectable` should be true, and the fourth argument
			# `single_click_inspect` should also be true for enemies.
			view.populate(loc, instance, true, is_enemy)
			# --- END OF CHANGE ---
			# EnemyLineup must be inspection-only: configure GachaBallView accordingly
			if container_name == &"EnemyLineup":
				var def = instance.get_definition()
				if is_instance_valid(def):
					view.set_interaction_context(&"INSPECTION_ONLY", def.category, 0)

			view.set_is_enemy(is_enemy)
			view.set_meta("location_identifier", loc)
		else:
			# If this slot is already a SlotView instance, simply update its location metadata.
			if slot.get_script() == preload("res://scripts/SlotView.gd"):
				slot.populate(loc)
				slot.set_meta("location_identifier", loc)
				# EnemyLineup must be inspection-only: configure SlotView accordingly
				if container_name == &"EnemyLineup":
					slot.set_interaction_context(&"INSPECTION_ONLY", 0)
				continue
			# Otherwise replace placeholder PanelContainer with a proper SlotView prefab.
			var SlotViewScene := preload("res://scenes/SlotView.tscn")
			var parent := slot.get_parent()
			var idx: int = slot.get_index()
			# Remove placeholder; queue_free so Godot cleans up after this frame.
			slot.queue_free()
			var slot_view: PanelContainer = SlotViewScene.instantiate()
			parent.add_child(slot_view)
			parent.move_child(slot_view, idx)
			# Populate location data so it can handle clicks/drops.
			slot_view.populate(loc)
			slot_view.set_meta("location_identifier", loc)
			# EnemyLineup must be inspection-only: configure SlotView accordingly
			if container_name == &"EnemyLineup":
				slot_view.set_interaction_context(&"INSPECTION_ONLY", 0)

func _update_gacha_token_label(new_amount: int):
	gacha_token_label.text = "Tokens: %d" % new_amount

func _on_battle_phase_changed(phase_name: StringName):
	var is_management_phase = (phase_name == &"MANAGEMENT")
	end_turn_button.disabled = not is_management_phase
	
	var main_node = get_tree().get_root().find_child("Main", true, false)
	if not is_instance_valid(main_node): return
	
	var draw_buttons_parent = main_node.get_node_or_null("VBoxContainer/BottomArea/HBoxContainer")
	if is_instance_valid(draw_buttons_parent):
		for button in draw_buttons_parent.get_children():
			if button is Button and button.name.begins_with("DrawTier"):
				button.disabled = not is_management_phase

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Create and emit InteractionContext for battle background
		var context = InteractionContext.new()
		context.source_view_instance_id = get_instance_id()
		context.event_type = &"SINGLE_CLICK"
		context.location = null  # No specific location for background
		context.entity_uuid = ""
		context.entity_type = &"GLOBAL_BACKGROUND"
		context.interaction_mode = &"FULLY_INTERACTIVE"
		context.window_group_id = 0  # Main battle scene
		
		SignalBus.emit_signal("interaction_context_received", context)

```