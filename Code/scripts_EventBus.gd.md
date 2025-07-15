<!-- Original: scripts/EventBus.gd -->

```gdscript
# res://scripts/EventBus.gd
extends Node # EventBus for Flashcard Heroes

const LocationIdentifier = preload("res://scripts/LocationIdentifier.gd")

## A global script containing only signal definitions for the entire game.
## All communication between major systems happens through these signals.

# --- Run/Scene Signals ---
signal new_game_requested
signal start_run_requested
signal loadout_scene_requested
signal main_scene_requested
signal path_choice_scene_requested
signal battle_scene_requested
signal battle_start_requested
signal title_scene_requested

# --- Window/Modal Signals ---
signal inspect_inventory_requested
signal display_discard_pile_requested
signal close_modal_requested
signal background_clicked # For modal background blockers
signal global_background_clicked # For main content area background

# --- Action Signals ---
signal draw_gacha_requested(tier: int)
signal inventory_action_requested(source_loc: LocationIdentifier, target_loc: LocationIdentifier)
signal choice_made(choice_id: StringName, source_loc: LocationIdentifier, target_loc: LocationIdentifier)
signal inspection_requested(loc: LocationIdentifier, source_view: Control)
signal end_turn_requested

# --- Selection Signals ---
signal view_selected(view: Control, location: LocationIdentifier)
signal view_deselected(view: Control)
signal invalid_action_triggered(view: Control)
signal selection_changed(new_location: LocationIdentifier)

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

```