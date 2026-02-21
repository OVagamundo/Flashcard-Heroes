# res://scripts/BattleView.gd
class_name BattleView
extends Control

const SlotViewScene = preload("res://scenes/SlotView.tscn")
const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")
const TraitTrackerScene = preload("res://scenes/TraitTracker.tscn")

# --- UI Node References ---
@onready var player_lineup: HBoxContainer = %PlayerLineup
@onready var player_bench: HBoxContainer = get_node("TeamAreas/PlayerArea/BenchAndInventory/PlayerBench")
@onready var enemy_lineup: HBoxContainer = %EnemyLineupContainer

@onready var discard_pile_button: Button = %DiscardPileButton
@onready var end_turn_button: Button = %EndTurnButton
@onready var enemy_trinket_bar: HBoxContainer = %EnemyTrinketBar

# Trait Containers (Created programmatically)
var player_traits: Control
var enemy_traits: Control
var _player_trait_anchor: Control
var _enemy_trait_anchor: Control
var _trait_hud_root: Control

const TRAIT_SORT_ORDER: Array[String] = ["FIRE", "EARTH", "WATER", "WIND"]
const TRAIT_HUD_Y: float = 10.0
const TRAIT_TRACKER_SPACING: float = 8.0
const TRAIT_SCREEN_MARGIN: float = 24.0

# --- Node References ---
var battle_manager: BattleManager

# --- Helper to convert placeholder PanelContainers into SlotView prefabs once ---
func _initialize_slots(ui_container: HBoxContainer, container_name: StringName) -> void:
	var slots: Array = ui_container.get_children()
	for i in range(slots.size()):
		var child = slots[i]
		if child is PanelContainer and child.get_script() != preload("res://scripts/SlotView.gd"):
			var loc := LocationIdentifier.new()
			loc.container = container_name
			loc.index = i
			var parent: Node = child.get_parent()
			var idx: int = child.get_index()
			child.free()
			var slot_view: PanelContainer = SlotViewScene.instantiate()
			parent.add_child(slot_view)
			parent.move_child(slot_view, idx)
			slot_view.populate(loc)
			
			# Apply battle-specific layout settings (responsive width, fixed height)
			if not is_instance_valid(slot_view):
				continue
				
			slot_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			# All battle slots use 2x scale
			slot_view.custom_minimum_size = Vector2(C.SLOT_SIZE_2X, C.SLOT_SIZE_2X)
			
			if slot_view.has_method("set_size_scale"):
				slot_view.set_size_scale(2.0)
				
			# Apply container-specific color scheme
			if slot_view.has_method("set_slot_color"):
				slot_view.set_slot_color(container_name)
			# EnemyLineup must be inspection-only: configure SlotView accordingly
			if container_name == &"EnemyLineup":
				slot_view.set_interaction_context(&"INSPECTION_ONLY", 0)

func _ready() -> void:
	# --- LAYOUT FIX INJECTION ---
	# Force Top Alignment and Insert Spacers to guarantee gap below Top Bar
	# Reverting to 240px spacer (proven safe from bottom clipping)
	# and raising HUD to 10px (Absolute Top) to clear unit slots.
	var team_areas = get_node_or_null("TeamAreas")
	if team_areas:
		# Player Area Fix
		var player_area_node = team_areas.get_node_or_null("PlayerArea")
		if player_area_node and player_area_node is BoxContainer:
			player_area_node.alignment = BoxContainer.ALIGNMENT_BEGIN
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 240) # 240px Top Gap
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			player_area_node.add_child(spacer)
			player_area_node.move_child(spacer, 0)
			
		# Enemy Area Fix
		var enemy_area_node = team_areas.get_node_or_null("EnemyArea")
		if enemy_area_node and enemy_area_node is BoxContainer:
			enemy_area_node.alignment = BoxContainer.ALIGNMENT_BEGIN
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 240) # 240px Top Gap
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			enemy_area_node.add_child(spacer)
			enemy_area_node.move_child(spacer, 0)

	# ----------------------------
	# TRAIT HUD LAYER
	# ----------------------------
	var trait_layer = Control.new()
	trait_layer.name = "TraitHUD"
	trait_layer.layout_mode = 1
	trait_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	trait_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trait_layer.z_index = 100
	add_child(trait_layer)
	
	# Player Traits Container (Floating HUD)
	player_traits = Control.new()
	player_traits.name = "PlayerTraits"
	player_traits.layout_mode = 1
	player_traits.set_anchors_preset(Control.PRESET_TOP_LEFT)
	player_traits.position = Vector2.ZERO
	
	# Enemy Traits Container (Floating HUD)
	enemy_traits = Control.new()
	enemy_traits.name = "EnemyTraits"
	enemy_traits.layout_mode = 1
	enemy_traits.set_anchors_preset(Control.PRESET_TOP_LEFT)
	enemy_traits.position = Vector2.ZERO
	
	_trait_hud_root = trait_layer
	
	# Player Side (Left)
	_player_trait_anchor = Control.new()
	_player_trait_anchor.layout_mode = 1 # Anchors
	_player_trait_anchor.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_player_trait_anchor.position = Vector2(160, TRAIT_HUD_Y)
	_trait_hud_root.add_child(_player_trait_anchor)
	_player_trait_anchor.add_child(player_traits)
	
	# Enemy Side (Right)
	_enemy_trait_anchor = Control.new()
	_enemy_trait_anchor.layout_mode = 1
	_enemy_trait_anchor.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_enemy_trait_anchor.position = Vector2(0, TRAIT_HUD_Y)
	_trait_hud_root.add_child(_enemy_trait_anchor)
	_enemy_trait_anchor.add_child(enemy_traits)
	# ----------------------------

		
	# ----------------------------

	# Guard against duplicate BattleView instances which would cause multiple
	# emissions of draw_gacha_requested per click.
	add_to_group("battle_view")
	var views := get_tree().get_nodes_in_group("battle_view")
	if views.size() > 1:
		queue_free()
		return
	battle_manager = get_node("BattleManager")
	if not is_instance_valid(battle_manager):
		return

	# Connect to all relevant state change signals
	SignalBus.battle_inventory_changed.connect(_redraw_board)

	SignalBus.battle_phase_changed.connect(_on_battle_phase_changed)
	SignalBus.gacha_draw_animated.connect(_on_gacha_draw_animated)
	
	# NOTE: Unit death tutorial is handled directly in BattleAnimator._animate_events
	# to properly block combat until the tutorial is dismissed.
	
	# Connect to battle_state_changed to trigger entry animation on EVERY battle start
	SignalBus.battle_state_changed.connect(_on_battle_state_changed)
	
	# Connect to SignalBus.results_acknowledged to show battle management tutorial
	SignalBus.results_acknowledged.connect(_on_results_acknowledged)
	
	# Connect this view's buttons to emit the correct intent signals
	end_turn_button.pressed.connect(func(): SignalBus.emit_signal("end_turn_requested"))
	discard_pile_button.pressed.connect(func(): SignalBus.emit_signal("display_discard_pile_requested"))
	
	# Pre-instantiate SlotView nodes to avoid runtime replacement duplicates
	_initialize_slots(player_lineup, &"PlayerLineup")
	_initialize_slots(player_bench, &"PlayerBench")
	_initialize_slots(enemy_lineup, &"EnemyLineup")
	_initialize_slots(enemy_trinket_bar, &"EnemyTrinkets")

	# The initial draw is now handled directly in _ready to avoid race conditions.
	# Subsequent updates will be handled by the battle_inventory_changed signal.
	_redraw_board()
	_redraw_board()
	_on_battle_phase_changed(battle_manager.get_current_phase_name())
	if is_instance_valid(player_lineup) and not player_lineup.resized.is_connected(_on_lineup_resized):
		player_lineup.resized.connect(_on_lineup_resized)
	if is_instance_valid(enemy_lineup) and not enemy_lineup.resized.is_connected(_on_lineup_resized):
		enemy_lineup.resized.connect(_on_lineup_resized)
	var viewport = get_viewport()
	if is_instance_valid(viewport) and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	
	# Animate initial unit entry (first battle only - subsequent battles via signal)
	await get_tree().process_frame
	_animate_initial_unit_entry()

func _on_battle_state_changed(is_in_battle: bool) -> void:
	"""Called when battle state changes - triggers entry animation on battle start"""
	if is_in_battle:
		# Wait for board to be redrawn first
		await get_tree().process_frame
		await get_tree().process_frame
		_animate_initial_unit_entry()


func _on_results_acknowledged() -> void:
	"""Called when results popup is closed - show battle management tutorial"""
	# Check if we are in MANAGEMENT phase (which we should be after minigame)
	if battle_manager.get_current_phase() == BattleManager.Phases.MANAGEMENT:
		# Wait a frame for the results popup to fully close/free
		await get_tree().process_frame
		TutorialManager.show_tutorial(&"battle_management_intro", [
			{"text": tr("tutorial.battle_management")}
		])


func _animate_initial_unit_entry() -> void:
	"""Animate hero and enemy units appearing one-by-one when entering battle"""
	var all_units: Array = []
	
	# Collect units from PlayerLineup (typically just the hero)
	for slot in player_lineup.get_children():
		if slot is PanelContainer:
			for child in slot.get_children():
				if child is GachaBallView:
					all_units.append(child)
					break
	
	# Collect units from EnemyLineup
	for slot in enemy_lineup.get_children():
		if slot is PanelContainer:
			for child in slot.get_children():
				if child is GachaBallView:
					all_units.append(child)
					break
	
	# Animate each unit with stagger
	for i in range(all_units.size()):
		var ball_view: GachaBallView = all_units[i]
		if not is_instance_valid(ball_view):
			continue
		
		# Find the correct sprite to animate (UnitSprite for battle mode)
		var sprite_node = ball_view.icon_rect.get_node_or_null("UnitSprite")
		var target_node = sprite_node if is_instance_valid(sprite_node) else ball_view.icon_rect
		
		if is_instance_valid(target_node):
			# Hide initially
			target_node.scale = Vector2.ZERO
			target_node.pivot_offset = target_node.size / 2.0
			
			# Schedule delayed reveal with bounce
			var delay = i * AnimationConstants.ENTRY_STAGGER_DELAY
			get_tree().create_timer(delay).timeout.connect(func():
				if is_instance_valid(target_node):
					target_node.scale = Vector2.ONE
				if is_instance_valid(ball_view):
					ball_view.play_landing_bounce()
			)


func _redraw_board() -> void:
	if not is_instance_valid(battle_manager) or not is_inside_tree() or is_queued_for_deletion():
		return
	
	# CRITICAL: NEVER redraw the board during animation phases!
	# The BattleAnimator owns all views during these phases (Puppet Mode).
	# Any board rebuild will destroy the registered views and break animations.
	var current_phase = battle_manager.get_current_phase()
	if current_phase == BattleManager.Phases.COMBAT or \
	   current_phase == BattleManager.Phases.START_OF_TURN or \
	   current_phase == BattleManager.Phases.END_OF_TURN:
		return
	

	_populate_container(player_lineup, "PlayerLineup", false)
	_populate_container(player_bench, "PlayerBench", false)
	_populate_container(enemy_lineup, "EnemyLineup", true)
	_populate_enemy_trinkets()
	
	_update_traits("PLAYER")
	_update_traits("ENEMY")
	call_deferred("_refresh_trait_hud_positions")

	var discard_container = battle_manager.get_container(&"DiscardPile")
	if is_instance_valid(discard_container):
		var discard_count = discard_container.get_all_non_empty_uuids().size()
		discard_pile_button.text = tr("ui.discard_pile_count") % discard_count

func _populate_container(ui_container: HBoxContainer, container_name: StringName, is_enemy: bool) -> void:
	if not is_instance_valid(battle_manager):
		return
	
	var data_container = battle_manager.get_container(container_name)
	if not is_instance_valid(data_container):
		return
	
	# 1. Get all PanelContainer nodes (the slots) from the UI container.
	var slots: Array[PanelContainer] = []
	for child in ui_container.get_children():
		if child is PanelContainer:
			slots.append(child)

	# 2. Remove all children from every slot (except indicator and background).
	for slot in slots:
		for content in slot.get_children():
			# Skip the indicator overlay (z_index 10) and slot background (z_index -1)
			if content is TextureRect and (content.z_index == 10 or content.z_index == -1):
				continue
			content.queue_free()

	var uuids = data_container.get_all_uuids()

	# 3. Iterate through the permanent slots and populate them with fresh data.
	for i in range(slots.size()):
		var slot = slots[i]
		var loc := LocationIdentifier.new()
		loc.container = container_name
		loc.index = i

		var instance: GachaBallInstance = null
		if i < uuids.size():
			var uuid = uuids[i]
			# If this UUID is currently animating, pretend the slot is empty so it doesn't snap in yet
			if not (uuid in _pending_animated_uuids):
				instance = battle_manager.get_instance(uuid)

		if is_instance_valid(instance):
			# Create visual data using the adapter, pass all_instances for equipped items
			var visual_data = VisualDataAdapter.create_visual_data(instance, battle_manager.get_all_instances())
			
			# Use SlotView's set_content to populate the view
			# This handles instantiation and population of GachaBallView internally
			slot.set_content(visual_data, true, is_enemy, is_enemy)
			
			# EnemyLineup must be inspection-only: configure GachaBallView accordingly
			# Note: We need to access the child view to set interaction context if needed,
			# but SlotView should ideally handle this. For now, we can access the child.
			if container_name == &"EnemyLineup":
				var def = instance.get_definition()
				if is_instance_valid(def):
					if slot.get_child_count() > 0:
						# Find GachaBallView among children (indicator TextureRect may also be present)
						var view: GachaBallView = null
						for child in slot.get_children():
							if child is GachaBallView:
								view = child
								break
						if is_instance_valid(view):
							# In test mode, allow full interaction with enemy units
							if battle_manager.is_test_mode:
								view.set_interaction_context(&"FULLY_INTERACTIVE", def.category, 0)
							else:
								view.set_interaction_context(&"INSPECTION_ONLY", def.category, 0)

			slot.set_meta("location_identifier", loc)
		else:
			# If this slot is already a SlotView instance, simply update its location metadata.
			if slot.get_script() == preload("res://scripts/SlotView.gd"):
				slot.populate(loc)
				slot.set_meta("location_identifier", loc)
				# Ensure it's empty
				slot.set_content({}, false, false, false)
				# EnemyLineup must be inspection-only: configure SlotView accordingly
				if container_name == &"EnemyLineup":
					# In test mode, allow full interaction with enemy slots
					if battle_manager.is_test_mode:
						slot.set_interaction_context(&"FULLY_INTERACTIVE", 0)
					else:
						slot.set_interaction_context(&"INSPECTION_ONLY", 0)
				continue

			# Otherwise replace placeholder PanelContainer with a proper SlotView prefab.
			var parent := slot.get_parent()
			var idx: int = slot.get_index()
			# Remove placeholder; queue_free so Godot cleans up after this frame.
			slot.queue_free()
			var slot_view: PanelContainer = preload("res://scenes/SlotView.tscn").instantiate()
			parent.add_child(slot_view)
			parent.move_child(slot_view, idx)
			# Populate location data so it can handle clicks/drops.
			slot_view.populate(loc)
			slot_view.set_meta("location_identifier", loc)
			
			# Apply battle-specific layout settings (responsive width, fixed height)
			# Apply battle-specific layout settings (responsive width, fixed height)
			if is_instance_valid(slot_view):
				slot_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				slot_view.custom_minimum_size = Vector2(0, 250)
				
				# Apply container-specific color scheme
				if slot_view.has_method("set_slot_color"):
					slot_view.set_slot_color(container_name)
				# EnemyLineup must be inspection-only: configure SlotView accordingly
				if container_name == &"EnemyLineup":
					slot_view.set_interaction_context(&"INSPECTION_ONLY", 0)


func _on_battle_phase_changed(phase_name: StringName) -> void:
	var is_management_phase = (phase_name == &"MANAGEMENT")
	var is_combat = (phase_name == &"COMBAT")
	# End Turn is only available during MANAGEMENT
	end_turn_button.disabled = not is_management_phase
	# Contextual/discovery buttons should be disabled only during COMBAT
	discard_pile_button.disabled = is_combat
	
	var main_node = get_tree().get_root().find_child("Main", true, false)
	if not is_instance_valid(main_node): return
	
	var draw_buttons_parent = main_node.get_node_or_null("VBoxContainer/BottomArea/HBoxContainer")
	if is_instance_valid(draw_buttons_parent):
		for button in draw_buttons_parent.get_children():
			if button is Button and button.name.begins_with("DrawTier"):
				button.disabled = is_combat
			# Also disable the InspectInventory button outside the battle view
			var inspect_btn := draw_buttons_parent.get_node_or_null("InspectInventoryButton")
			if inspect_btn is Button:
				inspect_btn.disabled = is_combat

	# Only redraw when entering MANAGEMENT phase (after all animations complete)
	# During animation phases (START_OF_TURN, COMBAT, END_OF_TURN), BattleAnimator
	# owns all views and updates them based on recorded events. Redrawing during
	# these phases destroys the views BattleAnimator is managing.
	if phase_name == &"MANAGEMENT":
		_redraw_board()

func _gui_input(event) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		print("DEBUG_INPUT: BattleView Background Clicked.")
		# Create and emit InteractionContext for battle background
		var context = InteractionContext.new()
		context.source_view_instance_id = get_instance_id()
		context.event_type = &"SINGLE_CLICK"
		context.location = null # No specific location for background
		context.entity_uuid = ""
		context.entity_type = &"GLOBAL_BACKGROUND"
		context.interaction_mode = &"FULLY_INTERACTIVE"
		context.window_group_id = 0 # Main battle scene
		
		SignalBus.emit_signal("interaction_context_received", context)

func _populate_enemy_trinkets() -> void:
	if not is_instance_valid(battle_manager):
		return
	var slots = enemy_trinket_bar.get_children()
	for i in range(slots.size()):
		var slot_view = slots[i]
		for child in slot_view.get_children():
			# Skip the indicator overlay (z_index 10) and slot background (z_index -1)
			if child is TextureRect and (child.z_index == 10 or child.z_index == -1):
				continue
			child.queue_free()
		var loc = LocationIdentifier.new()
		loc.container = &"EnemyTrinkets"
		loc.index = i
		
		# Validate slot_view before method calls
		if not is_instance_valid(slot_view):
			continue
			
		# Use 2x scale for enemy trinkets (128x128 display, 64x64 native texture)
		if slot_view.has_method("set_size_scale"):
			slot_view.set_size_scale(2.0)
		if slot_view.has_method("populate"):
			slot_view.populate(loc)
			if slot_view.has_method("set_interaction_context"):
				slot_view.set_interaction_context(&"INSPECTION_ONLY", 0)
		if i < battle_manager.enemy_trinkets.size():
			var instance = battle_manager.enemy_trinkets[i]
			if is_instance_valid(instance):
				var visual_data = VisualDataAdapter.create_visual_data(instance)
				slot_view.set_content(visual_data, true, true, false)
				if slot_view.get_child_count() > 0:
					# Find GachaBallView among children (indicator TextureRect may also be present)
					var view: GachaBallView = null
					for child in slot_view.get_children():
						if child is GachaBallView:
							view = child
							break
					if is_instance_valid(view) and view.has_method("set_interaction_context"):
						view.set_interaction_context(&"INSPECTION_ONLY", &"TRINKET", 0)

func _update_traits(team: String) -> void:
	if not is_instance_valid(battle_manager):
		return
	
	var container = player_traits if team == "PLAYER" else enemy_traits
	if not is_instance_valid(container):
		return
			
	# Clear existing
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

	var ordered_active_traits = _get_ordered_active_traits(team)
	for trait_entry in ordered_active_traits:
		if not TraitTrackerScene:
			break
		var tracker = TraitTrackerScene.instantiate()
		container.add_child(tracker)
		tracker.populate(trait_entry["trait"], trait_entry["count"], true)
	_layout_trait_trackers(container, team == "ENEMY")

func _get_ordered_active_traits(team: String) -> Array[Dictionary]:
	var ordered_active_traits: Array[Dictionary] = []
	var all_traits: Dictionary = battle_manager.get_active_traits(team)

	for i in range(TRAIT_SORT_ORDER.size()):
		var trait_name: String = TRAIT_SORT_ORDER[i]
		var count: int = all_traits.get(trait_name, 0)
		if count < _get_trait_activation_threshold(trait_name):
			continue

		ordered_active_traits.append({
			"trait": trait_name,
			"count": count,
			"level": _get_trait_active_level(trait_name, count),
			"order": i
		})

	ordered_active_traits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["level"] != b["level"]:
			return a["level"] > b["level"]
		if a["count"] != b["count"]:
			return a["count"] > b["count"]
		return a["order"] < b["order"]
	)

	return ordered_active_traits

func _get_trait_activation_threshold(trait_name: String) -> int:
	var trait_definition: Dictionary = C.TRAIT_DEFINITIONS.get(trait_name, {})
	var levels: Array = trait_definition.get("levels", [])
	if levels.is_empty():
		return 999
	return int(levels[0].get("min", 999))

func _get_trait_active_level(trait_name: String, count: int) -> int:
	var trait_definition: Dictionary = C.TRAIT_DEFINITIONS.get(trait_name, {})
	var levels: Array = trait_definition.get("levels", [])
	var level: int = 0
	for entry in levels:
		var min_required: int = int(entry.get("min", 0))
		if count >= min_required:
			level += 1
	return level

func _update_trait_hud_positions() -> void:
	if not is_instance_valid(_trait_hud_root) or not is_instance_valid(_player_trait_anchor) or not is_instance_valid(_enemy_trait_anchor):
		return
	var hud_width := _trait_hud_root.size.x
	if hud_width <= 0.0:
		hud_width = get_viewport_rect().size.x

	var player_slot = _get_lineup_edge_slot(player_lineup, false)
	if is_instance_valid(player_slot):
		var player_left = player_slot.get_global_rect().position
		var to_hud_local: Transform2D = _trait_hud_root.get_global_transform().affine_inverse()
		var player_left_local = to_hud_local * player_left
		var clamped_player_x = clampf(player_left_local.x, TRAIT_SCREEN_MARGIN, maxf(TRAIT_SCREEN_MARGIN, hud_width - TRAIT_SCREEN_MARGIN))
		_player_trait_anchor.position = Vector2(clamped_player_x, TRAIT_HUD_Y)

	var enemy_slot = _get_lineup_edge_slot(enemy_lineup, true)
	if is_instance_valid(enemy_slot):
		var enemy_rect = enemy_slot.get_global_rect()
		var enemy_right = enemy_rect.position + Vector2(enemy_rect.size.x, 0)
		var to_hud_local: Transform2D = _trait_hud_root.get_global_transform().affine_inverse()
		var enemy_right_local = to_hud_local * enemy_right
		var clamped_enemy_x = clampf(enemy_right_local.x, TRAIT_SCREEN_MARGIN, maxf(TRAIT_SCREEN_MARGIN, hud_width - TRAIT_SCREEN_MARGIN))
		_enemy_trait_anchor.position = Vector2(clamped_enemy_x, TRAIT_HUD_Y)

	if is_instance_valid(player_traits):
		player_traits.position = Vector2.ZERO
	if is_instance_valid(enemy_traits):
		enemy_traits.position = Vector2.ZERO
	
	_clamp_trait_trackers_to_viewport(player_traits)
	_clamp_trait_trackers_to_viewport(enemy_traits)

func _get_lineup_edge_slot(lineup: HBoxContainer, use_rightmost: bool) -> PanelContainer:
	if not is_instance_valid(lineup):
		return null

	var slots: Array[PanelContainer] = []
	for child in lineup.get_children():
		if child is PanelContainer:
			slots.append(child)

	if slots.is_empty():
		return null

	# Prefer an occupied + visible edge slot so labels stay tied to active formation,
	# not to off-screen overflow slots when the lineup is wider than its area.
	if use_rightmost:
		for i in range(slots.size() - 1, -1, -1):
			var slot = slots[i]
			if _slot_has_unit(slot) and _slot_is_visible(slot):
				return slot
		for i in range(slots.size() - 1, -1, -1):
			var slot = slots[i]
			if _slot_has_unit(slot):
				return slot
		return slots[slots.size() - 1]

	for slot in slots:
		if _slot_has_unit(slot) and _slot_is_visible(slot):
			return slot
	for slot in slots:
		if _slot_has_unit(slot):
			return slot
	return slots[0]

func _slot_has_unit(slot: PanelContainer) -> bool:
	if not is_instance_valid(slot):
		return false
	for child in slot.get_children():
		if child is GachaBallView:
			return true
	return false

func _slot_is_visible(slot: PanelContainer) -> bool:
	if not is_instance_valid(slot):
		return false
	var slot_rect = slot.get_global_rect()
	var viewport_width = get_viewport_rect().size.x
	return slot_rect.position.x < viewport_width and (slot_rect.position.x + slot_rect.size.x) > 0.0

func _layout_trait_trackers(container: Control, align_right: bool) -> void:
	if not is_instance_valid(container):
		return
	
	var cursor: float = 0.0
	for child in container.get_children():
		if not (child is Control):
			continue
		var tracker := child as Control
		var tracker_size = tracker.get_combined_minimum_size()
		tracker.size = tracker_size
		if align_right:
			cursor += tracker_size.x
			tracker.position = Vector2(-cursor, 0.0)
			cursor += TRAIT_TRACKER_SPACING
		else:
			tracker.position = Vector2(cursor, 0.0)
			cursor += tracker_size.x + TRAIT_TRACKER_SPACING

func _clamp_trait_trackers_to_viewport(container: Control) -> void:
	if not is_instance_valid(container):
		return
	
	var viewport_width = get_viewport_rect().size.x
	var min_x: float = INF
	var max_x: float = -INF
	
	for child in container.get_children():
		if not (child is Control):
			continue
		var ctrl := child as Control
		var rect = ctrl.get_global_rect()
		min_x = minf(min_x, rect.position.x)
		max_x = maxf(max_x, rect.position.x + rect.size.x)
	
	if min_x == INF or max_x == -INF:
		return
	
	var delta_x: float = 0.0
	if min_x < TRAIT_SCREEN_MARGIN:
		delta_x += (TRAIT_SCREEN_MARGIN - min_x)
	if max_x + delta_x > viewport_width - TRAIT_SCREEN_MARGIN:
		delta_x -= (max_x + delta_x - (viewport_width - TRAIT_SCREEN_MARGIN))
	
	if absf(delta_x) > 0.1:
		container.position.x += delta_x

func _on_viewport_size_changed() -> void:
	call_deferred("_refresh_trait_hud_positions")

func _on_lineup_resized() -> void:
	call_deferred("_refresh_trait_hud_positions")

func _refresh_trait_hud_positions() -> void:
	await get_tree().process_frame
	_update_trait_hud_positions()

# --- Gacha Animation Logic ---

var _pending_animated_uuids: Array[String] = []

func _on_gacha_draw_animated(draw_result) -> void:
	# Add the drawn UUID to the pending list. This prevents _populate_container from
	# showing it in the grid prematurely (it will be filtered out).
	if draw_result.drawn_uuid:
		_pending_animated_uuids.append(draw_result.drawn_uuid)
	
	# Attempt to find the Gacha Machine (Start Position)
	var main_node = get_tree().get_root().find_child("Main", true, false)
	if not is_instance_valid(main_node):
		_force_refresh_after_anim()
		return
	
	# Assuming machines are GachaMachine1, GachaMachine2, GachaMachine3
	# and we need to map Tier (int) to Machine (1/2/3)
	# The Tier comes from battle_manager.get_inventory_tier_instances(tier) context?
	# Wait, draw_result doesn't have Tier. But bm_draw_gacha_instance was called with tier.
	# We need the source tier to determine the machine.
	# InventoryOperations.DrawResult does NOT store "tier" but it stores "source_container".
	# source_container = "BattleInventoryT%d" % tier.
	var tier = 1
	if draw_result.source_container.ends_with("T2"): tier = 2
	elif draw_result.source_container.ends_with("T3"): tier = 3
	
	var machine_path = "VBoxContainer/BottomArea/HBoxContainer/GachaMachine%d/KnobButton" % tier
	var knob_node = main_node.get_node_or_null(machine_path)
	var start_pos: Vector2
	if knob_node:
		start_pos = knob_node.get_global_rect().get_center()
	else:
		start_pos = get_viewport_rect().get_center() # Fallback
	
	# Trigger machine bounce when ball pops out
	if main_node.has_method("trigger_machine_bounce"):
		main_node.trigger_machine_bounce(tier)
	
	# Determine End Position
	var end_pos: Vector2
	var dest_slot_view: Control = null
	
	if draw_result.went_to_discard or draw_result.dest_container == "DiscardPile":
		end_pos = discard_pile_button.get_global_rect().get_center()
	else:
		# Map destination container to UI container
		var target_ui_container: HBoxContainer = null
		if draw_result.dest_container == "PlayerBench":
			target_ui_container = player_bench
		
		if target_ui_container and draw_result.dest_slot >= 0 and draw_result.dest_slot < target_ui_container.get_child_count():
			dest_slot_view = target_ui_container.get_child(draw_result.dest_slot)
			end_pos = dest_slot_view.get_global_rect().get_center()
		else:
			# Fallback if slot not found
			end_pos = start_pos
	
	# Spawn animated ball
	var anim_ball = GachaBallViewScene.instantiate()
	
	# Add to effects layer FIRST (ensures @onready vars are initialized)
	var effects_layer = main_node.get_node_or_null("EffectsLayer")
	if effects_layer:
		effects_layer.add_child(anim_ball)
	else:
		add_child(anim_ball)
	
	# Configure visual style: Force "Inventory Mode" (2x scale, overlay, circle)
	anim_ball.force_inventory_mode = true
	anim_ball.custom_minimum_size = Vector2(192, 192)
	anim_ball.size = Vector2(192, 192)
	
	# Populate with visual data (after added to tree so @onready vars work)
	var instance = battle_manager.get_instance(draw_result.drawn_uuid)
	if is_instance_valid(instance):
		var visual_data = VisualDataAdapter.create_visual_data(instance)
		anim_ball.populate(null, visual_data)
	
	# Set pivot to center for proper centering during animation
	anim_ball.pivot_offset = anim_ball.size / 2.0
	
	# Calculate final target position (CENTER of the slot)
	# end_pos is already the center of the slot rect from get_global_rect().get_center()
	# We want anim_ball's CENTER to land there, so we position anim_ball such that:
	# anim_ball.global_position + pivot_offset = end_pos
	# => anim_ball.global_position = end_pos - pivot_offset
	# But pivot_offset is in local coords, scaled by scale. At final scale (1.0), it's size/2.
	
	# For animation, we'll track the CENTER position and derive global_position from it
	var start_center: Vector2 = start_pos
	# Offset end position DOWN significantly to land in the visual center of the slot
	# The ball is 192px, the slot is ~250px tall, and anchoring is top-left
	# So we need to offset by roughly half the ball size to center it vertically
	var end_center: Vector2 = end_pos + Vector2(0, 96) # Ball radius (192/2) to center
	
	# Initial setup: place ball at start (small scale, centered on knob)
	var initial_scale := 0.3
	anim_ball.scale = Vector2(initial_scale, initial_scale)
	# Position so that visual center is at start_center
	anim_ball.global_position = start_center - (anim_ball.pivot_offset * initial_scale)
	
	# Arc parameters
	var arc_height := 400.0 # Peak height above the highest point
	var duration := 0.45 # Snappy fast animation
	
	# Quadratic Bezier curve for natural basketball arc
	# P0 = start_center (launch point)
	# P1 = control point (apex of the arc)
	# P2 = end_center (landing point)
	var control_point := Vector2(
		(start_center.x + end_center.x) / 2.0, # Horizontally centered
		min(start_center.y, end_center.y) - arc_height # Above both points
	)
	
	# Use tween_method to animate along the Bezier curve
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	
	# Animate t from 0 to 1
	tween.tween_method(func(t: float):
		# VIOLENT POP-OUT with snappy landing
		# Ball shoots out fast, slows at peak, then accelerates down
		var eased_t = pow(t, 0.55) # Fast start AND snappy landing
		
		# Scale animation (grows quickly then settles)
		var scale_eased = 1.0 - pow(1.0 - t, 2)
		var current_scale = lerp(initial_scale, 1.0, scale_eased)
		anim_ball.scale = Vector2(current_scale, current_scale)
		
		# Quadratic Bezier formula: P = (1-t)²*P0 + 2*(1-t)*t*P1 + t²*P2
		var inv_t = 1.0 - eased_t
		var pos = (inv_t * inv_t * start_center) + \
				  (2.0 * inv_t * eased_t * control_point) + \
				  (eased_t * eased_t * end_center)
		
		# Position ball so its CENTER is at pos
		anim_ball.global_position = pos - (anim_ball.pivot_offset * current_scale)
	, 0.0, 1.0, duration)
	
	# Clean up after animation
	tween.tween_callback(func():
		anim_ball.queue_free()
		_force_refresh_after_anim(draw_result)
	)

func _force_refresh_after_anim(draw_result = null) -> void:
	if draw_result and draw_result.drawn_uuid:
		_pending_animated_uuids.erase(draw_result.drawn_uuid)
	
	_redraw_board()
	
	# Trigger bounce animation on the landed unit/item
	if draw_result == null:
		return
	
	# Skip bounce for discard pile
	if draw_result.went_to_discard or draw_result.dest_container == "DiscardPile":
		return
	
	# Show first draw tutorial (3 pages) - only on first successful draw
	TutorialManager.show_tutorial(&"first_draw", [
		{"text": tr("tutorial.first_draw_1")},
		{"text": tr("tutorial.first_draw_2")},
		{"text": tr("tutorial.first_draw_3")}
	])
	
	# Wait one frame for the redraw to complete (queue_free doesn't happen immediately)
	await get_tree().process_frame
	
	# Find the target slot
	var target_ui_container: HBoxContainer = null
	if draw_result.dest_container == "PlayerBench":
		target_ui_container = player_bench
	
	if not target_ui_container:
		return
	if draw_result.dest_slot < 0 or draw_result.dest_slot >= target_ui_container.get_child_count():
		return
	
	var slot = target_ui_container.get_child(draw_result.dest_slot)
	
	# Find the GachaBallView inside the slot
	var ball_view: GachaBallView = null
	for child in slot.get_children():
		if child is GachaBallView:
			ball_view = child
			break
	
	if not is_instance_valid(ball_view):
		return
	
	# Access the icon_rect directly from the GachaBallView (it's a public property)
	var icon_rect = ball_view.icon_rect
	if not is_instance_valid(icon_rect):
		return
	
	# Rubber ball bounce animation - squish on landing, then stretch up, settle
	var bounce_tween = create_tween()
	
	# Store pivot for centered scaling
	icon_rect.pivot_offset = icon_rect.size / 2.0
	
	# Phase 1: Squish on impact (compress vertically, stretch horizontally)
	bounce_tween.tween_property(icon_rect, "scale", Vector2(1.2, 0.8), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Phase 2: Stretch upward (bounce up)
	bounce_tween.tween_property(icon_rect, "scale", Vector2(0.9, 1.15), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Phase 3: Small squish
	bounce_tween.tween_property(icon_rect, "scale", Vector2(1.05, 0.95), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# Phase 4: Settle to normal
	bounce_tween.tween_property(icon_rect, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# VCR PATTERN: AFTER bounce completes, trigger management phase effects
	# This uses the same simulation-presentation pattern as combat
	bounce_tween.tween_callback(func():
		_trigger_on_draw_effects(draw_result)
	)

## Trigger management phase effects for a drawn unit/item (e.g., Royal Insignia buff)
## Uses the VCR pattern: capture snapshot, simulate effects, animate via BattleAnimator
func _trigger_on_draw_effects(draw_result) -> void:
	if not is_instance_valid(battle_manager):
		return
	
	# Get the drawn instance to check tags
	var drawn_instance = battle_manager.get_instance(draw_result.drawn_uuid)
	if not is_instance_valid(drawn_instance):
		return
	
	# Determine tier from source container (also equals token cost)
	var tier := 1
	if draw_result.source_container.ends_with("T2"):
		tier = 2
	elif draw_result.source_container.ends_with("T3"):
		tier = 3
	
	# Build context for on_draw trigger
	var context := {
		"drawn_uuid": draw_result.drawn_uuid,
		"dest_container": draw_result.dest_container,
		"dest_slot": draw_result.dest_slot,
		"tier": tier,
		"tokens_spent": tier # Tier equals tokens spent
	}
	
	# VCR Step 1: Capture snapshot BEFORE simulation
	var snapshot := battle_manager.get_board_snapshot()
	
	# VCR Step 2a: Trigger on_draw (once per draw)
	AbilityResolver.process_trigger(&"on_draw", context)
	
	# VCR Step 2b: Trigger on_token_spent (once per draw, with token amount in context)
	AbilityResolver.process_trigger(&"on_token_spent", context)
	
	# VCR Step 3: If effects were generated, resolve and animate them
	if battle_manager._pending_reactions.size() > 0:
		battle_manager.resolve_management_effects_and_animate(snapshot)
