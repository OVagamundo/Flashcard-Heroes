class_name InventoryWindow
extends Control

const _GachaBallView = preload("res://scenes/GachaBallView.tscn")
const _SlotView = preload("res://scenes/SlotView.tscn")
const InputUtils = preload("res://scripts/InputUtils.gd")

@onready var panel_container: PanelContainer = %PanelContainer
@onready var tier_1_grid: Container = %Tier1Grid
@onready var tier_2_grid: Container = %Tier2Grid
@onready var tier_3_grid: Container = %Tier3Grid
@onready var tier_1_panel: PanelContainer = $"PanelContainer/VBoxContainer/GridsArea/Tier1Panel"
@onready var tier_2_panel: PanelContainer = $"PanelContainer/VBoxContainer/GridsArea/Tier2Panel"
@onready var tier_3_panel: PanelContainer = $"PanelContainer/VBoxContainer/GridsArea/Tier3Panel"
@onready var tier_1_scroll: ScrollContainer = %Tier1Grid.get_parent() as ScrollContainer
@onready var tier_2_scroll: ScrollContainer = %Tier2Grid.get_parent() as ScrollContainer
@onready var tier_3_scroll: ScrollContainer = %Tier3Grid.get_parent() as ScrollContainer



var _data_source: Dictionary
var _grids_initialized: bool = false
const DRAG_SCROLL_ZONE_PX: float = 58.0
const DRAG_SCROLL_MAX_SPEED: float = 920.0

func _ready() -> void:
	panel_container.gui_input.connect(_on_panel_gui_input)
	SignalBus.inventory_ui_refresh_requested.connect(_on_ui_refresh)
	tier_1_grid.gui_input.connect(_on_grid_gui_input)
	tier_2_grid.gui_input.connect(_on_grid_gui_input)
	tier_3_grid.gui_input.connect(_on_grid_gui_input)
	
	_configure_scroll_navigation()
	set_process(true)
	# Initial state check
	process_mode = PROCESS_MODE_INHERIT if visible else PROCESS_MODE_DISABLED

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_node_ready():
			# Disable ALL processing (including physics) when hidden to prevent
			# overlapping colliders from interfering with other windows (like BattleInventory).
			process_mode = PROCESS_MODE_INHERIT if visible else PROCESS_MODE_DISABLED

func _configure_scroll_navigation() -> void:
	# Keep overflow bounded by inventory/tier panels.
	panel_container.clip_contents = true
	tier_1_panel.clip_contents = true
	tier_2_panel.clip_contents = true
	tier_3_panel.clip_contents = true

	for scroll in _get_tier_scrolls():
		if not is_instance_valid(scroll):
			continue
		# Keep slot visuals strictly contained inside each tier container artwork.
		scroll.clip_contents = true
		scroll.custom_minimum_size.x = maxf(scroll.custom_minimum_size.x, 608.0)
		scroll.mouse_filter = Control.MOUSE_FILTER_PASS
		
		var vbar: VScrollBar = scroll.get_v_scroll_bar()
		if not is_instance_valid(vbar):
			continue
		
		# Make scrollbar finger-friendly.
		vbar.custom_minimum_size = Vector2(30.0, 96.0)
		vbar.mouse_filter = Control.MOUSE_FILTER_STOP
		
		# Improve visual affordance for the drag handle.
		var rail := StyleBoxFlat.new()
		rail.bg_color = Color(0.16, 0.16, 0.24, 0.72)
		rail.corner_radius_top_left = 8
		rail.corner_radius_top_right = 8
		rail.corner_radius_bottom_left = 8
		rail.corner_radius_bottom_right = 8
		
		var grabber := StyleBoxFlat.new()
		grabber.bg_color = Color(0.82, 0.83, 0.95, 0.96)
		grabber.corner_radius_top_left = 8
		grabber.corner_radius_top_right = 8
		grabber.corner_radius_bottom_left = 8
		grabber.corner_radius_bottom_right = 8
		
		var grabber_hot := grabber.duplicate() as StyleBoxFlat
		grabber_hot.bg_color = Color(0.93, 0.94, 1.0, 1.0)
		
		vbar.add_theme_stylebox_override("scroll", rail)
		vbar.add_theme_stylebox_override("scroll_focus", rail)
		vbar.add_theme_stylebox_override("grabber", grabber)
		vbar.add_theme_stylebox_override("grabber_highlight", grabber_hot)
		vbar.add_theme_stylebox_override("grabber_pressed", grabber_hot)

func _get_tier_scrolls() -> Array[ScrollContainer]:
	return [tier_1_scroll, tier_2_scroll, tier_3_scroll]

func _process(delta: float) -> void:
	_auto_scroll_during_drag(delta)

func _auto_scroll_during_drag(delta: float) -> void:
	if not visible:
		return
	if not GlobalInteractionRouter.is_drag_active():
		return
	
	var mouse_pos: Vector2 = get_global_mouse_position()
	for scroll in _get_tier_scrolls():
		if not is_instance_valid(scroll):
			continue
		var rect: Rect2 = scroll.get_global_rect()
		if not rect.has_point(mouse_pos):
			continue
		
		var direction: float = 0.0
		var top_limit: float = rect.position.y + DRAG_SCROLL_ZONE_PX
		var bottom_limit: float = rect.end.y - DRAG_SCROLL_ZONE_PX
		
		if mouse_pos.y < top_limit:
			direction = - (1.0 - clampf((mouse_pos.y - rect.position.y) / DRAG_SCROLL_ZONE_PX, 0.0, 1.0))
		elif mouse_pos.y > bottom_limit:
			direction = 1.0 - clampf((rect.end.y - mouse_pos.y) / DRAG_SCROLL_ZONE_PX, 0.0, 1.0)
		
		if is_zero_approx(direction):
			continue
		
		var vbar: VScrollBar = scroll.get_v_scroll_bar()
		if not is_instance_valid(vbar):
			continue
		
		var max_value: int = int(ceil(vbar.max_value))
		var next_scroll: int = int(round(scroll.scroll_vertical + direction * DRAG_SCROLL_MAX_SPEED * delta))
		scroll.scroll_vertical = clampi(next_scroll, 0, max_value)

func _exit_tree() -> void:
	if SignalBus.is_connected("inventory_ui_refresh_requested", _on_ui_refresh):
		SignalBus.inventory_ui_refresh_requested.disconnect(_on_ui_refresh)
	# Disconnect child gui_input hooks if still connected
	if is_instance_valid(panel_container) and panel_container.gui_input.is_connected(_on_panel_gui_input):
		panel_container.gui_input.disconnect(_on_panel_gui_input)
	if is_instance_valid(tier_1_grid) and tier_1_grid.gui_input.is_connected(_on_grid_gui_input):
		tier_1_grid.gui_input.disconnect(_on_grid_gui_input)
	if is_instance_valid(tier_2_grid) and tier_2_grid.gui_input.is_connected(_on_grid_gui_input):
		tier_2_grid.gui_input.disconnect(_on_grid_gui_input)
	if is_instance_valid(tier_3_grid) and tier_3_grid.gui_input.is_connected(_on_grid_gui_input):
		tier_3_grid.gui_input.disconnect(_on_grid_gui_input)
	# Ensure any active drag is ended before this window and its children are freed,
	# BUT ONLY if the drag originated from within this window to prevent canceling unrelated drags.
	if GlobalInteractionRouter.is_drag_active():
		var source_view = GlobalInteractionRouter.get_drag_source_view()
		if is_instance_valid(source_view) and (source_view == self or self.is_ancestor_of(source_view)):
			GlobalInteractionRouter.end_drag(false)
			GlobalInteractionRouter.end_drag_visuals(false)

func populate(context: Dictionary) -> void:
	_data_source = context.get("inventory")
	
	# Trigger the initial population and drawing of the grids.
	_populate_grids()
	
	# Show run-mode inventory tutorial (deferred to allow window to render)
	call_deferred("_show_inventory_tutorial")


func _show_inventory_tutorial() -> void:
	"""Show the run-mode inventory tutorial after the window renders"""
	TutorialManager.show_tutorial(&"gacha_inspect_run", [
		{"text": "tutorial.gacha_inspect_run"}
	])

func _on_ui_refresh() -> void:
	if not self.visible:
		return
	# On refresh, just re-populate the content of the existing slots.
	_populate_grids()

func _on_panel_gui_input(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		if GlobalInteractionRouter.is_drag_active():
			GlobalInteractionRouter.end_drag(false)
			return
		
		# Create and emit InteractionContext for window background
		var context = InteractionContext.new()
		context.source_view_instance_id = get_instance_id()
		context.event_type = &"SINGLE_CLICK"
		context.location = null # No specific location for background
		context.entity_uuid = ""
		context.entity_type = &"WINDOW_BACKGROUND"
		context.interaction_mode = &"FULLY_INTERACTIVE"
		context.window_group_id = 1 # Inspection windows group
		
		SignalBus.emit_signal("interaction_context_received", context)
		get_viewport().set_input_as_handled()
		if InputUtils.is_touch_pointer_event(event):
			accept_event()

func _on_grid_gui_input(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		# Only clear selection if the click is not on a SlotView
		var target = get_viewport().gui_get_focus_owner()
		if not (target and target is SlotView):
			# Create and emit InteractionContext for grid background
			var context = InteractionContext.new()
			context.source_view_instance_id = get_instance_id()
			context.event_type = &"SINGLE_CLICK"
			context.location = null # No specific location for grid background
			context.entity_uuid = ""
			context.entity_type = &"WINDOW_BACKGROUND"
			context.interaction_mode = &"FULLY_INTERACTIVE"
			context.window_group_id = 1 # Inspection windows group
			
			SignalBus.emit_signal("interaction_context_received", context)
			get_viewport().set_input_as_handled()
			if InputUtils.is_touch_pointer_event(event):
				accept_event()

func _initialize_grids_if_needed() -> void:
	if _grids_initialized:
		return
	
	# Inventory uses 2x scale square slots (matches 2x gachaball)
	
	var grids: Dictionary = {1: tier_1_grid, 2: tier_2_grid, 3: tier_3_grid}
	for tier in grids:
		var grid_node = grids[tier]
		var container_name = &"RunInventoryT%d" % tier
		var container: DataContainer = _data_source.get(container_name)
		if not is_instance_valid(container):
			continue
			
		var slot_count = 39 # HARDCAP: Staggered grid max capacity at 0 padding
		for i in range(slot_count):
			var slot_view = _SlotView.instantiate()
			# Use 1x scale for inventory window
			slot_view.set_size_scale(1.0)
			# Force square slots matching 1x base size
			slot_view.custom_minimum_size = Vector2(C.SLOT_SIZE_BASE, C.SLOT_SIZE_BASE)
			grid_node.add_child(slot_view)
			# Configure interaction context for run inventory slots (FULLY_INTERACTIVE)
			slot_view.set_interaction_context(&"FULLY_INTERACTIVE", 0)
		
	
	_grids_initialized = true

func _populate_grids() -> void:
	if not _data_source:
		return

	# Scroll containers always visible in run mode
	tier_1_scroll.visible = true
	tier_2_scroll.visible = true
	tier_3_scroll.visible = true
	
	# Disable Scrolling since we have a hard-capped zero-padding grid 
	tier_1_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tier_1_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tier_2_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tier_2_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tier_3_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tier_3_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	# This will create the 16 SlotViews per grid, but only on the first run.
	_initialize_grids_if_needed()

	var data_owner = GameManager.run_state
	if not is_instance_valid(data_owner):
		return

	# --- Step 1: Correctly identify all equipped items ---
	var equipped_item_uuids: Dictionary = {}
	var unit_container_names: Array[StringName] = [&"PlayerLineup", &"PlayerBench"]
	for container_name in unit_container_names:
		var unit_container = data_owner.get_container(container_name)
		if is_instance_valid(unit_container):
			var all_uuids_in_container = unit_container.get_all_uuids()
			for i in range(all_uuids_in_container.size()):
				var loc = LocationIdentifier.new(container_name, i)
				var unit_instance = GameManager.get_instance_from_location(loc)
				if is_instance_valid(unit_instance):
					for item_uuid in unit_instance.equipped_item_uuids:
						if not item_uuid.is_empty():
							equipped_item_uuids[item_uuid] = true

	# --- Step 2: Iterate through the persistent slots and update their content ---
	var grids: Dictionary = {1: tier_1_grid, 2: tier_2_grid, 3: tier_3_grid}
	for tier in grids:
		var grid_node = grids[tier]
		var container_name = &"RunInventoryT%d" % tier
		var container: DataContainer = _data_source.get(container_name)
		if not is_instance_valid(container):
			continue

		var all_uuids = container.get_all_uuids()
		var slot_views = grid_node.get_children()

		for i in range(slot_views.size()):
			var slot_view: SlotView = slot_views[i]
			# Clear any previous content (except indicator and background)
			for child in slot_view.get_children():
				# Skip the indicator overlay (z_index 10) and slot background (z_index -1)
				if child is TextureRect and (child.z_index == 10 or child.z_index == -1):
					continue
				child.queue_free()

			var loc = LocationIdentifier.new(container_name, i)
			slot_view.populate(loc) # Always update the location data on the slot
			# Ensure interaction context is set for run inventory
			slot_view.set_interaction_context(&"FULLY_INTERACTIVE", 0)

			if i >= all_uuids.size(): continue # Should not happen with growable containers

			var uuid_at_slot = all_uuids[i]
			if uuid_at_slot.is_empty() or equipped_item_uuids.has(uuid_at_slot):
				continue # Leave the slot empty

			var instance = GameManager.get_instance_from_location(loc)
			if is_instance_valid(instance):
				# Use adapter to create visual data
				var visual_data = VisualDataAdapter.create_visual_data(instance)
				slot_view.set_content(visual_data, true, false, false)
				
				# Configure interaction context - find GachaBallView among children
				var gacha_view: GachaBallView = null
				for child in slot_view.get_children():
					if child is GachaBallView:
						gacha_view = child
						break
				if is_instance_valid(gacha_view):
					gacha_view.set_interaction_context(&"FULLY_INTERACTIVE", instance.get_definition().category, 0)

func get_window_to_animate() -> Control:
	if is_instance_valid(panel_container):
		return panel_container
	return self
