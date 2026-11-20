# res://scripts/Reward.gd
extends EncounterBase

@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var prize_lineup: HBoxContainer = %PrizeLineup
@onready var study_button: Button = %StudyButton
@onready var leave_button: Button = %LeaveButton

# Machines
@onready var tier1_machine: Control = %Tier1Machine
@onready var tier2_machine: Control = %Tier2Machine
@onready var tier3_machine: Control = %Tier3Machine
@onready var tier1_draw_button: Button = %Tier1Machine.get_node("DrawButton") as Button
@onready var tier2_draw_button: Button = %Tier2Machine.get_node("DrawButton") as Button
@onready var tier3_draw_button: Button = %Tier3Machine.get_node("DrawButton") as Button

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
var _trinity_rewarded: bool = false


func _ready() -> void:
	add_to_group("reward_scene")
	Audio.play_music(SoundRegistry.BGM_REWARD)

	if is_instance_valid(GameManager.run_state):
		GameManager.run_state.reset_room_tokens()

	tier1_draw_button.pressed.connect(func() -> void: _request_draw_tier(1))
	tier2_draw_button.pressed.connect(func() -> void: _request_draw_tier(2))
	tier3_draw_button.pressed.connect(func() -> void: _request_draw_tier(3))
	study_button.pressed.connect(_on_study_pressed)
	leave_button.pressed.connect(_on_leave_pressed)

	SignalBus.reward_collect_zone_activated.connect(_on_collect_pressed)
	SignalBus.reward_sell_zone_activated.connect(_on_sell_pressed)

	gui_input.connect(_handle_window_background_click)
	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()
	_mark_action_buttons_for_avoidance(
		[study_button, leave_button, tier1_draw_button, tier2_draw_button, tier3_draw_button],
		&"Rewards"
	)
	_setup_prize_slots()

	_update_token_display()
	set_process(true)
	call_deferred("_show_initial_instruction")


func _show_initial_instruction() -> void:
	var main_node: Node = GameManager._active_main_node
	if is_instance_valid(main_node):
		main_node.show_action_instruction(tr("ui.reward_instruction"))


func _process(_delta: float) -> void:
	_sync_reward_inventory_overlay("ui.reward_instruction", true)


func _exit_tree() -> void:
	if SignalBus.reward_collect_zone_activated.is_connected(_on_collect_pressed):
		SignalBus.reward_collect_zone_activated.disconnect(_on_collect_pressed)
	if SignalBus.reward_sell_zone_activated.is_connected(_on_sell_pressed):
		SignalBus.reward_sell_zone_activated.disconnect(_on_sell_pressed)

	var main_node: Node = GameManager._active_main_node
	if is_instance_valid(main_node):
		main_node.hide_reward_drop_zones()
		main_node.hide_action_instruction()


func _update_localized_text() -> void:
	if is_instance_valid(title_label):
		title_label.text = tr("ui.rewards_title")
	if is_instance_valid(description_label):
		description_label.text = tr("ui.reward_desc")

	study_button.text = tr("ui.study")
	leave_button.text = tr("ui.leave")

	var cost_t1: int = GameManager.get_gacha_token_cost(1)
	var cost_t2: int = GameManager.get_gacha_token_cost(2)
	var cost_t3: int = GameManager.get_gacha_token_cost(3)

	var tier_prize_format: String = tr("ui.reward_tier_prizes")
	tier1_draw_button.text = tier_prize_format % [1, cost_t1, "" if cost_t1 == 1 else "s"]
	tier2_draw_button.text = tier_prize_format % [2, cost_t2, "" if cost_t2 == 1 else "s"]
	tier3_draw_button.text = tier_prize_format % [3, cost_t3, "" if cost_t3 == 1 else "s"]


func _setup_prize_slots() -> void:
	var slots: Array[Node] = prize_lineup.get_children()
	for i: int in range(slots.size()):
		var slot_view: SlotView = slots[i] as SlotView
		slot_view.set_size_scale(2.0)
		for child in slot_view.get_children():
			if child is TextureRect and (child.z_index == 10 or child.z_index == -1):
				continue
			child.queue_free()
		slot_view.populate(LocationIdentifier.new(&"Rewards", i))
		slot_view.set_interaction_context(&"FULLY_INTERACTIVE", 0)


# --- Token & Draw Logic ---

func _on_study_pressed() -> void:
	if _has_studied or _action_in_progress:
		return
	ActionQueue.request(StudyRewardAction.new())


func _execute_study() -> void:
	_has_studied = true
	study_button.disabled = true


func _update_token_display() -> void:
	SignalBus.gacha_tokens_changed.emit(_tokens)


func _get_tier_machine(tier: int) -> Control:
	if tier == 1:
		return tier1_machine
	if tier == 2:
		return tier2_machine
	return tier3_machine


func _request_draw_tier(tier: int) -> void:
	var cost: int = GameManager.get_gacha_token_cost(tier)
	var machine: Control = _get_tier_machine(tier)
	var main_node: Node = GameManager._active_main_node
	var token_group: Control = main_node.get_node_or_null("%TokenGroup") as Control if is_instance_valid(main_node) else null

	if _tokens < cost:
		RejectionFeedbackScript.play_rejection_with_counter(machine, token_group, get_tree())
		return
	if _find_next_prize_slot() == -1:
		RejectionFeedbackScript.play_rejection_with_counter(machine, null, get_tree())
		return

	ActionQueue.request(DrawRewardAction.new(tier))


func play_transaction_log(event_log: Dictionary) -> void:
	if not event_log.get("success", false):
		_finish_active_action()
		return
	var tier: int = int(event_log.get("tier", 1))
	var cost: int = int(event_log.get("cost", tier))
	var discount_applied: bool = bool(event_log.get("discount_applied", false))
	var instance: GachaBallInstance = event_log.get("drawn_instance", null) as GachaBallInstance
	var slot_index: int = int(event_log.get("slot_index", -1))
	var trinity_triggered: bool = bool(event_log.get("trinity_triggered", false))
	_execute_draw_presentation(tier, cost, discount_applied, instance, slot_index, trinity_triggered)


func execute_draw_tier_visuals(tier: int, pre_drawn_instance: GachaBallInstance = null) -> void:
	if is_instance_valid(pre_drawn_instance):
		var slot_index: int = pre_drawn_instance.location_slot_index if pre_drawn_instance.location_slot_index != -1 else _find_next_prize_slot()
		var cost: int = GameManager.get_gacha_token_cost(tier)
		_execute_draw_presentation(tier, cost, false, pre_drawn_instance, slot_index, false)
	else:
		play_transaction_log(GameManager.simulate_reward_draw(tier))


func _execute_draw_presentation(
	tier: int,
	cost: int,
	discount_applied: bool,
	instance: GachaBallInstance,
	slot_index: int,
	trinity_triggered: bool
) -> void:
	if _action_in_progress:
		return
	_action_in_progress = true

	var machine: Control = _get_tier_machine(tier)
	var main_node: Node = GameManager._active_main_node
	var button: Button = machine.get_node_or_null("DrawButton") as Button
	if is_instance_valid(button):
		button.disabled = true

	# Bracket token animations when both spend + Trinity Charm gain happen in one transaction.
	var is_bracketed: bool = trinity_triggered and is_instance_valid(main_node)
	if is_bracketed:
		main_node.begin_token_animation()

	if discount_applied:
		BattleAnimator.hop_trinket_by_definition_id(&"trinket_bargain_charm", false)
		await AnimationConstants.create_pausable_timer(get_tree(), 0.25).timeout

	await _animate_machine_token_spend(machine, cost)

	_update_token_display()
	_update_localized_text()

	await _animate_prize_draw(machine, slot_index, instance)
	_prizes[slot_index] = instance
	_populate_prize_slot(slot_index, instance)

	if trinity_triggered:
		_trinity_rewarded = true
		_update_token_display()
		await _animate_trinity_token_gain()

	if is_bracketed:
		main_node.end_token_animation()

	if is_instance_valid(button):
		button.disabled = false
	_action_in_progress = false
	_finish_active_action()


func _animate_trinity_token_gain() -> void:
	var trinket_view: GachaBallView = null
	for node in get_tree().get_nodes_in_group("trinket_view"):
		if node is GachaBallView and node.is_inside_tree() and (node as GachaBallView).visible:
			if (node as GachaBallView).get_definition_id() == &"trinket_trinity_charm":
				trinket_view = node as GachaBallView
				break

	var start_pos: Vector2 = get_viewport().get_visible_rect().size / 2.0
	if is_instance_valid(trinket_view):
		start_pos = trinket_view.get_global_rect().get_center()
	await CurrencyAnimator.animate_token_gain(1, start_pos)


func _find_next_prize_slot() -> int:
	for i: int in range(_prizes.size()):
		if _prizes[i] == null:
			return i
	return -1


# --- Animations ---

func _animate_prize_draw(machine: Control, slot_index: int, instance: GachaBallInstance) -> void:
	var draw_btn: Control = machine.get_node_or_null("DrawButton") as Control
	var start_pos: Vector2 = draw_btn.get_global_rect().get_center() if is_instance_valid(draw_btn) else machine.get_global_rect().get_center()
	var end_pos: Vector2 = _get_content_slot_global_center(prize_lineup, slot_index)

	var main_node: Node = GameManager._active_main_node
	if is_instance_valid(main_node):
		var content_area: Control = main_node.get_node_or_null("%ContentArea") as Control
		if is_instance_valid(content_area):
			start_pos += content_area.global_position

	var anim_ball: GachaBallView = _spawn_vfx_gachaball(VisualDataAdapter.create_visual_data(instance), Vector2(96, 96), true, true)
	var tween: Tween = ArcTossAnimator.toss_bezier(anim_ball, start_pos, end_pos, {
		"arc_height": 200.0,
		"duration": 0.45,
		"ease_power": 0.55,
		"start_scale": 0.3,
		"end_scale": 1.0,
		"scale_curve": &"quad_out",
		"scale_pivot_offset": true,
	})
	await tween.finished
	anim_ball.queue_free()


func _populate_prize_slot(slot_index: int, instance: GachaBallInstance) -> void:
	var slot: SlotView = prize_lineup.get_child(slot_index) as SlotView
	slot.set_content(VisualDataAdapter.create_visual_data(instance), true, false)


func _clear_prize_slot(slot_index: int) -> void:
	_prizes[slot_index] = null
	var slot: SlotView = prize_lineup.get_child(slot_index) as SlotView
	slot.set_content({}, false, false)


# --- Collect, Sell & Leave ---

func _on_collect_pressed(is_drag: bool = false, mouse_pos: Vector2 = Vector2.ZERO) -> void:
	if _action_in_progress:
		return
	var prize_data: Dictionary = _get_selected_reward_entry(_prizes)
	if prize_data.is_empty():
		return
	var drop: Dictionary = _resolve_drop_interaction(is_drag, mouse_pos)
	ActionQueue.request(CollectRewardAction.new(prize_data["uuid"], drop["interaction_type"], drop["drop_pos"]))


func execute_collect_visuals(uuid: String, p_drop_pos: Vector2 = Vector2.ZERO) -> void:
	var prize_data: Dictionary = _resolve_reward_entry_by_uuid(_prizes, uuid)
	if prize_data.is_empty():
		_finish_active_action()
		return

	_action_in_progress = true
	var loc: LocationIdentifier = prize_data["location"] as LocationIdentifier
	var instance: GachaBallInstance = prize_data["instance"] as GachaBallInstance

	_clear_prize_slot(loc.index)
	SignalBus.selection_clear_requested.emit()

	var start_pos: Vector2 = _consume_animation_start_pos(_get_content_slot_global_center(prize_lineup, loc.index), p_drop_pos)
	var main_node: Node = GameManager._active_main_node
	if is_instance_valid(main_node):
		main_node.hide_reward_drop_zones()
		if not WindowManager.is_run_inventory_window_open():
			main_node.show_action_instruction(tr("ui.reward_instruction"))

	await _collect_instance_to_destination(instance, start_pos)
	_action_in_progress = false
	_finish_active_action()


func _collect_instance_to_destination(instance: GachaBallInstance, start_pos: Vector2) -> void:
	var uuid: String = instance.ball_uuid
	var visual_data: Dictionary = VisualDataAdapter.create_visual_data(instance)
	var def: Resource = instance.get_definition()
	var is_trinket: bool = is_instance_valid(def) and "category" in def and def.category == &"TRINKET"

	if is_trinket:
		var target_slot: int = _find_first_empty_trinket_slot()
		await _animate_gachaball_to_trinket_bar(start_pos, visual_data, target_slot, 1.0, false, true)
	else:
		var tier: int = int((def as GachaBallDefinition).tier) if def is GachaBallDefinition else 1
		await _animate_gachaball_to_machine(start_pos, visual_data, tier)

	SignalBus.reward_chosen.emit({"type": "gachaball", "instance_uuid": uuid})


func _on_sell_pressed(is_drag: bool = false, mouse_pos: Vector2 = Vector2.ZERO) -> void:
	if _action_in_progress:
		return
	var prize_data: Dictionary = _get_selected_reward_entry(_prizes)
	if prize_data.is_empty():
		return
	var drop: Dictionary = _resolve_drop_interaction(is_drag, mouse_pos)
	ActionQueue.request(SellRewardAction.new(prize_data["uuid"], drop["interaction_type"], drop["drop_pos"]))


func execute_sell_visuals(uuid: String, gold_yield: int = -1, p_drop_pos: Vector2 = Vector2.ZERO) -> void:
	var prize_data: Dictionary = _resolve_reward_entry_by_uuid(_prizes, uuid)
	if prize_data.is_empty():
		_finish_active_action()
		return

	_action_in_progress = true
	var loc: LocationIdentifier = prize_data["location"] as LocationIdentifier
	var instance: GachaBallInstance = prize_data["instance"] as GachaBallInstance

	if gold_yield <= 0 and is_instance_valid(instance):
		gold_yield = maxi(1, int(instance.get_gold_value() * 0.5))

	_clear_prize_slot(loc.index)
	SignalBus.selection_clear_requested.emit()

	var main_node: Node = GameManager._active_main_node
	if is_instance_valid(main_node):
		main_node.hide_reward_drop_zones()
		if not WindowManager.is_run_inventory_window_open():
			main_node.show_action_instruction(tr("ui.reward_instruction"))

	var start_pos: Vector2 = _consume_animation_start_pos(_get_content_slot_global_center(prize_lineup, loc.index), p_drop_pos)
	await CurrencyAnimator.animate_gold_gain(gold_yield, start_pos)
	_action_in_progress = false
	_finish_active_action()


func _on_leave_pressed() -> void:
	if _action_in_progress:
		return
	ActionQueue.request(LeaveRewardAction.new())


func execute_leave_visuals() -> void:
	_action_in_progress = true
	leave_button.disabled = true
	study_button.disabled = true
	tier1_draw_button.disabled = true
	tier2_draw_button.disabled = true
	tier3_draw_button.disabled = true

	var main_node: Node = GameManager._active_main_node
	if is_instance_valid(main_node):
		main_node.hide_reward_drop_zones()
		main_node.hide_empty_trinket_slots()

	for i: int in range(_prizes.size()):
		var instance: GachaBallInstance = _prizes[i]
		if is_instance_valid(instance):
			var start_pos: Vector2 = _get_content_slot_global_center(prize_lineup, i)
			_clear_prize_slot(i)
			await _collect_instance_to_destination(instance, start_pos)

	if is_instance_valid(GameManager.run_state):
		GameManager.run_state.reset_room_tokens()
	else:
		SignalBus.gacha_tokens_changed.emit(0)
	SignalBus.path_choice_scene_requested.emit()
	queue_free()


func populate(_context: Dictionary) -> void:
	pass
