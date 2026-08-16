extends SceneTree

func _init():
    print("Testing Merge Math...")
    var db = preload("res://scripts/core/Database.gd").new()
    # Wait, Database is an autoload. We might need to run this as a proper scene or just mock the definitions.
    print("Test finished.")
    quit()
