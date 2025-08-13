# res://scripts/Main.gd
extends Control

@onready var content_area: SubViewportContainer = %ContentArea
@onready var inspect_inventory_button: Button = %InspectInventoryButton
@onready var draw_tier1_button: Button = %DrawTier1Button
@onready var draw_tier2_button: Button = %DrawTier2Button
@onready var draw_tier3_button: Button = %DrawTier3Button

@onready var gold_label: Label = $VBoxContainer/TopArea/HBoxContainer/GoldLabel
@onready var days_label: Label = $VBoxContainer/TopArea/HBoxContainer/DaysLabel
@onready var tokens_label: Label = $VBoxContainer/TopArea/HBoxContainer/TokensLabel

const PATH_CHOICE_SCENE = preload("res://scenes/PathChoice.tscn")
const BATTLE_SCENE = preload("res://scenes/Battle.tscn")
const REWARD_SCENE = preload("res://scenes/Reward.tscn")
const SHOP_SCENE = preload("res://scenes/Shop.tscn")
const EncounterDefinition = preload("res://scripts/EncounterDefinition.gd")

var _current_content_node: Node = null

func _ready() -> void:
	inspect_inventory_button.pressed.connect(_on_inspect_inventory_pressed)
	draw_tier1_button.pressed.connect(func(): _on_draw_button_pressed(draw_tier1_button, 1))
	draw_tier2_button.pressed.connect(func(): _on_draw_button_pressed(draw_tier2_button, 2))
	draw_tier3_button.pressed.connect(func(): _on_draw_button_pressed(draw_tier3_button, 3))

	
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

	_on_battle_state_changed(false)
	SignalBus.emit_signal("path_choice_scene_requested")

	if is_instance_valid(GameManager.run_state):
		_on_gold_changed(GameManager.run_state.gold)
		_update_day_label(GameManager.run_state.day)

func _on_content_area_gui_input(event: InputEvent) -> void:
	# Handle background clicks and drag end on the main game area
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			# Create and emit InteractionContext for main game background
			var context = InteractionContext.new()
			context.source_view_instance_id = get_instance_id()
			context.event_type = &"SINGLE_CLICK"
			context.location = null  # No specific location for background
			context.entity_uuid = ""
			context.entity_type = &"GLOBAL_BACKGROUND"
			context.interaction_mode = &"FULLY_INTERACTIVE"
			context.window_group_id = 0  # Main game area
			SignalBus.emit_signal("interaction_context_received", context)
		elif GlobalInteractionRouter.is_drag_active() and not event.is_pressed():
			# Do NOT forcibly end drag on background release here; drop targets manage drag end.
			# This was canceling drag before GIR processed battle board drop targets.
			pass

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

func _on_inspect_inventory_pressed() -> void:
	# This is a bit of a hack for now, but the WindowManager is
	# responsible for figuring out which inventory to open based on game state.
	SignalBus.emit_signal("inspect_inventory_requested")
	inspect_inventory_button.release_focus()



func _on_draw_button_pressed(button: Button, tier: int) -> void:
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
	draw_tier1_button.disabled = false
	draw_tier2_button.disabled = false
	draw_tier3_button.disabled = false

func _on_battle_state_changed(is_in_battle: bool) -> void:
	draw_tier1_button.visible = is_in_battle
	draw_tier2_button.visible = is_in_battle
	draw_tier3_button.visible = is_in_battle

func _on_gold_changed(new_amount: int) -> void:
	if is_instance_valid(gold_label):
		gold_label.text = "Gold: %d" % new_amount

func _on_gacha_tokens_changed(new_amount: int) -> void:
	if is_instance_valid(tokens_label):
		tokens_label.text = "Tokens: %d" % new_amount
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

func _start_battle_with_encounter(encounter_def: EncounterDefinition) -> void:
	# Find the BattleManager in the loaded scene and start the battle
	var battle_manager = _current_content_node.get_node_or_null("BattleManager")
	if battle_manager and battle_manager.has_method("start_battle"):
		battle_manager.start_battle(encounter_def)
	else:
		pass
