# scripts/BattleAnimator.gd
extends Node

signal turn_animation_finished
signal _sequence_animation_finished(sequence_id: int)

var _dead_units: Dictionary = {} # Track units that have already animated death this turn
var _visual_registry: Dictionary = {} # UUID -> Control (GachaBallView or EnemyBannerView)
var _position_snapshot: Dictionary = {} # UUID -> {position: Vector2, size: Vector2, center: Vector2}
var _start_snapshot: Dictionary = {} # Full starting board snapshot for playback
var _snapshot_store: VisualSnapshotStore = VisualSnapshotStore.new()
var _pending_guardian_return: String = "" # UUID of Guardian needing to return after damage
var _tracker: AnimationCompletionTracker

var _is_playing_sequence: bool = false
var _sequence_queue: Array[Dictionary] = []
var _next_sequence_id: int = 0
var _is_draining_sequence_queue: bool = false
var _is_paused: bool = false


func is_playing_sequence() -> bool:
	return _is_playing_sequence


func is_snapshot_playback_active() -> bool:
	return _is_playing_sequence and _snapshot_store.is_active()


func get_visual_snapshot_store() -> VisualSnapshotStore:
	return _snapshot_store


func is_paused() -> bool:
	return _is_paused


func _ready() -> void:
	add_to_group("battle_animator")
	AnimationRegistry.load_standard_animations()
	_tracker = AnimationCompletionTracker.new(get_tree())
	SignalBus.trait_threshold_reached.connect(_on_trait_threshold_reached)


func play_turn_sequence(start_snapshot: Dictionary, turn_log: Array[CombatEvent]) -> void:
	_next_sequence_id += 1
	var sequence_id: int = _next_sequence_id
	_sequence_queue.append({
		"sequence_id": sequence_id,
		"start_snapshot": start_snapshot.duplicate(true),
		"events": turn_log.duplicate()
	})
	_is_playing_sequence = true
	if not _is_draining_sequence_queue:
		_is_draining_sequence_queue = true
		call_deferred("_drain_sequence_queue")

	while true:
		var completed_sequence_id: int = await _sequence_animation_finished
		if completed_sequence_id == sequence_id:
			return


func _drain_sequence_queue() -> void:
	while not _sequence_queue.is_empty():
		var sequence: Dictionary = _sequence_queue.pop_front()
		var sequence_id: int = sequence["sequence_id"]
		var start_snapshot: Dictionary = sequence["start_snapshot"]
		var turn_log: Array[CombatEvent] = sequence["events"]
		_start_snapshot = start_snapshot
		_snapshot_store.begin_playback(start_snapshot)

		var battle_view: BattleView = get_tree().get_first_node_in_group("battle_view") as BattleView
		if is_instance_valid(battle_view) and start_snapshot.has("__discard_count__"):
			battle_view.init_visual_discard_count(start_snapshot["__discard_count__"])

		_register_all_puppets(start_snapshot)

		await play_turn(turn_log)
		_snapshot_store.end_playback()
		_visual_registry.clear()
		_position_snapshot.clear()
		_start_snapshot.clear()
		_sequence_animation_finished.emit(sequence_id)

	_is_playing_sequence = false
	_is_draining_sequence_queue = false
	turn_animation_finished.emit()


func _register_all_puppets(start_snapshot: Dictionary) -> void:
	BattlePuppetRegistry.register_all_puppets(self, start_snapshot)


func play_turn(events: Array[CombatEvent]) -> void:
	if events.is_empty():
		return
	_dead_units.clear()
	_pending_guardian_return = ""
	await _animate_events(events)


func return_pending_guardian() -> void:
	if _pending_guardian_return.is_empty():
		return
	var guardian_uuid: String = _pending_guardian_return
	_pending_guardian_return = ""
	var guardian_view: GachaBallView = _visual_registry.get(guardian_uuid) as GachaBallView
	if is_instance_valid(guardian_view):
		await guardian_view.animate_leap_return()


static func _has_currency_event(events: Array[CombatEvent], types: Array[CombatEvent.Type]) -> bool:
	for e in events:
		if not is_instance_valid(e):
			continue
		if types.has(e.type):
			return true
		if is_instance_valid(e.visual_payload):
			var p: CombatPayload = e.visual_payload
			if not p.windup_events.is_empty() and _has_currency_event(p.windup_events, types):
				return true
			if not p.pre_impact_events.is_empty() and _has_currency_event(p.pre_impact_events, types):
				return true
			if not p.contact_events.is_empty() and _has_currency_event(p.contact_events, types):
				return true
			if not p.impact_events.is_empty() and _has_currency_event(p.impact_events, types):
				return true
	return false


func _run_registered_animation(anim_name: String, event: CombatEvent, sfx_name: String = "") -> void:
	var anim: BattleAnimation = AnimationRegistry.get_animation(anim_name)
	assert(anim != null, "[BattleAnimator] Animation not found in registry: %s" % anim_name)
	if not sfx_name.is_empty():
		Audio.play_sfx(sfx_name)
	await anim.execute(self, event.target_uuids, event.visual_payload)


func _animate_events(events: Array[CombatEvent]) -> void:
	# Outer brackets keep HUD currency animation counters > 0 until every
	# currency event in the turn finishes animating so desync assertions fire once.
	var currency_main: Node = GameManager._active_main_node if is_instance_valid(GameManager) else null
	var has_gold_events: bool = _has_currency_event(events, [CombatEvent.Type.GOLD_GAIN, CombatEvent.Type.GOLD_SPEND])
	var has_token_events: bool = _has_currency_event(events, [CombatEvent.Type.TOKEN_GAIN, CombatEvent.Type.TOKEN_SPEND])
	var has_timer_events: bool = _has_currency_event(events, [CombatEvent.Type.TIMER_BONUS])

	if has_gold_events and is_instance_valid(currency_main):
		currency_main.begin_gold_animation()
	if has_token_events and is_instance_valid(currency_main):
		currency_main.begin_token_animation()
	if has_timer_events and is_instance_valid(currency_main):
		currency_main.begin_bonus_timer_animation()

	for event in events:
		if event.type == CombatEvent.Type.ACTOR_ORDER:
			continue
		SignalBus.log_animation_event.emit(event)

		BattlePuppetRegistry.play_trinket_activations_for_event(self, event)
		if event.type == CombatEvent.Type.LOG_MESSAGE:
			if not event.trinket_activations.is_empty():
				await AnimationConstants.create_pausable_timer(get_tree(), AnimationConstants.scaled(0.2)).timeout
			continue

		while _is_paused:
			await get_tree().process_frame

		match event.type:
			CombatEvent.Type.LOG_MESSAGE:
				pass

			CombatEvent.Type.DISCARD_EJECT:
				await _run_registered_animation("discard_eject", event)

			CombatEvent.Type.DRAW:
				await BattleBoardEventPresenter.animate_draw(self, event)

			CombatEvent.Type.DAMAGE:
				await _run_registered_animation("damage", event)
				await return_pending_guardian()

			CombatEvent.Type.HEAL:
				await _run_registered_animation("heal", event, "combat_heal")

			CombatEvent.Type.BUFF, CombatEvent.Type.DEBUFF:
				await _run_registered_animation("buff", event, "combat_buff")

			CombatEvent.Type.STATUS_EFFECT:
				await _run_registered_animation("status_effect", event, "combat_buff")

			CombatEvent.Type.KNOCKOUT:
				await _animate_knockout(event)

			CombatEvent.Type.SUMMON:
				await BattleBoardEventPresenter.animate_summon(self, event)

			CombatEvent.Type.PREVENT_KNOCKOUT:
				await _run_registered_animation("lethal_save", event)

			CombatEvent.Type.GUARDIAN_INTERCEPT:
				await _run_registered_animation("guardian_intercept", event)

			CombatEvent.Type.PRE_KNOCKOUT_ATTACK:
				await _run_registered_animation("kamikaze", event)

			CombatEvent.Type.TRANSFORM:
				await _run_registered_animation("transform", event)

			CombatEvent.Type.GOLD_GAIN, CombatEvent.Type.GOLD_SPEND, CombatEvent.Type.TOKEN_GAIN, CombatEvent.Type.TOKEN_SPEND, CombatEvent.Type.TIMER_BONUS:
				var payload: CombatPayload = event.visual_payload
				await BattleBoardEventPresenter.animate_currency_event(self, event.type, payload.origin_uuid, float(payload.amount))

			CombatEvent.Type.MOVE:
				await BattleBoardEventPresenter.animate_incubator_move(self, event)

			CombatEvent.Type.ITEM_TRANSFER:
				var source_uuid: String = event.source_uuid
				var target_uuid: String = event.target_uuids[0] if not event.target_uuids.is_empty() else ""
				if not source_uuid.is_empty() and not target_uuid.is_empty():
					await BattleBoardEventPresenter.animate_item_transfer(self, source_uuid, target_uuid, event.visual_payload)

			CombatEvent.Type.ITEM_DISCARD:
				await BattleBoardEventPresenter.animate_item_discard(self, event.source_uuid, event.visual_payload)

			CombatEvent.Type.ITEM_EQUIP:
				var target_uuid: String = event.target_uuids[0] if not event.target_uuids.is_empty() else event.source_uuid
				await BattleBoardEventPresenter.animate_item_equip(self, target_uuid, event.visual_payload)

			CombatEvent.Type.SLOT_EFFECT_CHANGE:
				var payload: CombatPayload = event.visual_payload
				var slot_view: SlotView = BattlePuppetRegistry.get_slot_view(self, payload.container_tag, payload.slot_index) as SlotView
				if is_instance_valid(slot_view):
					await slot_view.animate_slot_effect_change(payload.to_effect)

			CombatEvent.Type.MERGE:
				var target_uuid: String = event.target_uuids[0] if not event.target_uuids.is_empty() else event.source_uuid
				var target_view: GachaBallView = _visual_registry.get(target_uuid) as GachaBallView
				if is_instance_valid(target_view):
					target_view.play_landing_bounce()
				await AnimationConstants.create_pausable_timer(get_tree(), AnimationConstants.scaled(0.15)).timeout

		_snapshot_store.apply_event(event)
		await get_tree().process_frame

	_is_paused = false

	if has_gold_events and is_instance_valid(currency_main):
		currency_main.end_gold_animation()
	if has_token_events and is_instance_valid(currency_main):
		currency_main.end_token_animation()
	if has_timer_events and is_instance_valid(currency_main):
		currency_main.end_bonus_timer_animation()


func _animate_knockout(event: CombatEvent) -> void:
	if event.target_uuids.is_empty():
		return
	var dead_uuid: String = event.target_uuids[0]
	if _dead_units.has(dead_uuid):
		return
	_dead_units[dead_uuid] = true

	var dead_view: Control = _visual_registry.get(dead_uuid) as Control
	var death_pos: Vector2 = Vector2.ZERO
	if is_instance_valid(dead_view) and dead_view.is_inside_tree():
		death_pos = dead_view.global_position + (dead_view.size / 2.0)
	else:
		var snap: Dictionary = get_snapshot_position(dead_uuid)
		if not snap.is_empty():
			death_pos = snap["center"]

	Audio.play_sfx("combat_death")
	SignalBus.unit_death_fade.emit(dead_uuid, false)
	await wait_for_animation_completion("death_fade", dead_uuid)

	if is_instance_valid(dead_view):
		dead_view.queue_free()
		_visual_registry.erase(dead_uuid)
		await get_tree().process_frame

	await animate_player_death_departure(dead_uuid, death_pos, event.visual_payload)


# =============================================================================
# PUPPET STAT & STATUS DELTA HOOKS (called by BattleAnimation subclasses)
# =============================================================================

func apply_hp_delta(target_uuid: String, amount: int, new_hp: int, trigger_reactions: bool = true) -> void:
	var view: GachaBallView = _visual_registry.get(target_uuid) as GachaBallView
	if is_instance_valid(view):
		view.animate_stat_change(new_hp, amount, "hp", trigger_reactions)


func apply_pwr_delta(target_uuid: String, amount: int, new_pwr: int) -> void:
	var view: GachaBallView = _visual_registry.get(target_uuid) as GachaBallView
	if is_instance_valid(view):
		view.animate_stat_change(new_pwr, amount, "pwr")


func apply_burn_stack(uuid: String, new_stacks: int) -> void:
	var view: GachaBallView = _visual_registry.get(uuid) as GachaBallView
	if is_instance_valid(view):
		view.animate_burn_change(new_stacks)


func apply_armor_stack(uuid: String, new_stacks: int) -> void:
	var view: GachaBallView = _visual_registry.get(uuid) as GachaBallView
	if is_instance_valid(view):
		view.animate_armor_change(new_stacks)


func apply_armor_delta(target_uuid: String, armor_consumed: int, new_armor: int) -> void:
	var view: GachaBallView = _visual_registry.get(target_uuid) as GachaBallView
	if is_instance_valid(view):
		view.animate_armor_stat_change(new_armor, armor_consumed)


func apply_status_stack(uuid: String, status_id: StringName, new_stacks: int) -> void:
	var view: GachaBallView = _visual_registry.get(uuid) as GachaBallView
	if is_instance_valid(view):
		view.animate_status_change(status_id, new_stacks)


func apply_spikes_stack(uuid: String, new_stacks: int) -> void:
	var view: GachaBallView = _visual_registry.get(uuid) as GachaBallView
	if is_instance_valid(view):
		view.animate_status_change(&"spikes", new_stacks)


# =============================================================================
# PUPPET REGISTRY & BOARD EVENT DELEGATES
# =============================================================================

func get_snapshot_position(uuid: String) -> Dictionary:
	return BattlePuppetRegistry.get_snapshot_position(self, uuid)


func get_live_position(uuid: String) -> Dictionary:
	return BattlePuppetRegistry.get_live_position(self, uuid)


func register_dynamic_position(uuid: String, view: Control) -> void:
	BattlePuppetRegistry.register_dynamic_position(self, uuid, view)


func play_trinket_activation(visual_uuid: String, trinket_definition_id: StringName = &"", is_enemy_trinket: bool = false) -> void:
	BattlePuppetRegistry.play_trinket_activation(self, visual_uuid, trinket_definition_id, is_enemy_trinket)


func hop_trinket_by_definition_id(trinket_definition_id: StringName, is_enemy_trinket: bool = false) -> void:
	play_trinket_activation("", trinket_definition_id, is_enemy_trinket)


func hop_trinket_by_visual_uuid(visual_uuid: String, trinket_definition_id: StringName = &"", is_enemy_trinket: bool = false) -> void:
	play_trinket_activation(visual_uuid, trinket_definition_id, is_enemy_trinket)


func animate_player_death_departure(dead_uuid: String, death_pos: Vector2, payload: CombatPayload) -> void:
	await BattleBoardEventPresenter.animate_player_death_departure(self, dead_uuid, death_pos, payload)


# =============================================================================
# ANIMATION COMPLETION TRACKING
# =============================================================================

func wait_for_animation_completion(animation_type: String, expected_uuid: String) -> void:
	if expected_uuid.is_empty() or not _visual_registry.has(expected_uuid):
		return
	var view: Variant = _visual_registry.get(expected_uuid)
	if not is_instance_valid(view):
		return
	var anim_type: AnimationCompletionTracker.AnimationType
	match animation_type:
		"flash":
			anim_type = AnimationCompletionTracker.AnimationType.FLASH
		"color_flash":
			anim_type = AnimationCompletionTracker.AnimationType.COLOR_FLASH
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
			anim_type = AnimationCompletionTracker.AnimationType.PREVENT_KNOCKOUT
		"move":
			anim_type = AnimationCompletionTracker.AnimationType.MOVE
		_:
			anim_type = AnimationCompletionTracker.AnimationType.FLASH

	await _tracker.await_completion(expected_uuid, anim_type)


func wait_for_animation_channels(expected_uuid: String, animation_types: Array[AnimationCompletionTracker.AnimationType]) -> void:
	assert(not expected_uuid.is_empty(), "BattleAnimator.wait_for_animation_channels requires a unit UUID")
	assert(_visual_registry.has(expected_uuid), "BattleAnimator.wait_for_animation_channels requires a registered unit view: %s" % expected_uuid)
	await _tracker.await_completions(expected_uuid, animation_types)


# =============================================================================
# SPEED & PAUSE CONTROL
# =============================================================================

func set_combat_speed(factor: float) -> void:
	AnimationConstants.speed_factor = clampf(factor, 1.0, 4.0)


func get_combat_speed() -> float:
	return AnimationConstants.speed_factor


func _on_trait_threshold_reached(trinket_uuid: String, definition_id: StringName, is_enemy: bool) -> void:
	call_deferred("hop_trinket_by_visual_uuid", trinket_uuid, definition_id, is_enemy)


func pause_combat() -> void:
	_is_paused = true


func play_continuous(speed: float) -> void:
	_is_paused = false
	set_combat_speed(speed)
