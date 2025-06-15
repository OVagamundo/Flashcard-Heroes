<!-- Original: BottomBar.gd -->

```gdscript
extends Control

# UI element references (no logic, only visual elements)
@onready var gacha_machine_1 = $HBoxContainer/GachaMachinesContainer/GachaMachine1
@onready var gacha_machine_2 = $HBoxContainer/GachaMachinesContainer/GachaMachine2
@onready var gacha_machine_3 = $HBoxContainer/GachaMachinesContainer/GachaMachine3

func _ready():
	gacha_machine_1.gacha_body_button.pressed.connect(_on_gacha_machine_1_pressed)
	gacha_machine_2.gacha_body_button.pressed.connect(_on_gacha_machine_2_pressed)
	gacha_machine_3.gacha_body_button.pressed.connect(_on_gacha_machine_3_pressed)

func _on_gacha_machine_1_pressed():
	EventBus.emit_signal("gacha_inspection_requested", "gacha_machine_1", gacha_machine_1.global_position, gacha_machine_1.size)

func _on_gacha_machine_2_pressed():
	EventBus.emit_signal("gacha_inspection_requested", "gacha_machine_2", gacha_machine_2.global_position, gacha_machine_2.size)

func _on_gacha_machine_3_pressed():
	EventBus.emit_signal("gacha_inspection_requested", "gacha_machine_3", gacha_machine_3.global_position, gacha_machine_3.size)

```