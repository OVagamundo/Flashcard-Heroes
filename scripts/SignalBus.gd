# res://scripts/SignalBus.gd
extends Node

## Central signal management system for Flashcard Heroes
## Centralized signal bus for all game events
## Replaces the old EventBus system with better organization and documentation
## TDD Section 10.1: SignalBus.gd

# -----------------------------------------------------------------------------
# RUN & SCENE MANAGEMENT SIGNALS
# -----------------------------------------------------------------------------

## Emitted when a new game is requested
signal new_game_requested

## Emitted when a run should start
## @param hero_def_id: StringName - The hero definition ID
## @param deck_id: StringName - The deck ID
signal start_run_requested(hero_def_id: StringName, deck_id: StringName)

## Emitted when loadout scene is requested
signal loadout_scene_requested

## Emitted when main scene is requested
signal main_scene_requested

## Emitted when title scene is requested
signal title_scene_requested

## Emitted when path choice scene is requested
signal path_choice_scene_requested

## Emitted when shop scene is requested
## @param context: Dictionary - Shop context with instances and reroll cost
signal shop_scene_requested(context: Dictionary)

## Emitted when battle scene is requested
## @param encounter_def: EncounterDefinition - The encounter to start
signal battle_scene_requested(encounter_def: EncounterDefinition)

## Emitted when rest site scene is requested
signal rest_site_scene_requested

# Battle events

## Emitted when reward scene is requested
## @param context: Dictionary - Reward context
signal reward_scene_requested(context: Dictionary)


## Emitted when flashcard minigame scene is requested
## @param run_state: RunState - The current run state
## @param active_deck: Array[String] - The active deck IDs
signal flashcard_minigame_requested(run_state: RunState, active_deck: Array[StringName])

## Emitted when battle victory is acknowledged
signal battle_victory_acknowledged

## Emitted when battle won rewards are pending
signal battle_won_rewards_pending

# -----------------------------------------------------------------------------
# BATTLE SYSTEM SIGNALS
# -----------------------------------------------------------------------------

## Emitted when battle starts with encounter definition
## @param encounter_def: EncounterDefinition - The encounter to start
signal battle_start_requested(encounter_def: EncounterDefinition)

## Emitted when battle ends with results
## @param results: Dictionary - Battle results (winner, rewards, etc.)
signal battle_ended(results: Dictionary)

## Emitted when a unit's stats change (HP, PWR, etc.)
## @param unit_uuid: String - The UUID of the unit whose stats changed
signal unit_stats_changed(unit_uuid: String)

## VCR Pattern: Visual stat update for battle animations (doesn't modify logical state)
signal unit_visual_stat_update(unit_uuid: String, new_value: int, delta: int, stat_type: String)

## Triggers a flash effect on a unit with a specific color
## @param unit_uuid: String - The UUID of the unit to flash
## @param flash_color: Color - The color to flash to
signal unit_flash_effect(unit_uuid: String, flash_color: Color)

## Emitted when a unit's flash animation completes
## @param unit_uuid: String - The UUID of the unit that finished flashing
signal unit_flash_finished(unit_uuid: String)

## Emitted to request a short pre-hit "bump" animation from the attacker.
## @param unit_uuid: String - The attacker unit UUID
## @param direction: Vector2 - Screen-space direction to bump (e.g., right for player, left for enemy)
signal unit_bump_attack(unit_uuid: String, direction: Vector2)

## Emitted when a unit's bump animation completes
## @param unit_uuid: String - The UUID of the unit that finished bumping
signal unit_bump_finished(unit_uuid: String)

## Emitted to request a melee lunge animation (unit sprite moves to target)
## @param unit_uuid: String - The attacker unit UUID
## @param target_position: Vector2 - The global position to lunge toward
signal unit_melee_lunge(unit_uuid: String, target_position: Vector2)

## Emitted when a unit's melee lunge animation completes (at target)
## @param unit_uuid: String - The UUID of the unit that finished lunging
signal unit_melee_lunge_finished(unit_uuid: String)

## Emitted to request a fast return animation after melee lunge
## @param unit_uuid: String - The unit UUID to return
signal unit_melee_return(unit_uuid: String)

## Emitted when a unit's melee return animation completes (back at origin)
## @param unit_uuid: String - The UUID of the unit that finished returning
signal unit_melee_return_finished(unit_uuid: String)

## Emitted by the animator after playing death fades so the BattleManager can
## actually remove dead units from containers/registry.
## @param dead_unit_uuids: Array[String] - UUIDs to remove
signal apply_deaths_requested(dead_unit_uuids: Array)

## Request that a unit view plays its death fade animation (visual only).
## The actual removal from data happens via apply_deaths_requested after fade.
signal unit_death_fade(unit_uuid: String)

## Emitted when a unit's death fade animation completes
## @param unit_uuid: String - The UUID of the unit that finished fading
signal unit_death_fade_finished(unit_uuid: String)

## Request screen shake effect
## @param intensity: float - Shake intensity from 0.0 to 1.0 (based on damage dealt)
signal screen_shake_requested(intensity: float)

## Request that a unit view plays its summon fade animation (visual only).
signal unit_summon_fade(unit_uuid: String)
## @param unit_uuid: String - The UUID of the unit that finished fading
signal unit_summon_fade_finished(unit_uuid: String)

## Request that a unit view plays its lethal save animation (Aegis Charm)
## Unit floats up like dying while turning gold, then lands back down to normal
## @param unit_uuid: String - The UUID of the unit that was saved
signal unit_lethal_save(unit_uuid: String)

## Emitted when a unit's lethal save animation completes
## @param unit_uuid: String - The UUID of the unit that finished the save animation
signal unit_lethal_save_finished(unit_uuid: String)

## Emitted when battle inventory changes (units/items added/removed)
signal battle_inventory_changed

## Emitted for each combat animation event (driven by BattleAnimator)
## @param event: CombatEvent - The animation event being played
signal log_animation_event(event: CombatEvent)

## Emitted when battle state changes
## @param is_in_battle: bool - Whether in battle
signal battle_state_changed(is_in_battle: bool)

## Emitted when battle phase changes
## @param phase_name: StringName - The phase name
signal battle_phase_changed(phase_name: StringName)

## Emitted when turn should end
signal end_turn_requested

## Emitted when gacha draw is requested
## @param tier: int - The tier to draw from
signal draw_gacha_requested(tier: int)

## Emitted when gacha tokens change
## @param new_amount: int - The new token amount
signal gacha_tokens_changed(new_amount: int)

# -----------------------------------------------------------------------------
# INVENTORY & LOADOUT SIGNALS
# -----------------------------------------------------------------------------

## Emitted when run data changes (inventory, gold, etc.)
signal run_data_changed

## Emitted when gold amount changes
## @param new_amount: int - The new gold amount
signal gold_changed(new_amount: int)

## Emitted when selection changes
## @param new_location: LocationIdentifier - The newly selected location
signal selection_changed(new_location: LocationIdentifier)

## Emitted when selection should be cleared
signal selection_clear_requested

## Emitted when inventory action is attempted
## @param source_loc: LocationIdentifier - Source location
## @param target_loc: LocationIdentifier - Target location
signal try_inventory_action(source_loc: LocationIdentifier, target_loc: LocationIdentifier)

## Emitted when inventory action is invalid
## @param source_loc: LocationIdentifier - Source location
## @param target_loc: LocationIdentifier - Target location
signal inventory_action_invalid(source_loc: LocationIdentifier, target_loc: LocationIdentifier)

## Emitted when unit inventory changes
## @param unit_uuid: String - The unit UUID
signal unit_inventory_changed(unit_uuid: String)

## Emitted when inventory UI refresh is requested
signal inventory_ui_refresh_requested

# -----------------------------------------------------------------------------
# SHOP SYSTEM SIGNALS
# -----------------------------------------------------------------------------

## Emitted when shop stock should be refreshed
## @param context: Dictionary - Shop context with instances and reroll cost
signal shop_stock_refreshed(context: Dictionary)

## Emitted when a shop purchase is requested
## @param instance_uuid: String - The UUID of the item to purchase
## @param cost: int - The cost of the item
signal shop_purchase_requested(instance_uuid: String, cost: int)

## Emitted when shop reroll is requested
signal shop_reroll_requested

# -----------------------------------------------------------------------------
# REWARD SYSTEM SIGNALS
# -----------------------------------------------------------------------------

## Emitted when a reward is chosen
## @param reward_data: Dictionary - Reward data (type, instance_uuid, amount)
signal reward_chosen(reward_data: Dictionary)

# -----------------------------------------------------------------------------
# INTERACTION SYSTEM SIGNALS
# -----------------------------------------------------------------------------

## Emitted when an InteractionContext is received
## @param context: InteractionContext - The interaction context
signal interaction_context_received(context: InteractionContext)

## Emitted when a choice is made
## @param choice_id: StringName - The choice ID
## @param source_loc: LocationIdentifier - Source location
## @param target_loc: LocationIdentifier - Target location
## @param recipe_id: StringName - The recipe ID
signal choice_made(choice_id: StringName, source_loc: LocationIdentifier, target_loc: LocationIdentifier, recipe_id: StringName)

## Emitted when inspection is requested
## @param loc: LocationIdentifier - Location to inspect
## @param source_view: Control - The source view
signal inspection_requested(loc: LocationIdentifier, source_view: Control)

## Emitted when a view is selected
## @param view: Control - The selected view
## @param location: LocationIdentifier - The location
signal view_selected(view: Control, location: LocationIdentifier)

## Emitted when a view is deselected
## @param view: Control - The deselected view
signal view_deselected(view: Control)

## Emitted when an invalid action is triggered
## @param view: Control - The view that triggered the action
signal invalid_action_triggered(view: Control)

## Emitted when a node is selected
## @param node_def: PathNodeDefinition - The selected node definition
signal node_selected(node_def: PathNodeDefinition)

# -----------------------------------------------------------------------------
# WINDOW MANAGEMENT SIGNALS
# -----------------------------------------------------------------------------

## Emitted when inspection windows should be closed
signal inspection_windows_close_requested

## Emitted when all inspection windows should be closed
signal all_inspection_windows_close_requested

## Emitted when inventory inspection is requested
signal inspect_inventory_requested

## Emitted when discard pile display is requested
signal display_discard_pile_requested

## Emitted when modal should be closed
signal close_modal_requested

## Emitted when the top contextual window should be closed
signal close_top_contextual_requested

## Emitted when background is clicked
signal background_clicked

## Emitted when an ambiguous action requires the player to choose (e.g., Merge or Swap).
## @param context: Dictionary - The context for the ChoiceWindow to populate itself.
signal open_choice_window_requested(context: Dictionary)

# -----------------------------------------------------------------------------
# FLASHCARD SYSTEM SIGNALS
# -----------------------------------------------------------------------------

## Emitted when flashcard minigame ends
## @param results: Dictionary - Minigame results (score, cards reviewed, etc.)
signal flashcard_minigame_completed(results: Dictionary)

## Emitted when flashcard progress is updated
## @param card_id: String - The card ID that was updated
## @param new_progress: FlashcardProgress - The updated progress
signal flashcard_progress_updated(card_id: StringName, new_progress: FlashcardProgress)

## Emitted when results are acknowledged
signal results_acknowledged

# -----------------------------------------------------------------------------
# DEBUG & DEVELOPMENT SIGNALS
# -----------------------------------------------------------------------------

## Emitted for debug logging
## @param message: String - The debug message
## @param level: String - The debug level (INFO, WARNING, ERROR)

## Emitted when game state should be saved

## Emitted when game state should be loaded
