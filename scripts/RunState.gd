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

    # Populate battle_gacha_pools with references from master_run_pool and update their location state.
    for tier_key in master_run_pool:
        for instance_in_master_pool in master_run_pool[tier_key]:
            # Only move instances that are currently in one of the master run pool states for that tier
            var target_battle_pool_state = -1
            var expected_master_pool_state = -1

            match tier_key:
                1:
                    expected_master_pool_state = GachaBallInstance.LocationState.IN_MASTER_RUN_POOL_TIER_1
                    target_battle_pool_state = GachaBallInstance.LocationState.IN_BATTLE_GACHA_POOL_TIER_1
                2:
                    expected_master_pool_state = GachaBallInstance.LocationState.IN_MASTER_RUN_POOL_TIER_2
                    target_battle_pool_state = GachaBallInstance.LocationState.IN_BATTLE_GACHA_POOL_TIER_2
                3:
                    expected_master_pool_state = GachaBallInstance.LocationState.IN_MASTER_RUN_POOL_TIER_3
                    target_battle_pool_state = GachaBallInstance.LocationState.IN_BATTLE_GACHA_POOL_TIER_3
            
            if instance_in_master_pool.current_location_state == expected_master_pool_state and target_battle_pool_state != -1:
                battle_gacha_pools[tier_key].append(instance_in_master_pool) # Add reference
                instance_in_master_pool.set_location_state(target_battle_pool_state) # Update state
            elif instance_in_master_pool.current_location_state == GachaBallInstance.LocationState.IN_BATTLE_DISCARD_PILE:
                # TDD: "After a successful draw, check if the battle pool for that tier is empty. 
                # If so, call a private method to reshuffle all matching-tier instances from 
                # the _battle_discard_pile back into the battle pool."
                # This part handles reshuffling if we decide to implement it here or ensure it's handled elsewhere.
                # For now, we only populate from master pools. Reshuffling logic will be separate.
                pass
    
    print("Battle pools created for combat!")
