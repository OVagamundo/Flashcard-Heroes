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

var _reward_instances: Array = []
var _gold_amount: int = 10 # Default to 10 for Elite rewards
var _action_in_progress: bool = false
var _original_reward_instances: Array = [] 
var _is_first_populate: bool = true

func _ready() -> void:
	add_to_group("reward_scene")
	Audio.play_music(SoundRegistry.BGM_REWARD)
	
	SignalBus.selection_changed.connect(_on_selection_changed)
	SignalBus.reward_stock_refreshed.connect(populate)
	SignalBus.reward_collect_zone_activated.connect(_on_collect_pressed)
	SignalBus.reward_sell_zone_activated.connect(_on_sell_pressed)
	
	gold_button.pressed.connect(_on_gold_pressed)
	gold_button.visible = false # Replaced by Sell drop zone
	back_to_path_button.pressed.connect(_on_back_to_path_pressed)
	gui_input.connect(_on_gui_input)
	
	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()
	_mark_reward_action_buttons()
	
	_show_initial_instruction()

func _show_initial_instruction() -> void:
	if is_instance_valid(GameManager._active_main_node):
		if GameManager._active_main_node.has_method("show_action_instruction"):
			GameManager._active_main_node.show_action_instruction(tr("ui.reward_elite_instruction"))

func _exit_tree() -> void:
	# Cleanup overlays when leaving
	if is_instance_valid(GameManager._active_main_node):
		if GameManager._active_main_node.has_method("hide_action_instruction"):
			GameManager._active_main_node.hide_action_instruction()
		if GameManager._active_main_node.has_method("hide_reward_drop_zones"):
			GameManager._active_main_node.hide_reward_drop_zones()

var _last_inventory_open: bool = false
func _process(_delta: float) -> void:
	var is_open := WindowManager.is_run_inventory_window_open()
	if is_open != _last_inventory_open:
		_last_inventory_open = is_open
		var main_node = GameManager._active_main_node
		if is_instance_valid(main_node):
			if is_open:
				if main_node.has_method("hide_action_instruction"):
					main_node.hide_action_instruction()
				if main_node.has_method("hide_reward_drop_zones"):
					main_node.hide_reward_drop_zones()
			else:
				var sel = GlobalInteractionRouter.get_current_selection()
				var is_prize_selected = sel and sel.location and sel.location.container == &"Rewards"
				# Only show instructions if choice is not yet complete
				if not is_prize_selected and not back_to_path_button.visible:
					if main_node.has_method("show_action_instruction"):
						main_node.show_action_instruction(tr("ui.reward_elite_instruction"))

func _mark_reward_action_buttons() -> void:
	_mark_action_button_for_inspection_avoidance(gold_button)
	_mark_action_button_for_inspection_avoidance(back_to_path_button)

func _mark_action_button_for_inspection_avoidance(button: Button) -> void:
	if is_instance_valid(button):
		button.set_meta(ACTION_BUTTON_AVOID_SCOPE_META, &"Rewards")

func _update_localized_text() -> void:
	var locale = TranslationServer.get_locale().left(2)
	if locale == "pt":
		title_label.text = "Escolha seu Amuleto"
		back_to_path_button.text = "Voltar ao Caminho"
	else:
		title_label.text = "Choose Your Trinket"
		back_to_path_button.text = tr("ui.back_to_path")
	
	gold_button.text = tr("ui.take_gold_amount") % _gold_amount

func populate(context: Dictionary) -> void:
	_reward_instances = context.get("reward_instances", [])
	_original_reward_instances = _reward_instances.duplicate()
	
	_gold_amount = context.get("gold_amount", 10)
	
	_update_localized_text()
	
	var slot_nodes = choices_container.get_children()
	for i in range(slot_nodes.size()):
		var slot_view = slot_nodes[i]
		if i < _reward_instances.size():
			var inst = _reward_instances[i]
			if is_instance_valid(inst):
				var loc = LocationIdentifier.new(&"Rewards", i)
				slot_view.populate(loc)
				
				var visual_data = VisualDataAdapter.create_visual_data(inst)
				var ball_view = slot_view.set_content(visual_data, true, false)
				
				# HIDE IMMEDIATELY (both visibility and scale)
				if is_instance_valid(ball_view):
					ball_view.visible = false
					ball_view.scale = Vector2.ZERO
				slot_view.set_interaction_context(&"FULLY_INTERACTIVE", 0)
				slot_view.set_size_scale(2.0)
				slot_view.visible = true
			else:
				slot_view.visible = false
	back_to_path_button.visible = true
	back_to_path_button.modulate.a = 0.0
	back_to_path_button.disabled = true
	gold_button.visible = false # Keep hidden, replaced by Sell zone
	
	_animate_staggered_entry()

# Replaced by direct call in populate
func _on_staggered_entry_timer_timeout() -> void:
	pass

func _animate_staggered_entry() -> void:
	"""Animate trinkets appearing one-by-one with landing bounce"""
	var slot_nodes = choices_container.get_children()
	
	# STAGE 2: Wait before starting the population sequence
	# Only wait a short time on first entry (per USER request)
	if _is_first_populate:
		await AnimationConstants.create_pausable_timer(get_tree(), 0.5).timeout
		_is_first_populate = false
	else:
		# Just a tiny delay for subsequent refreshes to let layout settle
		await get_tree().process_frame
	
	# STAGE 3: Wait for layout to settle so icon_rect.size is populated
	# This is critical for play_landing_bounce() which skips if size is zero.
	await get_tree().process_frame
	
	var ball_index: int = 0
	for slot_view in slot_nodes:
		# Find GachaBallView in slot
		var ball_view: GachaBallView = null
		for child in slot_view.get_children():
			if child is GachaBallView:
				ball_view = child
				break
		
		if is_instance_valid(ball_view) and is_instance_valid(ball_view.icon_rect):
			# Ensure pivot is centered based on now-valid size
			ball_view.icon_rect.pivot_offset = ball_view.icon_rect.size / 2.0
			
			# Schedule delayed reveal with landing bounce
			var delay = ball_index * AnimationConstants.ENTRY_STAGGER_DELAY
			var wait_tween = ball_view.create_tween()
			wait_tween.tween_interval(delay)
			wait_tween.tween_callback(func():
				if is_instance_valid(ball_view):
					ball_view.visible = true
					ball_view.scale = Vector2.ZERO
					ball_view.play_landing_bounce()
			)
			ball_index += 1

func _on_selection_changed(_new_location: LocationIdentifier) -> void:
	pass

func _get_selected_prize() -> Dictionary:
	var selected_ctx = GlobalInteractionRouter.get_current_selection()
	if selected_ctx == null: return {}
	var selected_loc = selected_ctx.location if selected_ctx else null
	if not is_instance_valid(selected_loc) or selected_loc.container != &"Rewards": return {}
	
	if selected_loc.index < 0 or selected_loc.index >= _reward_instances.size():
		return {}
		
	var instance = _reward_instances[selected_loc.index]
	if not is_instance_valid(instance): return {}
	
	return {"location": selected_loc, "instance": instance, "uuid": instance.ball_uuid}

func _on_collect_pressed(is_drag: bool = false, mouse_pos: Vector2 = Vector2.ZERO) -> void:
	if _action_in_progress: return
	var prize_data = _get_selected_prize()
	if prize_data.is_empty(): return
	
	_action_in_progress = true
	var loc = prize_data.location
	var instance = prize_data.instance
	
	_clear_reward_slot(loc.index)
	SignalBus.emit_signal("selection_clear_requested")
	
	var raw_pos = _get_slot_global_center(loc.index)
	if is_drag:
		raw_pos = mouse_pos if not mouse_pos.is_zero_approx() else get_viewport().get_mouse_position()
	
	var visual_data = VisualDataAdapter.create_visual_data(instance)
	var target_trinket_slot: int = 0
	if is_instance_valid(GameManager.run_state):
		var trinket_container = GameManager.run_state.get_container(RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS)
		if trinket_container and trinket_container.has_method("find_first_empty_slot"):
			target_trinket_slot = max(0, trinket_container.find_first_empty_slot())
	
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node):
		if main_node.has_method("hide_reward_drop_zones"):
			main_node.hide_reward_drop_zones()
		# We don't restore instruction here because choice is complete
		if main_node.has_method("hide_action_instruction"):
			main_node.hide_action_instruction()
	
	# Mapping for collection vfx (must stay global as it flies to Main bar)
	var start_pos = _map_screen_to_vfx_viewport(_get_absolute_screen_pos(raw_pos))
	await _animate_gachaball_to_trinket_bar(start_pos, visual_data, target_trinket_slot)
	
	SignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": instance.ball_uuid})
	
	_complete_choice()
	_action_in_progress = false

func _on_sell_pressed(is_drag: bool = false, mouse_pos: Vector2 = Vector2.ZERO) -> void:
	if _action_in_progress: return
	var prize_data = _get_selected_prize()
	if prize_data.is_empty(): return
	
	_action_in_progress = true
	var loc = prize_data.location
	var instance = prize_data.instance
	
	_clear_reward_slot(loc.index)
	SignalBus.emit_signal("selection_clear_requested")
	
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node):
		if main_node.has_method("hide_reward_drop_zones"):
			main_node.hide_reward_drop_zones()
		if main_node.has_method("hide_action_instruction"):
			main_node.hide_action_instruction()
	
	var raw_pos = _get_slot_global_center(loc.index)
	if is_drag:
		raw_pos = mouse_pos if not mouse_pos.is_zero_approx() else get_viewport().get_mouse_position()
	
	var screen_pos = _get_absolute_screen_pos(raw_pos)
	var vfx_start_pos = _map_screen_to_vfx_viewport(screen_pos)
	
	await _animate_gold_receive(_gold_amount, vfx_start_pos)
	
	SignalBus.emit_signal("reward_chosen", {"type": "gold", "amount": _gold_amount})
	
	_complete_choice()
	_action_in_progress = false

func _on_gold_pressed() -> void:
	# Keep legacy method for compatibility if needed, but it's now redundant
	pass

func _complete_choice() -> void:
	SignalBus.emit_signal("reward_chosen", {"type": "elite_choice_complete"})
	gold_button.visible = false
	
	# Reveal navigation button via modulation to prevent layout shifts
	back_to_path_button.modulate.a = 1.0
	back_to_path_button.disabled = false
	
	# Animate unselected balls flying away (parallel staggered)
	var slot_nodes = choices_container.get_children()
	for i in range(slot_nodes.size()):
		var slot = slot_nodes[i]
		var ball: Control = null
		for child in slot.get_children():
			if child is GachaBallView:
				ball = child
				break
		
		if is_instance_valid(ball) and ball.visible and ball.modulate.a > 0.1:
			var delay = i * 0.1
			var ball_tween = create_tween()
			ball_tween.tween_interval(delay)
			# Move and Fade in parallel, faster duration (0.4s)
			ball_tween.tween_property(ball, "position:y", ball.position.y - 120, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			ball_tween.parallel().tween_property(ball, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			ball_tween.tween_callback(ball.queue_free)
	
	_reward_instances.clear()

func _clear_reward_slot(index: int) -> void:
	var slot_nodes = choices_container.get_children()
	if index >= 0 and index < slot_nodes.size():
		var slot_view = slot_nodes[index]
		if slot_view.has_method("set_content"):
			slot_view.set_content({}, false)

func _get_slot_global_center(index: int) -> Vector2:
	var slot_nodes = choices_container.get_children()
	if index >= 0 and index < slot_nodes.size() and is_instance_valid(slot_nodes[index]):
		return slot_nodes[index].get_global_rect().get_center()
	return Vector2.ZERO

func _on_back_to_path_pressed() -> void:
	if is_instance_valid(GameManager._active_main_node) and GameManager._active_main_node.has_method("hide_reward_drop_zones"):
		GameManager._active_main_node.hide_reward_drop_zones()
	SignalBus.emit_signal("path_choice_scene_requested")
	queue_free()

func _on_gui_input(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		var context = InteractionContext.new()
		context.source_view_instance_id = get_instance_id()
		context.event_type = &"SINGLE_CLICK"
		context.entity_type = &"WINDOW_BACKGROUND"
		SignalBus.emit_signal("interaction_context_received", context)
		get_viewport().set_input_as_handled()

func _animate_gachaball_to_trinket_bar(start_pos: Vector2, visual_data: Dictionary, target_slot_index: int) -> void:
	var main_node = GameManager._active_main_node
	if not is_instance_valid(main_node): return
	var trinket_bar = main_node.get_node_or_null("%PlayerTrinketBar")
	if not is_instance_valid(trinket_bar) or trinket_bar.get_child_count() == 0: return
	
	var target_slot = trinket_bar.get_child(clampi(target_slot_index, 0, trinket_bar.get_child_count() - 1))
	var end_pos = _map_screen_to_vfx_viewport(_get_absolute_screen_pos(target_slot.get_global_rect().get_center(), target_slot.get_viewport()))
	
	var anim_ball = GachaBallViewScene.instantiate()
	WindowManager.get_vfx_layer().add_child(anim_ball)
	
	# Fix warning: Reset anchors before setting size for a manual-transform node
	anim_ball.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	
	anim_ball.top_level = true
	anim_ball.z_index = 100
	anim_ball.custom_minimum_size = Vector2(96, 96)
	anim_ball.size = Vector2(96, 96)
	anim_ball.populate(null, visual_data)
	anim_ball.pivot_offset = Vector2(48, 48)
	
	var control_point = Vector2((start_pos.x + end_pos.x) / 2.0, min(start_pos.y, end_pos.y) - 400)
	var tween = create_tween()
	tween.tween_method(func(t: float):
		var eased_t = pow(t, 0.55)
		var current_scale = lerp(2.0, 1.0, t) 
		var inv_t = 1.0 - eased_t
		var pos = (inv_t * inv_t * start_pos) + (2.0 * inv_t * eased_t * control_point) + (eased_t * eased_t * end_pos)
		anim_ball.global_position = pos - (anim_ball.pivot_offset * current_scale)
		anim_ball.scale = Vector2(current_scale, current_scale)
	, 0.0, 1.0, 0.45)
	await tween.finished
	anim_ball.queue_free()

func _animate_gold_receive(amount: int, start_pos: Vector2) -> void:
	var main_node = GameManager._active_main_node
	if not is_instance_valid(main_node): return
	var gold_group = main_node.get_node_or_null("%GoldGroup")
	if not is_instance_valid(gold_group): return
	
	var target_pos = _map_screen_to_vfx_viewport(_get_absolute_screen_pos(gold_group.get_global_rect().get_center(), gold_group.get_viewport()))
	var coins = mini(amount, 5)
	for i in range(coins):
		var coin = GoldCoinVFXScene.new()
		WindowManager.get_vfx_layer().add_child(coin)
		coin.coin_landed.connect(func(_p):
			var t = gold_group.create_tween()
			gold_group.pivot_offset = gold_group.size / 2.0
			t.tween_property(gold_group, "scale", Vector2(1.2, 1.2), 0.05)
			t.tween_property(gold_group, "scale", Vector2(1.0, 1.0), 0.1)
		)
		coin.play(start_pos + Vector2(randf_range(-15, 15), randf_range(-8, 8)), target_pos, i * 0.08)
	await AnimationConstants.create_pausable_timer(get_tree(), (coins - 1) * 0.08 + 0.55).timeout

func _map_screen_to_vfx_viewport(screen_pos: Vector2) -> Vector2:
	var vfx_layer = WindowManager.get_vfx_layer()
	if is_instance_valid(vfx_layer):
		var vp = vfx_layer.get_viewport()
		return (vp.get_screen_transform() * vp.get_canvas_transform()).affine_inverse() * screen_pos
	return screen_pos

func _get_absolute_screen_pos(pos: Vector2, vp: Viewport = null) -> Vector2:
	if not vp: vp = get_viewport()
	return vp.get_screen_transform() * (vp.get_canvas_transform() * pos) if is_instance_valid(vp) else pos
