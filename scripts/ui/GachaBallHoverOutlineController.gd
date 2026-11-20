# res://scripts/ui/GachaBallHoverOutlineController.gd
class_name GachaBallHoverOutlineController
extends RefCounted

## Manages hover/press tweening, draw-priority z-index elevation, selection
## feedback, and priority-ordered shader outlines (focus > merge > locked recipe
## > trait tier) for GachaBallView.

const C = preload("res://scripts/Constants.gd")
const InputUtils = preload("res://scripts/InputUtils.gd")
const SpriteOutline = preload("res://scripts/ui/SpriteOutline.gd")

const HOVER_SCALE: float = 0.12
const PRESS_SQUASH: float = 0.10
const INVENTORY_BRIGHTNESS_BOOST: float = 0.18
const INVENTORY_TRANSFORM_FACTOR: float = 0.92
const HOVER_RAISED_Z_INDEX: int = 40
const HOVER_RAISED_SLOT_Z_INDEX: int = 20

const RECIPE_LOCKED_OUTLINE_COLOR := Color(0.82, 0.38, 1.0)
const RECIPE_LOCKED_OUTLINE_WIDTH: float = 3.0
const MERGE_LEVEL_UP_OUTLINE_COLOR := Color(0.0, 0.95, 1.0)
const MERGE_RECIPE_TIER_UP_OUTLINE_COLOR := Color(1.0, 0.1, 0.9)
const MERGE_TARGET_OUTLINE_WIDTH: float = 3.0
const EQUIP_TARGET_OUTLINE_COLOR := Color.WHITE
const EQUIP_TARGET_OUTLINE_WIDTH: float = 3.0
const TRAIT_OUTLINE_COLORS: Array[Color] = [
	Color(0.8, 0.5, 0.2),
	Color(0.75, 0.75, 0.75),
	Color(1.0, 0.84, 0.0),
	Color(0.5, 1.0, 1.0)
]
const TRAIT_OUTLINE_WIDTH: float = 5.0

enum HoverFxMode {
	OFF,
	INVENTORY_SPHERE,
	BATTLE_NO_SHEEN,
}


func get_hover_fx_mode(view: Control) -> int:
	if not view._is_inspectable:
		return HoverFxMode.OFF
	if not is_instance_valid(view._location):
		return HoverFxMode.OFF
	if InputUtils.prefers_touch_input():
		return HoverFxMode.OFF

	var context_group: StringName = GlobalInteractionRouter.get_context_group(view._location.container)
	if context_group == &"InventoryGrid":
		return HoverFxMode.OFF
	if context_group == &"BattleBoard":
		return HoverFxMode.BATTLE_NO_SHEEN
	return HoverFxMode.OFF


func set_hover_state(view: Control, active: bool, play_sound: bool = false) -> void:
	if active and get_hover_fx_mode(view) == HoverFxMode.OFF:
		active = false
	if view._is_hovered == active:
		return
	view._is_hovered = active
	update_hover_draw_priority(view)

	if view.is_landing_bounce_active():
		return

	if active and play_sound:
		Audio.play_sfx("ui_hover", RNGManager.cosmetic_rng.randf_range(1.05, 1.12))

	animate_hover_to(view, 1.0 if active else 0.0, 0.16 if active else 0.12)
	if not active:
		animate_press_to(view, 0.0, 0.08)


func animate_hover_to(view: Control, target: float, duration: float) -> void:
	if view._interaction_mode == &"INSPECTION_ONLY":
		return
	if is_instance_valid(view._hover_tween):
		view._hover_tween.kill()
	view._hover_tween = view.create_tween()
	view._hover_tween.tween_method(view._set_hover_amount, view._hover_amount, target, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func animate_press_to(view: Control, target: float, duration: float) -> void:
	if view._interaction_mode == &"INSPECTION_ONLY":
		return
	if is_instance_valid(view._press_tween):
		view._press_tween.kill()
	view._press_tween = view.create_tween()
	view._press_tween.tween_method(view._set_press_amount, view._press_amount, target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func update_hover_animation(view: Control) -> void:
	var mode: int = get_hover_fx_mode(view)
	if view._is_dragging or GlobalInteractionRouter.is_drag_active():
		mode = HoverFxMode.OFF

	if mode == HoverFxMode.OFF and view._is_hovered:
		set_hover_state(view, false, false)

	apply_hover_visuals(view, mode)


func apply_hover_visuals(view: Control, mode: int) -> void:
	if view.is_landing_bounce_active():
		view.scale = Vector2.ONE
		view.rotation = 0.0
		apply_inventory_brightness(view, mode)
		return

	if mode == HoverFxMode.INVENTORY_SPHERE:
		view.pivot_offset = view.get_capsule_rect().get_center()
	else:
		view.pivot_offset = Vector2(view.size.x / 2.0, C.SLOT_UNIT_OFFSET_Y + C.UNIT_SPRITE_SIZE)
	var transform_factor: float = INVENTORY_TRANSFORM_FACTOR if mode == HoverFxMode.INVENTORY_SPHERE else 1.0

	var hover_scale: float = 1.0 + (HOVER_SCALE * view._hover_amount * transform_factor)
	var press_scale: float = 1.0 - (PRESS_SQUASH * view._press_amount * transform_factor)
	var stretch_x: float = 1.0 + (view._press_amount * 0.04 * transform_factor)
	var stretch_y: float = 1.0 - (view._press_amount * 0.06 * transform_factor)
	var final_scale: float = hover_scale * press_scale
	view.scale = Vector2(final_scale * stretch_x, final_scale * stretch_y)
	view.rotation = 0.0

	apply_inventory_brightness(view, mode)


func apply_inventory_brightness(view: Control, mode: int) -> void:
	var sprite: TextureRect = view._get_active_visual_sprite()
	if not is_instance_valid(sprite):
		return
	if mode == HoverFxMode.INVENTORY_SPHERE:
		var effective_hover: float = view._hover_amount
		if view._is_selected:
			effective_hover = maxf(effective_hover, 1.0)
		var brightness: float = 1.0 + (INVENTORY_BRIGHTNESS_BOOST * effective_hover)
		sprite.modulate = Color(brightness, brightness, brightness, 1.0)
	else:
		sprite.modulate = Color.WHITE


func update_hover_draw_priority(view: Control) -> void:
	var raise_priority: bool = view._is_hovered and get_hover_fx_mode(view) != HoverFxMode.OFF
	if view._is_selected and view._has_overlay_heuristic():
		raise_priority = true
	view.z_index = HOVER_RAISED_Z_INDEX if raise_priority else view._base_z_index
	if is_instance_valid(view._slot_view_ref):
		view._slot_view_ref.z_index = HOVER_RAISED_SLOT_Z_INDEX if raise_priority else view._slot_base_z_index


func apply_selection_feedback(view: Control) -> void:
	if not view.is_inside_tree() or not is_instance_valid(view.icon_rect):
		return
	update_hover_draw_priority(view)

	var overlay: Node2D = view.get_node_or_null("GachaBallOverlay") as Node2D
	var use_inventory_capsule_feedback: bool = is_instance_valid(overlay) and view._has_overlay_heuristic()
	if use_inventory_capsule_feedback:
		var selection_ring: Node = view.get_node_or_null("SelectionRing")
		if is_instance_valid(selection_ring):
			selection_ring.queue_free()
		var overlay_base_scale: Vector2 = overlay.get_meta("base_scale", Vector2.ONE)
		overlay.scale = overlay_base_scale * (1.05 if view._is_selected else 1.0)
		overlay.modulate = Color(1.3, 1.3, 1.3) if view._is_selected else Color.WHITE
	update_outline_visuals(view)


static func set_shader_outline(mat: ShaderMaterial, enabled: bool, color: Color = Color.WHITE, width: float = 3.0) -> void:
	if not is_instance_valid(mat):
		return
	mat.set_shader_parameter("outline_enabled", enabled)
	if enabled:
		mat.set_shader_parameter("outline_color", color)
		mat.set_shader_parameter("outline_width", width)


static func resolve_outline_spec(
	focused: bool,
	merge_target_type: StringName,
	has_locked_recipe: bool,
	is_reward_or_shop: bool,
	last_trait_level: int,
	is_in_battle: bool
) -> Dictionary:
	if focused:
		return {"enabled": false, "color": Color.WHITE, "width": 3.0}
	if merge_target_type == &"LEVEL_UP":
		return {"enabled": true, "color": MERGE_LEVEL_UP_OUTLINE_COLOR, "width": MERGE_TARGET_OUTLINE_WIDTH}
	if merge_target_type == &"RECIPE_TIER_UP":
		return {"enabled": true, "color": MERGE_RECIPE_TIER_UP_OUTLINE_COLOR, "width": MERGE_TARGET_OUTLINE_WIDTH}
	if merge_target_type == &"EQUIP":
		return {"enabled": true, "color": EQUIP_TARGET_OUTLINE_COLOR, "width": EQUIP_TARGET_OUTLINE_WIDTH}
	if has_locked_recipe and is_reward_or_shop:
		return {"enabled": true, "color": RECIPE_LOCKED_OUTLINE_COLOR, "width": RECIPE_LOCKED_OUTLINE_WIDTH}
	if last_trait_level > 0 and is_in_battle:
		var color_idx: int = mini(last_trait_level - 1, TRAIT_OUTLINE_COLORS.size() - 1)
		return {"enabled": true, "color": TRAIT_OUTLINE_COLORS[color_idx], "width": TRAIT_OUTLINE_WIDTH}
	return {"enabled": false, "color": Color.WHITE, "width": 3.0}


func update_outline_visuals(view: Control) -> void:
	if not is_instance_valid(view.icon_rect):
		return

	var unit_sprite: TextureRect = view.icon_rect.get_node_or_null("UnitSprite") as TextureRect
	var unit_sprite_mat: ShaderMaterial = unit_sprite.material as ShaderMaterial if is_instance_valid(unit_sprite) and is_instance_valid(unit_sprite.material) else null
	var icon_mat: ShaderMaterial = view.icon_rect.material as ShaderMaterial if is_instance_valid(view.icon_rect.material) else null

	var focused: bool = view._is_selected or view._is_inspected
	var use_unit_sprite: bool = view.icon_rect.texture == null and unit_sprite != null
	SpriteOutline.set_highlight(view.icon_rect, focused and not use_unit_sprite)
	if unit_sprite != null:
		SpriteOutline.set_highlight(unit_sprite, focused and use_unit_sprite)

	var spec: Dictionary = resolve_outline_spec(
		focused,
		view._merge_target_type,
		view._has_locked_recipe,
		view._is_reward_or_shop_context(),
		view._last_trait_level,
		GameManager.is_in_battle
	)
	var enabled: bool = bool(spec["enabled"])
	var color: Color = spec["color"]
	var width: float = float(spec["width"])
	set_shader_outline(unit_sprite_mat, enabled, color, width)
	set_shader_outline(icon_mat, enabled, color, width)
