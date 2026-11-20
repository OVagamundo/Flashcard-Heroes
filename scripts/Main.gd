# res://scripts/Main.gd
extends Control

const InputUtils = preload("res://scripts/InputUtils.gd")
const PATH_CHOICE_SCENE = preload("res://scenes/PathChoice.tscn")
const BATTLE_SCENE = preload("res://scenes/Battle.tscn")
const REWARD_SCENE = preload("res://scenes/Reward.tscn")
const REWARD_ELITE_SCENE = preload("res://scenes/RewardElite.tscn")
const SHOP_SCENE = preload("res://scenes/Shop.tscn")

@onready var content_area: SubViewportContainer = %ContentArea
@onready var scene_background: TextureRect = %SceneBackground
@onready var scene_slot: MarginContainer = %SceneSlot

# Gacha machine containers
@onready var gacha_machine_1: Control = %GachaMachine1
@onready var gacha_machine_2: Control = %GachaMachine2
@onready var gacha_machine_3: Control = %GachaMachine3
@onready var gacha_machine_discard: Control = %GachaMachineDiscard
@onready var bottom_area: PanelContainer = %BottomArea

# Knob buttons for drawing
@onready var knob_button_1: TextureButton = %GachaMachine1.get_node("KnobButton") as TextureButton
@onready var knob_button_2: TextureButton = %GachaMachine2.get_node("KnobButton") as TextureButton
@onready var knob_button_3: TextureButton = %GachaMachine3.get_node("KnobButton") as TextureButton
@onready var knob_button_discard: TextureButton = %GachaMachineDiscard.get_knob_button()

@onready var gold_label: Label = %GoldLabel
@onready var days_label: Label = %DaysLabel
@onready var tokens_label: Label = %TokensLabel
@onready var token_icon: TextureRect = %TokenIcon
@onready var bonus_timer_group: HBoxContainer = %BonusTimerGroup
@onready var bonus_timer_label: Label = %BonusTimerLabel
@onready var flashcard_progress_bar: Control = %FlashcardProgressBar
@onready var player_trinket_bar: HBoxContainer = %PlayerTrinketBar

# Speed and Pause/Menu Controls
@onready var speed_1x_btn: Button = %Speed1xBtn
@onready var speed_2x_btn: Button = %Speed2xBtn
@onready var speed_4x_btn: Button = %Speed4xBtn
@onready var pause_btn: Button = %PauseBtn

# Machine inventory count labels
@onready var machine_1_count_label: Label = %GachaMachine1.get_node("CountLabel") as Label
@onready var machine_2_count_label: Label = %GachaMachine2.get_node("CountLabel") as Label
@onready var machine_3_count_label: Label = %GachaMachine3.get_node("CountLabel") as Label

var _current_content_node: Node = null
var _drop_zones: EncounterDropZoneBar = EncounterDropZoneBar.new()
var _hud_bar: HudTopBarPresenter = HudTopBarPresenter.new()
var _machine_bar: GachaMachineBarPresenter = GachaMachineBarPresenter.new()

var _gold_animations_in_flight: int:
	get: return _hud_bar.gold_animations_in_flight
var _token_animations_in_flight: int:
	get: return _hud_bar.token_animations_in_flight
var _bonus_timer_animations_in_flight: int:
	get: return _hud_bar.bonus_timer_animations_in_flight


func _ready() -> void:
	add_to_group("main")
	_machine_bar.build_machine_labels(self)
	GameManager.register_main_node(self)

	# Connect knob buttons to draw functionality
	knob_button_1.pressed.connect(func() -> void: _on_draw_button_pressed(knob_button_1, 1))
	knob_button_2.pressed.connect(func() -> void: _on_draw_button_pressed(knob_button_2, 2))
	knob_button_3.pressed.connect(func() -> void: _on_draw_button_pressed(knob_button_3, 3))
	if is_instance_valid(knob_button_discard):
		knob_button_discard.pressed.connect(func() -> void: _on_draw_discard_button_pressed(knob_button_discard))

	# Connect hover animations for knob buttons
	for btn: TextureButton in [knob_button_1, knob_button_2, knob_button_3, knob_button_discard]:
		if is_instance_valid(btn):
			btn.mouse_entered.connect(func() -> void: _machine_bar.on_knob_hover_enter(self, btn))
			btn.mouse_exited.connect(func() -> void: _machine_bar.on_knob_hover_exit(self, btn))

	# Connect machine containers to open inventory when clicked (outside knob button)
	gacha_machine_1.gui_input.connect(_on_machine_gui_input)
	gacha_machine_2.gui_input.connect(_on_machine_gui_input)
	gacha_machine_3.gui_input.connect(_on_machine_gui_input)
	if is_instance_valid(gacha_machine_discard):
		gacha_machine_discard.pressed.connect(_on_discard_machine_pressed)

	SignalBus.path_choice_scene_requested.connect(_on_path_choice_scene_requested)
	SignalBus.battle_state_changed.connect(_on_battle_state_changed)
	SignalBus.reward_scene_requested.connect(_on_reward_scene_requested)
	SignalBus.battle_inventory_changed.connect(_on_battle_inventory_changed)
	content_area.gui_input.connect(_on_content_area_gui_input)

	# Connect Top Bar elements to background handler (Blind Spot Fix)
	for overlay_ctrl: Control in [days_label, flashcard_progress_bar, gold_label, tokens_label, bonus_timer_label]:
		if is_instance_valid(overlay_ctrl):
			overlay_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
			overlay_ctrl.gui_input.connect(_on_ui_overlay_gui_input)

	SignalBus.gold_changed.connect(_on_gold_changed)
	SignalBus.gacha_tokens_changed.connect(_on_gacha_tokens_changed)
	SignalBus.minigame_bonus_time_changed.connect(_on_minigame_bonus_time_changed)
	ActionQueue.queue_idle.connect(_on_action_queue_idle)
	SignalBus.run_data_changed.connect(_on_run_data_changed)
	SignalBus.battle_phase_changed.connect(_on_battle_phase_changed)
	SignalBus.locale_changed.connect(_update_programmatic_labels)

	# Connect drop zone signals
	SignalBus.selection_changed.connect(_on_selection_changed_for_drop_zone)
	SignalBus.drag_started.connect(_on_drag_started_for_drop_zone)
	SignalBus.drag_ended.connect(_on_drag_ended_for_drop_zone)

	# Connect speed and pause/menu buttons
	if is_instance_valid(speed_1x_btn):
		speed_1x_btn.pressed.connect(func() -> void: _on_speed_button_pressed(1.0))
	if is_instance_valid(speed_2x_btn):
		speed_2x_btn.pressed.connect(func() -> void: _on_speed_button_pressed(2.0))
	if is_instance_valid(speed_4x_btn):
		speed_4x_btn.pressed.connect(func() -> void: _on_speed_button_pressed(4.0))
	if is_instance_valid(pause_btn):
		pause_btn.pressed.connect(_on_pause_menu_button_pressed)

	SignalBus.combat_speed_changed.connect(_on_combat_speed_changed)
	SignalBus.combat_pause_changed.connect(_on_combat_pause_changed)

	for speed_btn: Button in [speed_1x_btn, speed_2x_btn, speed_4x_btn, pause_btn]:
		_hud_bar.setup_speed_button_hover(self, speed_btn)

	_on_battle_state_changed(false)
	_drop_zones.build_all(self)

	SignalBus.emit_signal("path_choice_scene_requested")

	_populate_player_trinkets()
	if is_instance_valid(GameManager.run_state):
		_on_gold_changed(GameManager.run_state.gold)
		_hud_bar.update_day_label(self, GameManager.run_state.day)
		_populate_flashcard_progress()
	_hud_bar.update_bonus_timer_display(self)

	call_deferred("sync_visual_machine_counts_with_model")


func _exit_tree() -> void:
	GameManager.unregister_main_node()
	if ActionQueue.queue_idle.is_connected(_on_action_queue_idle):
		ActionQueue.queue_idle.disconnect(_on_action_queue_idle)
	if SignalBus.selection_changed.is_connected(_on_selection_changed_for_drop_zone):
		SignalBus.selection_changed.disconnect(_on_selection_changed_for_drop_zone)
	if SignalBus.drag_started.is_connected(_on_drag_started_for_drop_zone):
		SignalBus.drag_started.disconnect(_on_drag_started_for_drop_zone)
	if SignalBus.drag_ended.is_connected(_on_drag_ended_for_drop_zone):
		SignalBus.drag_ended.disconnect(_on_drag_ended_for_drop_zone)
	if SignalBus.combat_speed_changed.is_connected(_on_combat_speed_changed):
		SignalBus.combat_speed_changed.disconnect(_on_combat_speed_changed)
	if SignalBus.combat_pause_changed.is_connected(_on_combat_pause_changed):
		SignalBus.combat_pause_changed.disconnect(_on_combat_pause_changed)


func _on_content_area_gui_input(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		pass
	elif InputUtils.is_primary_pointer_release(event) and GlobalInteractionRouter.is_drag_active():
		pass


func _on_ui_overlay_gui_input(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		var context := InteractionContext.new()
		context.source_view_instance_id = get_instance_id()
		context.event_type = &"SINGLE_CLICK"
		context.entity_type = &"GLOBAL_BACKGROUND"
		context.interaction_mode = &"FULLY_INTERACTIVE"
		SignalBus.emit_signal("interaction_context_received", context)
		get_viewport().set_input_as_handled()
		if InputUtils.is_touch_pointer_event(event):
			accept_event()


func _on_machine_gui_input(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		var kind: String = "BATTLE" if GameManager.is_in_battle else "RUN"
		if WindowManager.is_run_inventory_window_open() or WindowManager.is_battle_inventory_window_open():
			ActionQueue.request(CloseInventoryAction.new(kind))
		else:
			var bm: BattleManager = get_tree().get_first_node_in_group("battle_manager") as BattleManager
			var is_anim: bool = _machine_bar.is_drawing_token or (is_instance_valid(bm) and bm.is_animations_playing())
			if is_anim:
				get_viewport().set_input_as_handled()
				if InputUtils.is_touch_pointer_event(event):
					accept_event()
				return
			ActionQueue.request(OpenInventoryAction.new(kind))
		get_viewport().set_input_as_handled()
		if InputUtils.is_touch_pointer_event(event):
			accept_event()


func _on_discard_machine_pressed() -> void:
	if GameManager.is_in_battle:
		return
	if WindowManager.is_discard_pile_window_open():
		ActionQueue.request(CloseDiscardPileAction.new())
	else:
		ActionQueue.request(OpenDiscardPileAction.new())


func _process(_delta: float) -> void:
	var should_show_waiting: bool = false
	if _machine_bar.is_mouse_over_draw_mechanic(self):
		var bm: BattleManager = get_tree().get_first_node_in_group("battle_manager") as BattleManager
		if _machine_bar.is_drawing_token or (is_instance_valid(bm) and bm.is_animations_playing()):
			should_show_waiting = true
	CursorManager.set_waiting_indicator(should_show_waiting)


# =============================================================================
# SCENE CONTENT ORCHESTRATION
# =============================================================================

func clear_content_area() -> void:
	if is_instance_valid(_current_content_node):
		_current_content_node.queue_free()
	_current_content_node = null


func get_replay_content_scene_id() -> String:
	if not is_instance_valid(_current_content_node):
		return ""
	return _current_content_node.scene_file_path if not _current_content_node.scene_file_path.is_empty() else String(_current_content_node.name)


func load_content(scene_resource: PackedScene) -> Node:
	clear_content_area()
	var instance: Node = scene_resource.instantiate()
	_current_content_node = instance
	scene_slot.add_child(instance)
	_sync_scene_background(instance)
	_notify_scene_transition_complete(instance)
	return instance


func _notify_scene_transition_complete(instance: Node) -> void:
	if not is_instance_valid(instance):
		return
	if not instance.is_node_ready():
		await instance.ready
	await get_tree().process_frame
	if not is_instance_valid(instance):
		return

	if ActionQueue.is_busy():
		var act: GameAction = ActionQueue.get_active_action()
		if is_instance_valid(act):
			if act is SelectPathAction and instance.get_node_or_null("BattleManager") != null:
				return
			if act is SelectPathAction or act is LeaveShopAction or act is LeaveRewardAction or act is LeaveRestSiteAction or act is LeaveTrainingAction or act is LeaveShrineAction or act is LeaveMergeEncounterAction or act is AcknowledgeBattleResultsAction:
				ActionQueue.finish_action(act)


func sync_scene_background(scene_instance: Node = null) -> void:
	var target: Node = scene_instance if is_instance_valid(scene_instance) else _current_content_node
	if is_instance_valid(target):
		_sync_scene_background(target)


func _sync_scene_background(scene_instance: Node) -> void:
	if not is_instance_valid(scene_background):
		return
	var bg_node: Node = scene_instance.get_node_or_null("Background")
	if is_instance_valid(bg_node) and bg_node is TextureRect:
		scene_background.texture = (bg_node as TextureRect).texture
		(bg_node as TextureRect).visible = false
	else:
		scene_background.texture = null


func _on_battle_start_requested(encounter_def: EncounterDefinition) -> void:
	load_content(BATTLE_SCENE)
	sync_visual_machine_counts_with_model()
	_populate_flashcard_progress()
	_start_battle_with_encounter(encounter_def)


func _on_path_choice_scene_requested() -> void:
	load_content(PATH_CHOICE_SCENE)
	Audio.play_music(SoundRegistry.BGM_MENU)
	call_deferred("sync_visual_machine_counts_with_model")
	if is_instance_valid(GameManager.run_state):
		_hud_bar.update_day_label(self, GameManager.run_state.day)
	_hud_bar.update_bonus_timer_display(self)


func _on_reward_scene_requested(context: Dictionary) -> void:
	clear_content_area()
	var is_special: bool = bool(context.get("is_special_victory", false))
	var scene_to_use: PackedScene = REWARD_ELITE_SCENE if is_special else REWARD_SCENE
	var instance: Node = scene_to_use.instantiate()
	if not is_instance_valid(instance):
		return
	_current_content_node = instance
	scene_slot.add_child(instance)
	_sync_scene_background(instance)
	call_deferred("sync_visual_machine_counts_with_model")
	instance.populate(context)
	_notify_scene_transition_complete(instance)


func _on_shop_scene_requested(context: Dictionary) -> void:
	clear_content_area()
	var instance: Node = SHOP_SCENE.instantiate()
	_current_content_node = instance
	scene_slot.add_child(instance)
	_sync_scene_background(instance)
	call_deferred("sync_visual_machine_counts_with_model")
	instance.populate(context)
	_notify_scene_transition_complete(instance)


func _start_battle_with_encounter(encounter_def: EncounterDefinition) -> void:
	var battle_manager: BattleManager = _current_content_node.get_node_or_null("BattleManager") as BattleManager
	if is_instance_valid(battle_manager):
		battle_manager.start_battle(encounter_def)


# =============================================================================
# BATTLE & RUN STATE SIGNAL HANDLERS
# =============================================================================

func _on_battle_inventory_changed() -> void:
	_machine_bar.update_machine_costs()
	knob_button_1.disabled = false
	knob_button_2.disabled = false
	knob_button_3.disabled = false
	if is_instance_valid(knob_button_discard):
		knob_button_discard.disabled = false

	var bm: BattleManager = get_tree().get_first_node_in_group("battle_manager") as BattleManager
	if is_instance_valid(bm) and bm.get_current_phase() == BattleManager.Phases.COMBAT:
		return

	_populate_player_trinkets()
	_hud_bar.update_bonus_timer_display(self)


func _on_battle_state_changed(is_in_battle: bool) -> void:
	if is_instance_valid(knob_button_1):
		knob_button_1.disabled = not is_in_battle
	if is_instance_valid(knob_button_2):
		knob_button_2.disabled = not is_in_battle
	if is_instance_valid(knob_button_3):
		knob_button_3.disabled = not is_in_battle
	if is_instance_valid(knob_button_discard):
		knob_button_discard.disabled = not is_in_battle
	_hud_bar.update_bonus_timer_display(self)

	if is_instance_valid(speed_1x_btn):
		speed_1x_btn.visible = is_in_battle
	if is_instance_valid(speed_2x_btn):
		speed_2x_btn.visible = is_in_battle
	if is_instance_valid(speed_4x_btn):
		speed_4x_btn.visible = is_in_battle
	if is_instance_valid(pause_btn):
		pause_btn.visible = true

	if is_in_battle:
		call_deferred("sync_visual_machine_counts_with_model")
		var bm: BattleManager = GameManager.get_battle_manager() as BattleManager
		if is_instance_valid(bm):
			set_visual_tokens(bm.get_gacha_tokens(), false)
	_hud_bar.update_speed_button_styles(self, AnimationConstants.speed_factor)


func _on_battle_phase_changed(phase_name: StringName) -> void:
	if phase_name != &"COMBAT":
		_populate_player_trinkets()


func _on_gold_changed(new_amount: int) -> void:
	if _hud_bar.gold_animations_in_flight > 0 or ActionQueue.is_busy():
		return
	set_visual_gold(new_amount, true)


func _on_gacha_tokens_changed(new_amount: int) -> void:
	if _hud_bar.token_animations_in_flight > 0 or ActionQueue.is_busy():
		return
	set_visual_tokens(new_amount, true)


func _on_action_queue_idle() -> void:
	sync_visual_machine_counts_with_model()
	if _hud_bar.gold_animations_in_flight == 0 and is_instance_valid(GameManager.run_state):
		set_visual_gold(GameManager.run_state.gold, false)
	if _hud_bar.token_animations_in_flight == 0 and is_instance_valid(GameManager.run_state):
		set_visual_tokens(GameManager.run_state.get_room_tokens(), false)
	if _hud_bar.bonus_timer_animations_in_flight == 0:
		_hud_bar.update_bonus_timer_display(self)


func _on_run_data_changed() -> void:
	if is_instance_valid(GameManager.run_state):
		_hud_bar.update_day_label(self, GameManager.run_state.day)
		_on_gold_changed(GameManager.run_state.gold)
		_populate_player_trinkets()
		_populate_flashcard_progress()
		_hud_bar.update_bonus_timer_display(self)


func _on_minigame_bonus_time_changed(new_bonus_time: float) -> void:
	if _hud_bar.bonus_timer_animations_in_flight > 0 or ActionQueue.is_busy():
		return
	_hud_bar.update_bonus_timer_display(self, new_bonus_time)


func _populate_player_trinkets() -> void:
	if not is_instance_valid(player_trinket_bar):
		return
	var trinket_container: DataContainer = GameManager.run_state.get_container(RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS) if is_instance_valid(GameManager.run_state) else null
	var slots: Array[Node] = player_trinket_bar.get_children()
	for i: int in range(slots.size()):
		var slot_view: SlotView = slots[i] as SlotView
		if not is_instance_valid(slot_view):
			continue
		for child in slot_view.get_children():
			if child is TextureRect and (child.z_index == 10 or child.z_index == -1):
				continue
			child.queue_free()
		slot_view.set_size_scale(1.0)
		var loc := LocationIdentifier.new()
		loc.container = RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS
		loc.index = i
		slot_view.populate(loc)
		slot_view.set_interaction_context(&"INSPECTION_ONLY", 0)
		var instance: GachaBallInstance = GameManager.get_instance_from_location(loc) if is_instance_valid(trinket_container) else null
		if is_instance_valid(instance):
			var visual_data: Dictionary = VisualDataAdapter.create_visual_data(instance)
			slot_view.set_content(visual_data, true, false)
			if slot_view.get_child_count() > 0:
				var view: Node = slot_view.get_child(0)
				if view is GachaBallView:
					(view as GachaBallView).set_interaction_context(&"INSPECTION_ONLY", &"TRINKET", 0)
		else:
			slot_view.set_content({})


func show_empty_trinket_slots() -> void:
	if not is_instance_valid(player_trinket_bar):
		return
	for slot in player_trinket_bar.get_children():
		if slot is SlotView and (slot as SlotView).is_trinket_slot:
			(slot as SlotView).show_empty_trinket_slot = true


func hide_empty_trinket_slots() -> void:
	if not is_instance_valid(player_trinket_bar):
		return
	for slot in player_trinket_bar.get_children():
		if slot is SlotView and (slot as SlotView).is_trinket_slot:
			(slot as SlotView).show_empty_trinket_slot = false


func _populate_flashcard_progress() -> void:
	flashcard_progress_bar.populate(GameManager.run_state)


# =============================================================================
# HUD TOP BAR DELEGATES (HudTopBarPresenter)
# =============================================================================

func _on_speed_button_pressed(speed: float) -> void:
	_hud_bar.on_speed_button_pressed(speed)

func _on_pause_menu_button_pressed() -> void:
	WindowManager.toggle_options_window()

func _on_combat_speed_changed(speed: float) -> void:
	_hud_bar.update_speed_button_styles(self, speed)

func _on_combat_pause_changed(is_paused: bool) -> void:
	_hud_bar.update_speed_button_styles(self, -1.0 if is_paused else AnimationConstants.speed_factor)

func get_visual_gold() -> int:
	return _hud_bar.visual_gold

func get_visual_tokens() -> int:
	return _hud_bar.visual_tokens

func set_visual_gold(new_amount: int, animate_pop: bool = true) -> void:
	_hud_bar.set_visual_gold(self, new_amount, animate_pop)

func modify_visual_gold(delta: int, animate_pop: bool = true) -> void:
	_hud_bar.modify_visual_gold(self, delta, animate_pop)

func set_visual_tokens(new_amount: int, animate_pop: bool = true) -> void:
	_hud_bar.set_visual_tokens(self, new_amount, animate_pop)

func modify_visual_tokens(delta: int, animate_pop: bool = true) -> void:
	_hud_bar.modify_visual_tokens(self, delta, animate_pop)

func begin_gold_animation() -> void:
	_hud_bar.begin_gold_animation()

func end_gold_animation() -> void:
	_hud_bar.end_gold_animation()

func begin_token_animation() -> void:
	_hud_bar.begin_token_animation()

func end_token_animation() -> void:
	_hud_bar.end_token_animation()

func get_visual_bonus_timer() -> float:
	return _hud_bar.visual_bonus_timer

func set_visual_bonus_timer(new_amount: float, animate_pop: bool = true) -> void:
	_hud_bar.set_visual_bonus_timer(self, new_amount, animate_pop)

func modify_visual_bonus_timer(delta: float, animate_pop: bool = true) -> void:
	_hud_bar.modify_visual_bonus_timer(self, delta, animate_pop)

func begin_bonus_timer_animation() -> void:
	_hud_bar.begin_bonus_timer_animation(self)

func end_bonus_timer_animation() -> void:
	_hud_bar.end_bonus_timer_animation(self)

func set_gold_display(new_amount: int, animate_pop: bool = true) -> void:
	set_visual_gold(new_amount, animate_pop)

func set_token_display(new_amount: int, animate_pop: bool = true) -> void:
	set_visual_tokens(new_amount, animate_pop)

func set_battle_token_tray(tray: Control) -> void:
	_hud_bar.set_battle_token_tray(self, tray)

func clear_battle_token_tray(tray: Control) -> void:
	_hud_bar.clear_battle_token_tray(self, tray)

func get_token_feedback_control() -> Control:
	return _hud_bar.get_token_feedback_control(self)

func get_token_animation_origin() -> Vector2:
	return _hud_bar.get_token_animation_origin(self)


# =============================================================================
# GACHA MACHINE BAR DELEGATES (GachaMachineBarPresenter)
# =============================================================================

func get_knob_button(tier: int) -> BaseButton:
	match tier:
		1: return knob_button_1
		2: return knob_button_2
		3: return knob_button_3
		4: return knob_button_discard
	return null

func get_discard_knob_button() -> BaseButton:
	return knob_button_discard

func _on_draw_discard_button_pressed(_button: BaseButton) -> void:
	_machine_bar.request_machine_draw(self, 4, DrawDiscardAction.new())

func _on_draw_button_pressed(_button: BaseButton, tier: int) -> void:
	_machine_bar.request_machine_draw(self, tier, DrawGachaAction.new(tier))

func play_machine_draw(tier: int, cost: int) -> void:
	await _machine_bar.play_machine_draw(self, tier, cost)

func animate_machine_inventory_change(tier: int, amount: int) -> void:
	_machine_bar.animate_machine_inventory_change(self, tier, amount)

func play_machine_landing_bounce(machine: Control) -> void:
	_machine_bar.play_machine_landing_bounce(machine)

func animate_machine_bump(machine: Control) -> void:
	_machine_bar.play_machine_landing_bounce(machine)

func sync_visual_machine_counts_with_model() -> void:
	_machine_bar.sync_visual_machine_counts_with_model(self)

func get_gacha_machine(tier: int) -> Control:
	match tier:
		1: return gacha_machine_1
		2: return gacha_machine_2
		3: return gacha_machine_3
		4: return gacha_machine_discard
	return null

func get_discard_machine() -> Control:
	return gacha_machine_discard


# =============================================================================
# ENCOUNTER DROP ZONE DELEGATES (EncounterDropZoneBar)
# =============================================================================

func show_confirm_drop_zone(mode: StringName) -> void:
	_drop_zones.show_confirm_drop_zone(self, mode)

func hide_confirm_drop_zone() -> void:
	_drop_zones.hide_confirm_drop_zone(self)

func _on_selection_changed_for_drop_zone(new_location: LocationIdentifier) -> void:
	_drop_zones.on_selection_changed(self, new_location)

func _deferred_maybe_hide_drop_zone() -> void:
	_drop_zones.deferred_maybe_hide_drop_zone(self)

func _deferred_maybe_hide_action_drop_zones() -> void:
	_drop_zones.deferred_maybe_hide_action_drop_zones(self)

func _on_drag_started_for_drop_zone(origin_context: InteractionContext) -> void:
	_drop_zones.on_drag_started(self, origin_context)

func _on_drag_ended_for_drop_zone(_was_handled: bool) -> void:
	_drop_zones.on_drag_ended(self)

func get_confirm_drop_zone_rect() -> Rect2:
	return _drop_zones.get_confirm_drop_zone_rect()

func is_point_inside_active_drop_zone(pos: Vector2) -> bool:
	return _drop_zones.is_point_inside_active_drop_zone(pos)

func _update_programmatic_labels() -> void:
	_drop_zones.update_programmatic_labels()

func show_split_action_drop_zones(left_text: String = "", right_text: String = "") -> void:
	_drop_zones.show_split_action_drop_zones(self, left_text, right_text)

func set_action_zone_texts(left_text: String, right_text: String, units_only: bool = false) -> void:
	_drop_zones.set_action_zone_texts(left_text, right_text, units_only)

func hide_split_action_drop_zones() -> void:
	_drop_zones.hide_split_action_drop_zones(self)

func show_action_instruction(text: String = "") -> void:
	_drop_zones.show_action_instruction(self, text)

func hide_action_instruction() -> void:
	_drop_zones.hide_action_instruction(self)

func get_action_zone_2() -> Control:
	return _drop_zones.get_action_zone_2()

func get_action_zone_1() -> Control:
	return _drop_zones.get_action_zone_1()

func show_reward_drop_zones() -> void:
	_drop_zones.show_reward_drop_zones(self)

func hide_reward_drop_zones() -> void:
	_drop_zones.hide_reward_drop_zones(self)

func get_reward_collect_zone() -> Control:
	return _drop_zones.get_reward_collect_zone()

func get_reward_sell_zone() -> Control:
	return _drop_zones.get_reward_sell_zone()
