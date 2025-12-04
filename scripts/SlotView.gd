class_name SlotView
extends PanelContainer

var _location: LocationIdentifier

# InteractionContext properties
var _interaction_mode: StringName = &"FULLY_INTERACTIVE"
var _window_group_id: int = 0

func _ready() -> void:
	# Add a simple stylebox to make the empty slot visible.
	var style = StyleBoxFlat.new()
	style.set_bg_color(Color(0, 0, 0, 0.2))
	style.set_border_width_all(1)
	style.set_border_color(Color(0.5, 0.5, 0.5, 0.5))
	add_theme_stylebox_override("panel", style)
	
	# Connect to unit stats changed signal to update content
	SignalBus.unit_stats_changed.connect(_on_unit_stats_changed)

## Set custom color for this slot based on container type
func set_slot_color(container_name: StringName) -> void:
	var style = StyleBoxFlat.new()
	
	# Define color schemes for different container types
	match container_name:
		&"PlayerLineup":
			style.set_bg_color(Color(0.15, 0.2, 0.3, 0.3))
			style.set_border_width_all(2)
			style.set_border_color(Color(0.3, 0.5, 0.8, 0.6))
		&"PlayerBench":
			style.set_bg_color(Color(0.15, 0.25, 0.15, 0.3))
			style.set_border_width_all(2)
			style.set_border_color(Color(0.3, 0.7, 0.3, 0.6))
		&"ItemInventory":
			style.set_bg_color(Color(0.25, 0.15, 0.25, 0.3))
			style.set_border_width_all(2)
			style.set_border_color(Color(0.7, 0.3, 0.7, 0.6))
		&"EnemyLineup":
			style.set_bg_color(Color(0.3, 0.15, 0.15, 0.3))
			style.set_border_width_all(2)
			style.set_border_color(Color(0.8, 0.3, 0.3, 0.6))
		_:
			# Default color scheme
			style.set_bg_color(Color(0, 0, 0, 0.2))
			style.set_border_width_all(1)
			style.set_border_color(Color(0.5, 0.5, 0.5, 0.5))
	
	add_theme_stylebox_override("panel", style)

func _exit_tree() -> void:
	if SignalBus.unit_stats_changed.is_connected(_on_unit_stats_changed):
		SignalBus.unit_stats_changed.disconnect(_on_unit_stats_changed)

	# If a drag is active while this slot is being freed, end it to prevent leaks
	if GlobalInteractionRouter.is_drag_active():
		GlobalInteractionRouter.end_drag(false)
		GlobalInteractionRouter.end_drag_visuals(false)

func _notification(_what) -> void:
	pass

func populate(loc: LocationIdentifier) -> void:
	self._location = loc
	set_meta("location_identifier", loc) # For InteractionManager and WindowManager

## Set the content of this slot using VisualData
func set_content(visual_data: Dictionary, is_inspectable: bool = true, single_click_inspect: bool = false, is_enemy: bool = false) -> void:
	# Clear existing content
	for child in get_children():
		child.queue_free()
	
	if visual_data.is_empty():
		return
	
	print("[SlotView] set_content called with visual_data: ", visual_data.get("uuid", "NO_UUID"))
	
	var gacha_ball_view_scene = load("res://scenes/GachaBallView.tscn")
	print("[SlotView] Loaded scene: ", gacha_ball_view_scene)
	
	if not is_instance_valid(gacha_ball_view_scene):
		push_error("[SlotView] GachaBallViewScene failed to load!")
		return
		
	var view = gacha_ball_view_scene.instantiate()
	
	if not is_instance_valid(view):
		push_error("[SlotView] Failed to instantiate GachaBallView!")
		return
	
	add_child(view)
	
	# Populate the view with visual data
	view.populate(_location, visual_data, is_inspectable, single_click_inspect)
	view.set_is_enemy(is_enemy)
	
	# Configure interaction context based on data/context
	if is_enemy:
		# Enemy logic (inspection only usually)
		pass
	
	view.set_meta("location_identifier", _location)


func _on_unit_stats_changed(unit_uuid: String) -> void:
	# CRITICAL: Do not update views during COMBAT phase
	# BattleAnimator owns all views during this phase (Puppet Mode)
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		if is_instance_valid(bm):
			# Check if BattleManager has get_current_phase method
			if bm.has_method("get_current_phase"):
				var phase = bm.get_current_phase()
				# During COMBAT, animator controls views - ignore signal
				if phase == 2: # Phases.COMBAT == 2
					return
	
	# Normal update logic (MANAGEMENT phase only)
	# Check if we have a child view that matches this UUID
	if get_child_count() > 0:
		var view = get_child(0)
		if view is GachaBallView and view.get_instance_uuid() == unit_uuid:
			# Fetch fresh data and update
			var instance = GameManager.get_instance_by_uuid(unit_uuid)
			if is_instance_valid(instance):
				var data = VisualDataAdapter.create_visual_data(instance)
				view.update_visuals(data)


## Configure the interaction context for this slot
func set_interaction_context(interaction_mode: StringName, window_group_id: int = 0) -> void:
	_interaction_mode = interaction_mode
	_window_group_id = window_group_id

## Create and emit InteractionContext for this slot
func _create_interaction_context(event_type: StringName) -> InteractionContext:
	var context = InteractionContext.new()
	context.source_view_instance_id = get_instance_id()
	context.event_type = event_type
	context.location = _location
	context.entity_uuid = "" # Empty slots have no entity
	context.entity_type = &"EMPTY_SLOT"
	context.interaction_mode = _interaction_mode
	context.window_group_id = _window_group_id
	return context

func _gui_input(event: InputEvent) -> void:
	if not is_instance_valid(_location): return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Do NOT consume the event here; allow child views to initiate drag
		# Create and emit InteractionContext
		var context = _create_interaction_context(&"SINGLE_CLICK")
		SignalBus.emit_signal("interaction_context_received", context)
		# If this is an empty slot (no child view), stop propagation so Main/Battle don't emit GLOBAL_BACKGROUND
		if get_child_count() == 0:
			get_viewport().set_input_as_handled()

func _can_drop_data(_at_position, data) -> bool:
	# Check if this is an inspection-only context
	if _interaction_mode == &"INSPECTION_ONLY":
		return false
		
	return data is Dictionary and data.has("source_loc")

func _drop_data(_at_position, data) -> void:
	# Check if this is an inspection-only context
	if _interaction_mode == &"INSPECTION_ONLY":
		return

	# Create a target interaction context and route via GIR
	var target_ctx = _create_interaction_context(&"DROP")
	SignalBus.emit_signal("interaction_context_received", target_ctx)

	# Do not end drag here; InventoryManager will decide handled/unhandled and
	# call GlobalInteractionRouter.end_drag(true/false) centrally.
