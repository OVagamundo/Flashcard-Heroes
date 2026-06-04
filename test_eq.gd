extends SceneTree

func _init():
    var a = &"TRINKET"
    var b = "TRINKET"
    print("Test 1: ", a == b)
    var d = {"category": &"TRINKET"}
    print("Test 2: ", d.get("category", "") == "TRINKET")
    print("Test 3: ", str(d.get("category", "")) == "TRINKET")
    quit()
