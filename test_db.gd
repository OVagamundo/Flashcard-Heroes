extends SceneTree
func _init():
    var tier = 2
    var inventory_tag: StringName = "BattleInventoryT%d" % tier
    print("TAG: ", inventory_tag)
    quit()
