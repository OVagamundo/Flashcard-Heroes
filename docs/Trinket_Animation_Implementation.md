# Trinket Animation Implementation Design

This document details the two-phase implementation and verification plan for:
1. **Phase 1**: Decoupling the `BattleAnimator` from the battle scene into a universal autoload.
2. **Phase 2**: Leveraging the decoupled animator to implement elegant, synchronized trinket animations both in and out of combat.

---

## 1. Phase 1: Animator Decoupling

The goal of this phase is to make the `BattleAnimator` a universal global singleton so it exists and can be referenced in all scenes (combat, management, shop, minigames), without breaking any existing combat animations.

### Proposed Changes

#### A. Autoload Configuration
* **[MODIFY] [project.godot](file:///c:/Users/danhh/Desktop/Flashcard-Heroes/project.godot)**
  Register `BattleAnimator` as a global singleton:
  ```ini
  BattleAnimator="*res://scripts/BattleAnimator.gd"
  ```
  (Append to the end of the `[autoload]` block)

#### B. Scene Cleanliness
* **[MODIFY] [Battle.tscn](file:///c:/Users/danhh/Desktop/Flashcard-Heroes/scenes/Battle.tscn)**
  Remove the local `BattleAnimator` node and its script resource definition `2_battle_animator_script`.

#### C. Animator Reference Updates
* **[MODIFY] [BattleManager.gd](file:///c:/Users/danhh/Desktop/Flashcard-Heroes/scripts/BattleManager.gd)**
  * Change `@onready var _animator: Node = $"../BattleAnimator"` to `var _animator: Node = null`.
  * Update `_resolve_animator()` to look up the autoload:
    ```gdscript
    func _resolve_animator() -> void:
    	if is_instance_valid(_animator):
    		return
    	var candidate = get_node_or_null("/root/BattleAnimator")
    	if not is_instance_valid(candidate):
    		candidate = get_tree().get_first_node_in_group("battle_animator")
    	if is_instance_valid(candidate):
    		_animator = candidate
    		if not _animator.turn_animation_finished.is_connected(_on_turn_animation_finished):
    			_animator.turn_animation_finished.connect(_on_turn_animation_finished)
    ```

* **[MODIFY] [BattleView.gd](file:///c:/Users/danhh/Desktop/Flashcard-Heroes/scripts/BattleView.gd)**
  * Update `_battle_animator` initialization to resolve dynamically via autoload and group fallback:
    ```gdscript
    	_battle_animator = get_node_or_null("/root/BattleAnimator")
    	if not is_instance_valid(_battle_animator):
    		_battle_animator = get_tree().get_first_node_in_group("battle_animator")
    ```

### Phase 1 Verification Plan
* **Compilation Check**: Run `godot --headless -s scripts/debug_compile.gd` to ensure no syntax errors.
* **Functional Playback Verification**: Start a standard combat run. Ensure all unit actions (attacks, heals, status effects, death, and summons) play their animations correctly and sequence transitions proceed without freezing.

---

## 2. Phase 2: Elegant Trinket Animations

Once the animator is a global singleton, we can implement the trinket animation triggers using the non-cloning UUID pattern in combat, and tree-walking fallbacks outside of combat.

### Proposed Changes

#### A. Direct Player Trinket Registration (No Cloning)
* **[MODIFY] [BattleSetup.gd](file:///c:/Users/danhh/Desktop/Flashcard-Heroes/scripts/battle/BattleSetup.gd)**
  Register permanent run state instances in the battle state directly to avoid UUID mismatches:
  ```gdscript
  static func setup_player_trinkets(state: RefCounted) -> void:
  	if not is_instance_valid(GameManager.run_state):
  		return
  	var pt_container = state.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS)
  	var slot_index := 0
  	for perm_inst in GameManager.run_state.get_all_instances().values():
  		var def = perm_inst.get_definition()
  		if not is_trinket_definition(def):
  			continue
  		var perm_loc = GameManager.run_state.get_location_for_uuid(perm_inst.ball_uuid)
  		if not is_instance_valid(perm_loc):
  			continue
  		if perm_loc.container != RS.RUN_CONTAINER_TAGS.PLAYER_TRINKETS:
  			continue
  		state.register_instance(perm_inst)
  		pt_container.set_uuid(slot_index, perm_inst.ball_uuid)
  		state.update_instance_location(perm_inst.ball_uuid, C.BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS, slot_index)
  		slot_index += 1
  ```

#### B. Expose GachaBallView Properties
* **[MODIFY] [GachaBallView.gd](file:///c:/Users/danhh/Desktop/Flashcard-Heroes/scripts/GachaBallView.gd)**
  Expose `definition_id` and `is_enemy` properties, and assign them in `populate()` and `set_is_enemy()`.

#### C. Tree-Walking Fallback & Hop Implementation
* **[MODIFY] [BattleAnimator.gd](file:///c:/Users/danhh/Desktop/Flashcard-Heroes/scripts/BattleAnimator.gd)**
  * Add `_get_trinket_views_from_tree()` scanning `%PlayerTrinketBar` and `%EnemyTrinketBar`.
  * Update `hop_trinket_by_definition_id()` to fall back to walking the tree if the visual registry lookup fails.

#### D. Mechanical Trigger Hooks (All 18 Trinkets)
Integrate hops into individual effect scripts:
1. **Combat Events**: Hook `StatusEffectAnimation`, `BuffAnimation`, `DamageAnimation` (for Burn Vial), `TargetResolver`/`DeathProcessor` (for Insignias, Egis, Kamikaze, etc.).
2. **Phase/State Transitions**:
   * **Twin Charm**: Emit immediate hop on merge/summon stats recalculation.
   * **Bargain Charm**: Trigger hop inside `bm_draw_gacha_instance()`.
   * **Time Sprint**: Trigger hop in `FlashcardMinigame.gd:start_sprint_game()`.
   * **Polished Plate**: Append `STATUS_EFFECT` event inside `_process_status_turn_effect()`.
   * **Trait Thresholds**: Call `check_live_trait_thresholds` on dynamic inventory updates and battle events.

### Phase 2 Verification Plan
* **Out-of-Combat Hops**:
  * Buy a unit or spin the Gacha with **Bargain Charm** active; verify the Bargain Charm hops on draw.
  * Start the flashcard game with **Time Sprint Charm** active; verify the Sprint Charm hops immediately on start.
  * Merge/summon units causing identical counts to cross thresholds with **Twin Charm** active; verify it hops.
* **Combat Hops**:
  * Verify **Armor Aura** triggers a hop for *each* projectile landing.
  * Verify **Aegis Charm** triggers a hop when a unit is saved from lethal damage.
  * Verify **Trait Trinkets** hop as soon as a trait threshold level rises (e.g. 3rd fire unit summoned).
  * Verify **Enemy Trinkets** hop correctly during combat when their respective event conditions are met.
