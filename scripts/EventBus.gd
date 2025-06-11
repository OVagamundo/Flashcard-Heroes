extends Node

# Game Flow & State
signal new_run_requested(hero_def_id, deck_def_id)
signal run_started
signal run_ended(was_victory)
signal save_run_requested
signal load_run_requested

# Scene Management
signal change_scene_to_file_requested(scene_path)
signal load_scene_in_container_requested(scene_path, container)

# Player State & Resources
signal gold_updated(new_total)
signal hero_hp_updated(current_hp, base_hp)
signal day_updated(new_day)
signal master_pool_changed
signal trinkets_updated(active_trinkets)

# Battle & Turn Management
signal battle_start_requested(encounter_definition)
signal initiate_battle(battle_setup_data)
signal battle_started
signal battle_won
signal battle_lost
signal turn_phase_changed(new_phase)
signal gacha_tokens_updated(new_total)
signal draw_gacha_request(tier)
signal end_turn_button_pressed
signal merge_units_requested(unit_a_uuid, unit_b_uuid)
signal equip_item_requested(item_uuid, target_unit_uuid)

# Ability System Triggers
signal turn_started
signal turn_ended
signal unit_performed_attack(attacker_instance, target_instance)
signal unit_took_damage(attacker_instance, defender_instance, damage_amount)
signal unit_was_merged(merged_unit_instance)
signal unit_defeated(unit_uuid, is_enemy)
signal unit_is_acting(unit_instance)
