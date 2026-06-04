extends SceneTree
func _init():
    var gm = load("res://scripts/GameManager.gd").new()
    gm._ready()
    gm._on_start_run_requested(&"hero_timekeeper", &"deck_test")
    var has_charm = gm.has_trinket(&"trinket_beginners_charm")
    var db = load("res://scripts/Database.gd").new()
    db._ready()
    print("DB loaded trinkets: ", db.trinkets.keys())
    print("Has Charm: ", has_charm)
    var uids = []
    if gm.run_state:
        var cont = gm.run_state.get_container(gm.run_state.RUN_CONTAINER_TAGS.PLAYER_TRINKETS)
        if cont:
            for uid in cont.get_all_non_empty_uuids():
                var inst = gm.run_state.get_instance_by_uuid(uid)
                if inst:
                    var def = inst.get_definition()
                    if def:
                        uids.append(def.id)
    print("RunState trinkets: ", uids)
    quit()
