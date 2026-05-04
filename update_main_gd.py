import re

main_path = 'C:/Users/danhh/Desktop/Flashcard-Heroes/scripts/Main.gd'
with open(main_path, 'r', encoding='utf-8') as f:
    content = f.read()

vars_str = '''var _reward_drop_zone_container: PanelContainer = null
var _reward_collect_zone: PanelContainer = null
var _reward_sell_zone: PanelContainer = null
var _reward_collect_label: RichTextLabel = null
var _reward_sell_label: RichTextLabel = null
var _reward_drop_zones_visible: bool = false
'''
content = content.replace('var _bm_drop_zones_visible: bool = false', 'var _bm_drop_zones_visible: bool = false\n' + vars_str)

content = content.replace('_build_black_market_drop_zones()', '_build_black_market_drop_zones()\n\t_build_reward_drop_zones()')

funcs_str = '''
# =============================================================================
# REWARD DROP ZONES
# =============================================================================

func _build_reward_drop_zones() -> void:
\t_reward_drop_zone_container = PanelContainer.new()
\t_reward_drop_zone_container.name = "RewardDropZones"
\t
\t_reward_drop_zone_container.layout_mode = 1
\t_reward_drop_zone_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
\t_reward_drop_zone_container.custom_minimum_size = Vector2(0, 260)
\t_reward_drop_zone_container.offset_top = -260
\t_reward_drop_zone_container.offset_bottom = 0
\t
\tvar container_style = StyleBoxFlat.new()
\tcontainer_style.bg_color = Color(0, 0, 0, 0)
\t_reward_drop_zone_container.add_theme_stylebox_override("panel", container_style)
\t_reward_drop_zone_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
\t
\tvar hbox = HBoxContainer.new()
\thbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
\thbox.add_theme_constant_override("separation", 8)
\thbox.set_anchors_preset(Control.PRESET_FULL_RECT)
\t_reward_drop_zone_container.add_child(hbox)
\t
\t_reward_collect_zone = _create_bm_zone_panel(tr("Drag or click here to add it to your collection"), Color(0.93, 0.98, 0.93, 0.95))
\t_reward_collect_zone.name = "CollectZone"
\t_reward_collect_label = _reward_collect_zone.get_child(0).get_child(0) as RichTextLabel
\thbox.add_child(_reward_collect_zone)
\t_reward_collect_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\t_reward_collect_zone.gui_input.connect(_on_reward_collect_zone_gui_input)
\t
\t_reward_sell_zone = _create_bm_zone_panel(tr("Drag or click here to sell it"), Color(0.98, 0.93, 0.93, 0.95))
\t_reward_sell_zone.name = "SellZone"
\t_reward_sell_label = _reward_sell_zone.get_child(0).get_child(0) as RichTextLabel
\thbox.add_child(_reward_sell_zone)
\t_reward_sell_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\t_reward_sell_zone.gui_input.connect(_on_reward_sell_zone_gui_input)
\t
\tvar hud_container = bottom_area.get_parent()
\tif is_instance_valid(hud_container):
\t\thud_container.add_child(_reward_drop_zone_container)
\t\t_reward_drop_zone_container.z_index = 5
\t
\t_reward_drop_zone_container.visible = false
\t_reward_drop_zone_container.modulate.a = 0.0

func _on_reward_collect_zone_gui_input(event: InputEvent) -> void:
\tif InputUtils.is_primary_pointer_release(event) or InputUtils.is_primary_pointer_press(event):
\t\tSignalBus.emit_signal("reward_collect_zone_activated")
\t\tget_viewport().set_input_as_handled()

func _on_reward_sell_zone_gui_input(event: InputEvent) -> void:
\tif InputUtils.is_primary_pointer_release(event) or InputUtils.is_primary_pointer_press(event):
\t\tSignalBus.emit_signal("reward_sell_zone_activated")
\t\tget_viewport().set_input_as_handled()

func show_reward_drop_zones() -> void:
\tif not is_instance_valid(_reward_drop_zone_container): return
\tif _reward_drop_zones_visible: return
\t_reward_drop_zones_visible = true
\t_reward_drop_zone_container.visible = true
\tvar tween = create_tween()
\ttween.tween_property(_reward_drop_zone_container, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func hide_reward_drop_zones() -> void:
\tif not is_instance_valid(_reward_drop_zone_container): return
\tif not _reward_drop_zones_visible: return
\t_reward_drop_zones_visible = false
\tvar tween = create_tween()
\ttween.tween_property(_reward_drop_zone_container, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
\ttween.tween_callback(func():
\t\tif is_instance_valid(_reward_drop_zone_container) and not _reward_drop_zones_visible:
\t\t\t_reward_drop_zone_container.visible = false
\t)

func get_reward_collect_zone() -> Control:
\treturn _reward_collect_zone

func get_reward_sell_zone() -> Control:
\treturn _reward_sell_zone
'''
content += funcs_str

old_logic = '''if new_location and new_location.container == &"Rewards":
		show_confirm_drop_zone(&"Rewards")'''
new_logic = '''if new_location and new_location.container == &"Rewards":
		show_reward_drop_zones()'''
content = content.replace(old_logic, new_logic)

old_deferred = '''if sel.location.container == &"Rewards" or sel.location.container == &"Shop":
			return
	hide_confirm_drop_zone()'''
new_deferred = '''if sel.location.container == &"Shop":
			return
	hide_confirm_drop_zone()
	if not (sel and is_instance_valid(sel.location) and sel.location.container == &"Rewards"):
		hide_reward_drop_zones()'''
content = content.replace(old_deferred, new_deferred)

with open(main_path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Main.gd updated successfully.')
