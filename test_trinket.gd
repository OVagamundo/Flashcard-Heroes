extends SceneTree

func _init():
    var db = load("res://scripts/Database.gd").new()
    db._init()
    
    var view = load("res://scripts/GachaBallView.gd").new()
    var visual_data = {
        "uuid": "test-uuid",
        "definition_id": "trinket_trait_fire",
        "category": "TRINKET"
    }
    view.populate(null, visual_data)
    print("Is trait trinket: ", view._is_trait_trinket)
    print("Trait name: ", view._trait_name)
    quit()
