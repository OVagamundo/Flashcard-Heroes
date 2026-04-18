extends Control

const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")
const InputUtils = preload("res://scripts/InputUtils.gd")
const ACTION_BUTTON_AVOID_SCOPE_META = "action_button_avoid_scope"

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var choices_container: HBoxContainer = %RewardChoicesContainer
@onready var gold_button: Button = %TakeGoldButton
@onready var back_to_path_button: Button = %BackToPathButton

var _reward_uuids: Array[String] = []
var _gold_amount: int = 0

func _ready() -> void:
	# AUDIO HOOK: Reward BGM
	Audio.play_music(SoundRegistry.BGM_REWARD)
	
	SignalBus.selection_changed.connect(_on_selection_changed)
	SignalBus.reward_stock_refreshed.connect(populate)
	SignalBus.confirm_drop_zone_activated.connect(_on_confirm_pressed)
	gold_button.pressed.connect(_on_gold_pressed)
	back_to_path_button.pressed.connect(_on_back_to_path_pressed)
	
	# Add global input handling for closing inspection windows
	gui_input.connect(_on_gui_input)
	
	# Connect to locale changes
	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()
	_mark_reward_action_buttons()

func _mark_reward_action_buttons() -> void:
	_mark_action_button_for_inspection_avoidance(gold_button)
	_mark_action_button_for_inspection_avoidance(back_to_path_button)

func _mark_action_button_for_inspection_avoidance(button: Button) -> void:
	if not is_instance_valid(button):
		return
	button.set_meta(ACTION_BUTTON_AVOID_SCOPE_META, &"Rewards")

func _update_localized_text() -> void:
	title_label.text = tr("ui.choose_reward")
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
	
	gold_button.visible = true
	back_to_path_button.visible = true


	var slot_nodes = choices_container.get_children()

	for i in range(slot_nodes.size()):
		var slot_view = slot_nodes[i]
		# Set size scale for inventory-style rendering (2.0 = 192px slots)
		slot_view.set_size_scale(2.0)
		# 1. Clear any old GachaBallView from the persistent slot (preserve indicators).
		for child in slot_view.get_children():
			# Skip the indicator overlay (TextureRect with z_index 10)
			if child is TextureRect and (child.z_index == 10 or child.z_index == -1):
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

	# Wait one frame for layout to complete, then animate entry
	await get_tree().process_frame
	_animate_staggered_entry()

func _animate_staggered_entry() -> void:
	"""Animate reward choices appearing one-by-one with landing bounce"""
	var slot_nodes = choices_container.get_children()
	var ball_index: int = 0
	
	for slot_view in slot_nodes:
		# Find GachaBallView in slot
		var ball_view: GachaBallView = null
		for child in slot_view.get_children():
			if child is GachaBallView:
				ball_view = child
				break
		
		if is_instance_valid(ball_view) and is_instance_valid(ball_view.icon_rect):
			# Hide initially
			ball_view.icon_rect.scale = Vector2.ZERO
			ball_view.icon_rect.pivot_offset = ball_view.icon_rect.size / 2.0
			
			# Schedule delayed reveal with bounce
			var delay = ball_index * AnimationConstants.ENTRY_STAGGER_DELAY
			
			# Use tween instead of timer to bind to node lifecycle
			if is_instance_valid(ball_view):
				var tween = ball_view.create_tween()
				tween.tween_interval(delay)
				tween.tween_callback(func():
					if is_instance_valid(ball_view) and is_instance_valid(ball_view.icon_rect):
						ball_view.icon_rect.scale = Vector2.ONE
						ball_view.play_landing_bounce()
				)
			ball_index += 1


func _on_selection_changed(new_location: LocationIdentifier) -> void:
	# Drop zone visibility is handled by Main.gd via the same signal
	pass

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
			# CONVERSION: Slot is in SubViewport, animations are in Screen Space (Main)
			var main_node = GameManager._active_main_node
			if is_instance_valid(main_node):
				var content_area = main_node.get_node_or_null("%ContentArea")
				if is_instance_valid(content_area):
					start_pos += content_area.global_position
		
		# Get instance and capture visual data before it's cleared
		var instance = GameManager.get_instance_by_uuid(_reward_uuids[selected_loc.index])
		var visual_data: Dictionary = {}
		var tier: int = 1
		var target_trinket_slot: int = -1 # Will be set for trinkets
		if is_instance_valid(instance):
			visual_data = VisualDataAdapter.create_visual_data(instance)
			var def = instance.get_definition()
			if def is GachaBallDefinition:
				tier = int(def.tier)
			# Trinkets go to the player trinket bar (NOT a machine)
			if is_instance_valid(def) and def.category == &"TRINKET":
				tier = -1 # Special marker for trinket
				# CRITICAL: Capture the target slot BEFORE the signal adds the trinket
				if is_instance_valid(GameManager.run_state):
					var trinket_container = GameManager.run_state.get_container(RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS)
					if trinket_container and trinket_container.has_method("find_first_empty_slot"):
						target_trinket_slot = trinket_container.find_first_empty_slot()
						if target_trinket_slot < 0:
							target_trinket_slot = 0 # Default to first slot if full
		
		var uuid = _reward_uuids[selected_loc.index]
		
		# For non-trinkets, emit signal immediately
		# For trinkets, delay until animation ends to prevent early slot appearance
		if tier != -1:
			SignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": uuid})
		
		# Hide old buttons and drop zone overlay, show the back button
		var main_node_ref = GameManager._active_main_node
		if is_instance_valid(main_node_ref) and main_node_ref.has_method("hide_confirm_drop_zone"):
			main_node_ref.hide_confirm_drop_zone()
		gold_button.visible = false
		back_to_path_button.visible = true
		# Clear selection and remove all reward GachaBalls
		SignalBus.emit_signal("selection_clear_requested")
		for sv in choices_container.get_children():
			for child in sv.get_children():
				# Skip the indicator overlay
				if child is TextureRect and (child.z_index == 10 or child.z_index == -1):
					continue
				child.queue_free()
		
		# Trigger gachaball animation
		if not visual_data.is_empty():
			if tier == -1:
				# Trinkets: pass uuid so signal can be emitted AFTER animation
				_animate_gachaball_to_trinket_bar(start_pos, visual_data, target_trinket_slot, uuid)
			else:
				_animate_gachaball_to_machine(start_pos, visual_data, tier)

func _on_gold_pressed() -> void:
	SignalBus.emit_signal("reward_chosen", {"type": "gold", "amount": _gold_amount})
	
	# Hide old buttons and drop zone overlay, show the back button
	var main_node_ref = GameManager._active_main_node
	if is_instance_valid(main_node_ref) and main_node_ref.has_method("hide_confirm_drop_zone"):
		main_node_ref.hide_confirm_drop_zone()
	gold_button.visible = false
	back_to_path_button.visible = true

	# Clear selection and remove all reward GachaBalls (mirror confirm behavior)
	SignalBus.emit_signal("selection_clear_requested")
	for slot_view in choices_container.get_children():
		for child in slot_view.get_children():
			# Skip the indicator overlay
			if child is TextureRect and (child.z_index == 10 or child.z_index == -1):
				continue
			child.queue_free()

func _on_back_to_path_pressed() -> void:
	# Hide the drop zone overlay before leaving
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node) and main_node.has_method("hide_confirm_drop_zone"):
		main_node.hide_confirm_drop_zone()
	SignalBus.emit_signal("path_choice_scene_requested")
	# The reward scene has served its purpose and should be removed.
	queue_free()

func _on_gui_input(event: InputEvent) -> void:
	# Handle background clicks using the new InteractionContext system
	if InputUtils.is_primary_pointer_press(event):
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
	var machine = main_node.get_node_or_null("%%GachaMachine%d" % tier)
	if not is_instance_valid(machine):
		return
	
	var end_pos: Vector2 = machine.get_global_rect().get_center()
	# Offset target position DOWN slightly (towards coin slot area)
	end_pos.y = machine.get_global_rect().position.y + machine.get_global_rect().size.y * 0.4
	
	# Spawn animated ball
	var anim_ball = GachaBallViewScene.instantiate()
	
	# AUDIO HOOK: Ball toss sound
	Audio.play_sfx("ui_drag_drop")
	
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
	# Start exactly centered on the ball in the slot
	var start_center: Vector2 = start_pos
	var end_center: Vector2 = end_pos
	
	# FIXED SIZE: No scale changes, constant 1.0 scale throughout
	var constant_scale := 1.0
	anim_ball.scale = Vector2(constant_scale, constant_scale)
	anim_ball.global_position = start_center - (anim_ball.pivot_offset * constant_scale)
	
	# Arc parameters - fast and smooth
	var arc_height := 200.0 # Peak height above the highest point
	var duration := 0.45 # Faster animation
	
	# Quadratic Bezier curve for natural arc
	var control_point := Vector2(
		(start_center.x + end_center.x) / 2.0, # Horizontally centered
		min(start_center.y, end_center.y) - arc_height # Above both points
	)
	
	# Use tween_method to animate along the Bezier curve
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	
	# Nearly linear easing: smooth and fast
	tween.tween_method(func(t: float):
		# Almost linear: pow(t, 1.05) - very subtle ease for natural feel
		var eased_t = pow(t, 1.05)
		
		# Quadratic Bezier formula: P = (1-t)²*P0 + 2*(1-t)*t*P1 + t²*P2
		var inv_t = 1.0 - eased_t
		var pos = (inv_t * inv_t * start_center) + \
				  (2.0 * inv_t * eased_t * control_point) + \
				  (eased_t * eased_t * end_center)
		
		# Position ball so its CENTER is at pos (constant scale)
		anim_ball.global_position = pos - (anim_ball.pivot_offset * constant_scale)
	, 0.0, 1.0, duration)
	
	# Clean up and trigger machine bounce when ball lands
	tween.tween_callback(func():
		# AUDIO HOOK: Ball land sound
		Audio.play_sfx("coin_land")
		anim_ball.queue_free()
		# Trigger machine bounce
		if main_node.has_method("trigger_machine_bounce"):
			main_node.trigger_machine_bounce(tier)
	)

func _animate_gachaball_to_trinket_bar(start_pos: Vector2, visual_data: Dictionary, target_slot_index: int, instance_uuid: String) -> void:
	"""Animate a gachaball from its reward slot to the player trinket bar"""
	var main_node = GameManager._active_main_node
	if not is_instance_valid(main_node):
		# Emit signal anyway to ensure data consistency
		SignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": instance_uuid})
		return
	
	# Get target: PlayerTrinketBar in TopArea
	var trinket_bar = main_node.get_node_or_null("%PlayerTrinketBar")
	if not is_instance_valid(trinket_bar):
		SignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": instance_uuid})
		return
	
	# Use the pre-captured slot index (before signal was emitted)
	# Clamp to valid slot range
	var slot_count = trinket_bar.get_child_count()
	target_slot_index = clampi(target_slot_index, 0, slot_count - 1)
	
	# Get the target slot
	var target_slot = trinket_bar.get_child(target_slot_index) if target_slot_index < slot_count else null
	if not is_instance_valid(target_slot):
		SignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": instance_uuid})
		return
	
	var end_pos: Vector2 = target_slot.get_global_rect().get_center()
	
	# Spawn animated ball
	var anim_ball = GachaBallViewScene.instantiate()
	
	# Add to effects layer
	var effects_layer = main_node.get_node_or_null("EffectsLayer")
	if effects_layer:
		effects_layer.add_child(anim_ball)
	else:
		add_child(anim_ball)
	
	# Configure visual style: Use 128px ball (matches slot size)
	anim_ball.force_inventory_mode = true
	var target_rect_size: Vector2 = target_slot.get_global_rect().size
	var target_visual_size := minf(target_rect_size.x, target_rect_size.y)
	if target_visual_size <= 0.0:
		target_visual_size = 96.0
	anim_ball.custom_minimum_size = Vector2(target_visual_size, target_visual_size)
	anim_ball.size = Vector2(target_visual_size, target_visual_size)
	
	# Populate with visual data
	anim_ball.populate(null, visual_data)
	
	# Set pivot to center for proper centering during animation
	anim_ball.pivot_offset = anim_ball.size / 2.0
	
	# For animation, track CENTER position and derive global_position from it
	var start_center: Vector2 = start_pos
	var end_center: Vector2 = end_pos
	
	# MATCH BATTLE DRAW: Start small, grow to full size
	var initial_scale := 0.3
	var final_scale := 1.0
	anim_ball.scale = Vector2(initial_scale, initial_scale)
	anim_ball.global_position = start_center - (anim_ball.pivot_offset * initial_scale)
	
	# MATCH BATTLE DRAW: Arc and duration parameters
	var arc_height := 400.0 # Peak height above the highest point
	var duration := 0.45 # Snappy fast animation
	
	# Quadratic Bezier curve for natural arc
	var control_point := Vector2(
		(start_center.x + end_center.x) / 2.0, # Horizontally centered
		min(start_center.y, end_center.y) - arc_height # Above both points
	)
	
	# Use tween_method to animate along the Bezier curve
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	
	# MATCH BATTLE DRAW: Same easing for pop-out effect
	tween.tween_method(func(t: float):
		# Fast start AND snappy landing (same as battle draw)
		var eased_t = pow(t, 0.55)
		
		# Scale animation: grows quickly then settles (same as battle draw)
		var scale_eased = 1.0 - pow(1.0 - t, 2)
		var current_scale = lerp(initial_scale, final_scale, scale_eased)
		anim_ball.scale = Vector2(current_scale, current_scale)
		
		# Quadratic Bezier formula: P = (1-t)²*P0 + 2*(1-t)*t*P1 + t²*P2
		var inv_t = 1.0 - eased_t
		var pos = (inv_t * inv_t * start_center) + \
				  (2.0 * inv_t * eased_t * control_point) + \
				  (eased_t * eased_t * end_center)
		
		# Position ball so its CENTER is at pos (accounting for current scale)
		anim_ball.global_position = pos - (anim_ball.pivot_offset * current_scale)
	, 0.0, 1.0, duration)
	
	# Clean up when ball lands then emit signal to add trinket
	tween.tween_callback(func():
		anim_ball.queue_free()
		# NOW emit the delayed signal to add the trinket to RunState
		SignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": instance_uuid})
	)
