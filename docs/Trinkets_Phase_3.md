
# Trinkets — Phase 3: Effects, Trinket Abilities & Minigame Bonus (No-Guess, No-Defensive Code)

**Goal of Phase 3**  
Ship the actual **effects**, **trinket abilities**, and the **five trinket definitions**, plus the **minigame time bonus** call-site. This builds directly on Phase 1 (UI/data) and Phase 2 (engine plumbing).

After Phase 3:
- All five trinkets work end‑to‑end.
- Hourglass adds time to the Flashcard minigame at open.
- Pendant summons into the dead ally’s slot **once per team turn**.
- Healing/Non‑lethal/Damage trinkets behave as described.

---

## 0) Files created/edited in this phase

**New files**
- `res://scripts/trinkets/TrinketAbilityDefinition.gd`
- `res://scripts/effects/trinkets/EffectHealFlat.gd`
- `res://scripts/effects/trinkets/EffectDirectDamage.gd`
- `res://scripts/effects/trinkets/EffectSummonRandomTier1.gd`
- `res://scripts/effects/trinkets/EffectAddMinigameTime.gd`
- `res://resources/trinkets/HealingAmulet.tres`
- `res://resources/trinkets/BloodthirstyCharm.tres`
- `res://resources/trinkets/LightningRod.tres`
- `res://resources/trinkets/PhoenixPendant.tres`
- `res://resources/trinkets/ScholarsHourglass.tres`

**Edited files**
- `res://scripts/AbilityResolver.gd` (pass `trinket_id` in context; better source selection)
- `res://scripts/BattleManager.gd` (once‑per‑turn gating helpers; reset at start of turn)
- `res://scripts/FlashcardManager.gd` (immediate path call; pass `session_seconds`)
- `res://scripts/FlashcardMinigame.gd` (read `session_seconds` from populate())

> All code below assumes the `EffectDefinition.execute` signature used in your codebase:  
> `execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant`

---

## 1) TrinketAbility resource (keeps Phase 2 logic type-agnostic)

**File:** `res://scripts/trinkets/TrinketAbilityDefinition.gd`

```gdscript
@tool
class_name TrinketAbilityDefinition
extends Resource

@export var id: StringName
@export var trigger: StringName
@export var condition: StringName = StringName() # empty means no condition
@export var effects: Array[EffectDefinition] = []
```

Your Phase 2 resolver uses fields (`trigger`, `condition`, `effects`) without assuming a specific class, so this resource works out‑of‑the‑box.

---

## 2) Effects

Create these scripts exactly. They extend your existing `EffectDefinition` base.

**File:** `res://scripts/effects/trinkets/EffectHealFlat.gd`
```gdscript
@tool
class_name EffectHealFlat
extends EffectDefinition

@export var target_type: StringName = C.TARGET_SELF
@export var amount: int = 0
@export var clamp_to_hero_max: bool = false

func execute(source_uuid: String, targets: Array[String], bm: Node, ctx: Dictionary) -> void:
	for tu in targets:
		var t = bm.get_instance_by_uuid(tu)
		if not t:
			continue
		var new_hp := int(t.current_hp) + int(amount)
		if clamp_to_hero_max and t.get_definition() and t.get_definition().is_hero:
			var max_hp := t.get_effective_max_hp() if "get_effective_max_hp" in t else t.get_definition().base_hp
			new_hp = min(new_hp, max_hp)
		t.current_hp = new_hp
```

**File:** `res://scripts/effects/trinkets/EffectDirectDamage.gd`
```gdscript
@tool
class_name EffectDirectDamage
extends EffectDefinition

@export var target_type: StringName
@export var damage: int = 1

func execute(source_uuid: String, targets: Array[String], bm: Node, ctx: Dictionary) -> void:
	for t in targets:
		bm.apply_direct_damage(source_uuid, t, damage)
```

**File:** `res://scripts/effects/trinkets/EffectSummonRandomTier1.gd`
```gdscript
@tool
class_name EffectSummonRandomTier1
extends EffectDefinition

@export var once_per_turn: bool = true

func execute(source_uuid: String, targets: Array[String], bm: Node, ctx: Dictionary) -> void:
	var trid: StringName = ctx.get("trinket_id", StringName())
	if once_per_turn and bm.trinket_used_this_turn(trid):
		return

	var tag: StringName = ctx.get("dead_ally_container")
	var idx: int = int(ctx.get("dead_ally_slot_index"))
	if bm.get_uuid_at(tag, idx) != "":
		return

	var pool: Array = []
	for def in Database.units.values():
		if def.category == &"UNIT" and def.tier == 1 and not def.is_hero:
			pool.append(def)
	var pick = pool[randi() % pool.size()]

	var inst := GachaBallInstance.new()
	inst.initialize(pick)
	bm.bm_add_instance(inst, tag, idx)

	# Log a simple line to the battle log (spec requirement)
	if SignalBus.has_signal("battle_log_event"):
		SignalBus.emit_signal("battle_log_event", "Phoenix Pendant", "Summoned %s into slot %d" % [String(pick.id), idx])

	if once_per_turn:
		bm.mark_trinket_used_this_turn(trid)
```

**File:** `res://scripts/effects/trinkets/EffectAddMinigameTime.gd`
```gdscript
@tool
class_name EffectAddMinigameTime
extends EffectDefinition

@export var seconds: int = 0

func execute(source_uuid: String, targets: Array[String], bm: Node, ctx: Dictionary) -> void:
	ctx["bonus_seconds"] = int(ctx.get("bonus_seconds", 0)) + int(seconds)
```

---

## 3) BattleManager — once-per-turn gating helpers

**File:** `res://scripts/BattleManager.gd`

Add this near other private state:

```gdscript
var _trinket_used_this_turn: Dictionary = {} # StringName(id) -> bool
```

Add helpers:

```gdscript
func trinket_used_this_turn(id: StringName) -> bool:
	return bool(_trinket_used_this_turn.get(id, false))

func mark_trinket_used_this_turn(id: StringName) -> void:
	_trinket_used_this_turn[id] = true

func reset_trinket_turn_flags() -> void:
	_trinket_used_this_turn.clear()
```

**Reset at start of turn** (where you emit `TRIGGER_ON_TURN_START` per Phase 2):

```gdscript
reset_trinket_turn_flags()
AbilityResolver.process_trigger(C.TRIGGER_ON_TURN_START, {"team": "PLAYER", "phase": "START_OF_TURN"})
```

…and likewise for the enemy turn.

---

## 4) AbilityResolver — pass `trinket_id` and better `source_uuid`

**File:** `res://scripts/AbilityResolver.gd`

In both trinket loops inside `process_trigger(...)`, wrap the context and pass the **trinket id**. Also refine source selection for reactive triggers:

```gdscript
# Player trinkets
var hero_uuid: String = GameManager.run_state.hero_instance.ball_uuid if GameManager.run_state.hero_instance else ""
for tdef in GameManager.run_state.get_trinket_definitions():
	for ability in tdef.ability_definitions:
		if ability.trigger == trigger:
			var cx := context.duplicate(true)
			cx["trinket_id"] = tdef.id
			var src := hero_uuid
			if trigger == C.TRIGGER_ON_HURT and cx.has("attacker_uuid"):
				src = String(cx["attacker_uuid"])
			__process_trinket_ability(ability, src, bm, cx)

# Enemy trinkets
for tdef in bm.get_enemy_trinkets():
	for ability in tdef.ability_definitions:
		if ability.trigger == trigger:
			var cx := context.duplicate(true)
			cx["trinket_id"] = tdef.id
			var src := String(cx.get("attacker_uuid", ""))
			__process_trinket_ability(ability, src, bm, cx)
```

**Immediate path** (inside `process_trigger_immediate(...)`), do the same `trinket_id` wrapping and source choice (player-only):

```gdscript
var bm = get_tree().get_first_node_in_group("battle_manager")
var hero_uuid: String = GameManager.run_state.hero_instance.ball_uuid if GameManager.run_state.hero_instance else ""
for tdef in GameManager.run_state.get_trinket_definitions():
	for ability in tdef.ability_definitions:
		if ability.trigger == C.TRIGGER_ON_MINIGAME_OPEN:
			var cx := context.duplicate(true)
			cx["trinket_id"] = tdef.id
			for eff in ability.effects:
				var targets: Array[String] = []
				if "target_type" in eff:
					targets = bm.resolve_target(hero_uuid, eff.target_type, cx)
				eff.execute(hero_uuid, targets, bm, cx)
return context
```

---

## 5) Minigame integration (immediate path)

**File:** `res://scripts/FlashcardManager.gd` — replace the modal open call in `start_minigame(...)` with:

```gdscript
# Compute time bonus from player trinkets
var ctx := {"bonus_seconds": 0}
ctx = AbilityResolver.process_trigger_immediate(C.TRIGGER_ON_MINIGAME_OPEN, ctx)
var session_seconds := int(ctx.get("bonus_seconds", 0)) + 3

_minigame_instance = WindowManager.open_modal_window(&"FlashcardMinigame", {
	"run_state": run_state,
	"active_deck": active_deck,
	"session_seconds": session_seconds,
})
```

**File:** `res://scripts/FlashcardMinigame.gd` — read the passed time in `populate(context)`:

```gdscript
var _session_seconds: int = 3

func populate(context: Dictionary) -> void:
	_session_seconds = int(context.get("session_seconds", 3))
	# use _session_seconds wherever the timer length is set
```

---

## 6) Five Trinkets (.tres)

> These use `TrinketAbilityDefinition` and the four effects above. Icons are already available under `res://assets/sprites/trinkets/`. Assign them by adding a Texture2D `ext_resource` and setting `icon = ExtResource("<id>")` in the `[resource]` block. Examples below use the existing PNGs (you can choose any file you prefer).

**Common ext_resources at the top of each .tres** (adjust ids per file if your editor renumbers):
```ini
[ext_resource type="Script" path="res://scripts/trinkets/TrinketDefinition.gd" id="1"]
[ext_resource type="Script" path="res://scripts/trinkets/TrinketAbilityDefinition.gd" id="2"]
[ext_resource type="Script" path="res://scripts/effects/trinkets/EffectHealFlat.gd" id="3"]
[ext_resource type="Script" path="res://scripts/effects/trinkets/EffectDirectDamage.gd" id="4"]
[ext_resource type="Script" path="res://scripts/effects/trinkets/EffectSummonRandomTier1.gd" id="5"]
[ext_resource type="Script" path="res://scripts/effects/trinkets/EffectAddMinigameTime.gd" id="6"]
```

### 6.1 Healing Amulet — start-of-turn heal frontmost ally by 2
**File:** `res://resources/trinkets/HealingAmulet.tres`
```ini
[gd_resource type="Resource" script_class="TrinketDefinition" load_steps=9 format=3]
[ext_resource type="Script" path="res://scripts/trinkets/TrinketDefinition.gd" id="1"]
[ext_resource type="Script" path="res://scripts/trinkets/TrinketAbilityDefinition.gd" id="2"]
[ext_resource type="Script" path="res://scripts/effects/trinkets/EffectHealFlat.gd" id="3"]
[ext_resource type="Texture2D" path="res://assets/sprites/trinkets/Trinket1A.png" id="7"]

[sub_resource type="Resource" id="A1" script="ExtResource(2)"]
id = "healing_amulet_ability"
trigger = &"on_turn_start"
condition = ""
effects = [SubResource("E1")]

[sub_resource type="Resource" id="E1" script="ExtResource(3)"]
target_type = &"FRONTMOST_ALLY"
amount = 2
clamp_to_hero_max = true

[resource]
script = ExtResource("1")
id = "HealingAmulet"
display_name_key = "Healing Amulet"
description_key = "At the start of your turn, heal the frontmost ally by 2."
icon = ExtResource("7")
is_player_exclusive = true
ability_definitions = [SubResource("A1")]
```

### 6.2 Bloodthirsty Charm — on non‑lethal hurt, heal the attacker by 1
**File:** `res://resources/trinkets/BloodthirstyCharm.tres`
```ini
[gd_resource type="Resource" script_class="TrinketDefinition" load_steps=9 format=3]
[ext_resource type="Script" path="res://scripts/trinkets/TrinketDefinition.gd" id="1"]
[ext_resource type="Script" path="res://scripts/trinkets/TrinketAbilityDefinition.gd" id="2"]
[ext_resource type="Script" path="res://scripts/effects/trinkets/EffectHealFlat.gd" id="3"]
[ext_resource type="Texture2D" path="res://assets/sprites/trinkets/Trinket2A.png" id="8"]

[sub_resource type="Resource" id="A1" script="ExtResource(2)"]
id = "bloodthirsty_charm_ability"
trigger = &"on_hurt"
condition = &"TRIGGERING_DAMAGE_WAS_NON_LETHAL"
effects = [SubResource("E1")]

[sub_resource type="Resource" id="E1" script="ExtResource(3)"]
target_type = &"SELF"
amount = 1
clamp_to_hero_max = true

[resource]
script = ExtResource("1")
id = "BloodthirstyCharm"
display_name_key = "Bloodthirsty Charm"
description_key = "When you deal non‑lethal damage, heal yourself by 1."
icon = ExtResource("8")
ability_definitions = [SubResource("A1")]
```

> Because Phase 3 refines `source_uuid` to come from `attacker_uuid` for `on_hurt`, this heals the **attacker** (hero on player side).

### 6.3 Lightning Rod — on ally death, deal 2 damage to a random enemy
**File:** `res://resources/trinkets/LightningRod.tres`
```ini
[gd_resource type="Resource" script_class="TrinketDefinition" load_steps=9 format=3]
[ext_resource type="Script" path="res://scripts/trinkets/TrinketDefinition.gd" id="1"]
[ext_resource type="Script" path="res://scripts/trinkets/TrinketAbilityDefinition.gd" id="2"]
[ext_resource type="Script" path="res://scripts/effects/trinkets/EffectDirectDamage.gd" id="4"]
[ext_resource type="Texture2D" path="res://assets/sprites/trinkets/Trinket4A.png" id="9"]

[sub_resource type="Resource" id="A1" script="ExtResource(2)"]
id = "lightning_rod_ability"
trigger = &"on_ally_death"
condition = ""
effects = [SubResource("E1")]

[sub_resource type="Resource" id="E1" script="ExtResource(4)"]
target_type = &"RANDOM_ENEMY"
damage = 2

[resource]
script = ExtResource("1")
id = "LightningRod"
display_name_key = "Lightning Rod"
description_key = "When an ally dies, deal 2 damage to a random enemy."
icon = ExtResource("9")
ability_definitions = [SubResource("A1")]
```

### 6.4 Phoenix Pendant — on ally death, summon 1 random Tier 1 unit into that empty slot (**once per turn**)
**File:** `res://resources/trinkets/PhoenixPendant.tres`
```ini
[gd_resource type="Resource" script_class="TrinketDefinition" load_steps=9 format=3]
[ext_resource type="Script" path="res://scripts/trinkets/TrinketDefinition.gd" id="1"]
[ext_resource type="Script" path="res://scripts/trinkets/TrinketAbilityDefinition.gd" id="2"]
[ext_resource type="Script" path="res://scripts/effects/trinkets/EffectSummonRandomTier1.gd" id="5"]
[ext_resource type="Texture2D" path="res://assets/sprites/trinkets/Trinket5A.png" id="10"]

[sub_resource type="Resource" id="A1" script="ExtResource(2)"]
id = "phoenix_pendant_ability"
trigger = &"on_ally_death"
condition = ""
effects = [SubResource("E1")]

[sub_resource type="Resource" id="E1" script="ExtResource(5)"]
once_per_turn = true

[resource]
script = ExtResource("1")
id = "PhoenixPendant"
display_name_key = "Phoenix Pendant"
description_key = "When an ally dies, summon a random Tier 1 unit into that slot (once per turn)."
icon = ExtResource("10")
ability_definitions = [SubResource("A1")]
```

### 6.5 Scholar’s Hourglass — on minigame open, add +2 seconds (immediate)
**File:** `res://resources/trinkets/ScholarsHourglass.tres`
```ini
[gd_resource type="Resource" script_class="TrinketDefinition" load_steps=9 format=3]
[ext_resource type="Script" path="res://scripts/trinkets/TrinketDefinition.gd" id="1"]
[ext_resource type="Script" path="res://scripts/trinkets/TrinketAbilityDefinition.gd" id="2"]
[ext_resource type="Script" path="res://scripts/effects/trinkets/EffectAddMinigameTime.gd" id="6"]
[ext_resource type="Texture2D" path="res://assets/sprites/trinkets/Trinket3A.png" id="11"]

[sub_resource type="Resource" id="A1" script="ExtResource(2)"]
id = "scholars_hourglass_ability"
trigger = &"on_minigame_open"
condition = ""
effects = [SubResource("E1")]

[sub_resource type="Resource" id="E1" script="ExtResource(6)"]
seconds = 2

[resource]
script = ExtResource("1")
id = "ScholarsHourglass"
display_name_key = "Scholar's Hourglass"
description_key = "When a minigame starts, gain +2 seconds."
is_player_exclusive = true
icon = ExtResource("11")
ability_definitions = [SubResource("A1")]
```

---

## 7) Verification checklist — Phase 3

- **Healing Amulet:** At start of the player turn, the **frontmost living ally** gains +2 HP.
- **Bloodthirsty Charm:** Whenever the hero deals **non‑lethal** damage (i.e., `on_hurt.lethal == false`), the **attacker** heals +1.
- **Lightning Rod:** When any allied unit dies, a random **living** enemy takes 2 damage.
- **Phoenix Pendant:** On the **first** allied death each team turn, a random Tier 1 non‑hero is summoned into that exact slot. No second summon occurs until the next **start‑of‑turn** (gating resets).
- **Scholar’s Hourglass:** Opening the Flashcard minigame increases the session timer by 2 seconds (additive if multiple Hourglasses). The minigame receives `session_seconds` and uses it.
- Enemy trinkets from `EncounterDefinition.enemy_trinket_ids` also work for the reactive trinkets above (on hurt / ally death).
- No effect mutates HP directly for damage: all damage is routed through `BattleManager.apply_direct_damage`.

### 7.1 Bloodthirsty Charm — lethal vs non‑lethal
- **Setup:** Equip Bloodthirsty; prepare two attacks: one that leaves target alive, one that kills.
- **Action:** Execute the non‑lethal attack, then a lethal attack.
- **Expect:** Heal **+1** only when `on_hurt.lethal == false`; **no heal** on the lethal hit.

### 7.2 Phoenix Pendant — battle log emission
- **Setup:** As in the Pendant test, additionally attach a dev‑only listener to `SignalBus.battle_log_event`.
- **Action:** Cause an ally death that triggers a summon.
- **Expect:** Exactly one log entry mentioning a summon into the correct slot. Remove the listener after testing.

If all green, Trinkets are feature‑complete. 🎉
