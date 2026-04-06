class_name BattleInventoryWindow
extends Control

@onready var tier_1_tray: BattleInventoryTrayRig = %Tier1Tray
@onready var tier_2_tray: BattleInventoryTrayRig = %Tier2Tray
@onready var tier_3_tray: BattleInventoryTrayRig = %Tier3Tray



var _base_y: float = 162.0
var _closed_y: float = 1300.0
var _is_open: bool = false
var _data_source: Dictionary

func _ready() -> void:
	# Ensure the trays are spaced out properly across the 1920 width
	if is_instance_valid(tier_1_tray):
		tier_1_tray.position = Vector2(0.0, 0.0)
	if is_instance_valid(tier_2_tray):
		tier_2_tray.position = Vector2(640.0, 0.0)
	if is_instance_valid(tier_3_tray):
		tier_3_tray.position = Vector2(1280.0, 0.0)
		
	tier_1_tray.position.x = 0.0
	tier_2_tray.position.x = 640.0
	tier_3_tray.position.x = 1280.0
	
	# Connect to game signals
	SignalBus.battle_inventory_changed.connect(_on_battle_inventory_changed)
	if has_node("BaseMask"):
		$BaseMask.z_index = 10
		
	# Initial state check
	process_mode = PROCESS_MODE_INHERIT if visible else PROCESS_MODE_DISABLED

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_node_ready():
			# This ensures that hidden windows never collide with active ones 
			# in the physics world!
			process_mode = PROCESS_MODE_INHERIT if visible else PROCESS_MODE_DISABLED

func get_open_duration() -> float:
	return 0.45

func get_close_duration() -> float:
	return 0.35

func prepare_for_open() -> void:
	SignalBus.battle_inventory_transition_started.emit(true)
	self.mouse_filter = Control.MOUSE_FILTER_STOP
	# Open action disables overflow penalty until fully open
	tier_1_tray.set_overflow_monitoring_active(false)
	tier_2_tray.set_overflow_monitoring_active(false)
	tier_3_tray.set_overflow_monitoring_active(false)

func set_moving(moving: bool) -> void:
	pass

func set_open_progress(progress: float) -> void:
	var current_y = lerp(_closed_y, _base_y, progress)
	
	if is_instance_valid(tier_1_tray) and is_instance_valid(tier_1_tray.motion_body):
		tier_1_tray.motion_body.position.y = current_y
	if is_instance_valid(tier_2_tray) and is_instance_valid(tier_2_tray.motion_body):
		tier_2_tray.motion_body.position.y = current_y
	if is_instance_valid(tier_3_tray) and is_instance_valid(tier_3_tray.motion_body):
		tier_3_tray.motion_body.position.y = current_y

func get_open_progress() -> float:
	if not is_instance_valid(tier_1_tray) or not is_instance_valid(tier_1_tray.motion_body):
		return 0.0
	var ty = tier_1_tray.motion_body.position.y
	if is_zero_approx(_base_y - _closed_y):
		return 0.0
	return clamp((ty - _closed_y) / (_base_y - _closed_y), 0.0, 1.0)

func finish_open() -> void:
	_is_open = true
	# Re-enable overflow now that tray is fully exposed
	tier_1_tray.set_overflow_monitoring_active(true)
	tier_2_tray.set_overflow_monitoring_active(true)
	tier_3_tray.set_overflow_monitoring_active(true)
	
	_sync_all_trays()
	
	TutorialManager.show_tutorial(&"gacha_inspect_battle", [
		{
			"text": tr("tutorial.gacha_inspect_battle"),
			"center": true
		}
	])
	SignalBus.battle_inventory_transition_finished.emit()

func prepare_for_close() -> void:
	SignalBus.battle_inventory_transition_started.emit(false)
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Closing disables overflow penalty so it doesn't trigger while offscreen
	tier_1_tray.set_overflow_monitoring_active(false)
	tier_2_tray.set_overflow_monitoring_active(false)
	tier_3_tray.set_overflow_monitoring_active(false)

func finish_close() -> void:
	_is_open = false
	SignalBus.battle_inventory_transition_finished.emit()

func populate(context: Dictionary) -> void:
	# Called by WindowManager right before opening
	_data_source = context.get("inventory", {})

func _on_battle_inventory_changed() -> void:
	if _is_open:
		_sync_all_trays()

func _sync_all_trays() -> void:
	var bm = get_tree().get_first_node_in_group("battle_manager")
	if not is_instance_valid(bm):
		return
		
	if is_instance_valid(tier_1_tray):
		tier_1_tray.sync_state(bm.get_inventory_tier_instances(1))
	if is_instance_valid(tier_2_tray):
		tier_2_tray.sync_state(bm.get_inventory_tier_instances(2))
	if is_instance_valid(tier_3_tray):
		tier_3_tray.sync_state(bm.get_inventory_tier_instances(3))



func _gui_input(event: InputEvent) -> void:
	var InputUtils = preload("res://scripts/InputUtils.gd")
	if InputUtils.is_primary_pointer_press(event):
		if GlobalInteractionRouter.is_drag_active():
			GlobalInteractionRouter.end_drag(false)
			return
		
		# Background click closes inspection windows
		var context = InteractionContext.new()
		context.source_view_instance_id = get_instance_id()
		context.event_type = &"SINGLE_CLICK"
		context.entity_type = &"GLOBAL_BACKGROUND"
		context.interaction_mode = &"FULLY_INTERACTIVE"
		context.window_group_id = 1
		
		SignalBus.emit_signal("interaction_context_received", context)
		get_viewport().set_input_as_handled()
		if InputUtils.is_touch_pointer_event(event):
			accept_event()
