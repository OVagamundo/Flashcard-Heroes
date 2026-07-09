extends SceneTree
func _init():
    var eff = load("res://resources/effects/Effect_Scald_L3.tres")
    print("Multiplier: ", eff.parameters.get("multiplier"))
    quit()
