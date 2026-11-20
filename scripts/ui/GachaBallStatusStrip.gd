# res://scripts/ui/GachaBallStatusStrip.gd
class_name GachaBallStatusStrip
extends RefCounted

## Manages stat pill styling, battle vs overlay stat layouts, dynamic status
## effect icon creation, status/stat pop animations, and status tooltip click routing
## for GachaBallView.

const InputUtils = preload("res://scripts/InputUtils.gd")
const C = preload("res://scripts/Constants.gd")
const FONT_BLACK_PATH := "res://assets/fonts/static/NotoSansJP-Black.ttf"

var _pop_tweens: Dictionary[int, Tween] = {}


func animate_burn_change(view: Control, target_stacks: int) -> void:
	var old_stacks: int = view._visual_burn_stacks
	view._visual_burn_stacks = target_stacks

	if target_stacks > 0:
		view.burn_container.visible = true
		view.burn_label.text = str(target_stacks)

		if old_stacks == 0:
			view.burn_container.scale = Vector2.ZERO
			var tween: Tween = view.create_tween()
			tween.tween_property(view.burn_container, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_callback(func() -> void:
				pop_container(view, view.burn_container)
				Audio.play_sfx("status_burn", RNGManager.cosmetic_rng.randf_range(0.95, 1.05))
			)
		elif target_stacks > old_stacks:
			pop_container(view, view.burn_container)
			Audio.play_sfx("status_burn", RNGManager.cosmetic_rng.randf_range(0.95, 1.05))

		flash_label(view, view.burn_label)
	else:
		var tween: Tween = view.create_tween()
		tween.tween_property(view.burn_container, "scale", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			if is_instance_valid(view.burn_container):
				view.burn_container.visible = false
		)


func animate_armor_change(view: Control, target_stacks: int) -> void:
	var old_stacks: int = view._visual_armor_stacks
	view._visual_armor_stacks = target_stacks

	if target_stacks > 0:
		view.armor_container.visible = true
		view.armor_label.text = str(target_stacks)

		if old_stacks == 0:
			view.armor_container.scale = Vector2.ZERO
			var tween: Tween = view.create_tween()
			tween.tween_property(view.armor_container, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_callback(func() -> void:
				pop_container(view, view.armor_container)
				Audio.play_sfx("status_armor", RNGManager.cosmetic_rng.randf_range(0.95, 1.05))
			)
		elif target_stacks > old_stacks:
			pop_container(view, view.armor_container)
			Audio.play_sfx("status_armor", RNGManager.cosmetic_rng.randf_range(0.95, 1.05))

		flash_label(view, view.armor_label)
		view._animate_number(view.armor_label, old_stacks, target_stacks)
	else:
		var tween: Tween = view.create_tween()
		tween.tween_property(view.armor_container, "scale", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			if is_instance_valid(view.armor_container):
				view.armor_container.visible = false
		)


func animate_armor_stat_change(view: Control, target_stacks: int) -> void:
	var start_val: int = view._visual_armor_stacks
	view._visual_armor_stacks = target_stacks

	if target_stacks > 0:
		view.armor_container.visible = true
		flash_label(view, view.armor_label)
		var tween: Tween = view.create_tween()
		tween.tween_method(func(val: int) -> void: view.armor_label.text = str(val), start_val, target_stacks, 0.3)
	elif start_val > 0:
		view.armor_container.visible = true
		flash_label(view, view.armor_label)
		var tween: Tween = view.create_tween()
		tween.tween_method(func(val: int) -> void: view.armor_label.text = str(maxi(0, val)), start_val, 0, 0.3)
		tween.tween_property(view.armor_container, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			if is_instance_valid(view.armor_container):
				view.armor_container.visible = false
		)


func update_dynamic_status_icons(view: Control, animate: bool = true) -> void:
	var stats_container: Node = view.get_node_or_null("StatsOverlay/BottomStatsContainer")
	var underlay: Control = view.get_node_or_null("%StatsUnderlay") as Control
	var row2: Control = view.get_node_or_null("%Row2") as Control
	if is_instance_valid(underlay) and underlay.visible and is_instance_valid(row2):
		stats_container = row2

	if not is_instance_valid(stats_container):
		return

	for status_id in view._status_icon_nodes:
		var node: Control = view._status_icon_nodes[status_id] as Control
		if is_instance_valid(node):
			node.visible = false

	for status_id in view._visual_status_effects:
		var stacks: int = int(view._visual_status_effects[status_id])
		if status_id == &"burn" or status_id == &"armor":
			continue
		if stacks > 0:
			if not view._status_icon_nodes.has(status_id):
				create_status_icon(view, status_id, stats_container, animate)
			var icon_node: Control = view._status_icon_nodes.get(status_id) as Control
			if is_instance_valid(icon_node):
				icon_node.visible = true
				var label: Label = icon_node.get_node_or_null("Label") as Label
				if is_instance_valid(label):
					var visual_current: int = label.text.to_int()
					if animate and visual_current != stacks:
						view._animate_number(label, visual_current, stacks)
						if stacks > visual_current:
							pop_container(view, icon_node)
							if status_id == &"spikes":
								Audio.play_sfx("status_spikes", RNGManager.cosmetic_rng.randf_range(0.95, 1.05))
						flash_label(view, label)
					else:
						label.text = str(stacks)


func create_status_icon(view: Control, status_id: StringName, parent: Node, animate: bool = true) -> void:
	var effect_def: CombatEffectDefinition = CombatEffectRegistry.get_definition(status_id)
	if not is_instance_valid(effect_def):
		return

	var size_scale: float = view._size_scale
	var container_size: float = 8.0 * size_scale + 16.0
	var font_size: int = int(18.0 * size_scale - 4.0)
	var outline_size: int = int(4.0 * size_scale)

	var hbox := HBoxContainer.new()
	hbox.name = str(status_id) + "Container"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 4)
	apply_plastic_pill_style(hbox, size_scale)

	var status_icon_rect := TextureRect.new()
	status_icon_rect.name = "Icon"
	status_icon_rect.custom_minimum_size = Vector2(container_size, container_size)
	status_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	status_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	status_icon_rect.texture = effect_def.icon

	var label := Label.new()
	label.name = "Label"
	label.layout_mode = 2
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", load(FONT_BLACK_PATH))

	hbox.add_child(status_icon_rect)
	hbox.add_child(label)
	parent.add_child(hbox)
	view._status_icon_nodes[status_id] = hbox

	hbox.scale = Vector2.ONE
	if animate:
		hbox.scale = Vector2.ZERO
		var tween: Tween = view.create_tween()
		tween.tween_property(hbox, "scale", Vector2.ONE, AnimationConstants.scaled(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func animate_status_change(view: Control, status_id: StringName, new_stacks: int) -> void:
	var old_stacks: int = int(view._visual_status_effects.get(status_id, 0))
	view._visual_status_effects[status_id] = new_stacks
	update_dynamic_status_icons(view)
	if new_stacks > old_stacks:
		var icon_node: Control = view._status_icon_nodes.get(status_id) as Control
		if is_instance_valid(icon_node):
			pop_container(view, icon_node)


func animate_stat_change(view: Control, target_val: int, type: String, trigger_reactions: bool = true) -> void:
	var label: Label = view.hp_label if type == "hp" else view.pwr_label
	var container: Control = view.hp_container if type == "hp" else view.pwr_container
	var start_val: int = view._visual_hp if type == "hp" else view._visual_pwr

	if type == "hp":
		view._visual_hp = target_val
	else:
		view._visual_pwr = target_val

	if target_val > start_val:
		pop_container(view, container)

	flash_label(view, label)

	var tween: Tween = view.create_tween()
	tween.tween_method(func(val: int) -> void: label.text = str(val), start_val, target_val, AnimationConstants.scaled(0.5))

	if trigger_reactions:
		if target_val > start_val:
			SignalBus.emit_signal("unit_color_flash", view._instance_uuid, AnimationConstants.COLOR_HEAL_BUFF, AnimationConstants.FLASH_FADE_DURATION)
			SignalBus.emit_signal("unit_deform", view._instance_uuid, &"HOP_DEFORM")
			SignalBus.emit_signal("unit_move", view._instance_uuid, &"HOP", Vector2.ZERO)
		elif target_val < start_val:
			SignalBus.emit_signal("unit_color_flash", view._instance_uuid, Color(0.4, 0.4, 0.4), AnimationConstants.FLASH_FADE_DURATION)


func flash_label(view: Control, label: Label) -> void:
	if not is_instance_valid(label):
		return
	var original_modulate: Color = label.modulate
	label.modulate = Color(2.0, 2.0, 2.0, 1.0)
	var tween: Tween = view.create_tween()
	tween.tween_property(label, "modulate", original_modulate, AnimationConstants.scaled(0.2)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func pop_container(view: Control, container: Control) -> void:
	if not is_instance_valid(container):
		return
	var cid: int = container.get_instance_id()
	if _pop_tweens.has(cid):
		var existing: Tween = _pop_tweens[cid]
		if is_instance_valid(existing):
			existing.kill()
		_pop_tweens.erase(cid)

	if container.size == Vector2.ZERO:
		container.pivot_offset = container.custom_minimum_size / 2.0
	else:
		container.pivot_offset = container.size / 2.0

	var pop_tween: Tween = view.create_tween()
	_pop_tweens[cid] = pop_tween
	var flash_color := Color(1.0, 0.9, 0.2, 1.0)
	pop_tween.set_parallel(true)
	pop_tween.tween_property(container, "scale", Vector2(1.4, 1.4), AnimationConstants.scaled(0.1)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(container, "scale", Vector2.ONE, AnimationConstants.scaled(0.15)).set_delay(AnimationConstants.scaled(0.1)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(container, "modulate", flash_color, AnimationConstants.scaled(0.05))
	pop_tween.tween_property(container, "modulate", Color.WHITE, AnimationConstants.scaled(0.2)).set_delay(AnimationConstants.scaled(0.05))


func setup_status_effect_click_handlers(view: Control) -> void:
	if is_instance_valid(view.burn_container):
		view.burn_container.mouse_filter = Control.MOUSE_FILTER_STOP
		view.burn_container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if not view.burn_container.is_connected("gui_input", view._on_burn_container_clicked):
			view.burn_container.gui_input.connect(view._on_burn_container_clicked)
	if is_instance_valid(view.armor_container):
		view.armor_container.mouse_filter = Control.MOUSE_FILTER_STOP
		view.armor_container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if not view.armor_container.is_connected("gui_input", view._on_armor_container_clicked):
			view.armor_container.gui_input.connect(view._on_armor_container_clicked)


func open_status_effect_tooltip(location: LocationIdentifier, status_id: StringName) -> void:
	var action := InspectEntityAction.new(location, false, &"EffectInspection", status_id)
	ActionQueue.request(action)


func setup_battle_stats_layout(view: Control) -> void:
	var underlay: Control = view.get_node_or_null("%StatsUnderlay") as Control
	var overlay: Control = view.get_node_or_null("%StatsOverlay") as Control
	var row1: Control = view.get_node_or_null("%Row1") as Control
	var row2: Control = view.get_node_or_null("%Row2") as Control
	if not is_instance_valid(underlay):
		return

	overlay.visible = false
	underlay.visible = true

	if view.hp_container.get_parent() != row1:
		view.hp_container.reparent(row1)
		view.pwr_container.reparent(row1)

	var size_scale: float = view._size_scale
	apply_plastic_pill_style(view.hp_container, size_scale)
	apply_plastic_pill_style(view.pwr_container, size_scale)

	var standard_font_size: int = 32
	var standard_outline_size: int = 8
	var standard_icon_size := Vector2(32, 32)
	var font_black: Font = load(FONT_BLACK_PATH)

	view.hp_label.add_theme_color_override("font_color", Color.RED)
	view.hp_label.add_theme_color_override("font_outline_color", Color.WHITE)
	view.hp_label.add_theme_constant_override("outline_size", standard_outline_size)
	view.hp_label.add_theme_font_size_override("font_size", standard_font_size)

	view.pwr_label.add_theme_color_override("font_color", Color.BLACK)
	view.pwr_label.add_theme_color_override("font_outline_color", Color.WHITE)
	view.pwr_label.add_theme_constant_override("outline_size", standard_outline_size)
	view.pwr_label.add_theme_font_size_override("font_size", standard_font_size)

	underlay.offset_top = -28
	underlay.offset_bottom = -28

	var hp_icon: Control = view.get_node_or_null("%HPIcon") as Control
	var pwr_icon: Control = view.get_node_or_null("%PWRIcon") as Control
	if is_instance_valid(hp_icon):
		hp_icon.custom_minimum_size = standard_icon_size
	if is_instance_valid(pwr_icon):
		pwr_icon.custom_minimum_size = standard_icon_size

	if view.burn_container.get_parent() != row2:
		view.burn_container.reparent(row2)
		view.armor_container.reparent(row2)

	apply_plastic_pill_style(view.burn_container, size_scale)
	apply_plastic_pill_style(view.armor_container, size_scale)
	view.burn_container.custom_minimum_size = Vector2.ZERO
	view.armor_container.custom_minimum_size = Vector2.ZERO

	var burn_icon: Control = view.get_node_or_null("%BurnIcon") as Control
	var armor_icon: Control = view.get_node_or_null("%ArmorIcon") as Control
	if is_instance_valid(burn_icon):
		burn_icon.custom_minimum_size = standard_icon_size
	if is_instance_valid(armor_icon):
		armor_icon.custom_minimum_size = standard_icon_size

	for lbl: Label in [view.burn_label, view.armor_label]:
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", standard_outline_size)
		lbl.add_theme_font_size_override("font_size", standard_font_size)
		lbl.add_theme_font_override("font", font_black)


static func apply_plastic_pill_style(container: HBoxContainer, size_scale: float) -> void:
	if not is_instance_valid(container):
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.45)

	var radius: int = int(6.0 * size_scale)
	var h_margin: int = int(4.0 * size_scale)
	var v_margin: int = int(1.0 * size_scale)
	style.set_corner_radius_all(radius)
	style.content_margin_left = h_margin + 2
	style.content_margin_right = h_margin + 4
	style.content_margin_top = v_margin
	style.content_margin_bottom = v_margin
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_color = Color(1, 1, 1, 0.15)

	container.add_theme_stylebox_override("panel", style)
	container.add_theme_constant_override("separation", int(3.0 * size_scale))


func setup_overlay_stats_layout(view: Control, is_shelf_capsule: bool) -> void:
	var overlay: Control = view.get_node_or_null("%StatsOverlay") as Control
	var underlay: Control = view.get_node_or_null("%StatsUnderlay") as Control
	if not is_instance_valid(overlay):
		return

	underlay.visible = false
	overlay.visible = true

	var top_container: Control = view.get_node_or_null("%StatsContainer") as Control
	var bottom_container: Control = view.get_node_or_null("%BottomStatsContainer") as Control
	if not is_instance_valid(top_container) or not is_instance_valid(bottom_container):
		return

	var size_scale: float = view._size_scale
	var container_size: float = 8.0 * size_scale + 16.0
	var font_size: int = int(18.0 * size_scale - 4.0)
	var outline_size: int = int(4.0 * size_scale)
	var font_black: Font = load(FONT_BLACK_PATH)

	top_container.anchors_preset = Control.PRESET_CENTER_TOP
	top_container.offset_top = C.SHELF_SURFACE_Y + 5 if is_shelf_capsule else 85.0 * size_scale

	if view.hp_container.get_parent() != top_container:
		view.hp_container.reparent(top_container)
		view.pwr_container.reparent(top_container)

	apply_plastic_pill_style(view.hp_container, size_scale)
	apply_plastic_pill_style(view.pwr_container, size_scale)
	view.hp_container.custom_minimum_size = Vector2.ZERO
	view.pwr_container.custom_minimum_size = Vector2.ZERO

	var hp_icon: Control = view.get_node_or_null("%HPIcon") as Control
	var pwr_icon: Control = view.get_node_or_null("%PWRIcon") as Control
	if is_instance_valid(hp_icon):
		hp_icon.custom_minimum_size = Vector2(container_size, container_size)
	if is_instance_valid(pwr_icon):
		pwr_icon.custom_minimum_size = Vector2(container_size, container_size)

	view.hp_label.add_theme_color_override("font_color", Color.RED)
	view.hp_label.add_theme_color_override("font_outline_color", Color.WHITE)
	view.hp_label.add_theme_font_size_override("font_size", font_size)
	view.hp_label.add_theme_constant_override("outline_size", outline_size)
	view.hp_label.add_theme_font_override("font", font_black)

	view.pwr_label.add_theme_color_override("font_color", Color.BLACK)
	view.pwr_label.add_theme_color_override("font_outline_color", Color.WHITE)
	view.pwr_label.add_theme_font_size_override("font_size", font_size)
	view.pwr_label.add_theme_constant_override("outline_size", outline_size)
	view.pwr_label.add_theme_font_override("font", font_black)

	if view.burn_container.get_parent() != bottom_container:
		view.burn_container.reparent(bottom_container)
		view.armor_container.reparent(bottom_container)

	apply_plastic_pill_style(view.burn_container, size_scale)
	apply_plastic_pill_style(view.armor_container, size_scale)
	view.burn_container.custom_minimum_size = Vector2.ZERO
	view.armor_container.custom_minimum_size = Vector2.ZERO

	var burn_icon: Control = view.get_node_or_null("%BurnIcon") as Control
	var armor_icon: Control = view.get_node_or_null("%ArmorIcon") as Control
	if is_instance_valid(burn_icon):
		burn_icon.custom_minimum_size = Vector2(container_size, container_size)
	if is_instance_valid(armor_icon):
		armor_icon.custom_minimum_size = Vector2(container_size, container_size)

	for lbl: Label in [view.burn_label, view.armor_label]:
		lbl.add_theme_font_size_override("font_size", font_size)
		lbl.add_theme_constant_override("outline_size", outline_size)
		lbl.add_theme_font_override("font", font_black)
