
# Trinkets — Phase 1: Data & UI Scaffolding (No-Guess, No-Defensive Code)

**Goal of Phase 1**  
Lay down the *data structures*, *resource types*, and *UI scaffolding* for trinkets so they are visible and inspectable in the HUD and Battle screen. No gameplay logic or triggers in this phase. After Phase 1, you can add/remove player trinkets in `RunState` and define enemy trinkets per-encounter and see them rendered, with a working inspection window.

> This doc is self-contained. Copy-paste the blocks as-is. Names/paths are explicit to avoid ambiguity.

---

## 0) Overview of files created/edited

**New files**
- `res://scripts/trinkets/TrinketDefinition.gd`
- `res://scenes/TrinketView.tscn`
- `res://scripts/TrinketView.gd`
- `res://scenes/TrinketInspectionWindow.tscn`
- `res://scripts/TrinketInspectionWindow.gd`

**Edited files**
- `res://scripts/Constants.gd`
- `res://scripts/Database.gd`
- `res://scripts/RunState.gd`
- `res://scripts/EncounterDefinition.gd`
- `res://scripts/WindowManager.gd` (registration only)
- `res://scenes/Main.tscn` (insert Player grid)
- `res://scripts/Main.gd` (rebuild Player grid)
- `res://scenes/Battle.tscn` (insert Enemy grid)
- `res://scripts/BattleView.gd` (populate Enemy grid)
- `res://scripts/BattleManager.gd` (display-only enemy trinket storage/setup in Phase 1)
- *(Optional for quick manual test)* `res://resources/trinkets/Sample_*.tres`

---

## 1) Constants — add IDs used in UI & containers
**File:** `res://scripts/Constants.gd`

Append these (do not remove or alias existing constants):

```gdscript
# Trinkets
const TRIGGER_ON_TURN_START    = &"on_turn_start"      # used in later phases
const TRIGGER_ON_MINIGAME_OPEN = &"on_minigame_open"   # used in later phases

const TARGET_FRONTMOST_ALLY    = &"FRONTMOST_ALLY"     # used in later phases
const COND_TRIGGERING_DAMAGE_WAS_NON_LETHAL = &"TRIGGERING_DAMAGE_WAS_NON_LETHAL"  # later phases
```

Use `RUN_CONTAINER_TAGS.PLAYER_TRINKETS` for the player trinket container; do not define a separate alias constant.

> Do not add `TARGET_RANDOM_ENEMY` in Phase 1 — it already exists in the codebase.

---

## 2) Trinket resource type
**File:** `res://scripts/trinkets/TrinketDefinition.gd`

```gdscript
@tool
class_name TrinketDefinition
extends Resource

@export var id: StringName
@export var display_name_key: String
@export var description_key: String
@export var icon: Texture2D
@export var tags: Array[StringName] = [&"TRINKET"]
@export var is_player_exclusive: bool = false
@export var is_enemy_exclusive: bool = false

# Filled in Phase 3 with AbilityDefinition references; safe to leave empty in Phase 1
@export var ability_definitions: Array[Resource] = []
```

---

## 3) Database — loader & accessors
**File:** `res://scripts/Database.gd`

Add a dictionary and load path (mirror your existing loader calls). Search for your `_ready()` setup and add the trinkets line exactly once.

```gdscript
var trinkets: Dictionary = {}  # id -> TrinketDefinition

func _ready() -> void:
    # ...existing loaders...
    _load_resources_from_path("res://resources/trinkets/", trinkets) # NEW
```

Accessors:

```gdscript
func get_trinket_definition(id: StringName) -> TrinketDefinition:
    return trinkets.get(id, null)

func get_all_trinket_defs() -> Array[TrinketDefinition]:
    return trinkets.values()
```

---

## 4) RunState — 5-slot fixed container & helpers
**File:** `res://scripts/RunState.gd`

Add a lazy 5-slot container keyed by `RUN_CONTAINER_TAGS.PLAYER_TRINKETS`, backed by your existing `FixedArrayContainer`:

```gdscript
func get_container(tag: StringName) -> DataContainer:
    if _containers.has(tag):
        return _containers[tag]
    if tag == RUN_CONTAINER_TAGS.PLAYER_TRINKETS:
        var cont := FixedArrayContainer.new(5)
        _containers[tag] = cont
        return cont
    return null
```

Helper API (no defensive branches; assumes valid inputs from UI/editor):

```gdscript
func add_trinket_definition(def: TrinketDefinition) -> void:
    var cont: DataContainer = get_container(RUN_CONTAINER_TAGS.PLAYER_TRINKETS)
    # no duplicates
    for i in range(cont.get_size()):
        if cont.get_uuid(i) == String(def.id):
            return
    # first empty
    for i in range(cont.get_size()):
        if cont.get_uuid(i) == "":
            cont.set_uuid(i, String(def.id))
            SignalBus.emit_signal("run_data_changed")
            return

func remove_trinket_at(index: int) -> void:
    var cont: DataContainer = get_container(RUN_CONTAINER_TAGS.PLAYER_TRINKETS)
    cont.set_uuid(index, "")
    SignalBus.emit_signal("run_data_changed")

func get_trinket_definitions() -> Array[TrinketDefinition]:
    var cont: DataContainer = get_container(RUN_CONTAINER_TAGS.PLAYER_TRINKETS)
    var out: Array[TrinketDefinition] = []
    for i in range(cont.get_size()):
        var id_str: String = cont.get_uuid(i)
        if id_str != "":
            var def := Database.get_trinket_definition(StringName(id_str))
            if def: out.append(def)
    return out
```

---

## 5) EncounterDefinition — enemy trinket ids
**File:** `res://scripts/EncounterDefinition.gd`

Add an exported list for enemy trinkets (referencing IDs from `resources/trinkets`).

```gdscript
@export var enemy_trinket_ids: Array[StringName] = []
```

---

## 6) BattleManager — enemy trinket storage (display-only for Phase 1)
**File:** `res://scripts/BattleManager.gd`

Add a simple store and setup from the encounter (no triggers yet):

```gdscript
var _enemy_trinkets: Array[TrinketDefinition] = []

func get_enemy_trinkets() -> Array[TrinketDefinition]:
    return _enemy_trinkets

func _setup_enemy_trinkets_from_encounter(enc) -> void:
    _enemy_trinkets.clear()
    var ids: Array[StringName] = []
    if enc:
        ids = enc.enemy_trinket_ids
    for id in ids:
        var tdef: TrinketDefinition = Database.get_trinket_definition(id)
        if tdef and not tdef.is_player_exclusive:
            var exists := false
            for d in _enemy_trinkets:
                if d.id == tdef.id:
                    exists = true
                    break
            if not exists:
                _enemy_trinkets.append(tdef)
```

> Call `_setup_enemy_trinkets_from_encounter(encounter_def)` wherever you currently set up the battle (same place you build EnemyLineup).

---

## 7) UI prefab — TrinketView (icon + single-click to inspect)
**Files:**
- `res://scenes/TrinketView.tscn`
- `res://scripts/TrinketView.gd`

**TrinketView.gd**
```gdscript
@tool
extends Control
class_name TrinketView

@export var trinket_id: StringName
var _def: Resource

func _ready() -> void:
    add_to_group("InspectionOnly") # same parity as gachaballs in inspection-only contexts
    if trinket_id != StringName(""):
        _def = Database.get_trinket_definition(trinket_id)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if _def:
            WindowManager.open_window(&"TrinketInspection", {"trinket_id": _def.id})
```

**TrinketView.tscn**
```ini
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/TrinketView.gd" id="1"]

[node name="TrinketView" type="Control"]
custom_minimum_size = Vector2(24, 24)
mouse_filter = 1
script = ExtResource("1")
```

Keep the structure identical to the previous trinket view scene (Control root, icon, count label if applicable), just update the script path/class to `TrinketView.gd` / `TrinketView`.

> Note: The window key is `&"TrinketInspection"` and must match the WindowManager registration below.

> Icons are already available under `res://assets/sprites/trinkets/`. When authoring `.tres` definitions, add a Texture2D `ext_resource` that points to a PNG from that folder and set the resource's `icon` field to `ExtResource("<id>")`.

---

## 8) Player HUD — insert 5-slot grid in Main.tscn
**File:** `res://scenes/Main.tscn`

Under your top bar container (`VBoxContainer/TopArea/HBoxContainer`), **insert before `DaysLabel`**:

```ini
[node name="PlayerTrinketGrid" type="GridContainer" parent="VBoxContainer/TopArea/HBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
columns = 5
theme_override_constants/h_separation = 6
theme_override_constants/v_separation = 0

[node name="TrinketSlot0" type="PanelContainer" parent="VBoxContainer/TopArea/HBoxContainer/PlayerTrinketGrid"]
custom_minimum_size = Vector2(24, 24)

[node name="TrinketSlot1" type="PanelContainer" parent="VBoxContainer/TopArea/HBoxContainer/PlayerTrinketGrid"]
custom_minimum_size = Vector2(24, 24)

[node name="TrinketSlot2" type="PanelContainer" parent="VBoxContainer/TopArea/HBoxContainer/PlayerTrinketGrid"]
custom_minimum_size = Vector2(24, 24)

[node name="TrinketSlot3" type="PanelContainer" parent="VBoxContainer/TopArea/HBoxContainer/PlayerTrinketGrid"]
custom_minimum_size = Vector2(24, 24)

[node name="TrinketSlot4" type="PanelContainer" parent="VBoxContainer/TopArea/HBoxContainer/PlayerTrinketGrid"]
custom_minimum_size = Vector2(24, 24)
```

**File:** `res://scripts/Main.gd` — add rebuild logic

```gdscript
@onready var player_trinket_grid: GridContainer = %PlayerTrinketGrid
const TrinketViewScene = preload("res://scenes/TrinketView.tscn")

func _ready() -> void:
    # ...existing...
    SignalBus.run_data_changed.connect(_rebuild_player_trinkets)
    _rebuild_player_trinkets()

func _rebuild_player_trinkets() -> void:
    for c in player_trinket_grid.get_children():
        c.queue_free()
    var defs = GameManager.run_state.get_trinket_definitions()
    # Fill exactly 5 holders; populate existing defs in order
    for i in range(5):
        var holder = Control.new()
        holder.custom_minimum_size = Vector2(24, 24)
        player_trinket_grid.add_child(holder)
        if i < defs.size():
            var view = TrinketViewScene.instantiate()
            view.trinket_id = defs[i].id
            holder.add_child(view)
```

---

## 9) Enemy HUD — insert 5-slot grid in Battle.tscn
**File:** `res://scenes/Battle.tscn`

Under `TeamAreas/EnemyArea`, place this **after** `EnemyLineupContainer` (and **before** Discard/etc):

```ini
[node name="EnemyTrinketGrid" type="GridContainer" parent="TeamAreas/EnemyArea"]
unique_name_in_owner = true
layout_mode = 2
columns = 5
theme_override_constants/h_separation = 6
theme_override_constants/v_separation = 0

[node name="EnemyTrinketSlot0" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyTrinketGrid"]
custom_minimum_size = Vector2(24, 24)

[node name="EnemyTrinketSlot1" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyTrinketGrid"]
custom_minimum_size = Vector2(24, 24)

[node name="EnemyTrinketSlot2" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyTrinketGrid"]
custom_minimum_size = Vector2(24, 24)

[node name="EnemyTrinketSlot3" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyTrinketGrid"]
custom_minimum_size = Vector2(24, 24)

[node name="EnemyTrinketSlot4" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyTrinketGrid"]
custom_minimum_size = Vector2(24, 24)
```

**File:** `res://scripts/BattleView.gd` — populate from `BattleManager`

```gdscript
@onready var enemy_trinket_grid: GridContainer = %EnemyTrinketGrid
const TrinketViewScene = preload("res://scenes/TrinketView.tscn")

func populate_enemy_trinkets() -> void:
    for c in enemy_trinket_grid.get_children():
        c.queue_free()
    # Always render 5 holders
    for i in range(5):
        var holder = Control.new()
        holder.custom_minimum_size = Vector2(24, 24)
        enemy_trinket_grid.add_child(holder)
    var defs: Array = battle_manager.get_enemy_trinkets()
    for i in range(min(defs.size(), 5)):
        var view = TrinketViewScene.instantiate()
        view.trinket_id = defs[i].id
        enemy_trinket_grid.get_child(i).add_child(view)
```

> Call `populate_enemy_trinkets()` right after encounter setup (where EnemyLineup is populated).

---

## 10) Inspection window & registration
**Files:**
- `res://scenes/TrinketInspectionWindow.tscn`
- `res://scripts/TrinketInspectionWindow.gd`
- `res://scripts/WindowManager.gd` (registration line)

**TrinketInspectionWindow.tscn** (simple header + description — mirror your item window styling if you prefer)

```ini
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/TrinketInspectionWindow.gd" id="1"]

[node name="TrinketInspectionWindow" type="Window"]
title = "Trinket"
size = Vector2i(300, 160)
script = ExtResource("1")

[node name="VBox" type="VBoxContainer" parent="."]
layout_mode = 2
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 8.0
offset_top = 8.0
offset_right = -8.0
offset_bottom = -8.0

[node name="Title" type="Label" parent="VBox"]
text = "Trinket"

[node name="Description" type="RichTextLabel" parent="VBox"]
fit_content = true
```

**TrinketInspectionWindow.gd**

```gdscript
extends Window

@onready var title_label: Label = %Title
@onready var desc: RichTextLabel = %Description
var _def: TrinketDefinition

func _ready():
    if _def:
        _populate()

func open(payload: Dictionary) -> void:
    var id := StringName(payload.get("trinket_id", StringName("")))
    if id == StringName(""):
        return
    _def = Database.get_trinket_definition(id)
    _populate()

func _populate() -> void:
    if not _def: return
    title_label.text = _def.display_name_key
    desc.text = _def.description_key
```

**WindowManager.gd** — register the window (add once in your window registry block):

```gdscript
windows[&"TrinketInspection"] = load("res://scenes/TrinketInspectionWindow.tscn")
```

> Phase 1 scope note: This phase is scaffolding only — UI surfaces, resource definitions, containers, and registrations. No trigger handling, targeting logic, or minigame timing appears until Phase 2+.

---

## 11) Optional: sample trinkets to see the UI immediately
Create a couple of resource files to render something in the HUD. Icons may be null; they’ll still show a slot.

**`res://resources/trinkets/HealingAmulet.tres`**
```ini
[gd_resource type="Resource" script_class="TrinketDefinition" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/trinkets/TrinketDefinition.gd" id="1"]

[ext_resource type="Texture2D" path="res://assets/sprites/trinkets/Trinket1A.png" id="2"]

[resource]
script = ExtResource("1")
id = "HealingAmulet"
display_name_key = "Healing Amulet"
description_key = "At the start of your turn, heal the frontmost ally by 2."
icon = ExtResource("2")
is_player_exclusive = true
```

**`res://resources/trinkets/LightningRod.tres`**
```ini
[gd_resource type="Resource" script_class="TrinketDefinition" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/trinkets/TrinketDefinition.gd" id="1"]

[ext_resource type="Texture2D" path="res://assets/sprites/trinkets/Trinket4A.png" id="2"]

[resource]
script = ExtResource("1")
id = "LightningRod"
display_name_key = "Lightning Rod"
description_key = "When an ally dies, deal 2 damage to a random enemy."
icon = ExtResource("2")
is_enemy_exclusive = false
```

After creating them, you can in code (e.g., a debug button) call:

```gdscript
GameManager.run_state.add_trinket_definition(Database.get_trinket_definition(&"HealingAmulet"))
```

and set `enemy_trinket_ids` on an Encounter to `["LightningRod"]` to see them in Battle.

---

## 12) Verification checklist for Phase 1

- Project runs with zero new warnings/errors.
- `Main` screen shows a **5-slot PlayerTrinketGrid** before the Day label; adding/removing trinkets in RunState updates the grid immediately.
- `Battle` screen shows a **5-slot EnemyTrinketGrid** under the enemy lineup; encounter-specified trinkets render correctly.
- Single-clicking any trinket view opens **TrinketInspection** window with the correct title/description.
- No gameplay behavior has changed yet (that lands in Phase 2).

- No duplicates in `RUN_CONTAINER_TAGS.PLAYER_TRINKETS`: equipping the same trinket twice is ignored (five slots remain stable).
- Window key consistency: single click opens &"TrinketInspection"; title/description match the resource. `TrinketView` nodes are in the `InspectionOnly` group.
- Encounter wiring: enemy trinkets render from `EncounterDefinition.enemy_trinket_ids` without engine errors.

> Proceed to **Phase 2** only after the above are green.

---

## Changelog (Phase 1 fix)

- Corrected Overview: added `scripts/BattleManager.gd` under Edited files.
- Tightened constants to exactly five; added note not to add `TARGET_RANDOM_ENEMY` (already exists).
- Switched RunState snippets to use `RUN_CONTAINER_TAGS.PLAYER_TRINKETS` for the 5-slot container.
- Renamed `TrinketChip` to `TrinketView`; inspection is via single click.
- Standardized window payloads: `TrinketView.gd` passes `{ "trinket_id": ... }`; `TrinketInspectionWindow.gd` resolves via `Database.get_trinket_definition`.
- Simplified `BattleManager` encounter property access; no `has()` on resources.
- Added explicit note that window key is `&"TrinketInspection"` and a Phase 1 scope guard.

Commit message:

```
docs: fix Phase 1 — correct overview, constants, add BattleManager edit, ensure new/edited file blocks are complete
```
