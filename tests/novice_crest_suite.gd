extends Node

const C = preload("res://scripts/Constants.gd")
const BattleManagerScript = preload("res://scripts/BattleManager.gd")

var bm: BattleManagerScript
var checks: int = 0
var failures: int = 0

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _reset(tokens: int) -> void:
	bm._state = BattleState.new()
	bm._combat = CombatSimulator.new()
	GameManager.run_state = RunState.new()
	GameManager.run_state.gold = 10
	GameManager.run_state.current_room_tokens = tokens

func _add(id: StringName, container: StringName) -> GachaBallInstance:
	var unit := GachaBallInstance.new()
	var definition: Resource = Database.get_definition(id)
	if definition is TrinketDefinition:
		unit.initialize_from_trinket(definition)
	else:
		unit.initialize(definition)
	assert(bm._state.bm_add_instance(unit, container), "Test placement failed: %s" % id)
	return unit

func _trigger() -> Array[CombatEvent]:
	var context := TriggerContext.new()
	context.is_simulation = true
	AbilityResolver.process_trigger(C.TRIGGER_PRE_COMBAT, context)
	return bm._combat.process_reaction_queue(bm, {})

func _test_thresholds() -> void:
	for count: int in range(1, 6):
		for tokens: int in [0, 1, 2, 5, 14]:
			_reset(tokens)
			var crest: GachaBallInstance = _add(&"trinket_trait_novice", &"PlayerTrinkets")
			var novices: Array[GachaBallInstance] = []
			for i: int in range(count):
				novices.append(_add(&"?NovPla", &"PlayerLineup"))
			var shelf: GachaBallInstance = _add(&"?NovPla", &"PlayerShelf")
			var enemy: GachaBallInstance = _add(&"?NovPla", &"EnemyLineup")
			var other: GachaBallInstance
			if count < 5:
				other = _add(&"ETnkPla", &"PlayerLineup")
			var events: Array[CombatEvent] = _trigger()
			var pairs: int = int(tokens / 2)
			var gold_gain: int = pairs if count >= 3 else 0
			var armor_gain: int = pairs if count >= 4 else 0
			var spikes_gain: int = pairs if count >= 5 else 0
			var label: String = "%d Novices / %d Tokens" % [count, tokens]
			_check(GameManager.run_state.gold == 10 + gold_gain, label + ": cumulative Gold")
			_check(bm.get_gacha_tokens() == tokens, label + ": rewards do not spend Tokens")
			_check(is_equal_approx(bm.get_total_next_minigame_bonus_time(), 1.0 if count >= 2 else 0.0), label + ": cumulative Challenge time")
			for novice: GachaBallInstance in novices:
				_check(novice.get_status_effect_amount(&"armor") == armor_gain, label + ": Novice Armor")
				_check(novice.get_status_effect_amount(&"spikes") == spikes_gain, label + ": Novice Spikes")
			_check(shelf.get_status_effect_amount(&"armor") == 0 and shelf.get_status_effect_amount(&"spikes") == 0, label + ": Shelf excluded")
			_check(enemy.get_status_effect_amount(&"armor") == 0 and enemy.get_status_effect_amount(&"spikes") == 0, label + ": enemy excluded")
			if count < 5:
				_check(other.get_status_effect_amount(&"armor") == 0 and other.get_status_effect_amount(&"spikes") == 0, label + ": other traits excluded")
			var gold_events: int = 0
			var status_events: int = 0
			for event: CombatEvent in events:
				if event.type == CombatEvent.Type.GOLD_GAIN:
					gold_events += event.visual_payload.amount
					_check(event.source_uuid == crest.ball_uuid, label + ": Gold originates at Crest")
				if event.type == CombatEvent.Type.STATUS_EFFECT:
					status_events += 1
					_check(event.source_uuid == crest.ball_uuid and event.target_uuids.size() == count, label + ": shared status event targets")
			_check(gold_events == gold_gain, label + ": full Gold event coverage")
			_check(status_events == (int(armor_gain > 0) + int(spikes_gain > 0)), label + ": distinct Armor and Spikes events")
			_trigger()
			_check(GameManager.run_state.gold == 10 + gold_gain * 2, label + ": rewards recur at each Pre-Battle")

func _test_crest_gate_and_gold_reactions() -> void:
	_reset(5)
	for i: int in range(4):
		_add(&"?NovPla", &"PlayerLineup")
	var mercenary: GachaBallInstance = _add(&"?MerSpe", &"PlayerLineup")
	var hp_before: int = mercenary.current_hp
	_check(_trigger().is_empty(), "No Crest means no Novice rewards")
	_check(GameManager.run_state.gold == 10, "No Crest means no Gold")
	_add(&"trinket_trait_novice", &"PlayerTrinkets")
	_trigger()
	_check(mercenary.current_hp == hp_before + 2, "Each Gold earned triggers the existing active Mercenary ability")
	_check(mercenary.get_status_effect_amount(&"armor") == 0, "Gold-reacting non-Novice receives no Crest Armor")
	var item := GachaBallInstance.new()
	item.initialize(Database.items[&"item_novice_emblem"])
	assert(InventoryOperations.register_and_equip_item(bm._state, item, mercenary.ball_uuid).success)
	_check(int(bm.get_active_traits("PLAYER")["NOVICE"]) == 5, "Novice Emblem uses shared trait counting")
	_trigger()
	_check(mercenary.get_status_effect_amount(&"armor") == 2 and mercenary.get_status_effect_amount(&"spikes") == 2, "Novice Emblem holder receives both Crest effects")

func _test_prebattle_order() -> void:
	_reset(4)
	_add(&"trinket_trait_novice", &"PlayerTrinkets")
	var galebloom: GachaBallInstance = _add(&"E??ANovPla", &"PlayerLineup")
	var novice: GachaBallInstance = _add(&"?NovPla", &"PlayerLineup")
	_add(&"?NovPla", &"PlayerLineup")
	_add(&"?NovPla", &"PlayerLineup")
	_trigger()
	_check(bm.get_gacha_tokens() == 3, "Shared Pre-Battle order lets Galebloom spend before the Crest")
	_check(GameManager.run_state.gold == 11, "Crest uses the remaining 3 Tokens after earlier Pre-Battle spending")
	_check(galebloom.get_status_effect_amount(&"armor") == 5, "Crest Armor stacks through the same path as Galebloom Armor")
	_check(novice.get_status_effect_amount(&"armor") == 1, "All Crest rewards use the same Token pair count")

func _test_challenge_rewards() -> void:
	_reset(0)
	var run: RunState = RunState.new()
	run.initialize_run(&"hero_starter", &"deck_nihongo_starter")
	run.unlock_next_deck_card()
	GameManager.run_state = run
	GameManager.is_in_battle = true
	_add(&"trinket_trait_novice", &"PlayerTrinkets")
	for i: int in range(5):
		_add(&"?NovPla", &"PlayerLineup")
	FlashcardManager.reset_session_state()
	FlashcardManager._run_state_ref = run
	FlashcardManager._active_deck_ids = run.active_deck_ids.duplicate()
	FlashcardManager.is_session_active = true
	FlashcardManager.session_timer = 7.0
	FlashcardManager.has_unlocked_midgame_card = true
	var gold_before: int = run.gold
	for i: int in range(3):
		var card_id: StringName = run.active_deck_ids[i]
		run.flashcard_progress[card_id].mastery_level = 1
		var answer: Dictionary = FlashcardManager.submit_minigame_answer(card_id, card_id)
		_check(answer.tokens_to_give == 1 and answer.gold_to_give == 0, "Novice Crest no longer awards answer/streak Token or Gold bonuses")
	_check(run.gold == gold_before, "Streak does not award old Crest Gold")
	var timer_before: float = FlashcardManager.session_timer
	FlashcardManager.submit_minigame_answer(run.active_deck_ids[0], run.active_deck_ids[1])
	_check(is_equal_approx(FlashcardManager.session_timer, timer_before), "Incorrect answer does not award old Crest extra time")
	FlashcardManager.reset_session_state()

func _run() -> void:
	RNGManager.initialize(73410)
	bm = BattleManagerScript.new()
	add_child(bm)
	_test_thresholds()
	_test_crest_gate_and_gold_reactions()
	_test_prebattle_order()
	_test_challenge_rewards()
	bm.free()
	print("Novice Crest suite: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
