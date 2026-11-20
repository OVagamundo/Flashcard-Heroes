# res://scripts/ui/HudTopBarPresenter.gd
class_name HudTopBarPresenter
extends RefCounted

## Manages the persistent Main top HUD bar presentation:
## - Visual gold, token, and bonus-timer counters + animation locks + pop tweens
## - Combat speed / pause buttons (hover animations & active styles)
## - Day label and BattleTokenTray delegation

var visual_gold: int = 0
var visual_tokens: int = 0
var visual_bonus_timer: float = 0.0
var gold_animations_in_flight: int = 0
var token_animations_in_flight: int = 0
var bonus_timer_animations_in_flight: int = 0

var _battle_token_tray: Control = null
var _pop_tweens: Dictionary[int, Tween] = {}


func setup_speed_button_hover(main: Control, btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	btn.mouse_entered.connect(func() -> void:
		var tween: Tween = main.create_tween()
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		btn.pivot_offset = btn.size / 2.0
		tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.1)
	)
	btn.mouse_exited.connect(func() -> void:
		var tween: Tween = main.create_tween()
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(btn, "scale", Vector2.ONE, 0.1)
	)


func update_speed_button_styles(main: Control, active_speed: float) -> void:
	var buttons: Array[Dictionary] = [
		{"btn": main.speed_1x_btn, "speed": 1.0},
		{"btn": main.speed_2x_btn, "speed": 2.0},
		{"btn": main.speed_4x_btn, "speed": 4.0},
		{"btn": main.pause_btn, "speed": -1.0}
	]
	var in_battle: bool = GameManager.is_in_battle
	for entry: Dictionary in buttons:
		var btn: Button = entry["btn"] as Button
		if not is_instance_valid(btn):
			continue
		var target_speed: float = float(entry["speed"])
		var is_active: bool = is_equal_approx(target_speed, active_speed)
		if is_active and in_battle:
			btn.self_modulate = Color(0.35, 0.75, 1.0)
		elif target_speed == -1.0 and not in_battle:
			btn.self_modulate = Color(0.9, 0.9, 0.95)
		else:
			btn.self_modulate = Color(0.68, 0.7, 0.76)


func on_speed_button_pressed(speed: float) -> void:
	if WindowManager.is_options_window_open():
		WindowManager.close_options_window()
	ActionQueue.request(SetCombatSpeedAction.new(speed))


func set_visual_gold(main: Control, new_amount: int, animate_pop: bool = true) -> void:
	var old_amount: int = visual_gold
	visual_gold = new_amount
	if is_instance_valid(main.gold_label):
		main.gold_label.text = "%d" % visual_gold
		if old_amount != visual_gold and animate_pop:
			_animate_counter_pop(main, main.gold_label, main.gold_label.get_parent() as Control, Color(1.0, 0.85, 0.3, 1.0))


func modify_visual_gold(main: Control, delta: int, animate_pop: bool = true) -> void:
	set_visual_gold(main, maxi(0, visual_gold + delta), animate_pop)


func set_visual_tokens(main: Control, new_amount: int, animate_pop: bool = true) -> void:
	var old_amount: int = visual_tokens
	visual_tokens = new_amount
	if _battle_token_tray != null:
		_battle_token_tray.set_balance(new_amount)
	if is_instance_valid(main.tokens_label):
		main.tokens_label.text = "%d" % visual_tokens
		if old_amount != visual_tokens and animate_pop:
			var original_color: Color = main.tokens_label.get_theme_color("font_color") if main.tokens_label.has_theme_color_override("font_color") else Color.WHITE
			main.tokens_label.add_theme_color_override("font_color", original_color)
			_animate_counter_pop(main, main.tokens_label, main.tokens_label.get_parent() as Control, Color(1.0, 0.9, 0.2, 1.0))


func modify_visual_tokens(main: Control, delta: int, animate_pop: bool = true) -> void:
	set_visual_tokens(main, maxi(0, visual_tokens + delta), animate_pop)


func begin_gold_animation() -> void:
	gold_animations_in_flight += 1


func end_gold_animation() -> void:
	gold_animations_in_flight = maxi(0, gold_animations_in_flight - 1)
	if gold_animations_in_flight == 0 and is_instance_valid(GameManager.run_state):
		assert(visual_gold == GameManager.run_state.gold, "HUD visual gold (%d) desynced from authoritative gold (%d)!" % [visual_gold, GameManager.run_state.gold])


func begin_token_animation() -> void:
	token_animations_in_flight += 1


func end_token_animation() -> void:
	token_animations_in_flight = maxi(0, token_animations_in_flight - 1)
	if token_animations_in_flight == 0 and is_instance_valid(GameManager.run_state):
		var auth_tokens: int = GameManager.run_state.get_room_tokens()
		assert(visual_tokens == auth_tokens, "HUD visual tokens (%d) desynced from authoritative tokens (%d)!" % [visual_tokens, auth_tokens])


func set_visual_bonus_timer(main: Control, new_amount: float, animate_pop: bool = true) -> void:
	var old_amount: float = visual_bonus_timer
	visual_bonus_timer = new_amount
	_ensure_bonus_timer_nodes(main)
	if is_instance_valid(main.bonus_timer_group):
		main.bonus_timer_group.visible = (visual_bonus_timer > 0.0)
		main.bonus_timer_group.modulate.a = 1.0
	if is_instance_valid(main.bonus_timer_label):
		main.bonus_timer_label.text = _format_bonus_timer(visual_bonus_timer)
		if not is_equal_approx(old_amount, visual_bonus_timer) and animate_pop:
			_animate_counter_pop(main, main.bonus_timer_label, main.bonus_timer_group, Color(1.0, 0.9, 0.3, 1.0))


func modify_visual_bonus_timer(main: Control, delta: float, animate_pop: bool = true) -> void:
	set_visual_bonus_timer(main, maxf(0.0, visual_bonus_timer + delta), animate_pop)


func begin_bonus_timer_animation(main: Control) -> void:
	bonus_timer_animations_in_flight += 1
	_ensure_bonus_timer_nodes(main)
	if is_instance_valid(main.bonus_timer_group) and not main.bonus_timer_group.visible:
		main.bonus_timer_group.visible = true
		main.bonus_timer_group.modulate.a = 0.0


func end_bonus_timer_animation(main: Control) -> void:
	bonus_timer_animations_in_flight = maxi(0, bonus_timer_animations_in_flight - 1)
	if bonus_timer_animations_in_flight == 0:
		update_bonus_timer_display(main)


func update_bonus_timer_display(main: Control, override_bonus: float = -1.0) -> void:
	_ensure_bonus_timer_nodes(main)
	var bonus_time: float = 0.0
	if GameManager.is_in_battle:
		if override_bonus >= 0.0:
			bonus_time = override_bonus
		else:
			var bm: Node = GameManager.get_battle_manager()
			if is_instance_valid(bm):
				bonus_time = bm.get_total_next_minigame_bonus_time()

	visual_bonus_timer = bonus_time
	if is_instance_valid(main.bonus_timer_group):
		main.bonus_timer_group.visible = (bonus_time > 0.0)
		main.bonus_timer_group.modulate.a = 1.0
	if is_instance_valid(main.bonus_timer_label):
		main.bonus_timer_label.text = _format_bonus_timer(bonus_time)


func update_day_label(main: Control, day: int) -> void:
	if is_instance_valid(main.days_label):
		main.days_label.text = TranslationServer.translate("ui.day") % day


func set_battle_token_tray(main: Control, tray: Control) -> void:
	_battle_token_tray = tray
	main.tokens_label.visible = tray == null
	main.token_icon.visible = tray == null
	if tray != null:
		tray.set_balance(visual_tokens)


func clear_battle_token_tray(main: Control, tray: Control) -> void:
	if _battle_token_tray == tray:
		_battle_token_tray = null
		if not main.is_queued_for_deletion():
			set_battle_token_tray(main, null)


func get_token_feedback_control(main: Control) -> Control:
	return _battle_token_tray.get_count_feedback_control() if _battle_token_tray != null else main.get_node("%TokenGroup") as Control


func get_token_animation_origin(main: Control) -> Vector2:
	return _battle_token_tray.get_currency_origin() if _battle_token_tray != null else main.token_icon.get_global_rect().get_center()


func _animate_counter_pop(main: Control, label: Label, scale_group: Control, flash_color: Color) -> void:
	if not is_instance_valid(label) or not is_instance_valid(scale_group):
		return
	var lid: int = label.get_instance_id()
	if _pop_tweens.has(lid):
		var existing: Tween = _pop_tweens[lid]
		if is_instance_valid(existing):
			existing.kill()
		_pop_tweens.erase(lid)

	scale_group.pivot_offset = scale_group.size / 2.0
	var pop_tween: Tween = main.create_tween()
	_pop_tweens[lid] = pop_tween
	pop_tween.set_parallel(true)
	pop_tween.tween_property(scale_group, "scale", Vector2(1.4, 1.4), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(scale_group, "scale", Vector2.ONE, 0.15).set_delay(0.1).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(label, "modulate", flash_color, 0.05)
	pop_tween.tween_property(label, "modulate", Color.WHITE, 0.2).set_delay(0.05)


static func _ensure_bonus_timer_nodes(main: Control) -> void:
	if not is_instance_valid(main.bonus_timer_group):
		main.bonus_timer_group = main.get_node_or_null("%BonusTimerGroup")
	if not is_instance_valid(main.bonus_timer_label):
		main.bonus_timer_label = main.get_node_or_null("%BonusTimerLabel")


static func _format_bonus_timer(seconds: float) -> String:
	if is_equal_approx(seconds, roundf(seconds)):
		return "+%ds" % int(roundf(seconds))
	return "+%.1fs" % seconds
