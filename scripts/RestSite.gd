# res://scripts/RestSite.gd
extends Control
class_name ResourceSite

## Rest Site with token-based stat gacha system
## Supports HP, PWR, and GOLD variations

const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")
const TokenSpendScene = preload("res://scenes/vfx/TokenSpendVFX.tscn")
const RejectionFeedbackScript = preload("res://scripts/vfx/RejectionFeedback.gd")
const InputUtils = preload("res://scripts/InputUtils.gd")

enum SiteType { HP, PWR, GOLD }

@export var site_type: SiteType = SiteType.HP

# Machine references
@onready var tier1_machine: Control = %Tier1Machine
@onready var tier2_machine: Control = %Tier2Machine
@onready var tier3_machine: Control = %Tier3Machine

@onready var tier1_draw_button: Button = tier1_machine.get_node("DrawButton")
@onready var tier2_draw_button: Button = tier2_machine.get_node("DrawButton")
@onready var tier3_draw_button: Button = tier3_machine.get_node("DrawButton")

# UI references
@onready var study_button: Button = %StudyButton
@onready var leave_button: Button = %LeaveButton
@onready var prize_lineup: HBoxContainer = %PrizeLineup
@onready var hero_slot: Control = %HeroSlot
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var effects_layer: CanvasLayer = $EffectsLayer

# Token costs
const COST_TIER1: int = 1
const COST_TIER2: int = 2
const COST_TIER3: int = 3

# State
var _tokens: int = 0
var _prizes: Array[Dictionary] = [] # [{slot_index, stat_type, hp_value, pwr_value, gold_value}]
var _has_studied: bool = false # Study button only works once per rest site

func _ready() -> void:
	# AUDIO HOOK: Rest Site BGM
	Audio.play_music(SoundRegistry.BGM_REST)
	
	# Connect buttons
	tier1_draw_button.pressed.connect(_on_tier1_draw_pressed)
	tier2_draw_button.pressed.connect(_on_tier2_draw_pressed)
	tier3_draw_button.pressed.connect(_on_tier3_draw_pressed)
	study_button.pressed.connect(_on_study_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	
	# Connect to flashcard completion
	FlashcardManager.minigame_finished.connect(_on_flashcard_completed)
	
	# Connect to live token updates during minigame
	SignalBus.flashcard_token_earned.connect(_on_live_token_earned)
	
	# Connect locale changes
	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()
	
	# Timekeeper hero bonus: Start with 5 tokens for easy testing
	if _is_timekeeper_hero():
		_tokens = 5
	
	# Initialize token display
	_update_token_display()
	_update_button_states()
	_populate_hero_slot()
	_setup_prize_slot_clicks()

func setup_site() -> void:
	"""Call this after setting site_type to correctly initialize visuals and tutorials"""
	_update_localized_text()
	_setup_machine_visuals()
	
	# Show site-specific tutorial
	var tutorial_key = "rest_site_intro"
	var tutorial_text = "tutorial.rest_site"
	
	match site_type:
		SiteType.PWR:
			tutorial_key = "training_grounds_intro"
			tutorial_text = "tutorial.training_grounds"
		SiteType.GOLD:
			tutorial_key = "gambling_den_intro"
			tutorial_text = "tutorial.gambling_den"
			
	TutorialManager.show_tutorial(tutorial_key, [
		{"text": tr(tutorial_text)}
	])

func _update_localized_text() -> void:
	match site_type:
		SiteType.HP:
			title_label.text = tr("ui.rest_site")
		SiteType.PWR:
			title_label.text = tr("ui.training_grounds")
		SiteType.GOLD:
			title_label.text = tr("ui.gambling_den")
	
	study_button.text = tr("ui.study")
	leave_button.text = tr("ui.leave")

func _setup_machine_visuals() -> void:
	"""Configure machine labels and colors based on site type"""
	var machines = [tier1_machine, tier2_machine, tier3_machine]
	var costs = [COST_TIER1, COST_TIER2, COST_TIER3]
	
	var stat_label_text = ""
	var stat_color = Color.WHITE
	
	match site_type:
		SiteType.HP:
			stat_label_text = "HP"
			stat_color = Color.RED
		SiteType.PWR:
			stat_label_text = "PWR"
			stat_color = Color.MEDIUM_PURPLE
		SiteType.GOLD:
			stat_label_text = "GOLD"
			stat_color = Color.GOLD
	
	for i in range(machines.size()):
		var machine = machines[i]
		var label = machine.get_node("StatLabel")
		var button = machine.get_node("DrawButton")
		
		label.text = stat_label_text
		label.add_theme_color_override("font_color", stat_color)
		button.text = "%d Tokens" % costs[i]

func _populate_hero_slot() -> void:
	"""Display the hero in the first slot with entry animation"""
	if not is_instance_valid(GameManager.run_state) or not is_instance_valid(GameManager.run_state.hero_instance):
		return
	
	var hero = GameManager.run_state.hero_instance
	var visual_data = VisualDataAdapter.create_visual_data(hero)
	
	if hero_slot.has_method("set_content"):
		hero_slot.set_content(visual_data, true, false)
	
	# Animate hero entry after layout is ready
	await get_tree().process_frame
	_animate_hero_entry()

func _animate_hero_entry() -> void:
	"""Animate hero appearing with landing bounce"""
	# Find GachaBallView in hero slot
	var ball_view: GachaBallView = null
	for child in hero_slot.get_children():
		if child is GachaBallView:
			ball_view = child
			break
	
	if is_instance_valid(ball_view) and is_instance_valid(ball_view.icon_rect):
		# Hide initially
		ball_view.icon_rect.scale = Vector2.ZERO
		ball_view.icon_rect.pivot_offset = ball_view.icon_rect.size / 2.0
		
		# Animate reveal with bounce (small delay for polish)
		var wait_tween = ball_view.create_tween()
		wait_tween.tween_interval(0.05)
		wait_tween.tween_callback(func():
			if is_instance_valid(ball_view) and is_instance_valid(ball_view.icon_rect):
				ball_view.icon_rect.scale = Vector2.ONE
				ball_view.play_landing_bounce()
		)

func _setup_prize_slot_clicks() -> void:
	"""Setup click handlers for prize slots"""
	var slots = prize_lineup.get_children()
	for i in range(1, slots.size()): # Skip hero slot (index 0)
		var slot = slots[i]
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_prize_slot_gui_input.bind(i - 1))

# --- Token System ---

func _on_study_pressed() -> void:
	"""Open flashcard minigame to earn tokens - only once per rest site"""
	if _has_studied:
		return
	
	_has_studied = true
	study_button.disabled = true
	
	if is_instance_valid(GameManager.run_state):
		FlashcardManager.start_minigame(GameManager.run_state, GameManager.run_state.active_deck_ids)

func _on_live_token_earned(amount: int) -> void:
	"""Called when a token lands during flashcard minigame animation"""
	_tokens += amount
	_update_token_display()

func _on_flashcard_completed(_results: Dictionary) -> void:
	pass

func _update_token_display() -> void:
	"""Update the top-area token counter via the existing signal"""
	SignalBus.emit_signal("gacha_tokens_changed", _tokens)

func _update_button_states() -> void:
	pass

# --- Draw Logic ---

func _on_tier1_draw_pressed() -> void:
	_try_draw_tier(1, COST_TIER1, tier1_machine)

func _on_tier2_draw_pressed() -> void:
	_try_draw_tier(2, COST_TIER2, tier2_machine)

func _on_tier3_draw_pressed() -> void:
	_try_draw_tier(3, COST_TIER3, tier3_machine)

func _try_draw_tier(tier: int, cost: int, machine: Control) -> void:
	"""Attempt to draw a prize from a machine"""
	var main_node = GameManager._active_main_node
	var token_group = main_node.get_node_or_null("%TokenGroup") if is_instance_valid(main_node) else null
	
	if _tokens < cost:
		RejectionFeedbackScript.play_rejection_with_counter(machine, token_group, get_tree())
		return
	
	var button = machine.get_node("DrawButton")
	button.disabled = true
	
	# Animate token spend
	await _animate_token_spend(machine, cost, token_group)
	
	# Deduct tokens
	_tokens -= cost
	_update_token_display()
	
	# Roll value
	var value = _roll_value_for_tier(tier)
	
	# Find next available prize slot
	var slot_index = _find_next_prize_slot()
	if slot_index == -1:
		_auto_apply_oldest_prize()
		slot_index = 0
	
	var prize_data = {
		"slot_index": slot_index,
		"hp_value": value if site_type == SiteType.HP else 0,
		"pwr_value": value if site_type == SiteType.PWR else 0,
		"gold_value": value if site_type == SiteType.GOLD else 0
	}
	
	# Animate draw and add prize
	await _animate_prize_draw(machine, slot_index, prize_data)
	_prizes.append(prize_data)
	_populate_prize_slot(slot_index, prize_data)
	
	button.disabled = _tokens < cost

func _roll_value_for_tier(tier: int) -> int:
	"""Roll prize value based on tier (1: 0-1, 2: 0-3, 3: 0-5)"""
	match tier:
		1: return randi() % 2
		2: return randi() % 4
		3: return randi() % 6
	return 0

func _find_next_prize_slot() -> int:
	for i in range(4):
		var has_prize = false
		for prize in _prizes:
			if prize.slot_index == i:
				has_prize = true
				break
		if not has_prize:
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
	
	var stagger_delay = 0.12
	for i in range(cost):
		var token_vfx = TokenSpendScene.instantiate()
		effects_layer.add_child(token_vfx)
		token_vfx.coin_landed.connect(_on_coin_landed.bind(target_machine))
		Audio.play_sfx("token_spend", 1.0 + (i * 0.05))
		var offset = Vector2(randf_range(-15, 15), randf_range(-8, 8))
		token_vfx.play(start_pos + offset, target_pos, i * stagger_delay)
	
	await get_tree().create_timer((cost - 1) * stagger_delay + 0.55).timeout

func _on_coin_landed(_target_pos: Vector2, machine: Control) -> void:
	if not is_instance_valid(machine): return
	Audio.play_sfx("token_land")
	var machine_image = machine.get_node_or_null("MachineImage")
	machine.pivot_offset = Vector2(machine.size.x / 2, machine.size.y)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(machine, "scale", Vector2(1.03, 0.97), 0.04)
	tween.tween_property(machine, "scale", Vector2(0.98, 1.02), 0.06).set_delay(0.04)
	tween.tween_property(machine, "scale", Vector2(1.0, 1.0), 0.08).set_delay(0.10).set_trans(Tween.TRANS_ELASTIC)

func _animate_prize_draw(machine: Control, slot_index: int, prize_data: Dictionary) -> void:
	var start_pos = machine.get_node("DrawButton").get_global_rect().get_center()
	var target_slot = prize_lineup.get_child(slot_index + 1)
	var end_pos = target_slot.get_global_rect().get_center()
	
	var anim_ball = GachaBallViewScene.instantiate()
	effects_layer.add_child(anim_ball)
	anim_ball.force_inventory_mode = true
	anim_ball.custom_minimum_size = Vector2(128, 128)
	anim_ball.size = Vector2(128, 128)
	anim_ball.populate(null, _create_prize_visual_data(prize_data))
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

func _create_prize_visual_data(prize_data: Dictionary) -> Dictionary:
	var icon_tex = preload("res://assets/ui/textures/gachaballcapsule.png")
	return {
		"uuid": "prize_%d" % prize_data.slot_index,
		"icon": icon_tex,
		"hp": prize_data.hp_value,
		"pwr": prize_data.pwr_value,
		"gold": prize_data.gold_value,
		"display_name_key": "ui.stat_prize",
		"tier": 0,
		"category": &"ITEM"
	}

func _populate_prize_slot(slot_index: int, prize_data: Dictionary) -> void:
	var slot = prize_lineup.get_child(slot_index + 1)
	if slot.has_method("set_content"):
		slot.set_content(_create_prize_visual_data(prize_data), true, false)
	_add_stat_label_to_slot(slot, prize_data)

func _add_stat_label_to_slot(slot: Control, prize_data: Dictionary) -> void:
	var existing = slot.get_node_or_null("StatLabelContainer")
	if existing: existing.queue_free()
	
	var container = VBoxContainer.new()
	container.name = "StatLabelContainer"
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(container)
	
	var val = prize_data.hp_value + prize_data.pwr_value + prize_data.gold_value
	if val > 0:
		var label = Label.new()
		label.text = "%d" % val
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 36)
		var color = Color.RED if prize_data.hp_value > 0 else (Color.MEDIUM_PURPLE if prize_data.pwr_value > 0 else Color.GOLD)
		label.add_theme_color_override("font_color", color)
		label.add_theme_color_override("font_outline_color", Color.WHITE)
		label.add_theme_constant_override("outline_size", 6)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(label)

# --- Prize Application ---

func _on_prize_slot_gui_input(event: InputEvent, prize_index: int) -> void:
	if InputUtils.is_primary_pointer_press(event):
		_apply_prize(prize_index)

func _apply_prize(prize_index: int) -> void:
	Audio.play_sfx("ui_click")
	var p_idx = -1
	for i in range(_prizes.size()):
		if _prizes[i].slot_index == prize_index:
			p_idx = i
			break
	if p_idx == -1: return
	
	var prize = _prizes[p_idx]
	_prizes.remove_at(p_idx)
	
	await _animate_buff_application(prize_index, prize)
	_apply_stat_to_hero(prize)
	_clear_prize_slot(prize_index)
	_populate_hero_slot()

func _apply_stat_to_hero(prize_data: Dictionary) -> void:
	if not is_instance_valid(GameManager.run_state): return
	
	if site_type == SiteType.GOLD:
		GameManager.run_state.add_gold(prize_data.gold_value)
	elif is_instance_valid(GameManager.run_state.hero_instance):
		var hero_uuid = GameManager.run_state.hero_instance.ball_uuid
		GameManager.run_state.modify_unit_base_stats(hero_uuid, prize_data.hp_value, prize_data.pwr_value)

func _animate_buff_application(prize_index: int, prize_data: Dictionary) -> void:
	var prize_slot = prize_lineup.get_child(prize_index + 1)
	var ball_view: GachaBallView = null
	for child in prize_slot.get_children():
		if child is GachaBallView:
			ball_view = child
			break
	if not is_instance_valid(ball_view): return
	
	var start_pos = ball_view.get_global_rect().get_center()
	var end_pos: Vector2
	if site_type == SiteType.GOLD:
		var main_node = GameManager._active_main_node
		var gold_group = main_node.get_node_or_null("%GoldGroup") if is_instance_valid(main_node) else null
		end_pos = gold_group.get_global_rect().get_center() if gold_group else Vector2(100, 60)
	else:
		end_pos = hero_slot.get_global_rect().get_center()
	
	ball_view.pivot_offset = ball_view.size / 2.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(ball_view, "scale", Vector2(1.4, 1.4), 0.1)
	tween.tween_property(ball_view, "modulate:a", 0.0, 0.15).set_delay(0.1)
	
	var val = prize_data.hp_value + prize_data.pwr_value + prize_data.gold_value
	var type_str = "hp" if prize_data.hp_value > 0 else ("pwr" if prize_data.pwr_value > 0 else "gold")
	
	var proj = VFXFactory.spawn_projectile_on_layer(val, type_str, start_pos, end_pos, false)
	if proj:
		proj.launch()
		await proj.impact
		if site_type != SiteType.GOLD:
			_do_hero_buff_hop(Color.RED if type_str == "hp" else Color.MEDIUM_PURPLE)
	
	ball_view.hide()
	await get_tree().create_timer(0.2).timeout

func _do_hero_buff_hop(flash_color: Color) -> void:
	Audio.play_sfx("unit_buff")
	if is_instance_valid(GameManager.run_state.hero_instance):
		var uuid = GameManager.run_state.hero_instance.ball_uuid
		SignalBus.emit_signal("unit_color_flash", uuid, flash_color, 0.4)
		SignalBus.emit_signal("unit_deform", uuid, &"HOP_DEFORM")

func _clear_prize_slot(prize_index: int) -> void:
	var slot = prize_lineup.get_child(prize_index + 1)
	var label_container = slot.get_node_or_null("StatLabelContainer")
	if label_container: label_container.queue_free()
	if slot.has_method("set_content"):
		slot.set_content({}, false, false)

func _auto_apply_oldest_prize() -> void:
	if _prizes.is_empty(): return
	var p = _prizes[0]
	_prizes.remove_at(0)
	_apply_stat_to_hero(p)
	_clear_prize_slot(p.slot_index)
	for rem in _prizes: if rem.slot_index > 0: rem.slot_index -= 1
	_refresh_all_prize_slots()

func _refresh_all_prize_slots() -> void:
	for i in range(4): _clear_prize_slot(i)
	for p in _prizes: _populate_prize_slot(p.slot_index, p)

func _on_leave_pressed() -> void:
	# Disable all interactions during auto-collection
	leave_button.disabled = true
	study_button.disabled = true
	tier1_draw_button.disabled = true
	tier2_draw_button.disabled = true
	tier3_draw_button.disabled = true
	
	# Collect remaining prizes one by one
	while not _prizes.is_empty():
		var prize = _prizes[0]
		# Use the slot_index stored in the prize dictionary
		await _apply_prize(prize.slot_index)
	
	SignalBus.emit_signal("gacha_tokens_changed", 0)
	SignalBus.emit_signal("path_choice_scene_requested")
	queue_free()

func _exit_tree() -> void:
	if FlashcardManager.minigame_finished.is_connected(_on_flashcard_completed):
		FlashcardManager.minigame_finished.disconnect(_on_flashcard_completed)
	if SignalBus.flashcard_token_earned.is_connected(_on_live_token_earned):
		SignalBus.flashcard_token_earned.disconnect(_on_live_token_earned)

func _is_timekeeper_hero() -> bool:
	if not is_instance_valid(GameManager.run_state.hero_instance): return false
	return GameManager.run_state.hero_instance.get_definition().id == &"hero_timekeeper"
