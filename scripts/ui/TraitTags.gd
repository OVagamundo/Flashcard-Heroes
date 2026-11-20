extends HFlowContainer

const TRAIT_COLORS: Dictionary = {
	"FIRE": Color(0.85, 0.22, 0.12, 1.0),       # Fiery Vermilion
	"EARTH": Color(0.58, 0.35, 0.18, 1.0),      # Terracotta Brown
	"WATER": Color(0.12, 0.46, 0.86, 1.0),      # Ocean Blue
	"AIR": Color(0.15, 0.68, 0.82, 1.0),        # Sky Cyan
	"TANK": Color(0.32, 0.42, 0.54, 1.0),       # Slate Steel
	"FIGHTER": Color(0.72, 0.12, 0.22, 1.0),    # Ruby Crimson
	"SUPPORT": Color(0.12, 0.65, 0.48, 1.0),    # Emerald Mint
	"SPECIALIST": Color(0.58, 0.22, 0.78, 1.0), # Royal Violet
	"MERCENARY": Color(0.85, 0.65, 0.15, 1.0),  # Mercenary Amber/Gold
	"NOVICE": Color(0.38, 0.44, 0.52, 1.0),     # Slate Steel Grey
	"FOOD": Color(0.85, 0.42, 0.05, 1.0),       # Warm Tangerine
	"MECHA": Color(0.24, 0.28, 0.33, 1.0),      # Dark Gunmetal
	"ANIMAL": Color(0.48, 0.56, 0.18, 1.0),     # Wild Olive
	"PLANT": Color(0.18, 0.58, 0.18, 1.0),      # Leaf Green
	"TOY": Color(0.85, 0.18, 0.55, 1.0),        # Hot Pink
	"APPLIANCE": Color(0.78, 0.55, 0.06, 1.0),  # Electric Amber Gold
	"COSTUME": Color(0.34, 0.14, 0.52, 1.0)     # Velvet Indigo
}

func populate(instance: GachaBallInstance, all_instances: Dictionary = {}) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

	if instance == null:
		hide()
		return

	var soul_counts: Dictionary = instance.get_trait_soul_counts(all_instances)
	var active_traits: Array[String] = []
	for tag: StringName in instance.get_active_tags(all_instances):
		active_traits.append(String(tag).to_upper())

	for trait_id: String in C.TRAIT_SORT_ORDER:
		var trait_name: String = tr(C.TRAIT_DEFINITIONS[trait_id].display_name_key)
		if soul_counts.has(trait_id):
			var count: int = soul_counts[trait_id]
			if count > 0:
				_create_trait_tag(trait_id, "%dx %s" % [count, trait_name])
		elif active_traits.has(trait_id):
			_create_trait_tag(trait_id, trait_name)

	visible = get_child_count() > 0


func _create_trait_tag(trait_id: String, text: String) -> void:
	var tag_panel := PanelContainer.new()
	tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	var base_color: Color = TRAIT_COLORS.get(trait_id, Color(0.35, 0.35, 0.35, 1.0))
	style.bg_color = base_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 1.0, 1.0, 0.3)
	tag_panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Database.get_current_locale_font())
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 2)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	tag_panel.add_child(label)
	add_child(tag_panel)
