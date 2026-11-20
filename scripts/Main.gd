# res://scripts/Main.gd
extends Control

const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")
const RejectionFeedbackScript = preload("res://scripts/vfx/RejectionFeedback.gd")
const InputUtils = preload("res://scripts/InputUtils.gd")

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
@onready var knob_button_1: TextureButton = %GachaMachine1.get_knob_button() if %GachaMachine1.has_method("get_knob_button") else %GachaMachine1.get_node_or_null("KnobButton")
@onready var knob_button_2: TextureButton = %GachaMachine2.get_knob_button() if %GachaMachine2.has_method("get_knob_button") else %GachaMachine2.get_node_or_null("KnobButton")
@onready var knob_button_3: TextureButton = %GachaMachine3.get_knob_button() if %GachaMachine3.has_method("get_knob_button") else %GachaMachine3.get_node_or_null("KnobButton")
@onready var knob_button_discard: TextureButton = %GachaMachineDiscard.get_knob_button() if %GachaMachineDiscard.has_method("get_knob_button") else %GachaMachineDiscard.get_node_or_null("KnobButton")

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
@onready var machine_1_count_label: Label = %GachaMachine1.get_count_label() if %GachaMachine1.has_method("get_count_label") else %GachaMachine1.get_node_or_null("CountLabel")
@onready var machine_2_count_label: Label = %GachaMachine2.get_count_label() if %GachaMachine2.has_method("get_count_label") else %GachaMachine2.get_node_or_null("CountLabel")
@onready var machine_3_count_label: Label = %GachaMachine3.get_count_label() if %GachaMachine3.has_method("get_count_label") else %GachaMachine3.get_node_or_null("CountLabel")

# Local Presentation State (Strict Simulation/Presentation Decoupling)
var _visual_gold: int = 0
var _visual_tokens: int = 0
var _visual_bonus_timer: float = 0.0
var _gold_animations_in_flight: int = 0
var _token_animations_in_flight: int = 0
var _bonus_timer_animations_in_flight: int = 0


const PATH_CHOICE_SCENE = preload("res://scenes/PathChoice.tscn")
const BATTLE_SCENE = preload("res://scenes/Battle.tscn")
const REWARD_SCENE = preload("res://scenes/Reward.tscn")
const REWARD_ELITE_SCENE = preload("res://scenes/RewardElite.tscn")

const SHOP_SCENE = preload("res://scenes/Shop.tscn")

var _current_content_node: Node = null

# Confirm drop zone overlay (covers bottom area for Reward/Shop confirm)
var _confirm_drop_zone: PanelContainer = null
var _confirm_drop_zone_label: RichTextLabel = null
var _confirm_drop_zone_mode: StringName = &"" # &"Rewards" or &"Shop"
var _confirm_drop_zone_visible: bool = false
var _drop_zone_drag_context: InteractionContext = null # Saved drag origin for restoring selection on drop

var _visual_machine_counts: Dictionary[int, int] = {1: 0, 2: 0, 3: 0}
var _machine_costs: Dictionary[int, HBoxContainer] = {}
var _battle_token_tray: Control


# Shrine split drop zones (Remove / Transform)
var _split_action_drop_zone_container: PanelContainer = null
var _action_zone_2: PanelContainer = null
var _action_zone_1: PanelContainer = null
var _action_label_2: RichTextLabel = null
var _action_label_1: RichTextLabel = null
var _split_action_drop_zones_visible: bool = false
var _reward_drop_zone_container: PanelContainer = null
var _reward_collect_zone: PanelContainer = null
var _reward_sell_zone: PanelContainer = null
var _reward_collect_label: RichTextLabel = null
var _reward_sell_label: RichTextLabel = null
var _reward_drop_zones_visible: bool = false

# Used to prevent overdrawing tokens while waiting for token toss animations to finish
var _pending_tokens_spent: int = 0

var _action_drop_zone_drag_context: InteractionContext = null
var _action_instruction_overlay: PanelContainer = null
var _action_instruction_label: Label = null
var _action_instruction_visible: bool = false

# Configurable drop zone labels (set by content scenes like Shrine/UnitTrainingGround)
var _action_zone_1_text: String = "" # Left zone custom text
var _action_zone_2_text: String = "" # Right zone custom text

func _ready() -> void:
	add_to_group("main")
	_build_machine_labels()
	GameManager.register_main_node(self) # Register self with GameManager
	
	# Connect knob buttons to draw functionality
	knob_button_1.pressed.connect(func(): _on_draw_button_pressed(knob_button_1, 1))
	knob_button_2.pressed.connect(func(): _on_draw_button_pressed(knob_button_2, 2))
	knob_button_3.pressed.connect(func(): _on_draw_button_pressed(knob_button_3, 3))
	if is_instance_valid(knob_button_discard):
		knob_button_discard.pressed.connect(func(): _on_draw_discard_button_pressed(knob_button_discard))
	
	# Connect hover animations for knob buttons
	knob_button_1.mouse_entered.connect(func(): _on_knob_hover_enter(knob_button_1))
	knob_button_1.mouse_exited.connect(func(): _on_knob_hover_exit(knob_button_1))
	knob_button_2.mouse_entered.connect(func(): _on_knob_hover_enter(knob_button_2))
	knob_button_2.mouse_exited.connect(func(): _on_knob_hover_exit(knob_button_2))
	knob_button_3.mouse_entered.connect(func(): _on_knob_hover_enter(knob_button_3))
	knob_button_3.mouse_exited.connect(func(): _on_knob_hover_exit(knob_button_3))
	if is_instance_valid(knob_button_discard):
		knob_button_discard.mouse_entered.connect(func(): _on_knob_hover_enter(knob_button_discard))
		knob_button_discard.mouse_exited.connect(func(): _on_knob_hover_exit(knob_button_discard))
	
	# Connect machine containers to open inventory when clicked (outside knob button)
	gacha_machine_1.gui_input.connect(func(event): _on_machine_gui_input(event))
	gacha_machine_2.gui_input.connect(func(event): _on_machine_gui_input(event))
	gacha_machine_3.gui_input.connect(func(event): _on_machine_gui_input(event))
	
	# Connect discard machine base to open the Discard
	if is_instance_valid(gacha_machine_discard):
		gacha_machine_discard.pressed.connect(_on_discard_machine_pressed)
	

	
	SignalBus.battle_start_requested.connect(_on_battle_start_requested)
	SignalBus.path_choice_scene_requested.connect(_on_path_choice_scene_requested)
	SignalBus.battle_state_changed.connect(_on_battle_state_changed)
	SignalBus.reward_scene_requested.connect(_on_reward_scene_requested)
	# TDD Safeguard: Re-enable draw buttons after the UI has redrawn.
	SignalBus.battle_inventory_changed.connect(_on_battle_inventory_changed)
	content_area.gui_input.connect(_on_content_area_gui_input)
	
	# Connect Top Bar elements to background handler (Blind Spot Fix)
	if is_instance_valid(days_label):
		days_label.mouse_filter = Control.MOUSE_FILTER_STOP
		days_label.gui_input.connect(_on_ui_overlay_gui_input)
	if is_instance_valid(flashcard_progress_bar):
		flashcard_progress_bar.mouse_filter = Control.MOUSE_FILTER_STOP
		flashcard_progress_bar.gui_input.connect(_on_ui_overlay_gui_input)
	# Also connect the Gold and Token labels/groups if possible
	if is_instance_valid(gold_label):
		# Gold label is usually inside a container, let's try to connect the label itself
		gold_label.mouse_filter = Control.MOUSE_FILTER_STOP
		gold_label.gui_input.connect(_on_ui_overlay_gui_input)
	if is_instance_valid(tokens_label):
		tokens_label.mouse_filter = Control.MOUSE_FILTER_STOP
		tokens_label.gui_input.connect(_on_ui_overlay_gui_input)
	if is_instance_valid(bonus_timer_label):
		bonus_timer_label.mouse_filter = Control.MOUSE_FILTER_STOP
		bonus_timer_label.gui_input.connect(_on_ui_overlay_gui_input)

	SignalBus.gold_changed.connect(_on_gold_changed)
	SignalBus.gacha_tokens_changed.connect(_on_gacha_tokens_changed)
	SignalBus.minigame_bonus_time_changed.connect(_on_minigame_bonus_time_changed)
	if is_instance_valid(ActionQueue):
		ActionQueue.queue_idle.connect(_on_action_queue_idle)
	SignalBus.shop_scene_requested.connect(_on_shop_scene_requested)
	SignalBus.run_data_changed.connect(_on_run_data_changed)
	SignalBus.battle_phase_changed.connect(_on_battle_phase_changed)
	SignalBus.locale_changed.connect(_update_programmatic_labels)
	
	# Connect drop zone signals
	SignalBus.selection_changed.connect(_on_selection_changed_for_drop_zone)
	SignalBus.drag_started.connect(_on_drag_started_for_drop_zone)
	SignalBus.drag_ended.connect(_on_drag_ended_for_drop_zone)
	# Connect speed and pause/menu buttons
	if is_instance_valid(speed_1x_btn):
		speed_1x_btn.pressed.connect(func(): _on_speed_button_pressed(1.0))
	if is_instance_valid(speed_2x_btn):
		speed_2x_btn.pressed.connect(func(): _on_speed_button_pressed(2.0))
	if is_instance_valid(speed_4x_btn):
		speed_4x_btn.pressed.connect(func(): _on_speed_button_pressed(4.0))
	if is_instance_valid(pause_btn):
		pause_btn.pressed.connect(_on_pause_menu_button_pressed)

	if SignalBus.has_signal("combat_speed_changed"):
		SignalBus.combat_speed_changed.connect(_on_combat_speed_changed)
	if SignalBus.has_signal("combat_pause_changed"):
		SignalBus.combat_pause_changed.connect(_on_combat_pause_changed)

	_setup_speed_button_hover(speed_1x_btn)
	_setup_speed_button_hover(speed_2x_btn)
	_setup_speed_button_hover(speed_4x_btn)
	_setup_speed_button_hover(pause_btn)

	_on_battle_state_changed(false)

	
	# Build the confirm drop zone overlay (programmatic, not in .tscn)
	_build_confirm_drop_zone()
	# Build the shrine split drop zones
	_build_split_action_drop_zones()
	_build_reward_drop_zones()

	SignalBus.emit_signal("path_choice_scene_requested")

	_populate_player_trinkets()
	if is_instance_valid(GameManager.run_state):
		_on_gold_changed(GameManager.run_state.gold)
		_update_day_label(GameManager.run_state.day)
		_populate_flashcard_progress()
	_update_bonus_timer_display()
	
	# Initial sync of machine counts based on model data
	call_deferred("sync_visual_machine_counts_with_model")

func _exit_tree() -> void:
	GameManager.unregister_main_node()
	if is_instance_valid(ActionQueue) and ActionQueue.queue_idle.is_connected(_on_action_queue_idle):
		ActionQueue.queue_idle.disconnect(_on_action_queue_idle)
	# Cleanup drop zone signals
	if SignalBus.selection_changed.is_connected(_on_selection_changed_for_drop_zone):
		SignalBus.selection_changed.disconnect(_on_selection_changed_for_drop_zone)
	if SignalBus.drag_started.is_connected(_on_drag_started_for_drop_zone):
		SignalBus.drag_started.disconnect(_on_drag_started_for_drop_zone)
	if SignalBus.drag_ended.is_connected(_on_drag_ended_for_drop_zone):
		SignalBus.drag_ended.disconnect(_on_drag_ended_for_drop_zone)
	if SignalBus.has_signal("combat_speed_changed") and SignalBus.combat_speed_changed.is_connected(_on_combat_speed_changed):
		SignalBus.combat_speed_changed.disconnect(_on_combat_speed_changed)
	if SignalBus.has_signal("combat_pause_changed") and SignalBus.combat_pause_changed.is_connected(_on_combat_pause_changed):
		SignalBus.combat_pause_changed.disconnect(_on_combat_pause_changed)


func _on_content_area_gui_input(event: InputEvent) -> void:
	# Handle background clicks and drag end on the main game area
	if InputUtils.is_primary_pointer_press(event):
		# Create and emit InteractionContext for main game background
		var context = InteractionContext.new()
		context.source_view_instance_id = get_instance_id()
		context.event_type = &"SINGLE_CLICK"
		context.location = null # No specific location for background
		context.entity_uuid = ""
		context.entity_type = &"GLOBAL_BACKGROUND"
		context.interaction_mode = &"FULLY_INTERACTIVE"
		context.window_group_id = 0 # Main game area
		# SignalBus.emit_signal("interaction_context_received", context)
	elif InputUtils.is_primary_pointer_release(event) and GlobalInteractionRouter.is_drag_active():
		pass

## Explicit handler for UI overlays (Top Bar, etc.) that should act as "Background"
## Clicking these should close inspection windows/deselect.
func _on_ui_overlay_gui_input(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		var context = InteractionContext.new()
		context.source_view_instance_id = get_instance_id()
		context.event_type = &"SINGLE_CLICK"
		context.entity_type = &"GLOBAL_BACKGROUND"
		context.interaction_mode = &"FULLY_INTERACTIVE"
		SignalBus.emit_signal("interaction_context_received", context)
		get_viewport().set_input_as_handled()
		if InputUtils.is_touch_pointer_event(event):
			accept_event()

func _on_machine_gui_input(event: InputEvent) -> void:
	# Handle clicks on machine image area (outside the knob button)
	if InputUtils.is_primary_pointer_press(event):
		var kind := "BATTLE" if (is_instance_valid(GameManager) and GameManager.is_in_battle) else "RUN"
		if WindowManager.is_run_inventory_window_open() or WindowManager.is_battle_inventory_window_open():
			ActionQueue.request(CloseInventoryAction.new(kind))
		else:
			var bm = get_tree().get_first_node_in_group("battle_manager")
			var is_anim = _is_drawing_token or (is_instance_valid(bm) and bm.has_method("is_animations_playing") and bm.is_animations_playing())
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
	if is_instance_valid(GameManager) and GameManager.is_in_battle:
		return # Handled by BattleView during battle
	if is_instance_valid(WindowManager) and WindowManager.is_discard_pile_window_open():
		ActionQueue.request(CloseDiscardPileAction.new())
	else:
		ActionQueue.request(OpenDiscardPileAction.new())

func _on_knob_hover_enter(button: TextureButton) -> void:
	if button.disabled:
		return
	# Grow the button slightly with a smooth animation
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	button.pivot_offset = button.size / 2
	tween.tween_property(button, "scale", Vector2(1.08, 1.08), 0.15)

func _on_knob_hover_exit(button: TextureButton) -> void:
	# Return to normal size
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)

var _is_drawing_token: bool = false

func _is_mouse_over_draw_mechanic() -> bool:
	var mouse_pos = get_viewport().get_mouse_position()
	var draw_controls = [
		gacha_machine_1, gacha_machine_2, gacha_machine_3, gacha_machine_discard,
		knob_button_1, knob_button_2, knob_button_3, knob_button_discard
	]
	for ctrl in draw_controls:
		if is_instance_valid(ctrl) and ctrl.is_visible_in_tree():
			if ctrl.get_global_rect().has_point(mouse_pos):
				return true
	return false

func _process(_delta: float) -> void:
	if not CursorManager.has_method("set_waiting_indicator"):
		return
	var should_show_waiting := false
	if _is_mouse_over_draw_mechanic():
		var bm = get_tree().get_first_node_in_group("battle_manager")
		var is_anim = _is_drawing_token or (is_instance_valid(bm) and bm.has_method("is_animations_playing") and bm.is_animations_playing())
		if is_anim:
			should_show_waiting = true
	CursorManager.set_waiting_indicator(should_show_waiting)

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
	var instance = scene_resource.instantiate()
	_current_content_node = instance
	scene_slot.add_child(instance)
	
	# Sync background texture to full-screen SceneBackground
	_sync_scene_background(instance)
	_notify_scene_transition_complete(instance)
	return instance

func _notify_scene_transition_complete(instance: Node) -> void:
	if not is_instance_valid(instance): return
	if not instance.is_node_ready():
		await instance.ready
	await get_tree().process_frame
	if not is_instance_valid(instance): return
	
	if is_instance_valid(ActionQueue) and ActionQueue.is_busy():
		var act = ActionQueue.get_active_action()
		if is_instance_valid(act):
			if act is SelectPathAction and instance.get_node_or_null("BattleManager") != null:
				return # Handled authoritatively by BattleManager.start_battle once battle setup is complete
			if act is SelectPathAction or act is LeaveShopAction or act is LeaveRewardAction or act is LeaveRestSiteAction or act is LeaveTrainingAction or act is LeaveShrineAction or act is LeaveMergeEncounterAction or act is AcknowledgeBattleResultsAction:
				ActionQueue.finish_action(act)

func sync_scene_background(scene_instance: Node = null) -> void:
	"""Public method to update the full-screen background texture from the current or specified scene instance"""
	var target = scene_instance if is_instance_valid(scene_instance) else _current_content_node
	if is_instance_valid(target):
		_sync_scene_background(target)

func _sync_scene_background(scene_instance: Node) -> void:
	"""Extract background texture from loaded scene and apply to full-screen SceneBackground"""
	if not is_instance_valid(scene_background):
		return
	
	# Look for a Background TextureRect child in the scene
	var bg_node = scene_instance.get_node_or_null("Background")
	if is_instance_valid(bg_node) and bg_node is TextureRect:
		scene_background.texture = bg_node.texture
		# Hide the scene's internal background since we're using the full-screen one
		bg_node.visible = false
	else:
		# No background in scene - clear the full-screen background
		scene_background.texture = null

func _on_battle_start_requested(encounter_def: EncounterDefinition) -> void:
	load_content(BATTLE_SCENE)
	# Snap visuals to model on screen transition
	sync_visual_machine_counts_with_model()
	_populate_flashcard_progress()
	_start_battle_with_encounter(encounter_def)

func _on_path_choice_scene_requested() -> void:
	load_content(PATH_CHOICE_SCENE)
	# AUDIO HOOK: Menu BGM (Returning from battle or shop)
	Audio.play_music(SoundRegistry.BGM_MENU)
	
	# Snap visuals to model on screen transition
	call_deferred("sync_visual_machine_counts_with_model")
	
	if is_instance_valid(GameManager.run_state):
		_update_day_label(GameManager.run_state.day)
	_update_bonus_timer_display()

func _on_reward_scene_requested(context: Dictionary) -> void:
	clear_content_area()
	var scene_to_use = REWARD_SCENE
	
	# Determine if this is an Elite/Boss reward
	var is_special = context.get("is_special_victory", false)
	
	if is_special:
		scene_to_use = REWARD_ELITE_SCENE
	
	var instance = scene_to_use.instantiate()
	if not is_instance_valid(instance):
		return
		
	_current_content_node = instance
	scene_slot.add_child(instance)
	
	_sync_scene_background(instance)
	
	# Snap visuals to model on screen transition
	call_deferred("sync_visual_machine_counts_with_model")
	
	if instance.has_method("populate"):
		instance.populate(context)
	_notify_scene_transition_complete(instance)

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
	_request_machine_draw(4, DrawDiscardAction.new())

func _on_draw_button_pressed(_button: BaseButton, tier: int) -> void:
	_request_machine_draw(tier, DrawGachaAction.new(tier))

func _request_machine_draw(tier: int, action: GameAction) -> void:
	var battle: BattleManager = GameManager.get_battle_manager() as BattleManager
	if battle == null or battle.is_animations_playing():
		return
	if not ActionQueue.request(action) and not ActionQueue.is_busy():
		RejectionFeedbackScript.play_rejection_with_counter(get_gacha_machine(tier), get_token_feedback_control(), get_tree())

func play_machine_draw(tier: int, cost: int) -> void:
	var button: BaseButton = get_knob_button(tier)
	var machine: Control = get_gacha_machine(tier)
	_is_drawing_token = true
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
	await CurrencyAnimator.animate_token_spend(cost, target, _on_coin_landed_on_machine.bind(machine))
	_is_drawing_token = false

func _on_coin_landed_on_machine(target_pos: Vector2, machine: Control) -> void:
	"""React when a coin lands on a gacha machine - bounce and flash"""
	if not is_instance_valid(machine):
		return
	
	# AUDIO HOOK: Token land on machine
	Audio.play_sfx("token_land")
	
	# Ensure we ignore unused warning for target_pos (for future particle effects)
	var _unused = target_pos
	
	_play_machine_bounce(machine)

### Public function to trigger machine bounce and update inventory counts visually
## Used when gachballs visually arrive at or depart from a machine
func animate_machine_inventory_change(tier: int, amount: int) -> void:
	_visual_machine_counts[tier] = max(0, _visual_machine_counts[tier] + amount)
	_update_machine_count_labels()
	
	var target_machine: Control = get_gacha_machine(tier)
	if is_instance_valid(target_machine):
		if amount > 0:
			play_machine_landing_bounce(target_machine)
		else:
			_play_machine_bounce(target_machine)

## Plays a subtle, purely vertical landing bounce on any machine (compression -> hop -> squish -> settle)
## Strictly vertical (scale.x = 1.0) so flush machines never overlap horizontally.
func play_machine_landing_bounce(machine: Control) -> void:
	assert(is_instance_valid(machine), "play_machine_landing_bounce: machine must be valid")
	machine.pivot_offset = Vector2(machine.size.x / 2.0, machine.size.y)
	if machine.has_meta("_landing_bounce_tween"):
		var old_tween = machine.get_meta("_landing_bounce_tween")
		if is_instance_valid(old_tween) and old_tween.is_valid():
			old_tween.kill()
	var tween = machine.create_tween()
	machine.set_meta("_landing_bounce_tween", tween)
	# 1. Compress downwards upon impact
	tween.tween_property(machine, "scale", Vector2(1.0, 0.94), AnimationConstants.scaled(0.05)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 2. Hop upwards (rebound)
	tween.tween_property(machine, "scale", Vector2(1.0, 1.05), AnimationConstants.scaled(0.09)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 3. Land back down with a little squish
	tween.tween_property(machine, "scale", Vector2(1.0, 0.98), AnimationConstants.scaled(0.06)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# 4. Settle back to resting
	tween.tween_property(machine, "scale", Vector2.ONE, AnimationConstants.scaled(0.05)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func animate_machine_bump(machine: Control) -> void:
	play_machine_landing_bounce(machine)

func _play_machine_bounce(machine: Control) -> void:
	"""Internal function that plays the bounce and flash animation on a machine"""
	# Find the MachineImage child for the flash effect
	var machine_image = machine.get_node_or_null("MachineImage")
	if not is_instance_valid(machine_image):
		return
	
	# Set pivot for scaling from bottom center
	machine.pivot_offset = Vector2(machine.size.x / 2, machine.size.y)
	
	# Create juicy bounce and flash effect
	var reaction_tween = create_tween()
	reaction_tween.set_parallel(true)
	
	# Quick scale bounce - squash then stretch back purely vertically
	var b1 = AnimationConstants.scaled(0.04)
	var b2 = AnimationConstants.scaled(0.06)
	var b3 = AnimationConstants.scaled(0.08)
	reaction_tween.tween_property(machine, "scale", Vector2(1.0, 0.96), b1).set_trans(Tween.TRANS_SINE)
	reaction_tween.tween_property(machine, "scale", Vector2(1.0, 1.03), b2).set_delay(b1).set_trans(Tween.TRANS_SINE)
	reaction_tween.tween_property(machine, "scale", Vector2(1.0, 1.0), b3).set_delay(b1 + b2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Flash bright on the machine image
	var flash_color = Color(1.3, 1.25, 1.1, 1.0) # Warm bright flash
	var f1 = AnimationConstants.scaled(0.03)
	var f2 = AnimationConstants.scaled(0.12)
	reaction_tween.tween_property(machine_image, "modulate", flash_color, f1)
	reaction_tween.tween_property(machine_image, "modulate", Color.WHITE, f2).set_delay(f1)

func _on_battle_inventory_changed() -> void:
	_update_machine_costs()
	# TDD Safeguard: Re-enable buttons after the state has been updated.
	knob_button_1.disabled = false
	knob_button_2.disabled = false
	knob_button_3.disabled = false
	if is_instance_valid(knob_button_discard):
		knob_button_discard.disabled = false
	
	# Check for combat phase lock
	var bm = get_tree().get_first_node_in_group("battle_manager")
	if is_instance_valid(bm):
		if bm.get("Phases") and bm.get_current_phase() == bm.Phases.COMBAT:
			return

	# Refresh player trinkets as they might have changed (e.g. in Test Mode)
	_populate_player_trinkets()
	_update_bonus_timer_display()

func _on_battle_state_changed(is_in_battle: bool) -> void:
	# The gacha machines are always visible in the permanent HUD.
	# Only disable the knob buttons when not in battle (can't draw outside battle).
	if is_instance_valid(knob_button_1):
		knob_button_1.disabled = not is_in_battle
	if is_instance_valid(knob_button_2):
		knob_button_2.disabled = not is_in_battle
	if is_instance_valid(knob_button_3):
		knob_button_3.disabled = not is_in_battle
	if is_instance_valid(knob_button_discard):
		knob_button_discard.disabled = not is_in_battle
	_update_bonus_timer_display()
	
	# Speed controls: in battle all controls are shown; out of battle only the pause/menu button
	if is_instance_valid(speed_1x_btn): speed_1x_btn.visible = is_in_battle
	if is_instance_valid(speed_2x_btn): speed_2x_btn.visible = is_in_battle
	if is_instance_valid(speed_4x_btn): speed_4x_btn.visible = is_in_battle
	if is_instance_valid(pause_btn): pause_btn.visible = true
	
	if is_in_battle:
		# Entering battle - snap visual counters to model state
		call_deferred("sync_visual_machine_counts_with_model")
		var bm = GameManager.get_battle_manager()
		if is_instance_valid(bm):
			set_visual_tokens(bm.get_gacha_tokens(), false)
		_update_speed_button_styles(AnimationConstants.speed_factor)
	else:
		_update_speed_button_styles(AnimationConstants.speed_factor)

func _on_speed_button_pressed(speed: float) -> void:
	if WindowManager.is_options_window_open():
		WindowManager.close_options_window()
	var action := SetCombatSpeedAction.new(speed)
	if is_instance_valid(ActionQueue):
		ActionQueue.request(action)
	else:
		AnimationConstants.speed_factor = speed
		_update_speed_button_styles(speed)

func _on_pause_menu_button_pressed() -> void:
	WindowManager.toggle_options_window()

func _on_combat_speed_changed(speed: float) -> void:
	_update_speed_button_styles(speed)

func _on_combat_pause_changed(is_paused: bool) -> void:
	if is_paused:
		_update_speed_button_styles(-1.0)
	else:
		_update_speed_button_styles(AnimationConstants.speed_factor)

func _setup_speed_button_hover(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	btn.mouse_entered.connect(func():
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		btn.pivot_offset = btn.size / 2.0
		tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.1)
	)
	btn.mouse_exited.connect(func():
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	)

func _update_speed_button_styles(active_speed: float) -> void:
	var buttons = [
		{"btn": speed_1x_btn, "speed": 1.0},
		{"btn": speed_2x_btn, "speed": 2.0},
		{"btn": speed_4x_btn, "speed": 4.0},
		{"btn": pause_btn, "speed": -1.0}
	]
	var in_battle: bool = GameManager.is_in_battle if is_instance_valid(GameManager) else false
	for entry in buttons:
		var btn: Button = entry["btn"]
		if not is_instance_valid(btn):
			continue
		var target_speed: float = entry["speed"]
		var is_active: bool = is_equal_approx(target_speed, active_speed)
		if is_active and in_battle:
			btn.self_modulate = Color(0.35, 0.75, 1.0) # Active cyan/blue highlight
		elif target_speed == -1.0 and not in_battle:
			btn.self_modulate = Color(0.9, 0.9, 0.95) # Neutral pause/menu out of battle
		else:
			btn.self_modulate = Color(0.68, 0.7, 0.76) # Inactive clean

func _on_battle_phase_changed(phase_name: StringName) -> void:

	# If we just exited COMBAT, we must redraw the trinkets to reflect the final state
	if phase_name != &"COMBAT":
		_populate_player_trinkets()

func get_visual_gold() -> int:
	return _visual_gold

func get_visual_tokens() -> int:
	return _visual_tokens

func set_visual_gold(new_amount: int, animate_pop: bool = true) -> void:
	var old_amount = _visual_gold
	_visual_gold = new_amount
	if is_instance_valid(gold_label):
		gold_label.text = "%d" % _visual_gold
		if old_amount != _visual_gold and animate_pop:
			_animate_gold_counter_pop()

func modify_visual_gold(delta: int, animate_pop: bool = true) -> void:
	set_visual_gold(maxi(0, _visual_gold + delta), animate_pop)

func set_visual_tokens(new_amount: int, animate_pop: bool = true) -> void:
	var old_amount = _visual_tokens
	_visual_tokens = new_amount
	if _battle_token_tray != null:
		_battle_token_tray.set_balance(new_amount)
	if is_instance_valid(tokens_label):
		tokens_label.text = "%d" % _visual_tokens
		if old_amount != _visual_tokens and animate_pop:
			_animate_token_counter_pop()

func modify_visual_tokens(delta: int, animate_pop: bool = true) -> void:
	set_visual_tokens(maxi(0, _visual_tokens + delta), animate_pop)

func begin_gold_animation() -> void:
	_gold_animations_in_flight += 1

func end_gold_animation() -> void:
	_gold_animations_in_flight = maxi(0, _gold_animations_in_flight - 1)
	if _gold_animations_in_flight == 0 and is_instance_valid(GameManager) and is_instance_valid(GameManager.run_state):
		assert(_visual_gold == GameManager.run_state.gold, "HUD visual gold (%d) desynced from authoritative gold (%d)!" % [_visual_gold, GameManager.run_state.gold])

func begin_token_animation() -> void:
	_token_animations_in_flight += 1

func end_token_animation() -> void:
	_token_animations_in_flight = maxi(0, _token_animations_in_flight - 1)
	if _token_animations_in_flight == 0 and is_instance_valid(GameManager) and is_instance_valid(GameManager.run_state):
		var auth_tokens = GameManager.run_state.get_room_tokens()
		assert(_visual_tokens == auth_tokens, "HUD visual tokens (%d) desynced from authoritative tokens (%d)!" % [_visual_tokens, auth_tokens])

func get_visual_bonus_timer() -> float:
	return _visual_bonus_timer

func set_visual_bonus_timer(new_amount: float, animate_pop: bool = true) -> void:
	var old_amount = _visual_bonus_timer
	_visual_bonus_timer = new_amount
	if not is_instance_valid(bonus_timer_group):
		bonus_timer_group = get_node_or_null("%BonusTimerGroup")
	if not is_instance_valid(bonus_timer_label):
		bonus_timer_label = get_node_or_null("%BonusTimerLabel")
	if is_instance_valid(bonus_timer_group):
		bonus_timer_group.visible = (_visual_bonus_timer > 0.0)
		bonus_timer_group.modulate.a = 1.0
	if is_instance_valid(bonus_timer_label):
		if is_equal_approx(_visual_bonus_timer, roundf(_visual_bonus_timer)):
			bonus_timer_label.text = "+%ds" % int(roundf(_visual_bonus_timer))
		else:
			bonus_timer_label.text = "+%.1fs" % _visual_bonus_timer
		if not is_equal_approx(old_amount, _visual_bonus_timer) and animate_pop:
			_animate_bonus_timer_pop()

func modify_visual_bonus_timer(delta: float, animate_pop: bool = true) -> void:
	set_visual_bonus_timer(maxf(0.0, _visual_bonus_timer + delta), animate_pop)

func begin_bonus_timer_animation() -> void:
	_bonus_timer_animations_in_flight += 1
	if not is_instance_valid(bonus_timer_group):
		bonus_timer_group = get_node_or_null("%BonusTimerGroup")
	if is_instance_valid(bonus_timer_group) and not bonus_timer_group.visible:
		bonus_timer_group.visible = true
		bonus_timer_group.modulate.a = 0.0

func end_bonus_timer_animation() -> void:
	_bonus_timer_animations_in_flight = maxi(0, _bonus_timer_animations_in_flight - 1)
	if _bonus_timer_animations_in_flight == 0:
		_update_bonus_timer_display()

func _animate_bonus_timer_pop() -> void:
	if not is_instance_valid(bonus_timer_label):
		bonus_timer_label = get_node_or_null("%BonusTimerLabel")
	if not is_instance_valid(bonus_timer_group):
		bonus_timer_group = get_node_or_null("%BonusTimerGroup")
	if not is_instance_valid(bonus_timer_label) or not is_instance_valid(bonus_timer_group):
		return
	
	if bonus_timer_label.has_meta("_pop_tween"):
		var existing_tween = bonus_timer_label.get_meta("_pop_tween")
		if existing_tween is Tween and existing_tween.is_valid():
			existing_tween.kill()
	
	bonus_timer_group.pivot_offset = bonus_timer_group.size / 2.0
	var pop_tween = create_tween()
	bonus_timer_label.set_meta("_pop_tween", pop_tween)
	pop_tween.set_parallel(true)
	
	pop_tween.tween_property(bonus_timer_group, "scale", Vector2(1.4, 1.4), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(bonus_timer_group, "scale", Vector2(1.0, 1.0), 0.15).set_delay(0.1).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	var flash_color = Color(1.0, 0.9, 0.3, 1.0)
	pop_tween.tween_property(bonus_timer_label, "modulate", flash_color, 0.05)
	pop_tween.tween_property(bonus_timer_label, "modulate", Color.WHITE, 0.2).set_delay(0.05)

func _on_gold_changed(new_amount: int) -> void:
	if _gold_animations_in_flight > 0 or (is_instance_valid(ActionQueue) and ActionQueue.is_busy()):
		return
	set_visual_gold(new_amount, true)

func set_gold_display(new_amount: int, animate_pop: bool = true) -> void:
	set_visual_gold(new_amount, animate_pop)

func _animate_gold_counter_pop() -> void:
	"""Juicy pop animation for the gold counter when it updates"""
	if not is_instance_valid(gold_label):
		return
	
	# Kill any existing tween on this label
	if gold_label.has_meta("_pop_tween"):
		var existing_tween = gold_label.get_meta("_pop_tween")
		if existing_tween is Tween and existing_tween.is_valid():
			existing_tween.kill()
	
	# Get gold group for scaling
	var gold_group = gold_label.get_parent()
	if not is_instance_valid(gold_group):
		return
	
	# Set pivot to center for proper scaling
	gold_group.pivot_offset = gold_group.size / 2
	
	# Create juicy pop tween
	var pop_tween = create_tween()
	gold_label.set_meta("_pop_tween", pop_tween)
	
	pop_tween.set_parallel(true)
	
	# Scale: pop big then bounce back
	pop_tween.tween_property(gold_group, "scale", Vector2(1.4, 1.4), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(gold_group, "scale", Vector2(1.0, 1.0), 0.15).set_delay(0.1).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Color flash - gold color
	var flash_color = Color(1.0, 0.85, 0.3, 1.0) # Gold flash
	pop_tween.tween_property(gold_label, "modulate", flash_color, 0.05)
	pop_tween.tween_property(gold_label, "modulate", Color.WHITE, 0.2).set_delay(0.05)

func _on_gacha_tokens_changed(new_amount: int) -> void:
	if _token_animations_in_flight > 0 or (is_instance_valid(ActionQueue) and ActionQueue.is_busy()):
		return
	set_visual_tokens(new_amount, true)

func _on_action_queue_idle() -> void:
	sync_visual_machine_counts_with_model()
	if _gold_animations_in_flight == 0 and is_instance_valid(GameManager) and is_instance_valid(GameManager.run_state):
		set_visual_gold(GameManager.run_state.gold, false)
	if _token_animations_in_flight == 0 and is_instance_valid(GameManager) and is_instance_valid(GameManager.run_state):
		set_visual_tokens(GameManager.run_state.get_room_tokens(), false)
	if _bonus_timer_animations_in_flight == 0:
		_update_bonus_timer_display()

func set_token_display(new_amount: int, animate_pop: bool = true) -> void:
	set_visual_tokens(new_amount, animate_pop)

func _animate_token_counter_pop() -> void:
	"""Juicy pop animation for the token counter when it updates"""
	if not is_instance_valid(tokens_label):
		return
	
	# Kill any existing tween on this label
	if tokens_label.has_meta("_pop_tween"):
		var existing_tween = tokens_label.get_meta("_pop_tween")
		if existing_tween is Tween and existing_tween.is_valid():
			existing_tween.kill()
	
	# Store original values
	var token_group = tokens_label.get_parent()
	if not is_instance_valid(token_group):
		return
	
	# Set pivot to center for proper scaling
	token_group.pivot_offset = token_group.size / 2
	
	# Create juicy pop tween
	var pop_tween = create_tween()
	tokens_label.set_meta("_pop_tween", pop_tween)
	
	# Flash colors - ensure we have valid colors
	var original_color = Color.WHITE
	if tokens_label.has_theme_color_override("font_color"):
		original_color = tokens_label.get_theme_color("font_color")
	var flash_color = Color(1.0, 0.9, 0.2, 1.0) # Bright gold
	
	# Set initial color override if not already set
	tokens_label.add_theme_color_override("font_color", original_color)
	
	pop_tween.set_parallel(true)
	
	# Scale: pop big then bounce back
	pop_tween.tween_property(token_group, "scale", Vector2(1.4, 1.4), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(token_group, "scale", Vector2(1.0, 1.0), 0.15).set_delay(0.1).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Color flash - use modulate instead which is guaranteed to work
	pop_tween.tween_property(tokens_label, "modulate", flash_color, 0.05)
	pop_tween.tween_property(tokens_label, "modulate", Color.WHITE, 0.2).set_delay(0.05)

func _on_shop_scene_requested(context: Dictionary) -> void:
	clear_content_area()
	var instance = SHOP_SCENE.instantiate()
	_current_content_node = instance
	scene_slot.add_child(instance)
	
	# Sync background texture to full-screen SceneBackground
	_sync_scene_background(instance)
	
	# Snap visuals to model on screen transition
	call_deferred("sync_visual_machine_counts_with_model")
	
	if instance.has_method("populate"):
		instance.populate(context)
	_notify_scene_transition_complete(instance)

func _update_day_label(day: int) -> void:
	if is_instance_valid(days_label):
		days_label.text = tr("ui.day") % day

func _on_run_data_changed() -> void:
	if is_instance_valid(GameManager.run_state):
		_update_day_label(GameManager.run_state.day)
		_on_gold_changed(GameManager.run_state.gold)
		_populate_player_trinkets()
		_populate_flashcard_progress()
		_update_bonus_timer_display()

func _on_minigame_bonus_time_changed(new_bonus_time: float) -> void:
	if _bonus_timer_animations_in_flight > 0 or ActionQueue.is_busy():
		return
	_update_bonus_timer_display(new_bonus_time)

func _update_bonus_timer_display(override_bonus: float = -1.0) -> void:
	if not is_instance_valid(bonus_timer_group):
		bonus_timer_group = get_node_or_null("%BonusTimerGroup")
	if not is_instance_valid(bonus_timer_label):
		bonus_timer_label = get_node_or_null("%BonusTimerLabel")

	var bonus_time: float = 0.0
	if GameManager.is_in_battle:
		if override_bonus >= 0.0:
			bonus_time = override_bonus
		else:
			var bm = GameManager.get_battle_manager()
			if is_instance_valid(bm):
				bonus_time = bm.get_total_next_minigame_bonus_time()

	_visual_bonus_timer = bonus_time
	if is_instance_valid(bonus_timer_group):
		bonus_timer_group.visible = (bonus_time > 0.0)
		bonus_timer_group.modulate.a = 1.0
	if is_instance_valid(bonus_timer_label):
		if is_equal_approx(bonus_time, roundf(bonus_time)):
			bonus_timer_label.text = "+%ds" % int(roundf(bonus_time))
		else:
			bonus_timer_label.text = "+%.1fs" % bonus_time

func _populate_player_trinkets() -> void:
	if not is_instance_valid(player_trinket_bar):
		return
	var trinket_container = GameManager.run_state.get_container(RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS) if is_instance_valid(GameManager.run_state) else null
	var slots = player_trinket_bar.get_children()
	for i in range(slots.size()):
		var slot_view = slots[i]
		if not is_instance_valid(slot_view):
			continue
		for child in slot_view.get_children():
			# Skip indicator (z_index 10) and slot background (z_index -1)
			if child is TextureRect and (child.z_index == 10 or child.z_index == -1):
				continue
			child.queue_free()
		# Keep top-HUD trinkets in their compact inspection size so a full second row fits cleanly.
		if slot_view.has_method("set_size_scale"):
			slot_view.set_size_scale(1.0)
		var loc = LocationIdentifier.new()
		loc.container = RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS
		loc.index = i
		if slot_view.has_method("populate"):
			slot_view.populate(loc)
			if slot_view.has_method("set_interaction_context"):
				slot_view.set_interaction_context(&"INSPECTION_ONLY", 0)
		var instance = GameManager.get_instance_from_location(loc) if is_instance_valid(trinket_container) else null
		if is_instance_valid(instance):
			var visual_data = VisualDataAdapter.create_visual_data(instance)
			slot_view.set_content(visual_data, true, false)
			if slot_view.get_child_count() > 0:
				var view = slot_view.get_child(0)
				if view is GachaBallView and view.has_method("set_interaction_context"):
					view.set_interaction_context(&"INSPECTION_ONLY", &"TRINKET", 0)
		else:
			slot_view.set_content({})

func show_empty_trinket_slots() -> void:
	if not is_instance_valid(player_trinket_bar):
		return
	for slot in player_trinket_bar.get_children():
		if slot is SlotView and slot.is_trinket_slot:
			slot.show_empty_trinket_slot = true

func hide_empty_trinket_slots() -> void:
	if not is_instance_valid(player_trinket_bar):
		return
	for slot in player_trinket_bar.get_children():
		if slot is SlotView and slot.is_trinket_slot:
			slot.show_empty_trinket_slot = false

func _populate_flashcard_progress() -> void:
	flashcard_progress_bar.populate(GameManager.run_state)

func _start_battle_with_encounter(encounter_def: EncounterDefinition) -> void:
	# Find the BattleManager in the loaded scene and start the battle
	var battle_manager = _current_content_node.get_node_or_null("BattleManager")
	if battle_manager and battle_manager.has_method("start_battle"):
		battle_manager.start_battle(encounter_def)
	else:
		pass

## Hard-sync visual counts to current model data (only during screen transitions or loading)
func sync_visual_machine_counts_with_model() -> void:
	var battle: BattleManager = GameManager.get_battle_manager() as BattleManager
	for tier: int in range(1, 4):
		var count: int = 0
		if battle != null:
			count = battle.get_inventory_tier_instances(tier).size()
		elif is_instance_valid(GameManager.run_state):
			count = GameManager.run_state.get_inventory_tier_instances(tier).size()
		
		_visual_machine_counts[tier] = count
	
	_update_machine_count_labels()
	_update_machine_costs()
	var discard_count: int = battle.get_discard_count() if battle != null else 0
	gacha_machine_discard.text = "x%d/%d" % [discard_count, C.BATTLE_DISCARD_CAP]

func _update_machine_count_labels() -> void:
	machine_1_count_label.text = "x%d/%d" % [_visual_machine_counts[1], C.RUN_INVENTORY_CAP]
	machine_2_count_label.text = "x%d/%d" % [_visual_machine_counts[2], C.RUN_INVENTORY_CAP]
	machine_3_count_label.text = "x%d/%d" % [_visual_machine_counts[3], C.RUN_INVENTORY_CAP]

func _build_machine_labels() -> void:
	for tier: int in range(1, 5):
		var machine: Control = get_gacha_machine(tier)
		var knob: BaseButton = get_knob_button(tier)
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
			var number := _machine_number_label(str(tier))
			badge.add_child(number)
			row.add_child(badge)
		var cost := HBoxContainer.new()
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var token := TextureRect.new()
		token.mouse_filter = Control.MOUSE_FILTER_IGNORE
		token.texture = token_icon.texture
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

func _machine_number_label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_outline_color", Color(0.09, 0.12, 0.16))
	label.add_theme_constant_override("outline_size", 4)
	return label

func _update_machine_costs() -> void:
	var battle: BattleManager = GameManager.get_battle_manager() as BattleManager
	for tier: int in range(1, 4):
		var cost: Label = _machine_costs[tier].get_child(1) as Label
		cost.text = str(battle.get_gacha_draw_cost(tier) if battle != null and GameManager.is_in_battle else tier)
	_machine_costs[4].visible = battle != null and GameManager.is_in_battle and battle.can_draw_from_discard()

func set_battle_token_tray(tray: Control) -> void:
	_battle_token_tray = tray
	tokens_label.visible = tray == null
	token_icon.visible = tray == null
	if tray != null:
		tray.set_balance(_visual_tokens)

func clear_battle_token_tray(tray: Control) -> void:
	if _battle_token_tray == tray:
		_battle_token_tray = null
		if not is_queued_for_deletion():
			set_battle_token_tray(null)

func get_token_feedback_control() -> Control:
	return _battle_token_tray.get_count_feedback_control() if _battle_token_tray != null else %TokenGroup

func get_token_animation_origin() -> Vector2:
	return _battle_token_tray.get_currency_origin() if _battle_token_tray != null else token_icon.get_global_rect().get_center()

# =============================================================================
# CONFIRM DROP ZONE OVERLAY
# =============================================================================

func _build_confirm_drop_zone() -> void:
	"""Programmatically create the warm white overlay that covers the bottom area."""
	_confirm_drop_zone = PanelContainer.new()
	_confirm_drop_zone.name = "ConfirmDropZone"
	_confirm_drop_zone.unique_name_in_owner = true
	
	# Match the bottom machine bar's current height and anchors.
	_confirm_drop_zone.layout_mode = 1 # Anchored
	_confirm_drop_zone.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_confirm_drop_zone.custom_minimum_size = Vector2(0, bottom_area.size.y)
	_confirm_drop_zone.offset_top = -bottom_area.size.y
	_confirm_drop_zone.offset_bottom = 0
	
	# Warm white rounded rectangle style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.96, 0.93, 0.95) # Warm white, slight transparency
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	_confirm_drop_zone.add_theme_stylebox_override("panel", style)
	
	# Must capture mouse clicks
	_confirm_drop_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Center the label inside
	var center = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_drop_zone.add_child(center)
	
	_confirm_drop_zone_label = RichTextLabel.new()
	_confirm_drop_zone_label.bbcode_enabled = true
	_confirm_drop_zone_label.fit_content = true
	_confirm_drop_zone_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_confirm_drop_zone_label.custom_minimum_size = Vector2(800, 0)
	_confirm_drop_zone_label.add_theme_color_override("default_color", Color(0.35, 0.35, 0.32, 0.85))
	_confirm_drop_zone_label.add_theme_color_override("font_outline_color", Color(0.15, 0.17, 0.22, 0.3))
	_confirm_drop_zone_label.add_theme_constant_override("outline_size", 2)
	_confirm_drop_zone_label.add_theme_font_size_override("normal_font_size", 42)
	_confirm_drop_zone_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_confirm_drop_zone_label)
	
	# Add to HUDContainer, AFTER BottomArea so it renders on top
	var hud_container = bottom_area.get_parent()
	if is_instance_valid(hud_container):
		hud_container.add_child(_confirm_drop_zone)
		# Ensure it's above BottomArea in z-order
		_confirm_drop_zone.z_index = 5
	
	# Connect click handler
	_confirm_drop_zone.gui_input.connect(_on_confirm_drop_zone_gui_input)
	
	# Start hidden
	_confirm_drop_zone.set_script(load("res://scripts/utils/DropZone.gd"))
	_confirm_drop_zone.visible = false
	_confirm_drop_zone.modulate.a = 0.0

func show_confirm_drop_zone(mode: StringName) -> void:
	"""Show the confirm drop zone overlay with the appropriate text.
	mode should be &'Rewards' or &'Shop'."""
	if not is_instance_valid(_confirm_drop_zone):
		return
	_confirm_drop_zone_mode = mode
	
	# Set label text based on mode
	if mode == &"Rewards":
		_confirm_drop_zone_label.text = "[center]" + tr("ui.drop_zone_get_multi") + "[/center]"
	elif mode == &"Shop":
		_confirm_drop_zone_label.text = "[center]" + tr("ui.drop_zone_buy_multi") + "[/center]"
	else:
		_confirm_drop_zone_label.text = "[center]" + tr("ui.confirm") + "[/center]"
	
	if _confirm_drop_zone_visible:
		return # Already showing
	_confirm_drop_zone_visible = true
	_confirm_drop_zone.visible = true
	
	# Fade in animation
	var tween = create_tween()
	tween.tween_property(_confirm_drop_zone, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func hide_confirm_drop_zone() -> void:
	"""Hide the confirm drop zone overlay."""
	if not is_instance_valid(_confirm_drop_zone):
		return
	if not _confirm_drop_zone_visible:
		return
	_confirm_drop_zone_visible = false
	_confirm_drop_zone_mode = &""
	
	# Fade out animation
	var tween = create_tween()
	tween.tween_property(_confirm_drop_zone, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		if is_instance_valid(_confirm_drop_zone):
			_confirm_drop_zone.visible = false
	)

func _on_confirm_drop_zone_gui_input(event: InputEvent) -> void:
	"""Handle click on the confirm drop zone overlay."""
	if InputUtils.is_primary_pointer_press(event):
		# Gating: if we are currently dragging, ignore the raw gui_input press.
		if _drop_zone_drag_context != null:
			return
		if _confirm_drop_zone_mode != &"":
			SignalBus.emit_signal("confirm_drop_zone_activated", false, Vector2.ZERO)
			# Play confirm sound
			Audio.play_sfx("ui_click")
		get_viewport().set_input_as_handled()

func _on_selection_changed_for_drop_zone(new_location: LocationIdentifier) -> void:
	"""Show/hide drop zones based on current context and selection."""
	# Handle Reward/Shop
	if new_location and new_location.container == &"Rewards":
		show_reward_drop_zones()
		# Hide instruction if visible (transition to action zones)
		if _action_instruction_visible:
			_action_instruction_overlay.visible = false
			_action_instruction_visible = false
			_action_instruction_overlay.modulate.a = 0.0
	elif new_location and new_location.container == &"Shop":
		show_confirm_drop_zone(&"Shop")
	else:
		call_deferred("_deferred_maybe_hide_drop_zone")
	
	# Handle Shrine / Training Ground
	if _action_instruction_visible or _split_action_drop_zones_visible:
		var is_inventory_source = new_location and String(new_location.container).begins_with("RunInventoryT")
		
		# Validation: If we are in training mode (recognized by labels), only show for units
		var is_valid_for_training = true
		if _action_zone_1_text == tr("ui.utg_drop_hp"):
			var sel = GlobalInteractionRouter.get_current_selection()
			var sel_type: StringName = sel.entity_type if sel else &""
			if sel_type == &"" and is_instance_valid(new_location) and is_instance_valid(GameManager):
				var inst = GameManager.get_instance_from_location(new_location)
				if is_instance_valid(inst) and is_instance_valid(inst.get_definition()):
					sel_type = inst.get_definition().category
			if sel_type != &"UNIT":
				is_valid_for_training = false

		if is_inventory_source and is_valid_for_training and not MergeManager.is_merge_encounter_active():
			# "Upgrade" to action zones
			show_split_action_drop_zones()
			# Don't call hide_action_instruction yet, let the show method handle it or do it here
			_action_instruction_overlay.visible = false
			_action_instruction_visible = false
			_action_instruction_overlay.modulate.a = 0.0
		else:
			call_deferred("_deferred_maybe_hide_action_drop_zones")

func _deferred_maybe_hide_drop_zone() -> void:
	"""Hide drop zone if no relevant selection or drag is active."""
	if _confirm_drop_zone_mode == &"" and not _reward_drop_zones_visible:
		return
	var sel = GlobalInteractionRouter.get_current_selection()
	if sel and is_instance_valid(sel.location):
		if sel.location.container == &"Shop":
			return
	hide_confirm_drop_zone()
	if not (sel and is_instance_valid(sel.location) and sel.location.container == &"Rewards"):
		hide_reward_drop_zones()
		# Restore instruction if in Reward context
		var is_reward_context = false
		if is_instance_valid(_current_content_node):
			if _current_content_node.name.begins_with("Reward") or _current_content_node.is_in_group("reward_scene"):
				is_reward_context = true
				
		if is_reward_context and not WindowManager.is_run_inventory_window_open():
			show_action_instruction(tr("ui.reward_instruction"))

func _deferred_maybe_hide_action_drop_zones() -> void:
	"""Hide action drop zones and show instruction if no relevant selection or drag is active."""
	if not _split_action_drop_zones_visible:
		return
	
	# Only hide if no selection and no drag
	var sel = GlobalInteractionRouter.get_current_selection()
	if sel and is_instance_valid(sel.location) and String(sel.location.container).begins_with("RunInventoryT"):
		# If in training mode, still hide if not a unit
		var sel_type: StringName = sel.entity_type
		if sel_type == &"" and is_instance_valid(GameManager):
			var inst = GameManager.get_instance_from_location(sel.location)
			if is_instance_valid(inst) and is_instance_valid(inst.get_definition()):
				sel_type = inst.get_definition().category
		if _action_zone_1_text == tr("ui.utg_drop_hp") and sel_type != &"UNIT":
			pass # Continue to hide
		else:
			return
		
	if _action_drop_zone_drag_context != null:
		return
		
	hide_split_action_drop_zones()
	# "Downgrade" back to instruction overlay
	show_action_instruction()

func _on_drag_started_for_drop_zone(origin_context: InteractionContext) -> void:
	"""Show the drop zone when dragging from Reward/Shop. Save context for drop."""
	_drop_zone_drag_context = null
	_action_drop_zone_drag_context = null
	if origin_context and is_instance_valid(origin_context.location):
		if origin_context.location.container == &"Rewards":
			_drop_zone_drag_context = origin_context
			show_reward_drop_zones()
			# Hide instruction if visible
			if _action_instruction_visible:
				_action_instruction_overlay.visible = false
				_action_instruction_visible = false
				_action_instruction_overlay.modulate.a = 0.0
		elif origin_context.location.container == &"Shop":
			_drop_zone_drag_context = origin_context
			show_confirm_drop_zone(&"Shop")
		elif (_action_instruction_visible or _split_action_drop_zones_visible) and String(origin_context.location.container).begins_with("RunInventoryT") and not MergeManager.is_merge_encounter_active():
			# Dragging from inventory while Shrine context is active
			
			# Validation: If we are in training mode, only show for units
			if _action_zone_1_text == tr("ui.utg_drop_hp"):
				if origin_context.entity_type != &"UNIT":
					return
					
			_action_drop_zone_drag_context = origin_context
			show_split_action_drop_zones()
			# Instant hide instruction
			_action_instruction_overlay.visible = false
			_action_instruction_visible = false
			_action_instruction_overlay.modulate.a = 0.0

func _on_drag_ended_for_drop_zone(_was_handled: bool) -> void:
	"""Check if drag ended over any drop zone and trigger appropriate action."""
	var saved_ctx = _drop_zone_drag_context
	var saved_action_ctx = _action_drop_zone_drag_context
	_drop_zone_drag_context = null
	_action_drop_zone_drag_context = null
	
	# Check Shrine zones first (independent from confirm zone)
	if _check_action_drag_drop_on_zones_with_context(saved_action_ctx):
		return
	
	# Check Reward zones
	if _check_reward_drag_drop_on_zones_with_context(saved_ctx):
		return
	
	if _confirm_drop_zone_mode == &"":
		return
	
	# Check if pointer is over the drop zone rect
	if is_instance_valid(_confirm_drop_zone) and _confirm_drop_zone.visible:
		var pointer_pos: Vector2 = GlobalInteractionRouter.get_last_pointer_position() if is_instance_valid(GlobalInteractionRouter) else get_viewport().get_mouse_position()
		var zone_rect = _confirm_drop_zone.get_global_rect()
		if zone_rect.has_point(pointer_pos) and saved_ctx != null:
			# CRITICAL: GIR.end_drag() already cleared the selection before
			# this signal fired. Restore it so Reward/Shop confirm handlers
			# can find the selected item via get_current_selection().
			GlobalInteractionRouter.set_current_selection(saved_ctx)
			SignalBus.emit_signal("selection_changed", saved_ctx.location)
			
			# Drag ended over the drop zone — trigger confirm!
			SignalBus.emit_signal("confirm_drop_zone_activated", true, pointer_pos)
			Audio.play_sfx("ui_click")
			return
	
	# Drag ended elsewhere — hide the drop zone
	hide_confirm_drop_zone()
	
	# Also hide reward zones if no selection remains
	var sel = GlobalInteractionRouter.get_current_selection()
	if not (sel and is_instance_valid(sel.location) and sel.location.container == &"Rewards"):
		hide_reward_drop_zones()
		# Restore instruction if in Reward context
		var is_reward_context = false
		if is_instance_valid(_current_content_node):
			if _current_content_node.name.begins_with("Reward") or _current_content_node.is_in_group("reward_scene"):
				is_reward_context = true
				
		if is_reward_context and not WindowManager.is_run_inventory_window_open():
			show_action_instruction(tr("ui.reward_instruction"))


## Public API: Get the global rect of the drop zone (for external hit testing)
func get_confirm_drop_zone_rect() -> Rect2:
	if is_instance_valid(_confirm_drop_zone) and _confirm_drop_zone.visible:
		return _confirm_drop_zone.get_global_rect()
	return Rect2()

## Public API: Check if a given screen point is inside any active drop zone
func is_point_inside_active_drop_zone(pos: Vector2) -> bool:
	if is_instance_valid(_confirm_drop_zone) and _confirm_drop_zone.visible:
		if _confirm_drop_zone.get_global_rect().has_point(pos):
			return true
			
	if _reward_drop_zones_visible:
		if is_instance_valid(_reward_collect_zone) and _reward_collect_zone.get_global_rect().has_point(pos): return true
		if is_instance_valid(_reward_sell_zone) and _reward_sell_zone.get_global_rect().has_point(pos): return true
		
	if _split_action_drop_zones_visible:
		if is_instance_valid(_action_zone_1) and _action_zone_1.get_global_rect().has_point(pos): return true
		if is_instance_valid(_action_zone_2) and _action_zone_2.get_global_rect().has_point(pos): return true
		
	return false

# =============================================================================
# SHRINE SPLIT DROP ZONES (Remove / Transform)
# =============================================================================

func _build_split_action_drop_zones() -> void:
	"""Build two side-by-side drop zones for Shrine Remove and Transform."""
	_split_action_drop_zone_container = PanelContainer.new()
	_split_action_drop_zone_container.name = "ShrineDropZones"
	
	# Match the bottom machine bar's current height and anchors.
	_split_action_drop_zone_container.layout_mode = 1
	_split_action_drop_zone_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_split_action_drop_zone_container.custom_minimum_size = Vector2(0, bottom_area.size.y)
	_split_action_drop_zone_container.offset_top = -bottom_area.size.y
	_split_action_drop_zone_container.offset_bottom = 0
	
	# Transparent panel (children provide the visuals)
	var container_style = StyleBoxFlat.new()
	container_style.bg_color = Color(0, 0, 0, 0)
	_split_action_drop_zone_container.add_theme_stylebox_override("panel", container_style)
	_split_action_drop_zone_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# HBoxContainer to split into two halves
	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_split_action_drop_zone_container.add_child(hbox)
	
	# Left zone: Transform
	_action_zone_1 = _create_action_zone_panel(tr("ui.drop_zone_transform_multi"), Color(0.93, 0.96, 0.98, 0.95))
	_action_zone_1.name = "TransformZone"
	_action_label_1 = _action_zone_1.get_child(0).get_child(0) as RichTextLabel
	hbox.add_child(_action_zone_1)
	_action_zone_1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_zone_1.gui_input.connect(_on_action_zone_1_gui_input)
	
	# Right zone: Remove
	_action_zone_2 = _create_action_zone_panel(tr("ui.drop_zone_remove_multi"), Color(0.98, 0.93, 0.93, 0.95))
	_action_zone_2.name = "RemoveZone"
	_action_label_2 = _action_zone_2.get_child(0).get_child(0) as RichTextLabel
	hbox.add_child(_action_zone_2)
	_action_zone_2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_zone_2.gui_input.connect(_on_action_zone_2_gui_input)
	
	# Add to HUDContainer after BottomArea
	var hud_container = bottom_area.get_parent()
	if is_instance_valid(hud_container):
		hud_container.add_child(_split_action_drop_zone_container)
		_split_action_drop_zone_container.z_index = 5
	
	# Start hidden
	_split_action_drop_zone_container.visible = false
	_split_action_drop_zone_container.modulate.a = 0.0
	
	_build_action_instruction_overlay()

func _build_action_instruction_overlay() -> void:
	"""Build the dark background instruction overlay for Shrine."""
	_action_instruction_overlay = PanelContainer.new()
	_action_instruction_overlay.name = "ShrineInstruction"
	
	_action_instruction_overlay.layout_mode = 1
	_action_instruction_overlay.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_action_instruction_overlay.custom_minimum_size = Vector2(0, bottom_area.size.y)
	_action_instruction_overlay.offset_top = -bottom_area.size.y
	_action_instruction_overlay.offset_bottom = 0
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	_action_instruction_overlay.add_theme_stylebox_override("panel", style)
	
	# The user requested that this area lets clicks pass to close inventory just like 
	# if it wasn't there. Setting ignore ensures it doesn't block the scene content.
	_action_instruction_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var center = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_instruction_overlay.add_child(center)
	
	_action_instruction_label = Label.new()
	_action_instruction_label.text = tr("ui.shrine_instruction")
	_action_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_action_instruction_label.add_theme_font_size_override("font_size", 24)
	_action_instruction_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92, 0.8))
	_action_instruction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_action_instruction_label)
	
	# Add to HUDContainer
	var hud_container = bottom_area.get_parent()
	if is_instance_valid(hud_container):
		hud_container.add_child(_action_instruction_overlay)
		_action_instruction_overlay.z_index = 4 # Below drop zones (z=5)
	
	_action_instruction_overlay.visible = false
	_action_instruction_overlay.modulate.a = 0.0

func _update_programmatic_labels() -> void:
	"""Update all programmatically created labels with current localized text."""
	if is_instance_valid(_confirm_drop_zone_label):
		if _confirm_drop_zone_mode == &"Rewards":
			_confirm_drop_zone_label.text = "[center]" + tr("ui.drop_zone_get_multi") + "[/center]"
		elif _confirm_drop_zone_mode == &"Shop":
			_confirm_drop_zone_label.text = "[center]" + tr("ui.drop_zone_buy_multi") + "[/center]"
			
	if is_instance_valid(_action_label_1):
		_action_label_1.text = "[center]" + tr("ui.drop_zone_transform_multi") + "[/center]"
	if is_instance_valid(_action_label_2):
		_action_label_2.text = "[center]" + tr("ui.drop_zone_remove_multi") + "[/center]"
	if is_instance_valid(_action_instruction_label):
		_action_instruction_label.text = tr("ui.shrine_instruction")

func _create_action_zone_panel(text: String, bg_color: Color) -> PanelContainer:
	"""Create a single action zone panel with centered label."""
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_script(load("res://scripts/utils/DropZone.gd"))
	
	var center = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(center)
	
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size = Vector2(400, 0)
	label.text = "[center]" + text + "[/center]"
	label.add_theme_font_size_override("normal_font_size", 32)
	label.add_theme_color_override("default_color", Color(0.3, 0.3, 0.28, 0.85))
	label.add_theme_color_override("font_outline_color", Color(0.15, 0.17, 0.22, 0.3))
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(label)
	
	return panel

func show_split_action_drop_zones(left_text: String = "", right_text: String = "") -> void:
	# Fallback chain: 1. Argument, 2. Stored custom text (e.g. from UTG), 3. BM default
	var l_text = left_text
	if l_text == "": l_text = _action_zone_1_text
	if l_text == "": l_text = tr("ui.drop_zone_transform_multi")
	
	var r_text = right_text
	if r_text == "": r_text = _action_zone_2_text
	if r_text == "": r_text = tr("ui.drop_zone_remove_multi")
	
	if is_instance_valid(_action_label_1):
		_action_label_1.text = "[center]" + l_text + "[/center]"
	if is_instance_valid(_action_label_2):
		_action_label_2.text = "[center]" + r_text + "[/center]"

	"""Show the two-zone action overlay."""
	if not is_instance_valid(_split_action_drop_zone_container):
		return
	if _split_action_drop_zones_visible:
		return
	_split_action_drop_zones_visible = true
	_split_action_drop_zone_container.visible = true
	
	var tween = create_tween()
	tween.tween_property(_split_action_drop_zone_container, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Public API: Pre-register custom labels for the split action drop zones.
## Call this from content scenes (e.g., UnitTrainingGround) so that when Main.gd
## auto-upgrades the instruction to drop zones, it uses the correct text.
func set_action_zone_texts(left_text: String, right_text: String) -> void:
	_action_zone_1_text = left_text
	_action_zone_2_text = right_text

func hide_split_action_drop_zones() -> void:
	"""Hide the two-zone Shrine overlay."""
	if not is_instance_valid(_split_action_drop_zone_container):
		return
	if not _split_action_drop_zones_visible:
		return
	_split_action_drop_zones_visible = false
	
	var tween = create_tween()
	tween.tween_property(_split_action_drop_zone_container, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		if is_instance_valid(_split_action_drop_zone_container):
			_split_action_drop_zone_container.visible = false
	)

func show_action_instruction(text: String = "") -> void:
	if text != "":
		if is_instance_valid(_action_instruction_label):
			_action_instruction_label.text = text
	else:
		if is_instance_valid(_action_instruction_label):
			_action_instruction_label.text = tr("ui.shrine_instruction")

	"""Show the dark background instruction overlay for Shrine."""
	if not is_instance_valid(_action_instruction_overlay):
		return
	if _action_instruction_visible:
		return
	_action_instruction_visible = true
	_action_instruction_overlay.visible = true
	
	var tween = create_tween()
	tween.tween_property(_action_instruction_overlay, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func hide_action_instruction() -> void:
	"""Hide the dark background instruction overlay for Shrine."""
	if not is_instance_valid(_action_instruction_overlay):
		return
	if not _action_instruction_visible:
		return
	_action_instruction_visible = false
	
	var tween = create_tween()
	tween.tween_property(_action_instruction_overlay, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		if is_instance_valid(_action_instruction_overlay):
			_action_instruction_overlay.visible = false
	)

func _on_action_zone_2_gui_input(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		# Gating: ignore raw press if currently dragging
		if _action_drop_zone_drag_context != null:
			return
		SignalBus.emit_signal("action_drop_zone_2_activated", false, Vector2.ZERO)
		Audio.play_sfx("ui_click")
		get_viewport().set_input_as_handled()

func _on_action_zone_1_gui_input(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		# Gating: ignore raw press if currently dragging
		if _action_drop_zone_drag_context != null:
			return
		SignalBus.emit_signal("action_drop_zone_1_activated", false, Vector2.ZERO)
		Audio.play_sfx("ui_click")
		get_viewport().set_input_as_handled()

func _check_action_drag_drop_on_zones_with_context(context: InteractionContext) -> bool:
	"""Check if a drag ended over one of the BM zones. Returns true if handled."""
	if not _split_action_drop_zones_visible or not is_instance_valid(_split_action_drop_zone_container):
		return false
	if context == null:
		return false
	
	var pointer_pos: Vector2 = GlobalInteractionRouter.get_last_pointer_position() if is_instance_valid(GlobalInteractionRouter) else get_viewport().get_mouse_position()
	
	# Check Remove zone
	if is_instance_valid(_action_zone_2) and _action_zone_2.get_global_rect().has_point(pointer_pos):
		# Restore selection so handlers can find the item
		GlobalInteractionRouter.set_current_selection(context)
		SignalBus.emit_signal("selection_changed", context.location)
		SignalBus.emit_signal("action_drop_zone_2_activated", true, pointer_pos)
		Audio.play_sfx("ui_click")
		return true
	
	# Check Transform zone
	if is_instance_valid(_action_zone_1) and _action_zone_1.get_global_rect().has_point(pointer_pos):
		GlobalInteractionRouter.set_current_selection(context)
		SignalBus.emit_signal("selection_changed", context.location)
		SignalBus.emit_signal("action_drop_zone_1_activated", true, pointer_pos)
		Audio.play_sfx("ui_click")
		return true
	
	return false

## Public API: Get the BM Remove zone node (for rejection feedback)
func get_action_zone_2() -> Control:
	return _action_zone_2

## Public API: Get the BM Transform zone node (for rejection feedback)
func get_action_zone_1() -> Control:
	return _action_zone_1

# =============================================================================
# REWARD DROP ZONES
# =============================================================================

func _build_reward_drop_zones() -> void:
	_reward_drop_zone_container = PanelContainer.new()
	_reward_drop_zone_container.name = "RewardDropZones"
	
	_reward_drop_zone_container.layout_mode = 1
	_reward_drop_zone_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_reward_drop_zone_container.custom_minimum_size = Vector2(0, bottom_area.size.y)
	_reward_drop_zone_container.offset_top = -bottom_area.size.y
	_reward_drop_zone_container.offset_bottom = 0
	
	var container_style = StyleBoxFlat.new()
	container_style.bg_color = Color(0, 0, 0, 0)
	_reward_drop_zone_container.add_theme_stylebox_override("panel", container_style)
	_reward_drop_zone_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reward_drop_zone_container.add_child(hbox)
	
	_reward_collect_zone = _create_action_zone_panel(tr("Drag or click here to add it to your collection"), Color(0.93, 0.98, 0.93, 0.95))
	_reward_collect_zone.name = "CollectZone"
	_reward_collect_label = _reward_collect_zone.get_child(0).get_child(0) as RichTextLabel
	hbox.add_child(_reward_collect_zone)
	_reward_collect_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_collect_zone.gui_input.connect(_on_reward_collect_zone_gui_input)
	
	_reward_sell_zone = _create_action_zone_panel(tr("Drag or click here to sell it"), Color(0.98, 0.93, 0.93, 0.95))
	_reward_sell_zone.name = "SellZone"
	_reward_sell_label = _reward_sell_zone.get_child(0).get_child(0) as RichTextLabel
	hbox.add_child(_reward_sell_zone)
	_reward_sell_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_sell_zone.gui_input.connect(_on_reward_sell_zone_gui_input)
	
	var hud_container = bottom_area.get_parent()
	if is_instance_valid(hud_container):
		hud_container.add_child(_reward_drop_zone_container)
		_reward_drop_zone_container.z_index = 5
	
	_reward_drop_zone_container.visible = false
	_reward_drop_zone_container.modulate.a = 0.0

func _on_reward_collect_zone_gui_input(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_release(event) or InputUtils.is_primary_pointer_press(event):
		# If we are currently dragging, ignore the raw gui_input release.
		# The drag_ended signal will handle the activation with proper context.
		if _drop_zone_drag_context != null:
			return
		SignalBus.emit_signal("reward_collect_zone_activated", false, Vector2.ZERO)
		get_viewport().set_input_as_handled()

func _on_reward_sell_zone_gui_input(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_release(event) or InputUtils.is_primary_pointer_press(event):
		# If we are currently dragging, ignore the raw gui_input release.
		if _drop_zone_drag_context != null:
			return
		SignalBus.emit_signal("reward_sell_zone_activated", false, Vector2.ZERO)
		get_viewport().set_input_as_handled()

func show_reward_drop_zones() -> void:
	if not is_instance_valid(_reward_drop_zone_container): return
	if _reward_drop_zones_visible: return
	
	_reward_sell_zone.visible = true
	_reward_collect_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var get_text = tr("ui.drop_zone_get_multi")
	_reward_collect_label.text = "[center]" + get_text + "[/center]"
	
	var sell_text = tr("ui.drop_zone_sell_multi")
	_reward_sell_label.text = "[center]" + sell_text + "[/center]"
	
	_reward_drop_zones_visible = true
	_reward_drop_zone_container.visible = true
	var tween = create_tween()
	tween.tween_property(_reward_drop_zone_container, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func hide_reward_drop_zones() -> void:
	if not is_instance_valid(_reward_drop_zone_container): return
	if not _reward_drop_zones_visible: return
	_reward_drop_zones_visible = false
	var tween = create_tween()
	tween.tween_property(_reward_drop_zone_container, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		if is_instance_valid(_reward_drop_zone_container) and not _reward_drop_zones_visible:
			_reward_drop_zone_container.visible = false
	)

func _check_reward_drag_drop_on_zones_with_context(context: InteractionContext) -> bool:
	"""Check if a drag ended over one of the Reward zones. Returns true if handled."""
	if not _reward_drop_zones_visible or not is_instance_valid(_reward_drop_zone_container):
		return false
	if context == null:
		return false
	
	var pointer_pos: Vector2 = GlobalInteractionRouter.get_last_pointer_position() if is_instance_valid(GlobalInteractionRouter) else get_viewport().get_mouse_position()
	
	# Check Collect zone
	if is_instance_valid(_reward_collect_zone) and _reward_collect_zone.get_global_rect().has_point(pointer_pos):
		GlobalInteractionRouter.set_current_selection(context)
		SignalBus.emit_signal("selection_changed", context.location)
		SignalBus.emit_signal("reward_collect_zone_activated", true, pointer_pos)
		Audio.play_sfx("ui_click")
		return true
	
	# Check Sell zone
	if is_instance_valid(_reward_sell_zone) and _reward_sell_zone.visible and _reward_sell_zone.get_global_rect().has_point(pointer_pos):
		GlobalInteractionRouter.set_current_selection(context)
		SignalBus.emit_signal("selection_changed", context.location)
		SignalBus.emit_signal("reward_sell_zone_activated", true, pointer_pos)
		Audio.play_sfx("ui_click")
		return true
	
	return false
	
## Public API: Get the Reward Collect zone node
## Public API: Get a Gacha Machine node by tier
func get_gacha_machine(tier: int) -> Control:
	match tier:
		1: return gacha_machine_1
		2: return gacha_machine_2
		3: return gacha_machine_3
		4: return gacha_machine_discard
	return null

func get_discard_machine() -> Control:
	return gacha_machine_discard

func get_reward_collect_zone() -> Control:
	return _reward_collect_zone

## Public API: Get the Reward Sell zone node
func get_reward_sell_zone() -> Control:
	return _reward_sell_zone
