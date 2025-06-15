<!-- Original: GachaMachineUI.gd -->

```gdscript
extends Control

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var gacha_body_button: Button = $VBoxContainer/GachaBodyButton
@onready var draw_button: Button = $VBoxContainer/DrawButton

func _ready():
	gacha_body_button.pressed.connect(_on_gacha_body_button_pressed)

func _on_gacha_body_button_pressed():
	# Emit signal to request gacha pool inspection
	EventBus.gacha_inspection_requested.emit(name, global_position, size)

```