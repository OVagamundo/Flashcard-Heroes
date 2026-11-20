# res://scripts/ui/GlossaryClusterController.gd
class_name GlossaryClusterController
extends RefCounted

## Manages recursive glossary card discovery, multi-column outward tray layout,
## modal child glossary windows, and the GlossaryTogglePill attached to root
## inspection/choice windows.

const _GlossaryTogglePillScene = preload("res://scenes/GlossaryTogglePill.tscn")

var _modal_child_windows: Dictionary = {}
var _glossary_pill: Control = null


func get_glossary_pill() -> Control:
	return _glossary_pill


func is_point_inside_glossary_pill(pos: Vector2, root_viewport: Viewport) -> bool:
	if is_instance_valid(_glossary_pill) and _glossary_pill.is_inside_tree() and _glossary_pill.visible:
		return TooltipPositioner.get_screen_rect(_glossary_pill, root_viewport).has_point(pos)
	return false


func collect_recursive_glossary_specs(root_window: Control, active_inspection_group: Array[Control]) -> Array[Dictionary]:
	var initial_terms: Array[String] = []
	if root_window is InspectionWindow:
		initial_terms = (root_window as InspectionWindow).get_glossary_terms()
	elif root_window is ChoiceWindow:
		initial_terms = (root_window as ChoiceWindow).get_glossary_terms()

	# Also collect terms from any currently active child windows attached to this root (like equipped items)
	var root_id: int = root_window.get_instance_id()
	for w: Control in active_inspection_group:
		if is_instance_valid(w) and w is InspectionWindow and not (w is EffectInspectionWindow):
			var insp_w: InspectionWindow = w as InspectionWindow
			if insp_w.parent_inspection_window_id == root_id:
				initial_terms.append_array(insp_w.get_glossary_terms())

	var seen_terms: Dictionary = {}
	if root_window is EffectInspectionWindow:
		var own_meta: String = (root_window as EffectInspectionWindow).get_own_keyword_canonical()
		if not own_meta.is_empty():
			seen_terms[own_meta] = true

	var specs: Array[Dictionary] = []
	var queue: Array[String] = initial_terms.duplicate()

	while not queue.is_empty():
		var raw_key: String = queue.pop_front()
		var info: Dictionary = DescriptionParser.get_keyword_info(raw_key)
		if info.is_empty():
			continue
		var canonical: String = String(info.get("meta", raw_key))
		if seen_terms.has(canonical):
			continue
		seen_terms[canonical] = true

		specs.append({
			"window_type": &"EffectInspection",
			"populate_context": {
				"effect_definition": {
					"name_key": info.name_key,
					"description_key": info.desc_key,
					"color": info.color
				},
				"is_inside_unit_inspection": true,
				"target_parent_window_id": root_id
			}
		})

		# Recursive BFS: scan this keyword's description for nested glossary terms
		var desc_key: String = String(info.get("desc_key", ""))
		if not desc_key.is_empty():
			var translated_desc: String = TranslationServer.translate(desc_key)
			var nested_terms: Array[String] = DescriptionParser.find_keywords(translated_desc)
			for nested_key: String in nested_terms:
				var nested_info: Dictionary = DescriptionParser.get_keyword_info(nested_key)
				var nested_canonical: String = String(nested_info.get("meta", nested_key)) if not nested_info.is_empty() else nested_key
				if not seen_terms.has(nested_canonical):
					queue.append(nested_key)

	return specs


func refresh_glossary_windows_state(wm: Node) -> void:
	var active_group: Array[Control] = wm._active_inspection_group
	var root_viewport: Viewport = wm.get_viewport()
	if not wm.is_glossary_locked:
		var has_removed: bool = false
		var root_w: Control = null
		var root_anc: Control = null
		for i: int in range(active_group.size() - 1, -1, -1):
			var w: Control = active_group[i]
			if is_instance_valid(w):
				if w is EffectInspectionWindow and (w as InspectionWindow).parent_inspection_window_id != -1:
					active_group.remove_at(i)
					wm.stop_tracking_window(w.get_instance_id())
					w.queue_free()
					has_removed = true
				elif (w is InspectionWindow and (w as InspectionWindow).parent_inspection_window_id == -1) or w is ChoiceWindow:
					root_w = w
					root_anc = wm.get_anchor_for_window(w)

		if is_instance_valid(root_w) and is_instance_valid(root_anc):
			var pos_hint: String = wm.get_pos_hint_for_window(root_w)
			var pos: Vector2 = wm._calculate_contextual_window_position(root_anc, null, root_w, pos_hint)
			TooltipPositioner.set_window_screen_position(root_w, pos)
			update_glossary_pill_position(wm, root_w)

		if has_removed and is_instance_valid(root_w):
			var remaining_children: Array[Control] = []
			for w: Control in active_group:
				if is_instance_valid(w) and w != root_w and w is InspectionWindow:
					remaining_children.append(w)
			if not remaining_children.is_empty():
				var s_rect: Rect2 = TooltipPositioner.get_screen_rect(root_anc, root_viewport) if is_instance_valid(root_anc) else Rect2()
				layout_child_windows(s_rect, root_w, remaining_children, root_viewport)

		for m_id in _modal_child_windows:
			var list: Array = _modal_child_windows[m_id]
			for w in list:
				if is_instance_valid(w):
					wm.stop_tracking_window(w.get_instance_id())
					w.queue_free()
		_modal_child_windows.clear()
	else:
		var root_w: Control = null
		var root_anc: Control = null
		for w: Control in active_group:
			if is_instance_valid(w):
				if (w is InspectionWindow and (w as InspectionWindow).parent_inspection_window_id == -1) or w is ChoiceWindow:
					root_w = w
					root_anc = wm.get_anchor_for_window(w)
					break

		if is_instance_valid(root_w):
			if is_instance_valid(root_anc):
				var pos_hint: String = wm.get_pos_hint_for_window(root_w)
				var pos: Vector2 = wm._calculate_contextual_window_position(root_anc, null, root_w, pos_hint)
				TooltipPositioner.set_window_screen_position(root_w, pos)
				update_glossary_pill_position(wm, root_w)
			spawn_and_layout_glossary_only(wm, root_w, root_anc)

		var active_modal: Control = wm._modal_stack.back() if not wm._modal_stack.is_empty() else null
		if is_instance_valid(active_modal):
			var insp_container: Node = active_modal.get_node_or_null("%InspectionContainer")
			if insp_container:
				for ch in insp_container.get_children():
					if ch is InspectionWindow:
						setup_child_windows_for_modal(wm, active_modal, ch as InspectionWindow)
						break


func spawn_and_layout_glossary_only(wm: Node, root_window: Control, anchor: Control) -> void:
	if not is_instance_valid(root_window) or not root_window.is_inside_tree():
		return

	var active_group: Array[Control] = wm._active_inspection_group
	# Remove any old/duplicate EffectInspection child windows before spawning
	for i: int in range(active_group.size() - 1, -1, -1):
		var w: Control = active_group[i]
		if is_instance_valid(w) and w is EffectInspectionWindow and w != root_window:
			active_group.remove_at(i)
			wm.stop_tracking_window(w.get_instance_id())
			w.queue_free()

	if not wm.is_glossary_locked:
		return

	var glossary_specs: Array[Dictionary] = collect_recursive_glossary_specs(root_window, active_group)
	if glossary_specs.is_empty():
		return

	var new_glossary_windows: Array[Control] = []
	for spec: Dictionary in glossary_specs:
		var child_instance: Control = _instantiate_child_window(wm, spec, root_window.get_instance_id(), 100, true)
		if is_instance_valid(child_instance):
			new_glossary_windows.append(child_instance)

	if new_glossary_windows.is_empty():
		return

	await wm.get_tree().process_frame
	await wm.get_tree().process_frame

	if not wm.is_glossary_locked or not is_instance_valid(root_window) or not root_window.is_inside_tree():
		for child: Control in new_glossary_windows:
			if is_instance_valid(child):
				var idx: int = active_group.find(child)
				if idx != -1:
					active_group.remove_at(idx)
				wm.stop_tracking_window(child.get_instance_id())
				child.queue_free()
		return

	for child: Control in new_glossary_windows:
		if is_instance_valid(child) and child is InspectionWindow:
			child.size = Vector2(TooltipPositioner.GLOSSARY_WINDOW_WIDTH, 0)
			child.reset_size()

	var all_children: Array[Control] = []
	for w: Control in active_group:
		if is_instance_valid(w) and w != root_window and w is InspectionWindow:
			all_children.append(w)

	var root_viewport: Viewport = wm.get_viewport()
	var source_rect: Rect2 = TooltipPositioner.get_screen_rect(anchor, root_viewport) if is_instance_valid(anchor) else Rect2()
	layout_child_windows(source_rect, root_window, all_children, root_viewport)

	for child: Control in new_glossary_windows:
		if is_instance_valid(child):
			wm._animate_window_open(child)


func setup_child_windows_for_modal(wm: Node, modal: Control, preview_win: InspectionWindow) -> void:
	if not is_instance_valid(modal) or not modal.is_inside_tree():
		return
	if not is_instance_valid(preview_win) or not preview_win.is_inside_tree():
		return

	close_modal_child_windows(wm, modal)
	if not wm.is_glossary_locked:
		return

	var specs: Array[Dictionary] = collect_recursive_glossary_specs(preview_win, wm._active_inspection_group)
	if specs.is_empty():
		return

	var modal_id: int = modal.get_instance_id()
	var child_windows: Array[Control] = []
	for spec: Dictionary in specs:
		var child_instance: Control = _instantiate_child_window(wm, spec, preview_win.get_instance_id(), 200, false)
		if is_instance_valid(child_instance):
			child_windows.append(child_instance)

	_modal_child_windows[modal_id] = child_windows

	await wm.get_tree().process_frame
	await wm.get_tree().process_frame

	if not is_instance_valid(modal) or not modal.is_inside_tree():
		close_modal_child_windows(wm, modal)
		return

	for child: Control in child_windows:
		if is_instance_valid(child) and child is InspectionWindow:
			child.size = Vector2(TooltipPositioner.GLOSSARY_WINDOW_WIDTH, 0)
			child.reset_size()

	layout_child_windows(Rect2(), modal, child_windows, wm.get_viewport())

	for child: Control in child_windows:
		if is_instance_valid(child):
			wm._animate_window_open(child)


func close_modal_child_windows(wm: Node, modal: Control) -> void:
	if not is_instance_valid(modal):
		return
	close_modal_child_windows_by_id(wm, modal.get_instance_id())


func close_modal_child_windows_by_id(wm: Node, modal_id: int) -> void:
	if _modal_child_windows.has(modal_id):
		var list: Array = _modal_child_windows[modal_id]
		for w in list:
			if is_instance_valid(w):
				wm.stop_tracking_window(w.get_instance_id())
				w.queue_free()
		_modal_child_windows.erase(modal_id)


func setup_and_layout_child_windows(wm: Node, root_window: Control, anchor: Control) -> void:
	if not is_instance_valid(root_window) or not root_window.is_inside_tree():
		return
	if not (root_window is InspectionWindow or root_window is ChoiceWindow):
		return

	var specs: Array[Dictionary] = []
	if root_window is InspectionWindow:
		specs = (root_window as InspectionWindow).get_child_window_specs()
	elif root_window is ChoiceWindow:
		specs = (root_window as ChoiceWindow).get_child_window_specs()

	var active_group: Array[Control] = wm._active_inspection_group
	if wm.is_glossary_locked:
		specs.append_array(collect_recursive_glossary_specs(root_window, active_group))

	if specs.is_empty():
		return

	var child_windows: Array[Control] = []
	for spec: Dictionary in specs:
		var child_instance: Control = _instantiate_child_window(wm, spec, root_window.get_instance_id(), 100, true)
		if is_instance_valid(child_instance):
			child_windows.append(child_instance)

	if child_windows.is_empty():
		return

	# Wait for child windows layout to settle
	await wm.get_tree().process_frame
	await wm.get_tree().process_frame
	await wm.get_tree().process_frame

	if not is_instance_valid(root_window) or not root_window.is_inside_tree():
		for child: Control in child_windows:
			if is_instance_valid(child):
				child.queue_free()
		return

	# If glossary was toggled off during awaits, clean up any glossary windows
	if not wm.is_glossary_locked:
		for i: int in range(child_windows.size() - 1, -1, -1):
			var ch: Control = child_windows[i]
			if is_instance_valid(ch) and ch is EffectInspectionWindow:
				child_windows.remove_at(i)
				var a_idx: int = active_group.find(ch)
				if a_idx != -1:
					active_group.remove_at(a_idx)
				wm.stop_tracking_window(ch.get_instance_id())
				ch.queue_free()

	for child: Control in child_windows:
		if is_instance_valid(child) and child is InspectionWindow:
			var target_w: float = TooltipPositioner.GLOSSARY_WINDOW_WIDTH if child is EffectInspectionWindow else TooltipPositioner.INSPECTION_WINDOW_WIDTH
			child.size = Vector2(target_w, 0)
			child.reset_size()

	var root_viewport: Viewport = wm.get_viewport()
	var source_rect: Rect2 = TooltipPositioner.get_screen_rect(anchor, root_viewport) if is_instance_valid(anchor) else Rect2()
	layout_child_windows(source_rect, root_window, child_windows, root_viewport)

	for child: Control in child_windows:
		if is_instance_valid(child):
			wm._animate_window_open(child)


func layout_child_windows(source_rect: Rect2, root_window: Control, children: Array[Control], viewport: Viewport) -> void:
	if children.is_empty() or not is_instance_valid(root_window):
		return
	var root_rect: Rect2 = TooltipPositioner.get_screen_rect(root_window, viewport)
	var viewport_rect: Rect2 = viewport.get_visible_rect()
	var margin: float = 8.0
	var screen_margin: float = 12.0

	var secondary_windows: Array[Control] = []
	var glossary_windows: Array[Control] = []
	for child: Control in children:
		if is_instance_valid(child) and child.is_inside_tree():
			if child is EffectInspectionWindow:
				glossary_windows.append(child)
			else:
				secondary_windows.append(child)

	# Layout Secondary Windows (Equipped Items) - dock directly beside root_rect to form compound_rect
	var compound_rect: Rect2 = root_rect
	var place_sec_right: bool = true
	if source_rect.size != Vector2.ZERO:
		place_sec_right = root_rect.position.x >= source_rect.get_center().x
	else:
		place_sec_right = (viewport_rect.end.x - root_rect.end.x) >= (root_rect.position.x - viewport_rect.position.x)

	var sec_width: float = TooltipPositioner.INSPECTION_WINDOW_WIDTH
	var sec_x: float = (root_rect.end.x + margin) if place_sec_right else (root_rect.position.x - sec_width - margin)
	if place_sec_right and sec_x + sec_width > viewport_rect.end.x - screen_margin:
		var alt_x: float = root_rect.position.x - sec_width - margin
		if source_rect.size == Vector2.ZERO or alt_x >= source_rect.end.x:
			place_sec_right = false
			sec_x = alt_x
	elif not place_sec_right and sec_x < viewport_rect.position.x + screen_margin:
		var alt_x: float = root_rect.end.x + margin
		if source_rect.size == Vector2.ZERO or alt_x + sec_width <= source_rect.position.x:
			place_sec_right = true
			sec_x = alt_x

	for sec: Control in secondary_windows:
		var sz: Vector2 = TooltipPositioner.get_window_size(sec)
		var pos := Vector2(sec_x, root_rect.position.y)
		pos.y = clampf(pos.y, viewport_rect.position.y + screen_margin, viewport_rect.end.y - sz.y - screen_margin)
		pos.x = clampf(pos.x, viewport_rect.position.x + screen_margin, viewport_rect.end.x - sz.x - screen_margin)
		TooltipPositioner.set_window_screen_position(sec, pos)
		compound_rect = compound_rect.merge(Rect2(pos, sz))
		if place_sec_right:
			sec_x += sz.x + margin
		else:
			sec_x -= (sz.x + margin)

	if glossary_windows.is_empty():
		return

	# Layout Tertiary Glossary Cards in a Dedicated Unidirectional Outward Tray
	var space_tray_right: float = viewport_rect.end.x - compound_rect.end.x - screen_margin
	var space_tray_left: float = compound_rect.position.x - viewport_rect.position.x - screen_margin

	var tray_on_right: bool = true
	if source_rect.size != Vector2.ZERO:
		if source_rect.position.x >= compound_rect.end.x - 20.0:
			tray_on_right = false
		elif source_rect.end.x <= compound_rect.position.x + 20.0:
			tray_on_right = true
		else:
			tray_on_right = space_tray_right >= space_tray_left
	else:
		tray_on_right = space_tray_right >= space_tray_left

	var card_sizes: Array[Vector2] = []
	for gw: Control in glossary_windows:
		gw.custom_minimum_size = Vector2(TooltipPositioner.GLOSSARY_WINDOW_WIDTH, 0)
		gw.size = Vector2(TooltipPositioner.GLOSSARY_WINDOW_WIDTH, 0)
		gw.reset_size()
		card_sizes.append(TooltipPositioner.get_window_size(gw))

	var available_height: float = viewport_rect.size.y - (2.0 * screen_margin)
	var card_gap: float = 4.0
	var col_gap: float = 6.0
	var col_width: float = TooltipPositioner.GLOSSARY_WINDOW_WIDTH

	var columns: Array[Array] = []
	var cur_col: Array = []
	var cur_col_h: float = 0.0

	for i: int in range(glossary_windows.size()):
		var h: float = card_sizes[i].y
		if not cur_col.is_empty() and (cur_col_h + card_gap + h > available_height):
			columns.append(cur_col)
			cur_col = []
			cur_col_h = 0.0
		cur_col.append(i)
		cur_col_h += (card_gap if cur_col_h > 0.0 else 0.0) + h

	if not cur_col.is_empty():
		columns.append(cur_col)

	var cur_col_x: float = (compound_rect.end.x + margin) if tray_on_right else (compound_rect.position.x - margin)
	for col: Array in columns:
		var max_col_w: float = col_width
		for idx: int in col:
			max_col_w = maxf(max_col_w, card_sizes[idx].x)

		var col_x: float = cur_col_x if tray_on_right else (cur_col_x - max_col_w)
		var total_col_h: float = 0.0
		for idx: int in col:
			total_col_h += card_sizes[idx].y + card_gap
		total_col_h -= card_gap

		var cur_y: float = compound_rect.position.y
		if cur_y + total_col_h > viewport_rect.end.y - screen_margin:
			cur_y = maxf(screen_margin, viewport_rect.end.y - screen_margin - total_col_h)

		for idx: int in col:
			var card: Control = glossary_windows[idx]
			var sz: Vector2 = card_sizes[idx]
			TooltipPositioner.set_window_screen_position(card, Vector2(col_x, cur_y))
			cur_y += sz.y + card_gap

		if tray_on_right:
			cur_col_x += max_col_w + col_gap
		else:
			cur_col_x -= (max_col_w + col_gap)

	# Outer Screen Clamp
	var min_allowed_x: float = viewport_rect.position.x + screen_margin
	var max_allowed_x: float = viewport_rect.end.x - screen_margin
	for gw: Control in glossary_windows:
		if is_instance_valid(gw) and gw.is_inside_tree():
			var gw_sz: Vector2 = TooltipPositioner.get_window_size(gw)
			gw.position.x = clampf(gw.position.x, min_allowed_x, max_allowed_x - gw_sz.x)


func update_glossary_pill_for_root(wm: Node, root_window: Control) -> void:
	if not is_instance_valid(root_window) or not root_window.is_inside_tree():
		close_glossary_pill(wm)
		return
	if not (root_window is InspectionWindow or root_window is ChoiceWindow):
		close_glossary_pill(wm)
		return
	if root_window is InspectionWindow and (root_window as InspectionWindow).parent_inspection_window_id != -1:
		close_glossary_pill(wm)
		return

	var glossary_specs: Array[Dictionary] = collect_recursive_glossary_specs(root_window, wm._active_inspection_group)
	if glossary_specs.is_empty():
		close_glossary_pill(wm)
		return

	if not is_instance_valid(_glossary_pill):
		_glossary_pill = _GlossaryTogglePillScene.instantiate()
		_glossary_pill.process_mode = Node.PROCESS_MODE_ALWAYS
		wm._get_modal_layer().add_child(_glossary_pill)
		_glossary_pill.z_index = 101
		wm._register_window(_glossary_pill, false)
	else:
		_glossary_pill.z_index = 101

	_glossary_pill.show()
	update_glossary_pill_position(wm, root_window)


func update_glossary_pill_position(wm: Node, root_window: Control) -> void:
	if not is_instance_valid(_glossary_pill) or not is_instance_valid(root_window):
		return

	_glossary_pill.reset_size()
	var pill_sz: Vector2 = GlossaryTogglePill.FIXED_SIZE
	var root_viewport: Viewport = wm.get_viewport()
	var root_rect: Rect2 = TooltipPositioner.get_screen_rect(root_window, root_viewport)
	var viewport_rect: Rect2 = root_viewport.get_visible_rect()
	var margin: float = 8.0

	var x: float = root_rect.end.x - pill_sz.x
	var y: float = root_rect.end.y + 2.0
	if y + pill_sz.y > viewport_rect.end.y - margin:
		y = root_rect.position.y - pill_sz.y - 2.0

	x = clampf(x, viewport_rect.position.x + margin, viewport_rect.end.x - pill_sz.x - margin)
	y = clampf(y, viewport_rect.position.y + margin, viewport_rect.end.y - pill_sz.y - margin)
	TooltipPositioner.set_window_screen_position(_glossary_pill, Vector2(x, y))


func close_glossary_pill(wm: Node) -> void:
	if is_instance_valid(_glossary_pill):
		wm.stop_tracking_window(_glossary_pill.get_instance_id())
		_glossary_pill.queue_free()
		_glossary_pill = null


func _instantiate_child_window(wm: Node, spec: Dictionary, parent_id: int, z_idx: int, add_to_active_group: bool) -> Control:
	var w_type: StringName = spec.get("window_type", &"")
	if not wm._window_scenes.has(w_type):
		return null
	var child_instance: Control = wm._window_scenes[w_type].instantiate() as Control
	var child_insp := child_instance as InspectionWindow
	assert(child_insp != null, "Child window must be an InspectionWindow: %s" % w_type)
	var target_w: float = TooltipPositioner.GLOSSARY_WINDOW_WIDTH if w_type == &"EffectInspection" else TooltipPositioner.INSPECTION_WINDOW_WIDTH
	child_insp.custom_minimum_size = Vector2(target_w, 0)
	child_insp.parent_inspection_window_id = parent_id
	child_insp.enforce_display_only()
	child_insp.process_mode = Node.PROCESS_MODE_ALWAYS
	wm._get_modal_layer().add_child(child_insp)
	child_insp.modulate.a = 0.0
	child_insp.show()
	TooltipPositioner.set_window_screen_position(child_insp, Vector2(-2000, -2000))
	child_insp.z_index = z_idx
	child_insp.set_meta("window_type", w_type)
	wm._register_window(child_insp, false)
	if add_to_active_group:
		wm._active_inspection_group.push_back(child_insp)
	child_insp.populate(spec.get("populate_context", {}))
	child_insp.enforce_display_only()
	return child_insp
