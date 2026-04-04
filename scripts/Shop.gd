# res://scripts/Shop.gd
extends Control

const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")
const GoldCoinVFXScene = preload("res://scripts/vfx/GoldCoinVFX.gd")
const RejectionFeedbackScript = preload("res://scripts/vfx/RejectionFeedback.gd")
const InputUtils = preload("res://scripts/InputUtils.gd")

@onready var slots_container: HBoxContainer = %ShopSlotsContainer
@onready var buy_button: Button = %BuyButton
@onready var reroll_button: Button = %RerollButton
@onready var leave_button: Button = %LeaveButton
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel

var _current_shop_instances: Array = []
var _selected_cost: int = 0
var _current_reroll_cost: int = 1

func _ready() -> void:
	SignalBus.shop_stock_refreshed.connect(populate)
	SignalBus.selection_changed.connect(_on_selection_changed)

	buy_button.pressed.connect(_on_buy_pressed)
	reroll_button.pressed.connect(_on_reroll_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	

	# Add background input handling for the new InteractionContext system
	gui_input.connect(_on_gui_input)
	
	# Connect to locale changes
	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()
	
	# AUDIO HOOK: Shop BGM
	Audio.play_music(SoundRegistry.BGM_SHOP)

func _update_localized_text() -> void:
	title_label.text = tr("ui.shop")
	buy_button.text = tr("ui.buy")
	reroll_button.text = tr("ui.reroll_gold") % _current_reroll_cost
	leave_button.text = tr("ui.back_to_path")

func populate(context: Dictionary) -> void:
	_current_shop_instances = context.get("shop_instances", [])
	_current_reroll_cost = context.get("reroll_cost", 1)
	reroll_button.text = tr("ui.reroll_gold") % _current_reroll_cost

	var slot_nodes = slots_container.get_children()

	for i in range(slot_nodes.size()):
		var slot_view = slot_nodes[i]
		# Set size scale for inventory-style rendering (2.0 = 192px slots)
		slot_view.set_size_scale(2.0)
		# Clear any previous content (except indicator overlay)
		for child in slot_view.get_children():
			# Skip the indicator overlay (TextureRect with z_index 10)
			if child is TextureRect and (child.z_index == 10 or child.z_index == -1):
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
			# Note: SlotView.set_content now propagates interaction context automatically
		
		# Always create a price tag for each slot
		if is_instance_valid(inst_for_slot):
			var price_panel = PanelContainer.new()
			var style = StyleBoxFlat.new()
			style.bg_color = Color("#f1d533") # Bright yellow background
			style.border_color = Color("#000000") # Black border
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			style.corner_radius_top_left = 6
			style.corner_radius_top_right = 6
			style.corner_radius_bottom_right = 6
			style.corner_radius_bottom_left = 6
			style.content_margin_left = 12
			style.content_margin_right = 12
			style.content_margin_top = 6
			style.content_margin_bottom = 6
			price_panel.add_theme_stylebox_override("panel", style)
			
			# Align to bottom center
			price_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			price_panel.size_flags_vertical = Control.SIZE_SHRINK_END
			# Offset slightly downward to hang off the gachaball graphic
			price_panel.position.y += 20
			price_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			price_panel.z_index = 5 # Ensure it renders above the gachaball
			
			var price_label = Label.new()
			var shop_def = inst_for_slot.get_definition()
			var price = GameManager.get_item_cost(shop_def)
			price_label.text = tr("ui.gold_price") % price
			
			price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			price_label.add_theme_color_override("font_color", Color("#262b44")) # Dark blue/black text
			price_label.add_theme_constant_override("outline_size", 0) # Remove outline
			price_label.add_theme_font_size_override("font_size", 18)
			
			price_panel.add_child(price_label)
			slot_view.add_child(price_panel)
	
	# Wait one frame for layout to complete, then animate entry
	await get_tree().process_frame
	_animate_staggered_entry()
	
	# Show shop tutorial
	TutorialManager.show_tutorial(&"shop_intro", [
		{"text": tr("tutorial.shop")}
	])

func _animate_staggered_entry() -> void:
	"""Animate gachaballs appearing one-by-one with landing bounce"""
	var slot_nodes = slots_container.get_children()
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
			get_tree().create_timer(delay).timeout.connect(func():
				if is_instance_valid(ball_view) and is_instance_valid(ball_view.icon_rect):
					ball_view.icon_rect.scale = Vector2.ONE
					ball_view.play_landing_bounce()
			)
			ball_index += 1


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
			_selected_cost = GameManager.get_item_cost(shop_def)
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
			# PRE-VALIDATION: Check if player has enough gold BEFORE animating
			var current_gold: int = 0
			if is_instance_valid(GameManager.run_state):
				current_gold = GameManager.run_state.gold
			
			if current_gold < _selected_cost:
				# Insufficient gold - play rejection feedback
				var main_node = GameManager._active_main_node
				var gold_group = main_node.get_node_or_null("%GoldGroup") if is_instance_valid(main_node) else null
				RejectionFeedbackScript.play_rejection_with_counter(buy_button, gold_group, get_tree())
				return
			
			# Capture slot position and visual data BEFORE purchase
			var slot_nodes = slots_container.get_children()
			var slot_view = slot_nodes[selected_loc.index] if selected_loc.index < slot_nodes.size() else null
			var start_pos: Vector2 = Vector2.ZERO
			if is_instance_valid(slot_view):
				start_pos = slot_view.get_global_rect().get_center()
				# CONVERSION: Slot is in SubViewport, animations are in Screen Space (Main)
				# get_global_rect() in a SubViewport is relative to that Viewport.
				var main_node = GameManager._active_main_node
				if is_instance_valid(main_node):
					var content_area = main_node.get_node_or_null("%ContentArea")
					if is_instance_valid(content_area):
						start_pos += content_area.global_position
			
			# Capture visual data and tier before purchase clears the instance
			var visual_data = VisualDataAdapter.create_visual_data(instance)
			var def = instance.get_definition()
			var tier: int = 1
			if "tier" in def:
				tier = int(def.tier)
			# Trinkets go to machine 3
			if is_instance_valid(def) and def.category == &"TRINKET":
				tier = 3
			
			# Disable button during animation
			buy_button.disabled = true
			# Animate gold coins then purchase, then animate gachaball
			_animate_gold_spend(_selected_cost, buy_button, func():
				SignalBus.emit_signal("shop_purchase_requested", instance.ball_uuid, _selected_cost)
				# AUDIO HOOK: Buy
				Audio.play_sfx("shop_buy")
				buy_button.disabled = false
				# After purchase, animate gachaball to machine
				_animate_gachaball_to_machine(start_pos, visual_data, tier)
			)

func _on_reroll_pressed() -> void:
	# PRE-VALIDATION: Check if player has enough gold BEFORE animating
	var current_gold: int = 0
	if is_instance_valid(GameManager.run_state):
		current_gold = GameManager.run_state.gold
	
	if current_gold < _current_reroll_cost:
		# Insufficient gold - play rejection feedback
		var main_node = GameManager._active_main_node
		var gold_group = main_node.get_node_or_null("%GoldGroup") if is_instance_valid(main_node) else null
		RejectionFeedbackScript.play_rejection_with_counter(reroll_button, gold_group, get_tree())
		return
	
	# Disable button during animation
	reroll_button.disabled = true
	# Animate gold coins then reroll
	_animate_gold_spend(_current_reroll_cost, reroll_button, func():
		SignalBus.emit_signal("shop_reroll_requested")
		# AUDIO HOOK: Reroll
		Audio.play_sfx("shop_reroll")
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
	
	var gold_icon = gold_group.get_node_or_null("GoldIcon")
	if not is_instance_valid(gold_icon):
		# Fallback to group if icon is missing
		gold_icon = gold_group
		
	var gold_rect = gold_icon.get_global_rect()
	var start_pos = Vector2(
		gold_rect.position.x + gold_rect.size.x / 2,
		gold_rect.position.y + gold_rect.size.y / 2
	)
	
	var btn_rect = target_button.get_global_rect()
	var target_pos = Vector2(
		btn_rect.position.x + btn_rect.size.x / 2,
		btn_rect.position.y + btn_rect.size.y / 2
	)
	
	# CONVERSION: Button is in SubViewport, animations are in Screen Space (Main)
	if is_instance_valid(main_node):
		var content_area = main_node.get_node_or_null("%ContentArea")
		if is_instance_valid(content_area):
			target_pos += content_area.global_position
	
	# Spawn gold coins with stagger
	var coins_to_spawn = mini(amount, 5) # Cap at 5 coins for visual clarity
	var stagger_delay = 0.08
	
	for i in range(coins_to_spawn):
		var coin_vfx = GoldCoinVFXScene.new()
		var effects_layer = main_node.get_node_or_null("EffectsLayer")
		if is_instance_valid(effects_layer):
			effects_layer.add_child(coin_vfx)
		else:
			add_child(coin_vfx)
		
		# Connect to trigger button reaction
		coin_vfx.coin_landed.connect(_on_gold_landed_on_button.bind(target_button))
		
		var offset = Vector2(randf_range(-15, 15), randf_range(-8, 8))
		coin_vfx.play(start_pos + offset, target_pos, i * stagger_delay)
		# AUDIO HOOK: Coin Spawn
		Audio.play_sfx("coin_spawn", 1.0 + (i * 0.05)) # Pitch up slightly for each coin

	
	# Wait for animations then call completion callback
	var total_wait = (coins_to_spawn - 1) * stagger_delay + 0.45
	await get_tree().create_timer(total_wait).timeout
	on_complete.call()

func _on_gold_landed_on_button(_target_pos: Vector2, button: Button) -> void:
	"""React when a gold coin lands on a button - flash and bounce"""
	# AUDIO HOOK: Coin Land
	Audio.play_sfx("coin_land")
	
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
	var machine = main_node.get_node_or_null("%%GachaMachine%d" % tier)
	if not is_instance_valid(machine):
		return
	
	var end_pos: Vector2 = machine.get_global_rect().get_center()
	# Offset target position DOWN slightly (towards coin slot area)
	end_pos.y = machine.get_global_rect().position.y + machine.get_global_rect().size.y * 0.4
	
	# Spawn animated ball
	var anim_ball = GachaBallViewScene.instantiate()
	
	# AUDIO HOOK: Ball toss sound at animation start
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

func _on_leave_pressed() -> void:
	SignalBus.emit_signal("path_choice_scene_requested")
	queue_free()

func _on_gui_input(event: InputEvent) -> void:
	# Handle background clicks using the new InteractionContext system
	if InputUtils.is_primary_pointer_press(event):
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
