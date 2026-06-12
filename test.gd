extends SceneTree
func _init():
    print("Testing string format...")
    var s = "Get Tokens! ({cost} Gold)".format({"cost": "123"})
    print("Result: ", s)
    quit()
