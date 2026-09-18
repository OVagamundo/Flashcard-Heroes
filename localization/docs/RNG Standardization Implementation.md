# Implementation Mandate: RNG Standardization & Determinism (COMPLETED)

## 1. Commander's Intent & Context
Before we can implement the `ActionQueue` and achieve true replayability, the game must be completely sterilized of native, non-deterministic random number generation.

Currently, the codebase contains over 45 instances of Godot's global RNG functions (`randi()`, `randf()`, `shuffle()`, `pick_random()`). If the game is recorded and replayed in this state, the replay engine will instantly desync because enemy AI and map generation will roll different random numbers on the second pass.

Our objective is to implement a centralized `RNGManager` that maintains strict, isolated, seed-based PRNG streams for every subsystem in the game, and to purge all native randomness from the codebase.

---

## 2. Isolated PRNG Streams (The Architecture)
We will introduce a central `RNGManager` Autoload containing multiple instances of a custom `SeededRNG` class. 

### Why Isolated Streams?
If the game used a single global random seed, rolling a dice during a combat turn (e.g., picking a random target) would advance the global seed. This means your combat decisions would permanently alter the RNG sequence for the Map Generation on the next screen. By isolating them, the Map Generation sequence remains perfectly identical regardless of what happens in combat.

### The Implemented Streams:
* `map_rng`: Used for path generation, node selection, encounter generation (`EncounterGenerator.gd`), deck shuffling, and flashcard SRS algorithm.
* `combat_rng`: Used for enemy targeting, bounce mechanics, and random status effects (`TargetResolver.gd`, `AbilityResolver.gd`, `EffectBurnyCounter.gd`).
* `shop_rng`: Used for shop inventories and re-rolls (`WeightedPoolDirector.gd`).
* `reward_rng`: Used for post-combat loot drops, training outcomes, and rest sites.
* `gacha_rng`: Used for drawing units/items from gachaballs, UUID suffix generation, and inventory overflow replacement.
* `cosmetic_rng`: Used for screen shake offsets, audio pitch variance, physics ball spread, and coin scatter VFX.

---

## 3. Seed Injection & State Serialization
The `RNGManager` must be fully serializable so that run saves and replays can restore the exact state of the dice.

* **Master Seed:** At the start of a run, a single `_master_seed` is generated (or injected from a Replay `.mcr` file).
* **Stream Derivation:** Each isolated stream derives its initial seed deterministically from the master seed by hashing a unique string (e.g., `hash(str(_master_seed) + "_combat")`).
* **Serialization:** When saving the game or starting a replay, the `RNGManager` must be able to output its current internal state via `serialize() -> Dictionary` and restore it via `deserialize()`.

---

## 4. Codebase Purge Rules (Definition of Done)
Once the `RNGManager` is implemented, the developer must systematically purge native randomness across the entire codebase.

### Strict Replacement Guidelines:
1. **Never use native Godot RNG:** Any call to `randi()`, `randf()`, `randi_range()`, or `randf_range()` must be replaced with `RNGManager.[stream_name].randi()`.
2. **Never use native Array randomization:** Any call to `Array.shuffle()` or `Array.pick_random()` must be replaced with `RNGManager.[stream_name].shuffle(array)` or `RNGManager.[stream_name].pick_random(array)`.
3. **No Exceptions:** This applies universally to all scripts in `scripts/abilities/`, `scripts/effects/`, `TargetResolver.gd`, `FlashcardManager.gd`, and `RunState.gd`.

### Verification:
The refactor is considered complete when a global search (grep) for `randi`, `randf`, `shuffle`, and `pick_random` yields **zero** results outside of the `SeededRNG.gd` wrapper script, and the game compiles and runs normally using the new streams.

### Post-Completion Fix (Applied):
The `WeightedPoolDirector.draw_item()` defaults to `RNGManager.shop_rng` when no explicit RNG stream is passed. This caused `PathChoice.gd` and `EncounterGenerator.gd` to silently use the shop stream for map/encounter generation, breaking determinism across subsystem boundaries. Both scripts have been updated to explicitly pass `RNGManager.map_rng` to the director.
