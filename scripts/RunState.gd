# File: res://scripts/Core/RunState.gd
extends Node

# The player's hero for the run
var hero_instance: GachaBallInstance = null

# The player's collection of GachaBalls for this run, organized by tier.
# This is the "Master Run Gacha Pool" from the GDD.
var master_run_pool = {
    1: [], # Array of GachaBallInstances
    2: [],
    3: []
}

# This will hold temporary copies of our gachaballs for the current battle
var battle_gacha_pools = {
    1: [],
    2: [],
    3: []
}

# Call this at the start of a new game to initialize the player's state
func start_new_run(hero_definition: GachaBallDefinition, starting_gachaballs: Array[GachaBallDefinition]):
    # 1. Create an instance for our hero from its definition
    hero_instance = GachaBallInstance.new(hero_definition)

    # 2. Clear any old pool data to ensure a fresh start
    master_run_pool = { 1: [], 2: [], 3: [] }

    # 3. Populate the master pool with the hero's starting set of gachaballs
    for definition in starting_gachaballs:
        var new_instance = GachaBallInstance.new(definition)
        if master_run_pool.has(new_instance.definition.tier):
            master_run_pool[new_instance.definition.tier].append(new_instance)

    print("New run started! Hero: ", hero_instance.get_display_name())
    print("Master Pool Tier 1 has ", master_run_pool[1].size(), " units.")


# Call this at the start of every battle to create temporary, drawable pools
func create_battle_pools():
    # Clear out old battle pools from any previous combat
    battle_gacha_pools = { 1: [], 2: [], 3: [] }

    # Create deep copies for the battle so we don't affect the master pool.
    # This ensures the player starts each battle with their full collection available to be drawn.
    for tier in master_run_pool:
        for instance_in_master_pool in master_run_pool[tier]:
            # The create_battle_copy() method is used to create a fresh, independent copy for combat.
            var battle_copy = instance_in_master_pool.create_battle_copy()
            battle_gacha_pools[tier].append(battle_copy)
    
    print("Battle pools created for combat!")
