# res://scripts/ui/GachaMachineBarPresenter.gd
class_name GachaMachineBarPresenter
extends RefCounted

## Manages the bottom Gacha Machine HUD bar in Main:
## - Tier badges, cost indicators, and visual machine counts
## - Knob hover animations, draw token-toss choreography, and vertical landing bounces
## - Pointer hit-testing over draw mechanics for waiting cursor state

const C = preload("res://scripts/Constants.gd")
const RejectionFeedbackScript = preload("res://scripts/vfx/RejectionFeedback.gd")

var visual_machine_counts: Dictionary[int, int] = {1: 0, 2: 0, 3: 0}
var is_drawing_token: bool = false

var _machine_costs: Dictionary[int, HBoxContainer] = {}
static var _shared_landing_tweens: Dictionary[int, Tween] = {}


func build_machine_labels(main: Control) -> void:
	for tier: int in range(1, 5):
		var machine: Control = main.get_gacha_machine(tier)
		var knob: BaseButton = main.get_knob_button(tier)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 7)
		row.position = knob.position + Vector2(-116, 5)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.custom_minimum_size.x = 110
		machine.add_child(row)
		if tier <= 3:
			var badge := PanelContainer.new()
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.custom_minimum_size = Vector2(35, 35)
			var style := StyleBoxFlat.new()
			style.bg_color = [Color(0.10, 0.44, 0.49), Color(0.53, 0.19, 0.40), Color(0.48, 0.38, 0.11)][tier - 1]
			style.set_border_width_all(2)
			style.border_color = Color(0.96, 0.91, 0.72)
			badge.add_theme_stylebox_override("panel", style)
			badge.add_child(_machine_number_label(str(tier)))
			row.add_child(badge)
		var cost := HBoxContainer.new()
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var token := TextureRect.new()
		token.mouse_filter = Control.MOUSE_FILTER_IGNORE
		token.texture = main.token_icon.texture
		token.custom_minimum_size = Vector2(33, 33)
		token.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		token.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cost.add_child(token)
		cost.add_child(_machine_number_label(str(mini(tier, 3) if tier < 4 else 1)))
		row.add_child(cost)
		_machine_costs[tier] = cost
		var count: Label = machine.get_node("CountLabel") as Label
		if tier <= 3:
			count.offset_top += 30
			count.add_theme_font_size_override("font_size", 28)
		else:
			count.text = "x0/%d" % C.BATTLE_DISCARD_CAP


func sync_visual_machine_counts_with_model(main: Control) -> void:
	var battle: BattleManager = GameManager.get_battle_manager() as BattleManager
	for tier: int in range(1, 4):
		var count: int = 0
		if battle != null:
			count = battle.get_inventory_tier_instances(tier).size()
		elif is_instance_valid(GameManager.run_state):
			count = GameManager.run_state.get_inventory_tier_instances(tier).size()
		visual_machine_counts[tier] = count

	update_machine_count_labels(main)
	update_machine_costs()
	var discard_count: int = battle.get_discard_count() if battle != null else 0
	main.gacha_machine_discard.text = "x%d/%d" % [discard_count, C.BATTLE_DISCARD_CAP]


func update_machine_count_labels(main: Control) -> void:
	main.machine_1_count_label.text = "x%d/%d" % [visual_machine_counts[1], C.RUN_INVENTORY_CAP]
	main.machine_2_count_label.text = "x%d/%d" % [visual_machine_counts[2], C.RUN_INVENTORY_CAP]
	main.machine_3_count_label.text = "x%d/%d" % [visual_machine_counts[3], C.RUN_INVENTORY_CAP]


func update_machine_costs() -> void:
	var battle: BattleManager = GameManager.get_battle_manager() as BattleManager
	for tier: int in range(1, 4):
		if _machine_costs.has(tier):
			var cost: Label = _machine_costs[tier].get_child(1) as Label
			cost.text = str(battle.get_gacha_draw_cost(tier) if battle != null and GameManager.is_in_battle else tier)
	if _machine_costs.has(4):
		_machine_costs[4].visible = battle != null and GameManager.is_in_battle and battle.can_draw_from_discard()


func on_knob_hover_enter(main: Control, button: TextureButton) -> void:
	if button.disabled:
		return
	var tween: Tween = main.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	button.pivot_offset = button.size / 2.0
	tween.tween_property(button, "scale", Vector2(1.08, 1.08), 0.15)


func on_knob_hover_exit(main: Control, button: TextureButton) -> void:
	var tween: Tween = main.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(button, "scale", Vector2.ONE, 0.1)


func is_mouse_over_draw_mechanic(main: Control) -> bool:
	var mouse_pos: Vector2 = main.get_viewport().get_mouse_position()
	var draw_controls: Array[Control] = [
		main.gacha_machine_1, main.gacha_machine_2, main.gacha_machine_3, main.gacha_machine_discard,
		main.knob_button_1, main.knob_button_2, main.knob_button_3, main.knob_button_discard
	]
	for ctrl: Control in draw_controls:
		if is_instance_valid(ctrl) and ctrl.is_visible_in_tree():
			if ctrl.get_global_rect().has_point(mouse_pos):
				return true
	return false


func request_machine_draw(main: Control, tier: int, action: GameAction) -> void:
	var battle: BattleManager = GameManager.get_battle_manager() as BattleManager
	if battle == null or battle.is_animations_playing():
		return
	if not ActionQueue.request(action) and not ActionQueue.is_busy():
		RejectionFeedbackScript.play_rejection_with_counter(main.get_gacha_machine(tier), main.get_token_feedback_control(), main.get_tree())


func play_machine_draw(main: Control, tier: int, cost: int) -> void:
	var button: BaseButton = main.get_knob_button(tier)
	var machine: Control = main.get_gacha_machine(tier)
	is_drawing_token = true
	button.release_focus()
	var knob_tween: Tween = button.create_tween()
	knob_tween.tween_property(button, "rotation_degrees", 360.0, AnimationConstants.scaled(0.4)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	knob_tween.tween_property(button, "rotation_degrees", 0.0, 0.0)
	if WindowManager.is_discard_pile_window_open():
		WindowManager.close_discard_pile_window()
	if WindowManager.is_battle_inventory_window_open() or WindowManager.is_run_inventory_window_open():
		WindowManager.close_inventory_window(true)
	if WindowManager.is_any_inspection_window_open():
		WindowManager.close_all_inspection_windows(false)
	GlobalInteractionRouter.clear_current_selection()

	var rect: Rect2 = machine.get_global_rect()
	var target: Vector2 = rect.position + rect.size * Vector2(0.75 if tier == 4 else 0.5, 0.4)
	await CurrencyAnimator.animate_token_spend(cost, target, func(_pos: Vector2) -> void: on_coin_landed_on_machine(main, machine))
	is_drawing_token = false


func on_coin_landed_on_machine(main: Control, machine: Control) -> void:
	if not is_instance_valid(machine):
		return
	Audio.play_sfx("token_land")
	play_machine_bounce(main, machine)


func animate_machine_inventory_change(main: Control, tier: int, amount: int) -> void:
	visual_machine_counts[tier] = maxi(0, visual_machine_counts[tier] + amount)
	update_machine_count_labels(main)
	var target_machine: Control = main.get_gacha_machine(tier)
	if is_instance_valid(target_machine):
		if amount > 0:
			play_machine_landing_bounce(target_machine)
		else:
			play_machine_bounce(main, target_machine)


func play_machine_landing_bounce(machine: Control) -> void:
	play_landing_bounce(machine)


static func play_landing_bounce(machine: Control) -> void:
	assert(is_instance_valid(machine), "play_landing_bounce: machine must be valid")
	machine.pivot_offset = Vector2(machine.size.x / 2.0, machine.size.y)
	var mid: int = machine.get_instance_id()
	if _shared_landing_tweens.has(mid):
		var old_tween: Tween = _shared_landing_tweens[mid]
		if is_instance_valid(old_tween):
			old_tween.kill()
		_shared_landing_tweens.erase(mid)

	var tween: Tween = machine.create_tween()
	_shared_landing_tweens[mid] = tween
	tween.tween_property(machine, "scale", Vector2(1.0, 0.94), AnimationConstants.scaled(0.05)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(machine, "scale", Vector2(1.0, 1.05), AnimationConstants.scaled(0.09)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(machine, "scale", Vector2(1.0, 0.98), AnimationConstants.scaled(0.06)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(machine, "scale", Vector2.ONE, AnimationConstants.scaled(0.05)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


static func play_machine_bounce(owner_node: Node, machine: Control) -> void:
	var machine_image: Control = machine.get_node_or_null("MachineImage") as Control
	if not is_instance_valid(machine_image):
		return
	machine.pivot_offset = Vector2(machine.size.x / 2.0, machine.size.y)
	var reaction_tween: Tween = owner_node.create_tween()
	reaction_tween.set_parallel(true)

	var b1: float = AnimationConstants.scaled(0.04)
	var b2: float = AnimationConstants.scaled(0.06)
	var b3: float = AnimationConstants.scaled(0.08)
	reaction_tween.tween_property(machine, "scale", Vector2(1.0, 0.96), b1).set_trans(Tween.TRANS_SINE)
	reaction_tween.tween_property(machine, "scale", Vector2(1.0, 1.03), b2).set_delay(b1).set_trans(Tween.TRANS_SINE)
	reaction_tween.tween_property(machine, "scale", Vector2.ONE, b3).set_delay(b1 + b2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	var flash_color := Color(1.3, 1.25, 1.1, 1.0)
	var f1: float = AnimationConstants.scaled(0.03)
	var f2: float = AnimationConstants.scaled(0.12)
	reaction_tween.tween_property(machine_image, "modulate", flash_color, f1)
	reaction_tween.tween_property(machine_image, "modulate", Color.WHITE, f2).set_delay(f1)


static func _machine_number_label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_outline_color", Color(0.09, 0.12, 0.16))
	label.add_theme_constant_override("outline_size", 4)
	return label
