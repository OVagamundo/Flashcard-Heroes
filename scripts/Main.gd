# res://scripts/Main.gd
extends Control

const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")
const RejectionFeedbackScript = preload("res://scripts/vfx/RejectionFeedback.gd")
const InputUtils = preload("res://scripts/InputUtils.gd")

@onready var content_area: SubViewportContainer = %ContentArea
@onready var scene_background: TextureRect = %SceneBackground
@onready var scene_slot: MarginContainer = %SceneSlot
@onready var color_glow_rect: ColorRect = $PostProcessLayer/ColorGlowRect

# Gacha machine containers
@onready var gacha_machine_1: Control = %GachaMachine1
@onready var gacha_machine_2: Control = %GachaMachine2
@onready var gacha_machine_3: Control = %GachaMachine3
@onready var bottom_area: PanelContainer = %BottomArea

# Knob buttons for drawing
@onready var knob_button_1: TextureButton = %GachaMachine1.get_node("KnobButton")
@onready var knob_button_2: TextureButton = %GachaMachine2.get_node("KnobButton")
@onready var knob_button_3: TextureButton = %GachaMachine3.get_node("KnobButton")

@onready var gold_label: Label = %GoldLabel
@onready var days_label: Label = %DaysLabel
@onready var tokens_label: Label = %TokensLabel
@onready var flashcard_progress_bar: HBoxContainer = %FlashcardProgressBar

@onready var player_trinket_bar: HBoxContainer = %PlayerTrinketBar

# Machine inventory count labels
@onready var machine_1_count_label: Label = %GachaMachine1.get_node("CountLabel")
@onready var machine_2_count_label: Label = %GachaMachine2.get_node("CountLabel")
@onready var machine_3_count_label: Label = %GachaMachine3.get_node("CountLabel")


const PATH_CHOICE_SCENE = preload("res://scenes/PathChoice.tscn")
const BATTLE_SCENE = preload("res://scenes/Battle.tscn")
const REWARD_SCENE = preload("res://scenes/Reward.tscn")

const SHOP_SCENE = preload("res://scenes/Shop.tscn")

# Mastery level colors (matching FlashcardSystem.md)
const MASTERY_COLORS = {
	1: Color(0.9, 0.2, 0.2), # Very Hard - Red
	2: Color(0.95, 0.5, 0.1), # Hard - Orange
	3: Color(0.95, 0.8, 0.1), # Medium - Yellow
	4: Color(0.2, 0.8, 0.2), # Easy - Green
	5: Color(0.2, 0.4, 0.9) # Very Easy - Blue
}
const LOCKED_COLOR = Color(0.4, 0.4, 0.4) # Grey for locked cards

var _current_content_node: Node = null

# Confirm drop zone overlay (covers bottom area for Reward/Shop confirm)
var _confirm_drop_zone: PanelContainer = null
var _confirm_drop_zone_label: Label = null
var _confirm_drop_zone_mode: StringName = &"" # &"Rewards" or &"Shop"
var _confirm_drop_zone_visible: bool = false
var _drop_zone_drag_context: InteractionContext = null # Saved drag origin for restoring selection on drop

func _ready() -> void:
	GameManager.register_main_node(self ) # Register self with GameManager
	
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

	SignalBus.gold_changed.connect(_on_gold_changed)
	SignalBus.gacha_tokens_changed.connect(_on_gacha_tokens_changed)
	SignalBus.shop_scene_requested.connect(_on_shop_scene_requested)
	SignalBus.run_data_changed.connect(_on_run_data_changed)
	SignalBus.battle_phase_changed.connect(_on_battle_phase_changed)
	
	# Connect drop zone signals
	SignalBus.selection_changed.connect(_on_selection_changed_for_drop_zone)
	SignalBus.drag_started.connect(_on_drag_started_for_drop_zone)
	SignalBus.drag_ended.connect(_on_drag_ended_for_drop_zone)
	
	CRTEffect.glow_toggled.connect(func(enabled: bool):
		if is_instance_valid(color_glow_rect):
			color_glow_rect.visible = enabled
	)
	CRTEffect.glow_debug_view_changed.connect(_apply_glow_debug_view)
	if is_instance_valid(color_glow_rect):
		color_glow_rect.visible = CRTEffect.is_glow_enabled()
	_apply_glow_debug_view(CRTEffect.get_glow_debug_view())

	_on_battle_state_changed(false)
	
	# Build the confirm drop zone overlay (programmatic, not in .tscn)
	_build_confirm_drop_zone()

	SignalBus.emit_signal("path_choice_scene_requested")

	if is_instance_valid(GameManager.run_state):
		_on_gold_changed(GameManager.run_state.gold)
		_update_day_label(GameManager.run_state.day)
		_populate_player_trinkets()
		_populate_flashcard_progress()
	
	# Update machine counts after battle manager is ready
	call_deferred("_update_machine_counts")

func _exit_tree() -> void:
	GameManager.unregister_main_node()
	# Cleanup drop zone signals
	if SignalBus.selection_changed.is_connected(_on_selection_changed_for_drop_zone):
		SignalBus.selection_changed.disconnect(_on_selection_changed_for_drop_zone)
	if SignalBus.drag_started.is_connected(_on_drag_started_for_drop_zone):
		SignalBus.drag_started.disconnect(_on_drag_started_for_drop_zone)
	if SignalBus.drag_ended.is_connected(_on_drag_ended_for_drop_zone):
		SignalBus.drag_ended.disconnect(_on_drag_ended_for_drop_zone)

func _apply_glow_debug_view(view: int) -> void:
	if not is_instance_valid(color_glow_rect):
		return
	var glow_material := color_glow_rect.material as ShaderMaterial
	if glow_material == null:
		return
	glow_material.set_shader_parameter("debug_view", view)

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
		# FIXME: This interferes with SubViewport interaction handling (bubbling from SubViewportContainer)
		# effectively overriding all clicks in BattleView with a DESELECT.
		# Since BattleView has its own background handler that correctly respects STOP filters,
		# we can disable this catch-all.
		# SignalBus.emit_signal("interaction_context_received", context)
	elif InputUtils.is_primary_pointer_release(event) and GlobalInteractionRouter.is_drag_active():
		# Do NOT forcibly end drag on background release here; drop targets manage drag end.
		# This was canceling drag before GIR processed battle board drop targets.
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
		# Check if any windows are open
		if WindowManager.is_any_inspection_window_open():
			# Close all open windows - this is the "click outside window" behavior
			WindowManager.close_all_inspection_windows()
			# Don't open inventory - the close action was the intent
		else:
			# No windows open - open inventory
			SignalBus.emit_signal("inspect_inventory_requested")
		get_viewport().set_input_as_handled()
		if InputUtils.is_touch_pointer_event(event):
			accept_event()

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

func clear_content_area() -> void:
	if is_instance_valid(_current_content_node):
		_current_content_node.queue_free()
	_current_content_node = null

func load_content(scene_resource: PackedScene) -> Node:
	clear_content_area()
	var instance = scene_resource.instantiate()
	_current_content_node = instance
	scene_slot.add_child(instance)
	
	# Sync background texture to full-screen SceneBackground
	_sync_scene_background(instance)
	return instance

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
	# Use call_deferred to ensure the BattleManager is ready before calling it
	call_deferred("_start_battle_with_encounter", encounter_def)

func _on_path_choice_scene_requested() -> void:
	load_content(PATH_CHOICE_SCENE)
	# AUDIO HOOK: Menu BGM (Returning from battle or shop)
	Audio.play_music(SoundRegistry.BGM_MENU)
	
	if is_instance_valid(GameManager.run_state):
		_update_day_label(GameManager.run_state.day)

	
func _on_reward_scene_requested(context: Dictionary) -> void:
	clear_content_area()
	var instance = REWARD_SCENE.instantiate()
	_current_content_node = instance
	# Correctly parent the new scene inside the SceneSlot
	scene_slot.add_child(instance)
	
	# Sync background texture to full-screen SceneBackground
	_sync_scene_background(instance)
	
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
	
	# Animate knob rotation
	var knob_tween = create_tween()
	knob_tween.tween_property(button, "rotation_degrees", 360.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	knob_tween.tween_property(button, "rotation_degrees", 0.0, 0.0) # Reset
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
		
		# AUDIO HOOK: Token spend (play for each token)
		Audio.play_sfx("token_spend", 1.0 + (i * 0.05))
		
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
	
	# AUDIO HOOK: Token land on machine
	Audio.play_sfx("token_land")
	
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
	
	# Update machine inventory counts
	_update_machine_counts()

func _on_battle_state_changed(is_in_battle: bool) -> void:
	# The gacha machines are always visible in the permanent HUD.
	# Only disable the knob buttons when not in battle (can't draw outside battle).
	knob_button_1.disabled = not is_in_battle
	knob_button_2.disabled = not is_in_battle
	knob_button_3.disabled = not is_in_battle
	
	# Reset token counter to 0 when leaving battle (tokens don't persist between encounters)
	if not is_in_battle:
		if is_instance_valid(tokens_label):
			tokens_label.text = "0"
	else:
		# Entering battle - update machine counts
		_update_machine_counts()

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
	clear_content_area()
	var instance = SHOP_SCENE.instantiate()
	_current_content_node = instance
	scene_slot.add_child(instance)
	
	# Sync background texture to full-screen SceneBackground
	_sync_scene_background(instance)
	
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
		_populate_flashcard_progress()
		_update_machine_counts()

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

func _populate_flashcard_progress() -> void:
	"""Populate the flashcard progress bar with colored rectangles for each card in main deck."""
	if not is_instance_valid(flashcard_progress_bar):
		return
	if not is_instance_valid(GameManager.run_state):
		return
	
	# Clear existing indicators
	for child in flashcard_progress_bar.get_children():
		child.queue_free()
	
	# Get main deck cards from Database
	var deck_id = GameManager.run_state.deck_def_id
	if deck_id == &"":
		return
	
	var main_deck_cards = Database.get_cards_for_deck(deck_id)
	if main_deck_cards.is_empty():
		return
	
	# Calculate individual card width
	var total_width = 480.0
	var gap = 2.0
	var total_gaps = (main_deck_cards.size() - 1) * gap
	var card_width = (total_width - total_gaps) / main_deck_cards.size()
	
	# Create a rectangle for each card in main deck order
	var boss_thresholds = [0.2, 0.4, 0.6, 0.8, 1.0]
	var boss_indices = []
	for t in boss_thresholds:
		var idx = clampi(ceil(main_deck_cards.size() * t) - 1, 0, main_deck_cards.size() - 1)
		if not boss_indices.has(idx):
			boss_indices.append(idx)
	
	for i in range(main_deck_cards.size()):
		var card_id = main_deck_cards[i]
		var rect = ColorRect.new()
		
		# Check if card is in active deck
		var is_active = GameManager.run_state.active_deck_ids.has(card_id)
		var is_boss_trigger = boss_indices.has(i)
		
		var height = 10.0
		if is_boss_trigger and not is_active:
			height = 24.0 # Taller marker for future bosses
		
		rect.custom_minimum_size = Vector2(card_width, height)
		# Center taller markers vertically relative to the bar
		rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		if is_active:
			# Get mastery level and apply corresponding color
			var progress = GameManager.run_state.flashcard_progress.get(card_id)
			if is_instance_valid(progress):
				var mastery = progress.mastery_level
				rect.color = MASTERY_COLORS.get(mastery, LOCKED_COLOR)
			else:
				rect.color = MASTERY_COLORS[1] # Default to level 1 if no progress
		else:
			# Card not yet unlocked
			if is_boss_trigger:
				rect.color = Color.WHITE # White for locked bosses
			else:
				rect.color = LOCKED_COLOR # Grey for locked normal cards
		
		flashcard_progress_bar.add_child(rect)

func _start_battle_with_encounter(encounter_def: EncounterDefinition) -> void:
	# Find the BattleManager in the loaded scene and start the battle
	var battle_manager = _current_content_node.get_node_or_null("BattleManager")
	if battle_manager and battle_manager.has_method("start_battle"):
		battle_manager.start_battle(encounter_def)
	else:
		pass



## Update the inventory count labels on all three gacha machines
func _update_machine_counts() -> void:
	var bm = get_tree().get_first_node_in_group("battle_manager")
	
	for tier in [1, 2, 3]:
		var count = 0
		if is_instance_valid(bm) and bm.has_method("get_inventory_tier_instances"):
			count = bm.get_inventory_tier_instances(tier).size()
		elif is_instance_valid(GameManager.run_state):
			count = GameManager.run_state.get_inventory_tier_instances(tier).size()
			
		var label = null
		match tier:
			1: label = machine_1_count_label
			2: label = machine_2_count_label
			3: label = machine_3_count_label
			
		if is_instance_valid(label):
			label.text = "x%d" % count

# =============================================================================
# CONFIRM DROP ZONE OVERLAY
# =============================================================================

func _build_confirm_drop_zone() -> void:
	"""Programmatically create the warm white overlay that covers the bottom area."""
	_confirm_drop_zone = PanelContainer.new()
	_confirm_drop_zone.name = "ConfirmDropZone"
	_confirm_drop_zone.unique_name_in_owner = true
	
	# Match BottomArea anchors: full width, bottom-anchored, 260px tall
	_confirm_drop_zone.layout_mode = 1 # Anchored
	_confirm_drop_zone.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_confirm_drop_zone.custom_minimum_size = Vector2(0, 260)
	_confirm_drop_zone.offset_top = -260
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
	
	_confirm_drop_zone_label = Label.new()
	_confirm_drop_zone_label.text = "Get"
	_confirm_drop_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_drop_zone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_confirm_drop_zone_label.add_theme_font_size_override("font_size", 52)
	_confirm_drop_zone_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.32, 0.85))
	_confirm_drop_zone_label.add_theme_color_override("font_outline_color", Color(0.15, 0.17, 0.22, 0.3))
	_confirm_drop_zone_label.add_theme_constant_override("outline_size", 2)
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
		_confirm_drop_zone_label.text = "Get"
	elif mode == &"Shop":
		_confirm_drop_zone_label.text = "Buy"
	else:
		_confirm_drop_zone_label.text = "Confirm"
	
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
		if _confirm_drop_zone_mode != &"":
			SignalBus.emit_signal("confirm_drop_zone_activated")
			# Play confirm sound
			Audio.play_sfx("ui_click")
		get_viewport().set_input_as_handled()

func _on_selection_changed_for_drop_zone(new_location: LocationIdentifier) -> void:
	"""Show/hide the drop zone based on whether a Reward/Shop item is selected."""
	if new_location and new_location.container == &"Rewards":
		show_confirm_drop_zone(&"Rewards")
	elif new_location and new_location.container == &"Shop":
		show_confirm_drop_zone(&"Shop")
	else:
		# Defer the hide slightly: during drag-end, GIR clears selection (emitting
		# selection_changed(null)) BEFORE emitting drag_ended. If we hide immediately,
		# the drag_ended handler can't detect mouse-over-zone. Use call_deferred
		# so drag_ended processes first.
		call_deferred("_deferred_maybe_hide_drop_zone")

func _deferred_maybe_hide_drop_zone() -> void:
	"""Hide drop zone if no relevant selection or drag is active."""
	# If mode was already cleared (by confirm/buy), nothing to do
	if _confirm_drop_zone_mode == &"":
		return
	# If a new selection was established in the meantime, don't hide
	var sel = GlobalInteractionRouter.get_current_selection()
	if sel and is_instance_valid(sel.location):
		if sel.location.container == &"Rewards" or sel.location.container == &"Shop":
			return
	hide_confirm_drop_zone()

func _on_drag_started_for_drop_zone(origin_context: InteractionContext) -> void:
	"""Show the drop zone when dragging from Reward/Shop. Save context for drop."""
	_drop_zone_drag_context = null
	if origin_context and is_instance_valid(origin_context.location):
		if origin_context.location.container == &"Rewards":
			_drop_zone_drag_context = origin_context
			show_confirm_drop_zone(&"Rewards")
		elif origin_context.location.container == &"Shop":
			_drop_zone_drag_context = origin_context
			show_confirm_drop_zone(&"Shop")

func _on_drag_ended_for_drop_zone(_was_handled: bool) -> void:
	"""Check if drag ended over the drop zone and trigger confirm if so."""
	var saved_ctx = _drop_zone_drag_context
	_drop_zone_drag_context = null
	
	if _confirm_drop_zone_mode == &"":
		return
	
	# Check if mouse is over the drop zone rect
	if is_instance_valid(_confirm_drop_zone) and _confirm_drop_zone.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		var zone_rect = _confirm_drop_zone.get_global_rect()
		if zone_rect.has_point(mouse_pos) and saved_ctx != null:
			# CRITICAL: GIR.end_drag() already cleared the selection before
			# this signal fired. Restore it so Reward/Shop confirm handlers
			# can find the selected item via get_current_selection().
			GlobalInteractionRouter.set_current_selection(saved_ctx)
			SignalBus.emit_signal("selection_changed", saved_ctx.location)
			
			# Drag ended over the drop zone — trigger confirm!
			SignalBus.emit_signal("confirm_drop_zone_activated")
			Audio.play_sfx("ui_click")
			return
	
	# Drag ended elsewhere — hide the drop zone
	hide_confirm_drop_zone()


## Public API: Get the global rect of the drop zone (for external hit testing)
func get_confirm_drop_zone_rect() -> Rect2:
	if is_instance_valid(_confirm_drop_zone) and _confirm_drop_zone.visible:
		return _confirm_drop_zone.get_global_rect()
	return Rect2()
