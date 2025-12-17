# scripts/BattleAnimator.gd
extends Node

signal turn_animation_finished

const ANIM_TIMEOUT_DURATION = 1.1
const BUMP_DURATION = 0.5

var _hp_snapshot: Dictionary = {}
var _current_animation_uuid: String = "" # Track which unit is currently animating
var _dead_units: Dictionary = {} # Track units that have already animated death this turn
var _visual_registry: Dictionary = {} # UUID -> GachaBallView (for puppet mode)
var _position_snapshot: Dictionary = {} # UUID -> {position: Vector2, size: Vector2} - captured at animation start
var _pending_guardian_return: String = "" # UUID of Guardian needing to return after damage

func set_hp_snapshot(snapshot: Dictionary) -> void:
	# Snapshot of unit_uuid -> hp before simulation. Animator will restore these
	# values before playing events so each event updates the label visibly.
	_hp_snapshot = snapshot.duplicate(true)

func _ready() -> void:
	add_to_group("battle_animator")
	# Initialize animations
	AnimationRegistry.load_standard_animations()

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
							# GachaBallView is first child of SlotView
							var gacha_view = slot_view.get_child(0)
							
							if is_instance_valid(gacha_view) and gacha_view is GachaBallView:
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
						print("[BattleAnimator] Failed to register ", uuid, ": Index ", index, " out of bounds for ", container_tag)
				else:
					print("[BattleAnimator] Failed to register ", uuid, ": Invalid container or index")
	
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
	# Connect to animation completion signals for this turn
	_connect_animation_signals()
	
	# SIMULATION-PRESENTATION VERIFICATION: Log all events we're about to process
	print("[ANIM] ========== START ANIMATION SEQUENCE: %d events ==========" % events.size())
	for evt in events:
		evt.log_sim() # Log each event for cross-reference with simulation

	var processed_count: int = 0
	for event in events:
		processed_count += 1
		
		SignalBus.log_animation_event.emit(event)
		match event.type:
			CombatEvent.Type.LOG_MESSAGE:
				pass # Log messages are instant, no animation to wait for

			CombatEvent.Type.DAMAGE:
				# Use the dedicated DamageAnimation class which handles bumps, projectiles, and flashes
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
					await anim.execute(self, event.target_uuids, event.visual_payload)
				else:
					push_error("[BattleAnimator] Heal animation not found in registry!")

			CombatEvent.Type.BUFF:
				# Use the dedicated BuffAnimation class which handles projectiles and flashes
				var anim = AnimationRegistry.get_animation("buff")
				if anim:
					await anim.execute(self, event.target_uuids, event.visual_payload)
				else:
					push_error("[BattleAnimator] Buff animation not found in registry!")

			CombatEvent.Type.DEATH:
				# Play death fade on target
				if event.target_uuids.size() > 0:
					var dead_uuid := event.target_uuids[0]
					
					# Prevent duplicate death animations for the same unit in this sequence
					if _dead_units.has(dead_uuid):
						continue
						
					_dead_units[dead_uuid] = true
					_current_animation_uuid = dead_uuid
					
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
			CombatEvent.Type.SUMMON:
				var payload = event.visual_payload
				var _old_unit_uuid = String(payload.get("old_unit_uuid", "")) # For reference only
				var new_unit_uuid = String(payload.get("new_unit_uuid", ""))
				var old_location = payload.get("old_unit_location")
				
				# PRESENTATION ONLY: Create new view in slot
				# DEATH event already removed the old view (DEATH → SUMMON ordering)
				# Animator just plays events in sequence blindly - no game state knowledge needed
				if is_instance_valid(old_location):
					var container_tag = old_location.container
					var index = old_location.index
					
					var battle_view = get_tree().get_first_node_in_group("battle_view")
					if is_instance_valid(battle_view):
						var lineup_container: HBoxContainer = null
						if container_tag == &"PlayerLineup":
							lineup_container = battle_view.player_lineup
						elif container_tag == &"EnemyLineup":
							lineup_container = battle_view.enemy_lineup
						
						if is_instance_valid(lineup_container) and index >= 0 and index < lineup_container.get_child_count():
							var slot_view = lineup_container.get_child(index)
							
							# SAFETY: Clear any existing views in slot before adding new one
							# This handles cases where DEATH animation hasn't freed views yet
							for existing_child in slot_view.get_children():
								if existing_child is GachaBallView:
									# Also remove from registry if present
									var existing_uuid = existing_child.get_instance_uuid() if existing_child.has_method("get_instance_uuid") else ""
									if not existing_uuid.is_empty() and _visual_registry.has(existing_uuid):
										_visual_registry.erase(existing_uuid)
									existing_child.queue_free()
							
							# Create new view (slot now guaranteed empty)
							var new_view = preload("res://scenes/GachaBallView.tscn").instantiate()
							slot_view.add_child(new_view)
							
							# Use new_unit_snapshot from payload
							var new_snapshot = payload.get("new_unit_snapshot", {})
							if not new_snapshot.is_empty():
								var new_location = LocationIdentifier.new(container_tag, index)
								new_view.populate(new_location, new_snapshot, false, false)
								var def_id: StringName = new_snapshot.get("def_id", &"")
								new_view.set_is_enemy(container_tag == &"EnemyLineup", def_id)
								
								_visual_registry[new_unit_uuid] = new_view
								
								# DECOUPLING: Register position for animations targeting summoned units
								await get_tree().process_frame # Wait for layout to update
								var rect = new_view.get_global_rect()
								_position_snapshot[new_unit_uuid] = {
									"position": rect.position,
									"size": rect.size,
									"center": Vector2(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
								}
								
								# Trigger summon animation
								_current_animation_uuid = new_unit_uuid
								if SignalBus.has_signal("unit_summon_fade"):
									SignalBus.emit_signal("unit_summon_fade", new_unit_uuid)
									await wait_for_animation_completion("summon_fade", new_unit_uuid)

			CombatEvent.Type.LETHAL_SAVE:
				# Aegis Charm: unit floats up golden then lands back
				if event.target_uuids.size() > 0:
					var saved_uuid := event.target_uuids[0]
					var payload = event.visual_payload
					var heal_amount: int = int(payload.get("heal_amount", 1))
					_current_animation_uuid = saved_uuid
					
					if SignalBus.has_signal("unit_lethal_save"):
						SignalBus.emit_signal("unit_lethal_save", saved_uuid)
						await wait_for_animation_completion("lethal_save", saved_uuid)
					
					# Update HP label to 1 after animation completes
					apply_hp_delta(saved_uuid, heal_amount, 1)

			CombatEvent.Type.GUARDIAN_INTERCEPT:
				# Guardian Sentinel: leaps to ally's position to intercept lethal damage
				var payload = event.visual_payload
				var guardian_uuid: String = String(payload.get("guardian_uuid", ""))
				var original_target_uuid: String = String(payload.get("original_target_uuid", ""))
				
				print("[BattleAnimator] Processing GUARDIAN_INTERCEPT: guardian=%s original=%s" % [guardian_uuid.substr(0, 20), original_target_uuid.substr(0, 20)])
				
				var guardian_view = _visual_registry.get(guardian_uuid)
				var target_pos = get_snapshot_position(original_target_uuid)
				
				if is_instance_valid(guardian_view) and not target_pos.is_empty():
					# Leap to target's position
					_current_animation_uuid = guardian_uuid
					if guardian_view.has_method("animate_leap_to"):
						await guardian_view.animate_leap_to(target_pos.center)
					else:
						# Fallback: instant move
						guardian_view.global_position = Vector2(
							target_pos.center.x - guardian_view.size.x / 2,
							target_pos.center.y - guardian_view.size.y / 2
						)
					
					# Mark guardian for return after damage animation completes
					_pending_guardian_return = guardian_uuid
					print("[BattleAnimator] Guardian leaped to position, damage event follows")

		# Let the UI process the emitted signal this frame
		await get_tree().process_frame
	
	# Disconnect animation signals when done
	_disconnect_animation_signals()
	
	# SIMULATION-PRESENTATION VERIFICATION: Log completion summary
	print("[ANIM] ========== ANIMATION SEQUENCE COMPLETE: %d events processed ==========" % processed_count)
	
	print("[BattleAnimator] Emitting turn_animation_finished!")
	emit_signal("turn_animation_finished")

func apply_hp_delta(target_uuid: String, amount: int, new_hp: int) -> void:
	# PUPPET MODE: Use visual registry to update view directly
	var view = _visual_registry.get(target_uuid)
	
	if not is_instance_valid(view) or not (view is GachaBallView):
		# DECOUPLED: No fallback - if view not in registry, simulation emitted an invalid event
		push_error("[BattleAnimator] HP delta target not in visual registry: " + target_uuid)
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
		push_error("[BattleAnimator] PWR delta target not in visual registry: " + target_uuid)

func apply_burn_stack(uuid: String, new_stacks: int) -> void:
	# Update visual burn stacks on puppet view
	if _visual_registry.has(uuid):
		var view = _visual_registry[uuid]
		if view.has_method("animate_burn_change"):
			view.animate_burn_change(new_stacks)

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
func _connect_animation_signals() -> void:
	# Connect to animation completion signals with filtering
	if not SignalBus.unit_flash_finished.is_connected(_on_unit_flash_finished):
		SignalBus.unit_flash_finished.connect(_on_unit_flash_finished)
	if not SignalBus.unit_bump_finished.is_connected(_on_unit_bump_finished):
		SignalBus.unit_bump_finished.connect(_on_unit_bump_finished)
	if not SignalBus.unit_death_fade_finished.is_connected(_on_unit_death_fade_finished):
		SignalBus.unit_death_fade_finished.connect(_on_unit_death_fade_finished)
	if not SignalBus.unit_summon_fade_finished.is_connected(_on_unit_summon_fade_finished):
		SignalBus.unit_summon_fade_finished.connect(_on_unit_summon_fade_finished)
	if not SignalBus.unit_melee_lunge_finished.is_connected(_on_unit_melee_lunge_finished):
		SignalBus.unit_melee_lunge_finished.connect(_on_unit_melee_lunge_finished)
	if not SignalBus.unit_melee_return_finished.is_connected(_on_unit_melee_return_finished):
		SignalBus.unit_melee_return_finished.connect(_on_unit_melee_return_finished)
	if not SignalBus.unit_lethal_save_finished.is_connected(_on_unit_lethal_save_finished):
		SignalBus.unit_lethal_save_finished.connect(_on_unit_lethal_save_finished)

func _disconnect_animation_signals() -> void:
	# Disconnect animation completion signals
	if SignalBus.unit_flash_finished.is_connected(_on_unit_flash_finished):
		SignalBus.unit_flash_finished.disconnect(_on_unit_flash_finished)
	if SignalBus.unit_bump_finished.is_connected(_on_unit_bump_finished):
		SignalBus.unit_bump_finished.disconnect(_on_unit_bump_finished)
	if SignalBus.unit_death_fade_finished.is_connected(_on_unit_death_fade_finished):
		SignalBus.unit_death_fade_finished.disconnect(_on_unit_death_fade_finished)
	if SignalBus.unit_summon_fade_finished.is_connected(_on_unit_summon_fade_finished):
		SignalBus.unit_summon_fade_finished.disconnect(_on_unit_summon_fade_finished)
	if SignalBus.unit_melee_lunge_finished.is_connected(_on_unit_melee_lunge_finished):
		SignalBus.unit_melee_lunge_finished.disconnect(_on_unit_melee_lunge_finished)
	if SignalBus.unit_melee_return_finished.is_connected(_on_unit_melee_return_finished):
		SignalBus.unit_melee_return_finished.disconnect(_on_unit_melee_return_finished)
	if SignalBus.unit_lethal_save_finished.is_connected(_on_unit_lethal_save_finished):
		SignalBus.unit_lethal_save_finished.disconnect(_on_unit_lethal_save_finished)

# Signal handlers that filter by current animation UUID
func _on_unit_flash_finished(unit_uuid: String) -> void:
	# Only respond if this is the unit we're currently waiting for
	if unit_uuid == _current_animation_uuid:
		_current_animation_uuid = ""

func _on_unit_bump_finished(unit_uuid: String) -> void:
	# Only respond if this is the unit we're currently waiting for
	if unit_uuid == _current_animation_uuid:
		_current_animation_uuid = ""

func _on_unit_death_fade_finished(unit_uuid: String) -> void:
	# Only respond if this is the unit we're currently waiting for
	if unit_uuid == _current_animation_uuid:
		_current_animation_uuid = ""

func _on_unit_summon_fade_finished(unit_uuid: String) -> void:
	# Only respond if this is the unit we're currently waiting for
	if unit_uuid == _current_animation_uuid:
		_current_animation_uuid = ""

func _on_unit_melee_lunge_finished(unit_uuid: String) -> void:
	# Only respond if this is the unit we're currently waiting for
	if unit_uuid == _current_animation_uuid:
		_current_animation_uuid = ""

func _on_unit_melee_return_finished(unit_uuid: String) -> void:
	# Only respond if this is the unit we're currently waiting for
	if unit_uuid == _current_animation_uuid:
		_current_animation_uuid = ""

func _on_unit_lethal_save_finished(unit_uuid: String) -> void:
	# Only respond if this is the unit we're currently waiting for
	if unit_uuid == _current_animation_uuid:
		_current_animation_uuid = ""

# Robust animation waiting with timeout fallback
func wait_for_animation_completion(animation_type: String, expected_uuid: String) -> void:
	var timeout_duration: float
	match animation_type:
		"bump":
			timeout_duration = ANIM_TIMEOUT_DURATION # Bump is 1.0s
		"flash":
			timeout_duration = ANIM_TIMEOUT_DURATION # Flash is 1.0s
		"death_fade":
			timeout_duration = ANIM_TIMEOUT_DURATION # Death fade is 1.0s
		"summon_fade":
			timeout_duration = ANIM_TIMEOUT_DURATION # Summon fade is 1.0s
		"melee_lunge":
			timeout_duration = 1.5 # Melee lunge is ~1.0s (windup + lunge), add buffer
		"melee_return":
			timeout_duration = 0.4 # Melee return is ~0.2s, add buffer
		"lethal_save":
			timeout_duration = 2.0 # Lethal save is ~1.4s, add buffer
		_:
			timeout_duration = ANIM_TIMEOUT_DURATION # Default fallback
	
	# Create timeout timer
	var timeout_timer = get_tree().create_timer(timeout_duration)
	
	# Wait for either the signal (via _current_animation_uuid being cleared) or timeout
	while _current_animation_uuid == expected_uuid and timeout_timer.time_left > 0:
		await get_tree().process_frame
	
	# If we timed out, log it for debugging
	if _current_animation_uuid == expected_uuid:
		print("[BattleAnimator] Animation timeout for ", animation_type, " on unit ", expected_uuid)
	
	# Ensure UUID is cleared
	_current_animation_uuid = ""
