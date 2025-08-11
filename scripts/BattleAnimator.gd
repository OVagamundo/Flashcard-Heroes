# scripts/BattleAnimator.gd
extends Node

signal turn_animation_finished

const TURN_STEP_DELAY = 0.8 # The original delay from BattleManager

func _ready():
	add_to_group("battle_animator")

func play_turn(events: Array[CombatEvent]):
	if events.is_empty():
		emit_signal("turn_animation_finished")
		return
	await _animate_events(events)

func _animate_events(events: Array[CombatEvent]):
	for event in events:
		match event.type:
			CombatEvent.Type.LOG_MESSAGE:
				SignalBus.emit_signal("battle_log_event", event.text)

			CombatEvent.Type.DAMAGE:
				# The animator's only job for damage is to trigger the UI stat label update.
				if event.target_uuids.size() > 0:
					SignalBus.emit_signal("unit_stats_changed", event.target_uuids[0])

			CombatEvent.Type.INVENTORY_SYNC:
				# This triggers the removal of the dead unit's view from the UI.
				SignalBus.emit_signal("battle_inventory_changed")

		# Let the UI process the emitted signal this frame, then wait for the step delay.
		await get_tree().process_frame
		await get_tree().create_timer(TURN_STEP_DELAY).timeout
		
	emit_signal("turn_animation_finished")
