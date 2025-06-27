# res://scripts/BattleManager.gd
extends Node
class_name BattleManager

const GACHA_BALL_VIEW_SCENE = preload("res://scenes/GachaBallView.tscn")

@onready var lineup_container: HBoxContainer = %PlayerLineup
@onready var bench_container: HBoxContainer = %PlayerBench
@onready var item_container: HBoxContainer = %ItemInventory
@onready var discard_pile_button: Button = %DiscardPileButton
@onready var reshuffle_button: Button = get_node("UI/BattleArea/TeamAreas/EnemyArea/DrawBallArea/DiscardPileArea/ReshuffleButton")

var lineup_slots: Array[Node]
var bench_slots: Array[Node]
var item_slots: Array[Node]
var _battle_inventory: Dictionary = {0: [], 1: [], 2: [], 3: []}
var _draw_pools: Dictionary = {1: [], 2: [], 3: []}
var _discard_pile: Array[GachaBallInstance] = []

func _ready():
	add_to_group("battle_manager")
	lineup_slots = lineup_container.get_children()
	bench_slots = bench_container.get_children()
	item_slots = item_container.get_children()
	_setup_battle()
	_connect_signals()
	EventBus.emit_signal("battle_state_changed", true)

func _exit_tree():
	EventBus.emit_signal("battle_state_changed", false)

func _setup_battle():
	var hero_run_instance: GachaBallInstance = GameManager.run_state.hero_instance
	if is_instance_valid(hero_run_instance):
		var hero_battle_copy = hero_run_instance.create_battle_copy()
		_battle_inventory[0].append(hero_battle_copy)
		_place_instance_in_slot(hero_battle_copy, lineup_slots[0])
	
	for tier in GameManager.run_state.run_inventory:
		if not _battle_inventory.has(tier): _battle_inventory[tier] = []
		if not _draw_pools.has(tier): _draw_pools[tier] = []
		for instance in GameManager.run_state.run_inventory[tier]:
			var battle_copy = instance.create_battle_copy()
			_battle_inventory[tier].append(battle_copy)
			_draw_pools[tier].append(battle_copy)
	_update_discard_pile_ui()

func _connect_signals():
	# BUGFIX: The button now emits a generic signal, which the WindowManager listens for.
	discard_pile_button.pressed.connect(EventBus.display_discard_pile_requested.emit)
	EventBus.draw_gacha_requested.connect(_on_draw_gacha_requested)
	reshuffle_button.pressed.connect(_on_reshuffle_requested)

func _on_draw_gacha_requested(tier: int):
	if not _draw_pools.has(tier) or _draw_pools[tier].is_empty(): return
	var pool = _draw_pools[tier]
	var drawn_instance = pool.pick_random()
	pool.erase(drawn_instance)
	var definition = Database.units.get(drawn_instance.definition_id, Database.items.get(drawn_instance.definition_id))
	var empty_slot = _find_empty_unit_slot() if definition.category == &"UNIT" else _find_empty_item_slot()
	if is_instance_valid(empty_slot):
		_place_instance_in_slot(drawn_instance, empty_slot)
	else:
		_discard_pile.append(drawn_instance)
		_update_discard_pile_ui()

func _on_reshuffle_requested():
	if _discard_pile.is_empty(): return
	for instance in _discard_pile:
		var definition = Database.units.get(instance.definition_id, Database.items.get(instance.definition_id))
		if definition and _draw_pools.has(definition.tier):
			_draw_pools[definition.tier].append(instance)
	_discard_pile.clear()
	_update_discard_pile_ui()

func _update_discard_pile_ui():
	discard_pile_button.text = "DISCARD PILE (%d)" % _discard_pile.size()

func _find_empty_unit_slot() -> PanelContainer:
	for slot in bench_slots:
		if slot.get_child_count() == 0: return slot
	for slot in lineup_slots:
		if slot.get_child_count() == 0: return slot
	return null

func _find_empty_item_slot() -> PanelContainer:
	for slot in item_slots:
		if slot.get_child_count() == 0: return slot
	return null

func _place_instance_in_slot(instance_data: GachaBallInstance, slot_node: Node):
	var view = GACHA_BALL_VIEW_SCENE.instantiate()
	slot_node.add_child(view)
	view.set_instance_data(instance_data)
	instance_data.set_meta("view_node", view)

func get_battle_inventory() -> Dictionary:
	return _battle_inventory

func get_discard_pile() -> Array[GachaBallInstance]:
	return _discard_pile
