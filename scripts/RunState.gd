
class_name RunState
extends Resource

## Persistent state for a run using the single-source-of-truth data model.

@export var gold: int = 0
@export var hero_instance: GachaBallInstance

# Master registry of all permanent instances in this run.
@export var run_instances: Dictionary = {} # key = uuid (String), value = GachaBallInstance

# Inventory containers indexed by name (e.g., "RunInventoryT1").
var run_inventory_containers: Dictionary = {} # key = StringName, value = DataContainer
# Additional containers (lineup, bench, etc.) cached here
var _other_containers: Dictionary = {}

static var RUN_CONTAINER_TAGS: Dictionary = {
	HERO = &"Hero",
	LINEUP = &"Lineup",
	BENCH = &"Bench",
	ITEM_INVENTORY = &"ItemInventory",
	STARTER_PACK = &"StarterPack"
}

# ------------------------------------------------------------------
# Query helpers
# ------------------------------------------------------------------

func get_instance_by_uuid(uuid: String) -> GachaBallInstance:
    return run_instances.get(uuid)

func _normalize_container_tag(tag: StringName) -> StringName:
    var s := String(tag)
    if s.begins_with("RUN_INVENTORY_T"):
        var suffix := s.substr(len("RUN_INVENTORY_T"))
        return &"RunInventoryT%s" % suffix
    return tag

func get_instances_in_container(container_tag: StringName) -> Array[GachaBallInstance]:
    var norm_tag := _normalize_container_tag(container_tag)
    var results: Array[GachaBallInstance] = []
    for instance in run_instances.values():
        var inst_tag := _normalize_container_tag(instance.location_container_tag)
        if inst_tag == norm_tag:
            results.append(instance)
    results.sort_custom(func(a, b): return a.location_slot_index < b.location_slot_index)
    return results

func get_all_instances() -> Dictionary:
    return run_instances

# Internal helper to backfill container UUIDs from run_instances
func _ensure_container_populated(container_name: StringName, container: DataContainer):
    if container == null:
        return
    for inst in run_instances.values():
        var inst_tag := _normalize_container_tag(inst.location_container_tag)
        var target_tag := _normalize_container_tag(container_name)
        if inst_tag == target_tag:
            var idx: int = inst.location_slot_index
            if idx >= 0:
                # Resize if needed
                var fixed = container as FixedArrayContainer
                if fixed != null and idx >= fixed._data.size():
                    fixed._data.resize(idx + 1)
                    while fixed._data.size() < idx + 1:
                        fixed._data.append("")
                if container.get_uuid(idx).is_empty():
                    container.set_uuid(idx, inst.ball_uuid)

# Returns the instance located at the given LocationIdentifier (tier/index/container)
func get_instance_by_location(loc: LocationIdentifier) -> GachaBallInstance:
    if not is_instance_valid(loc):
        return null

    # Special case: equipped item slots on a unit
    if loc.container == &"equipped_item":
        var parent_uuid: String = loc.unit_uuid
        if parent_uuid.is_empty():
            return null
        var parent_inst: GachaBallInstance = get_instance_by_uuid(parent_uuid)
        if not is_instance_valid(parent_inst):
            return null
        if loc.index >= 0 and loc.index < parent_inst.equipped_item_uuids.size():
            var item_uuid: String = parent_inst.equipped_item_uuids[loc.index]
            if item_uuid.is_empty():
                return null
            return get_instance_by_uuid(item_uuid)
        return null

    var container := get_container(loc.container)
    if container == null:
        return null
    var uuid := container.get_uuid(loc.index)
    if uuid.is_empty():
        return null
    return get_instance_by_uuid(uuid)

func get_container(container_name: StringName) -> DataContainer:
    # 1. Inventory containers (tiered storage)
    if run_inventory_containers.has(container_name):
        var existing = run_inventory_containers[container_name]
        _ensure_container_populated(container_name, existing)
        return existing

    var cname := String(container_name)

    # Alias support: handle legacy uppercase "RUN_INVENTORY_T#" names.
    if cname.begins_with("RUN_INVENTORY_T"):
        var tier_str := cname.substr(len("RUN_INVENTORY_T"))
        var official_name := "RunInventoryT%s" % tier_str
        # Recursively fetch the official container (this will create it if needed)
        return get_container(official_name)

    if cname.begins_with("RunInventoryT"):
        var c := preload("res://scripts/FixedArrayContainer.gd").new(16)
        run_inventory_containers[container_name] = c
        return c

    # 2. Other permanent run containers (lineup, bench, item inventory, hero)
    if _other_containers.has(container_name):
        var ex = _other_containers[container_name]
        _ensure_container_populated(container_name, ex)
        return ex

    var default_size := 1
    if container_name == RUN_CONTAINER_TAGS.LINEUP or container_name == RUN_CONTAINER_TAGS.BENCH:
        default_size = 3
    elif container_name == RUN_CONTAINER_TAGS.ITEM_INVENTORY:
        default_size = 3

    # Lazily create misc container
    var new_c := preload("res://scripts/FixedArrayContainer.gd").new(default_size)
    _other_containers[container_name] = new_c
    _ensure_container_populated(container_name, new_c)
    return new_c

# ------------------------------------------------------------------
# Mutation helpers
# ------------------------------------------------------------------

func add_instance(instance: GachaBallInstance) -> bool:
    if not is_instance_valid(instance):
        return false

    var def: GachaBallDefinition = instance.get_definition()
    if not is_instance_valid(def):
        return false

    var container_tag: StringName = StringName("RunInventoryT%d" % def.tier)

    # Determine first free slot in the target container.
    var occupied: Array[int] = []
    for other in get_instances_in_container(container_tag):
        occupied.append(other.location_slot_index)

    var slot_index := 0
    while slot_index in occupied:
        slot_index += 1

    # Ensure container exists
    var container = get_container(container_tag)
    if container == null:
        return false

    instance.location_container_tag = container_tag
    instance.location_slot_index = slot_index

    run_instances[instance.ball_uuid] = instance
    # Record uuid in container
    container.set_uuid(slot_index, instance.ball_uuid)
    return true

func remove_instance_by_uuid(uuid: String) -> void:
    run_instances.erase(uuid)

# ------------------------------------------------------------------
# Run lifecycle
# ------------------------------------------------------------------

func start_new_run() -> void:
    gold = 10
    run_instances.clear()
    run_inventory_containers.clear()
    # Create fresh empty inventory containers for tiers 1-3
    for t in [1,2,3]:
        var name := StringName("RunInventoryT%d" % t)
        run_inventory_containers[name] = preload("res://scripts/FixedArrayContainer.gd").new(16)

    # --- Create hero instance ---
    var hero_def: GachaBallDefinition = Database.get_definition(&"hero")
    if hero_def:
        hero_instance = GachaBallInstance.new()
        hero_instance.initialize(hero_def)
        # Manually place hero in the lineup and register it.
        hero_instance.location_container_tag = RUN_CONTAINER_TAGS.LINEUP
        hero_instance.location_slot_index = 0
        run_instances[hero_instance.ball_uuid] = hero_instance
    else:
        printerr("RunState: CRITICAL – could not find hero definition in Database.")

    # --- Add starter units/items to inventory ---
    var starters: Array[StringName] = [
        &"unit_t1_a", &"unit_t1_a", &"unit_t1_b", &"unit_t1_b",
        &"item_t1_a", &"item_t1_a", &"item_t1_b", &"item_t1_b",
        &"unit_t2_c", &"unit_t2_c", &"item_t2_c", &"item_t2_c",
        &"unit_t3_d", &"unit_t3_d", &"item_t3_d", &"item_t3_d"
    ]

    for id in starters:
        var def: GachaBallDefinition = Database.get_definition(id)
        if not def:
            printerr("RunState: Missing definition '%s' while starting new run." % id)
            continue
        var inst := GachaBallInstance.new()
        inst.initialize(def)
        if not add_instance(inst):
            printerr("RunState: Failed to add starter instance '%s'." % id)

    # New run initialized
