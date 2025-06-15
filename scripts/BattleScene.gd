extends VBoxContainer

# NOTE: Ensure your BattleScene.tscn has nodes named "PlayerLineup" and "PlayerBench".
# These should be containers like HBoxContainer or GridContainer.
@onready var player_lineup = $HBoxContainer/PlayerContainer/PlayerLineup
@onready var player_bench = $HBoxContainer/PlayerContainer/BenchBattleInventory/Bench
@onready var back_button = $BackButton

# Preload the scene for a single unit's visual representation
const UnitScene = preload("res://scenes/Unit.tscn")

func _ready():
	back_button.pressed.connect(_on_back_pressed)

	# When the battle scene starts, place the hero in the lineup.
	# We check if a hero_instance exists in our global RunState.
	if RunState.hero_instance:
		var hero_card = UnitScene.instantiate()
		player_lineup.add_child(hero_card)
		hero_card.initialize(RunState.hero_instance)

	# Also, prepare the temporary gacha pools for this specific battle.
	# This creates copies so that drawing during combat doesn't affect the master pool.
	RunState.create_battle_pools()

func _on_back_pressed():
	EventBus.load_scene_in_container_requested.emit(
		"res://scenes/PathOptions.tscn",
		get_parent()
	)
