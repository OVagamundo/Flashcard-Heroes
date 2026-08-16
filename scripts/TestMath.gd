extends SceneTree

func _init():
    print("\n--- TEST MATH ---")
    
    var db = preload("res://scripts/core/Database.gd").new()
    var def = GachaBallDefinition.new()
    def.id = &"unit_t1_c"
    def.base_hp = 1
    def.base_pwr = 1
    def.category = &"UNIT"
    
    var parent_a = GachaBallInstance.new()
    parent_a.definition_id = def.id
    parent_a.level = 1
    parent_a.current_hp = 1
    parent_a.current_pwr = 1
    
    var parent_b = GachaBallInstance.new()
    parent_b.definition_id = def.id
    parent_b.level = 1
    parent_b.current_hp = 1
    parent_b.current_pwr = 1
    
    # Simulate Royal Insignia
    parent_a.add_or_update_stat_component(&"trinket_royal_insignia_permanent", &"PERMANENT_BUFF", "trinket_royal_insignia", 1, 1, false, "", "")
    parent_b.add_or_update_stat_component(&"trinket_royal_insignia_permanent", &"PERMANENT_BUFF", "trinket_royal_insignia", 1, 1, false, "", "")
    
    parent_a.current_hp = 2
    parent_a.current_pwr = 2
    parent_b.current_hp = 2
    parent_b.current_pwr = 2
    
    print("Parent A HP: ", parent_a.current_hp, " Persistent: ", parent_a.get_persistent_hp_modifier())
    print("Parent B HP: ", parent_b.current_hp, " Persistent: ", parent_b.get_persistent_hp_modifier())
    
    # Mock Database
    var all_db = {}
    var mm = preload("res://scripts/MergeManager.gd").new()
    
    # We can't fully run calculate_merge_result because it relies on Database singleton
    # Let's just do the math inline:
    var total_hp = def.base_hp + parent_a.get_persistent_hp_modifier() + def.base_hp + parent_b.get_persistent_hp_modifier()
    print("Total HP: ", total_hp)
    
    var base_a = def.base_hp
    var level_bonus_a = parent_a.level - 1
    var base_b = def.base_hp
    var level_bonus_b = parent_b.level - 1
    var extra_hp = total_hp - base_a - level_bonus_a - base_b - level_bonus_b
    print("Extra HP: ", extra_hp)
    
    var final_hp = def.base_hp + level_bonus_a + level_bonus_b + 1 + extra_hp
    print("Final HP (Spawn): ", final_hp)
    
    # Now simulate on_board_enter
    var current_hp = final_hp
    
    # Rusty Ring
    current_hp += 1
    print("After Rusty Ring: ", current_hp)
    
    # Veteran Insignia
    current_hp += 1
    print("After Veteran Insignia: ", current_hp)
    
    print("--- END TEST MATH ---\n")
    quit()
