extends VBoxContainer

# NOTE: Ensure your BattleScene.tscn has nodes named "PlayerLineup", "PlayerBench", and "BattleInventory".
# These should be containers like HBoxContainer or GridContainer.
@onready var player_lineup = $HBoxContainer/PlayerContainer/PlayerLineup
@onready var player_bench = $HBoxContainer/PlayerContainer/BenchBattleInventory/Bench
@onready var battle_inventory = $HBoxContainer/PlayerContainer/BenchBattleInventory/BattleInventory # Adjusted path, please verify in BattleScene.tscn
@onready var back_button = $BackButton

const UnitScene = preload("res://scenes/Unit.tscn")
const ItemScene = preload("res://scenes/Item.tscn") # Added ItemScene preload

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	
	# Connect to the new signal from the EventBus
	EventBus.draw_gacha_requested.connect(_on_draw_gacha_requested)

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

# This function will handle the draw request from any gacha machine
func _on_draw_gacha_requested(tier: int):
	print("Draw requested for tier ", tier)
	
	# Get the correct temporary battle pool for the requested tier
	var pool = RunState.battle_gacha_pools[tier]
	
	if pool.is_empty():
		print("Tier ", tier, " pool is empty! Cannot draw.")
		# In a full implementation, this is where you would implement reshuffling the discard pile.
		return
	
	# 1. Pick a random instance and REMOVE it from the temporary pool
	var drawn_instance = pool.pick_random()
	pool.erase(drawn_instance)
	# drawn_instance is now removed from the battle pool array.
	# Now, update its persistent location state.
	print("Drew a: ", drawn_instance.get_display_name())
	
	# 2. Check if it's a Unit or an Item and place it in the correct UI container
	if drawn_instance.is_unit():
		# It's a unit, so create a Unit card and place it on the bench
		drawn_instance.set_location_state(GachaBallInstance.LocationState.IN_PLAYER_BENCH)
		var unit_card = UnitScene.instantiate()
		player_bench.add_child(unit_card) 
		unit_card.initialize(drawn_instance)
	else:
		# It's an item, so create an Item card and place it in the battle inventory
		drawn_instance.set_location_state(GachaBallInstance.LocationState.IN_BATTLE_INVENTORY)
		var item_card = ItemScene.instantiate()
		battle_inventory.add_child(item_card)
		item_card.initialize(drawn_instance)
