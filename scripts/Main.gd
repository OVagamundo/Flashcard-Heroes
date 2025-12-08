# res://scripts/Main.gd
extends Control

const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")

@onready var content_area: SubViewportContainer = %ContentArea

# Gacha machine containers
@onready var gacha_machine_1: Control = %GachaMachine1
@onready var gacha_machine_2: Control = %GachaMachine2
@onready var gacha_machine_3: Control = %GachaMachine3

# Knob buttons for drawing
@onready var knob_button_1: Button = %GachaMachine1.get_node("KnobButton")
@onready var knob_button_2: Button = %GachaMachine2.get_node("KnobButton")
@onready var knob_button_3: Button = %GachaMachine3.get_node("KnobButton")

@onready var gold_label: Label = %GoldLabel
@onready var days_label: Label = %DaysLabel
@onready var tokens_label: Label = %TokensLabel

@onready var player_trinket_bar: HBoxContainer = %PlayerTrinketBar

const PATH_CHOICE_SCENE = preload("res://scenes/PathChoice.tscn")
const BATTLE_SCENE = preload("res://scenes/Battle.tscn")
const REWARD_SCENE = preload("res://scenes/Reward.tscn")

const SHOP_SCENE = preload("res://scenes/Shop.tscn")
const EncounterDefinition = preload("res://scripts/EncounterDefinition.gd")

var _current_content_node: Node = null

func _ready() -> void:
	GameManager.register_main_node(self) # Register self with GameManager
	
	# Connect knob buttons to draw functionality
	knob_button_1.pressed.connect(func(): _on_draw_button_pressed(knob_button_1, 1))
	knob_button_2.pressed.connect(func(): _on_draw_button_pressed(knob_button_2, 2))
	knob_button_3.pressed.connect(func(): _on_draw_button_pressed(knob_button_3, 3))
	
	# Connect hover animations for knob buttons
	knob_button_1.mouse_entered.connect(func(): _on_knob_hover_enter(knob_button_1))
	knob_button_1.mouse_exited.connect(func(): _on_knob_hover_exit(knob_button_1))
	knob_button_2.mouse_entered.connect(func(): _on_knob_hover_enter(knob_button_2))
	knob_button_2.mouse_exited.connect(func(): _on_knob_hover_exit(knob_button_2))
	knob_button_3.mouse_entered.connect(func(): _on_knob_hover_enter(knob_button_3))
	knob_button_3.mouse_exited.connect(func(): _on_knob_hover_exit(knob_button_3))
	
	# Connect machine containers to open inventory when clicked (outside knob button)
	gacha_machine_1.gui_input.connect(func(event): _on_machine_gui_input(event))
	gacha_machine_2.gui_input.connect(func(event): _on_machine_gui_input(event))
	gacha_machine_3.gui_input.connect(func(event): _on_machine_gui_input(event))

	
	SignalBus.battle_start_requested.connect(_on_battle_start_requested)
	SignalBus.path_choice_scene_requested.connect(_on_path_choice_scene_requested)
	SignalBus.battle_state_changed.connect(_on_battle_state_changed)
	SignalBus.reward_scene_requested.connect(_on_reward_scene_requested)
	# TDD Safeguard: Re-enable draw buttons after the UI has redrawn.
	SignalBus.battle_inventory_changed.connect(_on_battle_inventory_changed)
	content_area.gui_input.connect(_on_content_area_gui_input)

	SignalBus.gold_changed.connect(_on_gold_changed)
	SignalBus.gacha_tokens_changed.connect(_on_gacha_tokens_changed)
	SignalBus.shop_scene_requested.connect(_on_shop_scene_requested)
	SignalBus.run_data_changed.connect(_on_run_data_changed)
	SignalBus.battle_phase_changed.connect(_on_battle_phase_changed)


	_on_battle_state_changed(false)

	SignalBus.emit_signal("path_choice_scene_requested")

	if is_instance_valid(GameManager.run_state):
		_on_gold_changed(GameManager.run_state.gold)
		_update_day_label(GameManager.run_state.day)
		_populate_player_trinkets()

func _exit_tree() -> void:
	GameManager.unregister_main_node()

func _on_content_area_gui_input(event: InputEvent) -> void:
	# Handle background clicks and drag end on the main game area
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			# Create and emit InteractionContext for main game background
			var context = InteractionContext.new()
			context.source_view_instance_id = get_instance_id()
			context.event_type = &"SINGLE_CLICK"
			context.location = null # No specific location for background
			context.entity_uuid = ""
			context.entity_type = &"GLOBAL_BACKGROUND"
			context.interaction_mode = &"FULLY_INTERACTIVE"
			context.window_group_id = 0 # Main game area
			SignalBus.emit_signal("interaction_context_received", context)
		elif GlobalInteractionRouter.is_drag_active() and not event.is_pressed():
			# Do NOT forcibly end drag on background release here; drop targets manage drag end.
			# This was canceling drag before GIR processed battle board drop targets.
			pass

func _on_machine_gui_input(event: InputEvent) -> void:
	# Handle clicks on machine image area (outside the knob button)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Check if any windows are open
		if WindowManager.is_any_inspection_window_open():
			# Close all open windows - this is the "click outside window" behavior
			WindowManager.close_all_inspection_windows()
			# Don't open inventory - the close action was the intent
		else:
			# No windows open - open inventory
			SignalBus.emit_signal("inspect_inventory_requested")

func _on_knob_hover_enter(button: Button) -> void:
	if button.disabled:
		return
	# Grow the button slightly with a smooth animation
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	button.pivot_offset = button.size / 2
	tween.tween_property(button, "scale", Vector2(1.08, 1.08), 0.15)

func _on_knob_hover_exit(button: Button) -> void:
	# Return to normal size
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)

func _clear_content_area() -> void:
	if is_instance_valid(_current_content_node):
		_current_content_node.queue_free()
	_current_content_node = null

func _load_content(scene_resource: PackedScene) -> void:
	_clear_content_area()
	var instance = scene_resource.instantiate()
	_current_content_node = instance
	content_area.get_node("SubViewport").add_child(instance)

func _on_battle_start_requested(encounter_def: EncounterDefinition) -> void:
	_load_content(BATTLE_SCENE)
	# Use call_deferred to ensure the BattleManager is ready before calling it
	call_deferred("_start_battle_with_encounter", encounter_def)

func _on_path_choice_scene_requested() -> void:
	_load_content(PATH_CHOICE_SCENE)
	if is_instance_valid(GameManager.run_state):
		_update_day_label(GameManager.run_state.day)

	
func _on_reward_scene_requested(context: Dictionary) -> void:
	_clear_content_area()
	var instance = REWARD_SCENE.instantiate()
	_current_content_node = instance
	# Correctly parent the new scene inside the MarginContainer
	content_area.get_node("SubViewport/MarginContainer").add_child(instance)
	
	if instance.has_method("populate"):
		instance.populate(context)


func _on_draw_button_pressed(button: BaseButton, tier: int) -> void:
	# TDD Safeguard: Disable button immediately on press.
	button.disabled = true
	# Ensure UI focus doesn't interfere
	button.release_focus()
	# Route a background interaction through GIR so any open inspection windows close
	var context = InteractionContext.new()
	context.source_view_instance_id = button.get_instance_id()
	context.event_type = &"SINGLE_CLICK"
	context.location = null
	context.entity_uuid = ""
	context.entity_type = &"GLOBAL_BACKGROUND"
	context.interaction_mode = &"FULLY_INTERACTIVE"
	context.window_group_id = 0
	SignalBus.emit_signal("interaction_context_received", context)
	# Proceed with the draw
	SignalBus.emit_signal("draw_gacha_requested", tier)

func _on_battle_inventory_changed() -> void:
	# TDD Safeguard: Re-enable buttons after the state has been updated.
	knob_button_1.disabled = false
	knob_button_2.disabled = false
	knob_button_3.disabled = false
	
	# Check for combat phase lock
	var bm = get_tree().get_first_node_in_group("battle_manager")
	if is_instance_valid(bm):
		if bm.get("Phases") and bm.get_current_phase() == bm.Phases.COMBAT:
			return

	# Refresh player trinkets as they might have changed (e.g. in Test Mode)
	_populate_player_trinkets()

func _on_battle_state_changed(is_in_battle: bool) -> void:
	# The gacha machines are always visible in the permanent HUD.
	# Only disable the knob buttons when not in battle (can't draw outside battle).
	knob_button_1.disabled = not is_in_battle
	knob_button_2.disabled = not is_in_battle
	knob_button_3.disabled = not is_in_battle

func _on_battle_phase_changed(phase_name: StringName) -> void:
	# If we just exited COMBAT, we must redraw the trinkets to reflect the final state
	if phase_name != &"COMBAT":
		_populate_player_trinkets()

func _on_gold_changed(new_amount: int) -> void:
	if is_instance_valid(gold_label):
		gold_label.text = "%d" % new_amount

func _on_gacha_tokens_changed(new_amount: int) -> void:
	if is_instance_valid(tokens_label):
		tokens_label.text = "%d" % new_amount
	else:
		pass

func _on_shop_scene_requested(context: Dictionary) -> void:
	_clear_content_area()
	var instance = SHOP_SCENE.instantiate()
	_current_content_node = instance
	content_area.get_node("SubViewport/MarginContainer").add_child(instance)
	
	if instance.has_method("populate"):
		instance.populate(context)

func _update_day_label(day: int) -> void:
	if is_instance_valid(days_label):
		days_label.text = "Day %d" % day

func _on_run_data_changed() -> void:
	if is_instance_valid(GameManager.run_state):
		_update_day_label(GameManager.run_state.day)
		_on_gold_changed(GameManager.run_state.gold)
		_populate_player_trinkets()

func _populate_player_trinkets() -> void:
	if not is_instance_valid(GameManager.run_state):
		return
	var trinket_container = GameManager.run_state.get_container(RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS)
	if not is_instance_valid(trinket_container):
		return
	var slots = player_trinket_bar.get_children()
	for i in range(slots.size()):
		var slot_view = slots[i]
		if not is_instance_valid(slot_view):
			continue
		for child in slot_view.get_children():
			child.queue_free()
		var loc = LocationIdentifier.new()
		loc.container = RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS
		loc.index = i
		if slot_view.has_method("populate"):
			slot_view.populate(loc)
			if slot_view.has_method("set_interaction_context"):
				slot_view.set_interaction_context(&"INSPECTION_ONLY", 0)
		var instance = GameManager.get_instance_from_location(loc)
		if is_instance_valid(instance):
			var visual_data = VisualDataAdapter.create_visual_data(instance)
			slot_view.set_content(visual_data, true, true, false)
			if slot_view.get_child_count() > 0:
				var view = slot_view.get_child(0)
				if view is GachaBallView and view.has_method("set_interaction_context"):
					view.set_interaction_context(&"INSPECTION_ONLY", &"TRINKET", 0)

func _start_battle_with_encounter(encounter_def: EncounterDefinition) -> void:
	# Find the BattleManager in the loaded scene and start the battle
	var battle_manager = _current_content_node.get_node_or_null("BattleManager")
	if battle_manager and battle_manager.has_method("start_battle"):
		battle_manager.start_battle(encounter_def)
	else:
		pass
