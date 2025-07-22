<!-- Original: scripts/Reward.gd -->

```gdscript
extends VBoxContainer

const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")

@onready var choices_container: HBoxContainer = %RewardChoicesContainer
@onready var confirm_button: Button = %ConfirmSelectionButton
@onready var gold_button: Button = %TakeGoldButton

var _reward_uuids: Array[String] = []
var _gold_amount: int = 0

func _ready():
	EventBus.selection_changed.connect(_on_selection_changed)
	confirm_button.disabled = true
	confirm_button.pressed.connect(_on_confirm_pressed)
	gold_button.pressed.connect(_on_gold_pressed)

# This is a public function called by Main.gd at the correct time.
func populate():
	var reward_container = GameManager.get_temporary_reward_container()
	if not is_instance_valid(reward_container):
		printerr("Reward.gd: populate() called but GameManager has no reward container.")
		return

	_reward_uuids = reward_container.get_all_uuids()
	_gold_amount = GameManager.get_temporary_gold_reward()
	gold_button.text = "+%d Gold" % _gold_amount

	var slot_nodes = choices_container.get_children()

	for i in range(slot_nodes.size()):
		var slot = slot_nodes[i]
		for child in slot.get_children():
			child.queue_free() # Clear old content
		
		if i >= _reward_uuids.size() or _reward_uuids[i].is_empty():
			continue

		var uuid = _reward_uuids[i]
		# Debug logging
		print("--- Reward.gd: Accessing Rewards ---")
		print("Requesting UUID: ", uuid)
		print("GameManager's Master Dict at this moment: ", GameManager.get_temporary_reward_master_dict_for_debug().keys())
		
		var inst = GameManager.get_temporary_reward_instance(uuid)
		if not is_instance_valid(inst):
			printerr("Reward.gd: Invalid instance for UUID: ", uuid)
			continue

		var loc = LocationIdentifier.new(&"Rewards", i)
		
		# Directly create and populate a GachaBallView into the persistent slot.
		# This is the same pattern as your other inventories.
		var gacha_view = GachaBallViewScene.instantiate()
		slot.add_child(gacha_view)
		# TDD Rule: Reward choices are static, so inspection is single-click.
		gacha_view.populate(loc, inst, true, true)

func _on_selection_changed(new_location: LocationIdentifier):
	var is_valid_selection = new_location and new_location.container == &"Rewards"
	confirm_button.disabled = not is_valid_selection

func _on_confirm_pressed():
	var selected_loc = InteractionManager.get_selected_location()
	if selected_loc and selected_loc.container == &"Rewards":
		var uuid = _reward_uuids[selected_loc.index]
		EventBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": uuid})
		queue_free()

func _on_gold_pressed():
	EventBus.emit_signal("reward_chosen", {"type": "gold", "amount": _gold_amount})
	queue_free()

```