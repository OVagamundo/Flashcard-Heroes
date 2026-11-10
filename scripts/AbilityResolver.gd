# res://scripts/AbilityResolver.gd
extends Node

## A stateless service that acts as the central coordinator for the ability system.
## Its primary responsibility is to translate game events into EffectRequests.

const C = preload("res://scripts/Constants.gd")

# =============================================================================
# UNIFIED FILTER SYSTEM
# These helpers centralize trigger-based filtering. BattleManager broadcasts
# ONE event per occurrence; these filters determine which instances respond.
# =============================================================================

## Determine team from instance's container location.
## @param instance: The GachaBallInstance to check
## @param battle_manager: Reference to BattleManager for container tags
## @return "PLAYER", "ENEMY", or "" if unknown
func _get_instance_team(instance: GachaBallInstance, battle_manager: Node) -> String:
	assert(is_instance_valid(instance), "AbilityResolver: instance must be valid")
	var container = instance.location_container_tag
	if container == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or container == C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH:
		return "PLAYER"
	elif container == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP or container == C.BATTLE_CONTAINER_TAGS.ENEMY_BENCH:
		return "ENEMY"
	elif container == C.BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS:
		return "PLAYER"
	elif container == C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS:
		return "ENEMY"
	elif not instance.equipped_on_uuid.is_empty() and battle_manager != null and battle_manager.has_method("get_instance_by_uuid"):
		var parent_unit = battle_manager.get_instance_by_uuid(instance.equipped_on_uuid)
		if is_instance_valid(parent_unit):
			return _get_instance_team(parent_unit, battle_manager)
	return ""

## Unified filter: Should this unit respond to this trigger?
## Called once per unit per trigger broadcast.
## @param trigger: The trigger type being processed
## @param unit_uuid: UUID of the unit being checked
## @param unit: The GachaBallInstance
## @param context: Trigger context with semantic keys
## @param battle_manager: Reference to BattleManager
## @return true if this unit should process abilities for this trigger
func _should_unit_respond(trigger: StringName, unit_uuid: String, unit: GachaBallInstance,
						  context: TriggerContext, battle_manager: Node) -> bool:
	match trigger:
		C.TRIGGER_WHEN_ALLY_KNOCKED_OUT:
			# Unit must be: same team as fainting, alive, not the fainting unit
			var fainting_uuid = context.ally_knocked_out_uuid
			var fainting_team = context.ally_knocked_out_team
			var unit_team = _get_instance_team(unit, battle_manager)
			return unit_team == fainting_team and unit_uuid != fainting_uuid and unit.current_hp > 0
		
		C.TRIGGER_WHEN_TAKING_DAMAGE:
			# Only the unit that received damage responds
			return unit_uuid == context.damaged_uuid
		
		C.TRIGGER_WHEN_KNOCKED_OUT, C.TRIGGER_BEFORE_BEING_KNOCKED_OUT, C.TRIGGER_PREVENT_KNOCKOUT:
			# Only the affected unit responds (allowing current_hp <= 0)
			var target_uuid = context.knocked_out_uuid if not context.knocked_out_uuid.is_empty() else context.damaged_uuid
			return unit_uuid == target_uuid
		
		C.TRIGGER_INTERCEPT_ATTACK:
			# Only the intercepting guardian responds
			return unit_uuid == context.source_uuid
		
		C.TRIGGER_WHEN_ATTACKING, C.TRIGGER_ON_KNOCKOUT_BLOW, C.TRIGGER_ON_DAMAGE_DEALT:
			# Only the attacker responds
			return unit_uuid == context.attacker_uuid
		
		C.TRIGGER_BEFORE_TAKING_DAMAGE:
			# Only the unit about to receive attack damage responds
			return unit_uuid == context.defender_uuid
		
		C.TRIGGER_AT_TURN_START, C.TRIGGER_AT_TURN_END, C.TRIGGER_AT_BATTLE_START, C.TRIGGER_ON_BOARD_STATE_CHANGED, C.TRIGGER_PRE_COMBAT:
			# All living units ON THE BATTLE BOARD respond
			return unit.current_hp > 0 and _is_on_battle_board(unit)
		
		C.TRIGGER_WHEN_ENEMY_SUMMONED:
			# Only units on the OPPOSING team of the summoned unit respond
			var summoned_team = context.summoned_team
			var unit_team = _get_instance_team(unit, battle_manager)
			# Unit must be alive, on the board, and on the opposite team
			return unit.current_hp > 0 and _is_on_battle_board(unit) and unit_team != "" and unit_team != summoned_team
		
		C.TRIGGER_ON_ENTER_BOARD:
			# Only the unit that just entered the board responds
			return unit_uuid == context.entered_uuid
		
		C.TRIGGER_WHEN_ALLY_SUMMONED:
			# Only units on the SAME team as the summoned unit respond
			var summoned_team = context.summoned_team
			var unit_team = _get_instance_team(unit, battle_manager)
			# Unit must be alive, on the board, on the same team, and NOT the summoned unit itself
			var summoned_uuid = context.summoned_uuid
			return unit.current_hp > 0 and _is_on_battle_board(unit) and unit_team != "" and unit_team == summoned_team and unit_uuid != summoned_uuid

		C.TRIGGER_ON_MERGE:
			# Only living units already on battle board (lineup/bench) can respond.
			if unit.current_hp <= 0 or not _is_on_battle_board(unit):
				return false

			# If merge context has a team, only that side responds (Knight-style team scoping).
			var merged_team: String = context.merged_team
			if merged_team.is_empty():
				return true

			var unit_container: StringName = unit.location_container_tag
			var unit_team_on_board: String = ""
			if unit_container == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or unit_container == C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH:
				unit_team_on_board = "PLAYER"
			elif unit_container == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP or unit_container == C.BATTLE_CONTAINER_TAGS.ENEMY_BENCH:
				unit_team_on_board = "ENEMY"
			return unit_team_on_board == merged_team
		
		C.TRIGGER_ON_GACHA_DRAW:
			# Enemy units respond to player draws (draws benefit enemies)
			# AND the drawn unit itself responds (for initialization effects like Merchant)
			var unit_team = _get_instance_team(unit, battle_manager)
			var drawn_uuid = context.drawn_uuid
			
			if unit_uuid == drawn_uuid:
				return true # Self-trigger
				
			return unit.current_hp > 0 and _is_on_battle_board(unit) and unit_team == "ENEMY"
		
		C.TRIGGER_ON_TOKEN_SPENT:
			# Only enemy units respond to player token spending
			var unit_team = _get_instance_team(unit, battle_manager)
			return unit.current_hp > 0 and _is_on_battle_board(unit) and unit_team == "ENEMY"
		
		C.TRIGGER_WHEN_ALLY_TAKES_DAMAGE:
			# Teammates of the hurt unit respond (not the hurt unit itself)
			var damaged_unit_uuid = context.damaged_uuid
			var victim_team = context.damaged_team
			var unit_team = _get_instance_team(unit, battle_manager)
			# Must be alive, same team as victim, not the victim itself
			return unit.current_hp > 0 and unit_team == victim_team and unit_uuid != damaged_unit_uuid
		
		C.TRIGGER_WHEN_HEALED:
			# Only the healed unit itself responds to its own healing
			var healed_uuid = context.healed_uuid if not context.healed_uuid.is_empty() else context.unit_uuid
			return unit.current_hp > 0 and unit_uuid == healed_uuid
		
		C.TRIGGER_ON_GACHA_TOKENS_CHANGED:
			# All living units respond to token changes
			return unit.current_hp > 0 and _is_on_battle_board(unit)
			
		C.TRIGGER_WHEN_ANY_UNIT_KNOCKED_OUT:
			# All living units respond to any unit death
			return unit.current_hp > 0 and _is_on_battle_board(unit)
			
		C.TRIGGER_ON_GOLD_EARNED, C.TRIGGER_ON_GOLD_SPENT, C.TRIGGER_AT_MINIGAME_END, C.TRIGGER_BEFORE_MINIGAME:
			# Living units respond if in active lineup (AMer does not trigger while benched)
			var container: StringName = unit.location_container_tag
			return unit.current_hp > 0 and (
				container == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or
				container == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
			)
			
		C.TRIGGER_ON_STAT_INCREASED, C.TRIGGER_ON_STAT_DECREASED:
			# Units respond if they are on the battle board and alive
			# Loop Prevention: Do not respond if this unit caused the stat modification
			var target_uuid = context.unit_uuid
			var source_uuid = context.source_uuid
			
			if unit.current_hp <= 0 or not _is_on_battle_board(unit):
				return false
				
			if not source_uuid.is_empty() and unit_uuid == source_uuid:
				return false
				
			# The unit whose stat changed always responds (self-trigger)
			if unit_uuid == target_uuid:
				return true
				
			# Living allies on the same team also respond (e.g. team reaction abilities)
			var target_inst = battle_manager.get_instance_by_uuid(target_uuid)
			if is_instance_valid(target_inst):
				var target_team = _get_instance_team(target_inst, battle_manager)
				var unit_team = _get_instance_team(unit, battle_manager)
				return unit_team == target_team
				
			return false
	
	# Default: respond (for any new triggers)
	return true

## Determine if a unit is on the battle board (lineup or bench)
func _is_on_battle_board(unit: GachaBallInstance) -> bool:
	if not is_instance_valid(unit):
		return false
	var container: StringName = unit.location_container_tag
	return (
		container == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
		or container == C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH
		or container == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
		or container == C.BATTLE_CONTAINER_TAGS.ENEMY_BENCH
	)

## Unified filter: Should this equipped item respond to this trigger?
## @param trigger: The trigger type being processed
## @param item: The equipped item instance
## @param context: Trigger context with semantic keys
## @return true if this item should process abilities for this trigger
func _should_item_respond(trigger: StringName, item: GachaBallInstance, context: TriggerContext) -> bool:
	# Items can always respond to on_board_state_changed to update their passive stats, even on the bench
	if trigger == C.TRIGGER_ON_BOARD_STATE_CHANGED:
		return true

	var holder_uuid = item.equipped_on_uuid
	assert(not holder_uuid.is_empty(), "AbilityResolver: item must be equipped to respond to combat triggers")
	
	match trigger:
		C.TRIGGER_WHEN_TAKING_DAMAGE:
			return holder_uuid == context.damaged_uuid
		
		C.TRIGGER_WHEN_KNOCKED_OUT, C.TRIGGER_BEFORE_BEING_KNOCKED_OUT, C.TRIGGER_PREVENT_KNOCKOUT:
			var target_uuid = context.knocked_out_uuid if not context.knocked_out_uuid.is_empty() else context.damaged_uuid
			return holder_uuid == target_uuid
		
		C.TRIGGER_WHEN_ATTACKING, C.TRIGGER_ON_KNOCKOUT_BLOW, C.TRIGGER_ON_DAMAGE_DEALT:
			return holder_uuid == context.attacker_uuid
		
		C.TRIGGER_BEFORE_TAKING_DAMAGE:
			return holder_uuid == context.defender_uuid
		
		C.TRIGGER_WHEN_ALLY_KNOCKED_OUT:
			# Items on living allies respond (not on the dying unit)
			var fainting_uuid = context.ally_knocked_out_uuid
			return holder_uuid != fainting_uuid
		
		C.TRIGGER_AT_TURN_START, C.TRIGGER_AT_TURN_END, C.TRIGGER_AT_BATTLE_START, C.TRIGGER_ON_BOARD_STATE_CHANGED, C.TRIGGER_PRE_COMBAT, C.TRIGGER_ON_GOLD_EARNED, C.TRIGGER_ON_GOLD_SPENT, C.TRIGGER_AT_MINIGAME_END, C.TRIGGER_BEFORE_MINIGAME:
			# All equipped items on living holders respond
			return true
		
		C.TRIGGER_ON_GACHA_DRAW:
			# Items don't respond to on_draw - only trinkets do
			return false
		
		C.TRIGGER_WHEN_HEALED:
			var healed_uuid = context.healed_uuid if not context.healed_uuid.is_empty() else context.unit_uuid
			return holder_uuid == healed_uuid
		
		C.TRIGGER_ON_STAT_INCREASED, C.TRIGGER_ON_STAT_DECREASED:
			var target_uuid = context.unit_uuid
			return holder_uuid == target_uuid
	
	return true

## Unified filter: Should this trinket respond to this trigger?
## @param trigger: The trigger type being processed
## @param trinket: The trinket instance
## @param context: Trigger context with semantic keys
## @param battle_manager: Reference to BattleManager
## @return true if this trinket should process abilities for this trigger
func _should_trinket_respond(trigger: StringName, trinket: GachaBallInstance,
							 context: TriggerContext, battle_manager: Node) -> bool:
	var trinket_team = _get_instance_team(trinket, battle_manager)
	var trinket_def = trinket.get_definition()
	var trinket_name = trinket_def.name_key if is_instance_valid(trinket_def) else "Unknown"
	
	match trigger:
		C.TRIGGER_WHEN_ALLY_KNOCKED_OUT:
			# Trinkets only respond to deaths on their own team
			var fainting_team = context.ally_knocked_out_team
			return trinket_team == fainting_team
		
		C.TRIGGER_PREVENT_KNOCKOUT:
			var target_team = context.damaged_team
			return trinket_team == target_team
		
		C.TRIGGER_AT_TURN_START, C.TRIGGER_AT_TURN_END, C.TRIGGER_AT_BATTLE_START, C.TRIGGER_ON_BOARD_STATE_CHANGED, C.TRIGGER_PRE_COMBAT, C.TRIGGER_ON_GOLD_EARNED, C.TRIGGER_ON_GOLD_SPENT, C.TRIGGER_AT_MINIGAME_END, C.TRIGGER_BEFORE_MINIGAME:
			# All trinkets respond
			return true
		
		C.TRIGGER_ON_GACHA_DRAW:
			# Only player trinkets respond to player draws
			# (enemies don't draw, so this is always player team for now)
			return trinket_team == "PLAYER"
		
		C.TRIGGER_ON_MERGE:
			# Trinkets only respond to merges on their own team
			var merged_team = context.merged_team
			return trinket_team == merged_team
		
		C.TRIGGER_WHEN_ALLY_SUMMONED:
			# Trinkets only respond to ally summons on their own team
			var summoned_team = context.summoned_team
			return trinket_team == summoned_team
		
		C.TRIGGER_ON_STAT_INCREASED, C.TRIGGER_ON_STAT_DECREASED:
			var target_uuid = context.unit_uuid
			var target_inst = battle_manager.get_instance_by_uuid(target_uuid)
			if is_instance_valid(target_inst):
				return trinket_team == _get_instance_team(target_inst, battle_manager)
			return true
	
	# For other triggers, trinkets respond based on team context if available
	return true

# =============================================================================
# MAIN TRIGGER PROCESSING
# =============================================================================

## Process a trigger event and generate EffectRequests for all matching abilities.
##
## UNIFIED BROADCAST PATTERN: BattleManager calls this ONCE per event.
## AbilityResolver self-filters to determine which instances respond.
##
## Ordering contract (docs/AbilitySystem.md):
## 1) Units first
## 2) Equipped Items second (sorted by slot index)
## 3) Trinkets last
##
## @param trigger: StringName - The trigger type (e.g., "on_attack", "on_death")
## @param context: TriggerContext - The context with semantic properties (e.g., damaged_uuid, attacker_uuid)
func process_trigger(trigger: StringName, context: TriggerContext = null) -> void:
	if context == null:
		context = TriggerContext.new()
	# Add trigger_type to context so it flows through to CombatEvents
	context.trigger_type = trigger
	if is_instance_valid(GameManager.run_state):
		context.gold_tens = int(GameManager.run_state.gold / 10)
	else:
		context.gold_tens = 0
	
	# Get the current BattleManager
	var battle_manager = GameManager.get_battle_manager()
	if not is_instance_valid(battle_manager):
		battle_manager = get_tree().get_first_node_in_group("battle_manager")
	assert(is_instance_valid(battle_manager), "AbilityResolver: BattleManager not found")

	# Optimization: Single pass to bucket all instances by category
	var all_instances = battle_manager.get_all_instances()
	
	var unit_instances: Array[Dictionary] = []
	var equipped_item_instances: Array[Dictionary] = []
	var trinket_instances: Array[Dictionary] = []

	for instance_uuid in all_instances:
		var instance = all_instances.get(instance_uuid)
		if not is_instance_valid(instance):
			continue
		var definition = instance.get_definition()
		if not is_instance_valid(definition) or not ("category" in definition):
			continue

		if definition.category == &"UNIT":
			unit_instances.append({"uuid": instance_uuid, "inst": instance, "def": definition})
		elif definition.category == &"ITEM":
			# Skip unequipped items unless it's a passive stat update trigger
			if instance.equipped_on_uuid.is_empty() and trigger != C.TRIGGER_ON_BOARD_STATE_CHANGED:
				continue
				
			# Use unified filter to check if item should respond
			if not _should_item_respond(trigger, instance, context):
				continue
			# Check if item has matching ability for this trigger
			var has_matching = false
			for entry in instance.get_active_ability_entries(all_instances):
				var ability: AbilityDefinition = entry.get("ability_def")
				if not is_instance_valid(ability):
					continue
				if ability.trigger == trigger:
					has_matching = true
					break
			if has_matching:
				equipped_item_instances.append({
					"instance_uuid": instance_uuid,
					"instance": instance,
					"definition": definition,
					"slot_index": instance.equipped_slot_index
				})
		elif definition.category == &"TRINKET":
			trinket_instances.append({"uuid": instance_uuid, "inst": instance, "def": definition})

	# Phase 1: Process unit abilities
	for data in unit_instances:
		var instance_uuid: String = data.uuid
		var instance: GachaBallInstance = data.inst
		var definition = data.def
		
		# Use unified filter
		if not _should_unit_respond(trigger, instance_uuid, instance, context, battle_manager):
			continue

		# Process all abilities from the component system (definition + injected + persistent)
		for entry in instance.get_active_ability_entries(all_instances):
			if entry.get("source_type") == &"EQUIPMENT":
				continue
			var ability: AbilityDefinition = entry.get("ability_def")
			if not is_instance_valid(ability):
				continue
			if ability.trigger == trigger or (ability.trigger == C.TRIGGER_ON_GACHA_TOKENS_CHANGED and (trigger == C.TRIGGER_ON_ENTER_BOARD or trigger == C.TRIGGER_ON_BOARD_STATE_CHANGED)):
				_process_ability(ability, entry.get("source_instance_uuid", instance_uuid), battle_manager, context)


	# Phase 2: Process equipped item abilities (sorted by slot for deterministic order)
	equipped_item_instances.sort_custom(func(a, b): return a.slot_index < b.slot_index)
	
	for item_data in equipped_item_instances:
		var instance_uuid: String = item_data.instance_uuid
		var item_instance: GachaBallInstance = item_data.instance

		for entry in item_instance.get_active_ability_entries(all_instances):
			var ability: AbilityDefinition = entry.get("ability_def")
			if not is_instance_valid(ability):
				continue
			if ability.trigger == trigger:
				_process_ability(ability, entry.get("source_instance_uuid", instance_uuid), battle_manager, context)

	# Phase 3: Process trinket abilities
	for data in trinket_instances:
		var instance_uuid: String = data.uuid
		var instance: GachaBallInstance = data.inst
		var definition = data.def
		
		# Use unified filter
		if not _should_trinket_respond(trigger, instance, context, battle_manager):
			continue
		
		# Add trinket's team to context for effects that need it
		var trinket_team = _get_instance_team(instance, battle_manager)
		var trinket_context: TriggerContext = context.duplicate_context()
		trinket_context.team = trinket_team
		
		for entry in instance.get_active_ability_entries(all_instances):
			var ability: AbilityDefinition = entry.get("ability_def")
			if not is_instance_valid(ability):
				continue
			if ability.trigger == trigger:
				# Trinkets are team-based, not unit-based. The trinket itself is the source.
				# This avoids dead-unit edge cases and is semantically correct.
				_process_ability(ability, entry.get("source_instance_uuid", instance_uuid), battle_manager, trinket_context)


## Process a single ability and create EffectRequests for its effects.
## @param source_uuid: String - The UUID of the source instance
## @param battle_manager: Node - The current battle manager
func _process_ability(ability: AbilityDefinition, source_uuid: String, battle_manager: Node, context: TriggerContext) -> void:
	var source = null
	# Check if source is dead and ability doesn't allow lethal execution
	# ONLY for UNITS - items and trinkets don't have HP
	if not source_uuid.is_empty():
		source = battle_manager.get_instance_by_uuid(source_uuid)
		if is_instance_valid(source):
			var source_def = source.get_definition()
			# Only check HP for UNIT category - items/trinkets don't have meaningful HP
			if is_instance_valid(source_def) and source_def.category == &"UNIT":
				if source.current_hp <= 0:
					# Allow if this is the dying unit's own knockout trigger
					var ko_uuid: String = context.knocked_out_uuid
					var is_own_death_trigger: bool = (not ko_uuid.is_empty() and ko_uuid == source_uuid)
					if not is_own_death_trigger and not ability.execute_before_knockout:
						return
	
	# Check condition if present
	if is_instance_valid(ability.condition):
		var condition_result = battle_manager.check_condition(ability.condition, source_uuid, context)
		if not condition_result:
			return # Condition failed, skip this ability
	
	var category: StringName = &""
	var is_player: bool = false
	var slot_index: int = -1
	var sub_index: int = 0
	if is_instance_valid(source):
		var source_def = source.get_definition()
		if is_instance_valid(source_def) and ("category" in source_def):
			category = source_def.category
		if battle_manager.has_method("_is_player_owned"):
			is_player = battle_manager._is_player_owned(source)
		elif battle_manager.has_method("_is_player_unit"):
			is_player = battle_manager._is_player_unit(source)
		
		if not source.equipped_on_uuid.is_empty():
			var holder = battle_manager.get_instance_by_uuid(source.equipped_on_uuid)
			if is_instance_valid(holder):
				slot_index = holder.location_slot_index
				if battle_manager.has_method("_is_player_owned"):
					is_player = battle_manager._is_player_owned(holder)
			sub_index = source.equipped_slot_index
		else:
			slot_index = source.location_slot_index
	
	var ability_activated := false
	
	# Process each effect in the ability
	for effect in ability.effects:
		if not is_instance_valid(effect):
			continue
		
		# Resolve targets for this effect
		var resolved_targets: Array[String] = battle_manager.resolve_target(source_uuid, effect.target_type, context)
		
		# If we found valid targets, mark ability as activated
		if not resolved_targets.is_empty():
			ability_activated = true
		
		# Create EffectRequest
		# For counter-attack abilities, mark the context to identify counter-attack effects
		var effect_context: TriggerContext = context.duplicate_context()
		if ability.replaces_basic_attack:
			effect_context.on_attack_already_triggered = true
		if ability.id.contains("counter"):
			effect_context.is_counter = true
		
		var effect_request = EffectRequest.new(
			source_uuid,
			ability.id,
			effect,
			resolved_targets,
			effect_context,
			ability.sub_phase,
			category,
			is_player,
			slot_index,
			sub_index
		)
		
		# Enqueue the request
		battle_manager.enqueue_effect_request(effect_request)

	# If ability successfully activated (found targets) AND it replaces basic attack, set flag
	# This ensures we fallback to basic attack if the special ability fails to find a target (e.g. empty mirror slot)
	if ability_activated and ability.replaces_basic_attack and context.trigger_type == C.TRIGGER_WHEN_ATTACKING:
		context.attack_replaced = true
