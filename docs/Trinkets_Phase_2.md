
# Trinkets — Phase 2: Engine Plumbing & Trigger Pipeline (No-Guess, No-Defensive Code)

**Goal of Phase 2**  
Implement the core engine hooks so trinkets can react to events deterministically:
- Single damage entry point
- Living-only target resolution for new targets
- Deterministic trinket processing order (player then enemy)
- New condition check
- Start-of-turn trigger emission
- Ally-death context enrichment
- (Prepared) immediate-path trigger function for minigame time bonus

> This phase does **not** add trinket effects or definitions yet (Phase 3). It wires the engine so those will “just work.”

---

## 0) Files edited in this phase

- `res://scripts/BattleManager.gd`
- `res://scripts/AbilityResolver.gd`
- `res://scripts/BasicAttackEffect.gd`

*(If you keep your condition checks elsewhere, keep the code blocks but place them in your canonical condition function.)*

---

## 1) BattleManager — Single Damage Entry Point

**File:** `res://scripts/BattleManager.gd`

Add this function (exactly) and use it for all direct damage in your codebase from now on:

```gdscript
func apply_direct_damage(attacker_uuid: String, target_uuid: String, amount: int) -> int:
    var t = get_instance_by_uuid(target_uuid)
    var before := max(0, t.current_hp)
    var dealt := min(before, max(0, amount))
    var after := before - dealt
    t.current_hp = after

    var hurt_ctx := {
        "attacker_uuid": attacker_uuid,
        "hurt_uuid": target_uuid,
        "damage_amount": dealt,
        "lethal": after <= 0
    }
    AbilityResolver.process_trigger(C.TRIGGER_ON_HURT, hurt_ctx)

    if after <= 0 and before > 0:
        var kill_ctx := {"source_uuid": attacker_uuid, "killed_uuid": target_uuid}
        AbilityResolver.process_trigger(C.TRIGGER_ON_KILL, kill_ctx)

    return dealt
```

> Do **not** emit `on_hurt`/`on_kill` anywhere else in the codebase.

---

## 2) BasicAttackEffect — route damage via BattleManager

**File:** `res://scripts/BasicAttackEffect.gd`

Replace the attack’s execute body so it **does not** mutate HP directly and **does not** call legacy trigger helpers. Return the dealt amount.

```gdscript
func execute(source_uuid: String, targets: Array[String], battle_manager: Node, _context: Dictionary) -> Variant:
    if targets.is_empty():
        return 0
    var src = battle_manager.get_instance_by_uuid(source_uuid)
    var dmg = _calculate_damage(src)
    return battle_manager.apply_direct_damage(source_uuid, targets[0], dmg)
```

Remove any remaining `trigger_on_hurt` / `trigger_on_kill` calls in this file.

---

## 3) BattleManager — helpers and target resolution

**File:** `res://scripts/BattleManager.gd`

Add helpers used by targeting/effects:

```gdscript
# Null-safe container read used by Pendant placement and checks
func get_uuid_at(container_tag: StringName, slot_index: int) -> String:
    var cont := get_container(container_tag)
    if cont == null:
        return ""
    return cont.get_uuid(slot_index)

# Used by FRONTMOST_ALLY and other selection rules
func get_instances_in_container(tag: StringName) -> Array:
    var cont := get_container(tag)
    var out: Array = []
    if cont:
        for i in range(cont.get_size()):
            var uid: String = cont.get_uuid(i)
            if uid != "":
                var inst = get_instance_by_uuid(uid)
                if inst:
                    out.append(inst)
    return out

# Living-only enemy list for RANDOM_ENEMY
func get_opponent_living_uuids(source_uuid: String) -> Array[String]:
    var src = get_instance_by_uuid(source_uuid)
    if not src:
        return []
    var is_player := _is_player_unit(src)
    var tag := is_player ? BATTLE_CONTAINER_TAGS.ENEMY_LINEUP : BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
    var result: Array[String] = []
    for inst in get_instances_in_container(tag):
        if inst.current_hp > 0:
            result.append(inst.ball_uuid)
    return result
```

Extend your `resolve_target(...)` to support **living-only** selection for the two new target types:

```gdscript
if target_type == C.TARGET_FRONTMOST_ALLY:
    var src = get_instance_by_uuid(source_uuid)
    if not src:
        return []
    var is_player := _is_player_unit(src)
    var tag := is_player ? BATTLE_CONTAINER_TAGS.PLAYER_LINEUP : BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
    var arr := get_instances_in_container(tag)
    # Player side: rightmost is frontmost; Enemy side: leftmost is frontmost
    if is_player:
        for i in range(arr.size() - 1, -1, -1):
            if arr[i].current_hp > 0:
                return [arr[i].ball_uuid]
    else:
        for i in range(0, arr.size()):
            if arr[i].current_hp > 0:
                return [arr[i].ball_uuid]
    return []

if target_type == C.TARGET_RANDOM_ENEMY:
    var candidates := get_opponent_living_uuids(source_uuid)
    if candidates.is_empty():
        return []
    return [candidates[randi() % candidates.size()]]
```

> Note: Do not re-declare `C.TARGET_RANDOM_ENEMY` in Phase 2; it already exists. Phase 2 only enforces living-only selection.

---

## 4) BattleManager — enrich on_ally_death context

Where you emit the `on_ally_death` trigger, add the dead unit’s container and slot index to the context **before** dispatching:

```gdscript
ally_death_context["dead_ally_container"] = unit.location_container_tag
ally_death_context["dead_ally_slot_index"] = unit.location_slot_index
```

This enables “summon into the exact empty slot” trinkets in Phase 3.

---

## 5) AbilityResolver — deterministic trinket processing

**File:** `res://scripts/AbilityResolver.gd`

Add two private helpers so trinkets don’t depend on your instance/item ability pipeline. These helpers do **no** defensive checks and assume valid data.

```gdscript
func __process_trinket_ability(ability: Resource, source_uuid: String, bm: Node, context: Dictionary) -> void:
    if ability.condition != StringName():
        if not __check_condition(ability.condition, bm, context):
            return
    for eff in ability.effects:
        var targets: Array[String] = []
        if "target_type" in eff:
            targets = bm.resolve_target(source_uuid, eff.target_type, context)
        eff.execute(source_uuid, targets, bm, context)

func __check_condition(cond_type: StringName, bm: Node, ctx: Dictionary) -> bool:
    if cond_type == C.COND_TRIGGERING_DAMAGE_WAS_NON_LETHAL:
        var hurt_uuid: String = String(ctx.get("hurt_uuid", ""))
        var inst = bm.get_instance_by_uuid(hurt_uuid)
        return inst != null and inst.current_hp > 0
    return true
```

Now run trinkets **before** your existing unit/item pass, with a stable order:

```gdscript
func process_trigger(trigger: StringName, context: Dictionary) -> void:
    var bm = get_tree().get_first_node_in_group("battle_manager")

    # 1) Player trinkets (use hero uuid for global triggers; reactive triggers may still use hero as source)
    var hero_uuid: String = GameManager.run_state.hero_instance.ball_uuid if GameManager.run_state.hero_instance else ""
    for tdef in GameManager.run_state.get_trinket_definitions():
        for ability in tdef.ability_definitions:
            if ability.trigger == trigger:
                __process_trinket_ability(ability, hero_uuid, bm, context)

    # 2) Enemy trinkets (definition order) — use a reactive source from context for deterministic targeting
    var reactive_src := String(context.get("attacker_uuid", context.get("source_uuid", "")))
    for tdef in bm.get_enemy_trinkets():
        for ability in tdef.ability_definitions:
            if ability.trigger == trigger:
                __process_trinket_ability(ability, reactive_src, bm, context)

    # 3) Existing engine pipeline (unchanged)
    _process_instances_with_trigger(trigger, bm, context)  # keep your current call
```

> If your resolver uses a different entry name for the final pass, call that instead of `_process_instances_with_trigger`.

---

## 6) AbilityResolver — immediate path (minigame time bonus)

Add a small, **pure** function that mutates and returns the context, with no queuing/logging. You’ll call this in Phase 3 at the minigame open site.

```gdscript
static func process_trigger_immediate(trigger: StringName, context: Dictionary) -> Dictionary:
    if trigger != C.TRIGGER_ON_MINIGAME_OPEN:
        return context
    var hero_uuid: String = GameManager.run_state.hero_instance.ball_uuid if GameManager.run_state.hero_instance else ""
    for tdef in GameManager.run_state.get_trinket_definitions():
        for ability in tdef.ability_definitions:
            if ability.trigger == C.TRIGGER_ON_MINIGAME_OPEN:
                for eff in ability.effects:
                    # Immediate effects do not need targets or the battle manager
                    eff.execute(hero_uuid, [], null, context)
    return context
```

---

## 7) BattleManager — start-of-turn trigger emission

Insert this hook when advancing phases, exactly when entering START_OF_TURN — and before opening the minigame:

```gdscript
if next_phase == Phases.START_OF_TURN:
	AbilityResolver.process_trigger(C.TRIGGER_ON_TURN_START, {
		"team": team,
		"phase": "START_OF_TURN"
	})
```

> Use whatever team identifier type your codebase already uses; the keys above are for future extensibility.

---

## 8) Verification checklist for Phase 2

- Build succeeds. No references remain to direct HP mutation in BasicAttackEffect.
- `apply_direct_damage` is the **only** code path that emits `on_hurt`/`on_kill`.
- `resolve_target` now supports `FRONTMOST_ALLY` and filters dead units for both `FRONTMOST_ALLY` and `RANDOM_ENEMY`.
- `on_ally_death` context includes `dead_ally_container` and `dead_ally_slot_index`.
- `AbilityResolver.process_trigger` runs **player trinkets then enemy trinkets** before your usual pass.
- Enemy trinket loop uses a reactive source derived from context (`attacker_uuid` or `source_uuid`).
- Start-of-turn trigger is emitted upon entering `START_OF_TURN` in `BattleManager`, before any minigame UI opens.
- `AbilityResolver.process_trigger_immediate` exists (not yet called anywhere).

### 8.1 FRONTMOST_ALLY — orientation & fallback (living-only)
- **Setup:** Two living allies on player side; the rightmost is the player "frontmost". Ensure both are below max HP to observe selection.
- **Action:** Kill the current frontmost ally. Advance to `START_OF_TURN` to trigger start-of-turn effects.
- **Expect:** The next living ally becomes frontmost and is selected by `FRONTMOST_ALLY` for heals/effects.
- **Also verify:** On enemy side, the leftmost living unit is frontmost.

### 8.2 RANDOM_ENEMY — living-only
- **Setup:** Enemy lineup contains at least one dead unit and one living unit.
- **Action:** Trigger an effect that targets `RANDOM_ENEMY` (e.g., Lightning Rod in Phase 3) in a controlled test.
- **Expect:** The dead unit is never selected; only living enemies are eligible.

> Once this is green, proceed to **Phase 3** (effects + definitions + minigame call-site).

---

## Changelog (Phase 2 fix)

- Added complete helpers in `BattleManager`: null-safe `get_uuid_at`, `get_instances_in_container`, and living-only `get_opponent_living_uuids`.
- Target resolution now explicitly implements `FRONTMOST_ALLY` (oriented, living-only) and `RANDOM_ENEMY` (living-only).
- Enemy trinket pass in `AbilityResolver.process_trigger` now uses a reactive source from context for deterministic targeting.
- Start-of-turn trigger dispatch made explicit at the `next_phase == Phases.START_OF_TURN` hook (before minigame).
- Added note to avoid redeclaring constants already present (e.g., `C.TARGET_RANDOM_ENEMY`).

Commit message:

```
docs: tighten Phase 2 — add helpers, fix enemy trinket reactive source, explicit start-of-turn trigger, enforce living-only targeting
```
