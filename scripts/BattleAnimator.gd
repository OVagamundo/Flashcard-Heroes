# scripts/BattleAnimator.gd
extends Node

signal turn_animation_finished

const TURN_STEP_DELAY = 0.8 # The original delay from BattleManager
const PRE_HIT_DELAY = 0.12 # Short delay so bump precedes damage application
const DEATH_FADE_DURATION = 0.3 # Duration for death fade before removal

var _hp_snapshot: Dictionary = {}

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
	for event in events:
		match event.type:
			CombatEvent.Type.LOG_MESSAGE:
				SignalBus.emit_signal("battle_log_event", event.text)

			CombatEvent.Type.DAMAGE:
				# Pre-hit: small attacker bump toward the opponent, then apply damage
				if event.target_uuids.size() > 0:
					var target_uuid := event.target_uuids[0]
					_emit_bump(event.source_uuid)
					await get_tree().create_timer(PRE_HIT_DELAY).timeout
					_apply_hp_delta(target_uuid, event.amount)
					if SignalBus.has_signal("unit_flash_effect"):
						# Use a light red tint for damage; pure white can be invisible on default themes
						SignalBus.emit_signal("unit_flash_effect", target_uuid, Color(1.0, 0.6, 0.6))

			CombatEvent.Type.HEAL:
				# Apply numeric HP delta and update UI in sync with flash
				if event.target_uuids.size() > 0:
					var target_uuid2 := event.target_uuids[0]
					_apply_hp_delta(target_uuid2, event.amount)
					if SignalBus.has_signal("unit_flash_effect"):
						SignalBus.emit_signal("unit_flash_effect", target_uuid2, Color(0.6, 1.0, 0.6))

			CombatEvent.Type.INVENTORY_SYNC:
				# This triggers the removal of the dead unit's view from the UI.
				SignalBus.emit_signal("battle_inventory_changed")

			CombatEvent.Type.DEATH:
				# Play death fade on target, then request removal
				if event.target_uuids.size() > 0:
					var dead_uuid := event.target_uuids[0]
					if SignalBus.has_signal("unit_death_fade"):
						SignalBus.emit_signal("unit_death_fade", dead_uuid)
					# Wait for fade to complete, then request data removal
					await get_tree().create_timer(DEATH_FADE_DURATION).timeout
					if SignalBus.has_signal("apply_deaths_requested"):
						SignalBus.emit_signal("apply_deaths_requested", [dead_uuid])

		# Let the UI process the emitted signal this frame, then wait for the step delay.
		await get_tree().process_frame
		await get_tree().create_timer(TURN_STEP_DELAY).timeout
		
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
