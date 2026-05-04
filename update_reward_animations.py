import re

with open('C:/Users/danhh/Desktop/Flashcard-Heroes/scripts/Reward.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# For _on_collect_pressed
content = content.replace('_animate_gachaball_to_machine(start_pos, visual_data, tier, func(): _action_in_progress = false)', 'await _animate_gachaball_to_machine(start_pos, visual_data, tier)\n\t\t_action_in_progress = false')
content = content.replace('_animate_gachaball_to_trinket_bar(start_pos, visual_data, target_trinket_slot, uuid, func(): _action_in_progress = false)', 'await _animate_gachaball_to_trinket_bar(start_pos, visual_data, target_trinket_slot, uuid)\n\t\t_action_in_progress = false')

# For _on_sell_pressed
content = content.replace('''\t_animate_gold_receive(gold_yield, start_pos, func():
\t\tif is_instance_valid(GameManager.run_state):
\t\t\tGameManager.run_state.add_gold(gold_yield)
\t\t_action_in_progress = false
\t)''', '''\tawait _animate_gold_receive(gold_yield, start_pos)
\tif is_instance_valid(GameManager.run_state):
\t\tGameManager.run_state.add_gold(gold_yield)
\t_action_in_progress = false''')

# For _on_leave_pressed
old_leave = '''\t\t\tvar anim_completed = false
\t\t\t
\t\t\tif tier != -1:
\t\t\t\tif is_instance_valid(GameManager.run_state):
\t\t\t\t\tGameManager.run_state.run_instances[uuid] = instance
\t\t\t\tSignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": uuid})
\t\t\t\t_animate_gachaball_to_machine(start_pos, visual_data, tier, func(): anim_completed = true)
\t\t\telse:
\t\t\t\tif is_instance_valid(GameManager.run_state):
\t\t\t\t\tGameManager.run_state.run_instances[uuid] = instance
\t\t\t\t_animate_gachaball_to_trinket_bar(start_pos, visual_data, target_trinket_slot, uuid, func(): anim_completed = true)
\t\t\t
\t\t\twhile not anim_completed:
\t\t\t\tawait get_tree().process_frame'''

new_leave = '''\t\t\tif tier != -1:
\t\t\t\tif is_instance_valid(GameManager.run_state):
\t\t\t\t\tGameManager.run_state.add_instance(instance, &"RunInventoryT%d" % tier, -1)
\t\t\t\t\tGameManager.run_state.unlock_recipe_for_result(def.id)
\t\t\t\tawait _animate_gachaball_to_machine(start_pos, visual_data, tier)
\t\t\telse:
\t\t\t\tif is_instance_valid(GameManager.run_state):
\t\t\t\t\tGameManager.run_state.add_instance(instance, RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS, -1)
\t\t\t\t\tGameManager.run_state.unlock_recipe_for_result(def.id)
\t\t\t\tawait _animate_gachaball_to_trinket_bar(start_pos, visual_data, target_trinket_slot, uuid)'''

content = content.replace(old_leave, new_leave)

# Also update the _on_collect_pressed so it properly uses RunState.add_instance instead of reward_chosen
old_collect = '''\t\t# Since we instantiated it locally, we must pass it to the inventory manager or emit reward_chosen
\t\t# We will use the existing reward_chosen signal, but we need to pass the actual instance!
\t\t# Wait, the signal expects it to be in GameManager. Let's add it to run_instances manually so it can be found.
\t\tif is_instance_valid(GameManager.run_state):
\t\t\tGameManager.run_state.run_instances[uuid] = instance
\t\tSignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": uuid})
\t\tawait _animate_gachaball_to_machine(start_pos, visual_data, tier)
\t\t_action_in_progress = false
\telse:
\t\tif is_instance_valid(GameManager.run_state):
\t\t\tGameManager.run_state.run_instances[uuid] = instance
\t\tawait _animate_gachaball_to_trinket_bar(start_pos, visual_data, target_trinket_slot, uuid)
\t\t_action_in_progress = false'''

new_collect = '''\t\tif is_instance_valid(GameManager.run_state):
\t\t\tGameManager.run_state.add_instance(instance, &"RunInventoryT%d" % tier, -1)
\t\t\tGameManager.run_state.unlock_recipe_for_result(def.id)
\t\tawait _animate_gachaball_to_machine(start_pos, visual_data, tier)
\t\t_action_in_progress = false
\telse:
\t\tif is_instance_valid(GameManager.run_state):
\t\t\tGameManager.run_state.add_instance(instance, RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS, -1)
\t\t\tGameManager.run_state.unlock_recipe_for_result(def.id)
\t\tawait _animate_gachaball_to_trinket_bar(start_pos, visual_data, target_trinket_slot, uuid)
\t\t_action_in_progress = false'''

content = content.replace(old_collect, new_collect)

# Now fix the animate functions to properly await the tweens
anim1_old = '''\ttween.tween_callback(func():
\t\tAudio.play_sfx("coin_land")
\t\tanim_ball.queue_free()
\t\tif main_node.has_method("trigger_machine_bounce"):
\t\t\tmain_node.trigger_machine_bounce(tier)
\t)'''
anim1_new = '''\tawait tween.finished
\tAudio.play_sfx("coin_land")
\tanim_ball.queue_free()
\tif main_node.has_method("trigger_machine_bounce"):
\t\tmain_node.trigger_machine_bounce(tier)'''
content = content.replace(anim1_old, anim1_new)

anim2_old = '''\ttween.tween_callback(func():
\t\tanim_ball.queue_free()
\t\tSignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": instance_uuid})
\t)'''
anim2_new = '''\tawait tween.finished
\tanim_ball.queue_free()'''
content = content.replace(anim2_old, anim2_new)

# Remove the early returns `return` and replace with `await get_tree().process_frame` just in case
content = content.replace('''func _animate_gachaball_to_machine(start_pos: Vector2, visual_data: Dictionary, tier: int) -> void:
\tvar main_node = GameManager._active_main_node
\tif not is_instance_valid(main_node):
\t\t
\t\treturn
\t
\tvar machine = main_node.get_node_or_null("%%GachaMachine%d" % tier)
\tif not is_instance_valid(machine):
\t\t
\t\treturn''', '''func _animate_gachaball_to_machine(start_pos: Vector2, visual_data: Dictionary, tier: int) -> void:
\tvar main_node = GameManager._active_main_node
\tif not is_instance_valid(main_node):
\t\tawait get_tree().process_frame
\t\treturn
\t
\tvar machine = main_node.get_node_or_null("%%GachaMachine%d" % tier)
\tif not is_instance_valid(machine):
\t\tawait get_tree().process_frame
\t\treturn''')

content = content.replace('''func _animate_gachaball_to_trinket_bar(start_pos: Vector2, visual_data: Dictionary, target_slot_index: int, instance_uuid: String) -> void:
\tvar main_node = GameManager._active_main_node
\tif not is_instance_valid(main_node):
\t\tSignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": instance_uuid})
\t\t
\t\treturn
\t
\tvar trinket_bar = main_node.get_node_or_null("%PlayerTrinketBar")
\tif not is_instance_valid(trinket_bar):
\t\tSignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": instance_uuid})
\t\t
\t\treturn
\t
\tvar slot_count = trinket_bar.get_child_count()
\ttarget_slot_index = clampi(target_slot_index, 0, slot_count - 1)
\tvar target_slot = trinket_bar.get_child(target_slot_index) if target_slot_index < slot_count else null
\tif not is_instance_valid(target_slot):
\t\tSignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": instance_uuid})
\t\t
\t\treturn''', '''func _animate_gachaball_to_trinket_bar(start_pos: Vector2, visual_data: Dictionary, target_slot_index: int, instance_uuid: String) -> void:
\tvar main_node = GameManager._active_main_node
\tif not is_instance_valid(main_node):
\t\tawait get_tree().process_frame
\t\treturn
\t
\tvar trinket_bar = main_node.get_node_or_null("%PlayerTrinketBar")
\tif not is_instance_valid(trinket_bar):
\t\tawait get_tree().process_frame
\t\treturn
\t
\tvar slot_count = trinket_bar.get_child_count()
\tif slot_count == 0:
\t\tawait get_tree().process_frame
\t\treturn
\ttarget_slot_index = clampi(target_slot_index, 0, slot_count - 1)
\tvar target_slot = trinket_bar.get_child(target_slot_index) if target_slot_index < slot_count else null
\tif not is_instance_valid(target_slot):
\t\tawait get_tree().process_frame
\t\treturn''')

content = content.replace('''func _animate_gold_receive(amount: int, start_pos: Vector2) -> void:
\tvar main_node = GameManager._active_main_node
\tif not is_instance_valid(main_node):
\t\t
\t\treturn
\t
\tvar gold_group = main_node.get_node_or_null("%GoldGroup")
\tif not is_instance_valid(gold_group):
\t\t
\t\treturn''', '''func _animate_gold_receive(amount: int, start_pos: Vector2) -> void:
\tvar main_node = GameManager._active_main_node
\tif not is_instance_valid(main_node):
\t\tawait get_tree().process_frame
\t\treturn
\t
\tvar gold_group = main_node.get_node_or_null("%GoldGroup")
\tif not is_instance_valid(gold_group):
\t\tawait get_tree().process_frame
\t\treturn''')

content = content.replace('''\tvar wait_tween = create_tween()
\twait_tween.tween_interval(total_wait)
\twait_tween.tween_callback()''', '''\tawait get_tree().create_timer(total_wait).timeout''')

with open('C:/Users/danhh/Desktop/Flashcard-Heroes/scripts/Reward.gd', 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated animations to await')
