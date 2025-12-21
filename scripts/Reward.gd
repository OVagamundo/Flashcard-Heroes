extends VBoxContainer

const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")

@onready var title_label: Label = $TitleLabel
@onready var choices_container: HBoxContainer = %RewardChoicesContainer
@onready var confirm_button: Button = %ConfirmSelectionButton
@onready var gold_button: Button = %TakeGoldButton
@onready var back_to_path_button: Button = %BackToPathButton

var _reward_uuids: Array[String] = []
var _gold_amount: int = 0

func _ready() -> void:
	SignalBus.selection_changed.connect(_on_selection_changed)
	confirm_button.disabled = true
	confirm_button.pressed.connect(_on_confirm_pressed)
	gold_button.pressed.connect(_on_gold_pressed)
	back_to_path_button.pressed.connect(_on_back_to_path_pressed)
	
	# Add global input handling for closing inspection windows
	gui_input.connect(_on_gui_input)
	
	# Connect to locale changes
	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()

func _update_localized_text() -> void:
	title_label.text = tr("ui.choose_reward")
	confirm_button.text = tr("ui.confirm_selection")
	back_to_path_button.text = tr("ui.back_to_path")
	# Gold button text is set in populate() with the amount

# This is a public function called by Main.gd at the correct time.
func populate(context: Dictionary) -> void:
	# This function now accepts a context dictionary with reward instances and gold amount.
	# Get reward instances and gold amount from the context
	var reward_instances: Array = context.get("reward_instances", [])
	_gold_amount = context.get("gold_amount", 0)

	# Derive the UUIDs from the instances passed in the context
	_reward_uuids.clear()
	for inst in reward_instances:
		if is_instance_valid(inst):
			_reward_uuids.append(inst.ball_uuid)
	
	gold_button.text = tr("ui.take_gold_amount") % _gold_amount

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
		# Set up interaction context for the slot
		slot_view.set_interaction_context(&"SELECTION_ONLY", 0)
		
		# 4. Get the instance for this slot from the context data.
		var inst: GachaBallInstance = null
		if i < reward_instances.size():
			inst = reward_instances[i]

		# 5. If an instance exists, create its view and add it as a child to the SlotView.
		if is_instance_valid(inst):
			# Use adapter to create visual data
			var visual_data = VisualDataAdapter.create_visual_data(inst)
			slot_view.set_content(visual_data, true, false, false)


func _on_selection_changed(new_location: LocationIdentifier) -> void:
	var is_valid_selection = new_location and new_location.container == &"Rewards"
	confirm_button.disabled = not is_valid_selection

func _on_confirm_pressed() -> void:
	var selected_ctx = GlobalInteractionRouter.get_current_selection()
	var selected_loc = selected_ctx.location if selected_ctx else null
	if selected_loc and selected_loc.container == &"Rewards":
		var uuid = _reward_uuids[selected_loc.index]
		SignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": uuid})
		# Hide old buttons, show the new one
		confirm_button.visible = false
		gold_button.visible = false
		back_to_path_button.visible = true
		# Clear selection and remove all reward GachaBalls
		SignalBus.emit_signal("selection_clear_requested")
		for slot_view in choices_container.get_children():
			for child in slot_view.get_children():
				child.queue_free()

func _on_gold_pressed() -> void:
	SignalBus.emit_signal("reward_chosen", {"type": "gold", "amount": _gold_amount})
	
	# Hide old buttons, show the new one
	confirm_button.visible = false
	gold_button.visible = false
	back_to_path_button.visible = true

	# Clear selection and remove all reward GachaBalls (mirror confirm behavior)
	SignalBus.emit_signal("selection_clear_requested")
	for slot_view in choices_container.get_children():
		for child in slot_view.get_children():
			child.queue_free()

func _on_back_to_path_pressed() -> void:
	SignalBus.emit_signal("path_choice_scene_requested")
	# The reward scene has served its purpose and should be removed.
	queue_free()

func _on_gui_input(event: InputEvent) -> void:
	# Handle background clicks using the new InteractionContext system
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Create and emit InteractionContext for reward background
		var context = InteractionContext.new()
		context.source_view_instance_id = get_instance_id()
		context.event_type = &"SINGLE_CLICK"
		context.location = null # No specific location for background
		context.entity_uuid = ""
		context.entity_type = &"WINDOW_BACKGROUND"
		context.interaction_mode = &"FULLY_INTERACTIVE"
		context.window_group_id = 0 # Main window group
		
		SignalBus.emit_signal("interaction_context_received", context)
		get_viewport().set_input_as_handled()
