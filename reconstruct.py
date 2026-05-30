import base64

b64_content = b'''	for event in events:
		SignalBus.log_animation_event.emit(event)
		
		await _play_trinket_activations_for_event(event)
		if event.type == CombatEvent.Type.LOG_MESSAGE:
			continue
		
		if _is_paused and not _step_advance_requested:
			var step_info = _build_step_info(event)
			emit_signal("combat_step_reached", step_info)
			
			while _is_paused and not _step_advance_requested:
				await get_tree().process_frame
				
		_step_advance_requested = false
		
		match event.type:
			CombatEvent.Type.LOG_MESSAGE:
				pass

			CombatEvent.Type.DAMAGE:
				var anim = AnimationRegistry.get_animation("damage")
				if anim:
					await anim.execute(self, event.target_uuids, event.visual_payload)
				else:
					push_error("[BattleAnimator] Damage animation not found in registry!")
				
				if not _pending_guardian_return.is_empty():
					var guardian_view = _visual_registry.get(_pending_guardian_return)
					if is_instance_valid(guardian_view) and guardian_view.has_method("animate_leap_return"):
						await guardian_view.animate_leap_return()
					_pending_guardian_return = ""

			CombatEvent.Type.HEAL:
				var anim = AnimationRegistry.get_animation("heal")
				if anim:
					Audio.play_sfx("combat_heal")
					await anim.execute(self, event.target_uuids, event.visual_payload)
				else:
					push_error("[BattleAnimator] Heal animation not found in registry!")

			CombatEvent.Type.BUFF:
				var anim = AnimationRegistry.get_animation("buff")
				if anim:
					Audio.play_sfx("combat_buff")
					await anim.execute(self, event.target_uuids, event.visual_payload)
				else:
					push_error("[BattleAnimator] Buff animation not found in registry!")

			CombatEvent.Type.STATUS_EFFECT:
				var anim = AnimationRegistry.get_animation("status_effect")
				if anim:
					Audio.play_sfx("combat_buff")
					await anim.execute(self, event.target_uuids, event.visual_payload)
				else:
					push_error("[BattleAnimator] Status effect animation not found in registry!")

			CombatEvent.Type.DEATH:
				if event.target_uuids.size() > 0:
					var dead_uuid := event.target_uuids[0]
					if _dead_units.has(dead_uuid):
						continue
					_dead_units[dead_uuid] = true
					Audio.play_sfx("combat_death")
					if SignalBus.has_signal("unit_death_fade"):
						SignalBus.emit_signal("unit_death_fade", dead_uuid)
					await wait_for_animation_completion("death_fade", dead_uuid)
					
					var dead_view = _visual_registry.get(dead_uuid)
					if is_instance_valid(dead_view):
						dead_view.queue_free()
						_visual_registry.erase(dead_uuid)
						await get_tree().process_frame

			CombatEvent.Type.SUMMON:
				var payload = event.visual_payload
				var new_unit_uuid = payload.get("new_unit_uuid", "")
				var old_location = payload.get("old_unit_location")
				var spawn_source_uuid = payload.get("spawn_source_uuid", "")
				var unit_tier = int(payload.get("unit_tier", 1))
				
				var container_tag = old_location.container if old_location else &""
				var index = old_location.index if old_location else -1
				var is_inventory_summon = String(container_tag).begins_with("BattleInventoryT")
				
				var battle_view = get_tree().get_first_node_in_group("battle_view")
				var main_node = get_tree().get_root().find_child("Main", true, false)
				
				var arc_completed = false
				if not spawn_source_uuid.is_empty() and is_instance_valid(main_node):
					var source_pos_data = _position_snapshot.get(spawn_source_uuid, {})
					var machine_node = main_node.get_node_or_null("%%GachaMachine%d" % unit_tier)
					if not source_pos_data.is_empty() and is_instance_valid(machine_node):
						var start_center: Vector2 = source_pos_data["center"]
						var machine_rect = machine_node.get_global_rect()
						var end_center: Vector2 = machine_rect.get_center()
						
						var anim_capsule = preload("res://scenes/GachaBallView.tscn").instantiate()
						var effects_layer = WindowManager.get_vfx_layer()
						effects_layer.add_child(anim_capsule)
						anim_capsule.anchors_preset = Control.PRESET_TOP_LEFT
						anim_capsule.set_size_scale(1.0)
						anim_capsule.force_inventory_mode = true
						var new_snapshot = payload.get("new_unit_snapshot", {})
						anim_capsule.populate(null, new_snapshot)
						
						var initial_scale := 0.3
						var final_scale_val := 1.5
						anim_capsule.scale = Vector2(initial_scale, initial_scale)
						
						var center_offset = Vector2(48, 48)
						var arc_height := 500.0
						var duration := 0.7
						
						var tween = anim_capsule.create_tween()
						tween.set_trans(Tween.TRANS_LINEAR)
						
						tween.tween_method(func(t: float):
							var curr_x = lerp(start_center.x, end_center.x, t)
							var curr_y = lerp(start_center.y, end_center.y, t) - (4.0 * arc_height * t * (1.0 - t))
							var scale_t = clamp(t * 10.0, 0.0, 1.0)
							var current_scale = lerp(initial_scale, final_scale_val, scale_t)
							anim_capsule.scale = Vector2(current_scale, current_scale)
							var pos = Vector2(curr_x, curr_y)
							anim_capsule.global_position = pos - (center_offset * current_scale)
						, 0.0, 1.0, duration)
						
						await tween.finished
						anim_capsule.queue_free()
						Audio.play_sfx("coin_land")
						if main_node.has_method("trigger_machine_bounce"):
							main_node.trigger_machine_bounce(unit_tier)
						arc_completed = true

				if not is_inventory_summon and is_instance_valid(battle_view):
					var lineup_container: HBoxContainer = null
					if container_tag == &"PlayerLineup" or container_tag == &"PlayerBench":
						lineup_container = battle_view.player_lineup if container_tag == &"PlayerLineup" else battle_view.player_bench
					elif container_tag == &"EnemyLineup":
						lineup_container = battle_view.enemy_lineup
					
					if is_instance_valid(lineup_container) and index >= 0 and index < lineup_container.get_child_count():
						var slot_view = lineup_container.get_child(index)
						var new_view = preload("res://scenes/GachaBallView.tscn").instantiate()
						
						var has_existing_unit := false
						for child in slot_view.get_children():
							if child.has_method("populate"): # Defensive check instead of is GachaBallView
								has_existing_unit = true
								break
						if has_existing_unit:
							new_view.queue_free()
						else:
							slot_view.add_child(new_view)
							var new_snapshot = payload.get("new_unit_snapshot", {})
							if not new_snapshot.is_empty():
								var new_location = LocationIdentifier.new(container_tag, index)
								new_view.populate(new_location, new_snapshot, false)
								new_view.set_is_enemy(container_tag == &"EnemyLineup", new_snapshot.get("def_id", &""))
								_visual_registry[new_unit_uuid] = new_view
								
								await get_tree().process_frame
								var rect = new_view.get_global_rect()
								_position_snapshot[new_unit_uuid] = {
									"position": rect.position,
									"size": rect.size,
									"center": Vector2(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
								}
								
								if arc_completed:
									new_view.play_landing_bounce()
								else:
									if SignalBus.has_signal("unit_summon_fade"):
										SignalBus.emit_signal("unit_summon_fade", new_unit_uuid)
										Audio.play_sfx("combat_summon")
										await wait_for_animation_completion("summon_fade", new_unit_uuid)
				
				if arc_completed:
					await get_tree().create_timer(0.2).timeout

			CombatEvent.Type.LETHAL_SAVE:
				var anim = AnimationRegistry.get_animation("lethal_save")
				if anim:
					await anim.execute(self, event.target_uuids, event.visual_payload)
				else:
					push_error("[BattleAnimator] Lethal save animation not found in registry!")

			CombatEvent.Type.GUARDIAN_INTERCEPT:
				var anim = AnimationRegistry.get_animation("guardian_intercept")
				if anim:
					await anim.execute(self, event.target_uuids, event.visual_payload)
				else:
					push_error("[BattleAnimator] Guardian intercept animation not found in registry!")

			CombatEvent.Type.KAMIKAZE_ATTACK:
				var anim = AnimationRegistry.get_animation("kamikaze")
				if anim:
					await anim.execute(self, event.target_uuids, event.visual_payload)
				else:
					push_error("[BattleAnimator] Kamikaze animation not found in registry!")

			CombatEvent.Type.TRANSFORM:
				var anim = AnimationRegistry.get_animation("transform")
				if anim:
					await anim.execute(self, event.target_uuids, event.visual_payload)
				else:
					push_error("[BattleAnimator] Transform animation not found in registry!")

			CombatEvent.Type.GOLD_GAIN:
				var payload = event.visual_payload
				var amount = int(payload.get("amount", 0))
				var origin_uuid = payload.get("origin_uuid", "")
				if has_method("_animate_gold_gain"):
					await _animate_gold_gain(origin_uuid, amount)

			CombatEvent.Type.TOKEN_GAIN:
				var payload = event.visual_payload
				var amount = int(payload.get("amount", 0))
				var origin_uuid = payload.get("origin_uuid", "")
				if has_method("_animate_token_gain"):
					await _animate_token_gain(origin_uuid, amount)

			CombatEvent.Type.ITEM_TRANSFER:
				var payload = event.visual_payload
				var source_uuid = event.source_uuid
				var target_uuid = event.target_uuids[0] if event.target_uuids.size() > 0 else ""
				if not source_uuid.is_empty() and not target_uuid.is_empty():
					if has_method("_animate_item_transfer"):
						await _animate_item_transfer(source_uuid, target_uuid, payload)

			CombatEvent.Type.SLOT_EFFECT_CHANGE:
				var payload = event.visual_payload
				var container_tag: StringName = payload.get("container_tag", &"")
				var slot_index: int = int(payload.get("slot_index", -1))
				var to_effect: StringName = payload.get("to_effect", &"")
				if has_method("_get_slot_view"):
					var slot_view = _get_slot_view(container_tag, slot_index)
					if is_instance_valid(slot_view) and slot_view.has_method("animate_slot_effect_change"):
						await slot_view.animate_slot_effect_change(to_effect)
					elif is_instance_valid(slot_view) and slot_view.has_method("set_slot_effect"):
						slot_view.set_slot_effect(to_effect)
						await get_tree().create_timer(0.2).timeout

		await get_tree().process_frame
	
	_is_paused = false
	_step_advance_requested = false
	
	emit_signal("turn_animation_finished")

func apply_hp_delta(target_uuid: String, amount: int, new_hp: int) -> void:
	var view = _visual_registry.get(target_uuid)
	if not is_instance_valid(view) or not view.has_method("animate_stat_change"):
		push_warning("[BattleAnimator] HP delta target not in visual registry: " + target_uuid)
		return
	view.animate_stat_change(new_hp, amount, "hp")

func apply_pwr_delta(target_uuid: String, amount: int, new_pwr: int) -> void:
	var view = _visual_registry.get(target_uuid)
	if is_instance_valid(view) and view.has_method("animate_stat_change"):
		view.animate_stat_change(new_pwr, amount, "pwr")
	else:
		push_warning("[BattleAnimator] PWR delta target not in visual registry: " + target_uuid)

func apply_burn_stack(uuid: String, new_stacks: int) -> void:
	if _visual_registry.has(uuid):
		var view = _visual_registry[uuid]
		if is_instance_valid(view) and view.has_method("animate_burn_change"):
			view.animate_burn_change(new_stacks)

func apply_armor_stack(uuid: String, new_stacks: int) -> void:
	if _visual_registry.has(uuid):
		var view = _visual_registry[uuid]
		if is_instance_valid(view) and view.has_method("animate_armor_change"):
			view.animate_armor_change(new_stacks)

func apply_armor_delta(target_uuid: String, armor_consumed: int, new_armor: int) -> void:
	var view = _visual_registry.get(target_uuid)
	if is_instance_valid(view):
		if view.has_method("animate_armor_stat_change"):
			view.animate_armor_stat_change(new_armor, armor_consumed)
		elif view.has_method("animate_armor_change"):
			view.animate_armor_change(new_armor)

func apply_status_stack(uuid: String, status_id: StringName, new_stacks: int) -> void:
	if _visual_registry.has(uuid):
		var view = _visual_registry[uuid]
		if is_instance_valid(view) and view.has_method("animate_status_change"):
			view.animate_status_change(status_id, new_stacks)

func apply_spikes_stack(uuid: String, new_stacks: int) -> void:
	if _visual_registry.has(uuid):
		var view = _visual_registry[uuid]
		if is_instance_valid(view) and view.has_method("animate_status_change"):
			view.animate_status_change(&"spikes", new_stacks)

func _emit_bump(_attacker_uuid: String) -> void:
	pass

func get_snapshot_position(uuid: String) -> Dictionary:
	if _position_snapshot.has(uuid):
		return _position_snapshot[uuid]
		
	var trinket_view = _find_trinket_view(uuid, &"", false)
	if not is_instance_valid(trinket_view):
		trinket_view = _find_trinket_view("", StringName(uuid), false)
		
	if is_instance_valid(trinket_view):
		var rect = trinket_view.get_global_rect()
		return {
			"position": rect.position,
			"size": rect.size,
			"center": Vector2(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
		}
		
	return {}

func register_dynamic_position(uuid: String, view) -> void:
	if is_instance_valid(view):
		var rect = view.get_global_rect()
		_position_snapshot[uuid] = {
			"position": rect.position,
			"size": rect.size,
			"center": Vector2(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
		}
		_visual_registry[uuid] = view

func _play_trinket_activations_for_event(event: CombatEvent) -> void:
	if event.type == CombatEvent.Type.DAMAGE:
		return
		
	var payload: Dictionary = event.visual_payload
	var activations: Array = []
	if payload.has("trinket_activations"):
		var raw_activations = payload.get("trinket_activations", [])
		if raw_activations is Array:
			for raw_activation in raw_activations:
				if raw_activation is Dictionary:
					activations.append(raw_activation)
	elif payload.has("trinket_visual_uuid") or payload.has("trinket_definition_id"):
		activations.append({
			"visual_uuid": String(payload.get("trinket_visual_uuid", "")),
			"definition_id": StringName(payload.get("trinket_definition_id", &"")),
			"is_enemy": bool(payload.get("trinket_is_enemy", false))
		})
	
	for activation in activations:
		play_trinket_activation(
			String(activation.get("visual_uuid", "")),
			StringName(activation.get("definition_id", &"")),
			bool(activation.get("is_enemy", false))
		)
		await get_tree().create_timer(0.25).timeout

func play_trinket_activation(visual_uuid: String, trinket_definition_id: StringName = &"", is_enemy_trinket: bool = false) -> void:
	var view = _find_trinket_view(visual_uuid, trinket_definition_id, is_enemy_trinket)
	if is_instance_valid(view) and view.has_method("play_landing_bounce"):
		view.play_landing_bounce()
'''

with open('scripts/BattleAnimator.gd', 'r', encoding='utf-8') as f:
    orig = f.read()

lines = orig.split('\n')

start_idx = -1
for i, line in enumerate(lines):
    if 'func _animate_events(events: Array[CombatEvent]) -> void:' in line:
        start_idx = i
        break

end_idx = -1
for i, line in enumerate(lines):
    if 'func hop_trinket_by_definition_id' in line:
        end_idx = i
        break

if start_idx != -1 and end_idx != -1:
    new_lines = lines[:start_idx+1] + b64_content.decode('utf-8').split('\n') + lines[end_idx:]
    with open('scripts/BattleAnimator.gd', 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines))
    print('Reconstructed success')
else:
    print('Failed to find markers')
