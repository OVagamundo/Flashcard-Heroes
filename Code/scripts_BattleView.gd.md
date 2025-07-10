<!-- Original: scripts/BattleView.gd -->

```gdscript
# res://scripts/BattleView.gd
class_name BattleView
extends Control

const GachaBallView = preload("res://scenes/GachaBallView.tscn")
const SlotView = preload("res://scenes/SlotView.tscn")
const LocationIdentifier = preload("res://scripts/LocationIdentifier.gd")

# --- UI Node References ---
@onready var player_lineup: HBoxContainer = %PlayerLineup
@onready var player_bench: HBoxContainer = %PlayerBench
@onready var item_inventory: HBoxContainer = %ItemInventory
@onready var enemy_lineup: HBoxContainer = %EnemyLineupContainer
@onready var gacha_token_label: Label = %GachaTokenLabel
@onready var discard_pile_button: Button = %DiscardPileButton
@onready var end_turn_button: Button = %EndTurnButton

# --- Node References ---
var battle_manager: BattleManager

func _ready():
	battle_manager = get_node("../BattleManager")
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
	
	# Proactively draw the initial state.
	_redraw_board()
	_update_gacha_token_label(battle_manager._gacha_tokens)
	
	# The BattleManager will emit battle_inventory_changed after its own _ready() is done.
	# This view will catch that signal and draw the board for the first time.
	
func _redraw_board():
	if not is_instance_valid(battle_manager): return

	_populate_container(player_lineup, "PlayerLineup", false)
	_populate_container(player_bench, "PlayerBench", false)
	_populate_container(item_inventory, "ItemInventory", false)
	_populate_container(enemy_lineup, "EnemyLineup", true)

	var discard_container = battle_manager.get_container(&"DiscardPile")
	if is_instance_valid(discard_container):
		var discard_count = discard_container.get_all_non_empty_uuids().size()
		discard_pile_button.text = "Discard Pile (%d)" % discard_count

func _populate_container(ui_container: HBoxContainer, container_name: StringName, is_enemy: bool):
	if not is_instance_valid(battle_manager): return
	
	var data_container = battle_manager.get_container(container_name)
	if not is_instance_valid(data_container):
		printerr("BattleView: Could not find data container named: ", container_name)
		return

	for child in ui_container.get_children():
		child.queue_free()

	var uuids = data_container.get_all_uuids()
	for i in range(uuids.size()):
		var uuid = uuids[i]
		var instance = battle_manager.get_instance(uuid)
		
		var loc = LocationIdentifier.new()
		loc.container = container_name
		loc.index = i
		loc.tier = -1

		if is_instance_valid(instance):
			var view = GachaBallView.instantiate()
			ui_container.add_child(view)
			view.populate(loc, instance, true)
			view.set_is_enemy(is_enemy)
		else:
			var slot = SlotView.instantiate()
			ui_container.add_child(slot)
			slot.populate(loc)

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

```