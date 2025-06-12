extends VBoxContainer

@onready var battle_button = $ButtonsContainer/BattleButton
@onready var rest_button = $ButtonsContainer/RestButton
@onready var shop_button = $ButtonsContainer/ShopButton

func _ready():
	battle_button.pressed.connect(_on_battle_pressed)
	rest_button.pressed.connect(_on_rest_pressed)
	shop_button.pressed.connect(_on_shop_pressed)

func _on_battle_pressed():
	# Use load_scene_in_container_requested to load into dynamic content
	EventBus.load_scene_in_container_requested.emit(
		"res://scenes/BattleScene.tscn",
		get_parent()
	)

func _on_rest_pressed():
	EventBus.load_scene_in_container_requested.emit(
		"res://scenes/RestScene.tscn",
		get_parent()
	)

func _on_shop_pressed():
	EventBus.load_scene_in_container_requested.emit(
		"res://scenes/ShopScene.tscn",
		get_parent()
	)
