extends Control

const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")
const TokenSpendScene = preload("res://scenes/vfx/TokenSpendVFX.tscn")
const GoldCoinVFXScene = preload("res://scripts/vfx/GoldCoinVFX.gd")
const RejectionFeedbackScript = preload("res://scripts/vfx/RejectionFeedback.gd")
const InputUtils = preload("res://scripts/InputUtils.gd")
const ACTION_BUTTON_AVOID_SCOPE_META = "action_button_avoid_scope"

# Token costs
const COST_TIER1: int = 1
const COST_TIER2: int = 2
const COST_TIER3: int = 3

@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var prize_lineup: HBoxContainer = %PrizeLineup
@onready var study_button: Button = %StudyButton
@onready var leave_button: Button = %LeaveButton
@onready var effects_layer: CanvasLayer = $EffectsLayer

# Machines
@onready var tier1_machine: Control = %Tier1Machine
@onready var tier2_machine: Control = %Tier2Machine
@onready var tier3_machine: Control = %Tier3Machine
@onready var tier1_draw_button: Button = %Tier1Machine.get_draw_button() if %Tier1Machine.has_method("get_draw_button") else %Tier1Machine.get_node_or_null("DrawButton")
@onready var tier2_draw_button: Button = %Tier2Machine.get_draw_button() if %Tier2Machine.has_method("get_draw_button") else %Tier2Machine.get_node_or_null("DrawButton")
@onready var tier3_draw_button: Button = %Tier3Machine.get_draw_button() if %Tier3Machine.has_method("get_draw_button") else %Tier3Machine.get_node_or_null("DrawButton")

var _tokens: int = 0
var _prizes: Array[GachaBallInstance] = [null, null, null, null, null]
var _has_studied: bool = false
var _action_in_progress: bool = false
var _last_inventory_open: bool = false

var _trinity_t1_drawn: bool = false
var _trinity_t2_drawn: bool = false
var _trinity_t3_drawn: bool = false
var _trinity_rewarded: bool = false

func _ready() -> void:
	add_to_group("reward_scene")
	Audio.play_music(SoundRegistry.BGM_REWARD)
	
	# Clear pre-generated rewards and setup for dynamic token draws
	GameManager._temporary_reward_master_dict.clear()
	GameManager._temporary_reward_container = preload("res://scripts/FixedArrayContainer.gd").new(5)
	
	tier1_draw_button.pressed.connect(_on_tier1_draw_pressed)
	tier2_draw_button.pressed.connect(_on_tier2_draw_pressed)
	tier3_draw_button.pressed.connect(_on_tier3_draw_pressed)
	study_button.pressed.connect(_on_study_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	
	FlashcardManager.minigame_finished.connect(_on_flashcard_completed)
	SignalBus.flashcard_token_earned.connect(_on_live_token_earned)
	SignalBus.selection_changed.connect(_on_selection_changed)
	
	SignalBus.reward_collect_zone_activated.connect(_on_collect_pressed)
	SignalBus.reward_sell_zone_activated.connect(_on_sell_pressed)
	
	gui_input.connect(_on_gui_input)
	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()
	_mark_reward_action_buttons()
	_setup_prize_slots()
	
	_update_token_display()
	set_process(true)
	call_deferred("_show_initial_instruction")

func _show_initial_instruction() -> void:
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node) and main_node.has_method("show_action_instruction"):
		main_node.show_action_instruction(tr("ui.reward_instruction"))

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
				if not is_prize_selected:
					if main_node.has_method("show_action_instruction"):
						main_node.show_action_instruction(tr("ui.reward_instruction"))

func _exit_tree() -> void:
	if FlashcardManager.minigame_finished.is_connected(_on_flashcard_completed):
		FlashcardManager.minigame_finished.disconnect(_on_flashcard_completed)
	if SignalBus.flashcard_token_earned.is_connected(_on_live_token_earned):
		SignalBus.flashcard_token_earned.disconnect(_on_live_token_earned)
	if SignalBus.reward_collect_zone_activated.is_connected(_on_collect_pressed):
		SignalBus.reward_collect_zone_activated.disconnect(_on_collect_pressed)
	if SignalBus.reward_sell_zone_activated.is_connected(_on_sell_pressed):
		SignalBus.reward_sell_zone_activated.disconnect(_on_sell_pressed)

	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node):
		if main_node.has_method("hide_reward_drop_zones"):
			main_node.hide_reward_drop_zones()
		if main_node.has_method("hide_action_instruction"):
			main_node.hide_action_instruction()

func _mark_reward_action_buttons() -> void:
	_mark_action_button_for_inspection_avoidance(study_button)
	_mark_action_button_for_inspection_avoidance(leave_button)
	_mark_action_button_for_inspection_avoidance(tier1_draw_button)
	_mark_action_button_for_inspection_avoidance(tier2_draw_button)
	_mark_action_button_for_inspection_avoidance(tier3_draw_button)

func _mark_action_button_for_inspection_avoidance(button: Button) -> void:
	if is_instance_valid(button):
		button.set_meta(ACTION_BUTTON_AVOID_SCOPE_META, &"Rewards")

func _update_localized_text() -> void:
	if is_instance_valid(title_label):
		title_label.text = tr("ui.rewards_title")
	if is_instance_valid(description_label):
		description_label.text = tr("ui.reward_desc")
	
	study_button.text = tr("ui.study")
	leave_button.text = tr("ui.leave")
	
	var cost_t1 = GameManager.get_gacha_token_cost(1)
	var cost_t2 = GameManager.get_gacha_token_cost(2)
	var cost_t3 = GameManager.get_gacha_token_cost(3)
	
	tier1_draw_button.text = "Tier 1 prizes\n(%d Token%s)" % [cost_t1, "" if cost_t1 == 1 else "s"]
	tier2_draw_button.text = "Tier 2 prizes\n(%d Token%s)" % [cost_t2, "" if cost_t2 == 1 else "s"]
	tier3_draw_button.text = "Tier 3 prizes\n(%d Token%s)" % [cost_t3, "" if cost_t3 == 1 else "s"]

func _setup_prize_slots() -> void:
	var slots = prize_lineup.get_children()
	for i in range(slots.size()):
		var slot_view = slots[i]
		slot_view.set_size_scale(2.0)
		for child in slot_view.get_children():
			if child is TextureRect and (child.z_index == 10 or child.z_index == -1): continue
			child.queue_free()
		
		var loc = LocationIdentifier.new(&"Rewards", i)
		slot_view.populate(loc)
		slot_view.set_interaction_context(&"FULLY_INTERACTIVE", 0)

# --- Token Logic ---

func _on_study_pressed() -> void:
	if _has_studied or _action_in_progress: return
	_has_studied = true
	study_button.disabled = true
	if is_instance_valid(GameManager.run_state):
		FlashcardManager.start_minigame(GameManager.run_state, GameManager.run_state.active_deck_ids)

func _on_live_token_earned(amount: int) -> void:
	_tokens += amount
	_update_token_display()

func _on_flashcard_completed(_results: Dictionary) -> void:
	pass

func _update_token_display() -> void:
	SignalBus.emit_signal("gacha_tokens_changed", _tokens)
	SignalBus.emit_signal("gacha_tokens_visual_changed", _tokens)

# --- Draw Logic ---

func _on_tier1_draw_pressed() -> void:
	_try_draw_tier(1, GameManager.get_gacha_token_cost(1), tier1_machine)

func _on_tier2_draw_pressed() -> void:
	_try_draw_tier(2, GameManager.get_gacha_token_cost(2), tier2_machine)

func _on_tier3_draw_pressed() -> void:
	_try_draw_tier(3, GameManager.get_gacha_token_cost(3), tier3_machine)

func _try_draw_tier(tier: int, cost: int, machine: Control) -> void:
	if _action_in_progress: return
	
	var main_node = GameManager._active_main_node
	var token_group = main_node.get_node_or_null("%TokenGroup") if is_instance_valid(main_node) else null
	
	if _tokens < cost:
		RejectionFeedbackScript.play_rejection_with_counter(machine, token_group, get_tree())
		return
	
	var slot_index = _find_next_prize_slot()
	if slot_index == -1:
		# Lineup full
		RejectionFeedbackScript.play_rejection_with_counter(machine, null, get_tree())
		return
	
	_action_in_progress = true
	var button: Button = machine.get_draw_button() if machine.has_method("get_draw_button") else machine.get_node_or_null("DrawButton")
	if is_instance_valid(button):
		button.disabled = true
	
	# Animate Bargain Charm if it is providing a discount
	if GameManager.is_bargain_charm_active(tier):
		BattleAnimator.hop_trinket_by_definition_id(&"trinket_bargain_charm", false)
		await AnimationConstants.create_pausable_timer(get_tree(), 0.25).timeout
	
	await _animate_token_spend(machine, cost, token_group)
	
	_tokens -= cost
	_update_token_display()
	
	GameManager.use_gacha_discount(tier)
	_update_localized_text()
	
	var definition = _draw_definition_for_tier(tier)
	var instance = GachaBallInstance.new()
	instance.initialize(definition)
	
	# Add to GameManager so inspection windows resolve correctly
	instance.location_container_tag = &"Rewards"
	instance.location_slot_index = slot_index
	GameManager._temporary_reward_master_dict[instance.ball_uuid] = instance
	GameManager._temporary_reward_container.set_uuid(slot_index, instance.ball_uuid)
	
	# Animate draw and add prize
	await _animate_prize_draw(machine, slot_index, instance)
	_prizes[slot_index] = instance
	_populate_prize_slot(slot_index, instance)
	
	if GameManager.has_trinket(&"trinket_trinity_charm") and not _trinity_rewarded:
		if tier == 1: _trinity_t1_drawn = true
		elif tier == 2: _trinity_t2_drawn = true
		elif tier == 3: _trinity_t3_drawn = true
		if _trinity_t1_drawn and _trinity_t2_drawn and _trinity_t3_drawn:
			_trinity_rewarded = true
			_tokens += 1
			if is_instance_valid(GameManager.run_state):
				GameManager.run_state.total_tokens_earned += 1
			_update_token_display()
			_animate_trinity_token_gain()
	
	button.disabled = false
	_action_in_progress = false

func _animate_trinity_token_gain() -> void:
	var TokenPopVFXScene = preload("res://scenes/vfx/TokenPopVFX.tscn")
	var token_vfx = TokenPopVFXScene.instantiate()
	var effects_layer_vfx = WindowManager.get_vfx_layer()
	
	var trinket_view = null
	for node in get_tree().get_nodes_in_group("trinket_view"):
		if node.has_method("get_definition") and is_instance_valid(node.get_definition()):
			if node.get_definition().id == &"trinket_trinity_charm" and node.is_inside_tree() and node.visible:
				trinket_view = node
				break
				
	var start_pos = get_viewport().get_visible_rect().size / 2.0
	if is_instance_valid(trinket_view):
		start_pos = trinket_view.get_global_rect().get_center()
		
	var main_node = GameManager._active_main_node
	var token_group = main_node.get_node_or_null("%TokenGroup") if is_instance_valid(main_node) else null
	var target_pos = start_pos
	if is_instance_valid(token_group):
		var token_icon = token_group.get_node_or_null("TokenIcon")
		if is_instance_valid(token_icon):
			target_pos = token_icon.get_global_rect().get_center()
		else:
			target_pos = token_group.get_global_rect().get_center()
	
	token_vfx.position = start_pos
	effects_layer_vfx.add_child(token_vfx)
	token_vfx.setup(start_pos, target_pos)
	
	token_vfx.animation_finished.connect(func():
		Audio.play_sfx("coin_land")
		if is_instance_valid(token_group):
			var tween = create_tween()
			token_group.pivot_offset = token_group.size / 2.0
			tween.tween_property(token_group, "scale", Vector2(1.2, 1.2), 0.05)
			tween.tween_property(token_group, "scale", Vector2(1.0, 1.0), 0.1)
	)
	token_vfx.play(target_pos)
	Audio.play_sfx("coin_spawn", 1.0)

func _draw_definition_for_tier(tier: int) -> GachaBallDefinition:
	var eligible: Array[GachaBallDefinition] = []
	for definition in Database.get_all_pool_definitions():
		if not is_instance_valid(definition): continue
		if definition.tier != tier: continue
		eligible.append(definition)
	
	if eligible.is_empty():
		return null
	return eligible[randi() % eligible.size()]

func _find_next_prize_slot() -> int:
	for i in range(_prizes.size()):
		if _prizes[i] == null:
			return i
	return -1

# --- Animations ---

func _animate_token_spend(target_machine: Control, cost: int, token_group: Control) -> void:
	var start_pos: Vector2
	if is_instance_valid(token_group):
		var token_rect = token_group.get_global_rect()
		start_pos = token_rect.get_center()
	else:
		start_pos = Vector2(get_viewport_rect().size.x / 2, 60)
	
	var machine_rect = target_machine.get_global_rect()
	var target_pos = Vector2(machine_rect.get_center().x, machine_rect.position.y + machine_rect.size.y * 0.4)
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node):
		var content_area = main_node.get_node_or_null("%ContentArea")
		if is_instance_valid(content_area):
			target_pos += content_area.global_position
	
	
	var stagger_delay = 0.12
	for i in range(cost):
		var token_vfx = TokenSpendScene.instantiate()
		WindowManager.get_vfx_layer().add_child(token_vfx)
		token_vfx.coin_landed.connect(_on_coin_landed.bind(target_machine))
		Audio.play_sfx("token_spend", 1.0 + (i * 0.05))
		var offset = Vector2(randf_range(-15, 15), randf_range(-8, 8))
		token_vfx.play(start_pos + offset, target_pos, i * stagger_delay)
	
	await AnimationConstants.create_pausable_timer(get_tree(), (cost - 1) * stagger_delay + 0.55).timeout

func _on_coin_landed(_target_pos: Vector2, machine: Control) -> void:
	if not is_instance_valid(machine): return
	Audio.play_sfx("token_land")
	machine.pivot_offset = Vector2(machine.size.x / 2, machine.size.y)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(machine, "scale", Vector2(1.03, 0.97), 0.04)
	tween.tween_property(machine, "scale", Vector2(0.98, 1.02), 0.06).set_delay(0.04)
	tween.tween_property(machine, "scale", Vector2(1.0, 1.0), 0.08).set_delay(0.10).set_trans(Tween.TRANS_ELASTIC)

func _animate_prize_draw(machine: Control, slot_index: int, instance: GachaBallInstance) -> void:
	var draw_btn: Control = machine.get_draw_button() if machine.has_method("get_draw_button") else machine.get_node_or_null("DrawButton")
	var start_pos: Vector2 = draw_btn.get_global_rect().get_center() if is_instance_valid(draw_btn) else machine.get_global_rect().get_center()
	var target_slot = prize_lineup.get_child(slot_index)
	var end_pos = target_slot.get_global_rect().get_center()
	
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node):
		var content_area = main_node.get_node_or_null("%ContentArea")
		if is_instance_valid(content_area):
			start_pos += content_area.global_position
			end_pos += content_area.global_position
	
	
	var anim_ball = GachaBallViewScene.instantiate()
	WindowManager.get_vfx_layer().add_child(anim_ball)
	
	# Fix warning: Reset anchors before setting size for a manual-transform node
	anim_ball.anchors_preset = Control.PRESET_TOP_LEFT
	
	anim_ball.top_level = true
	anim_ball.z_index = 100
	anim_ball.force_inventory_mode = true
	# Use 1.0 scale (96x96) to match the inventory standard
	anim_ball.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	anim_ball.custom_minimum_size = Vector2(96, 96)
	anim_ball.size = Vector2(96, 96)
	anim_ball.populate(null, VisualDataAdapter.create_visual_data(instance))
	anim_ball.pivot_offset = anim_ball.size / 2.0
	
	var control_point = Vector2((start_pos.x + end_pos.x) / 2.0, min(start_pos.y, end_pos.y) - 200)
	var tween = create_tween()
	tween.tween_method(func(t: float):
		var eased_t = pow(t, 0.55)
		var scale_eased = 1.0 - pow(1.0 - t, 2)
		var current_scale = lerp(0.3, 1.0, scale_eased)
		anim_ball.scale = Vector2(current_scale, current_scale)
		var inv_t = 1.0 - eased_t
		var pos = (inv_t * inv_t * start_pos) + (2.0 * inv_t * eased_t * control_point) + (eased_t * eased_t * end_pos)
		anim_ball.global_position = pos - (anim_ball.pivot_offset * current_scale)
	, 0.0, 1.0, 0.45)
	
	await tween.finished
	anim_ball.queue_free()

func _populate_prize_slot(slot_index: int, instance: GachaBallInstance) -> void:
	var slot = prize_lineup.get_child(slot_index)
	if slot.has_method("set_content"):
		slot.set_content(VisualDataAdapter.create_visual_data(instance), true, false)

func _clear_prize_slot(slot_index: int) -> void:
	if _prizes[slot_index] != null:
		var uuid = _prizes[slot_index].ball_uuid
		
	_prizes[slot_index] = null
	var slot = prize_lineup.get_child(slot_index)
	if slot.has_method("set_content"):
		slot.set_content({}, false, false)

# --- Service Overlay & Drag Drop ---

func _on_selection_changed(new_location: LocationIdentifier) -> void:
	# Drop zone visibility is handled by Main.gd via the same signal
	pass

func _get_selected_prize() -> Dictionary:
	var selected_ctx = GlobalInteractionRouter.get_current_selection()
	if selected_ctx == null: return {}
	var selected_loc = selected_ctx.location if selected_ctx else null
	if not is_instance_valid(selected_loc): return {}
	if selected_loc.container != &"Rewards": return {}
	
	var instance = _prizes[selected_loc.index]
	if not is_instance_valid(instance): return {}
	
	return {
		"location": selected_loc,
		"instance": instance,
		"uuid": instance.ball_uuid
	}

func _on_collect_pressed(is_drag: bool = false, mouse_pos: Vector2 = Vector2.ZERO) -> void:
	if _action_in_progress: return
	var prize_data = _get_selected_prize()
	if prize_data.is_empty(): return
	
	_action_in_progress = true
	
	var loc = prize_data.location
	var instance = prize_data.instance
	var uuid = prize_data.uuid
	
	_clear_prize_slot(loc.index)
	SignalBus.emit_signal("selection_clear_requested")
	
	# Determine animation origin: use mouse position for Drag & Drop, slot center for Click-to-Get
	var start_pos = _get_slot_global_center(loc.index)
	
	if is_drag:
		# Use mouse_pos if provided, fallback to viewport if Zero
		if mouse_pos.is_zero_approx():
			start_pos = get_viewport().get_mouse_position()
		else:
			start_pos = mouse_pos
	
	var visual_data = VisualDataAdapter.create_visual_data(instance)
	var def = instance.get_definition()
	var tier: int = 1
	var target_trinket_slot: int = -1
	if def is GachaBallDefinition: tier = int(def.tier)
	if is_instance_valid(def) and def.category == &"TRINKET":
		tier = -1
		if is_instance_valid(GameManager.run_state):
			var trinket_container = GameManager.run_state.get_container(RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS)
			if trinket_container and trinket_container.has_method("find_first_empty_slot"):
				target_trinket_slot = trinket_container.find_first_empty_slot()
				if target_trinket_slot < 0: target_trinket_slot = 0
	
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node):
		if main_node.has_method("hide_reward_drop_zones"):
			main_node.hide_reward_drop_zones()
		if not WindowManager.is_run_inventory_window_open() and main_node.has_method("show_action_instruction"):
			main_node.show_action_instruction(tr("ui.reward_instruction"))
	
	if tier != -1:
		await _animate_gachaball_to_machine(start_pos, visual_data, tier)
		SignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": uuid})
		_action_in_progress = false
	else:
		await _animate_gachaball_to_trinket_bar(start_pos, visual_data, target_trinket_slot, uuid)
		SignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": uuid})
		_action_in_progress = false

func _on_sell_pressed(is_drag: bool = false, mouse_pos: Vector2 = Vector2.ZERO) -> void:
	if _action_in_progress: return
	var prize_data = _get_selected_prize()
	if prize_data.is_empty(): return
	
	_action_in_progress = true
	
	var loc = prize_data.location
	var instance = prize_data.instance
	
	# NEW: Use the dynamic gold value from the instance (half value, min 1 gold)
	var unit_value = instance.get_gold_value()
	var gold_yield = max(1, int(unit_value * 0.5))
	
	_clear_prize_slot(loc.index)
	SignalBus.emit_signal("selection_clear_requested")
	
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node):
		if main_node.has_method("hide_reward_drop_zones"):
			main_node.hide_reward_drop_zones()
		if not WindowManager.is_run_inventory_window_open() and main_node.has_method("show_action_instruction"):
			main_node.show_action_instruction(tr("ui.reward_instruction"))
	
	# Determine animation origin: use mouse position for Drag & Drop, slot center for Click-to-Sell
	var start_pos = _get_slot_global_center(loc.index)
	
	if is_drag:
		# Use mouse_pos if provided, fallback to viewport if Zero
		if mouse_pos.is_zero_approx():
			start_pos = get_viewport().get_mouse_position()
		else:
			start_pos = mouse_pos
	
	await _animate_gold_receive(gold_yield, start_pos)
	SignalBus.emit_signal("reward_chosen", {"type": "gold", "amount": gold_yield})
	_action_in_progress = false

func _get_slot_global_center(index: int) -> Vector2:
	var slot_view = prize_lineup.get_child(index)
	var center_pos: Vector2 = Vector2.ZERO
	if is_instance_valid(slot_view):
		center_pos = slot_view.get_global_rect().get_center()
		# Global center already includes screen position, but if Main uses ContentArea translation
		# we MUST subtract it to get the 'raw' screen position that WindowManager VFX layer expects
		var main_node = GameManager._active_main_node
		if is_instance_valid(main_node):
			var content_area = main_node.get_node_or_null("%ContentArea")
			if is_instance_valid(content_area):
				center_pos += content_area.global_position
	return center_pos

func _animate_gachaball_to_machine(start_pos: Vector2, visual_data: Dictionary, tier: int) -> void:
	var main_node = GameManager._active_main_node
	if not is_instance_valid(main_node):
		await get_tree().process_frame
		return
	
	var machine: Control = null
	if main_node.has_method("get_gacha_machine"):
		machine = main_node.get_gacha_machine(tier)
	else:
		# Fallback to direct name lookup if method doesn't exist
		machine = main_node.get_node_or_null("%%GachaMachine%d" % tier)
	
	if not is_instance_valid(machine):
		await get_tree().process_frame
		return
	
	# Target is outside ContentArea, so end_pos is already in screen coordinates
	var machine_rect = machine.get_global_rect()
	var end_pos: Vector2 = machine_rect.get_center()
	end_pos.y = machine_rect.position.y + machine_rect.size.y * 0.4
	
	var anim_ball = GachaBallViewScene.instantiate()
	Audio.play_sfx("ui_drag_drop")
	
	WindowManager.get_vfx_layer().add_child(anim_ball)
	
	# Fix warning: Reset anchors before setting size for a manual-transform node
	anim_ball.anchors_preset = Control.PRESET_TOP_LEFT
	
	anim_ball.top_level = true
	anim_ball.z_index = 100
	anim_ball.force_inventory_mode = true
	# Use 1.0 scale (96x96) to match the inventory standard
	anim_ball.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	anim_ball.custom_minimum_size = Vector2(96, 96)
	anim_ball.size = Vector2(96, 96)
	anim_ball.populate(null, visual_data)
	anim_ball.pivot_offset = anim_ball.size / 2.0
	
	var control_point = Vector2((start_pos.x + end_pos.x) / 2.0, min(start_pos.y, end_pos.y) - 200)
	var tween = create_tween()
	tween.tween_method(func(t: float):
		var eased_t = pow(t, 0.55)
		var scale_eased = 1.0 - pow(1.0 - t, 2)
		var current_scale = lerp(1.0, 1.0, scale_eased)
		anim_ball.scale = Vector2(current_scale, current_scale)
		var inv_t = 1.0 - eased_t
		var pos = (inv_t * inv_t * start_pos) + (2.0 * inv_t * eased_t * control_point) + (eased_t * eased_t * end_pos)
		anim_ball.global_position = pos - (anim_ball.pivot_offset * current_scale)
	, 0.0, 1.0, 0.45)
	
	await tween.finished
	Audio.play_sfx("coin_land")
	anim_ball.queue_free()
	if main_node.has_method("animate_machine_inventory_change"):
		main_node.animate_machine_inventory_change(tier, 1)

func _animate_gachaball_to_trinket_bar(start_pos: Vector2, visual_data: Dictionary, target_slot_index: int, instance_uuid: String) -> void:
	var main_node = GameManager._active_main_node
	if not is_instance_valid(main_node):
		await get_tree().process_frame
		return
	
	var trinket_bar = main_node.get_node_or_null("%PlayerTrinketBar")
	if not is_instance_valid(trinket_bar):
		await get_tree().process_frame
		return
	
	var slot_count = trinket_bar.get_child_count()
	if slot_count == 0:
		await get_tree().process_frame
		return
	target_slot_index = clampi(target_slot_index, 0, slot_count - 1)
	var target_slot = trinket_bar.get_child(target_slot_index) if target_slot_index < slot_count else null
	if not is_instance_valid(target_slot):
		await get_tree().process_frame
		return
	
	# Target is outside ContentArea, so end_pos is already in screen coordinates
	var target_rect = target_slot.get_global_rect()
	var end_pos = target_rect.get_center()
	
	var anim_ball = GachaBallViewScene.instantiate()
	WindowManager.get_vfx_layer().add_child(anim_ball)
	
	# Fix warning: Reset anchors before setting size for a manual-transform node
	anim_ball.anchors_preset = Control.PRESET_TOP_LEFT
	
	anim_ball.top_level = true
	anim_ball.z_index = 100
	anim_ball.force_inventory_mode = true
	# Use 1.0 scale (96x96) to match the inventory standard
	anim_ball.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	anim_ball.custom_minimum_size = Vector2(96, 96)
	anim_ball.size = Vector2(96, 96)
	anim_ball.populate(null, visual_data)
	anim_ball.pivot_offset = anim_ball.size / 2.0
	
	var control_point = Vector2((start_pos.x + end_pos.x) / 2.0, min(start_pos.y, end_pos.y) - 400)
	var tween = create_tween()
	tween.tween_method(func(t: float):
		var eased_t = pow(t, 0.55)
		var scale_eased = 1.0 - pow(1.0 - t, 2)
		var current_scale = lerp(1.0, 1.0, scale_eased)
		anim_ball.scale = Vector2(current_scale, current_scale)
		var inv_t = 1.0 - eased_t
		var pos = (inv_t * inv_t * start_pos) + (2.0 * inv_t * eased_t * control_point) + (eased_t * eased_t * end_pos)
		anim_ball.global_position = pos - (anim_ball.pivot_offset * current_scale)
	, 0.0, 1.0, 0.45)
	
	await tween.finished
	anim_ball.queue_free()
	SignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": instance_uuid})

func _animate_gold_receive(amount: int, start_pos: Vector2) -> void:
	var main_node = GameManager._active_main_node
	if not is_instance_valid(main_node):
		await get_tree().process_frame
		return
	
	var gold_group = main_node.get_node_or_null("%GoldGroup")
	if not is_instance_valid(gold_group):
		await get_tree().process_frame
		return
	
	var gold_icon = gold_group.get_node_or_null("GoldIcon")
	if not is_instance_valid(gold_icon): gold_icon = gold_group
	
	# Target is outside ContentArea, so target_pos is already in screen coordinates
	var gold_rect = gold_icon.get_global_rect()
	var target_pos = gold_rect.get_center()
	
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
	
	var total_wait = (coins_to_spawn - 1) * stagger_delay + 0.55
	await AnimationConstants.create_pausable_timer(get_tree(), total_wait).timeout

func _on_leave_pressed() -> void:
	if _action_in_progress: return
	
	# Auto collect sequence
	_action_in_progress = true
	leave_button.disabled = true
	study_button.disabled = true
	tier1_draw_button.disabled = true
	tier2_draw_button.disabled = true
	tier3_draw_button.disabled = true
	
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node) and main_node.has_method("hide_reward_drop_zones"):
		main_node.hide_reward_drop_zones()
	
	# Collect all remaining sequentially
	for i in range(_prizes.size()):
		var instance = _prizes[i]
		if is_instance_valid(instance):
			# Set selection context so we can re-use _on_collect_pressed? Or just run logic manually.
			var uuid = instance.ball_uuid
			var def = instance.get_definition()
			var tier: int = int(def.tier) if "tier" in def else 1
			var target_trinket_slot: int = -1
			if is_instance_valid(def) and def.category == &"TRINKET":
				tier = -1
				if is_instance_valid(GameManager.run_state):
					var trinket_container = GameManager.run_state.get_container(RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS)
					if trinket_container and trinket_container.has_method("find_first_empty_slot"):
						target_trinket_slot = trinket_container.find_first_empty_slot()
						if target_trinket_slot < 0: target_trinket_slot = 0
			
			var start_pos = _get_slot_global_center(i)
			var visual_data = VisualDataAdapter.create_visual_data(instance)
			
			_clear_prize_slot(i)
			
			if tier != -1:
				await _animate_gachaball_to_machine(start_pos, visual_data, tier)
				SignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": uuid})
			else:
				await _animate_gachaball_to_trinket_bar(start_pos, visual_data, target_trinket_slot, uuid)
				SignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": uuid})
	
	SignalBus.emit_signal("gacha_tokens_changed", 0)
	SignalBus.emit_signal("gacha_tokens_visual_changed", 0)
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

func populate(context: Dictionary) -> void:
	# Fallback in case GameManager calls populate(). With the new flow, we don't use context rewards.
	pass
