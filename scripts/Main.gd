# res://scripts/Main.gd
extends Control

const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")
const RejectionFeedbackScript = preload("res://scripts/vfx/RejectionFeedback.gd")

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
	content_area.get_node("SubViewport/MarginContainer").add_child(instance)

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
	# PRE-VALIDATION: Check if player has enough tokens BEFORE animating
	var bm = get_tree().get_first_node_in_group("battle_manager")
	if is_instance_valid(bm) and bm.has_method("get_gacha_tokens"):
		var current_tokens: int = bm.get_gacha_tokens()
		if current_tokens < tier:
			# Insufficient tokens - play rejection feedback on machine and token counter
			var target_machine: Control = null
			match tier:
				1: target_machine = gacha_machine_1
				2: target_machine = gacha_machine_2
				3: target_machine = gacha_machine_3
			var token_group = get_node_or_null("%TokenGroup")
			if is_instance_valid(target_machine):
				RejectionFeedbackScript.play_rejection_with_counter(target_machine, token_group, get_tree())
			return
	
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
	
	# Animate tokens flying from counter to machine, then proceed with draw
	_animate_token_spend(tier, button)

func _animate_token_spend(tier: int, _button: BaseButton) -> void:
	"""Animate tokens flying from counter to gacha machine before drawing"""
	const TokenSpendScene = preload("res://scenes/vfx/TokenSpendVFX.tscn")
	
	# Get token counter position (source)
	var token_group = get_node_or_null("%TokenGroup")
	if not is_instance_valid(token_group):
		# No animation, just draw
		SignalBus.emit_signal("draw_gacha_requested", tier)
		return
	
	var token_rect = token_group.get_global_rect()
	var start_pos = Vector2(
		token_rect.position.x + token_rect.size.x / 2,
		token_rect.position.y + token_rect.size.y / 2
	)
	
	# Get target gacha machine
	var target_machine: Control = null
	match tier:
		1: target_machine = gacha_machine_1
		2: target_machine = gacha_machine_2
		3: target_machine = gacha_machine_3
	
	if not is_instance_valid(target_machine):
		SignalBus.emit_signal("draw_gacha_requested", tier)
		return
	
	var machine_rect = target_machine.get_global_rect()
	var target_pos = Vector2(
		machine_rect.position.x + machine_rect.size.x / 2,
		machine_rect.position.y + machine_rect.size.y * 0.4 # Aim for coin slot area
	)
	
	# Spawn tokens with stagger - each one triggers machine reaction on landing
	var tokens_to_spawn = tier
	var stagger_delay = 0.12 # Increased delay for more dramatic sequential tosses
	
	for i in range(tokens_to_spawn):
		var token_vfx = TokenSpendScene.instantiate()
		add_child(token_vfx)
		
		# Connect to coin_landed to trigger machine reaction
		token_vfx.coin_landed.connect(_on_coin_landed_on_machine.bind(target_machine))
		
		# Slight random offset to start position for natural feel
		var offset = Vector2(randf_range(-20, 20), randf_range(-10, 10))
		token_vfx.play(start_pos + offset, target_pos, i * stagger_delay)
	
	# Wait for all animations to complete, then trigger draw
	# TokenSpendVFX.TOSS_DURATION = 0.45
	var total_wait = (tokens_to_spawn - 1) * stagger_delay + 0.55
	await get_tree().create_timer(total_wait).timeout
	
	# Proceed with the draw
	SignalBus.emit_signal("draw_gacha_requested", tier)

func _on_coin_landed_on_machine(target_pos: Vector2, machine: Control) -> void:
	"""React when a coin lands on a gacha machine - bounce and flash"""
	if not is_instance_valid(machine):
		return
	
	# Ensure we ignore unused warning for target_pos (for future particle effects)
	var _unused = target_pos
	
	_play_machine_bounce(machine)

## Public function to trigger machine bounce animation from external scripts
## Used when gachballs arrive at or depart from a machine
func trigger_machine_bounce(tier: int) -> void:
	var target_machine: Control = null
	match tier:
		1: target_machine = gacha_machine_1
		2: target_machine = gacha_machine_2
		3: target_machine = gacha_machine_3
	
	if is_instance_valid(target_machine):
		_play_machine_bounce(target_machine)

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
	
	# Quick scale bounce - squash then stretch back
	reaction_tween.tween_property(machine, "scale", Vector2(1.03, 0.97), 0.04).set_trans(Tween.TRANS_SINE)
	reaction_tween.tween_property(machine, "scale", Vector2(0.98, 1.02), 0.06).set_delay(0.04).set_trans(Tween.TRANS_SINE)
	reaction_tween.tween_property(machine, "scale", Vector2(1.0, 1.0), 0.08).set_delay(0.10).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Flash bright on the machine image
	var flash_color = Color(1.3, 1.25, 1.1, 1.0) # Warm bright flash
	reaction_tween.tween_property(machine_image, "modulate", flash_color, 0.03)
	reaction_tween.tween_property(machine_image, "modulate", Color.WHITE, 0.12).set_delay(0.03)

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
		var old_text = gold_label.text
		gold_label.text = "%d" % new_amount
		
		# Only animate if value actually changed (not initial load)
		if old_text != gold_label.text:
			_animate_gold_counter_pop()

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
	if is_instance_valid(tokens_label):
		var old_text = tokens_label.text
		tokens_label.text = "%d" % new_amount
		
		# Only animate if value actually changed (not initial load)
		if old_text != tokens_label.text:
			_animate_token_counter_pop()

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
	_clear_content_area()
	var instance = SHOP_SCENE.instantiate()
	_current_content_node = instance
	content_area.get_node("SubViewport/MarginContainer").add_child(instance)
	
	if instance.has_method("populate"):
		instance.populate(context)

func _update_day_label(day: int) -> void:
	if is_instance_valid(days_label):
		days_label.text = tr("ui.day") % day

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
			# Skip indicator (z_index 10) and slot background (z_index -1)
			if child is TextureRect and (child.z_index == 10 or child.z_index == -1):
				continue
			child.queue_free()
		# Use 1x scale for player trinkets (compact 128x128 display, native 64x64 texture)
		# NOTE: TopArea slots are 128x128 which can't fit 2x Battle Mode (192x192)
		if slot_view.has_method("set_size_scale"):
			slot_view.set_size_scale(1.0)
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
