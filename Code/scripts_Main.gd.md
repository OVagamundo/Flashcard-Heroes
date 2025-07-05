<!-- Original: scripts/Main.gd -->

```gdscript
# res://scripts/Main.gd
extends Control

@onready var content_area: SubViewportContainer = %ContentArea
@onready var inspect_inventory_button: Button = %InspectInventoryButton
@onready var draw_tier1_button: Button = %DrawTier1Button
@onready var draw_tier2_button: Button = %DrawTier2Button
@onready var draw_tier3_button: Button = %DrawTier3Button

const PATH_CHOICE_SCENE = preload("res://scenes/PathChoice.tscn")
const BATTLE_SCENE = preload("res://scenes/Battle.tscn")

var _current_content_node: Node = null

func _ready():
	inspect_inventory_button.pressed.connect(_on_inspect_inventory_pressed)
	draw_tier1_button.pressed.connect(func(): _on_draw_button_pressed(draw_tier1_button, 1))
	draw_tier2_button.pressed.connect(func(): _on_draw_button_pressed(draw_tier2_button, 2))
	draw_tier3_button.pressed.connect(func(): _on_draw_button_pressed(draw_tier3_button, 3))
	
	EventBus.battle_start_requested.connect(_on_battle_start_requested)
	EventBus.battle_state_changed.connect(_on_battle_state_changed)
	# TDD Safeguard: Re-enable draw buttons after the UI has redrawn.
	EventBus.battle_inventory_changed.connect(_on_battle_inventory_changed)
	content_area.gui_input.connect(_on_content_area_gui_input)
	
	_on_battle_state_changed(false)
	_load_content(PATH_CHOICE_SCENE)

func _on_content_area_gui_input(event: InputEvent):
	# This acts as a backstop for drops on the background of the game area.
	if event is InputEventMouseButton and not event.is_pressed() and InteractionManager.is_drag_active():
		InteractionManager.end_drag(false)

func _clear_content_area():
	if is_instance_valid(_current_content_node):
		_current_content_node.queue_free()
	_current_content_node = null

func _load_content(scene_resource: PackedScene):
	_clear_content_area()
	var instance = scene_resource.instantiate()
	_current_content_node = instance
	content_area.get_node("SubViewport").add_child(instance)

func _on_battle_start_requested():
	_load_content(BATTLE_SCENE)

func _on_inspect_inventory_pressed():
	# This is a bit of a hack for now, but the WindowManager is
	# responsible for figuring out which inventory to open based on game state.
	EventBus.emit_signal("inspect_inventory_requested")
	inspect_inventory_button.release_focus()

func _on_draw_button_pressed(button: Button, tier: int):
	# TDD Safeguard: Disable button immediately on press.
	button.disabled = true
	EventBus.emit_signal("draw_gacha_requested", tier)

func _on_battle_inventory_changed():
	# TDD Safeguard: Re-enable buttons after the state has been updated.
	draw_tier1_button.disabled = false
	draw_tier2_button.disabled = false
	draw_tier3_button.disabled = false

func _on_battle_state_changed(is_in_battle: bool):
	draw_tier1_button.visible = is_in_battle
	draw_tier2_button.visible = is_in_battle
	draw_tier3_button.visible = is_in_battle

```