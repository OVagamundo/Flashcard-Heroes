extends SceneTree

func _init():
    print("Testing Merge Math...")
    # Load base classes
    var db = load("res://scripts/core/Database.gd").new()
    var bm = load("res://scripts/BattleManager.gd").new()
    
    # We can't easily mock the entire DB if it relies on nodes. Let's just create raw GachaBallInstances.
    var parent_a = load("res://scripts/GachaBallInstance.gd").new()
    var parent_b = load("res://scripts/GachaBallInstance.gd").new()
    var merged = load("res://scripts/GachaBallInstance.gd").new()
    
    # Mocking a definition
    var def1 = load("res://scripts/core/GachaBallDefinition.gd").new()
    def1.id = &"unit_t1_c"
    def1.base_hp = 1
    def1.base_pwr = 1
    def1.category = &"UNIT"
    
    var def2 = load("res://scripts/core/GachaBallDefinition.gd").new()
    def2.id = &"unit_t1_c"
    def2.base_hp = 1
    def2.base_pwr = 1
    def2.category = &"UNIT"
    
    parent_a.definition_id = def1.id
    parent_b.definition_id = def1.id
    parent_a.level = 1
    parent_b.level = 1
    
    # We need to manually add components or just mock the values for the test
    print("Test finished.")
    quit()
