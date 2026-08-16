extends SceneTree

func _init():
    print("Running save data fix...")
    var save_path = "user://saves/"
    var dir = DirAccess.open(save_path)
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        var latest_file = ""
        var latest_time = 0
        while file_name != "":
            if not dir.current_is_dir() and file_name.ends_with(".save"):
                var full_path = save_path + file_name
                var modified_time = FileAccess.get_modified_time(full_path)
                if modified_time > latest_time:
                    latest_time = modified_time
                    latest_file = full_path
            file_name = dir.get_next()
            
        if latest_file != "":
            print("Found latest save: " + latest_file)
            var file = FileAccess.open(latest_file, FileAccess.READ)
            if file:
                var content = file.get_as_text()
                file.close()
                var json = JSON.new()
                if json.parse(content) == OK:
                    var data = json.get_data()
                    var instances = data.get("state", {}).get("run_state", {}).get("all_instances", {})
                    var fixed_count = 0
                    for uuid in instances:
                        var inst = instances[uuid]
                        var components = inst.get("components", [])
                        var new_components = []
                        for comp in components:
                            if comp.get("component_id") == "PERMANENT_BUFF":
                                # If it has 2 HP and 2 PWR perm buff, it might be bugged.
                                # Let's just reset all PERMANENT_BUFF to 1/1 if they are Dewey and have 2/2?
                                # Actually, just report them for now to be safe.
                                print("Unit " + uuid + " (" + str(inst.get("definition_id")) + ") has PERM_BUFF: " + str(comp.get("hp_modifier")) + "/" + str(comp.get("pwr_modifier")))
                    print("Save data analysis complete.")
                else:
                    print("Failed to parse JSON")
    else:
        print("No saves dir found.")
    quit()
