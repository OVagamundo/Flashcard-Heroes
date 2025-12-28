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
		# Set size scale for inventory-style rendering (2.0 = 192px slots)
		slot_view.set_size_scale(2.0)
		# 1. Clear any old GachaBallView from the persistent slot (preserve indicators).
		for child in slot_view.get_children():
			# Skip the indicator overlay (TextureRect with z_index 10)
			if child is TextureRect and child.z_index == 10:
				continue
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
		# Capture slot position and visual data BEFORE emitting signal
		var slot_nodes = choices_container.get_children()
		var slot_view = slot_nodes[selected_loc.index] if selected_loc.index < slot_nodes.size() else null
		var start_pos: Vector2 = Vector2.ZERO
		if is_instance_valid(slot_view):
			start_pos = slot_view.get_global_rect().get_center()
		
		# Get instance and capture visual data before it's cleared
		var instance = GameManager.get_instance_by_uuid(_reward_uuids[selected_loc.index])
		var visual_data: Dictionary = {}
		var tier: int = 1
		if is_instance_valid(instance):
			visual_data = VisualDataAdapter.create_visual_data(instance)
			var def = instance.get_definition()
			if def is GachaBallDefinition:
				tier = int(def.tier)
			# Trinkets go to machine 3
			if is_instance_valid(def) and def.category == &"TRINKET":
				tier = 3
		
		var uuid = _reward_uuids[selected_loc.index]
		SignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": uuid})
		# Hide old buttons, show the new one
		confirm_button.visible = false
		gold_button.visible = false
		back_to_path_button.visible = true
		# Clear selection and remove all reward GachaBalls
		SignalBus.emit_signal("selection_clear_requested")
		for sv in choices_container.get_children():
			for child in sv.get_children():
				# Skip the indicator overlay
				if child is TextureRect and child.z_index == 10:
					continue
				child.queue_free()
		
		# Trigger gachaball animation to machine
		if not visual_data.is_empty():
			_animate_gachaball_to_machine(start_pos, visual_data, tier)

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
			# Skip the indicator overlay
			if child is TextureRect and child.z_index == 10:
				continue
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

func _animate_gachaball_to_machine(start_pos: Vector2, visual_data: Dictionary, tier: int) -> void:
	"""Animate a gachaball from its reward slot to the corresponding tier machine"""
	var main_node = GameManager._active_main_node
	if not is_instance_valid(main_node):
		return
	
	# Get target machine position
	var machine_path = "VBoxContainer/BottomArea/HBoxContainer/GachaMachine%d" % tier
	var machine = main_node.get_node_or_null(machine_path)
	if not is_instance_valid(machine):
		return
	
	var end_pos: Vector2 = machine.get_global_rect().get_center()
	# Offset target position DOWN slightly (towards coin slot area)
	end_pos.y = machine.get_global_rect().position.y + machine.get_global_rect().size.y * 0.4
	
	# Spawn animated ball
	var anim_ball = GachaBallViewScene.instantiate()
	
	# Add to effects layer
	var effects_layer = main_node.get_node_or_null("EffectsLayer")
	if effects_layer:
		effects_layer.add_child(anim_ball)
	else:
		add_child(anim_ball)
	
	# Configure visual style: Force "Inventory Mode" (2x scale, overlay, circle)
	anim_ball.force_inventory_mode = true
	anim_ball.custom_minimum_size = Vector2(192, 192)
	anim_ball.size = Vector2(192, 192)
	
	# Populate with visual data
	anim_ball.populate(null, visual_data)
	
	# Set pivot to center for proper centering during animation
	anim_ball.pivot_offset = anim_ball.size / 2.0
	
	# For animation, track CENTER position and derive global_position from it
	var start_center: Vector2 = start_pos
	var end_center: Vector2 = end_pos
	
	# Initial setup: place ball at start (full scale)
	anim_ball.scale = Vector2(1.0, 1.0)
	anim_ball.global_position = start_center - anim_ball.pivot_offset
	
	# Arc parameters - SAME as battle scene
	var arc_height := 400.0 # Peak height above the highest point
	var duration := 0.45 # Snappy fast animation
	
	# Quadratic Bezier curve for natural basketball arc
	var control_point := Vector2(
		(start_center.x + end_center.x) / 2.0, # Horizontally centered
		min(start_center.y, end_center.y) - arc_height # Above both points
	)
	
	# Use tween_method to animate along the Bezier curve
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	
	# Animate t from 0 to 1 - SAME easing as battle scene
	tween.tween_method(func(t: float):
		# Same easing as battle scene - fast start, snappy landing
		var eased_t = pow(t, 0.55)
		
		# Quadratic Bezier formula: P = (1-t)²*P0 + 2*(1-t)*t*P1 + t²*P2
		var inv_t = 1.0 - eased_t
		var pos = (inv_t * inv_t * start_center) + \
				  (2.0 * inv_t * eased_t * control_point) + \
				  (eased_t * eased_t * end_center)
		
		# Position ball so its CENTER is at pos
		anim_ball.global_position = pos - anim_ball.pivot_offset
	, 0.0, 1.0, duration)
	
	# Clean up and trigger machine bounce when ball lands
	tween.tween_callback(func():
		anim_ball.queue_free()
		# Trigger machine bounce
		if main_node.has_method("trigger_machine_bounce"):
			main_node.trigger_machine_bounce(tier)
	)
