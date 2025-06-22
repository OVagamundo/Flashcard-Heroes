# res://scripts/PathChoice.gd
extends Control

@onready var start_battle_button: Button = $CenterContainer/StartBattleButton

func _ready():
	start_battle_button.pressed.connect(func(): EventBus.emit_signal("battle_start_requested"))
