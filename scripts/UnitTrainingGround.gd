# res://scripts/UnitTrainingGround.gd
extends Control

## Unit Training Ground - Train units' HP or PWR using flashcard tokens
## Mirrors BlackMarket UI flow with training-specific drop zones

const TRAIN_COST_GOLD: int = 5
const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")
const SlotViewScene = preload("res://scenes/SlotView.tscn")
const GoldCoinVFXScene = preload("res://scripts/vfx/GoldCoinVFX.gd")
const RejectionFeedbackScript = preload("res://scripts/vfx/RejectionFeedback.gd")
const InputUtils = preload("res://scripts/InputUtils.gd")

@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var open_inventory_button: Button = %OpenInventoryButton
@onready var leave_button: Button = %LeaveButton

var _action_in_progress: bool = false
var _last_inventory_open: bool = false
var _training_stat: String = "" # "hp" or "pwr"
var _training_unit_data: Dictionary = {}
var _training_unit_location: LocationIdentifier = null
var _tokens: int = 0

# Popup references (built programmatically)
var _popup_root: CenterContainer = null
var _popup_panel: PanelContainer = null
var _popup_ball_view: GachaBallView = null
var _popup_btn_1: Button = null
var _popup_btn_2: Button = null
var _popup_btn_3: Button = null
var _popup_done_btn: Button = null
var _popup_title_label: Label = null

func _ready() -> void:
	open_inventory_button.pressed.connect(_on_open_inventory_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	gui_input.connect(_on_gui_input)
	SignalBus.locale_changed.connect(_update_localized_text)
	SignalBus.action_drop_zone_1_activated.connect(_on_train_hp_requested)
	SignalBus.action_drop_zone_2_activated.connect(_on_train_pwr_requested)
	FlashcardManager.minigame_finished.connect(_on_flashcard_completed)
	SignalBus.flashcard_token_earned.connect(_on_live_token_earned)
	_update_localized_text()
	set_process(true)
	_build_training_popup()
	# Pre-register custom drop zone labels with Main.gd
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node) and main_node.has_method("set_action_zone_texts"):
		main_node.set_action_zone_texts(tr("ui.utg_drop_hp"), tr("ui.utg_drop_pwr"))

func _exit_tree() -> void:
	if SignalBus.locale_changed.is_connected(_update_localized_text):
		SignalBus.locale_changed.disconnect(_update_localized_text)
	if SignalBus.action_drop_zone_1_activated.is_connected(_on_train_hp_requested):
		SignalBus.action_drop_zone_1_activated.disconnect(_on_train_hp_requested)
	if SignalBus.action_drop_zone_2_activated.is_connected(_on_train_pwr_requested):
		SignalBus.action_drop_zone_2_activated.disconnect(_on_train_pwr_requested)
	if FlashcardManager.minigame_finished.is_connected(_on_flashcard_completed):
		FlashcardManager.minigame_finished.disconnect(_on_flashcard_completed)
	if SignalBus.flashcard_token_earned.is_connected(_on_live_token_earned):
		SignalBus.flashcard_token_earned.disconnect(_on_live_token_earned)
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node):
		if main_node.has_method("set_action_zone_texts"):
			main_node.set_action_zone_texts("", "")
		if main_node.has_method("hide_action_instruction"):
			main_node.hide_action_instruction()
		if main_node.has_method("hide_split_action_drop_zones"):
			main_node.hide_split_action_drop_zones()
	if is_instance_valid(_popup_root):
		_popup_root.queue_free()

func _process(_delta: float) -> void:
	var is_open := WindowManager.is_run_inventory_window_open()
	if is_open != _last_inventory_open:
		_last_inventory_open = is_open
		var main_node = GameManager._active_main_node
		if is_instance_valid(main_node):
			if is_open:
				if main_node.has_method("show_action_instruction"):
					main_node.show_action_instruction(tr("ui.utg_instruction"))
			else:
				if main_node.has_method("hide_action_instruction"):
					main_node.hide_action_instruction()
				if main_node.has_method("hide_split_action_drop_zones"):
					main_node.hide_split_action_drop_zones()

func _update_localized_text() -> void:
	title_label.text = tr("ui.utg_title")
	if description_label:
		description_label.text = tr("ui.utg_desc")
	open_inventory_button.text = tr("ui.utg_btn")
	leave_button.text = tr("ui.leave")

# --- Inventory helpers (reused from BlackMarket pattern) ---

func _is_run_inventory_source(source_loc: LocationIdentifier) -> bool:
	return String(source_loc.container).begins_with("RunInventoryT")

func _get_selected_inventory_unit() -> Dictionary:
	var selected_ctx = GlobalInteractionRouter.get_current_selection()
	if selected_ctx == null: return {}
	var selected_loc = selected_ctx.location if selected_ctx else null
	if not is_instance_valid(selected_loc): return {}
	if not _is_run_inventory_source(selected_loc): return {}
	var instance = GameManager.get_instance_from_location(selected_loc)
	if not is_instance_valid(instance): return {}
	var definition = instance.get_definition()
	if not is_instance_valid(definition): return {}
	# Only allow units (not items/trinkets)
	if definition.category != &"UNIT": return {}
	return {
		"location": selected_loc,
		"instance": instance,
		"definition": definition,
		"uuid": instance.ball_uuid
	}

# --- Training requests ---

func _on_train_hp_requested(is_drag: bool = false, mouse_pos: Vector2 = Vector2.ZERO) -> void:
	_start_training("hp", is_drag, mouse_pos)

func _on_train_pwr_requested(is_drag: bool = false, mouse_pos: Vector2 = Vector2.ZERO) -> void:
	_start_training("pwr", is_drag, mouse_pos)

func _start_training(stat: String, is_drag: bool, mouse_pos: Vector2) -> void:
	if _action_in_progress: return
	var item_data = _get_selected_inventory_unit()
	if item_data.is_empty(): return

	var main_node = GameManager._active_main_node
	var zone = null
	if is_instance_valid(main_node):
		if stat == "hp" and main_node.has_method("get_action_zone_1"):
			zone = main_node.get_action_zone_1()
		elif stat == "pwr" and main_node.has_method("get_action_zone_2"):
			zone = main_node.get_action_zone_2()

	# Check gold
	if not is_instance_valid(GameManager.run_state) or GameManager.run_state.gold < TRAIN_COST_GOLD:
		var gold_group = main_node.get_node_or_null("%GoldGroup") if is_instance_valid(main_node) else null
		var target = zone if is_instance_valid(zone) else open_inventory_button
		RejectionFeedbackScript.play_rejection_with_counter(target, gold_group, get_tree())
		return

	_action_in_progress = true
	_training_stat = stat
	_training_unit_data = item_data
	_training_unit_location = item_data.location

	# Determine interaction position
	var interaction_pos = Vector2.ZERO
	if is_drag:
		interaction_pos = mouse_pos if not mouse_pos.is_zero_approx() else get_viewport().get_mouse_position()
	else:
		var slot_view = WindowManager.find_view_for_location(item_data.location)
		if is_instance_valid(slot_view):
			interaction_pos = slot_view.get_global_rect().get_center()

	# Hide the unit in inventory slot
	var source_anchor = WindowManager.find_view_for_location(item_data.location)
	if is_instance_valid(source_anchor):
		for child in source_anchor.get_children():
			if child is GachaBallView:
				child.modulate.a = 0.0
				child.visible = false

	# Reset local tokens
	_tokens = 0
	SignalBus.emit_signal("gacha_tokens_changed", _tokens)

	# Animate gold spend then start minigame
	_animate_gold_spend(TRAIN_COST_GOLD, interaction_pos, func():
		if GameManager.run_state.spend_gold(TRAIN_COST_GOLD):
			SignalBus.emit_signal("selection_clear_requested")
			Audio.play_sfx("ui_drag_drop")
			# Start flashcard minigame
			if is_instance_valid(GameManager.run_state):
				FlashcardManager.start_minigame(GameManager.run_state, GameManager.run_state.active_deck_ids)
		else:
			_action_in_progress = false
			# Restore unit visibility
			if is_instance_valid(source_anchor):
				for child in source_anchor.get_children():
					if child is GachaBallView:
						child.visible = true
						child.modulate.a = 1.0
	)

# --- Token tracking ---

func _on_live_token_earned(amount: int) -> void:
	_tokens += amount
	SignalBus.emit_signal("gacha_tokens_changed", _tokens)

func _on_flashcard_completed(_results: Dictionary) -> void:
	# Show the training popup directly since the inventory remains open
	_show_training_popup()

# --- Training Popup ---

func _build_training_popup() -> void:
	_popup_root = CenterContainer.new()
	_popup_root.name = "TrainingPopupRoot"
	_popup_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_root.visible = false

	_popup_panel = PanelContainer.new()
	_popup_panel.name = "TrainingPopupPanel"
	# Compact container taking as little space as its contents allow
	_popup_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_popup_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	_popup_panel.add_theme_stylebox_override("panel", style)
	_popup_root.add_child(_popup_panel)

	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.custom_minimum_size = Vector2(440, 0)
	vbox.add_theme_constant_override("separation", 20)
	_popup_panel.add_child(vbox)

	# Title
	_popup_title_label = Label.new()
	_popup_title_label.text = tr("ui.utg_popup_title")
	_popup_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_title_label.add_theme_font_size_override("font_size", 28)
	_popup_title_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92))
	vbox.add_child(_popup_title_label)

	# Unit display slot (placed BEFORE buttons so it appears above)
	var unit_center = CenterContainer.new()
	unit_center.custom_minimum_size = Vector2(192, 192)
	vbox.add_child(unit_center)

	var unit_slot = Control.new()
	unit_slot.custom_minimum_size = Vector2(192, 192)
	unit_center.add_child(unit_slot)
	unit_slot.name = "UnitSlot"

	# Spacer between unit and buttons
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	# Buttons container
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_hbox)

	_popup_btn_1 = Button.new()
	_popup_btn_1.text = "1 Token"
	_popup_btn_1.custom_minimum_size = Vector2(140, 60)
	_popup_btn_1.pressed.connect(_on_popup_train_1)
	btn_hbox.add_child(_popup_btn_1)

	_popup_btn_2 = Button.new()
	_popup_btn_2.text = "2 Tokens"
	_popup_btn_2.custom_minimum_size = Vector2(140, 60)
	_popup_btn_2.pressed.connect(_on_popup_train_2)
	btn_hbox.add_child(_popup_btn_2)

	_popup_btn_3 = Button.new()
	_popup_btn_3.text = "3 Tokens"
	_popup_btn_3.custom_minimum_size = Vector2(140, 60)
	_popup_btn_3.pressed.connect(_on_popup_train_3)
	btn_hbox.add_child(_popup_btn_3)

	# Done button (sized to fit text, not oversized)
	_popup_done_btn = Button.new()
	_popup_done_btn.text = tr("ui.utg_done")
	_popup_done_btn.custom_minimum_size = Vector2(0, 40)
	_popup_done_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_popup_done_btn.pressed.connect(_on_popup_done)
	vbox.add_child(_popup_done_btn)

	# Place popup root into the global modal layer so it renders above the inventory
	var modal_layer = get_tree().get_first_node_in_group("modal_layer")
	if not is_instance_valid(modal_layer):
		if WindowManager.has_method("_get_modal_layer"):
			modal_layer = WindowManager._get_modal_layer()
	if is_instance_valid(modal_layer):
		modal_layer.add_child(_popup_root)
	else:
		add_child(_popup_root)

func _show_training_popup() -> void:
	if not is_instance_valid(_training_unit_data.get("instance")):
		_action_in_progress = false
		return

	# Populate the unit display using a SlotView wrapper (same as BattleView)
	var unit_slot = _popup_panel.find_child("UnitSlot", true, false)

	if is_instance_valid(unit_slot):
		# Clear previous
		for c in unit_slot.get_children():
			c.queue_free()
		await get_tree().process_frame

		# Create a SlotView wrapper just like BattleView does
		var visual_data = VisualDataAdapter.create_visual_data(_training_unit_data.instance)
		var slot_view: PanelContainer = SlotViewScene.instantiate()
		slot_view.set_size_scale(2.0)
		slot_view.custom_minimum_size = Vector2(C.SLOT_SIZE_2X, C.SLOT_SIZE_2X)
		slot_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		# Use battle slot texture (same as battle board)
		if slot_view.has_method("set_slot_color"):
			slot_view.set_slot_color(&"PlayerLineup")
		unit_slot.add_child(slot_view)
		# Use set_content to create and configure the GachaBallView internally
		slot_view.set_content(visual_data, false, false)
		# Find the GachaBallView that set_content created
		for child in slot_view.get_children():
			if child is GachaBallView:
				_popup_ball_view = child
				_popup_ball_view.set_is_interactive(false)
				break

	_update_popup_buttons()
	_popup_root.visible = true
	_popup_root.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(_popup_root, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _update_popup_buttons() -> void:
	_popup_btn_1.disabled = _tokens < 1
	_popup_btn_2.disabled = _tokens < 2
	_popup_btn_3.disabled = _tokens < 3
	_popup_btn_1.text = "1 Token"
	_popup_btn_2.text = "2 Tokens"
	_popup_btn_3.text = "3 Tokens"

func _on_popup_train_1() -> void:
	_spend_tokens_and_train(1)

func _on_popup_train_2() -> void:
	_spend_tokens_and_train(2)

func _on_popup_train_3() -> void:
	_spend_tokens_and_train(3)

func _spend_tokens_and_train(cost: int) -> void:
	if _tokens < cost: return
	_tokens -= cost
	SignalBus.emit_signal("gacha_tokens_changed", _tokens)
	_update_popup_buttons()

	# Roll: cost+1 possible outcomes (0..cost), uniform distribution
	var roll = randi() % (cost + 1)

	# Apply stat buff (even if zero, we still animate)
	var unit_uuid = _training_unit_data.get("uuid", "")
	if unit_uuid == "" or not is_instance_valid(GameManager.run_state):
		return

	# Self-buff VFX: projectile from unit to itself (animate even on zero)
	if is_instance_valid(_popup_ball_view):
		var center = _popup_ball_view.get_global_rect().get_center()
		var proj = VFXFactory.spawn_projectile_on_layer(roll, _training_stat, center, center, true)
		if proj:
			proj.launch()
			await proj.impact
		
		# DEFERRED: Apply stat buff to backend AFTER impact so visual tween has correct start/end
		if roll > 0:
			var hp_delta = roll if _training_stat == "hp" else 0
			var pwr_delta = roll if _training_stat == "pwr" else 0
			GameManager.run_state.modify_unit_base_stats(unit_uuid, hp_delta, pwr_delta)
		
		# Update the visual label with animation (replicates battle board logic)
		var instance = GameManager.run_state.get_instance_by_uuid(unit_uuid)
		if is_instance_valid(instance):
			var new_val = instance.current_hp if _training_stat == "hp" else instance.current_pwr
			_popup_ball_view.animate_stat_change(new_val, roll, _training_stat)
			
		# HOP_DEFORM animation (same as battle buff hop)
		await _play_buff_hop()
	else:
		Audio.play_sfx("unit_buff")

func _play_buff_hop() -> void:
	"""Replicate the battle-board HOP + HOP_DEFORM animation on the popup ball view."""
	if not is_instance_valid(_popup_ball_view):
		return

	Audio.play_sfx("unit_buff")

	var icon = _popup_ball_view.icon_rect if is_instance_valid(_popup_ball_view.icon_rect) else _popup_ball_view
	if not is_instance_valid(icon):
		return

	# Set bottom-center pivot so the hop looks grounded
	icon.pivot_offset = Vector2(icon.size.x / 2.0, icon.size.y)

	# Constants matching AnimationConstants.gd
	var hop_height := 30.0
	var squish := Vector2(0.85, 1.15)
	var stretch := Vector2(1.15, 0.85)

	var original_pos = _popup_ball_view.position
	var hop_target = Vector2(original_pos.x, original_pos.y - hop_height)

	# Movement: hop up then land
	var move_tween = _popup_ball_view.create_tween()
	move_tween.tween_property(_popup_ball_view, "position", hop_target, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	move_tween.tween_property(_popup_ball_view, "position", original_pos, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Deform: squish → stretch → squish → elastic normalize (synced with hop)
	var deform_tween = icon.create_tween()
	deform_tween.tween_property(icon, "scale", squish, 0.03).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	deform_tween.tween_property(icon, "scale", stretch, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	deform_tween.tween_property(icon, "scale", squish, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	deform_tween.tween_property(icon, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Color flash
	var flash_color = Color.RED if _training_stat == "hp" else Color.MEDIUM_PURPLE
	_popup_ball_view.modulate = Color(flash_color.r * 1.3, flash_color.g * 1.3, flash_color.b * 1.3, 1.0)
	var color_tween = _popup_ball_view.create_tween()
	color_tween.tween_property(_popup_ball_view, "modulate", Color.WHITE, 0.3)

	await deform_tween.finished
	icon.scale = Vector2.ONE

func _on_popup_done() -> void:
	if not is_instance_valid(_popup_panel): return

	# Inventory should already be open (re-opened after minigame), find the target slot
	var target_view = WindowManager.find_view_for_location(_training_unit_location)
	var start_pos = Vector2.ZERO
	if is_instance_valid(_popup_ball_view):
		start_pos = _popup_ball_view.get_global_rect().get_center()

	# Hide popup
	var tween = create_tween()
	tween.tween_property(_popup_root, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		_popup_root.visible = false
	)

	# Create a VFX ball to fly back to the slot
	if is_instance_valid(_training_unit_data.get("instance")) and start_pos != Vector2.ZERO:
		var visual_data = VisualDataAdapter.create_visual_data(_training_unit_data.instance)
		var vfx_ball = _create_vfx_gachaball(visual_data, start_pos)

		if is_instance_valid(target_view):
			# Hide the target view during animation
			var ball_in_slot = _resolve_ball_view(target_view)
			if is_instance_valid(ball_in_slot):
				ball_in_slot.visible = false
				ball_in_slot.modulate.a = 0.0

			await _animate_jump_to_slot(vfx_ball, start_pos, target_view)
		else:
			if is_instance_valid(vfx_ball): vfx_ball.queue_free()
	else:
		# Just restore visibility
		if is_instance_valid(target_view):
			var ball_in_slot = _resolve_ball_view(target_view)
			if is_instance_valid(ball_in_slot):
				ball_in_slot.visible = true
				ball_in_slot.modulate.a = 1.0

	_action_in_progress = false
	_training_unit_data = {}
	_training_unit_location = null
	_training_stat = ""
	SignalBus.emit_signal("gacha_tokens_changed", 0)

# --- Animation helpers (reused from BlackMarket pattern) ---

func _create_vfx_gachaball(visual_data: Dictionary, pos: Vector2) -> GachaBallView:
	var anim_ball = GachaBallViewScene.instantiate()
	var effects_layer = WindowManager.get_vfx_layer()
	effects_layer.add_child(anim_ball)
	
	# Fix warning: Reset anchors before setting size for a manual-transform node
	anim_ball.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	
	anim_ball.force_inventory_mode = true
	anim_ball.set_size_scale(1.0)
	anim_ball.custom_minimum_size = Vector2(96, 96)
	anim_ball.size = Vector2(96, 96)
	anim_ball.populate(null, visual_data, false)
	anim_ball.set_is_interactive(false)
	anim_ball.pivot_offset = anim_ball.size / 2.0
	anim_ball.global_position = pos - anim_ball.pivot_offset
	return anim_ball

func _animate_jump_to_slot(vfx_ball: GachaBallView, start_pos: Vector2, target_slot: Control) -> void:
	if not is_instance_valid(vfx_ball) or not is_instance_valid(target_slot):
		if is_instance_valid(vfx_ball): vfx_ball.queue_free()
		return

	var end_pos = target_slot.get_global_rect().get_center()
	vfx_ball.z_index = RenderingServer.CANVAS_ITEM_Z_MAX

	var control_point = Vector2((start_pos.x + end_pos.x) / 2.0, min(start_pos.y, end_pos.y) - 200)
	var jump_tween = vfx_ball.create_tween()

	jump_tween.tween_method(func(t: float):
		var eased_t = pow(t, 0.55)
		var inv_t = 1.0 - eased_t
		var pos = (inv_t * inv_t * start_pos) + (2.0 * inv_t * eased_t * control_point) + (eased_t * eased_t * end_pos)
		vfx_ball.global_position = pos - vfx_ball.pivot_offset
	, 0.0, 1.0, 0.45)

	await jump_tween.finished
	vfx_ball.queue_free()

	# Restore target slot visibility
	if is_instance_valid(target_slot):
		target_slot.visible = true
		target_slot.modulate.a = 1.0
		for child in target_slot.get_children():
			if child is Control:
				child.visible = true
				child.modulate.a = 1.0
		var ball_view = _resolve_ball_view(target_slot)
		if is_instance_valid(ball_view) and ball_view.has_method("play_landing_bounce"):
			ball_view.play_landing_bounce()

func _resolve_ball_view(anchor: Control) -> Control:
	if not is_instance_valid(anchor): return null
	if anchor is GachaBallView: return anchor
	for child in anchor.get_children():
		if child is GachaBallView: return child
	return null

func _animate_gold_spend(amount: int, target_pos: Vector2, on_complete: Callable) -> void:
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
		gold_icon = gold_group
	var gold_rect = gold_icon.get_global_rect()
	var start_pos = Vector2(
		gold_rect.position.x + gold_rect.size.x / 2,
		gold_rect.position.y + gold_rect.size.y / 2
	)
	var end_pos = target_pos
	var coins_to_spawn = mini(amount, 5)
	var stagger_delay = 0.08
	for i in range(coins_to_spawn):
		var coin_vfx = GoldCoinVFXScene.new()
		var effects_layer = WindowManager.get_vfx_layer()
		effects_layer.add_child(coin_vfx)
		coin_vfx.coin_landed.connect(func(_pos: Vector2):
			Audio.play_sfx("coin_land")
		)
		var offset = Vector2(randf_range(-15, 15), randf_range(-8, 8))
		coin_vfx.play(start_pos + offset, end_pos, i * stagger_delay)
		Audio.play_sfx("coin_spawn", 1.0 + (i * 0.05))
	var total_wait = (coins_to_spawn - 1) * stagger_delay + 0.55
	var wait_tween = create_tween()
	wait_tween.tween_interval(total_wait)
	wait_tween.tween_callback(on_complete)

# --- Standard UI handlers ---

func _on_open_inventory_pressed() -> void:
	if WindowManager.is_any_inspection_window_open():
		WindowManager.close_all_inspection_windows()
	else:
		SignalBus.emit_signal("inspect_inventory_requested")

func _on_leave_pressed() -> void:
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node):
		if main_node.has_method("hide_action_instruction"):
			main_node.hide_action_instruction()
		if main_node.has_method("hide_split_action_drop_zones"):
			main_node.hide_split_action_drop_zones()
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
