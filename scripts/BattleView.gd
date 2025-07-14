# res://scripts/BattleView.gd
class_name BattleView
extends Control

const GachaBallView = preload("res://scenes/GachaBallView.tscn")
const SlotView = preload("res://scenes/SlotView.tscn")
const LocationIdentifier = preload("res://scripts/LocationIdentifier.gd")

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

func _ready():
	# Guard against duplicate BattleView instances which would cause multiple
	# emissions of draw_gacha_requested per click.
	add_to_group("battle_view")
	var views := get_tree().get_nodes_in_group("battle_view")
	if views.size() > 1:
		printerr("BattleView: Duplicate instance detected – self-terminating to avoid duplicate draw emissions.")
		queue_free()
		return
	battle_manager = get_node("BattleManager")
	if not is_instance_valid(battle_manager):
		printerr("BattleView CRITICAL: BattleManager node not found!")
		return

	# Connect to all relevant state change signals
	EventBus.battle_inventory_changed.connect(_redraw_board)
	EventBus.gacha_tokens_changed.connect(_update_gacha_token_label)
	EventBus.battle_phase_changed.connect(_on_battle_phase_changed)
	
	# Connect this view's buttons to emit the correct intent signals
	end_turn_button.pressed.connect(func(): EventBus.emit_signal("end_turn_requested"))
	discard_pile_button.pressed.connect(func(): EventBus.emit_signal("display_discard_pile_requested"))
	
	# Connect draw buttons (named DrawTier1, DrawTier2, DrawTier3) to EventBus
	var main_node = get_tree().get_root().find_child("Main", true, false)
	if is_instance_valid(main_node):
		var btn_parent = main_node.get_node_or_null("VBoxContainer/BottomArea/HBoxContainer")
		if is_instance_valid(btn_parent):
			for child in btn_parent.get_children():
				if child is Button and child.name.begins_with("DrawTier"):
					var tier_str := child.name.substr(len("DrawTier"))
					var tier := int(tier_str)
					# Only connect once per button by checking a meta flag
					# Ensure exactly one pressed connection – remove all existing, then connect.
					var existing_connections: Array = child.pressed.get_connections()
					for conn_dict in existing_connections:
						var existing_callable: Callable = conn_dict["callable"]
						child.pressed.disconnect(existing_callable)
					child.pressed.connect(func(t=tier):
						print("--- BUTTON-PRESS EMIT --- tier=", t)
						EventBus.emit_signal("draw_gacha_requested", t)
					)
	
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
	if not is_instance_valid(battle_manager): return
	
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
		print("BattleView: BattleManager is not valid")
		return
	
	var data_container = battle_manager.get_container(container_name)
	if not is_instance_valid(data_container):
		printerr("BattleView: Could not find data container named: ", container_name)
		return
	
	# 1. Get all PanelContainer nodes (the slots) from the UI container.
	var slots: Array[PanelContainer] = []
	for child in ui_container.get_children():
		if child is PanelContainer:
			slots.append(child)

	# 2. Unconditionally clear all content from every slot. This is the crucial step
	#    to ensure no old or duplicate views remain before repopulating.
	for slot in slots:
		for content in slot.get_children():
			content.free()

	var uuids = data_container.get_all_uuids()

	# 3. Iterate through the permanent slots and populate them with fresh data.
	for i in range(slots.size()):
		var slot = slots[i]
		var loc := LocationIdentifier.new()
		loc.container = container_name
		loc.index = i
		if container_name.begins_with("BattleInventoryT"):
			loc.tier = int(container_name.substr(len("BattleInventoryT")))
		else:
			loc.tier = -1

		var instance = null
		if i < uuids.size():
			var uuid = uuids[i]
			instance = battle_manager.get_instance(uuid)

		if is_instance_valid(instance):
			var view = GachaBallView.instantiate()
			slot.add_child(view)
			view.populate(loc, instance, not is_enemy)
			view.set_is_enemy(is_enemy)
			view.set_meta("location_identifier", loc)
		else:
			# If this slot is already a SlotView instance, simply update its location metadata.
			if slot.get_script() == preload("res://scripts/SlotView.gd"):
				slot.populate(loc)
				slot.set_meta("location_identifier", loc)
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
