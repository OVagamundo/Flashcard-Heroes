# res://scripts/ui/TooltipPositioner.gd
class_name TooltipPositioner
extends RefCounted

## Pure geometric positioning, screen-space rect conversion, sizing, and
## viewport clamping for contextual tooltips, inspection windows, and child panels.

const INSPECTION_WINDOW_MARGIN: float = 20.0
const INSPECTION_WINDOW_WIDTH: float = 360.0
const GLOSSARY_WINDOW_WIDTH: float = 260.0


static func get_screen_rect(ctrl: Control, root_viewport: Viewport) -> Rect2:
	if not is_instance_valid(ctrl):
		return Rect2()
	var size: Vector2 = ctrl.size
	if size == Vector2.ZERO:
		var min_sz: Vector2 = ctrl.get_combined_minimum_size()
		if min_sz != Vector2.ZERO:
			size = min_sz
	var xf: Transform2D = ctrl.get_global_transform_with_canvas()
	var p0: Vector2 = xf * Vector2(0, 0)
	var p1: Vector2 = xf * Vector2(size.x, 0)
	var p2: Vector2 = xf * Vector2(0, size.y)
	var p3: Vector2 = xf * Vector2(size.x, size.y)
	var min_x: float = minf(p0.x, minf(p1.x, minf(p2.x, p3.x)))
	var max_x: float = maxf(p0.x, maxf(p1.x, maxf(p2.x, p3.x)))
	var min_y: float = minf(p0.y, minf(p1.y, minf(p2.y, p3.y)))
	var max_y: float = maxf(p0.y, maxf(p1.y, maxf(p2.y, p3.y)))
	var rect := Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
	var viewport: Viewport = ctrl.get_viewport()
	if viewport != root_viewport and viewport is SubViewport:
		var viewport_host: Node = viewport.get_parent()
		if viewport_host is SubViewportContainer:
			var host_rect: Rect2 = get_screen_rect(viewport_host as Control, root_viewport)
			var viewport_size := Vector2(viewport.size)
			if viewport_size.x > 0.0 and viewport_size.y > 0.0:
				var scale := Vector2(
					host_rect.size.x / viewport_size.x,
					host_rect.size.y / viewport_size.y
				)
				rect.position = host_rect.position + rect.position * scale
				rect.size *= scale
			else:
				rect.position += host_rect.position
	return rect


static func set_window_screen_position(window: Control, screen_pos: Vector2) -> void:
	var parent: Node = window.get_parent()
	if parent is CanvasItem:
		var parent_xf: Transform2D = (parent as CanvasItem).get_global_transform_with_canvas()
		var parent_inv: Transform2D = parent_xf.affine_inverse()
		window.position = parent_inv * screen_pos
	else:
		window.global_position = screen_pos


static func find_canvas_layer(node: Node) -> CanvasLayer:
	var current: Node = node
	while is_instance_valid(current):
		if current is CanvasLayer:
			return current as CanvasLayer
		current = current.get_parent()
	return null


static func get_window_size(window: Control) -> Vector2:
	if window is EffectInspectionWindow:
		window.custom_minimum_size = Vector2(GLOSSARY_WINDOW_WIDTH, 0)
		window.size = Vector2(GLOSSARY_WINDOW_WIDTH, 0)
		window.reset_size()
		var min_sz: Vector2 = window.get_combined_minimum_size()
		return Vector2(GLOSSARY_WINDOW_WIDTH, maxf(min_sz.y, window.size.y))
	elif window is InspectionWindow or window is ChoiceWindow:
		window.custom_minimum_size = Vector2(INSPECTION_WINDOW_WIDTH, 0)
		window.size = Vector2(INSPECTION_WINDOW_WIDTH, 0)
		window.reset_size()
		var min_sz: Vector2 = window.get_combined_minimum_size()
		if min_sz != Vector2.ZERO:
			return Vector2(maxf(min_sz.x, INSPECTION_WINDOW_WIDTH), min_sz.y)

	var sz: Vector2 = window.size
	if sz == Vector2.ZERO:
		var min_sz: Vector2 = window.get_combined_minimum_size()
		if min_sz != Vector2.ZERO:
			return min_sz
	return sz


static func clamp_window_to_viewport(pos: Vector2, size: Vector2, viewport_rect: Rect2) -> Vector2:
	var margin: float = INSPECTION_WINDOW_MARGIN
	var x: float = clampf(pos.x, viewport_rect.position.x + margin, viewport_rect.end.x - size.x - margin)
	var y: float = clampf(pos.y, viewport_rect.position.y + margin, viewport_rect.end.y - size.y - margin)
	return Vector2(x, y)


static func calculate_window_position(
	source_view: Control,
	new_window: Control,
	viewport: Viewport,
	is_glossary_locked: bool,
	has_glossary_specs: bool
) -> Vector2:
	if not is_instance_valid(source_view):
		return Vector2.ZERO
	var src: Rect2 = get_screen_rect(source_view, viewport)
	var win_sz: Vector2 = get_window_size(new_window)
	var viewport_rect: Rect2 = viewport.get_visible_rect()
	var margin: float = INSPECTION_WINDOW_MARGIN
	var screen_margin: float = 12.0

	var required_width: float = win_sz.x
	if is_glossary_locked and has_glossary_specs:
		required_width += 8.0 + GLOSSARY_WINDOW_WIDTH

	var space_right: float = viewport_rect.end.x - src.end.x - margin - screen_margin
	var space_left: float = src.position.x - viewport_rect.position.x - margin - screen_margin

	var place_right: bool = true
	if space_right >= required_width and space_left >= required_width:
		place_right = space_right >= space_left
	elif space_right >= required_width:
		place_right = true
	elif space_left >= required_width:
		place_right = false
	else:
		place_right = space_right >= space_left

	var x: float = (src.end.x + margin) if place_right else (src.position.x - win_sz.x - margin)
	var max_x: float = (viewport_rect.end.x - required_width - screen_margin) if (place_right and is_glossary_locked) else (viewport_rect.end.x - win_sz.x - screen_margin)
	var min_x: float = (viewport_rect.position.x + screen_margin + (required_width - win_sz.x)) if (not place_right and is_glossary_locked) else (viewport_rect.position.x + screen_margin)
	x = clampf(x, min_x, max_x)

	# SACRED ANCHOR INVARIANT: Window must NEVER overlap src horizontally
	if place_right and x < src.end.x:
		if space_left >= win_sz.x:
			x = src.position.x - win_sz.x - margin
	elif not place_right and x + win_sz.x > src.position.x:
		if space_right >= win_sz.x:
			x = src.end.x + margin

	# Vertical: align the window's base (bottom) with the source center
	var y: float = src.get_center().y - win_sz.y
	y = clampf(y, viewport_rect.position.y + screen_margin, viewport_rect.end.y - win_sz.y - screen_margin)

	return Vector2(x, y)


static func calculate_child_window_position_from_anchor(anchor: Control, child_window: Control, viewport: Viewport) -> Vector2:
	var anchor_rect: Rect2 = get_screen_rect(anchor, viewport)
	var child_sz: Vector2 = get_window_size(child_window)
	var viewport_rect: Rect2 = viewport.get_visible_rect()
	var vp_center: Vector2 = viewport_rect.get_center()

	var place_right: bool = anchor_rect.get_center().x <= vp_center.x
	var x: float = (anchor_rect.end.x + INSPECTION_WINDOW_MARGIN) if place_right else (anchor_rect.position.x - child_sz.x - INSPECTION_WINDOW_MARGIN)
	var y: float = anchor_rect.get_center().y - child_sz.y

	return clamp_window_to_viewport(Vector2(x, y), child_sz, viewport_rect)


static func calculate_centered_over_anchor(anchor: Control, new_window: Control, viewport: Viewport) -> Vector2:
	var anchor_rect: Rect2 = get_screen_rect(anchor, viewport)
	var window_size: Vector2 = get_window_size(new_window)
	var desired: Vector2 = anchor_rect.get_center() - window_size / 2.0
	return clamp_window_to_viewport(desired, window_size, viewport.get_visible_rect())


static func calculate_top_center_over_anchor(anchor: Control, new_window: Control, viewport: Viewport) -> Vector2:
	var viewport_rect: Rect2 = viewport.get_visible_rect()
	var anchor_rect: Rect2 = get_screen_rect(anchor, viewport)
	var window_size: Vector2 = get_window_size(new_window)
	var margin: float = INSPECTION_WINDOW_MARGIN

	var x: float = anchor_rect.get_center().x - window_size.x / 2.0
	var above_y: float = anchor_rect.position.y - window_size.y - margin
	var below_y: float = anchor_rect.end.y + margin

	var viewport_top: float = float(viewport_rect.position.y) + margin
	var viewport_bottom: float = float(viewport_rect.end.y) - window_size.y - margin

	var y: float
	if above_y >= viewport_top:
		y = above_y
	elif below_y <= viewport_bottom:
		y = below_y
	else:
		var space_above: float = float(anchor_rect.position.y) - float(viewport_rect.position.y) - margin
		var space_below: float = float(viewport_rect.end.y) - float(anchor_rect.end.y) - margin
		y = above_y if space_above >= space_below else below_y

	return clamp_window_to_viewport(Vector2(x, y), window_size, viewport_rect)


static func calculate_left_of_anchor(anchor: Control, new_window: Control, viewport: Viewport) -> Vector2:
	var viewport_rect: Rect2 = viewport.get_visible_rect()
	var anchor_rect: Rect2 = get_screen_rect(anchor, viewport)
	var win_sz: Vector2 = get_window_size(new_window)
	var margin: float = INSPECTION_WINDOW_MARGIN
	var viewport_left: float = float(viewport_rect.position.x) + margin

	var x_left: float = anchor_rect.position.x - win_sz.x - margin
	var x: float = x_left if x_left >= viewport_left else (anchor_rect.end.x + margin)

	var vp_center_y: float = float(viewport_rect.get_center().y)
	var align_top: bool = anchor_rect.get_center().y <= vp_center_y
	var y: float = anchor_rect.position.y if align_top else (anchor_rect.end.y - win_sz.y)

	return clamp_window_to_viewport(Vector2(x, y), win_sz, viewport_rect)


static func calculate_child_window_position(parent_window: Control, child_window: Control, viewport: Viewport) -> Vector2:
	var viewport_rect: Rect2 = viewport.get_visible_rect()
	var vp_center: Vector2 = viewport_rect.get_center()
	var parent_rect: Rect2 = get_screen_rect(parent_window, viewport)
	var child_sz: Vector2 = get_window_size(child_window)
	var place_right: bool = parent_rect.get_center().x <= vp_center.x
	var x: float = (parent_rect.end.x + INSPECTION_WINDOW_MARGIN) if place_right else (parent_rect.position.x - child_sz.x - INSPECTION_WINDOW_MARGIN)
	var align_top: bool = parent_rect.get_center().y <= vp_center.y
	var y: float = parent_rect.position.y if align_top else (parent_rect.end.y - child_sz.y)
	return clamp_window_to_viewport(Vector2(x, y), child_sz, viewport_rect)


static func calculate_contextual_window_position(
	anchor: Control,
	parent_window: Control,
	window: Control,
	pos_hint: String,
	viewport: Viewport,
	is_glossary_locked: bool,
	has_glossary_specs: bool
) -> Vector2:
	if is_instance_valid(parent_window):
		if pos_hint == "use_parent_window":
			return calculate_child_window_position(parent_window, window, viewport)
		elif is_instance_valid(anchor):
			return calculate_child_window_position_from_anchor(anchor, window, viewport)
		return calculate_child_window_position(parent_window, window, viewport)
	elif is_instance_valid(anchor):
		if pos_hint == "center_over_anchor":
			return calculate_centered_over_anchor(anchor, window, viewport)
		elif pos_hint == "top_center_over_anchor":
			return calculate_top_center_over_anchor(anchor, window, viewport)
		elif pos_hint == "left_of_anchor":
			return calculate_left_of_anchor(anchor, window, viewport)
		return calculate_window_position(anchor, window, viewport, is_glossary_locked, has_glossary_specs)
	else:
		var viewport_rect: Rect2 = viewport.get_visible_rect()
		return Vector2(viewport_rect.position) + Vector2(viewport_rect.size) / 2.0 - get_window_size(window) / 2.0
