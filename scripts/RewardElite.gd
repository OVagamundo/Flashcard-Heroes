# res://scripts/RewardElite.gd
extends Control

const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")
const GoldCoinVFXScene = preload("res://scripts/vfx/GoldCoinVFX.gd")
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
	back_to_path_button.visible = false # Only show after a choice is made


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
		slot_view.set_interaction_context(&"FULLY_INTERACTIVE", 0)
		
		# 4. Get the instance for this slot from the context data.
		var inst: GachaBallInstance = null
		if i < reward_instances.size():
			inst = reward_instances[i]

		# 5. If an instance exists, create its view and add it as a child to the SlotView.
		if is_instance_valid(inst):
			# Use adapter to create visual data
			var visual_data = VisualDataAdapter.create_visual_data(inst)
			slot_view.set_content(visual_data, true)

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
			var delay = ball_index * 0.1 # Stagger
			
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
	pass

func _on_confirm_pressed(_is_drag: bool = false, _mouse_pos: Vector2 = Vector2.ZERO) -> void:
	var selected_ctx = GlobalInteractionRouter.get_current_selection()
	var selected_loc = selected_ctx.location if selected_ctx else null
	if selected_loc and selected_loc.container == &"Rewards":
		var uuid = _reward_uuids[selected_loc.index]
		
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
				if child is GachaBallView:
					child.queue_free()

func _on_gold_pressed() -> void:
	# Disable button during animation
	gold_button.disabled = true
	
	_animate_gold_receive(_gold_amount, gold_button, func():
		SignalBus.emit_signal("reward_chosen", {"type": "gold", "amount": _gold_amount})
		
		var main_node_ref = GameManager._active_main_node
		if is_instance_valid(main_node_ref) and main_node_ref.has_method("hide_confirm_drop_zone"):
			main_node_ref.hide_confirm_drop_zone()
		gold_button.visible = false
		back_to_path_button.visible = true

		SignalBus.emit_signal("selection_clear_requested")
		for slot_view in choices_container.get_children():
			for child in slot_view.get_children():
				if child is GachaBallView:
					child.queue_free()
	)

func _on_back_to_path_pressed() -> void:
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node) and main_node.has_method("hide_confirm_drop_zone"):
		main_node.hide_confirm_drop_zone()
	SignalBus.emit_signal("path_choice_scene_requested")
	queue_free()

func _on_gui_input(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		var context = InteractionContext.new()
		context.source_view_instance_id = get_instance_id()
		context.event_type = &"SINGLE_CLICK"
		context.location = null
		context.entity_uuid = ""
		context.entity_type = &"WINDOW_BACKGROUND"
		context.interaction_mode = &"FULLY_INTERACTIVE"
		context.window_group_id = 0
		
		SignalBus.emit_signal("interaction_context_received", context)
		get_viewport().set_input_as_handled()

func _animate_gold_receive(amount: int, source_button: Button, on_complete: Callable) -> void:
	var main_node = GameManager._active_main_node
	if not is_instance_valid(main_node):
		on_complete.call()
		return
	
	var gold_group = main_node.get_node_or_null("%GoldGroup")
	if not is_instance_valid(gold_group):
		on_complete.call()
		return
	
	var gold_icon = gold_group.get_node_or_null("GoldIcon")
	if not is_instance_valid(gold_icon):
		gold_icon = gold_group
		
	var gold_rect = gold_icon.get_global_rect()
	var target_pos = gold_rect.get_center()
	
	var btn_rect = source_button.get_global_rect()
	var start_pos = btn_rect.get_center()
	
	# Spawn gold coins with stagger
	var coins_to_spawn = mini(amount, 5) 
	var stagger_delay = 0.08
	
	for i in range(coins_to_spawn):
		var coin_vfx = GoldCoinVFXScene.new()
		WindowManager.get_vfx_layer().add_child(coin_vfx)
		
		coin_vfx.coin_landed.connect(func(_pos: Vector2):
			Audio.play_sfx("coin_land")
			if is_instance_valid(gold_group):
				var tween = gold_group.create_tween()
				gold_group.pivot_offset = gold_group.size / 2.0
				tween.tween_property(gold_group, "scale", Vector2(1.2, 1.2), 0.05)
				tween.tween_property(gold_group, "scale", Vector2(1.0, 1.0), 0.1)
		)
		
		var offset = Vector2(randf_range(-15, 15), randf_range(-8, 8))
		coin_vfx.play(start_pos + offset, target_pos, i * stagger_delay)
		Audio.play_sfx("coin_spawn", 1.0 + (i * 0.05))

	var total_wait = (coins_to_spawn - 1) * stagger_delay + 0.45
	var wait_tween = create_tween()
	wait_tween.tween_interval(total_wait)
	wait_tween.tween_callback(on_complete)