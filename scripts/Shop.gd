# res://scripts/Shop.gd
extends Control

const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")
const GoldCoinVFXScene = preload("res://scripts/vfx/GoldCoinVFX.gd")

@onready var slots_container: HBoxContainer = %ShopSlotsContainer
@onready var buy_button: Button = %BuyButton
@onready var reroll_button: Button = %RerollButton
@onready var leave_button: Button = %LeaveButton
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel

var _current_shop_instances: Array = []
var _selected_cost: int = 0
var _price_labels_container: HBoxContainer
var _current_reroll_cost: int = 1

func _ready() -> void:
	SignalBus.shop_stock_refreshed.connect(populate)
	SignalBus.selection_changed.connect(_on_selection_changed)

	buy_button.pressed.connect(_on_buy_pressed)
	reroll_button.pressed.connect(_on_reroll_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	
	# Create price labels container
	_price_labels_container = HBoxContainer.new()
	_price_labels_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_price_labels_container.add_theme_constant_override("separation", 20)
	add_child(_price_labels_container)
	move_child(_price_labels_container, 2) # Place after slots container
	
	# Add background input handling for the new InteractionContext system
	gui_input.connect(_on_gui_input)
	
	# Connect to locale changes
	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()

func _update_localized_text() -> void:
	title_label.text = tr("ui.shop")
	buy_button.text = tr("ui.buy")
	reroll_button.text = tr("ui.reroll_gold") % _current_reroll_cost
	leave_button.text = tr("ui.back_to_path")

func populate(context: Dictionary) -> void:
	_current_shop_instances = context.get("shop_instances", [])
	_current_reroll_cost = context.get("reroll_cost", 1)
	reroll_button.text = tr("ui.reroll_gold") % _current_reroll_cost

	# Clear existing price labels
	for child in _price_labels_container.get_children():
		child.queue_free()

	var slot_nodes = slots_container.get_children()

	for i in range(slot_nodes.size()):
		var slot_view = slot_nodes[i]
		# Set size scale for inventory-style rendering (2.0 = 192px slots)
		slot_view.set_size_scale(2.0)
		# Clear any previous content (except indicator overlay)
		for child in slot_view.get_children():
			# Skip the indicator overlay (TextureRect with z_index 10)
			if child is TextureRect and child.z_index == 10:
				continue
			child.queue_free()

		var loc = LocationIdentifier.new(&"Shop", i)
		slot_view.populate(loc)
		slot_view.set_interaction_context(&"SELECTION_ONLY", 0)

		var inst_for_slot = _find_instance_for_slot(i)
		if is_instance_valid(inst_for_slot):
			# Ensure the instance has valid stats before populating
			var def = inst_for_slot.get_definition()
			if inst_for_slot.current_hp <= 0 or inst_for_slot.current_pwr <= 0:
				print("Warning: Instance has invalid stats, resetting from definition")
				if is_instance_valid(def):
					inst_for_slot.current_hp = def.base_hp
					inst_for_slot.current_pwr = def.base_pwr
			
			# Use adapter to create visual data
			var visual_data = VisualDataAdapter.create_visual_data(inst_for_slot)
			slot_view.set_content(visual_data, true, false, false)
			
			# Find GachaBallView among children (indicator TextureRect may also be present)
			var gacha_view: GachaBallView = null
			for child in slot_view.get_children():
				if child is GachaBallView:
					gacha_view = child
					break
			if is_instance_valid(gacha_view):
				gacha_view.set_interaction_context(&"SELECTION_ONLY", &"UNIT", 0)
		
		# Always create a price label for each slot to maintain positioning
		var price_label = Label.new()
		if is_instance_valid(inst_for_slot):
			var shop_def = inst_for_slot.get_definition()
			var price = (shop_def.tier if (shop_def is GachaBallDefinition) else 1)
			price_label.text = tr("ui.gold_price") % price
		else:
			price_label.text = "" # Empty text for slots without items
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.add_theme_font_size_override("font_size", 12)
		price_label.custom_minimum_size = Vector2(120, 30)
		_price_labels_container.add_child(price_label)

func _find_instance_for_slot(slot_index: int) -> GachaBallInstance:
	for inst in _current_shop_instances:
		if is_instance_valid(inst) and inst.get_location().index == slot_index:
			return inst
	return null

## Handle selection changes from the new InteractionContext system
func _on_selection_changed(new_location: LocationIdentifier) -> void:
	if new_location and new_location.container == &"Shop":
		var instance = _find_instance_for_slot(new_location.index)
		if is_instance_valid(instance):
			var shop_def = instance.get_definition()
			_selected_cost = (shop_def.tier if (shop_def is GachaBallDefinition) else 1)
			buy_button.text = tr("ui.buy_gold") % _selected_cost
			buy_button.disabled = false
			return

	buy_button.text = tr("ui.buy")
	buy_button.disabled = true
	_selected_cost = 0

func _on_buy_pressed() -> void:
	# Get the currently selected location from the new InteractionManager
	var selected_ctx = GlobalInteractionRouter.get_current_selection()
	var selected_loc = selected_ctx.location if selected_ctx else null
	if selected_loc and selected_loc.container == &"Shop":
		var instance = _find_instance_for_slot(selected_loc.index)
		if is_instance_valid(instance):
			# Capture slot position and visual data BEFORE purchase
			var slot_nodes = slots_container.get_children()
			var slot_view = slot_nodes[selected_loc.index] if selected_loc.index < slot_nodes.size() else null
			var start_pos: Vector2 = Vector2.ZERO
			if is_instance_valid(slot_view):
				start_pos = slot_view.get_global_rect().get_center()
			
			# Capture visual data and tier before purchase clears the instance
			var visual_data = VisualDataAdapter.create_visual_data(instance)
			var def = instance.get_definition()
			var tier: int = (int(def.tier) if (def is GachaBallDefinition) else 1)
			# Trinkets go to machine 3
			if is_instance_valid(def) and def.category == &"TRINKET":
				tier = 3
			
			# Disable button during animation
			buy_button.disabled = true
			# Animate gold coins then purchase, then animate gachaball
			_animate_gold_spend(_selected_cost, buy_button, func():
				SignalBus.emit_signal("shop_purchase_requested", instance.ball_uuid, _selected_cost)
				buy_button.disabled = false
				# After purchase, animate gachaball to machine
				_animate_gachaball_to_machine(start_pos, visual_data, tier)
			)

func _on_reroll_pressed() -> void:
	# Disable button during animation
	reroll_button.disabled = true
	# Animate gold coins then reroll
	_animate_gold_spend(_current_reroll_cost, reroll_button, func():
		SignalBus.emit_signal("shop_reroll_requested")
		reroll_button.disabled = false
	)

func _animate_gold_spend(amount: int, target_button: Button, on_complete: Callable) -> void:
	"""Animate gold coins flying from gold counter to target button"""
	# Find gold counter in Main
	var main_node = GameManager._active_main_node
	if not is_instance_valid(main_node):
		on_complete.call()
		return
	
	var gold_group = main_node.get_node_or_null("%GoldGroup")
	if not is_instance_valid(gold_group):
		on_complete.call()
		return
	
	var gold_rect = gold_group.get_global_rect()
	var start_pos = Vector2(
		gold_rect.position.x + gold_rect.size.x / 2,
		gold_rect.position.y + gold_rect.size.y / 2
	)
	
	var btn_rect = target_button.get_global_rect()
	var target_pos = Vector2(
		btn_rect.position.x + btn_rect.size.x / 2,
		btn_rect.position.y + btn_rect.size.y / 2
	)
	
	# Spawn gold coins with stagger
	var coins_to_spawn = mini(amount, 5) # Cap at 5 coins for visual clarity
	var stagger_delay = 0.08
	
	for i in range(coins_to_spawn):
		var coin_vfx = GoldCoinVFXScene.new()
		add_child(coin_vfx)
		
		# Connect to trigger button reaction
		coin_vfx.coin_landed.connect(_on_gold_landed_on_button.bind(target_button))
		
		var offset = Vector2(randf_range(-15, 15), randf_range(-8, 8))
		coin_vfx.play(start_pos + offset, target_pos, i * stagger_delay)
	
	# Wait for animations then call completion callback
	var total_wait = (coins_to_spawn - 1) * stagger_delay + 0.45
	await get_tree().create_timer(total_wait).timeout
	on_complete.call()

func _on_gold_landed_on_button(_target_pos: Vector2, button: Button) -> void:
	"""React when a gold coin lands on a button - flash and bounce"""
	if not is_instance_valid(button):
		return
	
	# Set pivot for scaling from center
	button.pivot_offset = button.size / 2
	
	# Create bounce and flash effect
	var reaction_tween = create_tween()
	reaction_tween.set_parallel(true)
	
	# Quick scale bounce
	reaction_tween.tween_property(button, "scale", Vector2(1.05, 0.95), 0.03)
	reaction_tween.tween_property(button, "scale", Vector2(0.97, 1.03), 0.05).set_delay(0.03)
	reaction_tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.08).set_delay(0.08).set_trans(Tween.TRANS_ELASTIC)
	
	# Flash bright gold
	var flash_color = Color(1.3, 1.2, 0.8, 1.0)
	reaction_tween.tween_property(button, "modulate", flash_color, 0.03)
	reaction_tween.tween_property(button, "modulate", Color.WHITE, 0.1).set_delay(0.03)

func _animate_gachaball_to_machine(start_pos: Vector2, visual_data: Dictionary, tier: int) -> void:
	"""Animate a gachaball from its shop slot to the corresponding tier machine"""
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

func _on_leave_pressed() -> void:
	SignalBus.emit_signal("path_choice_scene_requested")
	queue_free()

func _on_gui_input(event: InputEvent) -> void:
	# Handle background clicks using the new InteractionContext system
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Create and emit InteractionContext for shop background
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
