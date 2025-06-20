extends VBoxContainer

const DiscardPileInspectorScene = preload("res://scenes/DiscardPileInspector.tscn")

@onready var player_lineup = $HBoxContainer/PlayerContainer/PlayerLineup
@onready var player_bench = $HBoxContainer/PlayerContainer/BenchBattleInventory/Bench
@onready var battle_inventory = $HBoxContainer/PlayerContainer/BenchBattleInventory/BattleInventory
@onready var view_discard_pile_button: Button = $HBoxContainer/EnemyContainer/ViewDiscardPileButton
@onready var back_button = $BackButton

const MAX_BENCH_SIZE = 3
const MAX_LINEUP_SIZE = 6
const MAX_INVENTORY_SIZE = 3

const UnitScene = preload("res://scenes/Unit.tscn")
const ItemScene = preload("res://scenes/Item.tscn")

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	EventBus.draw_gacha_requested.connect(_on_draw_gacha_requested)

	if view_discard_pile_button:
		view_discard_pile_button.pressed.connect(_on_view_discard_pile_button_pressed)

	if RunState.hero_instance:
		var hero_card = UnitScene.instantiate()
		player_lineup.add_child(hero_card)
		hero_card.initialize(RunState.hero_instance)

	RunState.create_battle_pools()

func _on_back_pressed():
	EventBus.load_scene_in_container_requested.emit(
		"res://scenes/PathOptions.tscn",
		get_parent()
	)

func _on_draw_gacha_requested(tier_drawn: int):
	var pool = RunState.battle_gacha_pools[tier_drawn]
	if pool.is_empty():
		return
	
	var drawn_instance = pool.pick_random()
	pool.erase(drawn_instance)

	if drawn_instance.is_unit():
		var unit_scene = UnitScene.instantiate()
		if _get_entity_count(player_bench) < MAX_BENCH_SIZE:
			drawn_instance.set_location_state(GachaBallInstance.LocationState.IN_PLAYER_BENCH)
			player_bench.add_child(unit_scene)
			unit_scene.initialize(drawn_instance)
		elif _get_entity_count(player_lineup) < MAX_LINEUP_SIZE:
			drawn_instance.set_location_state(GachaBallInstance.LocationState.IN_PLAYER_LINEUP)
			player_lineup.add_child(unit_scene)
			unit_scene.initialize(drawn_instance)
		else:
			drawn_instance.set_location_state(GachaBallInstance.LocationState.IN_BATTLE_DISCARD_PILE)
			RunState.add_to_discard_pile(drawn_instance)
			unit_scene.queue_free()
	else: # It's an item
		var item_scene = ItemScene.instantiate()
		if _get_entity_count(battle_inventory) < MAX_INVENTORY_SIZE:
			drawn_instance.set_location_state(GachaBallInstance.LocationState.IN_BATTLE_INVENTORY)
			battle_inventory.add_child(item_scene)
			item_scene.initialize(drawn_instance)
		else:
			drawn_instance.set_location_state(GachaBallInstance.LocationState.IN_BATTLE_DISCARD_PILE)
			RunState.add_to_discard_pile(drawn_instance)
			item_scene.queue_free()

func _get_entity_count(container: Node) -> int:
	var count = 0
	for child in container.get_children():
		if child.has_method("initialize"):
			count += 1
	return count

func _on_view_discard_pile_button_pressed():
	var inspector_instance = DiscardPileInspectorScene.instantiate()
	add_child(inspector_instance)
	inspector_instance.populate_display(RunState.battle_discard_pile)