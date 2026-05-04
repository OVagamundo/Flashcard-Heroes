import re

with open('C:/Users/danhh/Desktop/Flashcard-Heroes/scripts/Main.gd', 'r') as f:
    content = f.read()

new_func = '''func _check_reward_drag_drop_on_zones_with_context(context: InteractionContext) -> bool:
\t"""Check if a drag ended over one of the Reward zones. Returns true if handled."""
\tif not _reward_drop_zones_visible or not is_instance_valid(_reward_drop_zone_container):
\t\treturn false
\tif context == null:
\t\treturn false
\t
\tvar mouse_pos = get_viewport().get_mouse_position()
\t
\t# Check Collect zone
\tif is_instance_valid(_reward_collect_zone) and _reward_collect_zone.get_global_rect().has_point(mouse_pos):
\t\tGlobalInteractionRouter.set_current_selection(context)
\t\tSignalBus.emit_signal("selection_changed", context.location)
\t\tSignalBus.emit_signal("reward_collect_zone_activated")
\t\tAudio.play_sfx("ui_click")
\t\treturn true
\t
\t# Check Sell zone
\tif is_instance_valid(_reward_sell_zone) and _reward_sell_zone.get_global_rect().has_point(mouse_pos):
\t\tGlobalInteractionRouter.set_current_selection(context)
\t\tSignalBus.emit_signal("selection_changed", context.location)
\t\tSignalBus.emit_signal("reward_sell_zone_activated")
\t\tAudio.play_sfx("ui_click")
\t\treturn true
\t
\treturn false
'''

content += '\n' + new_func

old_call = '''\t# Check Black Market zones first (independent from confirm zone)
\tif _check_bm_drag_drop_on_zones_with_context(saved_bm_ctx):
\t\treturn
\t
\tif _confirm_drop_zone_mode == &"":'''

new_call = '''\t# Check Black Market zones first (independent from confirm zone)
\tif _check_bm_drag_drop_on_zones_with_context(saved_bm_ctx):
\t\treturn
\t
\t# Check Reward zones
\tif _check_reward_drag_drop_on_zones_with_context(saved_ctx):
\t\treturn
\t
\tif _confirm_drop_zone_mode == &"":'''

content = content.replace(old_call, new_call)

with open('C:/Users/danhh/Desktop/Flashcard-Heroes/scripts/Main.gd', 'w') as f:
    f.write(content)
print('Updated Main.gd for Reward drag drop.')
