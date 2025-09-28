# scripts/BattleAnimator.gd
extends Node

signal turn_animation_finished

var _hp_snapshot: Dictionary = {}
var _current_animation_uuid: String = ""  # Track which unit is currently animating

func set_hp_snapshot(snapshot: Dictionary) -> void:
	# Snapshot of unit_uuid -> hp before simulation. Animator will restore these
	# values before playing events so each event updates the label visibly.
	_hp_snapshot = snapshot.duplicate(true)

func _ready() -> void:
	add_to_group("battle_animator")

func play_turn(events: Array[CombatEvent]) -> void:
	if events.is_empty():
		emit_signal("turn_animation_finished")
		return
	# Restore HP from snapshot so subsequent per-event changes are visible.
	# Skip missing instances (e.g., already removed by simulation due to death).
	var bm := _get_battle_manager()
	if is_instance_valid(bm):
		for uuid in _hp_snapshot.keys():
			var inst: GachaBallInstance = bm.get_instance(String(uuid))
			if is_instance_valid(inst):
				inst.set_current_hp_silent(int(_hp_snapshot[uuid]))
	await _animate_events(events)

func _animate_events(events: Array[CombatEvent]) -> void:
	# Connect to animation completion signals for this turn
	_connect_animation_signals()
	
	for event in events:
		match event.type:
			CombatEvent.Type.LOG_MESSAGE:
				SignalBus.emit_signal("battle_log_event", event.text)
				# Log messages are instant, no animation to wait for

			CombatEvent.Type.DAMAGE:
				# Pre-hit: small attacker bump toward the opponent, then apply damage
				if event.target_uuids.size() > 0:
					var target_uuid := event.target_uuids[0]
					
					# Bump animation (if source exists)
					if not event.source_uuid.is_empty():
						_current_animation_uuid = event.source_uuid
						_emit_bump(event.source_uuid)
						await _wait_for_animation_completion("bump", event.source_uuid)
					
					# Apply damage and flash animation
					_apply_hp_delta(target_uuid, event.amount)
					_current_animation_uuid = target_uuid
					if SignalBus.has_signal("unit_flash_effect"):
						SignalBus.emit_signal("unit_flash_effect", target_uuid, Color(1.0, 0.6, 0.6))
						await _wait_for_animation_completion("flash", target_uuid)

			CombatEvent.Type.HEAL:
				# Apply numeric HP delta and flash animation
				if event.target_uuids.size() > 0:
					var target_uuid2 := event.target_uuids[0]
					_apply_hp_delta(target_uuid2, event.amount)
					_current_animation_uuid = target_uuid2
					if SignalBus.has_signal("unit_flash_effect"):
						SignalBus.emit_signal("unit_flash_effect", target_uuid2, Color(0.6, 1.0, 0.6))
						await _wait_for_animation_completion("flash", target_uuid2)

			CombatEvent.Type.INVENTORY_SYNC:
				# This triggers the removal of the dead unit's view from the UI.
				SignalBus.emit_signal("battle_inventory_changed")
				# Inventory sync is instant, no animation to wait for

			CombatEvent.Type.DEATH:
				# Play death fade on target, then request removal
				if event.target_uuids.size() > 0:
					var dead_uuid := event.target_uuids[0]
					_current_animation_uuid = dead_uuid
					if SignalBus.has_signal("unit_death_fade"):
						SignalBus.emit_signal("unit_death_fade", dead_uuid)
						await _wait_for_animation_completion("death_fade", dead_uuid)
					if SignalBus.has_signal("apply_deaths_requested"):
						SignalBus.emit_signal("apply_deaths_requested", [dead_uuid])

		# Let the UI process the emitted signal this frame
		await get_tree().process_frame
	
	# Disconnect animation signals when done
	_disconnect_animation_signals()
	emit_signal("turn_animation_finished")

func _apply_hp_delta(target_uuid: String, amount: int) -> void:
	var bm := _get_battle_manager()
	if not is_instance_valid(bm):
		return
	var inst: GachaBallInstance = bm.get_instance(target_uuid)
	if not is_instance_valid(inst):
		return
	var def = inst.get_definition()
	if not is_instance_valid(def) or def.category != &"UNIT":
		return
	var old_hp := inst.current_hp
	var new_hp := old_hp + amount
	# Clamp to minimum zero; allow overheal as per recalc rules
	new_hp = max(0, new_hp)
	inst.set_current_hp(new_hp)

func _emit_bump(attacker_uuid: String) -> void:
	if attacker_uuid == null or String(attacker_uuid).is_empty():
		return
	var bm := _get_battle_manager()
	if not is_instance_valid(bm):
		return
	var inst: GachaBallInstance = bm.get_instance(String(attacker_uuid))
	if not is_instance_valid(inst):
		return
	# Determine direction: player team bumps right, enemy bumps left
	var dir := Vector2.ZERO
	var def = inst.get_definition()
	if is_instance_valid(def):
		var tag := inst.location_container_tag
		if tag == &"PlayerLineup" or tag == &"PlayerBench":
			dir = Vector2(1, 0)
		elif tag == &"EnemyLineup" or tag == &"EnemyBench":
			dir = Vector2(-1, 0)
	if dir == Vector2.ZERO:
		return
	# Emit bump request; views will animate themselves
	SignalBus.emit_signal("unit_bump_attack", String(attacker_uuid), dir)

func _get_battle_manager() -> Node:
	var node = get_tree().get_first_node_in_group("battle_manager")
	return node

func _connect_animation_signals() -> void:
	# Connect to animation completion signals with filtering
	if not SignalBus.unit_flash_finished.is_connected(_on_unit_flash_finished):
		SignalBus.unit_flash_finished.connect(_on_unit_flash_finished)
	if not SignalBus.unit_bump_finished.is_connected(_on_unit_bump_finished):
		SignalBus.unit_bump_finished.connect(_on_unit_bump_finished)
	if not SignalBus.unit_death_fade_finished.is_connected(_on_unit_death_fade_finished):
		SignalBus.unit_death_fade_finished.connect(_on_unit_death_fade_finished)

func _disconnect_animation_signals() -> void:
	# Disconnect animation completion signals
	if SignalBus.unit_flash_finished.is_connected(_on_unit_flash_finished):
		SignalBus.unit_flash_finished.disconnect(_on_unit_flash_finished)
	if SignalBus.unit_bump_finished.is_connected(_on_unit_bump_finished):
		SignalBus.unit_bump_finished.disconnect(_on_unit_bump_finished)
	if SignalBus.unit_death_fade_finished.is_connected(_on_unit_death_fade_finished):
		SignalBus.unit_death_fade_finished.disconnect(_on_unit_death_fade_finished)

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

# Robust animation waiting with timeout fallback
func _wait_for_animation_completion(animation_type: String, expected_uuid: String) -> void:
	var timeout_duration: float
	match animation_type:
		"bump":
			timeout_duration = 0.16
		"flash":
			timeout_duration = 0.30
		"death_fade":
			timeout_duration = 0.28
		_:
			timeout_duration = 0.30  # Default fallback
	
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
