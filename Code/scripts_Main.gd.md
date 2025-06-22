<!-- Original: scripts/Main.gd -->

```gdscript
extends Control

@onready var content_area: SubViewportContainer = %ContentArea
@onready var inspect_inventory_button: Button = %InspectInventoryButton
@onready var modal_layer: CanvasLayer = %ModalLayer
@onready var draw_tier1_button: Button = %DrawTier1Button
@onready var draw_tier2_button: Button = %DrawTier2Button
@onready var draw_tier3_button: Button = %DrawTier3Button

const PATH_CHOICE_SCENE = preload("res://scenes/PathChoice.tscn")
const BATTLE_SCENE = preload("res://scenes/Battle.tscn")
const INVENTORY_MODAL_SCENE = preload("res://scenes/InventoryModal.tscn")

func _ready():
	inspect_inventory_button.pressed.connect(_on_inspect_inventory_pressed)
	draw_tier1_button.pressed.connect(func(): EventBus.emit_signal("draw_gacha_requested", 1))
	draw_tier2_button.pressed.connect(func(): EventBus.emit_signal("draw_gacha_requested", 2))
	draw_tier3_button.pressed.connect(func(): EventBus.emit_signal("draw_gacha_requested", 3))
	
	EventBus.battle_start_requested.connect(_on_battle_start_requested)
	EventBus.battle_state_changed.connect(_on_battle_state_changed)
	
	# Initially disable draw buttons as we don't start in a battle.
	_on_battle_state_changed(false)
	_load_content(PATH_CHOICE_SCENE)

func _clear_content_area():
	# When clearing the content area, we are freeing the children of the SubViewport, not the container itself.
	for child in content_area.get_node("SubViewport").get_children():
		child.queue_free()

func _load_content(scene_resource: PackedScene):
	_clear_content_area()
	var instance = scene_resource.instantiate()
	# The new scene should be a child of the SubViewport, not the SubViewportContainer.
	content_area.get_node("SubViewport").add_child(instance)

func _on_battle_start_requested():
	_load_content(BATTLE_SCENE)

func _on_inspect_inventory_pressed():
	EventBus.emit_signal("inspect_inventory_requested")
	var modal = INVENTORY_MODAL_SCENE.instantiate()
	modal_layer.add_child(modal)
	# Use the new display method to show the run inventory and enable auto-refresh
	modal.display(GameManager.run_state.run_inventory, "Run Inventory", true)

func _on_battle_state_changed(is_in_battle: bool):
	draw_tier1_button.disabled = not is_in_battle
	draw_tier2_button.disabled = not is_in_battle
	draw_tier3_button.disabled = not is_in_battle

```