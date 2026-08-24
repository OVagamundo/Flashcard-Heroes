# scripts/BattleAnimator.gd
extends Node

signal turn_animation_finished

const ANIM_TIMEOUT_DURATION = 1.1
const BUMP_DURATION = 0.5

var _hp_snapshot: Dictionary = {}
var _dead_units: Dictionary = {} # Track units that have already animated death this turn
var _visual_registry: Dictionary = {} # UUID -> GachaBallView (for puppet mode)
var _position_snapshot: Dictionary = {} # UUID -> {position: Vector2, size: Vector2} - captured at animation start
var _pending_guardian_return: String = "" # UUID of Guardian needing to return after damage
var _tracker: AnimationCompletionTracker # Animation completion tracking

var _is_playing_sequence: bool = false

func is_playing_sequence() -> bool:
	return _is_playing_sequence

const GoldCoinVFXScene = preload("res://scripts/vfx/GoldCoinVFX.gd")
const TokenPopVFXScene = preload("res://scenes/vfx/TokenPopVFX.tscn")

# --- Speed Control ---
# Speed factor is stored in AnimationConstants.speed_factor (static var)

# --- Step Mode & Pause ---
var _is_paused: bool = false
var _step_advance_requested: bool = false

signal combat_step_reached(step_info: Dictionary)  # For UI to display step description

func set_hp_snapshot(snapshot: Dictionary) -> void:
	# Snapshot of unit_uuid -> hp before simulation. Animator will restore these
	# values before playing events so each event updates the label visibly.
	_hp_snapshot = snapshot.duplicate(true)

func _ready() -> void:
	add_to_group("battle_animator")
	# Initialize animations
	AnimationRegistry.load_standard_animations()
	# Initialize animation completion tracker
	_tracker = AnimationCompletionTracker.new(get_tree())
	
	if SignalBus.has_signal("trait_threshold_reached"):
		SignalBus.connect("trait_threshold_reached", _on_trait_threshold_reached)

func play_turn_sequence(start_snapshot: Dictionary, turn_log: Array[CombatEvent]) -> void:
	_is_playing_sequence = true
	# VCR Pattern: start_snapshot contains full board state, turn_log is the event sequence
	# Extract HP snapshot for backward compatibility
	var hp_only_snapshot: Dictionary = {}
	for uuid in start_snapshot:
		var data = start_snapshot[uuid]
		if data is Dictionary and data.has("hp"):
			hp_only_snapshot[uuid] = data["hp"]
	
	# Visual gacha tokens are now handled by BattleManager.
	
	_register_all_puppets(start_snapshot)
	
	await play_turn(turn_log)
	_visual_registry.clear()
	_position_snapshot.clear()
	_is_playing_sequence = false
	emit_signal("turn_animation_finished")

func _register_all_puppets(start_snapshot: Dictionary) -> void:
	# PUPPET MODE: Build visual registry by scanning scene tree
	_visual_registry.clear()
	_position_snapshot.clear() # DECOUPLING: Reset position snapshot each sequence
	
	var battle_view = get_tree().get_first_node_in_group("battle_view")
	
	if is_instance_valid(battle_view):
		# CRITICAL FIX: Filter out equipped items from snapshot
		# Equipped items don't have views in lineups - they're displayed on their holder units
		# Including them in iteration can cause unpredictable behavior due to dictionary iteration order
		for uuid in start_snapshot:
			var snapshot_data = start_snapshot[uuid]
			
			# TRUE DECOUPLING: Use VALUES from snapshot, not object references
			if snapshot_data is Dictionary and snapshot_data.has("container_tag") and snapshot_data.has("slot_index"):
				var container_tag = snapshot_data.get("container_tag") # StringName VALUE
				var index = snapshot_data.get("slot_index") # int VALUE
				
				# Map container tag to battle view lineup nodes via scene tree
				var lineup_container: HBoxContainer = null
				if container_tag == &"PlayerLineup":
					lineup_container = battle_view.player_lineup
				elif container_tag == &"EnemyLineup":
					lineup_container = battle_view.enemy_lineup
				elif container_tag == &"PlayerBench":
					lineup_container = battle_view.player_bench
				elif container_tag == &"EnemyTrinkets":
					lineup_container = battle_view.enemy_trinket_bar
				elif container_tag == &"PlayerTrinkets":
					var main_node = get_tree().get_first_node_in_group("main")
					if is_instance_valid(main_node) and "player_trinket_bar" in main_node:
						lineup_container = main_node.player_trinket_bar
				
				if is_instance_valid(lineup_container) and index >= 0:
					var children = lineup_container.get_children()
					
					if index < children.size():
						var slot_view = children[index]
						
						if is_instance_valid(slot_view) and slot_view.get_child_count() > 0:
							# Find GachaBallView among children (indicator TextureRect may also be present).
							# Prefer a UUID match to avoid selecting stale views that are queued_free this frame.
							var gacha_view: GachaBallView = null
							var fallback_view: GachaBallView = null
							for child in slot_view.get_children():
								if child.is_queued_for_deletion():
									continue
								if child is GachaBallView:
									var candidate: GachaBallView = child
									if not is_instance_valid(fallback_view):
										fallback_view = candidate
									if candidate.has_method("get_instance_uuid") and candidate.get_instance_uuid() == uuid:
										gacha_view = candidate
										break
							if not is_instance_valid(gacha_view):
								gacha_view = fallback_view
							
							if is_instance_valid(gacha_view):
								# Register and initialize view from snapshot VALUES
								_visual_registry[uuid] = gacha_view
								
								# DECOUPLING: Capture position NOW - animations will use this snapshot
								# instead of querying views at animation time
								var rect = gacha_view.get_global_rect()
								_position_snapshot[uuid] = {
									"position": rect.position,
									"size": rect.size,
									"center": Vector2(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
								}
								
								# Inject uuid into snapshot so set_visual_state can update _instance_uuid
								snapshot_data["uuid"] = uuid
								gacha_view.set_visual_state(snapshot_data)
				else:
					pass
		
		# Also scan EffectsLayer for in-flight views (Gacha Draws)
		# This handles race conditions where a unit is targeted while still animating/flying
		var effects_layer = get_tree().get_first_node_in_group("effects_layer")
		if is_instance_valid(effects_layer):
			for child in effects_layer.get_children():
				if child is GachaBallView:
					var uuid = child.get_instance_uuid()
					if not uuid.is_empty():
						_visual_registry[uuid] = child
						
						# Capture snapshot for flying unit
						var rect = child.get_global_rect()
						_position_snapshot[uuid] = {
							"position": rect.position,
							"size": rect.size,
							"center": Vector2(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
						}

func _get_slot_view(container_tag: StringName, slot_index: int) -> PanelContainer:
	if slot_index < 0:
		return null
	var battle_view = get_tree().get_first_node_in_group("battle_view")
	if not is_instance_valid(battle_view):
		return null
	
	var lineup_container: HBoxContainer = null
	match container_tag:
		&"PlayerLineup":
			lineup_container = battle_view.player_lineup
		&"EnemyLineup":
			lineup_container = battle_view.enemy_lineup
		&"PlayerBench":
			lineup_container = battle_view.player_bench
		_:
			return null
	
	if not is_instance_valid(lineup_container):
		return null
	if slot_index >= lineup_container.get_child_count():
		return null
	return lineup_container.get_child(slot_index) as PanelContainer

func play_turn(events: Array[CombatEvent]) -> void:
	if events.is_empty():
		return
	
	_dead_units.clear()
	
	# SYSTEMIC CONSOLIDATION: Merge consecutive stat/status events from same source
	var consolidated_events = _consolidate_consecutive_events(events)
	await _animate_events(consolidated_events)

## Systemically consolidates consecutive visual events originating from the same source
func _consolidate_consecutive_events(raw_events: Array[CombatEvent]) -> Array[CombatEvent]:
	if raw_events.size() <= 1:
		return raw_events
		
	var consolidated: Array[CombatEvent] = []
	var i = 0
	while i < raw_events.size():
		var current = raw_events[i]
		
		# Check if current is a visual stat event (BUFF, HEAL, STATUS_EFFECT)
		if current.type in [CombatEvent.Type.BUFF, CombatEvent.Type.HEAL, CombatEvent.Type.STATUS_EFFECT]:
			var merged_event = current.deep_clone()
			var merged_payload = merged_event.visual_payload
			var source_uuid = merged_event.source_uuid
			var ability_id = merged_event.ability_id
			
			var j = i + 1
			while j < raw_events.size():
				var next_ev = raw_events[j]
				if next_ev.type == CombatEvent.Type.LOG_MESSAGE and not next_ev.trinket_activations.is_empty():
					break
				elif next_ev.type in [CombatEvent.Type.BUFF, CombatEvent.Type.HEAL, CombatEvent.Type.STATUS_EFFECT]:
					var next_payload = next_ev.visual_payload
					
					# Match Rule: Events must originate from the SAME source_uuid. If both are passive (empty source_uuid), ability_id must match.
					var is_same_source = (next_ev.source_uuid == source_uuid and not source_uuid.is_empty())
					var is_both_passive = (source_uuid.is_empty() and next_ev.source_uuid.is_empty() and next_ev.ability_id == ability_id)
					
					if is_same_source or is_both_passive:
						_merge_event_payloads(merged_event, next_ev)
						j += 1
						continue
					else:
						break
				elif next_ev.type == CombatEvent.Type.LOG_MESSAGE:
					j += 1
					continue
				else:
					break
			
			consolidated.append(merged_event)
			i = j
		else:
			consolidated.append(current)
			i += 1
			
	return consolidated


func _merge_event_payloads(merged_event: CombatEvent, next_ev: CombatEvent) -> void:
	var merged_payload = merged_event.visual_payload
	var next_payload = next_ev.visual_payload
	
	for t_idx in range(next_ev.target_uuids.size()):
		var t_uuid = next_ev.target_uuids[t_idx]
		var existing_idx = merged_event.target_uuids.find(t_uuid)
		
		if existing_idx >= 0:
			# Target is already in merged_event: update its NEW values in-place (net accumulation)
			if t_idx < next_payload.targets_new_pwr.size() and existing_idx < merged_payload.targets_new_pwr.size():
				merged_payload.targets_new_pwr[existing_idx] = next_payload.targets_new_pwr[t_idx]
			if t_idx < next_payload.targets_new_hp.size() and existing_idx < merged_payload.targets_new_hp.size():
				merged_payload.targets_new_hp[existing_idx] = next_payload.targets_new_hp[t_idx]
			if t_idx < next_payload.targets_max_hp.size() and existing_idx < merged_payload.targets_max_hp.size():
				merged_payload.targets_max_hp[existing_idx] = next_payload.targets_max_hp[t_idx]
			if t_idx < next_payload.targets_new_val.size() and existing_idx < merged_payload.targets_new_val.size():
				merged_payload.targets_new_val[existing_idx] = next_payload.targets_new_val[t_idx]
		else:
			# Target is new: append target_uuid and its old/new payloads
			merged_event.target_uuids.append(t_uuid)
			if t_idx < next_payload.targets_old_hp.size():
				merged_payload.targets_old_hp.append(next_payload.targets_old_hp[t_idx])
				merged_payload.targets_new_hp.append(next_payload.targets_new_hp[t_idx])
			if t_idx < next_payload.targets_max_hp.size():
				merged_payload.targets_max_hp.append(next_payload.targets_max_hp[t_idx])
			if t_idx < next_payload.targets_old_pwr.size():
				merged_payload.targets_old_pwr.append(next_payload.targets_old_pwr[t_idx])
				merged_payload.targets_new_pwr.append(next_payload.targets_new_pwr[t_idx])
			if t_idx < next_payload.targets_old_val.size():
				merged_payload.targets_old_val.append(next_payload.targets_old_val[t_idx])
				merged_payload.targets_new_val.append(next_payload.targets_new_val[t_idx])

func _animate_events(events: Array[CombatEvent]) -> void:
	for event in events:
		SignalBus.log_animation_event.emit(event)
		
		_play_trinket_activations_for_event(event)
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

			CombatEvent.Type.DRAW:
				var payload = event.visual_payload
				var draw_result = payload.draw_result
				if draw_result:
					SignalBus.emit_signal("gacha_draw_animated", draw_result)
					await AnimationConstants.create_pausable_timer(get_tree(), 0.45 / AnimationConstants.speed_factor).timeout
					
					var battle_view = get_tree().get_first_node_in_group("battle_view")
					if is_instance_valid(battle_view) and not draw_result.went_to_discard:
						var container_tag = draw_result.dest_container
						var index = draw_result.dest_slot
						var lineup_container: HBoxContainer = null
						
						if container_tag == &"PlayerBench":
							lineup_container = battle_view.player_bench
						
						if is_instance_valid(lineup_container) and index >= 0 and index < lineup_container.get_child_count():
							var slot_view = lineup_container.get_child(index)
							var new_view = preload("res://scenes/GachaBallView.tscn").instantiate()
							
							var has_existing_unit := false
							for child in slot_view.get_children():
								if child.is_queued_for_deletion():
									continue
								if child.has_method("populate"):
									has_existing_unit = true
									break
							
							if has_existing_unit:
								for child in slot_view.get_children():
									if child.has_method("populate"):
										child.hide()
										child.queue_free()
							
							slot_view.add_child(new_view)
							var new_snapshot = payload.new_unit_snapshot
							if not new_snapshot.is_empty():
								var new_location = LocationIdentifier.new(container_tag, index)
								new_view.populate(new_location, new_snapshot, false)
								var new_unit_uuid = draw_result.drawn_uuid
								_visual_registry[new_unit_uuid] = new_view
								
								await get_tree().process_frame
								var rect = new_view.get_global_rect()
								_position_snapshot[new_unit_uuid] = {
									"position": rect.position,
									"size": rect.size,
									"center": Vector2(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
								}
								
								if new_view.has_method("play_landing_bounce"):
									new_view.play_landing_bounce()

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
						SignalBus.emit_signal("unit_death_fade", dead_uuid, false)
					await wait_for_animation_completion("death_fade", dead_uuid)
					
					var dead_view = _visual_registry.get(dead_uuid)
					if is_instance_valid(dead_view):
						dead_view.queue_free()
						_visual_registry.erase(dead_uuid)
						await get_tree().process_frame

			CombatEvent.Type.SUMMON:
				var payload = event.visual_payload
				var new_unit_uuid = payload.new_unit_uuid
				var old_location = payload.old_unit_location
				var spawn_source_uuid = payload.spawn_source_uuid
				var unit_tier = payload.unit_tier
				
				var container_tag = old_location.container if old_location else &""
				var index = old_location.index if old_location else -1
				var is_inventory_summon = String(container_tag).begins_with("BattleInventoryT")
				
				var battle_view = get_tree().get_first_node_in_group("battle_view")
				var main_node = GameManager.get_main_node()
				
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
						var new_snapshot = payload.new_unit_snapshot
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
						if main_node.has_method("animate_machine_inventory_change"):
							main_node.animate_machine_inventory_change(unit_tier, 1)
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
						var old_unit_uuid = payload.old_unit_uuid
						for child in slot_view.get_children():
							if child.is_queued_for_deletion():
								continue
							if child.has_method("populate"): # Defensive check instead of is GachaBallView
								if old_unit_uuid != "" and child.has_method("get_instance_uuid") and child.get_instance_uuid() == old_unit_uuid:
									continue # Allow overlapping with the unit being replaced
								has_existing_unit = true
								break
						
						# If there is already a unit, force clear it visually to avoid overlap
						if has_existing_unit:
							for child in slot_view.get_children():
								if child.has_method("populate"):
									child.hide()
									child.queue_free()
									
						slot_view.add_child(new_view)
						var new_snapshot = payload.new_unit_snapshot
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
					await AnimationConstants.create_pausable_timer(get_tree(), 0.2).timeout

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
				var amount = payload.amount
				var origin_uuid = payload.origin_uuid
				var target_gold_amount = payload.target_gold_amount
				if has_method("_animate_gold_gain"):
					await _animate_gold_gain(origin_uuid, amount, target_gold_amount)

			CombatEvent.Type.TOKEN_GAIN:
				var payload = event.visual_payload
				var amount = payload.amount
				var origin_uuid = payload.origin_uuid
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
				var container_tag: StringName = payload.container_tag
				var slot_index: int = payload.slot_index
				var to_effect: StringName = payload.to_effect
				if has_method("_get_slot_view"):
					var slot_view = _get_slot_view(container_tag, slot_index)
					if is_instance_valid(slot_view) and slot_view.has_method("animate_slot_effect_change"):
						await slot_view.animate_slot_effect_change(to_effect)
					elif is_instance_valid(slot_view) and slot_view.has_method("set_slot_effect"):
						slot_view.set_slot_effect(to_effect)
						await AnimationConstants.create_pausable_timer(get_tree(), 0.2).timeout

		await get_tree().process_frame
	
	_is_paused = false
	_step_advance_requested = false

func apply_hp_delta(target_uuid: String, amount: int, new_hp: int) -> void:
	var view = _visual_registry.get(target_uuid)
	if is_instance_valid(view) and view.has_method("animate_stat_change"):
		view.animate_stat_change(new_hp, amount, "hp")

func apply_pwr_delta(target_uuid: String, amount: int, new_pwr: int) -> void:
	var view = _visual_registry.get(target_uuid)
	if is_instance_valid(view) and view.has_method("animate_stat_change"):
		view.animate_stat_change(new_pwr, amount, "pwr")

func apply_burn_stack(uuid: String, new_stacks: int) -> void:
	var view = _visual_registry.get(uuid)
	if is_instance_valid(view) and view.has_method("animate_burn_change"):
		view.animate_burn_change(new_stacks)

func apply_armor_stack(uuid: String, new_stacks: int) -> void:
	var view = _visual_registry.get(uuid)
	if is_instance_valid(view) and view.has_method("animate_armor_change"):
		view.animate_armor_change(new_stacks)

func apply_armor_delta(target_uuid: String, armor_consumed: int, new_armor: int) -> void:
	var view = _visual_registry.get(target_uuid)
	if is_instance_valid(view) and view.has_method("animate_armor_stat_change"):
		view.animate_armor_stat_change(new_armor, armor_consumed)

func apply_status_stack(uuid: String, status_id: StringName, new_stacks: int) -> void:
	var view = _visual_registry.get(uuid)
	if is_instance_valid(view) and view.has_method("animate_status_change"):
		view.animate_status_change(status_id, new_stacks)

func apply_spikes_stack(uuid: String, new_stacks: int) -> void:
	var view = _visual_registry.get(uuid)
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

func get_live_position(uuid: String) -> Dictionary:
	var view = _visual_registry.get(uuid)
	if is_instance_valid(view) and view.is_inside_tree():
		var rect = view.get_global_rect()
		return {
			"position": rect.position,
			"size": rect.size,
			"center": Vector2(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
		}
	return get_snapshot_position(uuid)

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
	for activation in event.trinket_activations:
		var act_visual_uuid := activation.visual_uuid
		play_trinket_activation(
			act_visual_uuid,
			activation.definition_id,
			activation.is_enemy
		)
		# The trinket activation registers the view under visual_uuid (origin UUID).
		# The BUFF/DAMAGE event's visual_payload.source_uuid may be the combat UUID,
		# which is different. Register the same view under that UUID too so the
		# projectile in BuffAnimation can locate its source.
		var event_source_uuid := event.visual_payload.source_uuid
		if not event_source_uuid.is_empty() and event_source_uuid != act_visual_uuid:
			var snap = get_snapshot_position(act_visual_uuid)
			if not snap.is_empty():
				_position_snapshot[event_source_uuid] = snap
				# Also copy the visual registry entry
				var view_ref = _visual_registry.get(act_visual_uuid)
				if is_instance_valid(view_ref):
					_visual_registry[event_source_uuid] = view_ref
		# No await timer here to allow concurrent playback

func play_trinket_activation(visual_uuid: String, trinket_definition_id: StringName = &"", is_enemy_trinket: bool = false) -> void:
	var view = _find_trinket_view(visual_uuid, trinket_definition_id, is_enemy_trinket)
	if is_instance_valid(view):
		# Register the trinket view in the position snapshot so subsequent
		# BuffAnimation / DamageAnimation projectiles can locate it as a source.
		if not visual_uuid.is_empty():
			register_dynamic_position(visual_uuid, view)
		if view.has_method("play_trinket_activation_bounce"):
			view.play_trinket_activation_bounce()
		elif view.has_method("play_landing_bounce"):
			view.play_landing_bounce()
func hop_trinket_by_definition_id(trinket_definition_id: StringName, is_enemy_trinket: bool = false) -> void:
	play_trinket_activation("", trinket_definition_id, is_enemy_trinket)

func hop_trinket_by_visual_uuid(visual_uuid: String, trinket_definition_id: StringName = &"", is_enemy_trinket: bool = false) -> void:
	play_trinket_activation(visual_uuid, trinket_definition_id, is_enemy_trinket)

func _find_trinket_view(visual_uuid: String, trinket_definition_id: StringName, is_enemy_trinket: bool) -> GachaBallView:
	var trinket_views := _get_trinket_views_from_tree()
	if not visual_uuid.is_empty():
		for view in trinket_views:
			if is_instance_valid(view):
				var v_uuid = view.get_instance_uuid()
				if v_uuid == visual_uuid or visual_uuid.begins_with(v_uuid + "_"):
					return view
	if trinket_definition_id != &"":
		for view in trinket_views:
			if is_instance_valid(view):
				var view_def_id = view.get_definition_id()
				var view_is_enemy = false
				if is_instance_valid(view._location):
					view_is_enemy = view._location.container == C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS
				if view_def_id == trinket_definition_id and view_is_enemy == is_enemy_trinket:
					return view
	return null

func _get_trinket_views_from_tree() -> Array[GachaBallView]:
	var result: Array[GachaBallView] = []
	for node in get_tree().get_nodes_in_group("trinket_view"):
		if node is GachaBallView and is_instance_valid(node) and not node.is_queued_for_deletion() and node.is_inside_tree() and node.visible:
			result.append(node)
	return result

# Animation waiting now delegated to AnimationCompletionTracker
# All signal connect/disconnect and callback methods removed
func wait_for_animation_completion(animation_type: String, expected_uuid: String) -> void:
	# Map string type to enum
	var anim_type: AnimationCompletionTracker.AnimationType
	match animation_type:
		"flash":
			anim_type = AnimationCompletionTracker.AnimationType.FLASH
		"bump":
			anim_type = AnimationCompletionTracker.AnimationType.BUMP
		"death_fade":
			anim_type = AnimationCompletionTracker.AnimationType.DEATH_FADE
		"summon_fade":
			anim_type = AnimationCompletionTracker.AnimationType.SUMMON_FADE
		"melee_lunge":
			anim_type = AnimationCompletionTracker.AnimationType.MELEE_LUNGE
		"melee_return":
			anim_type = AnimationCompletionTracker.AnimationType.MELEE_RETURN
		"lethal_save":
			anim_type = AnimationCompletionTracker.AnimationType.LETHAL_SAVE
		"move":
			anim_type = AnimationCompletionTracker.AnimationType.MOVE
		_:
			anim_type = AnimationCompletionTracker.AnimationType.FLASH # Default fallback
	
	await _tracker.await_completion(expected_uuid, anim_type)

# =============================================================================
# SPEED CONTROL
# =============================================================================

## Set combat playback speed (1.0 = normal, 2.0 = 2x, 3.0 = 3x, 4.0 = 4x)
func set_combat_speed(factor: float) -> void:
	AnimationConstants.speed_factor = clampf(factor, 1.0, 4.0)

## Get current combat playback speed
func get_combat_speed() -> float:
	return AnimationConstants.speed_factor

# =============================================================================
# STEP MODE & PAUSE CONTROL
# =============================================================================

func _on_battle_inventory_changed() -> void:
	pass

func _on_trait_threshold_reached(trinket_uuid: String, definition_id: StringName, is_enemy: bool) -> void:
	# Using call_deferred so it executes cleanly after layout updates finish
	call_deferred("hop_trinket_by_visual_uuid", trinket_uuid, definition_id, is_enemy)

func pause_combat() -> void:
	_is_paused = true
	_step_advance_requested = false

func play_continuous(speed: float) -> void:
	_is_paused = false
	_step_advance_requested = true # unblock if waiting
	set_combat_speed(speed)

func request_step() -> void:
	_is_paused = true
	_step_advance_requested = true
	set_combat_speed(1.0) # Step always processes at 1x speed

## Build human-readable step info from a CombatEvent for UI display
func _build_step_info(event: CombatEvent) -> Dictionary:
	var info: Dictionary = {
		"event_type": event.get_type_name(),
		"source_uuid": event.source_uuid,
		"target_uuids": event.target_uuids,
		"ability_id": event.ability_id,
		"trigger_type": event.trigger_type
	}
	
	match event.type:
		CombatEvent.Type.DAMAGE:
			var amount = abs(event.visual_payload.amount)
			info["description"] = "Deals %d damage" % amount
		CombatEvent.Type.HEAL:
			var amount = event.visual_payload.amount
			info["description"] = "Heals for %d" % amount
		CombatEvent.Type.BUFF:
			var stat = event.visual_payload.stat
			var amount = event.visual_payload.amount
			info["description"] = "+%d %s" % [amount, stat.to_upper()]
		CombatEvent.Type.DEATH:
			info["description"] = "Dies"
		CombatEvent.Type.SUMMON:
			info["description"] = "Summoned"
		CombatEvent.Type.KAMIKAZE_ATTACK:
			var amount = abs(event.visual_payload.amount)
			info["description"] = "Kamikaze for %d damage" % amount
		CombatEvent.Type.STATUS_EFFECT:
			var stat = event.visual_payload.stat
			var amount = event.visual_payload.amount
			info["description"] = "%s %d" % [stat.trim_suffix("_stacks").to_upper(), amount]
		CombatEvent.Type.LETHAL_SAVE:
			info["description"] = "Saved from lethal damage"
		CombatEvent.Type.GUARDIAN_INTERCEPT:
			info["description"] = "Guardian intercepts"
		CombatEvent.Type.TRANSFORM:
			info["description"] = "Transforms"
		CombatEvent.Type.SLOT_EFFECT_CHANGE:
			var to_effect: String = String(event.visual_payload.to_effect)
			var slot_index: int = event.visual_payload.slot_index
			info["description"] = "Slot %d becomes %s" % [slot_index + 1, to_effect]
		_:
			info["description"] = event.get_type_name()
	
	return info

func _animate_gold_gain(origin_uuid: String, amount: int, target_gold_amount: int = -1) -> void:
	"""Animate gold coins flying from a unit to the gold counter at the top"""
	# 1. Get origin position from snapshot
	var pos_data = _position_snapshot.get(origin_uuid, {})
	if pos_data.is_empty():
		return
	var start_pos = pos_data["center"]
	
	# 2. Get target position (GoldGroup in Main)
	var main_node = GameManager._active_main_node
	if not is_instance_valid(main_node):
		return
	
	var gold_group = main_node.get_node_or_null("%GoldGroup")
	if not is_instance_valid(gold_group):
		return
	
	var gold_icon = gold_group.get_node_or_null("GoldIcon")
	if not is_instance_valid(gold_icon):
		gold_icon = gold_group
		
	var gold_rect = gold_icon.get_global_rect()
	var target_pos = Vector2(
		gold_rect.position.x + gold_rect.size.x / 2,
		gold_rect.position.y + gold_rect.size.y / 2
	)
	
	# Spawn gold coins with stagger
	var coins_to_spawn = mini(amount, 5) # Cap at 5 coins for visual clarity
	var stagger_delay = 0.08
	
	for i in range(coins_to_spawn):
		var coin_vfx = GoldCoinVFXScene.new()
		var effects_layer = WindowManager.get_vfx_layer()
		
		# Set position before add_child to prevent one-frame flash at (0,0)
		coin_vfx.position = start_pos
		effects_layer.add_child(coin_vfx)
		
		# Connect to trigger counter reaction
		coin_vfx.coin_landed.connect(func(_pos: Vector2):
			Audio.play_sfx("coin_land")
			if is_instance_valid(gold_group):
				var tween = gold_group.create_tween()
				gold_group.pivot_offset = gold_group.size / 2.0
				tween.tween_property(gold_group, "scale", Vector2(1.2, 1.2), 0.05)
				tween.tween_property(gold_group, "scale", Vector2(1.0, 1.0), 0.1)
				
				if target_gold_amount != -1:
					SignalBus.emit_signal("gold_changed", target_gold_amount)
		)
		
		var offset = Vector2(RNGManager.cosmetic_rng.randf_range(-15, 15), RNGManager.cosmetic_rng.randf_range(-8, 8))
		coin_vfx.play(start_pos + offset, target_pos, i * stagger_delay)
		Audio.play_sfx("coin_spawn", 1.0 + (i * 0.05))

	# Wait for animations
	var total_wait = (coins_to_spawn - 1) * stagger_delay + 0.45
	await AnimationConstants.create_pausable_timer(get_tree(), total_wait).timeout

func _animate_token_gain(origin_uuid: String, amount: int) -> void:
	# 1. Get origin position from snapshot
	var pos_data = _position_snapshot.get(origin_uuid, {})
	var start_pos = Vector2.ZERO
	if not pos_data.is_empty():
		start_pos = pos_data["center"]
	else:
		# Fallback to visual registry if available
		var view = _visual_registry.get(origin_uuid)
		if not is_instance_valid(view) or not view.is_inside_tree():
			view = _find_trinket_view(origin_uuid, &"", false)
			
		if is_instance_valid(view) and view.is_inside_tree():
			start_pos = view.get_global_rect().get_center()
			
	if start_pos == Vector2.ZERO:
		var window_size = get_viewport().get_visible_rect().size
		start_pos = window_size / 2.0
		
	# 2. Get target position (TokenGroup in Main)
	var main_node = GameManager._active_main_node
	if not is_instance_valid(main_node):
		return
		
	var token_group = main_node.get_node_or_null("%TokenGroup")
	if not is_instance_valid(token_group):
		return
	
	var token_icon = token_group.get_node_or_null("TokenIcon")
	if not is_instance_valid(token_icon):
		token_icon = token_group
		
	var token_rect = token_icon.get_global_rect()
	var target_pos = Vector2(
		token_rect.position.x + token_rect.size.x / 2,
		token_rect.position.y + token_rect.size.y / 2
	)
	
	# Spawn tokens with stagger
	var tokens_to_spawn = mini(amount, 5) # Cap at 5 tokens for visual clarity
	var stagger_delay = 0.08
	
	var total_coins_landed = 0
	
	for i in range(tokens_to_spawn):
		var token_vfx = TokenPopVFXScene.instantiate()
		var effects_layer = WindowManager.get_vfx_layer()
		
		# Set position before add_child to prevent one-frame flash at (0,0)
		token_vfx.position = start_pos
		effects_layer.add_child(token_vfx)
		
		token_vfx.setup(start_pos, target_pos)
		
		# Connect to trigger counter reaction
		token_vfx.animation_finished.connect(func():
			Audio.play_sfx("coin_land")
			total_coins_landed += 1
			var bm = GameManager._active_battle_manager
			if is_instance_valid(bm) and bm.has_method("add_visual_gacha_token"):
				bm.add_visual_gacha_token(1)
			
			if is_instance_valid(token_group):
				var tween = token_group.create_tween()
				token_group.pivot_offset = token_group.size / 2.0
				tween.tween_property(token_group, "scale", Vector2(1.2, 1.2), 0.05)
				tween.tween_property(token_group, "scale", Vector2(1.0, 1.0), 0.1)
		)
		
		if i > 0:
			await AnimationConstants.create_pausable_timer(get_tree(), stagger_delay).timeout
		
		if is_instance_valid(token_vfx):
			token_vfx.play(target_pos)
			Audio.play_sfx("coin_spawn", 1.0 + (i * 0.05))

	# Wait for animations to complete
	var total_wait_token = 0.5 + (tokens_to_spawn * stagger_delay)
	await AnimationConstants.create_pausable_timer(get_tree(), total_wait_token).timeout

func _animate_item_transfer(source_uuid: String, target_uuid: String, payload: CombatPayload) -> void:
	var source_view = _visual_registry.get(source_uuid)
	var target_view = _visual_registry.get(target_uuid)
	
	var item_icon_path = payload.item_icon_path
	
	# Extract chronological stats from the payload so we do not query the "future" simulated state
	var old_hp = payload.old_hp
	var new_hp = payload.new_hp
	var old_pwr = payload.old_pwr
	var new_pwr = payload.new_pwr
	
	var hp_diff = new_hp - old_hp
	var pwr_diff = new_pwr - old_pwr
	
	var start_pos = Vector2.ZERO
	var end_pos = Vector2.ZERO
	
	# Try to get live positions if available, fallback to snapshot
	if is_instance_valid(source_view) and source_view.is_inside_tree():
		start_pos = source_view.global_position + (source_view.size / 2.0)
	else:
		var snap = get_snapshot_position(source_uuid)
		if not snap.is_empty():
			start_pos = snap["center"]
			
	if is_instance_valid(target_view) and target_view.is_inside_tree():
		end_pos = target_view.global_position + (target_view.size / 2.0)
	else:
		var snap = get_snapshot_position(target_uuid)
		if not snap.is_empty():
			end_pos = snap["center"]
			
	if start_pos == Vector2.ZERO or end_pos == Vector2.ZERO:
		# Fail gracefully if positions are invalid
		if is_instance_valid(source_view) and source_view.has_method("set_visual_equipped_item_icon"):
			source_view.set_visual_equipped_item_icon(null)
		if is_instance_valid(target_view) and target_view.has_method("set_visual_equipped_item_icon"):
			var item_texture = load(item_icon_path) as Texture2D
			target_view.set_visual_equipped_item_icon(item_texture)
			
			if hp_diff != 0 and target_view.has_method("animate_stat_change"):
				target_view.animate_stat_change(new_hp, hp_diff, "hp")
			if pwr_diff != 0 and target_view.has_method("animate_stat_change"):
				target_view.animate_stat_change(new_pwr, pwr_diff, "pwr")
		return
		
	# Load item texture
	var item_texture = load(item_icon_path) as Texture2D
	if not is_instance_valid(item_texture):
		return
		
	# Clear source view icon immediately as the item begins to fly!
	if is_instance_valid(source_view) and source_view.has_method("set_visual_equipped_item_icon"):
		source_view.set_visual_equipped_item_icon(null)
		
	# Calculate target scale to fit exactly 96x96 pixels in battle (matching the standard bench size)
	var target_size := 96.0
	var tex_size := item_texture.get_size()
	var scale_factor := target_size / maxf(maxf(tex_size.x, tex_size.y), 1.0)
	
	# Create flying item visual using Sprite2D to prevent Control scale/pivot shifts
	var flying_icon = Sprite2D.new()
	flying_icon.texture = item_texture
	flying_icon.centered = true
	flying_icon.scale = Vector2(scale_factor, scale_factor)
	
	var effects_layer = WindowManager.get_vfx_layer()
	effects_layer.add_child(flying_icon)
	
	# Kinematic parabolic arc tween
	var duration := 0.6
	var arc_height := 250.0
	
	# Spawn sound
	Audio.play_sfx("unit_toss")
	
	var tween = flying_icon.create_tween()
	tween.tween_method(func(t: float):
		var curr_x = lerp(start_pos.x, end_pos.x, t)
		var curr_y = lerp(start_pos.y, end_pos.y, t) - (4.0 * arc_height * t * (1.0 - t))
		flying_icon.global_position = Vector2(curr_x, curr_y)
	, 0.0, 1.0, duration)
	
	await tween.finished
	flying_icon.queue_free()
	
	# Landing sound and impact
	Audio.play_sfx("token_land")
	
	# Landing visual update - set target's equipped item icon!
	if is_instance_valid(target_view) and target_view.has_method("set_visual_equipped_item_icon"):
		target_view.set_visual_equipped_item_icon(item_texture)
		target_view.play_landing_bounce()
		
		# Animate the stat change immediately upon landing, just like a self buff, with NO flying projectile!
		if hp_diff != 0 and target_view.has_method("animate_stat_change"):
			target_view.animate_stat_change(new_hp, hp_diff, "hp")
		if pwr_diff != 0 and target_view.has_method("animate_stat_change"):
			target_view.animate_stat_change(new_pwr, pwr_diff, "pwr")
