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

func play_turn_sequence(start_snapshot: Dictionary, turn_log: Array[CombatEvent]) -> void:
	# VCR Pattern: start_snapshot contains full board state, turn_log is the event sequence
	# Extract HP snapshot for backward compatibility
	var hp_only_snapshot: Dictionary = {}
	for uuid in start_snapshot:
		var data = start_snapshot[uuid]
		if data is Dictionary and data.has("hp"):
			hp_only_snapshot[uuid] = data["hp"]
	
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
								push_warning("[BattleAnimator] Failed to register %s: Child is not GachaBallView" % uuid)
						else:
							push_warning("[BattleAnimator] Failed to register %s: Slot %d in %s is empty" % [uuid, index, container_tag])
					else:
						pass
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
	
	await play_turn(turn_log)

func play_turn(events: Array[CombatEvent]) -> void:
	if events.is_empty():
		emit_signal("turn_animation_finished")
		return
	
	_dead_units.clear()
	
	# DECOUPLED: No instance rewinding needed
	# Views are initialized from snapshot in play_turn_sequence()
	# Events contain absolute values (old_hp,  new_hp) so views animate correctly
	# This is true presentation-only mode - no simulation mutation
	
	await _animate_events(events)

func _animate_events(events: Array[CombatEvent]) -> void:
	# NOTE: Animation completion tracking now handled by AnimationCompletionTracker
	# SIMULATION-PRESENTATION VERIFICATION: Log all events we're about to process
	# SIMULATION-PRESENTATION VERIFICATION: Log all events we're about to process
	for event in events:
		SignalBus.log_animation_event.emit(event)
		
		# Skip non-visual events in step mode
		if event.type == CombatEvent.Type.LOG_MESSAGE:
			continue
		
		# STEP MODE: Pause before each visual event and wait for user input
		if _is_paused and not _step_advance_requested:
			var step_info = _build_step_info(event)
			emit_signal("combat_step_reached", step_info)
			
			# Wait for user to click "Next Step" or a Play speed
			while _is_paused and not _step_advance_requested:
				await get_tree().process_frame
				
		_step_advance_requested = false # consume the step request exactly once per event
		
		match event.type:
			CombatEvent.Type.LOG_MESSAGE:
				pass # Log messages are instant, no animation to wait for

			CombatEvent.Type.DAMAGE:
				# Use the dedicated DamageAnimation class which handles bumps, projectiles, and flashes
				# NOTE: Audio is handled inside DamageAnimation at proper timing (lunge + impact)
				var anim = AnimationRegistry.get_animation("damage")
				if anim:
					await anim.execute(self, event.target_uuids, event.visual_payload)
				else:
					push_error("[BattleAnimator] Damage animation not found in registry!")
				
				# After damage, check if Guardian needs to return to original position
				if not _pending_guardian_return.is_empty():
					var guardian_view = _visual_registry.get(_pending_guardian_return)
					if is_instance_valid(guardian_view) and guardian_view.has_method("animate_leap_return"):
						await guardian_view.animate_leap_return()
					_pending_guardian_return = ""

			CombatEvent.Type.HEAL:
				# Use the dedicated HealAnimation class which handles projectiles and flashes
				var anim = AnimationRegistry.get_animation("heal")
				if anim:
					# AUDIO HOOK: Heal (play BEFORE await so sound syncs with animation start)
					Audio.play_sfx("combat_heal")
					await anim.execute(self, event.target_uuids, event.visual_payload)
				else:
					push_error("[BattleAnimator] Heal animation not found in registry!")

			CombatEvent.Type.BUFF:
				# Use the dedicated BuffAnimation class for HP/PWR stats
				var anim = AnimationRegistry.get_animation("buff")
				if anim:
					# AUDIO HOOK: Buff (play BEFORE await so sound syncs with animation start)
					Audio.play_sfx("combat_buff")
					await anim.execute(self, event.target_uuids, event.visual_payload)
				else:
					push_error("[BattleAnimator] Buff animation not found in registry!")

			CombatEvent.Type.STATUS_EFFECT:
				# Use the dedicated StatusEffectAnimation class for status effect stacks
				var anim = AnimationRegistry.get_animation("status_effect")
				if anim:
					# AUDIO HOOK: Status effect (same sound as buff for now)
					Audio.play_sfx("combat_buff")
					await anim.execute(self, event.target_uuids, event.visual_payload)
				else:
					push_error("[BattleAnimator] Status effect animation not found in registry!")

			CombatEvent.Type.DEATH:
				# Play death fade on target
				if event.target_uuids.size() > 0:
					var dead_uuid := event.target_uuids[0]
					
					# Prevent duplicate death animations for the same unit in this sequence
					if _dead_units.has(dead_uuid):
						continue
						
					_dead_units[dead_uuid] = true
					
					# Check if this is a player unit BEFORE the animation (data may be gone after)
					var is_player_unit := false
					var payload = event.visual_payload
					if payload.has("container_tag"):
						var tag = payload.get("container_tag")
						is_player_unit = tag == &"PlayerLineup" or tag == &"PlayerBench" or tag == &"DiscardPile"
					
					# AUDIO HOOK: Death
					Audio.play_sfx("combat_death")
					
					if SignalBus.has_signal("unit_death_fade"):
						SignalBus.emit_signal("unit_death_fade", dead_uuid)
					await wait_for_animation_completion("death_fade", dead_uuid)
					
					# Remove the dead view from scene after animation completes
					# With DEATH → SUMMON ordering, the slot will be empty when SUMMON runs
					var dead_view = _visual_registry.get(dead_uuid)
					if is_instance_valid(dead_view):
						dead_view.queue_free()
						_visual_registry.erase(dead_uuid)
						# CRITICAL: Wait one frame for queue_free() to actually remove the node
						# This ensures the slot is empty before any SUMMON event runs
						await get_tree().process_frame
					
					# TUTORIAL: Show unit death tutorial if player unit died (BLOCKING)
					if is_player_unit:
						await TutorialManager.show_tutorial_and_wait(&"unit_death_intro", [
							{"text": TranslationServer.translate("tutorial.unit_death")}
						])
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
				
				# 1. Arc Animation (Elite -> Machine) if metadata present
				var arc_completed = false
				if not spawn_source_uuid.is_empty() and is_instance_valid(main_node):
					var source_pos_data = _position_snapshot.get(spawn_source_uuid, {})
					var machine_node = main_node.get_node_or_null("%%GachaMachine%d" % unit_tier)
					
					if not source_pos_data.is_empty() and is_instance_valid(machine_node):
						var start_center: Vector2 = source_pos_data["center"]
						var machine_rect = machine_node.get_global_rect()
						var end_center: Vector2 = machine_rect.get_center()
						
						# Initial setup - REUSING EXACT SYSTEM PROPORTIONS
						var anim_capsule = preload("res://scenes/GachaBallView.tscn").instantiate()
						anim_capsule.set_size_scale(1.0) # Matches 96px Inventory Standard
						
						# Standard UI setup to prevent expansion
						anim_capsule.custom_minimum_size = Vector2(96, 96)
						anim_capsule.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
						
						# CRITICAL: Add to tree BEFORE populate so @onready vars work!
						anim_capsule.top_level = true
						if not anim_capsule.is_inside_tree():
							main_node.add_child(anim_capsule)
						
						anim_capsule.force_inventory_mode = true # Ensure system capsule overlay is used
						var new_snapshot = payload.get("new_unit_snapshot", {})
						anim_capsule.populate(null, new_snapshot)
						
						var initial_scale := 0.3
						var final_scale_val := 1.5
						anim_capsule.scale = Vector2(initial_scale, initial_scale)
						
						var center_offset = Vector2(48, 48) # slot_base/2
						var arc_height := 500.0 # Standard weighted peak
						var duration := 0.7
						
						var tween = anim_capsule.create_tween()
						tween.set_trans(Tween.TRANS_LINEAR)
						
						tween.tween_method(func(t: float):
							# 1. THE "CORRECT" KINEMATIC ARC:
							var curr_x = lerp(start_center.x, end_center.x, t)
							var curr_y = lerp(start_center.y, end_center.y, t) - (4.0 * arc_height * t * (1.0 - t))
							
							# 2. FAST-SCALE "POP": Reaches final size at 10% of duration
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

				# 2. Fade in unit in its actual slot (unless it's an inventory summon, which has no slot)
				if not is_inventory_summon and is_instance_valid(battle_view):
					var lineup_container: HBoxContainer = null
					if container_tag == &"PlayerLineup" or container_tag == &"PlayerBench":
						lineup_container = battle_view.player_lineup if container_tag == &"PlayerLineup" else battle_view.player_bench
					elif container_tag == &"EnemyLineup":
						lineup_container = battle_view.enemy_lineup
					
					if is_instance_valid(lineup_container) and index >= 0 and index < lineup_container.get_child_count():
						var slot_view = lineup_container.get_child(index)
						var new_view = preload("res://scenes/GachaBallView.tscn").instantiate()
						# Defensive: if slot already has a GachaBallView, skip this summon entirely
						# NOTE: SlotView always has indicator/background children, so we must
						# check for GachaBallView specifically, not just any child.
						var has_existing_unit := false
						for child in slot_view.get_children():
							if child is GachaBallView:
								has_existing_unit = true
								break
						if has_existing_unit:
							new_view.queue_free()
						else:
							slot_view.add_child(new_view)
							
							var new_snapshot = payload.get("new_unit_snapshot", {})
							if not new_snapshot.is_empty():
								var new_location = LocationIdentifier.new(container_tag, index)
								new_view.populate(new_location, new_snapshot, false, false)
								new_view.set_is_enemy(container_tag == &"EnemyLineup", new_snapshot.get("def_id", &""))
								
								_visual_registry[new_unit_uuid] = new_view
								
								# Register dynamic position
								await get_tree().process_frame
								var rect = new_view.get_global_rect()
								_position_snapshot[new_unit_uuid] = {
									"position": rect.position,
									"size": rect.size,
									"center": Vector2(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
								}
								
								if arc_completed:
									# If we arced, just snap the unit in and bounce
									new_view.play_landing_bounce()
								else:
									# Standard fade in
									if SignalBus.has_signal("unit_summon_fade"):
										SignalBus.emit_signal("unit_summon_fade", new_unit_uuid)
										Audio.play_sfx("combat_summon")
										await wait_for_animation_completion("summon_fade", new_unit_uuid)
				
				# Wait a tiny bit for the machine bounce to feel solid
				if arc_completed:
					await get_tree().create_timer(0.2).timeout

			CombatEvent.Type.LETHAL_SAVE:
				# Aegis Charm: use dedicated LethalSaveAnimation
				var anim = AnimationRegistry.get_animation("lethal_save")
				if anim:
					await anim.execute(self, event.target_uuids, event.visual_payload)
				else:
					push_error("[BattleAnimator] Lethal save animation not found in registry!")

			CombatEvent.Type.GUARDIAN_INTERCEPT:
				# Guardian Sentinel: use dedicated GuardianInterceptAnimation
				var anim = AnimationRegistry.get_animation("guardian_intercept")
				if anim:
					await anim.execute(self, event.target_uuids, event.visual_payload)
				else:
					push_error("[BattleAnimator] Guardian intercept animation not found in registry!")

			CombatEvent.Type.KAMIKAZE_ATTACK:
				# Death's Bargain: dying unit lunges to target, attacks, dies at target
				var anim = AnimationRegistry.get_animation("kamikaze")
				if anim:
					await anim.execute(self, event.target_uuids, event.visual_payload)
				else:
					push_error("[BattleAnimator] Kamikaze animation not found in registry!")

			CombatEvent.Type.TRANSFORM:
				# Mimic Transform: use dedicated TransformAnimation
				var anim = AnimationRegistry.get_animation("transform")
				if anim:
					# AUDIO HOOK: Hop sound? Or maybe a special transform sound if available.
					# For now, using unit_hop signal in the animation handles the hop sound.
					await anim.execute(self, event.target_uuids, event.visual_payload)
				else:
					push_error("[BattleAnimator] Transform animation not found in registry!")

		# Let the UI process the emitted signal this frame
		await get_tree().process_frame
	# NOTE: Animation completion tracking now handled by AnimationCompletionTracker
	
	# SIMULATION-PRESENTATION VERIFICATION: Log completion summary
	# SIMULATION-PRESENTATION VERIFICATION: Log completion summary
	
	# Clear step mode at end of turn
	_is_paused = false
	_step_advance_requested = false
	
	emit_signal("turn_animation_finished")

func apply_hp_delta(target_uuid: String, amount: int, new_hp: int) -> void:
	# PUPPET MODE: Use visual registry to update view directly
	var view = _visual_registry.get(target_uuid)
	
	if not is_instance_valid(view) or not (view is GachaBallView):
		# DECOUPLED: No fallback - if view not in registry, simulation emitted an invalid event
		# Graceful degradation: Warn but don't crash, logic already applied
		push_warning("[BattleAnimator] HP delta target not in visual registry: " + target_uuid)
		return
		
	view.animate_stat_change(new_hp, amount, "hp")

func apply_pwr_delta(target_uuid: String, amount: int, new_pwr: int) -> void:
	# PUPPET MODE: Use visual registry to update view directly
	var view = _visual_registry.get(target_uuid)
	if is_instance_valid(view) and view is GachaBallView:
		# Call puppet view's animate method with absolute value
		view.animate_stat_change(new_pwr, amount, "pwr")
	else:
		# DECOUPLED: No fallback - if view not in registry, simulation emitted an invalid event
		# Graceful degradation: Warn but don't crash, logic already applied
		push_warning("[BattleAnimator] PWR delta target not in visual registry: " + target_uuid)

func apply_burn_stack(uuid: String, new_stacks: int) -> void:
	# Update visual burn stacks on puppet view
	if _visual_registry.has(uuid):
		var view = _visual_registry[uuid]
		if is_instance_valid(view) and view.has_method("animate_burn_change"):
			view.animate_burn_change(new_stacks)

func apply_armor_stack(uuid: String, new_stacks: int) -> void:
	# Update visual armor stacks on puppet view - same pattern as burn
	if _visual_registry.has(uuid):
		var view = _visual_registry[uuid]
		if is_instance_valid(view) and view.has_method("animate_armor_change"):
			view.animate_armor_change(new_stacks)

func apply_armor_delta(target_uuid: String, armor_consumed: int, new_armor: int) -> void:
	# Animate armor countdown (counts down from old to new value)
	var view = _visual_registry.get(target_uuid)
	if is_instance_valid(view) and view is GachaBallView:
		if view.has_method("animate_armor_stat_change"):
			view.animate_armor_stat_change(new_armor, armor_consumed)
		else:
			# Fallback to simple update
			view.animate_armor_change(new_armor)

func apply_status_stack(uuid: String, status_id: StringName, new_stacks: int) -> void:
	# Update visual status effect stacks on puppet view (for generic status effects like armor)
	if _visual_registry.has(uuid):
		var view = _visual_registry[uuid]
		if is_instance_valid(view) and view.has_method("animate_status_change"):
			view.animate_status_change(status_id, new_stacks)

func apply_spikes_stack(uuid: String, new_stacks: int) -> void:
	# Update visual spikes stacks on puppet view - same pattern as armor/burn
	# Falls back to generic status change animation
	if _visual_registry.has(uuid):
		var view = _visual_registry[uuid]
		if is_instance_valid(view) and view.has_method("animate_status_change"):
			view.animate_status_change(&"spikes", new_stacks)

func _emit_bump(_attacker_uuid: String) -> void:
	# LEGACY FALLBACK: This is no longer called since all DAMAGE events
	# now have bump_direction precomputed in their payload (handled at line 121-123).
	# Keeping this as a no-op for compatibility with any legacy code paths.
	# TRUE DECOUPLING: No instance queries needed!
	pass

## Get position data from snapshot - animations use this instead of querying views
## Returns: Dictionary with "position", "size", "center" or empty dict if not found
func get_snapshot_position(uuid: String) -> Dictionary:
	return _position_snapshot.get(uuid, {})

## Register a new position for dynamically created units (e.g., summoned units)
func register_dynamic_position(uuid: String, view: GachaBallView) -> void:
	if is_instance_valid(view):
		var rect = view.get_global_rect()
		_position_snapshot[uuid] = {
			"position": rect.position,
			"size": rect.size,
			"center": Vector2(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
			}
		_visual_registry[uuid] = view

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
			var amount = abs(int(event.visual_payload.get("amount", 0)))
			info["description"] = "Deals %d damage" % amount
		CombatEvent.Type.HEAL:
			var amount = int(event.visual_payload.get("amount", 0))
			info["description"] = "Heals for %d" % amount
		CombatEvent.Type.BUFF:
			var stat = String(event.visual_payload.get("stat", ""))
			var amount = int(event.visual_payload.get("amount", 0))
			info["description"] = "+%d %s" % [amount, stat.to_upper()]
		CombatEvent.Type.DEATH:
			info["description"] = "Dies"
		CombatEvent.Type.SUMMON:
			info["description"] = "Summoned"
		CombatEvent.Type.KAMIKAZE_ATTACK:
			var amount = abs(int(event.visual_payload.get("amount", 0)))
			info["description"] = "Kamikaze for %d damage" % amount
		CombatEvent.Type.STATUS_EFFECT:
			var stat = String(event.visual_payload.get("stat", ""))
			var amount = int(event.visual_payload.get("amount", 0))
			info["description"] = "%s %d" % [stat.trim_suffix("_stacks").to_upper(), amount]
		CombatEvent.Type.LETHAL_SAVE:
			info["description"] = "Saved from lethal damage"
		CombatEvent.Type.GUARDIAN_INTERCEPT:
			info["description"] = "Guardian intercepts"
		CombatEvent.Type.TRANSFORM:
			info["description"] = "Transforms"
		_:
			info["description"] = event.get_type_name()
	
	return info
