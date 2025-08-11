<!-- Original: scripts/RunState.gd -->

```gdscript

class_name RunState
extends Resource

## Persistent state for a run using the single-source-of-truth data model.

const FlashcardProgress = preload("res://scripts/FlashcardProgress.gd")

@export var gold: int = 0
@export var day: int = 1
@export var hero_instance: GachaBallInstance

# Master registry of all permanent instances in this run.
@export var run_instances: Dictionary = {} # key = uuid (String), value = GachaBallInstance

# Flashcard learning progress - key = card_id (StringName), value = FlashcardProgress
@export var flashcard_progress: Dictionary = {} # key = StringName, value = FlashcardProgress
@export var active_deck_ids: Array[StringName] = [] # Cards available in the mini-game

# All containers indexed by name (e.g., "RunInventoryT1", "PlayerLineup", etc.)
var _containers: Dictionary[StringName, DataContainer] = {}

static var RUN_CONTAINER_TAGS: Dictionary = {
	HERO = &"Hero",
	PLAYER_LINEUP = &"PlayerLineup",
	PLAYER_BENCH = &"PlayerBench",
	PLAYER_ITEM_INVENTORY = &"ItemInventory"
}

# ------------------------------------------------------------------
# Query helpers
# ------------------------------------------------------------------

func get_instance_by_uuid(uuid: String) -> GachaBallInstance:
	return run_instances.get(uuid)

func get_instance_by_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc):
		return null
	var container = get_container(loc.container)
	if not is_instance_valid(container):
		return null
	var uuid = container.get_uuid(loc.index)
	if uuid.is_empty():
		return null
	return get_instance_by_uuid(uuid)

func get_inventory_tier_instances(tier: int) -> Array[GachaBallInstance]:
	var instances: Array[GachaBallInstance] = []
	var container_name = &"RunInventoryT%d" % tier
	var container = get_container(container_name)
	if is_instance_valid(container):
		var uuids = container.get_all_non_empty_uuids()
		for uuid in uuids:
			var instance = get_instance_by_uuid(uuid)
			if is_instance_valid(instance):
				instances.append(instance)
	return instances

func _normalize_container_tag(tag: StringName) -> StringName:
	var s := String(tag)
	if s.begins_with("RUN_INVENTORY_T"):
		var suffix := s.substr(len("RUN_INVENTORY_T"))
		return &"RunInventoryT%s" % suffix
	return tag

func get_all_instances() -> Dictionary:
	return run_instances

func get_run_inventory_containers() -> Dictionary:
	var inventory_data = {}
	for tier in [1, 2, 3]:
		var container_name = &"RunInventoryT%d" % tier
		var container = get_container(container_name)
		if is_instance_valid(container):
			inventory_data[container_name] = container
	return inventory_data

func get_location_for_uuid(uuid: String) -> LocationIdentifier:
	if uuid.is_empty():
		return null
	
	var instance = get_instance_by_uuid(uuid)
	if is_instance_valid(instance):
		return instance.get_location()
	return null

func get_container(container_name: StringName) -> DataContainer:
	# Check if container exists
	if _containers.has(container_name):
		return _containers[container_name]
	
	# Handle standard containers with default sizes if they don't exist yet
	if container_name == RUN_CONTAINER_TAGS.PLAYER_LINEUP or container_name == RUN_CONTAINER_TAGS.PLAYER_BENCH:
		_containers[container_name] = FixedArrayContainer.new(6)
		return _containers[container_name]
	elif container_name == RUN_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY:
		_containers[container_name] = FixedArrayContainer.new(12)
		return _containers[container_name]
	
	return null

# ------------------------------------------------------------------
# Mutation helpers
# ------------------------------------------------------------------

func remove_instance_by_uuid(uuid: String) -> void:
	run_instances.erase(uuid)

# ------------------------------------------------------------------
# Run lifecycle
# ------------------------------------------------------------------

func start_new_run() -> void:
	gold = 5 # Set starting gold
	day = 0
	run_instances.clear()
	_containers.clear()
	flashcard_progress.clear()
	active_deck_ids.clear()

func initialize_run(hero_def_id: StringName, deck_id: StringName) -> void:
	start_new_run()
	
	# Create hero instance from the selected hero definition
	var hero_def = Database.get_definition(hero_def_id)
	if hero_def:
		self.hero_instance = GachaBallInstance.new()
		self.hero_instance.initialize(hero_def)
		self.run_instances[self.hero_instance.ball_uuid] = self.hero_instance
	
	# Initialize flashcard progress for the selected deck
	var deck_card_ids = Database.flashcard_definitions.keys()
	for card_id in deck_card_ids:
		if not flashcard_progress.has(card_id):
			var progress = FlashcardProgress.new()
			flashcard_progress[card_id] = progress
	
	# Populate the initial active deck with the first 10 cards
	var all_card_ids = flashcard_progress.keys()
	for i in range(min(10, all_card_ids.size())):
		active_deck_ids.append(all_card_ids[i])
	
	# Create fresh empty inventory containers for tiers 1-3
	for t in [1, 2, 3]:
		var container_name: StringName = &"RunInventoryT%d" % t
		_containers[container_name] = GrowableGridContainer.new(16)

	# --- Create hero instance ---
	if hero_def:
		# --- Inlined logic from the deleted add_instance function ---
		var hero_container = get_container(RUN_CONTAINER_TAGS.PLAYER_LINEUP)
		var hero_slot = 0 # Hero always goes in the first slot
		
		# 1. Update the Index
		hero_container.set_uuid(hero_slot, hero_instance.ball_uuid)
		# 2. Update the Truth
		hero_instance.location_container_tag = RUN_CONTAINER_TAGS.PLAYER_LINEUP
		hero_instance.location_slot_index = hero_slot
		# 3. Add to master dictionary
		run_instances[hero_instance.ball_uuid] = hero_instance

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
			continue
			
		var inst := GachaBallInstance.new()
		inst.initialize(def)
		
		var container_name: StringName = &"RunInventoryT%d" % def.tier
		
		# --- Inlined logic from the deleted add_instance function ---
		var container = get_container(container_name)
		if not is_instance_valid(container):
			continue
		
		var target_slot = container.find_first_empty_slot()
		
		# 1. Update the Index
		container.set_uuid(target_slot, inst.ball_uuid)
		# 2. Update the Truth
		inst.location_container_tag = container_name
		inst.location_slot_index = target_slot
		# 3. Add to master dictionary
		run_instances[inst.ball_uuid] = inst

```