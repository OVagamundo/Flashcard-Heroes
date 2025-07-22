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
func populate(context: Dictionary):
	# This function now accepts a context dictionary with reward instances and gold amount.
	
	# Get reward instances and gold amount from the context
	var reward_instances: Array = context.get("reward_instances", [])
	_gold_amount = context.get("gold_amount", 0)

	# Derive the UUIDs from the instances passed in the context
	_reward_uuids.clear()
	for inst in reward_instances:
		if is_instance_valid(inst):
			_reward_uuids.append(inst.ball_uuid)
	
	gold_button.text = "+%d Gold" % _gold_amount

	var slot_nodes = choices_container.get_children()

	for i in range(slot_nodes.size()):
		var slot_view = slot_nodes[i]
		# 1. Clear any old GachaBallView from the persistent slot.
		for child in slot_view.get_children():
			child.queue_free()
		
		# 2. Create the location identifier for this slot.
		var loc = LocationIdentifier.new(&"Rewards", i)

		# 3. Populate the SlotView itself, making it a valid interactive target.
		slot_view.populate(loc)
		
		# 4. Get the instance for this slot from the context data.
		var inst = null
		if i < reward_instances.size():
			inst = reward_instances[i]

		# 5. If an instance exists, create its view and add it as a child to the SlotView.
		if is_instance_valid(inst):
			var gacha_view = GachaBallViewScene.instantiate()
			slot_view.add_child(gacha_view)
			# THE CRITICAL FIX: The last argument must be 'false' to enable
			# standard inventory interactions (select, double-click, drag).
			gacha_view.populate(loc, inst, true, false)

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
