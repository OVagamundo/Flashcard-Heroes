# res://scripts/Shop.gd
extends Control

const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")
const GoldCoinVFXScene = preload("res://scripts/vfx/GoldCoinVFX.gd")
const RejectionFeedbackScript = preload("res://scripts/vfx/RejectionFeedback.gd")
const InputUtils = preload("res://scripts/InputUtils.gd")
const ACTION_BUTTON_AVOID_SCOPE_META = "action_button_avoid_scope"

@onready var slots_container: HBoxContainer = %ShopSlotsContainer
@onready var reroll_button: Button = %RerollButton
@onready var leave_button: Button = %LeaveButton
@onready var title_label: Label = %TitleLabel

var _current_shop_instances: Array = []
var _selected_cost: int = 0
var _price_tag_nodes: Array[Control] = []
var _current_reroll_cost: int = 1

func _ready() -> void:
	SignalBus.shop_stock_refreshed.connect(populate)
	SignalBus.selection_changed.connect(_on_selection_changed)

	SignalBus.confirm_drop_zone_activated.connect(_on_buy_pressed)
	reroll_button.pressed.connect(_on_reroll_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	

	# Add background input handling for the new InteractionContext system
	gui_input.connect(_on_gui_input)
	
	# Connect to locale changes
	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()
	_mark_shop_action_buttons()
	
	# AUDIO HOOK: Shop BGM
	Audio.play_music(SoundRegistry.BGM_SHOP)

func _mark_shop_action_buttons() -> void:
	_mark_action_button_for_inspection_avoidance(reroll_button)
	_mark_action_button_for_inspection_avoidance(leave_button)

func _mark_action_button_for_inspection_avoidance(button: Button) -> void:
	if not is_instance_valid(button):
		return
	button.set_meta(ACTION_BUTTON_AVOID_SCOPE_META, &"Shop")

func _update_localized_text() -> void:
	title_label.text = tr("ui.shop")
	reroll_button.text = tr("ui.reroll_gold") % _current_reroll_cost
	leave_button.text = tr("ui.leave")

func populate(context: Dictionary) -> void:
	_current_shop_instances = context.get("shop_instances", [])
	_current_reroll_cost = context.get("reroll_cost", 1)
	reroll_button.text = tr("ui.reroll_gold") % _current_reroll_cost

	var slot_nodes = slots_container.get_children()

	for i in range(slot_nodes.size()):
		var slot_view = slot_nodes[i]
		# Ensure slot is visible and has full alpha (resets after any purchase-hiding)
		slot_view.visible = true
		slot_view.modulate.a = 1.0
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
		slot_view.set_interaction_context(&"FULLY_INTERACTIVE", 0)

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
			slot_view.set_content(visual_data, true)
			# Note: SlotView.set_content now propagates interaction context automatically
	
	_update_fixed_price_tags()
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
			var wait_tween = ball_view.create_tween()
			wait_tween.tween_interval(delay)
			wait_tween.tween_callback(func():
				if is_instance_valid(ball_view) and is_instance_valid(ball_view.icon_rect):
					ball_view.icon_rect.scale = Vector2.ONE
					ball_view.play_landing_bounce()
			)
			ball_index += 1
			

func _update_fixed_price_tags() -> void:
	const TAG_W := 84.0
	const TAG_H := 38.0
	
	if _price_tag_nodes.is_empty():
		for i in range(3):
			var tag = _create_price_tag_node(TAG_W, TAG_H)
			add_child(tag)
			_price_tag_nodes.append(tag)
	
	# Wait for layout to settle so global_position is accurate
	await get_tree().process_frame
	
	var slot_nodes = slots_container.get_children()
	for i in range(slot_nodes.size()):
		if i >= _price_tag_nodes.size(): break
		
		var tag = _price_tag_nodes[i]
		var slot = slot_nodes[i]
		var inst = _find_instance_for_slot(i)
		
		# Pinned to the slot's top-right corner in the Shop scene
		# This ensures they stay put even when balls are dragged
		tag.global_position = slot.global_position + Vector2(slot.size.x - TAG_W, 0)
		
		var lbl = tag.get_node("PriceLabel")
		if is_instance_valid(inst):
			var price = GameManager.get_item_cost(inst.get_definition())
			lbl.text = tr("ui.gold_price") % price
		else:
			lbl.text = "Sold!"

func _create_price_tag_node(w: float, h: float) -> Control:
	var tag_wrapper = Control.new()
	tag_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_wrapper.z_index = 5
	tag_wrapper.size = Vector2(w, h)
	
	# Proportional background texture
	var tag_texture = TextureRect.new()
	tag_texture.name = "PriceTagTexture"
	tag_texture.texture = load("res://assets/ui/textures/PriceTag.png")
	tag_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tag_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tag_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	tag_texture.set_offsets_preset(Control.PRESET_FULL_RECT)
	tag_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_wrapper.add_child(tag_texture)
	
	# Price label
	var price_label = Label.new()
	price_label.name = "PriceLabel"
	price_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	price_label.set_offsets_preset(Control.PRESET_FULL_RECT)
	price_label.offset_left = 18 # Clear the hole graphic
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.add_theme_color_override("font_color", Color("#000000"))
	price_label.add_theme_constant_override("outline_size", 0)
	price_label.add_theme_font_size_override("font_size", 16)
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_wrapper.add_child(price_label)
	
	return tag_wrapper


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
			return

	_selected_cost = 0

func _on_buy_pressed(is_drag: bool = false, mouse_pos: Vector2 = Vector2.ZERO) -> void:
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
				# Play rejection on the drop zone overlay instead of the old buy button
				var drop_zone = main_node.get_node_or_null("%ConfirmDropZone") if is_instance_valid(main_node) else null
				var rejection_target = drop_zone if is_instance_valid(drop_zone) else reroll_button
				RejectionFeedbackScript.play_rejection_with_counter(rejection_target, gold_group, get_tree())
				return
			
			# Capture slot position and visual data BEFORE purchase
			var slot_nodes = slots_container.get_children()
			var slot_view = slot_nodes[selected_loc.index] if selected_loc.index < slot_nodes.size() else null
			var slot_center: Vector2 = Vector2.ZERO
			if is_instance_valid(slot_view):
				slot_center = slot_view.get_global_rect().get_center()
				# CONVERSION: Slot is in SubViewport, animations are in Screen Space (Main)
				var main_node = GameManager._active_main_node
				if is_instance_valid(main_node):
					var content_area = main_node.get_node_or_null("%ContentArea")
					if is_instance_valid(content_area):
						slot_center += content_area.global_position
			
			# Determine interaction point: drop point for drag, slot center for click
			var interaction_pos = slot_center
			if is_drag:
				if mouse_pos.is_zero_approx():
					interaction_pos = get_viewport().get_mouse_position()
				else:
					interaction_pos = mouse_pos
			
			# Capture visual data and tier before purchase clears the instance
			var visual_data = VisualDataAdapter.create_visual_data(instance)
			var def = instance.get_definition()
			var tier: int = 1
			if "tier" in def:
				tier = int(def.tier)
			# Trinkets go to machine 3
			if is_instance_valid(def) and def.category == &"TRINKET":
				tier = 3
			
			# Hide the gachaball in the slot IMMEDIATELY before starting gold animation
			# We only hide the child GachaBallView so the slot background remains visible
			var source_anchor = WindowManager.find_view_for_location(selected_loc)
			if is_instance_valid(source_anchor):
				for child in source_anchor.get_children():
					if child is GachaBallView:
						child.modulate.a = 0.0
						child.visible = false
			
			# Create the VFX gachaball immediately so it stays visible during the coin animation
			var vfx_ball = _create_vfx_gachaball(visual_data, interaction_pos)
			
			var ball_uuid = instance.ball_uuid
			
			# Animate gold coins then purchase, then animate gachaball
			_animate_gold_spend(_selected_cost, interaction_pos, func():
				SignalBus.emit_signal("shop_purchase_requested", ball_uuid, _selected_cost)
				# AUDIO HOOK: Buy
				Audio.play_sfx("shop_buy")
				
				# After purchase, animate the already-visible VFX gachaball to machine
				_animate_gachaball_to_machine_vfx(vfx_ball, interaction_pos, tier)
				
				# Hide the drop zone after purchase
				var mn = GameManager._active_main_node
				if is_instance_valid(mn) and mn.has_method("hide_confirm_drop_zone"):
					mn.hide_confirm_drop_zone()
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
	
	var target_pos = reroll_button.get_global_rect().get_center()
	# Button is in SubViewport
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node):
		var content_area = main_node.get_node_or_null("%ContentArea")
		if is_instance_valid(content_area):
			target_pos += content_area.global_position
			
	# Animate gold coins then reroll
	_animate_gold_spend(_current_reroll_cost, target_pos, func():
		SignalBus.emit_signal("shop_reroll_requested")
		# AUDIO HOOK: Reroll
		Audio.play_sfx("shop_reroll")
		reroll_button.disabled = false
	)

func _animate_gold_spend(amount: int, target_pos: Vector2, on_complete: Callable) -> void:
	"""Animate gold coins flying from gold counter to target position"""
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
	
	# target_pos is already in screen coordinates (passed from caller)
	
	# Spawn gold coins with stagger
	var coins_to_spawn = mini(amount, 5) # Cap at 5 coins for visual clarity
	var stagger_delay = 0.08
	
	for i in range(coins_to_spawn):
		var coin_vfx = GoldCoinVFXScene.new()
		var effects_layer = WindowManager.get_vfx_layer()
		effects_layer.add_child(coin_vfx)
		
		# Connect to trigger counter pop and landing sound
		coin_vfx.coin_landed.connect(func(_pos: Vector2):
			Audio.play_sfx("coin_land")
			# No target button feedback here anymore as we might be targeting a point in space
		)
		
		var offset = Vector2(randf_range(-15, 15), randf_range(-8, 8))
		coin_vfx.play(start_pos + offset, target_pos, i * stagger_delay)
		# AUDIO HOOK: Coin Spawn
		Audio.play_sfx("coin_spawn", 1.0 + (i * 0.05)) # Pitch up slightly for each coin

	
	# Wait for animations then call completion callback
	var total_wait = (coins_to_spawn - 1) * stagger_delay + 0.45
	var wait_tween = create_tween()
	wait_tween.tween_interval(total_wait)
	wait_tween.tween_callback(on_complete)

func _create_vfx_gachaball(visual_data: Dictionary, pos: Vector2) -> GachaBallView:
	"""Create a static VFX gachaball at a specific screen position."""
	var anim_ball = GachaBallViewScene.instantiate()
	var effects_layer = WindowManager.get_vfx_layer()
	effects_layer.add_child(anim_ball)
	
	anim_ball.force_inventory_mode = true
	# Use 2.0 scale (192x192) to match the Shop's slot scale
	anim_ball.custom_minimum_size = Vector2(192, 192)
	anim_ball.size = Vector2(192, 192)
	anim_ball.populate(null, visual_data, false)
	anim_ball.set_is_interactive(false)
	
	anim_ball.pivot_offset = anim_ball.size / 2.0
	anim_ball.global_position = pos - anim_ball.pivot_offset
	return anim_ball

func _animate_gachaball_to_machine_vfx(anim_ball: GachaBallView, start_pos: Vector2, tier: int) -> void:
	if not is_instance_valid(anim_ball):
		return
		
	var main_node = GameManager._active_main_node
	if not is_instance_valid(main_node):
		anim_ball.queue_free()
		return
	
	# Get target machine position
	var machine = main_node.get_gacha_machine(tier)
	if not is_instance_valid(machine):
		anim_ball.queue_free()
		return
	
	var end_pos: Vector2 = machine.get_global_rect().get_center()
	# Offset target position DOWN slightly (towards coin slot area)
	end_pos.y = machine.get_global_rect().position.y + machine.get_global_rect().size.y * 0.4
	
	# AUDIO HOOK: Ball toss sound at animation start
	Audio.play_sfx("ui_drag_drop")
	
	# For animation, track CENTER position and derive global_position from it
	var start_center: Vector2 = start_pos
	var end_center: Vector2 = end_pos
	
	# Arc parameters - fast and smooth
	var arc_height := 200.0
	var duration := 0.45
	
	var control_point := Vector2(
		(start_center.x + end_center.x) / 2.0,
		min(start_center.y, end_center.y) - arc_height
	)
	
	var tween = anim_ball.create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	
	tween.tween_method(func(t: float):
		var eased_t = pow(t, 1.05)
		var inv_t = 1.0 - eased_t
		var pos = (inv_t * inv_t * start_center) + \
				  (2.0 * inv_t * eased_t * control_point) + \
				  (eased_t * eased_t * end_center)
		
		anim_ball.global_position = pos - anim_ball.pivot_offset
	, 0.0, 1.0, duration)
	
	tween.tween_callback(func():
		Audio.play_sfx("coin_land")
		anim_ball.queue_free()
		if is_instance_valid(main_node) and main_node.has_method("trigger_machine_bounce"):
			main_node.trigger_machine_bounce(tier)
	)

func _on_leave_pressed() -> void:
	# Hide the drop zone overlay before leaving
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node) and main_node.has_method("hide_confirm_drop_zone"):
		main_node.hide_confirm_drop_zone()
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
