# res://scripts/Main.gd
extends Control

@onready var content_area: SubViewportContainer = %ContentArea
@onready var inspect_inventory_button: Button = %InspectInventoryButton
@onready var modal_layer: CanvasLayer = %ModalLayer
@onready var draw_tier1_button: Button = %DrawTier1Button
@onready var draw_tier2_button: Button = %DrawTier2Button
@onready var draw_tier3_button: Button = %DrawTier3Button

const PATH_CHOICE_SCENE = preload("res://scenes/PathChoice.tscn")
const BATTLE_SCENE = preload("res://scenes/Battle.tscn")

var _is_in_battle: bool = false
var _current_content_node: Node = null

func _ready():
	inspect_inventory_button.pressed.connect(_on_inspect_inventory_pressed)
	draw_tier1_button.pressed.connect(func(): EventBus.emit_signal("draw_gacha_requested", 1))
	draw_tier2_button.pressed.connect(func(): EventBus.emit_signal("draw_gacha_requested", 2))
	draw_tier3_button.pressed.connect(func(): EventBus.emit_signal("draw_gacha_requested", 3))
	
	EventBus.battle_start_requested.connect(_on_battle_start_requested)
	EventBus.battle_state_changed.connect(_on_battle_state_changed)
	
	_on_battle_state_changed(false)
	_load_content(PATH_CHOICE_SCENE)

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
	var context = {}
	if GameManager.is_in_battle:
		var battle_manager = get_tree().get_first_node_in_group("battle_manager")
		context = {
			"inventory": battle_manager.get_battle_inventory(),
			"title": "Battle Inventory (Temporary)",
			"is_interactive": true,
			"is_battle_context": true
		}
	else:
		context = {
			"inventory": GameManager.run_state.run_inventory,
			"title": "Run Inventory",
			"is_interactive": true,
			"is_battle_context": false
		}
	WindowManager.open_workspace_window(&"Inventory", context)

func _on_battle_state_changed(is_in_battle: bool):
	self._is_in_battle = is_in_battle
	draw_tier1_button.visible = is_in_battle
	draw_tier2_button.visible = is_in_battle
	draw_tier3_button.visible = is_in_battle
