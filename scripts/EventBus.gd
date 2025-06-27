# res://scripts/EventBus.gd
extends Node

## A global script containing only signal definitions for the entire game.
## All communication between major systems happens through these signals.

# --- Scene & Run Management Signals ---
signal start_run_requested
signal loadout_scene_requested
signal main_scene_requested
signal battle_start_requested

# --- UI & Modal Signals ---
signal inspect_inventory_requested
signal inspection_requested(source_view: Control) # TDD-aligned signal for any view
signal close_modal_requested
signal display_discard_pile_requested
signal battle_state_changed(is_in_battle: bool)

# --- Player Action & Interaction Signals ---
signal draw_gacha_requested(tier: int)
signal inventory_action_requested(source_view: Control, target_view: Control)
signal choice_made(choice: StringName)
signal reshuffle_discard_pile_requested

# --- View State Signals ---
signal view_selected(view: Control)
signal view_deselected(view: Control)
signal invalid_action_triggered(view: Control)
signal view_data_updated(view: Control)

# Signals have been removed as they were unused
