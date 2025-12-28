# res://scripts/RestSite.gd
extends Control

## Rest Site with token-based stat gacha system
## Uses the existing top-area token display from Main via SignalBus.gacha_tokens_changed

const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")
const TokenSpendScene = preload("res://scenes/vfx/TokenSpendVFX.tscn")

# Machine references
@onready var hp_machine: Control = %HPMachine
@onready var pwr_machine: Control = %PWRMachine
@onready var both_machine: Control = %BothMachine

@onready var hp_draw_button: Button = hp_machine.get_node("DrawButton")
@onready var pwr_draw_button: Button = pwr_machine.get_node("DrawButton")
@onready var both_draw_button: Button = both_machine.get_node("DrawButton")

# UI references
@onready var study_button: Button = %StudyButton
@onready var leave_button: Button = %LeaveButton
@onready var prize_lineup: HBoxContainer = %PrizeLineup
@onready var hero_slot: Control = %HeroSlot
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var effects_layer: CanvasLayer = $EffectsLayer

# Token costs
const COST_HP: int = 2
const COST_PWR: int = 2
const COST_BOTH: int = 3

# State - tokens are local to this scene, reset on leave
var _tokens: int = 0
var _prizes: Array[Dictionary] = [] # [{slot_index, stat_type, hp_value, pwr_value}]
var _has_studied: bool = false # Study button only works once per rest site

enum StatType {HP, PWR, BOTH}

func _ready() -> void:
	# Connect buttons
	hp_draw_button.pressed.connect(_on_hp_draw_pressed)
	pwr_draw_button.pressed.connect(_on_pwr_draw_pressed)
	both_draw_button.pressed.connect(_on_both_draw_pressed)
	study_button.pressed.connect(_on_study_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	
	# Connect to flashcard completion
	FlashcardManager.minigame_finished.connect(_on_flashcard_completed)
	
	# Connect to live token updates during minigame
	SignalBus.flashcard_token_earned.connect(_on_live_token_earned)
	
	# Connect locale changes
	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()
	
	# Initialize token display in top area via existing signal
	_update_token_display()
	_update_button_states()
	_populate_hero_slot()
	_setup_prize_slot_clicks()

func _update_localized_text() -> void:
	title_label.text = tr("ui.rest_site")
	study_button.text = tr("ui.study")
	leave_button.text = tr("ui.leave")
	# Button text stays as "X Tokens" (set in scene)

func _populate_hero_slot() -> void:
	"""Display the hero in the first slot"""
	if not is_instance_valid(GameManager.run_state) or not is_instance_valid(GameManager.run_state.hero_instance):
		return
	
	var hero = GameManager.run_state.hero_instance
	var visual_data = VisualDataAdapter.create_visual_data(hero)
	
	if hero_slot.has_method("set_content"):
		hero_slot.set_content(visual_data, true, false, false)

func _setup_prize_slot_clicks() -> void:
	"""Setup click handlers for prize slots"""
	var slots = prize_lineup.get_children()
	for i in range(1, slots.size()): # Skip hero slot (index 0)
		var slot = slots[i]
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_prize_slot_gui_input.bind(i - 1))

# --- Token System (uses existing top-area display) ---

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
	_update_button_states()

func _on_flashcard_completed(_results: Dictionary) -> void:
	"""Called when flashcard minigame ends"""
	# NOTE: Tokens are already awarded live via _on_live_token_earned
	# Window closing is handled by FlashcardManager
	# Nothing to do here - tokens were added as they landed
	pass

func _award_tokens(count: int) -> void:
	"""Add tokens and update top-area display"""
	_tokens += count
	_update_token_display()
	_update_button_states()

func _update_token_display() -> void:
	"""Update the top-area token counter via the existing signal"""
	SignalBus.emit_signal("gacha_tokens_changed", _tokens)

func _update_button_states() -> void:
	"""Enable/disable draw buttons based on token count"""
	hp_draw_button.disabled = _tokens < COST_HP
	pwr_draw_button.disabled = _tokens < COST_PWR
	both_draw_button.disabled = _tokens < COST_BOTH

# --- Draw Logic ---

func _on_hp_draw_pressed() -> void:
	_try_draw_stat(StatType.HP, COST_HP, hp_machine)

func _on_pwr_draw_pressed() -> void:
	_try_draw_stat(StatType.PWR, COST_PWR, pwr_machine)

func _on_both_draw_pressed() -> void:
	_try_draw_stat(StatType.BOTH, COST_BOTH, both_machine)

func _try_draw_stat(stat_type: StatType, cost: int, machine: Control) -> void:
	"""Attempt to draw a stat prize from a machine"""
	if _tokens < cost:
		return
	
	# Disable button during animation
	var button = machine.get_node("DrawButton")
	button.disabled = true
	
	# Get token group position from Main for animation
	var main_node = GameManager._active_main_node
	var token_group = main_node.get_node_or_null("%TokenGroup") if is_instance_valid(main_node) else null
	
	# Animate token spend from top-area to machine
	await _animate_token_spend(machine, cost, token_group)
	
	# Deduct tokens and update display
	_tokens -= cost
	_update_token_display()
	_update_button_states()
	
	# Roll stat values
	var hp_value = 0
	var pwr_value = 0
	
	if stat_type == StatType.HP:
		hp_value = _roll_stat_value()
	elif stat_type == StatType.PWR:
		pwr_value = _roll_stat_value()
	else: # BOTH
		hp_value = _roll_stat_value()
		pwr_value = _roll_stat_value()
	
	# Find next available prize slot
	var slot_index = _find_next_prize_slot()
	
	# If all slots full, auto-apply oldest prize first
	if slot_index == -1:
		_auto_apply_oldest_prize()
		slot_index = 0
	
	# Create prize data - now supports BOTH with separate hp/pwr values
	var prize_data = {
		"slot_index": slot_index,
		"stat_type": stat_type, # Keep original type
		"hp_value": hp_value,
		"pwr_value": pwr_value
	}
	
	# Animate draw and add prize
	await _animate_prize_draw(machine, slot_index, prize_data)
	
	# Store prize
	_prizes.append(prize_data)
	
	# Populate the prize slot
	_populate_prize_slot(slot_index, prize_data)
	
	# Re-enable button based on token count
	button.disabled = _tokens < cost

func _roll_stat_value() -> int:
	"""Roll a random stat value from 1-5 (never 0)"""
	return (randi() % 5) + 1

func _find_next_prize_slot() -> int:
	"""Find the next empty prize slot (0-3), or -1 if all full"""
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
	"""Animate tokens flying from top-area token display to machine"""
	var start_pos: Vector2
	
	if is_instance_valid(token_group):
		var token_rect = token_group.get_global_rect()
		start_pos = Vector2(
			token_rect.position.x + token_rect.size.x / 2,
			token_rect.position.y + token_rect.size.y / 2
		)
	else:
		# Fallback to top-center of screen
		start_pos = Vector2(get_viewport_rect().size.x / 2, 60)
	
	var machine_rect = target_machine.get_global_rect()
	var target_pos = Vector2(
		machine_rect.position.x + machine_rect.size.x / 2,
		machine_rect.position.y + machine_rect.size.y * 0.4
	)
	
	var stagger_delay = 0.12
	
	for i in range(cost):
		var token_vfx = TokenSpendScene.instantiate()
		effects_layer.add_child(token_vfx)
		
		token_vfx.coin_landed.connect(_on_coin_landed.bind(target_machine))
		
		var offset = Vector2(randf_range(-15, 15), randf_range(-8, 8))
		token_vfx.play(start_pos + offset, target_pos, i * stagger_delay)
	
	var total_wait = (cost - 1) * stagger_delay + 0.55
	await get_tree().create_timer(total_wait).timeout

func _on_coin_landed(_target_pos: Vector2, machine: Control) -> void:
	"""Machine bounce reaction when coin lands"""
	if not is_instance_valid(machine):
		return
	
	var machine_image = machine.get_node_or_null("MachineImage")
	if not is_instance_valid(machine_image):
		return
	
	machine.pivot_offset = Vector2(machine.size.x / 2, machine.size.y)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(machine, "scale", Vector2(1.03, 0.97), 0.04).set_trans(Tween.TRANS_SINE)
	tween.tween_property(machine, "scale", Vector2(0.98, 1.02), 0.06).set_delay(0.04).set_trans(Tween.TRANS_SINE)
	tween.tween_property(machine, "scale", Vector2(1.0, 1.0), 0.08).set_delay(0.10).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	var original_modulate = machine_image.modulate
	var flash_color = Color(original_modulate.r * 1.3, original_modulate.g * 1.25, original_modulate.b * 1.1, 1.0)
	tween.tween_property(machine_image, "modulate", flash_color, 0.03)
	tween.tween_property(machine_image, "modulate", original_modulate, 0.12).set_delay(0.03)

func _animate_prize_draw(machine: Control, slot_index: int, prize_data: Dictionary) -> void:
	"""Animate gachaball from machine to prize slot with Bezier arc"""
	var knob = machine.get_node("DrawButton")
	var start_pos = knob.get_global_rect().get_center()
	
	var target_slot = prize_lineup.get_child(slot_index + 1) # +1 to skip hero slot
	var end_pos = target_slot.get_global_rect().get_center()
	
	var anim_ball = GachaBallViewScene.instantiate()
	effects_layer.add_child(anim_ball)
	
	anim_ball.force_inventory_mode = true
	anim_ball.custom_minimum_size = Vector2(128, 128)
	anim_ball.size = Vector2(128, 128)
	
	var visual_data = _create_prize_visual_data(prize_data)
	anim_ball.populate(null, visual_data)
	
	anim_ball.pivot_offset = anim_ball.size / 2.0
	
	var control_point = Vector2(
		(start_pos.x + end_pos.x) / 2.0,
		min(start_pos.y, end_pos.y) - 200
	)
	var duration = 0.45
	var initial_scale = 0.3
	
	anim_ball.scale = Vector2(initial_scale, initial_scale)
	anim_ball.global_position = start_pos - (anim_ball.pivot_offset * initial_scale)
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	
	tween.tween_method(func(t: float):
		var eased_t = pow(t, 0.55)
		var scale_eased = 1.0 - pow(1.0 - t, 2)
		var current_scale = lerp(initial_scale, 1.0, scale_eased)
		anim_ball.scale = Vector2(current_scale, current_scale)
		
		var inv_t = 1.0 - eased_t
		var pos = (inv_t * inv_t * start_pos) + \
				  (2.0 * inv_t * eased_t * control_point) + \
				  (eased_t * eased_t * end_pos)
		
		anim_ball.global_position = pos - (anim_ball.pivot_offset * current_scale)
	, 0.0, 1.0, duration)
	
	tween.tween_callback(func():
		anim_ball.queue_free()
	)
	
	await tween.finished

func _create_prize_visual_data(prize_data: Dictionary) -> Dictionary:
	"""Create synthetic visual data for a stat prize ball"""
	var hp_value: int = prize_data.hp_value
	var pwr_value: int = prize_data.pwr_value
	
	var icon_texture = preload("res://assets/ui/textures/gachaball.png")
	
	return {
		"uuid": "prize_%d" % prize_data.slot_index,
		"icon": icon_texture,
		"hp": hp_value,
		"pwr": pwr_value,
		"display_name_key": "ui.stat_prize",
		"tier": 0,
		"category": &"ITEM"
	}

func _populate_prize_slot(slot_index: int, prize_data: Dictionary) -> void:
	"""Populate a prize slot with visual representation"""
	var slot = prize_lineup.get_child(slot_index + 1)
	
	var visual_data = _create_prize_visual_data(prize_data)
	
	if slot.has_method("set_content"):
		slot.set_content(visual_data, true, false, false)
	
	_add_stat_label_to_slot(slot, prize_data)

func _add_stat_label_to_slot(slot: Control, prize_data: Dictionary) -> void:
	"""Add labels showing stat values in a vertical stack"""
	# Remove existing label container
	var existing_container = slot.get_node_or_null("StatLabelContainer")
	if existing_container:
		existing_container.queue_free()
	
	var hp_value: int = prize_data.hp_value
	var pwr_value: int = prize_data.pwr_value
	var _has_both = hp_value > 0 and pwr_value > 0
	
	# Create a VBoxContainer to automatically stack labels vertically
	var container = VBoxContainer.new()
	container.name = "StatLabelContainer"
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	# Fill the slot
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.offset_left = 0
	container.offset_right = 0
	container.offset_top = 0
	container.offset_bottom = 0
	# CRITICAL: Let mouse clicks pass through to the slot
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(container)
	
	# Spacer for vertical centering
	var top_spacer = Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(top_spacer)
	
	if hp_value > 0:
		var hp_label = Label.new()
		hp_label.name = "StatPrizeLabel"
		hp_label.text = "%d" % hp_value
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_label.add_theme_font_size_override("font_size", 36)
		hp_label.add_theme_color_override("font_color", Color.RED)
		hp_label.add_theme_color_override("font_outline_color", Color.WHITE)
		hp_label.add_theme_constant_override("outline_size", 6)
		hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(hp_label)
	
	if pwr_value > 0:
		var pwr_label = Label.new()
		pwr_label.name = "StatPrizeLabel2" if hp_value > 0 else "StatPrizeLabel"
		pwr_label.text = "%d" % pwr_value
		pwr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pwr_label.add_theme_font_size_override("font_size", 36)
		pwr_label.add_theme_color_override("font_color", Color.BLACK)
		pwr_label.add_theme_color_override("font_outline_color", Color.WHITE)
		pwr_label.add_theme_constant_override("outline_size", 6)
		pwr_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(pwr_label)
	
	# Bottom spacer for vertical centering
	var bottom_spacer = Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bottom_spacer)

# --- Prize Application ---

func _on_prize_slot_gui_input(event: InputEvent, prize_index: int) -> void:
	"""Handle clicks on prize slots"""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		_apply_prize(prize_index)

func _apply_prize(prize_index: int) -> void:
	"""Apply a prize to the hero"""
	var prize_to_apply: Dictionary = {}
	var prize_array_index: int = -1
	
	for i in range(_prizes.size()):
		if _prizes[i].slot_index == prize_index:
			prize_to_apply = _prizes[i]
			prize_array_index = i
			break
	
	if prize_to_apply.is_empty():
		return
	
	# CRITICAL: Remove from array BEFORE animation to prevent race condition
	# If user clicks multiple prizes during await, the array would change
	if prize_array_index >= 0 and prize_array_index < _prizes.size():
		_prizes.remove_at(prize_array_index)
	
	await _animate_buff_application(prize_index, prize_to_apply)
	
	_apply_stat_to_hero(prize_to_apply)
	
	_clear_prize_slot(prize_index)
	
	_populate_hero_slot()

func _auto_apply_oldest_prize() -> void:
	"""Auto-apply the oldest prize (slot 0) when drawing with full slots"""
	if _prizes.is_empty():
		return
	
	for i in range(_prizes.size()):
		if _prizes[i].slot_index == 0:
			var prize = _prizes[i]
			_apply_stat_to_hero(prize)
			_prizes.remove_at(i)
			_clear_prize_slot(0)
			_populate_hero_slot()
			
			for remaining in _prizes:
				if remaining.slot_index > 0:
					remaining.slot_index -= 1
			_refresh_all_prize_slots()
			return

func _apply_stat_to_hero(prize_data: Dictionary) -> void:
	"""Apply stat change to hero using RunState API"""
	if not is_instance_valid(GameManager.run_state) or not is_instance_valid(GameManager.run_state.hero_instance):
		return
	
	var hero_uuid = GameManager.run_state.hero_instance.ball_uuid
	var hp_value: int = prize_data.hp_value
	var pwr_value: int = prize_data.pwr_value
	
	# Apply both stats at once (works for single or combined)
	GameManager.run_state.modify_unit_base_stats(hero_uuid, hp_value, pwr_value)

func _animate_buff_application(prize_index: int, prize_data: Dictionary) -> void:
	"""Animate prize ball: hop + flash + pop into projectile"""
	var prize_slot = prize_lineup.get_child(prize_index + 1)
	var hero_slot_view = hero_slot
	
	# Find the GachaBallView inside the slot
	var ball_view: GachaBallView = null
	for child in prize_slot.get_children():
		if child is GachaBallView:
			ball_view = child
			break
	
	if not is_instance_valid(ball_view):
		# No ball view found, skip animation
		return
	
	# Get positions for projectile
	var start_pos = ball_view.get_global_rect().get_center()
	var end_pos = hero_slot_view.get_global_rect().get_center()
	
	# Set pivot on the ball view for scaling animations
	ball_view.pivot_offset = ball_view.size / 2.0
	
	# Phase 1: Hop up with squish - animate the ball itself
	var hop_tween = create_tween()
	hop_tween.set_parallel(true)
	hop_tween.tween_property(ball_view, "scale", Vector2(0.85, 1.25), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop_tween.tween_property(ball_view, "position:y", ball_view.position.y - 25, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await hop_tween.finished
	
	# Phase 2: Flash bright white
	ball_view.modulate = Color(2.5, 2.5, 2.5, 1.0) # Bright flash
	await get_tree().create_timer(0.04).timeout
	ball_view.modulate = Color(4.0, 4.0, 4.0, 1.0) # Even brighter
	await get_tree().create_timer(0.03).timeout
	
	# Phase 3: Pop! - rapid scale up then vanish
	var pop_tween = create_tween()
	pop_tween.set_parallel(true)
	pop_tween.tween_property(ball_view, "scale", Vector2(1.4, 1.4), 0.05).set_trans(Tween.TRANS_QUAD)
	pop_tween.tween_property(ball_view, "modulate:a", 0.0, 0.05).set_trans(Tween.TRANS_QUAD)
	
	# CRITICAL: Hide ball NOW
	ball_view.hide()
	
	# Get label container for hiding
	var label_container = prize_slot.get_node_or_null("StatLabelContainer")
	
	# Launch projectile(s) as ball pops - SEQUENTIALLY so they don't block each other
	var hp_value: int = prize_data.hp_value
	var pwr_value: int = prize_data.pwr_value
	var has_both = hp_value > 0 and pwr_value > 0
	
	# For single stat: hide container immediately (label becomes projectile)
	# For dual stat: hide each label as its projectile launches
	if not has_both and label_container:
		label_container.hide()
	
	# Launch HP projectile first
	if hp_value > 0:
		# For dual stat, hide HP label as it launches
		if has_both and label_container:
			var hp_label = label_container.get_node_or_null("StatPrizeLabel")
			if hp_label:
				hp_label.hide()
		var hp_proj = VFXFactory.spawn_projectile_on_layer(hp_value, "hp", start_pos, end_pos, false)
		if hp_proj:
			hp_proj.launch()
			await hp_proj.impact
			# Hop after HP projectile lands
			_do_hero_buff_hop(AnimationConstants.COLOR_HEAL_BUFF)
	
	# Launch PWR projectile AFTER HP is done
	if pwr_value > 0:
		# For dual stat, hide PWR label as it launches
		if has_both and label_container:
			var pwr_label = label_container.get_node_or_null("StatPrizeLabel2")
			if pwr_label:
				pwr_label.hide()
		var pwr_proj = VFXFactory.spawn_projectile_on_layer(pwr_value, "pwr", start_pos, end_pos, false)
		if pwr_proj:
			pwr_proj.launch()
			await pwr_proj.impact
			# Hop after PWR projectile lands
			_do_hero_buff_hop(Color(0.8, 0.4, 1.0))
	
	# If no projectiles, wait for pop animation
	if hp_value == 0 and pwr_value == 0:
		await pop_tween.finished
	
	# Wait for hero animation to complete
	await get_tree().create_timer(0.3).timeout

func _do_hero_buff_hop(flash_color: Color) -> void:
	"""Apply hop animation to hero when buff projectile lands"""
	if is_instance_valid(GameManager.run_state) and is_instance_valid(GameManager.run_state.hero_instance):
		var hero_uuid = GameManager.run_state.hero_instance.ball_uuid
		SignalBus.emit_signal("unit_color_flash", hero_uuid, flash_color, AnimationConstants.FLASH_FADE_DURATION)
		SignalBus.emit_signal("unit_deform", hero_uuid, &"HOP_DEFORM")
		SignalBus.emit_signal("unit_move", hero_uuid, &"HOP", Vector2.ZERO)

func _clear_prize_slot(prize_index: int) -> void:
	"""Clear a prize slot's visual content"""
	var slot = prize_lineup.get_child(prize_index + 1)
	
	var label_container = slot.get_node_or_null("StatLabelContainer")
	if label_container:
		label_container.queue_free()
	
	if slot.has_method("set_content"):
		slot.set_content({}, false, false, false)

func _refresh_all_prize_slots() -> void:
	"""Refresh all prize slot visuals after reordering"""
	for i in range(4):
		_clear_prize_slot(i)
	
	for prize in _prizes:
		_populate_prize_slot(prize.slot_index, prize)

# --- Navigation ---

func _on_leave_pressed() -> void:
	"""Leave rest site and return to path selection"""
	# Reset token display to 0 when leaving
	SignalBus.emit_signal("gacha_tokens_changed", 0)
	SignalBus.emit_signal("path_choice_scene_requested")
	queue_free()

func _exit_tree() -> void:
	if FlashcardManager.minigame_finished.is_connected(_on_flashcard_completed):
		FlashcardManager.minigame_finished.disconnect(_on_flashcard_completed)
	if SignalBus.flashcard_token_earned.is_connected(_on_live_token_earned):
		SignalBus.flashcard_token_earned.disconnect(_on_live_token_earned)
