# res://scripts/SignalBus.gd
extends Node

## Central signal management system for Flashcard Heroes
## Centralized signal bus for all game events
## Replaces the old EventBus system with better organization and documentation
## TDD Section 10.1: SignalBus.gd

# -----------------------------------------------------------------------------
# RUN & SCENE MANAGEMENT SIGNALS
# -----------------------------------------------------------------------------

## Emitted when a run should start
## @param hero_def_id: StringName - The hero definition ID
## @param deck_id: StringName - The deck ID
## @param deck_order: String - The order to add cards ("REGULAR", "INVERTED", "RANDOM")
## @param deck_size: String - The size of the deck to use ("FULL", "HALF")
signal start_run_requested(hero_def_id: StringName, deck_id: StringName, deck_order: String, deck_size: String)

## Emitted after a run has reached its initial path-map state or a saved run resumes.
## metadata contains the original loadout/options needed by replay headers.
signal run_initialized(run_state: RunState, metadata: Dictionary, continuing: bool)

## Emitted before GameManager clears the current run when returning to Title.
signal run_ending(reason: String)

## Emitted when loadout scene is requested
signal loadout_scene_requested

## Emitted when main scene is requested
signal main_scene_requested

## Emitted when title scene is requested
signal title_scene_requested

## Emitted when path choice scene is requested
signal path_choice_scene_requested

# Battle events

## Emitted when reward scene is requested
## @param context: Dictionary - Reward context
signal reward_scene_requested(context: Dictionary)

## Emitted when battle victory is acknowledged
signal battle_victory_acknowledged

## Emitted when battle won rewards are pending
signal battle_won_rewards_pending

## Emitted when a trait trinket's threshold level changes (up or down).
## Used to trigger its activation hop animation via BattleAnimator.
signal trait_threshold_reached(trinket_uuid: String, definition_id: StringName, is_enemy: bool)

# -----------------------------------------------------------------------------
# BATTLE SYSTEM SIGNALS
# -----------------------------------------------------------------------------

## Emitted when battle ends with results
## @param results: Dictionary - Battle results (winner, rewards, etc.)
signal battle_ended(results: Dictionary)

## Emitted when combat playback speed multiplier changes (1.0, 2.0, 4.0).
signal combat_speed_changed(speed: float)

## Emitted when combat is paused or resumed.
signal combat_pause_changed(is_paused: bool)


## Emitted when a specific stat on a unit changes (HP, PWR, armor_stacks, burn_stacks, etc.)
## Granular signal that specifies WHICH stat changed - handlers update only that stat
## @param unit_uuid: String - The UUID of the unit whose stat changed
## @param stat_name: StringName - The name of the stat (&"hp", &"pwr", &"armor_stacks", &"burn_stacks")
## @param old_value: int - The previous value
## @param new_value: int - The new value
signal unit_stat_changed(unit_uuid: String, stat_name: StringName, old_value: int, new_value: int)

## Emitted when a unit's flash animation completes
## @param unit_uuid: String - The UUID of the unit that finished flashing
signal unit_flash_finished(unit_uuid: String)

# -----------------------------------------------------------------------------
# COMPOSABLE ANIMATION EFFECTS (Independent parallel effects)
# -----------------------------------------------------------------------------

## Color flash effect - shader-based color tint that fades over time
## @param unit_uuid: String - The UUID of the unit to flash
## @param flash_color: Color - The color to flash
## @param duration: float - How long the flash should fade
signal unit_color_flash(unit_uuid: String, flash_color: Color, duration: float)

## Emitted when color flash completes
signal unit_color_flash_finished(unit_uuid: String)

## Deformation effect - squish/stretch on icon scale
## @param unit_uuid: String - The UUID of the unit
## @param deform_type: StringName - Type: "SQUISH_BOUNCE", "STRETCH_BOUNCE", "HIT_IMPACT", "HOP_DEFORM"
signal unit_deform(unit_uuid: String, deform_type: StringName)

## Emitted when deformation completes
signal unit_deform_finished(unit_uuid: String)

## Movement effect - position animation
## @param unit_uuid: String - The UUID of the unit
## @param move_type: StringName - Type: "HOP", "RECOIL", "BUMP"
## @param direction: Vector2 - Direction for directional moves (e.g., recoil direction)
signal unit_move(unit_uuid: String, move_type: StringName, direction: Vector2)

## Emitted when movement completes
signal unit_move_finished(unit_uuid: String)

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

## Request that a unit view plays its death fade animation (visual only).
signal unit_death_fade(unit_uuid: String, stay_in_place: bool)

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

# -----------------------------------------------------------------------------
# BATTLE INVENTORY TRANSITION SIGNALS
# -----------------------------------------------------------------------------

## Emitted when the battle inventory starts its open/close animation
## @param is_opening: bool - True if opening, False if closing
signal battle_inventory_transition_started(is_opening: bool)

## Emitted when the battle inventory finishes its animation
signal battle_inventory_transition_finished

## Emitted for each combat animation event (driven by BattleAnimator)
## @param event: CombatEvent - The animation event being played
signal log_animation_event(event: CombatEvent)

## Emitted when battle state changes
## @param snapshot: Dictionary - Board snapshot
signal management_animation_requested(snapshot: Dictionary)

## Emitted when battle state changes
## @param is_in_battle: bool - Whether in battle
signal battle_state_changed(is_in_battle: bool)

## Emitted when battle phase changes
## @param phase_name: StringName - The phase name
signal battle_phase_changed(phase_name: StringName)

## Emitted when turn should end
signal end_turn_requested

## Visual completion of a draw, before the VCR releases input.
signal gacha_draw_animation_completed(draw_result: InventoryOperations.DrawResult)

## Emitted when gacha tokens change (canonical signal for both logic and UI presentation)
## @param new_amount: int - The new token amount
signal gacha_tokens_changed(new_amount: int)

## Emitted when the shrine receives a user action (remove or transform)
## @param payload: Dictionary containing 'type', 'instance_uuid', etc.
signal shrine_action_requested(payload: Dictionary)

## Emitted when BattleManager wants the UI to play the battle entry animation
signal battle_entry_animation_requested()

## Emitted by BattleView when the battle entry animation has finished
signal battle_entry_animation_finished()

# -----------------------------------------------------------------------------
# INVENTORY & LOADOUT SIGNALS
# -----------------------------------------------------------------------------

## Emitted when an item overflows a physics container lid for 5 consecutive seconds

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

## Emitted after a successful inventory action (move/swap/merge/equip) for bounce animation
## @param target_uuids: Array[String] - UUIDs of instances that were affected and should bounce
signal inventory_action_completed(target_uuids: Array)

## Emitted after a merge's data mutations are complete.
## The animation layer uses this to orchestrate the visual merge sequence.
## @param context: Dictionary - Contains all data the animator needs
signal merge_animation_requested(context: Dictionary)

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
# SLOT INDICATOR SIGNALS
# -----------------------------------------------------------------------------

## Emitted to show indicators on valid drop target slots
## @param locations: Array[LocationIdentifier] - The valid target locations to highlight
signal show_slot_indicators(locations: Array)

## Emitted to hide all slot indicators
signal hide_slot_indicators

## Emitted to show merge highlight outlines on target gachaballs
## @param merge_targets: Dictionary - Key: uuid (String), Value: merge_type (StringName: &"LEVEL_UP" or &"RECIPE_TIER_UP")
signal show_merge_target_indicators(merge_targets: Dictionary)

## Emitted to clear merge highlight outlines from all target gachaballs
signal hide_merge_target_indicators

## Emitted when a drag operation starts (for slot indicators)
## @param origin_context: InteractionContext - The dragged item's context
signal drag_started(origin_context: InteractionContext)

## Emitted when a drag operation ends
## @param was_handled: bool - Whether the drop was handled
signal drag_ended(was_handled: bool)

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

## Emitted when reward stock should be refreshed
## @param context: Dictionary - Reward context with instances and reroll cost
signal reward_stock_refreshed(context: Dictionary)

## Emitted when reward reroll is requested
signal reward_reroll_requested

## Emitted when the confirm drop zone overlay is activated (clicked or drop received)
## Used by Reward and Shop scenes to trigger confirm/buy actions
signal confirm_drop_zone_activated(is_drag: bool, mouse_position: Vector2)

# Split Action Drop Zone signals (Used by Shrine, Unit Training, etc.)
signal action_drop_zone_1_activated(is_drag: bool, mouse_position: Vector2)
signal action_drop_zone_2_activated(is_drag: bool, mouse_position: Vector2)

# Reward Scene signals
## Emitted when the collect zone is activated
## @param is_drag: bool - Whether the activation was via drag-and-drop
## @param mouse_position: Vector2 - The screen position of the mouse at activation
signal reward_collect_zone_activated(is_drag: bool, mouse_position: Vector2)

## Emitted when the sell zone is activated
## @param is_drag: bool - Whether the activation was via drag-and-drop
## @param mouse_position: Vector2 - The screen position of the mouse at activation
signal reward_sell_zone_activated(is_drag: bool, mouse_position: Vector2)


# -----------------------------------------------------------------------------
# INTERACTION SYSTEM SIGNALS
# -----------------------------------------------------------------------------

## Emitted when an InteractionContext is received
## @param context: InteractionContext - The interaction context
signal interaction_context_received(context: InteractionContext)

## Emitted when a view is selected
## @param view: Control - The selected view
## @param location: LocationIdentifier - The location
signal view_selected(view: Control, location: LocationIdentifier)

## Emitted when a view is deselected
## @param view: Control - The deselected view
signal view_deselected(view: Control)

## Emitted when an entity's inspection panel starts or stops using this source.
signal view_inspection_changed(view: Control, active: bool)

## Emitted when a node is selected
## @param node_def: PathNodeDefinition - The selected node definition
signal node_selected(node_def: PathNodeDefinition)

## Emitted when an interaction lock is requested (e.g., by a modal prompt)
## @param locked: bool - Whether to lock inspection/hover interactions
signal interaction_lock_requested(locked: bool)

# -----------------------------------------------------------------------------
# WINDOW MANAGEMENT SIGNALS
# -----------------------------------------------------------------------------

## Emitted when modal should be closed
signal close_modal_requested

## Emitted when the glossary details lock is toggled on/off
signal glossary_lock_changed(is_locked: bool)

## Emitted when background is clicked
signal background_clicked

# -----------------------------------------------------------------------------
# FLASHCARD SYSTEM SIGNALS
# -----------------------------------------------------------------------------

## Emitted when results are acknowledged
signal results_acknowledged

## Emitted when bonus time for the next minigame changes
## @param new_bonus_time: float - The new banked bonus time in seconds
signal minigame_bonus_time_changed(new_bonus_time: float)


# -----------------------------------------------------------------------------
# DEBUG & DEVELOPMENT SIGNALS
# -----------------------------------------------------------------------------

## Emitted for debug logging
## @param message: String - The debug message
## @param level: String - The debug level (INFO, WARNING, ERROR)

## Emitted when game state should be saved

## Emitted when game state should be loaded

# -----------------------------------------------------------------------------
# TUTORIAL SYSTEM SIGNALS
# -----------------------------------------------------------------------------

## Emitted when a tutorial popup should be shown
## @param tutorial_id: StringName - Unique identifier for the tutorial
## @param pages: Array - Array of page dictionaries with text and optional anchor_path
## @param anchor: Control - Optional control to point an arrow at
signal tutorial_requested(tutorial_id: StringName, pages: Array, anchor: Control)

## Emitted when a tutorial takes or releases ownership of the scene-tree pause
signal tutorial_pause_changed(tutorial_id: StringName, is_paused: bool)

## Emitted when a tutorial is dismissed (completed)
## @param tutorial_id: StringName - The tutorial that was dismissed
signal tutorial_dismissed(tutorial_id: StringName)

# -----------------------------------------------------------------------------
# LOCALIZATION SIGNALS
# -----------------------------------------------------------------------------

## Emitted when the game locale changes
signal locale_changed
