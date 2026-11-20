extends Node

const InputUtils = preload("res://scripts/InputUtils.gd")
const InspectionPeekController = preload("res://scripts/ui/InspectionPeekController.gd")

## GlobalInteractionRouter is the single source of truth for interpreting user intent.
## Receives InteractionContext from clicked views, generates command queues, and coordinates
## selection, inspection lock, drag sessions, and close suppression.

enum CommandType {
	DESELECT,
	SELECT,
	OPEN_INSPECTION_WINDOW,
	CLOSE_ALL_INSPECTION_WINDOWS,
	CLOSE_CHILD_WINDOWS,
	CLOSE_TOP_CONTEXTUAL_WINDOW,
	REQUEST_ACTION,
	INVALID_ACTION,
}

class Command:
	var cmd: CommandType
	var context: Dictionary = {}

	func _init(command_type: CommandType, command_context: Dictionary = {}) -> void:
		cmd = command_type
		context = command_context


var _current_selection: InteractionContext = null
var _is_combat_phase: bool = false
var _is_ui_transitioning: bool = false
var _last_pointer_pos: Vector2 = Vector2.ZERO

## Lock inspection state (separate from _current_selection; CloseInspectionAction resets via set())
var _locked_entity_view_id: int = -1
var _is_inspection_locked: bool = false

var _peek_controller: InspectionPeekController = null
var _drag: DragSessionController = DragSessionController.new()
var _suppression: CloseSuppressionState = CloseSuppressionState.new()


func get_peek_controller() -> InspectionPeekController:
	return _peek_controller


func is_combat_phase() -> bool:
	return _is_combat_phase


func is_ui_transitioning() -> bool:
	return _is_ui_transitioning


func _ready() -> void:
	add_to_group("global_interaction_router")
	set_process(true)
	process_mode = Node.PROCESS_MODE_ALWAYS

	_peek_controller = InspectionPeekController.new()
	_peek_controller.name = "InspectionPeekController"
	add_child(_peek_controller)

	SignalBus.interaction_context_received.connect(_on_interaction_context_received)
	SignalBus.selection_clear_requested.connect(_on_selection_clear_requested)
	SignalBus.battle_phase_changed.connect(_on_battle_phase_changed)
	SignalBus.interaction_lock_requested.connect(_on_interaction_lock_requested)
	SignalBus.battle_inventory_transition_started.connect(_on_battle_inventory_transition_started)
	SignalBus.battle_inventory_transition_finished.connect(_on_battle_inventory_transition_finished)
	WindowManager.window_closed.connect(_on_window_closed)
	ActionQueue.action_rejected.connect(_on_action_rejected)


func _on_action_rejected(_action: GameAction, _reason: String) -> void:
	if _drag.is_drag_active:
		end_drag(false)


func _exit_tree() -> void:
	_drag.cleanup()
	_is_inspection_locked = false
	_locked_entity_view_id = -1
	if _current_selection != null:
		_emit_view_deselected(_current_selection)
		_emit_selection_changed(null)
	if SignalBus.interaction_context_received.is_connected(_on_interaction_context_received):
		SignalBus.interaction_context_received.disconnect(_on_interaction_context_received)
	if SignalBus.interaction_lock_requested.is_connected(_on_interaction_lock_requested):
		SignalBus.interaction_lock_requested.disconnect(_on_interaction_lock_requested)
	if SignalBus.selection_clear_requested.is_connected(_on_selection_clear_requested):
		SignalBus.selection_clear_requested.disconnect(_on_selection_clear_requested)
	if SignalBus.battle_phase_changed.is_connected(_on_battle_phase_changed):
		SignalBus.battle_phase_changed.disconnect(_on_battle_phase_changed)
	if WindowManager.window_closed.is_connected(_on_window_closed):
		WindowManager.window_closed.disconnect(_on_window_closed)


func _on_interaction_context_received(context: InteractionContext) -> void:
	if _is_ui_transitioning:
		return
	if context.event_type == &"DRAG_START":
		if is_vcr_playing() or _drag.is_drag_active:
			return
		start_drag(context)
		return
	var command_queue: Array[Command] = _generate_command_queue(context)
	_execute_command_queue(command_queue)


func _process(_delta: float) -> void:
	_drag.update_overlay_position(get_last_pointer_position())


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		WindowManager.toggle_glossary_lock()
		get_viewport().set_input_as_handled()
		return
	if WindowManager.is_tutorial_overlay_open():
		return

	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		_last_pointer_pos = InputUtils.get_event_global_position(event)

	var is_choice_open: bool = WindowManager.is_choice_window_open()
	if not _is_inspection_locked and not is_choice_open:
		return
	if not InputUtils.is_primary_pointer_press(event):
		return

	var pos: Vector2 = InputUtils.get_event_global_position(event)
	if pos.is_zero_approx():
		return

	if is_choice_open:
		if WindowManager.is_point_inside_any_inspection_window(pos):
			return
		_is_inspection_locked = false
		_locked_entity_view_id = -1
		_execute_close_all_inspection_windows()
		return

	if WindowManager.is_point_inside_any_inspection_window(pos):
		return

	var main_node: Node = get_tree().get_first_node_in_group("main")
	if is_instance_valid(main_node) and main_node.is_point_inside_active_drop_zone(pos):
		return

	# During Combat or VCR playback, paused Controls cannot receive _gui_input:
	# route clicks to switch inspection or close the pinned inspection.
	if _is_combat_phase or is_vcr_playing():
		var context: InteractionContext = _find_combat_inspection_at_position(pos)
		if context != null and context.source_view_instance_id != _locked_entity_view_id:
			_on_interaction_context_received(context)
		else:
			_is_inspection_locked = false
			_locked_entity_view_id = -1
			_execute_close_all_inspection_windows()
		get_viewport().set_input_as_handled()
		return

	if not _suppression.is_active():
		_is_inspection_locked = false
		_locked_entity_view_id = -1
		_execute_close_all_inspection_windows()


func _find_combat_inspection_at_position(pos: Vector2) -> InteractionContext:
	var screen_position: Vector2 = get_viewport().get_screen_transform() * pos
	var banner: EnemyBannerView = get_tree().get_first_node_in_group("enemy_banner_view") as EnemyBannerView
	if banner != null and banner.is_visible_in_tree():
		var banner_point: Vector2 = banner.get_screen_transform().affine_inverse() * screen_position
		if banner._has_point(banner_point):
			return banner.create_inspection_context(pos)

	var views: Array[Node] = get_tree().get_nodes_in_group("gachaball_view")
	for i: int in range(views.size() - 1, -1, -1):
		var view: GachaBallView = views[i] as GachaBallView
		if not view.is_visible_in_tree():
			continue
		var local_pos: Vector2 = view.get_screen_transform().affine_inverse() * screen_position
		if Rect2(Vector2.ZERO, view.size).has_point(local_pos) and view._has_point(local_pos):
			return view._create_interaction_context(&"SINGLE_CLICK", pos)
	return null


func _unhandled_input(event: InputEvent) -> void:
	if _is_combat_phase and not _is_inspection_locked:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			WindowManager.toggle_options_window()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _drag.is_drag_active:
			var origin_loc: LocationIdentifier = _drag.drag_origin_context.location if _drag.drag_origin_context != null else null
			ActionQueue.request(CancelDragAction.new(origin_loc, null, "cancelled_by_escape", Vector2.ZERO))
			return
		if WindowManager.is_modal_open():
			SignalBus.close_modal_requested.emit()
			return
		_is_inspection_locked = false
		_locked_entity_view_id = -1
		if WindowManager.has_any_contextual_windows():
			if not _suppression.is_active():
				_execute_close_all_inspection_windows()
			return
		if not is_vcr_playing() and not _is_combat_phase and _current_selection != null:
			ActionQueue.request(DeselectAction.new())
			return
		WindowManager.toggle_options_window()
		return

	if InputUtils.is_primary_pointer_press(event):
		if not _suppression.is_active():
			_is_inspection_locked = false
			_locked_entity_view_id = -1
			_execute_close_all_inspection_windows()
		if not is_vcr_playing() and not _is_combat_phase:
			if _current_selection != null:
				ActionQueue.request(DeselectAction.new())
			else:
				_execute_deselect()


func _on_selection_clear_requested() -> void:
	_is_inspection_locked = false
	_locked_entity_view_id = -1
	if _current_selection != null:
		_execute_deselect()
	_suppression.arm(0, CloseSuppressionState.CLOSE_SUPPRESS_GRACE_FRAMES, false)


func _on_interaction_lock_requested(locked: bool) -> void:
	_is_inspection_locked = locked


func _on_battle_phase_changed(phase_name: StringName) -> void:
	_is_combat_phase = (phase_name == &"COMBAT")
	if _is_combat_phase:
		_execute_close_all_inspection_windows()
		_execute_deselect()
		_is_inspection_locked = false
		_locked_entity_view_id = -1
		if _drag.is_drag_active:
			end_drag(false)
		var vp: Viewport = get_viewport()
		if is_instance_valid(vp):
			vp.gui_cancel_drag()


func _on_battle_inventory_transition_started(_is_opening: bool) -> void:
	_is_ui_transitioning = true
	if _drag.is_drag_active:
		end_drag(false)


func _on_battle_inventory_transition_finished() -> void:
	_is_ui_transitioning = false


func _on_window_closed(window: Control) -> void:
	if _current_selection == null or not is_instance_valid(window):
		return
	var sel_view: Control = _find_view_by_instance_id(_current_selection.source_view_instance_id)
	if is_instance_valid(sel_view) and (window == sel_view or window.is_ancestor_of(sel_view)):
		_execute_deselect()


# =============================================================================
# COMMAND QUEUE GENERATION
# =============================================================================

func _generate_command_queue(context: InteractionContext) -> Array[Command]:
	var commands: Array[Command] = []

	if _drag.is_drag_active and _drag.drag_origin_context != null:
		var source_group: StringName = get_context_group(_drag.drag_origin_context.location.container) if _drag.drag_origin_context.location != null else &""
		if source_group == &"SelectionOnly":
			return commands
		var drop_pos: Vector2 = context.pointer_position if is_instance_valid(context) and not context.pointer_position.is_zero_approx() else get_last_pointer_position()
		commands.append(Command.new(CommandType.REQUEST_ACTION, _build_request_action_ctx(_drag.drag_origin_context, context, "DRAG", drop_pos)))
		commands.append(Command.new(CommandType.DESELECT))
		return commands

	if context.entity_type != &"UI_LINK" and (WindowManager.is_any_inspection_window_open() or WindowManager.is_any_inventory_window_open()):
		var src_view: Control = _find_view_by_instance_id(context.source_view_instance_id)
		if is_instance_valid(src_view) and context.entity_type != &"WINDOW_BACKGROUND":
			var parent_window: Control = WindowManager.find_ancestor_window_for_view(src_view)
			if is_instance_valid(parent_window):
				var skip_prune: bool = _is_inspection_locked and _locked_entity_view_id == context.source_view_instance_id
				if not skip_prune:
					commands.append(Command.new(CommandType.CLOSE_CHILD_WINDOWS, {
						"parent_window_id": parent_window.get_instance_id(),
					}))
		if not _is_click_inside_inspection_group(context):
			var suppressed: bool = _suppression.is_suppressed_for_context(context, get_tree().root) \
				or _suppression.is_active() \
				or (_is_inspection_locked and _locked_entity_view_id == context.source_view_instance_id)
			if not suppressed:
				commands.append(Command.new(CommandType.CLOSE_ALL_INSPECTION_WINDOWS))

	match context.entity_type:
		&"GLOBAL_BACKGROUND":
			if not _suppression.is_active():
				commands.append(Command.new(CommandType.CLOSE_ALL_INSPECTION_WINDOWS))
				commands.append(Command.new(CommandType.DESELECT))
		&"WINDOW_BACKGROUND":
			commands.append(Command.new(CommandType.CLOSE_CHILD_WINDOWS, {
				"window_group_id": context.window_group_id,
				"parent_window_id": context.source_view_instance_id,
			}))
			commands.append(Command.new(CommandType.DESELECT))
		&"UNIT", &"ITEM", &"TRINKET", &"CONSUMABLE":
			commands.append_array(_handle_gachaball_interaction(context))
		&"EMPTY_SLOT":
			commands.append_array(_handle_empty_slot_interaction(context))
		&"UI_LINK":
			commands.append_array(_handle_ui_link_interaction(context))

	return commands


func _build_request_action_ctx(source: InteractionContext, target: InteractionContext, interaction_type: String, drop_pos: Vector2) -> Dictionary:
	var req_ctx: Dictionary = {
		"source_context": source,
		"target_context": target,
		"interaction_type": interaction_type,
		"drop_pos": drop_pos,
	}
	var tgt_parent_id: int = _resolve_parent_window_id_for_context(target)
	if tgt_parent_id != -1:
		req_ctx["target_parent_window_id"] = tgt_parent_id
		req_ctx["is_inside_unit_inspection"] = InteractionTargetRules.is_unit_inspection_window_id(tgt_parent_id)
	return req_ctx


func _handle_locked_inspection_toggle(context: InteractionContext) -> Array[Command]:
	var commands: Array[Command] = []
	if _is_inspection_locked and _locked_entity_view_id == context.source_view_instance_id:
		commands.append(Command.new(CommandType.CLOSE_TOP_CONTEXTUAL_WINDOW))
	else:
		if not _is_click_inside_inspection_group(context) and not _suppression.is_suppressed_for_context(context, get_tree().root):
			commands.append(Command.new(CommandType.CLOSE_ALL_INSPECTION_WINDOWS))
		commands.append(Command.new(CommandType.OPEN_INSPECTION_WINDOW, {
			"context": context,
			"anchor_view_id": context.source_view_instance_id,
			"lock": true,
		}))
	return commands


func _handle_gachaball_interaction(context: InteractionContext) -> Array[Command]:
	match context.interaction_mode:
		&"FULLY_INTERACTIVE":
			return _handle_fully_interactive(context)
		&"SELECTION_ONLY":
			return _handle_selection_only(context)
		&"INSPECTION_ONLY":
			return _handle_locked_inspection_toggle(context)
	return []


func _handle_fully_interactive(context: InteractionContext) -> Array[Command]:
	if is_vcr_playing() or _is_combat_phase:
		return _handle_locked_inspection_toggle(context)

	var commands: Array[Command] = []
	if _current_selection == null:
		commands.append(Command.new(CommandType.SELECT, {"context": context}))
		return commands

	if _current_selection.source_view_instance_id == context.source_view_instance_id:
		return commands

	if InteractionTargetRules.is_inventory_tier_change(_current_selection, context):
		commands.append(Command.new(CommandType.DESELECT))
		commands.append(Command.new(CommandType.SELECT, {"context": context}))
		return commands

	if InteractionTargetRules.is_valid_action_target(_current_selection, context):
		commands.append(Command.new(CommandType.REQUEST_ACTION, _build_request_action_ctx(_current_selection, context, "CLICK", Vector2.ZERO)))
		commands.append(Command.new(CommandType.DESELECT))
	else:
		if not _is_click_inside_inspection_group(context) and not _suppression.is_suppressed_for_context(context, get_tree().root):
			commands.append(Command.new(CommandType.CLOSE_ALL_INSPECTION_WINDOWS))
		commands.append(Command.new(CommandType.DESELECT))
		commands.append(Command.new(CommandType.SELECT, {"context": context}))
	return commands


func _handle_selection_only(context: InteractionContext) -> Array[Command]:
	var commands: Array[Command] = []
	if _current_selection != null:
		var same_view: bool = _current_selection.source_view_instance_id == context.source_view_instance_id
		var same_loc: bool = _current_selection.location != null and context.location != null \
			and _current_selection.location.container == context.location.container \
			and _current_selection.location.index == context.location.index
		if same_view or same_loc:
			return commands
		commands.append(Command.new(CommandType.DESELECT))
	commands.append(Command.new(CommandType.SELECT, {"context": context}))
	return commands


func _handle_empty_slot_interaction(context: InteractionContext) -> Array[Command]:
	var commands: Array[Command] = []
	if _current_selection == null:
		return commands

	if InteractionTargetRules.is_inventory_tier_change(_current_selection, context):
		commands.append(Command.new(CommandType.DESELECT))
	elif InteractionTargetRules.is_valid_move_target(_current_selection, context):
		if is_vcr_playing() or _is_combat_phase:
			commands.append(Command.new(CommandType.CLOSE_ALL_INSPECTION_WINDOWS))
			return commands
		commands.append(Command.new(CommandType.REQUEST_ACTION, _build_request_action_ctx(_current_selection, context, "CLICK", Vector2.ZERO)))
		commands.append(Command.new(CommandType.DESELECT))
	else:
		if not _is_click_inside_inspection_group(context) and not _suppression.is_suppressed_for_context(context, get_tree().root):
			commands.append(Command.new(CommandType.CLOSE_ALL_INSPECTION_WINDOWS))
		commands.append(Command.new(CommandType.DESELECT))
	return commands


func _handle_ui_link_interaction(context: InteractionContext) -> Array[Command]:
	var parent_window_id: int = _resolve_parent_window_id_for_context(context)
	if parent_window_id == -1:
		parent_window_id = context.source_view_instance_id
	return [
		Command.new(CommandType.CLOSE_CHILD_WINDOWS, {"parent_window_id": parent_window_id}),
		Command.new(CommandType.OPEN_INSPECTION_WINDOW, {
			"context": context,
			"anchor_view_id": context.source_view_instance_id,
		}),
	]


func _is_click_inside_inspection_group(context: InteractionContext) -> bool:
	if context != null and is_instance_valid(context.location) and context.location.container == &"Shrine" and WindowManager.is_run_inventory_window_open():
		return true
	var view: Control = _find_view_by_instance_id(context.source_view_instance_id)
	if not is_instance_valid(view):
		return false
	if WindowManager.is_view_inside_inventory(view):
		return true
	return is_instance_valid(WindowManager.find_ancestor_window_for_view(view))


func _resolve_parent_window_id_for_context(context: InteractionContext) -> int:
	if context == null:
		return -1
	var v: Control = _find_view_by_instance_id(context.source_view_instance_id)
	if not is_instance_valid(v):
		return -1
	var parent_window: Control = WindowManager.find_ancestor_window_for_view(v)
	return parent_window.get_instance_id() if is_instance_valid(parent_window) else -1


# =============================================================================
# COMMAND EXECUTION
# =============================================================================

func _execute_command_queue(commands: Array[Command]) -> void:
	for command: Command in commands:
		_execute_command(command)


func _execute_command(command: Command) -> void:
	match command.cmd:
		CommandType.DESELECT:
			ActionQueue.request(DeselectAction.new())
		CommandType.SELECT:
			var ctx: InteractionContext = command.context.get("context") as InteractionContext
			if is_instance_valid(ctx):
				ActionQueue.request(SelectEntityAction.new(ctx.location, ctx.entity_uuid, ctx.source_view_instance_id))
			Audio.play_sfx("ui_select")
		CommandType.OPEN_INSPECTION_WINDOW:
			_execute_open_inspection_window(command.context)
		CommandType.CLOSE_ALL_INSPECTION_WINDOWS:
			_execute_close_all_inspection_windows()
		CommandType.CLOSE_CHILD_WINDOWS:
			_execute_close_child_windows(command.context.get("window_group_id", 0), command.context.get("parent_window_id", -1))
		CommandType.CLOSE_TOP_CONTEXTUAL_WINDOW:
			if WindowManager.is_any_inspection_window_open() or WindowManager.is_any_inventory_window_open():
				ActionQueue.request(CloseInspectionAction.new(false))
			else:
				WindowManager.close_top_contextual_window()
		CommandType.REQUEST_ACTION:
			_execute_request_action(command.context)
			Audio.play_sfx("ui_click")
		CommandType.INVALID_ACTION:
			_execute_close_all_inspection_windows()
			_execute_deselect()


func _execute_deselect() -> void:
	apply_deselect_entity()


func apply_deselect_entity() -> void:
	# Preserve modal/system locks (_locked_entity_view_id == -1) while clearing entity inspection locks.
	if _locked_entity_view_id != -1:
		_is_inspection_locked = false
		_locked_entity_view_id = -1
	if _current_selection != null:
		_emit_view_deselected(_current_selection)
		_emit_selection_changed(null)
		_current_selection = null


func _execute_select(context: InteractionContext) -> void:
	if context == null:
		return
	apply_select_entity(context.location, context.entity_uuid, context.entity_type, context.source_view_instance_id)


func apply_select_entity(location: LocationIdentifier, entity_uuid: String = "", entity_type: StringName = &"", source_view_id: int = 0) -> void:
	var target_location: LocationIdentifier = location
	if not is_instance_valid(target_location) and not entity_uuid.is_empty() and is_instance_valid(GameManager.run_state):
		target_location = GameManager.run_state.get_location_for_uuid(entity_uuid)

	var view: Control = _find_view_by_instance_id(source_view_id)
	if view == null and target_location != null:
		view = WindowManager.find_entity_view_for_location(target_location)

	var ctx := InteractionContext.new()
	ctx.location = target_location
	ctx.entity_uuid = entity_uuid
	ctx.entity_type = entity_type
	if is_instance_valid(view):
		ctx.source_view_instance_id = view.get_instance_id()

	if ctx.entity_type == &"":
		var inst: GachaBallInstance = null
		if not entity_uuid.is_empty() and is_instance_valid(GameManager.run_state):
			inst = GameManager.run_state.get_instance_by_uuid(entity_uuid)
		elif is_instance_valid(target_location):
			inst = GameManager.get_instance_from_location(target_location)
		if is_instance_valid(inst):
			var def: Resource = inst.get_definition()
			if is_instance_valid(def) and "category" in def:
				ctx.entity_type = def.category

	if _current_selection != null and _current_selection.source_view_instance_id != ctx.source_view_instance_id:
		_emit_view_deselected(_current_selection)
	_current_selection = ctx
	if is_instance_valid(view):
		SignalBus.view_selected.emit(view, target_location)
	_emit_selection_changed(target_location)


func _execute_open_inspection_window(command_context: Dictionary) -> void:
	var context: InteractionContext = command_context.get("context") as InteractionContext
	if context == null:
		return
	var anchor_view_id: int = int(command_context.get("anchor_view_id", 0))
	var should_lock: bool = bool(command_context.get("lock", false))
	if should_lock:
		ActionQueue.request(InspectEntityAction.new(context.location, should_lock, &"", &"", context.entity_uuid, ""))
	else:
		var anchor_view: Control = _find_view_by_instance_id(anchor_view_id)
		if is_instance_valid(anchor_view) and is_instance_valid(context.location):
			WindowManager.open_inspection_window(context.location, anchor_view)


func _execute_close_all_inspection_windows() -> void:
	if WindowManager.is_any_inspection_window_open() or WindowManager.is_any_inventory_window_open():
		ActionQueue.request(CloseInspectionAction.new(true))


func _execute_close_child_windows(window_group_id: int, parent_window_id: int = -1) -> void:
	if WindowManager.is_any_inspection_window_open() or WindowManager.is_any_inventory_window_open():
		ActionQueue.request(CloseInspectionAction.new(false))
	else:
		WindowManager.close_child_windows(window_group_id, parent_window_id)


func _execute_request_action(command_context: Dictionary) -> void:
	if _is_combat_phase or is_vcr_playing():
		_execute_close_all_inspection_windows()
		_execute_deselect()
		return
	var source_context: InteractionContext = command_context.get("source_context") as InteractionContext
	var target_context: InteractionContext = command_context.get("target_context") as InteractionContext
	if source_context == null or target_context == null:
		return

	var tgt_parent_id: int = int(command_context.get("target_parent_window_id", -1))
	if tgt_parent_id != -1:
		activate_close_suppression_for_window_id(tgt_parent_id)
	else:
		var tgt_view: Control = _find_view_by_instance_id(target_context.source_view_instance_id)
		if is_instance_valid(tgt_view):
			_suppression.activate_for_view(tgt_view)
		else:
			var src_view: Control = _find_view_by_instance_id(source_context.source_view_instance_id)
			if is_instance_valid(src_view):
				_suppression.activate_for_view(src_view)

	var interaction_type: String = String(command_context.get("interaction_type", "CLICK"))
	var drop_pos: Vector2 = command_context.get("drop_pos", Vector2.ZERO)
	var move_action := MoveInventoryAction.new(source_context.location, target_context.location, interaction_type, drop_pos)
	if not ActionQueue.request(move_action):
		ActionQueue.request(CancelDragAction.new(source_context.location, target_context.location, "action_rejected", drop_pos))


func _emit_selection_changed(loc: LocationIdentifier) -> void:
	SignalBus.selection_changed.emit(loc)


func _emit_view_deselected(sel: InteractionContext) -> void:
	var view: Control = _find_view_by_instance_id(sel.source_view_instance_id)
	if is_instance_valid(view):
		SignalBus.view_deselected.emit(view)


func _find_view_by_instance_id(instance_id: int) -> Control:
	return InteractionTargetRules.find_view_by_instance_id(instance_id, get_tree().root)


# =============================================================================
# PUBLIC API DELEGATES
# =============================================================================

func set_current_selection(context: InteractionContext) -> void:
	_current_selection = context


func get_current_selection() -> InteractionContext:
	return _current_selection


func clear_current_selection() -> void:
	apply_deselect_entity()


func get_context_group(container_name: StringName) -> StringName:
	return InteractionTargetRules.get_container_functional_group(container_name)


func start_drag(origin_context: InteractionContext) -> void:
	_drag.start_drag(self, origin_context)


func end_drag(was_handled: bool) -> void:
	_drag.end_drag(self, was_handled)


func start_drag_visuals(source_view: Control, placeholder: Control) -> void:
	_drag.start_drag_visuals(_is_combat_phase, source_view, placeholder)


func end_drag_visuals(was_handled: bool) -> void:
	_drag.end_drag_visuals(was_handled)


func set_drag_overlay_preview(preview: Control) -> void:
	_drag.set_drag_overlay_preview(self, preview)


func is_drag_active() -> bool:
	return _drag.is_drag_active


func get_drag_source_view() -> Control:
	return _drag.drag_source_view


func get_drag_origin_context() -> InteractionContext:
	return _drag.drag_origin_context


func is_combat_locked() -> bool:
	return _is_combat_phase


func is_inspection_locked() -> bool:
	return _is_inspection_locked


func lock_inspection_on_view(view: Control) -> void:
	_is_inspection_locked = true
	_locked_entity_view_id = view.get_instance_id() if is_instance_valid(view) else -1


func activate_close_suppression_for_window_id(window_id: int, grace_frames: int = CloseSuppressionState.CLOSE_SUPPRESS_GRACE_FRAMES) -> void:
	_suppression.activate_for_window_id(window_id, grace_frames)


func clear_close_suppression() -> void:
	_suppression.clear()


func is_close_suppressed_for_window_id(window_id: int) -> bool:
	return _suppression.is_suppressed_for_window_id(window_id)


func is_close_suppressed_now() -> bool:
	return _suppression.is_active()


func get_last_pointer_position() -> Vector2:
	if not _last_pointer_pos.is_zero_approx():
		return _last_pointer_pos
	var vp: Viewport = get_viewport()
	return vp.get_mouse_position() if is_instance_valid(vp) else Vector2.ZERO


func is_vcr_playing() -> bool:
	if ActionQueue.is_replay_mode():
		return true
	if BattleAnimator.is_playing_sequence():
		return true
	var bm: BattleManager = get_tree().get_first_node_in_group("battle_manager") as BattleManager
	return is_instance_valid(bm) and bm.is_animations_playing()
