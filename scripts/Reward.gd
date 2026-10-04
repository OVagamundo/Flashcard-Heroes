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

var _tokens: int:
	get:
		if is_instance_valid(GameManager) and is_instance_valid(GameManager.run_state):
			return GameManager.run_state.get_room_tokens()
		return 0
	set(value):
		if is_instance_valid(GameManager) and is_instance_valid(GameManager.run_state):
			GameManager.run_state.current_room_tokens = value
var _prizes: Array[GachaBallInstance] = [null, null, null, null, null]
var _has_studied: bool = false
var _action_in_progress: bool = false
var _transient_drop_pos: Vector2 = Vector2.ZERO
var _last_inventory_open: bool = false

var _trinity_t1_drawn: bool = false
var _trinity_t2_drawn: bool = false
var _trinity_t3_drawn: bool = false
var _trinity_rewarded: bool = false

func _ready() -> void:
	add_to_group("reward_scene")
	Audio.play_music(SoundRegistry.BGM_REWARD)
	
	tier1_draw_button.pressed.connect(_on_tier1_draw_pressed)
	tier2_draw_button.pressed.connect(_on_tier2_draw_pressed)
	tier3_draw_button.pressed.connect(_on_tier3_draw_pressed)
	study_button.pressed.connect(_on_study_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	
	FlashcardManager.minigame_finished.connect(_on_flashcard_completed)
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
	var action := StudyRewardAction.new()
	if is_instance_valid(ActionQueue):
		ActionQueue.request(action)
	else:
		_execute_study()

func _execute_study() -> void:
	_has_studied = true
	study_button.disabled = true

func _on_flashcard_completed(_results: Dictionary) -> void:
	pass

func _update_token_display() -> void:
	SignalBus.emit_signal("gacha_tokens_changed", _tokens)

# --- Draw Logic ---

func _on_tier1_draw_pressed() -> void:
	_request_draw_tier(1)

func _on_tier2_draw_pressed() -> void:
	_request_draw_tier(2)

func _on_tier3_draw_pressed() -> void:
	_request_draw_tier(3)

func _request_draw_tier(tier: int) -> void:
	var action := DrawRewardAction.new(tier)
	if is_instance_valid(ActionQueue):
		ActionQueue.request(action)
	else:
		execute_draw_tier_visuals(tier)

func execute_draw_tier_visuals(tier: int, pre_drawn_instance: GachaBallInstance = null) -> void:
	var cost = GameManager.get_gacha_token_cost(tier)
	var machine = tier1_machine if tier == 1 else (tier2_machine if tier == 2 else tier3_machine)
	_try_draw_tier(tier, cost, machine, pre_drawn_instance)

func _try_draw_tier(tier: int, cost: int, machine: Control, pre_drawn_instance: GachaBallInstance = null) -> void:
	if _action_in_progress: return
	
	var main_node = GameManager._active_main_node
	var token_group = main_node.get_node_or_null("%TokenGroup") if is_instance_valid(main_node) else null
	
	if not is_instance_valid(pre_drawn_instance) and _tokens < cost:
		RejectionFeedbackScript.play_rejection_with_counter(machine, token_group, get_tree())
		if is_instance_valid(ActionQueue):
			ActionQueue.finish_action(ActionQueue.get_active_action())
		return
	
	var slot_index = pre_drawn_instance.location_slot_index if is_instance_valid(pre_drawn_instance) else _find_next_prize_slot()
	if slot_index == -1:
		# Lineup full
		RejectionFeedbackScript.play_rejection_with_counter(machine, null, get_tree())
		if is_instance_valid(ActionQueue):
			ActionQueue.finish_action(ActionQueue.get_active_action())
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
	
	var instance = pre_drawn_instance
	if not is_instance_valid(instance):
		instance = GameManager.create_reward_draw(tier, slot_index)
	_update_token_display()
	_update_localized_text()
	
	# Animate draw and add prize
	await _animate_prize_draw(machine, slot_index, instance)
	_prizes[slot_index] = instance
	_populate_prize_slot(slot_index, instance)
	
	if GameManager._trinity_rewarded and not _trinity_rewarded:
		_trinity_rewarded = true
		_update_token_display()
		_animate_trinity_token_gain()
	
	button.disabled = false
	_action_in_progress = false
	if is_instance_valid(ActionQueue):
		ActionQueue.finish_action(ActionQueue.get_active_action())

func _animate_trinity_token_gain() -> void:
	var trinket_view = null
	for node in get_tree().get_nodes_in_group("trinket_view"):
		if node.has_method("get_definition") and is_instance_valid(node.get_definition()):
			if node.get_definition().id == &"trinket_trinity_charm" and node.is_inside_tree() and node.visible:
				trinket_view = node
				break
				
	var start_pos = get_viewport().get_visible_rect().size / 2.0
	if is_instance_valid(trinket_view):
		start_pos = trinket_view.get_global_rect().get_center()
		
	await CurrencyAnimator.animate_token_gain(1, start_pos)

func _draw_definition_for_tier(tier: int) -> GachaBallDefinition:
	var eligible: Array[GachaBallDefinition] = []
	for definition in Database.get_all_pool_definitions():
		if not is_instance_valid(definition): continue
		if definition.tier != tier: continue
		eligible.append(definition)
	
	if eligible.is_empty():
		return null
	return RNGManager.reward_rng.pick_random(eligible)

func _find_next_prize_slot() -> int:
	for i in range(_prizes.size()):
		if _prizes[i] == null:
			return i
	return -1

# --- Animations ---

func _animate_token_spend(target_machine: Control, cost: int, _token_group: Control = null) -> void:
	var machine_rect = target_machine.get_global_rect()
	var target_pos = Vector2(machine_rect.get_center().x, machine_rect.position.y + machine_rect.size.y * 0.4)
	var on_token_landed := func(land_pos: Vector2):
		_on_coin_landed(land_pos, target_machine)
	await CurrencyAnimator.animate_token_spend(cost, target_pos, on_token_landed)

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
	var uuid = prize_data.uuid

	var drop_pos := Vector2.ZERO
	var interaction_type := "CLICK"
	if is_drag:
		drop_pos = mouse_pos if not mouse_pos.is_zero_approx() else GlobalInteractionRouter.get_last_pointer_position()
		interaction_type = "DRAG"
	_transient_drop_pos = drop_pos

	var action := CollectRewardAction.new(uuid, interaction_type, drop_pos)
	if is_instance_valid(ActionQueue):
		ActionQueue.request(action)
	else:
		execute_collect_visuals(uuid, drop_pos)

func execute_collect_visuals(uuid: String, p_drop_pos: Vector2 = Vector2.ZERO) -> void:
	var prize_data = _get_selected_prize()
	if prize_data.is_empty() or prize_data.uuid != uuid:
		# Search by uuid in prizes
		for i in range(_prizes.size()):
			if is_instance_valid(_prizes[i]) and _prizes[i].ball_uuid == uuid:
				prize_data = {
					"location": LocationIdentifier.new(&"Rewards", i),
					"instance": _prizes[i],
					"uuid": uuid
				}
				break
	if prize_data.is_empty():
		if is_instance_valid(ActionQueue):
			ActionQueue.finish_action(ActionQueue.get_active_action())
		return

	_action_in_progress = true
	var loc = prize_data.location
	var instance = prize_data.instance
	
	_clear_prize_slot(loc.index)
	SignalBus.emit_signal("selection_clear_requested")
	
	var start_pos = _get_slot_global_center(loc.index)
	if not p_drop_pos.is_zero_approx():
		start_pos = p_drop_pos
	elif not _transient_drop_pos.is_zero_approx():
		start_pos = _transient_drop_pos
		_transient_drop_pos = Vector2.ZERO
	
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

	if is_instance_valid(ActionQueue):
		ActionQueue.finish_action(ActionQueue.get_active_action())

func _on_sell_pressed(is_drag: bool = false, mouse_pos: Vector2 = Vector2.ZERO) -> void:
	if _action_in_progress: return
	var prize_data = _get_selected_prize()
	if prize_data.is_empty(): return
	var uuid = prize_data.uuid

	var drop_pos := Vector2.ZERO
	var interaction_type := "CLICK"
	if is_drag:
		drop_pos = mouse_pos if not mouse_pos.is_zero_approx() else GlobalInteractionRouter.get_last_pointer_position()
		interaction_type = "DRAG"
	_transient_drop_pos = drop_pos

	var action := SellRewardAction.new(uuid, interaction_type, drop_pos)
	if is_instance_valid(ActionQueue):
		ActionQueue.request(action)
	else:
		var gold_yield = GameManager.sell_reward_instance(uuid)
		execute_sell_visuals(uuid, gold_yield, drop_pos)

func execute_sell_visuals(uuid: String, gold_yield: int = -1, p_drop_pos: Vector2 = Vector2.ZERO) -> void:
	var prize_data = _get_selected_prize()
	if prize_data.is_empty() or prize_data.uuid != uuid:
		for i in range(_prizes.size()):
			if is_instance_valid(_prizes[i]) and _prizes[i].ball_uuid == uuid:
				prize_data = {
					"location": LocationIdentifier.new(&"Rewards", i),
					"instance": _prizes[i],
					"uuid": uuid
				}
				break
	if prize_data.is_empty():
		if is_instance_valid(ActionQueue):
			ActionQueue.finish_action(ActionQueue.get_active_action())
		return

	_action_in_progress = true
	var loc = prize_data.location
	var instance = prize_data.instance
	
	if gold_yield <= 0 and is_instance_valid(instance):
		var unit_value = instance.get_gold_value()
		gold_yield = max(1, int(unit_value * 0.5))
	
	_clear_prize_slot(loc.index)
	SignalBus.emit_signal("selection_clear_requested")
	
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node):
		if main_node.has_method("hide_reward_drop_zones"):
			main_node.hide_reward_drop_zones()
		if not WindowManager.is_run_inventory_window_open() and main_node.has_method("show_action_instruction"):
			main_node.show_action_instruction(tr("ui.reward_instruction"))
	
	var start_pos = _get_slot_global_center(loc.index)
	if not p_drop_pos.is_zero_approx():
		start_pos = p_drop_pos
	elif not _transient_drop_pos.is_zero_approx():
		start_pos = _transient_drop_pos
		_transient_drop_pos = Vector2.ZERO
	
	await _animate_gold_receive(gold_yield, start_pos)
	_action_in_progress = false

	if is_instance_valid(ActionQueue):
		ActionQueue.finish_action(ActionQueue.get_active_action())

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
	await CurrencyAnimator.animate_gold_gain(amount, start_pos)

func _on_leave_pressed() -> void:
	if _action_in_progress: return
	var action := LeaveRewardAction.new()
	if is_instance_valid(ActionQueue):
		ActionQueue.request(action)
	else:
		execute_leave_visuals()

func execute_leave_visuals() -> void:
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
