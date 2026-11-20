# res://scripts/RestSite.gd
class_name ResourceSite
extends EncounterBase

## Rest Site with token-based stat gacha system.
## Supports HP, PWR, and GOLD variations.

enum SiteType { HP, PWR, GOLD }

const COST_TIER1: int = 1
const COST_TIER2: int = 2
const COST_TIER3: int = 3

@export var site_type: SiteType = SiteType.HP:
	set(val):
		site_type = val
		if is_node_ready():
			_update_localized_text()
			_setup_machine_visuals()
			_update_background_visuals()

@onready var tier1_machine: Control = %Tier1Machine
@onready var tier2_machine: Control = %Tier2Machine
@onready var tier3_machine: Control = %Tier3Machine
@onready var tier1_draw_button: Button = %Tier1Machine.get_node("DrawButton") as Button
@onready var tier2_draw_button: Button = %Tier2Machine.get_node("DrawButton") as Button
@onready var tier3_draw_button: Button = %Tier3Machine.get_node("DrawButton") as Button

@onready var background: TextureRect = $Background
@onready var study_button: Button = %StudyButton
@onready var leave_button: Button = %LeaveButton
@onready var prize_lineup: HBoxContainer = %PrizeLineup
@onready var hero_slot: SlotView = %HeroSlot
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var effects_layer: CanvasLayer = $EffectsLayer

var _tokens: int:
	get:
		if is_instance_valid(GameManager.run_state):
			return GameManager.run_state.get_room_tokens()
		return 0
	set(val):
		if is_instance_valid(GameManager.run_state):
			GameManager.run_state.current_room_tokens = val

var _prizes: Array[Dictionary] = []
var _has_studied: bool = false
var _action_in_progress: bool = false


func _ready() -> void:
	Audio.play_music(SoundRegistry.BGM_REST)

	tier1_draw_button.pressed.connect(func() -> void: ActionQueue.request(DrawRestSiteAction.new(1)))
	tier2_draw_button.pressed.connect(func() -> void: ActionQueue.request(DrawRestSiteAction.new(2)))
	tier3_draw_button.pressed.connect(func() -> void: ActionQueue.request(DrawRestSiteAction.new(3)))
	study_button.pressed.connect(_on_study_pressed)
	leave_button.pressed.connect(_on_leave_pressed)

	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()
	_update_token_display()
	_populate_hero_slot()
	_setup_prize_slot_clicks()
	_update_background_visuals()


func setup_site() -> void:
	_update_localized_text()
	_setup_machine_visuals()
	_update_background_visuals()


func _update_background_visuals() -> void:
	var bg_texture: Texture2D = null
	match site_type:
		SiteType.PWR:
			bg_texture = preload("res://assets/PixelArt/ui/BGs/training.png")
		SiteType.GOLD:
			bg_texture = preload("res://assets/PixelArt/ui/BGs/gambling.png")
		SiteType.HP, _:
			bg_texture = preload("res://assets/PixelArt/ui/BGs/rest.png")

	var bg_node: TextureRect = background if is_instance_valid(background) else get_node_or_null("Background") as TextureRect
	if is_instance_valid(bg_node):
		bg_node.texture = bg_texture

	var main_node: Node = GameManager._active_main_node
	if is_instance_valid(main_node):
		main_node.sync_scene_background(self)


func _update_localized_text() -> void:
	var cost: int = GameManager.run_state.get_tokens_cost if is_instance_valid(GameManager.run_state) else 5
	match site_type:
		SiteType.HP:
			title_label.text = tr("ui.rest_site")
			description_label.text = tr("ui.rest_site_desc")
		SiteType.PWR:
			title_label.text = tr("ui.training_grounds")
			description_label.text = tr("ui.training_grounds_desc")
		SiteType.GOLD:
			title_label.text = tr("ui.gambling_den")
			description_label.text = tr("ui.gambling_den_desc")

	study_button.text = tr("ui.rest_study") % cost
	leave_button.text = tr("ui.leave")


func _setup_machine_visuals() -> void:
	var machines: Array[Control] = [tier1_machine, tier2_machine, tier3_machine]
	var costs: Array[int] = [COST_TIER1, COST_TIER2, COST_TIER3]

	var stat_label_text: String = ""
	var stat_color: Color = Color.WHITE
	match site_type:
		SiteType.HP:
			stat_label_text = tr("ui.hp")
			stat_color = Color.RED
		SiteType.PWR:
			stat_label_text = tr("ui.pwr")
			stat_color = Color.MEDIUM_PURPLE
		SiteType.GOLD:
			stat_label_text = "GOLD"
			stat_color = Color.GOLD

	for i: int in range(machines.size()):
		var machine: Control = machines[i]
		var label: Label = machine.get_node_or_null("StatLabel") as Label
		var button: Button = machine.get_node_or_null("DrawButton") as Button
		if is_instance_valid(label):
			label.text = stat_label_text
			label.add_theme_color_override("font_color", stat_color)
		if is_instance_valid(button):
			button.text = "%d Tokens" % costs[i]


func _populate_hero_slot() -> void:
	if not is_instance_valid(GameManager.run_state) or not is_instance_valid(GameManager.run_state.hero_instance):
		return
	var visual_data: Dictionary = VisualDataAdapter.create_visual_data(GameManager.run_state.hero_instance)
	hero_slot.set_content(visual_data, true, false)
	await get_tree().process_frame
	_animate_hero_entry()


func _animate_hero_entry() -> void:
	var ball_view: GachaBallView = _resolve_ball_view(hero_slot)
	if is_instance_valid(ball_view) and is_instance_valid(ball_view.icon_rect):
		ball_view.icon_rect.scale = Vector2.ZERO
		ball_view.icon_rect.pivot_offset = ball_view.icon_rect.size / 2.0
		var wait_tween: Tween = ball_view.create_tween()
		wait_tween.tween_interval(0.05)
		wait_tween.tween_callback(func() -> void:
			if is_instance_valid(ball_view) and is_instance_valid(ball_view.icon_rect):
				ball_view.icon_rect.scale = Vector2.ONE
				ball_view.play_landing_bounce()
		)


func _setup_prize_slot_clicks() -> void:
	var slots: Array[Node] = prize_lineup.get_children()
	for i: int in range(1, slots.size()): # Skip hero slot (index 0)
		var slot: Control = slots[i] as Control
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_prize_slot_gui_input.bind(i - 1))


# --- Token & Draw System ---

func _on_study_pressed() -> void:
	if _has_studied or _action_in_progress:
		return
	ActionQueue.request(StudyRestSiteAction.new())


func _execute_study() -> void:
	_has_studied = true
	study_button.disabled = true


func _update_token_display() -> void:
	SignalBus.gacha_tokens_changed.emit(_tokens)


func play_transaction_log(event_log: Dictionary) -> void:
	if not event_log.get("success", false):
		_finish_active_action()
		return
	var tier: int = int(event_log.get("tier", 1))
	var prize_data: Dictionary = event_log.get("prize_data", {})
	execute_draw_tier_visuals(tier, prize_data)


func execute_draw_tier_visuals(tier: int, pre_rolled_prize: Dictionary = {}) -> void:
	var cost: int = COST_TIER1 if tier == 1 else (COST_TIER2 if tier == 2 else COST_TIER3)
	var machine: Control = tier1_machine if tier == 1 else (tier2_machine if tier == 2 else tier3_machine)
	await _try_draw_tier(tier, cost, machine, pre_rolled_prize)


func _try_draw_tier(tier: int, cost: int, machine: Control, pre_rolled_prize: Dictionary = {}) -> void:
	var main_node: Node = GameManager._active_main_node
	var token_group: Control = main_node.get_node_or_null("%TokenGroup") as Control if is_instance_valid(main_node) else null

	if pre_rolled_prize.is_empty() and _tokens < cost:
		RejectionFeedbackScript.play_rejection_with_counter(machine, token_group, get_tree())
		_finish_active_action()
		return

	var button: Button = machine.get_node_or_null("DrawButton") as Button
	if is_instance_valid(button):
		button.disabled = true

	await _animate_machine_token_spend(machine, cost)

	var prize_data: Dictionary = pre_rolled_prize
	if prize_data.is_empty():
		GameManager.current_rest_site_type = int(site_type)
		prize_data = GameManager.roll_rest_site_prize(tier)
	_update_token_display()

	if prize_data.is_empty():
		if is_instance_valid(button):
			button.disabled = _tokens < cost
		_finish_active_action()
		return

	var slot_index: int = prize_data["slot_index"]
	_prizes = GameManager._temporary_rest_site_prizes.duplicate(true)
	_refresh_all_prize_slots()

	await _animate_prize_draw(machine, slot_index, prize_data)
	_populate_prize_slot(slot_index, prize_data)

	if is_instance_valid(button):
		button.disabled = _tokens < cost
	_finish_active_action()


# --- Animations & Prize Slots ---

func _animate_prize_draw(machine: Control, slot_index: int, prize_data: Dictionary) -> void:
	var draw_btn: Control = machine.get_node_or_null("DrawButton") as Control
	var start_pos: Vector2 = draw_btn.get_global_rect().get_center() if is_instance_valid(draw_btn) else machine.get_global_rect().get_center()
	var target_slot: Control = prize_lineup.get_child(slot_index + 1) as Control
	var end_pos: Vector2 = target_slot.get_global_rect().get_center()

	var anim_ball: GachaBallView = GachaBallViewScene.instantiate() as GachaBallView
	effects_layer.add_child(anim_ball)
	anim_ball.force_inventory_mode = true
	anim_ball.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	anim_ball.custom_minimum_size = Vector2(128, 128)
	anim_ball.size = Vector2(128, 128)
	anim_ball.populate(null, _create_prize_visual_data(prize_data))
	anim_ball.pivot_offset = anim_ball.size / 2.0

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


func _create_prize_visual_data(prize_data: Dictionary) -> Dictionary:
	var icon_tex: Texture2D = preload("res://assets/PixelArt/ui/textures/gachaballcapsule.png")
	return {
		"uuid": "prize_%d" % prize_data["slot_index"],
		"icon": icon_tex,
		"hp": prize_data["hp_value"],
		"pwr": prize_data["pwr_value"],
		"gold": prize_data["gold_value"],
		"display_name_key": "ui.stat_prize",
		"tier": 0,
		"category": &"ITEM",
	}


func _populate_prize_slot(slot_index: int, prize_data: Dictionary) -> void:
	var slot: SlotView = prize_lineup.get_child(slot_index + 1) as SlotView
	slot.set_content(_create_prize_visual_data(prize_data), true, false)
	_add_stat_label_to_slot(slot, prize_data)


func _add_stat_label_to_slot(slot: Control, prize_data: Dictionary) -> void:
	var existing: Node = slot.get_node_or_null("StatLabelContainer")
	if is_instance_valid(existing):
		existing.queue_free()

	var container := VBoxContainer.new()
	container.name = "StatLabelContainer"
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(container)

	var val: int = int(prize_data["hp_value"]) + int(prize_data["pwr_value"]) + int(prize_data["gold_value"])
	if val > 0:
		var label := Label.new()
		label.text = "%d" % val
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 36)
		var color: Color = Color.RED if int(prize_data["hp_value"]) > 0 else (Color.MEDIUM_PURPLE if int(prize_data["pwr_value"]) > 0 else Color.GOLD)
		label.add_theme_color_override("font_color", color)
		label.add_theme_color_override("font_outline_color", Color.WHITE)
		label.add_theme_constant_override("outline_size", 6)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(label)


# --- Prize Application & Leave ---

func _on_prize_slot_gui_input(event: InputEvent, prize_index: int) -> void:
	if InputUtils.is_primary_pointer_press(event):
		var action: GameAction = ClaimRestSiteGoldAction.new(prize_index) if site_type == SiteType.GOLD else UpgradeRestSiteAction.new(prize_index)
		ActionQueue.request(action)


func execute_upgrade_visuals(prize_index: int) -> void:
	await _apply_prize(prize_index)
	_finish_active_action()


func _apply_prize(prize_index: int) -> void:
	Audio.play_sfx("ui_click")
	var prize: Dictionary = GameManager.claim_rest_site_prize(prize_index)
	if prize.is_empty():
		return
	_prizes = GameManager._temporary_rest_site_prizes.duplicate(true)
	await _animate_buff_application(prize_index, prize)
	_clear_prize_slot(prize_index)
	_populate_hero_slot()


func _animate_buff_application(prize_index: int, prize_data: Dictionary) -> void:
	var prize_slot: Control = prize_lineup.get_child(prize_index + 1) as Control
	var ball_view: GachaBallView = _resolve_ball_view(prize_slot)
	if not is_instance_valid(ball_view):
		return

	var start_pos: Vector2 = ball_view.get_global_rect().get_center()
	var end_pos: Vector2
	if site_type == SiteType.GOLD:
		var main_node: Node = GameManager._active_main_node
		var gold_group: Control = main_node.get_node_or_null("%GoldGroup") as Control if is_instance_valid(main_node) else null
		end_pos = gold_group.get_global_rect().get_center() if is_instance_valid(gold_group) else Vector2(100, 60)
	else:
		end_pos = hero_slot.get_global_rect().get_center()

	ball_view.pivot_offset = ball_view.size / 2.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(ball_view, "scale", Vector2(1.4, 1.4), 0.1)
	tween.tween_property(ball_view, "modulate:a", 0.0, 0.15).set_delay(0.1)

	var val: int = int(prize_data["hp_value"]) + int(prize_data["pwr_value"]) + int(prize_data["gold_value"])
	var type_str: String = "hp" if int(prize_data["hp_value"]) > 0 else ("pwr" if int(prize_data["pwr_value"]) > 0 else "gold")

	var proj: Node = VFXFactory.spawn_projectile_on_layer(val, type_str, start_pos, end_pos, false)
	if is_instance_valid(proj):
		proj.launch()
		await proj.impact
		if site_type != SiteType.GOLD:
			_do_hero_buff_hop(Color.RED if type_str == "hp" else Color.MEDIUM_PURPLE)

	ball_view.hide()
	await AnimationConstants.create_pausable_timer(get_tree(), 0.2).timeout


func _do_hero_buff_hop(flash_color: Color) -> void:
	Audio.play_sfx("unit_buff")
	if is_instance_valid(GameManager.run_state.hero_instance):
		var uuid: String = GameManager.run_state.hero_instance.ball_uuid
		SignalBus.unit_color_flash.emit(uuid, flash_color, 0.4)
		SignalBus.unit_deform.emit(uuid, &"HOP_DEFORM")


func _clear_prize_slot(prize_index: int) -> void:
	var slot: SlotView = prize_lineup.get_child(prize_index + 1) as SlotView
	var label_container: Node = slot.get_node_or_null("StatLabelContainer")
	if is_instance_valid(label_container):
		label_container.queue_free()
	slot.set_content({}, false, false)


func _refresh_all_prize_slots() -> void:
	for i: int in range(4):
		_clear_prize_slot(i)
	for p: Dictionary in _prizes:
		_populate_prize_slot(p["slot_index"], p)


func _on_leave_pressed() -> void:
	ActionQueue.request(LeaveRestSiteAction.new())


func execute_leave_visuals() -> void:
	leave_button.disabled = true
	study_button.disabled = true
	tier1_draw_button.disabled = true
	tier2_draw_button.disabled = true
	tier3_draw_button.disabled = true

	while not _prizes.is_empty():
		var prize: Dictionary = _prizes[0]
		await _apply_prize(prize["slot_index"])
	GameManager.finish_rest_site_leave()

	SignalBus.gacha_tokens_changed.emit(0)
	SignalBus.path_choice_scene_requested.emit()
	queue_free()
