# res://scripts/EventBus.gd
extends Node # EventBus for Flashcard Heroes

const LocationIdentifier = preload("res://scripts/LocationIdentifier.gd")
const EncounterDefinition = preload("res://scripts/data/EncounterDefinition.gd")

## A global script containing only signal definitions for the entire game.
## All communication between major systems happens through these signals.

# --- Run/Scene Signals ---
signal new_game_requested
signal start_run_requested(hero_def_id: StringName, deck_id: StringName)
signal loadout_scene_requested
signal main_scene_requested
signal path_choice_scene_requested
signal battle_scene_requested
signal battle_start_requested(encounter_def: EncounterDefinition)
signal title_scene_requested
signal reward_scene_requested(context)
signal battle_victory_acknowledged
signal reward_chosen(payload)

# --- Window/Modal Signals ---
signal inspect_inventory_requested
signal display_discard_pile_requested
signal close_modal_requested
signal background_clicked # For modal background blockers

signal gold_changed(new_amount: int)

# --- Shop Signals ---
signal shop_scene_requested(context: Dictionary)
signal shop_purchase_requested(instance_uuid: String, cost: int)
signal shop_reroll_requested
signal shop_stock_refreshed(context: Dictionary)

# --- Path/Node Signals ---
signal node_selected(node_def: PathNodeDefinition)

# --- Action Signals ---
signal draw_gacha_requested(tier: int)
signal inventory_action_requested(source_loc: LocationIdentifier, target_loc: LocationIdentifier)
signal choice_made(choice_id: StringName, source_loc: LocationIdentifier, target_loc: LocationIdentifier, recipe_id: StringName)
signal inspection_requested(loc: LocationIdentifier, source_view: Control)
signal end_turn_requested

# --- Selection Signals ---
signal view_selected(view: Control, location: LocationIdentifier)
signal view_deselected(view: Control)
signal invalid_action_triggered(view: Control)
signal selection_changed(new_location: LocationIdentifier)
signal selection_clear_requested

# --- State Change Signals ---
signal run_state_changed
signal battle_inventory_changed
signal run_data_changed
signal battle_state_changed(is_in_battle: bool)
signal battle_phase_changed(phase_name: StringName)
signal gacha_tokens_changed(new_amount: int)
signal unit_stats_changed(unit_uuid: String)
signal unit_inventory_changed(unit_uuid: String)
signal battle_log_event(message: String)
signal inventory_ui_refresh_requested

# --- Flashcard Signals ---
signal flashcard_minigame_completed(results: Dictionary)
signal results_acknowledged
