# res://scripts/EventBus.gd
extends Node

## A global script containing only signal definitions for the entire game.
## All communication between major systems happens through these signals.

# --- Scene & Run Management Signals ---
signal start_run_requested
signal loadout_scene_requested
signal main_scene_requested
signal battle_start_requested
signal game_over

# --- UI & Modal Signals ---
signal inspect_inventory_requested
signal display_discard_pile_requested
signal inspection_requested(source_view: Control) # Correct generic signal
signal close_modal_requested

# --- State Change Signals ---
signal battle_state_changed(is_in_battle: bool)
signal run_inventory_changed
signal battle_inventory_changed # New signal for battle UI refresh

# --- Player Action & Interaction Signals ---
signal draw_gacha_requested(tier: int)
signal inventory_action_requested(source_view: Control, target_view: Control)
signal choice_made(choice_id: StringName)
signal reshuffle_discard_pile_requested

# --- View State Signals ---
signal view_selected(view: Control)
signal view_deselected(view: Control)
signal invalid_action_triggered(view: Control) # BUGFIX: This signal was missing.

# Signals have been removed as they were unused
