# scripts/BattleAnimator.gd
extends Node

signal turn_animation_finished

var _hp_snapshot: Dictionary = {}
var _current_animation_uuid: String = "" # Track which unit is currently animating
var _dead_units: Dictionary = {} # Track units that have already animated death this turn
var _visual_registry: Dictionary = {} # UUID -> GachaBallView (for puppet mode)

func set_hp_snapshot(snapshot: Dictionary) -> void:
	# Snapshot of unit_uuid -> hp before simulation. Animator will restore these
	# values before playing events so each event updates the label visibly.
	_hp_snapshot = snapshot.duplicate(true)

func _ready() -> void:
	add_to_group("battle_animator")

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
	
	var battle_view = get_tree().get_first_node_in_group("battle_view")
	
	if is_instance_valid(battle_view):
		# CRITICAL FIX: Filter out equipped items from snapshot
		# Equipped items don't have views in lineups - they're displayed on their holder units
		# Including them in iteration can cause unpredictable behavior due to dictionary iteration order
		print("[BattleAnimator] Populating registry. Snapshot size: ", start_snapshot.size())
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
								gacha_view.set_visual_state(snapshot_data)
								# print("[BattleAnimator] Registered ", uuid, " to view ", gacha_view)
							else:
								print("[BattleAnimator] Failed to register ", uuid, ": Child is not GachaBallView")
						else:
							print("[BattleAnimator] Failed to register ", uuid, ": Slot ", index, " in ", container_tag, " is empty or invalid")
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

	for event in events:
		SignalBus.log_animation_event.emit(event)
		match event.type:
			CombatEvent.Type.LOG_MESSAGE:
				pass # Log messages are instant, no animation to wait for

			CombatEvent.Type.DAMAGE:
				# Emit bump (unless flagged to skip), then flash animation
				# Apply HP delta incrementally so each attack shows its own damage
				var payload = event.visual_payload
				if event.target_uuids.size() > 0:
					var target_uuid := event.target_uuids[0]
					var source_uuid_str := String(event.source_uuid)
					var skip_bump = bool(payload.get("skip_bump", false))
					var amount = int(payload.get("amount", 0))
					# Extract absolute value from payload (Step 1 enhancement)
					var targets_new_hp: Array = payload.get("targets_new_hp", [])
					var new_hp = targets_new_hp[0] if targets_new_hp.size() > 0 else 0
					var should_bump: bool = (not skip_bump) and (not source_uuid_str.is_empty())
					
					if should_bump:
						# Use pre-computed direction from payload if available (new system)
						var bump_dir: Vector2 = payload.get("bump_direction", Vector2.ZERO)
						if bump_dir != Vector2.ZERO:
							SignalBus.emit_signal("unit_bump_attack", event.source_uuid, bump_dir)
						else:
							# Fallback to old method for legacy DAMAGE events without bump_direction
							_emit_bump(event.source_uuid)
						# Wait for half of the bump animation (0.5s)
						await get_tree().create_timer(0.5).timeout
					# Apply HP delta NOW so UI updates incrementally (each attack shows its own damage)
					_apply_hp_delta(target_uuid, amount, new_hp)
					
					# Apply poison if flagged (syncs with damage visual)
					var apply_poison = bool(payload.get("apply_poison", false))
					if apply_poison:
						var targets_new_poison: Array = payload.get("targets_new_poison", [])
						var new_poison = targets_new_poison[0] if targets_new_poison.size() > 0 else 0
						_apply_poison_stack(target_uuid, new_poison)
					
					# Start damage flash while bump (if any) is finishing
					if SignalBus.has_signal("unit_flash_effect"):
						var flash_color = Color(1.0, 0.6, 0.6) # Default red
						if bool(payload.get("is_poison_damage", false)):
							flash_color = Color(0.6, 0.2, 0.8) # Purple for poison
						SignalBus.emit_signal("unit_flash_effect", target_uuid, flash_color)
					# Wait for any bump and then the flash to complete
					if should_bump:
						await _wait_for_animation_completion("bump", event.source_uuid)
					_current_animation_uuid = target_uuid
					await _wait_for_animation_completion("flash", target_uuid)

			CombatEvent.Type.HEAL:
				# HP-only: apply HP delta incrementally with green flash
				var payload = event.visual_payload
				var amount = int(payload.get("amount", 0))
				# Extract absolute values from payload (Step 1 enhancement)
				var targets_new_hp: Array = payload.get("targets_new_hp", [])
				for i in range(event.target_uuids.size()):
					var target_uuid2 = event.target_uuids[i]
					var new_hp = targets_new_hp[i] if i < targets_new_hp.size() else 0
					_current_animation_uuid = target_uuid2
					_apply_hp_delta(target_uuid2, amount, new_hp)
					if SignalBus.has_signal("unit_flash_effect"):
						SignalBus.emit_signal("unit_flash_effect", target_uuid2, Color(0.6, 1.0, 0.6))
						await _wait_for_animation_completion("flash", target_uuid2)

			CombatEvent.Type.BUFF:
				var payload = event.visual_payload
				var amount = int(payload.get("amount", 0))
				var stat = String(payload.get("stat", "pwr")) # Default to pwr for legacy
				
				if stat == "pwr":
					var new_pwr = int(payload.get("new_pwr", 0))
					for target_uuid3 in event.target_uuids:
						_current_animation_uuid = target_uuid3
						_apply_pwr_delta(target_uuid3, amount, new_pwr)
						if SignalBus.has_signal("unit_flash_effect"):
							SignalBus.emit_signal("unit_flash_effect", target_uuid3, Color(1.0, 0.8, 0.4))
							await _wait_for_animation_completion("flash", target_uuid3)
				elif stat == "poison_stacks":
					var new_val = int(payload.get("new_val", 0))
					for target_uuid3 in event.target_uuids:
						_current_animation_uuid = target_uuid3
						_apply_poison_stack(target_uuid3, new_val)
						if SignalBus.has_signal("unit_flash_effect"):
							SignalBus.emit_signal("unit_flash_effect", target_uuid3, Color(0.6, 0.2, 0.8)) # Purple
							await _wait_for_animation_completion("flash", target_uuid3)

			CombatEvent.Type.DEATH:
				# Play death fade on target
				if event.target_uuids.size() > 0:
					var dead_uuid := event.target_uuids[0]
					print("[BattleAnimator] Processing DEATH event for: ", dead_uuid)
					
					# Prevent duplicate death animations for the same unit in this sequence
					if _dead_units.has(dead_uuid):
						print("[BattleAnimator] Skipping duplicate DEATH for: ", dead_uuid)
						continue
						
					_dead_units[dead_uuid] = true
					_current_animation_uuid = dead_uuid
					
					if SignalBus.has_signal("unit_death_fade"):
						print("[BattleAnimator] Emitting unit_death_fade signal for: ", dead_uuid)
						SignalBus.emit_signal("unit_death_fade", dead_uuid)
						print("[BattleAnimator] Waiting for death_fade animation completion...")
						await _wait_for_animation_completion("death_fade", dead_uuid)
						print("[BattleAnimator] Death animation completed for: ", dead_uuid)
					
					# DON'T remove view here! Later events may target this dead unit.
					# _redraw_board() will sync UI to data after all animations complete.
					# The view stays in registry and scene tree for now.

			CombatEvent.Type.SUMMON:
				var payload = event.visual_payload
				var _old_unit_uuid = String(payload.get("old_unit_uuid", "")) # Not used anymore - DEATH handler cleans up
				var new_unit_uuid = String(payload.get("new_unit_uuid", ""))
				var old_location = payload.get("old_unit_location")
				
				# PRESENTATION ONLY: Visual swap of views
				# Container mutations were already done during simulation
				# BattleAnimator should ONLY update the visual layer
				var bm = _get_battle_manager()
				if is_instance_valid(bm) and is_instance_valid(old_location):
					var container_tag = old_location.container
					var index = old_location.index
					
					# Visual swap: Remove old view, create new view
					var battle_view = get_tree().get_first_node_in_group("battle_view")
					if is_instance_valid(battle_view):
						var lineup_container: HBoxContainer = null
						if container_tag == &"PlayerLineup":
							lineup_container = battle_view.player_lineup
						elif container_tag == &"EnemyLineup":
							lineup_container = battle_view.enemy_lineup
						
						if is_instance_valid(lineup_container) and index >= 0 and index < lineup_container.get_child_count():
							var slot_view = lineup_container.get_child(index)
							
							# DON'T clean up old view here - DEATH event will handle that!
							# The old view will be removed by the DEATH handler after its fade animation
							# This prevents premature destruction of stat labels and other child nodes
							
							# Create new view
							var new_view = preload("res://scenes/GachaBallView.tscn").instantiate()
							slot_view.add_child(new_view)
							
							# Use new_unit_snapshot from payload
							var new_snapshot = payload.get("new_unit_snapshot", {})
							if not new_snapshot.is_empty():
								var new_location = LocationIdentifier.new(container_tag, index)
								new_view.populate(new_location, new_snapshot, false, false)
								new_view.set_is_enemy(container_tag == &"EnemyLineup")
								
								_visual_registry[new_unit_uuid] = new_view
								print("[BattleAnimator] Processing SUMMON event for: ", new_unit_uuid)
								
								# Trigger summon animation
								_current_animation_uuid = new_unit_uuid
								if SignalBus.has_signal("unit_summon_fade"):
									print("[BattleAnimator] Emitting unit_summon_fade signal for: ", new_unit_uuid)
									SignalBus.emit_signal("unit_summon_fade", new_unit_uuid)
									print("[BattleAnimator] Waiting for summon_fade animation completion...")
									await _wait_for_animation_completion("summon_fade", new_unit_uuid)
									print("[BattleAnimator] Summon animation completed for: ", new_unit_uuid)

		# Let the UI process the emitted signal this frame
		await get_tree().process_frame
	
	# Disconnect animation signals when done
	_disconnect_animation_signals()
	print("[BattleAnimator] Emitting turn_animation_finished!")
	emit_signal("turn_animation_finished")

func _apply_hp_delta(target_uuid: String, amount: int, new_hp: int) -> void:
	print("[BattleAnimator] _apply_hp_delta called: target_uuid=", target_uuid, " amount=", amount, " new_hp=", new_hp)
	
	# PUPPET MODE: Use visual registry to update view directly
	var view = _visual_registry.get(target_uuid)
	print("[BattleAnimator]   Registry lookup: view_found=", is_instance_valid(view), " is_GachaBallView=", view is GachaBallView if is_instance_valid(view) else false)
	
	if is_instance_valid(view) and view is GachaBallView:
		# Call puppet view's animate method with absolute value
		print("[BattleAnimator]   Calling animate_stat_change on registered view")
		view.animate_stat_change(new_hp, amount, "hp")
	else:
		# DECOUPLED: No fallback - if view not in registry, it's a bug in snapshot processing
		push_error("[BattleAnimator] HP delta target not in visual registry: " + target_uuid)

func _apply_pwr_delta(target_uuid: String, amount: int, new_pwr: int) -> void:
	# PUPPET MODE: Use visual registry to update view directly
	var view = _visual_registry.get(target_uuid)
	if is_instance_valid(view) and view is GachaBallView:
		# Call puppet view's animate method with absolute value
		view.animate_stat_change(new_pwr, amount, "pwr")
	else:
		# DECOUPLED: No fallback - if view not in registry, it's a bug in snapshot processing
		push_error("[BattleAnimator] PWR delta target not in visual registry: " + target_uuid)

func _apply_poison_stack(target_uuid: String, new_stacks: int) -> void:
	print("[BattleAnimator] _apply_poison_stack called for ", target_uuid, " with new_stacks: ", new_stacks)
	# Update visual poison stacks on puppet view
	if _visual_registry.has(target_uuid):
		var view = _visual_registry[target_uuid]
		if is_instance_valid(view) and view is GachaBallView:
			print("[BattleAnimator] Calling view.animate_poison_change")
			view.animate_poison_change(new_stacks)
		else:
			print("[BattleAnimator] View is invalid or not GachaBallView")
	else:
		print("[BattleAnimator] target_uuid not in _visual_registry")

func _emit_bump(_attacker_uuid: String) -> void:
	# LEGACY FALLBACK: This is no longer called since all DAMAGE events
	# now have bump_direction precomputed in their payload (handled at line 121-123).
	# Keeping this as a no-op for compatibility with any legacy code paths.
	# TRUE DECOUPLING: No instance queries needed!
	pass

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
	if not SignalBus.unit_summon_fade_finished.is_connected(_on_unit_summon_fade_finished):
		SignalBus.unit_summon_fade_finished.connect(_on_unit_summon_fade_finished)

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

# Robust animation waiting with timeout fallback
func _wait_for_animation_completion(animation_type: String, expected_uuid: String) -> void:
	var timeout_duration: float
	match animation_type:
		"bump":
			timeout_duration = 1.1 # Bump is 1.0s
		"flash":
			timeout_duration = 1.1 # Flash is 1.0s
		"death_fade":
			timeout_duration = 1.1 # Death fade is 1.0s
		"summon_fade":
			timeout_duration = 1.1 # Summon fade is 1.0s
		_:
			timeout_duration = 1.1 # Default fallback
	
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

func _find_view_for_uuid(uuid: String) -> Node:
	# Scan battle view to find GachaBallView with matching _instance_uuid
	var battle_view = get_tree().get_first_node_in_group("battle_view")
	if not is_instance_valid(battle_view):
		return null
	
	# Check all lineup containers using exposed properties
	var lineups = [
		battle_view.player_lineup,
		battle_view.enemy_lineup,
		battle_view.player_bench
	]
	
	for lineup in lineups:
		if not is_instance_valid(lineup):
			continue
		for slot_view in lineup.get_children():
			if not is_instance_valid(slot_view):
				continue
			for child in slot_view.get_children():
				if child is GachaBallView and child._instance_uuid == uuid:
					return child
	
	return null
